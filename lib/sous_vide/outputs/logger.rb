module SousVide
  module Outputs
    # Prints the report to the logger (usually Chef logger).
    #
    #   Outputs::Logger.new
    class Logger
      def initialize(logger: nil)
        @logger = logger
      end

      def call(run_data:, node_data:, resources_data:)
        log "=============== #{self.class.name} ==============="
        log ""
        log "Processing #{resources_data.size} resources."
        log ""

        resources_data.each do |tracked|
          log("#{tracked.execution_order}.", tracked.to_s, tracked.status,
              "(#{tracked.duration_ms.to_i} ms)", tracked.execution_phase)
        end

        log ""
        log "Node info:"
        log ""
        log "Name:", node_data[:chef_node_instance_id]
        log "IP Address:", node_data[:chef_node_ipv4]
        log "Role:", node_data[:chef_node_role]
        log ""
        log "Run info:"
        log ""
        log "ID:", run_data[:chef_run_id]
        log "Started at:", run_data[:chef_run_started_at]
        log "Completed at:", run_data[:chef_run_completed_at]
        log "Success:", run_data[:chef_run_success]
        log ""
      end

      def log(*args)
        message = args.compact.join(' ')
        logger.info(message)
      end

      def logger
        @logger ||= ::Chef::Log
      end
    end
  end
end