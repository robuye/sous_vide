module SousVide
  module Outputs
    # Combines multiple outputs
    #
    # @example
    #   http = JsonHTTP.new(url: "http://localhost:9200/endpoint")
    #   logger = SousVide::Outputs::Logger.new
    #   file = SousVide::Outputs::JsonFile.new
    #
    #   SousVide::Outputs::Multi.new(logger, file, http)
    class Multi
      def initialize(*outputs)
        @outputs = outputs
      end

      # Calls all configured outputs in order.
      def call(run_data:, node_data:, resources_data:)
        @outputs.each do |output|
          output.call(run_data: run_data, node_data: node_data,
                      resources_data: resources_data)
        end
      end
    end
  end
end
