module SousVide
  # == SousVide::TrackedResource
  #
  # This is a very simple data structure SousVide uses to capture interesting
  # information.
  class TrackedResource
    attr_accessor :type,
                  :name,
                  :action,
                  :status,
                  :duration_ms,
                  :guard_description,
                  :execution_phase,
                  :execution_order,
                  :notifying_resource,
                  :notification_type,
                  :before_notifications,
                  :immediate_notifications,
                  :delayed_notifications,
                  :retries,
                  :error_output,
                  :error_source,
                  :cookbook_name,
                  :cookbook_recipe,
                  :source_line,
                  :started_at,
                  :completed_at

    attr_accessor :chef_resource_handle

    def initialize(name:, action:, type:)
      @name = name
      @action = action
      @type = type

      @status = "unprocessed"
      @duration_ms = nil
      @guard_description = nil

      @retries = 0
      @error_output = nil
      @error_source = nil
    end

    def to_s
      "#{@type}[#{@name}]##{@action}"
    end

    def to_h
      {
        chef_resource: "#{@type}[#{@name}]##{@action}",
        chef_resource_name: @name,
        chef_resource_type: @type,
        chef_resource_cookbook: @cookbook_name,
        chef_resource_recipe: @cookbook_recipe,
        chef_resource_action: @action,
        chef_resource_guard: @guard_description,
        chef_resource_duration_ms: @duration_ms,
        chef_resource_error_output: @error_output,
        chef_resource_error_source: @error_source,
        chef_resource_retries: @retries,
        chef_resource_notified_by: @notifying_resource,
        chef_resource_notified_via: @notification_type,
        chef_resource_before_notifications: @before_notifications,
        chef_resource_immediate_notifications: @immediate_notifications,
        chef_resource_delayed_notifications: @delayed_notifications,
        chef_resource_order: @execution_order,
        chef_resource_execution_phase: @execution_phase,
        chef_resource_started_at: @started_at,
        chef_resource_completed_at: @completed_at,
        chef_resource_status: @status
      }
    end
  end
end
