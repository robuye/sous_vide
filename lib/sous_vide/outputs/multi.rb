module SousVide
  module Outputs
    # Combines multiple outputs
    #
    #   es = Outputs::ES.new ...
    #   log = Outputs::Logger.new ...
    #   multi = Outputs::Multi.new(es, log)
    class Multi
      def initialize(*outputs)
        @outputs = outputs
      end

      def call(run_data:, node_data:, resources_data:)
        @outputs.each do |output|
          output.call(run_data: run_data, node_data: node_data,
                      resources_data: resources_data)
        end
      end
    end
  end
end
