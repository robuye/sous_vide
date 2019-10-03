module SousVide
  # This module implements Chef event methods. It's based on Chef::EventDispatch::Base.
  #
  # The event flow is as follows:
  #
  #   * resource_action_start                    # top level resource
  #   * resource_current_state_loaded            # top level resource
  #   * resource_action_start                    # 1st nested resource
  #   * resource_* events (possibly multiple)    # 1st nested resource
  #   * resource_completed                       # 1st nested resource
  #   * resource_action_start                    # 2nd nested resource
  #   * resource_* events (possibly multiple)    # 2nd nested resource
  #   * resource_completed                       # 2nd nested resource
  #   * resource_* events (possibly multiple)    # top level resource
  #   * resource_completed                       # top level resource
  #
  # Example output from SousVide:
  #
  #   1. sous_vide_e2e_nested_three[e2e sous nesting]#run updated (88 ms) converge
  #   > 2. execute[e2e nested three, before]#run updated (14 ms) converge
  #   > 3. sous_vide_e2e_nested_two[inside e2e nested three]#run updated (50 ms) converge
  #   > > 4. execute[e2e nested two, before]#run updated (15 ms) converge
  #   > > 5. sous_vide_e2e_nested_one[inside e2e nested two]#run updated (17 ms) converge
  #   > > > 6. execute[e2e nested one]#run updated (15 ms) converge
  #   > > 7. execute[e2e nested two, after]#run updated (16 ms) converge
  #   > 8. execute[e2e nested three, after]#run updated (20 ms) converge
  #
  # @see https://www.rubydoc.info/gems/chef/Chef/EventDispatch/Base
  module EventMethods
    # Called before action is executed on a resource.
    def resource_action_start(new_resource, action, notification_type, notifying_resource)
      @current_action = action
      @current_event = __callee__

      log_event_received(new_resource)

      # This is a delayed notification. From now on we are in 'delayed' run phase.
      if notification_type == :delayed && @run_phase != "delayed"
        debug("Changed run phase to 'delayed'.")
        @run_phase = "delayed"
      end

      # We're entering a new nest level (:resource_action_start called immediatelly after
      # :resource_current_state_loaded). The @processing_now is a previous event (it didn't go
      # through :resource_completed) and it already passed through this method completely so it
      # has all necessary attributes populated.
      #
      # Put it into @nested_queue array so it can be retrieved from there by other event methods
      # when needed. Also, unset @processing_now so it's not accidentally reused.
      if @previous_event == :resource_current_state_loaded
        debug("It's a nested resource and #{@processing_now} will be added to the nested queue.")
        @nested_queue << @processing_now
        @processing_now = nil
      end

      @processing_now = create(chef_resource: new_resource, action: action)

      # Calculate nesting level / depth. If there are any resources in @nested_queue then this is
      # a nested resource, one level deeper than the last element in @nested_queue array.
      if parent_resource = @nested_queue.last
        @processing_now.nest_level = parent_resource.nest_level + 1
        debug("Set #{@processing_now} nest level to #{@processing_now.nest_level}")
      end

      # The execution order is captured when Chef begins processing a resource and it's pushed to
      # the @processed array in :resource_completed. This is significant when working with nested
      # resources.
      #
      # Setting it at the :resource_action_start will cause outer resource to be reported at the
      # top (lower order) and sub-resources beneath. It is easier to read than the other way
      # around although it may feel counter-intuitive at first glance.
      #
      # Note the @processed array being populated in :resource_completed is ordered the other way
      # around (inner-most resources are at the top) so it should be sorted by the outputs.
      @execution_order += 1
      @processing_now.execution_order = @execution_order

      @processing_now.execution_phase = @run_phase
      @processing_now.started_at = Time.now.strftime("%F %T")

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

      @previous_event = @current_event
      @current_event = nil
      true
    end

    # Called after a resource has been completely converged, but only if modifications were made.
    def resource_updated(new_resource, action)
      @current_action = action
      @current_event = __callee__

      log_event_received(new_resource)
      get_resource_from_nested_queue if @processing_now.nil?
      return false if event_out_of_bound?(new_resource)

      @processing_now.status = "updated"

      @previous_event = @current_event
      @current_event = nil
      true
    end

    # Called after #load_current_resource has run
    def resource_current_state_loaded(new_resource, action, current_resource)
      @current_action = action
      @current_event = __callee__

      # Note this event does not attempt to retrieve @processing_now from @nested_queue because
      # it's only ever called after :resource_action_start or not at all (when skipped) so the
      # @processing_now is set or it's out of bound.
      log_event_received(new_resource)
      return false if event_out_of_bound?(new_resource)

      # Capture loaded & wanted attributes so it can be later used to build a diff.
      # This is the only place we have access to 'current_resource'.
      #
      # The diff itself will be computed later, in :resource_completed event as it provides
      # more flexibility and information.
      @processing_now.loaded_attributes =
        case current_resource
        when Chef::Resource::Package
          get_chef_attributes(current_resource, :version)
        when Chef::Resource::Service
          get_chef_attributes(current_resource, :running, :enabled)
        when Chef::Resource::User
          get_chef_attributes(current_resource, :uid, :gid, :home, :shell, :comment)
        end

      @processing_now.wanted_attributes =
        case current_resource
        when Chef::Resource::Package
          get_chef_attributes(new_resource, :version)
        when Chef::Resource::Service
          get_chef_attributes(new_resource, :running, :enabled)
        when Chef::Resource::User
          get_chef_attributes(new_resource, :uid, :gid, :home, :shell, :comment)
        end


      # Some resources (ie Execute) do not set instance variable and Chef passes nil.
      @processing_now.attributes_loaded = !!current_resource

      @previous_event = @current_event
      @current_event = nil
      true
    end

    # Called when a resource action has been skipped b/c of a conditional.
    def resource_skipped(new_resource, action, conditional)
      @current_action = action
      @current_event = __callee__

      log_event_received(new_resource, "(#{conditional.to_text})")
      get_resource_from_nested_queue if @processing_now.nil?
      return false if event_out_of_bound?(new_resource)

      @processing_now.guard_description = conditional.to_text
      @processing_now.status = "skipped"

      @previous_event = @current_event
      @current_event = nil
      true
    end

    # Called when a resource has no converge actions, e.g., it was already correct.
    def resource_up_to_date(new_resource, action)
      @current_action = action
      @current_event = __callee__

      log_event_received(new_resource)
      get_resource_from_nested_queue if @processing_now.nil?
      return false if event_out_of_bound?(new_resource)

      @processing_now.status = "up-to-date"
      @previous_event = @current_event
      @current_event = nil
      true
    end

    # Called when a resource action has been completed.
    def resource_completed(new_resource)
      @current_event = __callee__

      log_event_received(new_resource)
      get_resource_from_nested_queue if @processing_now.nil?
      return false if event_out_of_bound?(new_resource)

      @processing_now.duration_ms = (new_resource.elapsed_time.to_f * 1000).to_i

      # If a resource has notifications Chef will converge it in a forced_why_run mode to
      # determine if any update will happen and if the notifications should be called.
      #
      # When this event was fired in why_run mode we override its status to `why-run`.
      #
      # This is also how Chef::Runner#focred_why_run is implemented so it should be reliable.
      if ::Chef::Config[:why_run]
        debug("Resource #{@processing_now.name}##{@processing_now.action} marked why-run",
              "because Chef::Config[:why_run] is true.")
        @processing_now.status = "why-run"
      end

      # This is a top-level resource that was not notified by another and is a subject of normal
      # ordered converge process. @resource_collection_cursor is pointing to next resource
      # according to the expanded resource collection.
      #
      # Nested resources should not increment the cursor because they are not included in Chef's
      # resource collection to begin with. Should a failure occur in a nested resource it will
      # be propagated to a parent and handled normally by SousVide as a top-level resource
      # failure.
      #
      # When chef-client fails we will take remaining entries and add to the report as
      # 'unprocessed'. It works because resources are ordered, and we can keep track where we are.
      #
      # why-run mode, nested resource and notifications are not in natural order according to
      # expanded resource collection and must not move the cursor.
      #
      # Having it pointing ahead is relevant because current resource has just been converged
      # (maybe 'failed') and it is not 'unprocessed'.
      if !@processing_now.notifying_resource && # not notified
         !::Chef::Config[:why_run] &&           # not why-run
         @nested_queue.empty? &&                # not nested
         @run_phase == "converge"               # only converge phase

        @resource_collection_cursor += 1
      end

      # Populate the diff at the end so the DiffBuilder can access fields that would not be
      # available before, ie status. Additionaly the 'case' here avoids leaking abstraction.
      @processing_now.diff =
        case new_resource
        when Chef::Resource::Package then DiffBuilder.package_diff(@processing_now)
        when Chef::Resource::Service then DiffBuilder.service_diff(@processing_now)
        when Chef::Resource::User then DiffBuilder.user_diff(@processing_now)
        when Chef::Resource::File then DiffBuilder.file_diff(new_resource.diff)
        end

      @processing_now.completed_at = Time.now.strftime("%F %T")
      @processed << @processing_now
      @processing_now = nil

      @previous_event = @current_event
      @current_event = nil
      true
    end

    # Called when a resource fails and will not be retried.
    def resource_failed(new_resource, action, exception)
      @current_event = __callee__
      @current_action = action

      log_event_received(new_resource)
      get_resource_from_nested_queue if @processing_now.nil?
      return false if event_out_of_bound?(new_resource)

      @processing_now.status = "failed"
      @processing_now.error_source = new_resource.to_text
      @processing_now.error_output = exception.message

      @previous_event = @current_event
      @current_event = nil
      true
    end

    # Called when a resource fails, but will retry.
    #
    # Resources with retries can succeed on subsequent attempts or ignore_failure option may be
    # set and it's the only place we can capture intermittent errors.
    #
    # This event can fire multiple times, but we capture only the most recent error.
    def resource_failed_retriable(new_resource, action, _remaining_retries, exception)
      @current_event = __callee__
      @current_action = action

      log_event_received(new_resource)
      get_resource_from_nested_queue if @processing_now.nil?
      return false if event_out_of_bound?(new_resource)

      @processing_now.retries += 1
      @processing_now.error_source = new_resource.to_text
      @processing_now.error_output = exception.message

      @previous_event = @current_event
      @current_event = nil
      true
    end

    # Called before convergence starts
    def converge_start
      debug("Received :converge_start")
      debug("Changed run phase to 'converge'.")
      @run_phase = "converge"
      @run_name ||= [@run_started_at, @chef_node_role, @chef_node_ipv4, @run_id].join(" ")
    end

    # Called when the converge phase is finished (success)
    def converge_complete
      debug("Received :converge_completed")
      @run_success = true
      @run_completed_at = Time.now.strftime("%F %T")
      send_to_output!
    end

    # Called if the converge phase fails
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
