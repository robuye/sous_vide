require "chef/config"
require "chef/json_compat"
require "chef/log"

module SousVide
  module Outputs
    # Saves the report to a JSON file on a node.  The file will be saved to chef cache directory.
    #
    #   Outputs::JsonFile.new
    #
    # By the report will be saved to "<chef-cache-path>/sous-vide-report.json".
    class JsonFile
      def initialize(logger: logger)
        @logger = logger
      end

      def call(run_data:, node_data:, resources_data:)
        log "=============== #{self.class.name} ==============="
        log ""
        log "Processing #{resources_data.size} resources."

        json_data = resources_data.map do |tracked|
          tracked.to_h.merge(node_data).merge(run_data)
        end

        ::Chef::FileCache.store("sous-vide-report.json",
                                ::Chef::JSONCompat.to_json_pretty(json_data))

        log "The report is in #{Chef::Config[:file_cache_path]}/sous-vide-report.json file."
        log ""
      end

      def log(*args)
        message = args.compact.join(" ")
        logger.info(message)
      end

      def logger
        @logger ||= ::Chef::Log
      end
    end
  end
end
