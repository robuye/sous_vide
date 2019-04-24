module SousVide
  module Outputs
    # Saves the report to a JSON file.  The file will be saved to chef cache directory.
    #
    # Default file name is "sous-vide-report.json".
    #
    # @example
    #
    #   SousVide::Outputs::JsonFile.new
    class JsonFile
      def initialize(logger: nil, file_name: "sous-vide-report.json")
        @logger = logger
        @file_name = file_name
      end

      # Saves report to file.
      def call(run_data:, node_data:, resources_data:)
        log "=============== #{self.class.name} ==============="
        log ""
        log "Processing #{resources_data.size} resources."

        json_data = resources_data.map do |tracked|
          tracked.to_h.merge(node_data).merge(run_data)
        end

        ::Chef::FileCache.store(@file_name, ::Chef::JSONCompat.to_json_pretty(json_data))

        log "The report is in #{Chef::Config[:file_cache_path]}/#{@file_name} file."
        log ""
      end

      private

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
