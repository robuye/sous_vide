require "sous_vide/event_methods"
require "sous_vide/outputs/json_file"
require "sous_vide/outputs/json_http"
require "sous_vide/outputs/logger"
require "sous_vide/outputs/multi"

require "securerandom"
require "singleton"

module SousVide
  # == SousVide::Handler
  #
  # The Handler receives event data from chef-client and keeps track of the converge process. It's
  # essentially a stream parser hooked into Chef::EventDispatch.
  #
  # Event methods are all in SousVide::EventMethods module. This file contains logic that does not
  # deal with events directly.
  class Handler
    include Singleton
    include EventMethods

    attr_accessor :chef_run_context,
                  :logger,
                  :sous_output,
                  :processing_now,
                  :processed,
                  :run_phase,
                  :run_id,
                  :run_name

    # Enables the handler. Call it anywhere in the recipe, ideally as early as possible.
    #
    #   SousVide::Handler.register(node.run_context)
    #
    # All converge-time resources will be included in the report regardless at what point
    # registration happens.
    #
    # Compile-time resources defined before registration will not be included.
    # TODO: see client.rb start_handlers as an option.
    #
    # `chef_handler` resource does not support subscribing to :events so we have give up DSL and
    # use Chef API.
    #
    # The `Chef.event_handler` DSL could be used but dealing with returns and exceptions in procs
    # is a pain.
    def self.register(run_context)
      ::Chef::Log.info "Registering SousVide"

      instance.chef_run_context = run_context
      instance.post_initialize

      run_context.events.register(instance)
    end

    def initialize
      @execution_order = 0
      @resource_collection_cursor = 0

      @processed = []
      @processing_now = nil

      @run_started_at = Time.now.strftime("%F %T")

      # Not related to RunStatus#run_id, it's our internal run id.
      @run_id = SecureRandom.uuid.split("-").first # => 596e9d00
      @run_phase = "compile"

      # Default to Chef logger, but can be changed to anything that responds to #call
      @logger = ::Chef::Log
      @sous_output = Outputs::Logger.new(logger: @logger)
    end

    # This is called in #register, as soon as @chef_run_context is available.
    def post_initialize
      @chef_node_ipv4 = @chef_run_context.node["ipaddress"] || "<no ip>"
      @chef_node_role = @chef_run_context.node["roles"].first || "<no role>"
      @chef_node_instance_id = @chef_run_context.node.name
    end


    def run_data
      {
        chef_run_id: @run_id,
        chef_run_name: @run_name,
        chef_run_started_at: @run_started_at,
        chef_run_completed_at: @run_completed_at,
        chef_run_success: @run_success
      }
    end

    def node_data
      {
        chef_node_ipv4: @chef_node_ipv4,
        chef_node_instance_id: @chef_node_instance_id,
        chef_node_role: @chef_node_role
      }
    end

    def create(chef_resource:, action:)
      tracked = TrackedResource.new(action: action,
                                    name: chef_resource.name,
                                    type: chef_resource.resource_name)

      tracked.cookbook_name = chef_resource.cookbook_name || "<Dynamically Defined Resource>"
      tracked.cookbook_recipe = chef_resource.recipe_name || "<Dynamically Defined Resource>"
      tracked.source_line = chef_resource.source_line || "<Dynamically Defined Resource>"
      tracked.chef_resource_handle = chef_resource
      tracked
    end

    # We will ignore nested resources. Once a top level resource triggered :resource_action
    # started any events not related to it will be ignored.
    def nested?(chef_resource)
      @processing_now &&
        @processing_now.chef_resource_handle != chef_resource
    end

    # When chef-client fails we haven't seen all resources and need to backfill the handler.
    def consume_unprocessed_resources!
      all_known_resources = expand_chef_resources!

      # No unprocessed resources left. Failure likely occured on last resource or in a delayed
      # notification.
      # TODO: check delayed notification failure
      return if @resource_collection_cursor >= all_known_resources.size

      unprocessed = all_known_resources[@resource_collection_cursor..-1]

      # We will pass unprocessed resources via  :resource_action_start and :resource_completed so
      # they will end up in @processed array, but with status set to 'unprocessed' and execution
      # phase 'post-converge'.
      #
      # TODO: consider placing these resources before delayed notification, currently they are
      # always at the very end. It _maybe_ makes sense.
      unprocessed.each do |tracked|
        resource_action_start(
          tracked.chef_resource_handle, # new_resource
          tracked.action,               # action
          nil,                          # notification_type
          nil                           # notifying_resource
        )

        resource_completed(
          tracked.chef_resource_handle  # new_resource
        )
      end
    end

    # Resources with multiple actions must be expanded, ie. given resource:
    #
    #   service 'nginx' do
    #     action [:enable, :start]
    #   end
    #
    # After expansion we should have 2 resources:
    #
    #   * service[nginx] with action :enable
    #   * service[nginx] with action :start
    #
    # We keep track of the progress and on failure we will pick up unprocessed resources from here
    # to feed the handler in post-converge stage.
    #
    # On a successful chef-client run @processed will contain all resources and this method won't
    # be called.
    def expand_chef_resources!
      chef_run_context.resource_collection.flat_map do |chef_resource|
        Array(chef_resource.action).map do |action|
          create(chef_resource: chef_resource, action: action)
        end
      end
    end

    def send_to_output!
      @sous_output.call(run_data: run_data, node_data: node_data, resources_data: @processed)
    end

    def debug(*args)
      message = args.compact.join(" ")
      logger.debug(message)
    end

    def logger
      @logger ||= ::Chef::Log
    end
  end
end
