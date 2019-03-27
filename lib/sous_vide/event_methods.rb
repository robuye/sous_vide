module SousVide
  # This module implements Chef event methods. It's based on Chef::EventDispatch::Base.
  #
  # Nested resources are explicitly ignored and the code flow will be as follows:
  #
  # 1. resource_action_start
  # 2. resource_* events (possibly multiple)
  # 3. resource_action_complete
  #
  # The code is intentionally procedural and explicit. If :resource_action_start assigned
  # @processing_now only then other events will work. :resource_action_completed unassigns
  # @processing_now so all events will be ignored until :resource_action_start is called
  # again.
  module EventMethods
    # This hook will always fire whenever chef is about to converge a resource, including why_run
    # mode, notifications or skipped resources.
    def resource_action_start(new_resource, action, notification_type, notifying_resource)
      if nested?(new_resource) # ignore nested resources
        new_r_name = "#{new_resource.resource_name}[#{new_resource.name}]##{action}"
        debug("Received :resource_action_start on #{new_r_name}.",
              "It's a nested resource and will be ignored.")
        return false
      end

      # This is a delayed notification. From now on we are in 'delayed' run phase.
      if notification_type == :delayed && @run_phase != "delayed"
        debug("Changed run phase to 'delayed'.")
        @run_phase = "delayed"
      end

      @processing_now = create(chef_resource: new_resource, action: action)
      debug("Received :resource_action_start on #{@processing_now}.")

      @execution_order += 1
      @processing_now.execution_order = @execution_order
      @processing_now.execution_phase = @run_phase
      @processing_now.started_at = Time.now.strftime("%F %T")

      @processing_now.chef_resource_handle = new_resource

      @processing_now.before_notifications = new_resource.before_notifications.size
      @processing_now.immediate_notifications = new_resource.immediate_notifications.size
      @processing_now.delayed_notifications = new_resource.delayed_notifications.size

      # When notifying resource is present notification_type will also be present.  It is nil for
      # delayed notifications.
      if notifying_resource
        _name = "#{notifying_resource.resource_name}[#{notifying_resource.name}]"
        debug("Notified from #{_name} (:#{notification_type})")
        @processing_now.notifying_resource = _name
      end
      @processing_now.notification_type = notification_type
      true
    end

    def resource_updated(new_resource, _action)
      return false if @processing_now.nil? || nested?(new_resource) # ignore nested resources

      debug("Received :resource_updated on #{@processing_now}")
      @processing_now.status = "updated"
      true
    end

    # Resource is skipped when a guard instruction stops the converge process or when
    # `action :nothing` is used (it's a guard too).
    def resource_skipped(new_resource, _action, conditional)
      return false if @processing_now.nil? || nested?(new_resource) # ignore nested resources

      debug("Received :resource_skipped on #{@processing_now}", "(#{conditional.to_text})")
      @processing_now.guard_description = conditional.to_text
      @processing_now.status = "skipped"
      true
    end

    def resource_up_to_date(new_resource, _action)
      return false if @processing_now.nil? || nested?(new_resource) # ignore nested resources

      debug("Received :resource_up_to_date on #{@processing_now}")
      @processing_now.status = "up-to-date"
      true
    end

    def resource_completed(new_resource)
      return false if @processing_now.nil? || nested?(new_resource) # ignore nested resources

      debug("Received :resource_completed on #{@processing_now}")
      @processing_now.duration_ms = (new_resource.elapsed_time.to_f * 1000).to_i

      # If a resource has notifications Chef will converge it in a forced_why_run mode to
      # determine if any update will happen and if the notifications should be called.
      #
      # When this event was fired in why_run mode we override it's status to `why-run`.
      #
      # This is also how Chef::Runner#focred_why_run is implemented so it should be reliable.
      #
      # TODO: what happens when :why_run for notification fails?
      if ::Chef::Config[:why_run]
        debug("Resource #{@processing_now.name}##{@processing_now.action} marked why-run",
              "because Chef::Config[:why_run] is true.")
        @processing_now.status = "why-run"
      end

      # This resource was not notified by another and is a subject of normal ordered converge
      # process. @resource_collection_cursor is pointing to next resource according to the
      # expanded resource collection.
      #
      # When chef-client fails we will take remaining entries and add to the report as
      # 'unprocessed'. It works because resources are ordered and we can keep track where we are.
      #
      # why-run mode and notifications are not in natural order and must not move the cursor.
      #
      # Having it pointing ahead is relevant because current resource has just been converged
      # (technically 'failed') and it is not 'unprocessed'.
      if !@processing_now.notifying_resource && # not notified
         !::Chef::Config[:why_run] &&           # not why-run
         @run_phase == "converge"               # only converge phase

        @resource_collection_cursor += 1
      end

      @processing_now.completed_at = Time.now.strftime("%F %T")
      @processed << @processing_now
      @processing_now = nil
      true
    end

    def resource_failed(new_resource, _action, exception)
      return false if @processing_now.nil? || nested?(new_resource) # ignore nested resources

      debug("Received :resource_failed on #{@processing_now}")
      @processing_now.status = "failed"
      @processing_now.error_source = new_resource.to_text
      @processing_now.error_output = exception.message
      true
    end

    # Resources with retries can succeed on subsequent attempts or ignore_failure option may be
    # set and it's the only place we can capture intermittent errors.
    #
    # This event can fire multiple times, but we capture only the most recent error.
    def resource_failed_retriable(new_resource, _action, _remaining_retries, exception)
      return false if @processing_now.nil? || nested?(new_resource) # ignore nested resources

      debug("Received :resource_failed_retriable on #{@processing_now}")
      @processing_now.retries += 1
      @processing_now.error_source = new_resource.to_text
      @processing_now.error_output = exception.message
      true
    end

    def converge_start
      debug("Received :converge_start")
      debug("Changed run phase to 'converge'.")
      @run_phase = "converge"
      @run_name ||= [@run_started_at, @chef_node_role, @chef_node_ipv4, @run_id].join(" ")
    end

    def converge_complete
      debug("Received :converge_completed")
      @run_success = true
      @run_completed_at = Time.now.strftime("%F %T")
      send_to_output!
    end

    def converge_failed(_exception)
      debug("Received :converge_failed")
      @run_success = false
      @run_completed_at = Time.now.strftime("%F %T")
      @run_phase = "post-converge"
      debug("Changed run phase to 'post-converge'.")

      consume_unprocessed_resources!
      send_to_output!
    end
  end
end
