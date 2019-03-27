require "net/http"
require "time"
require "uri"

module SousVide
  module Outputs
    # Makes a POST request to a configured endpoint. Logstash & Elasticsearch friendly format.
    #
    #   JsonHTTP.new(url: "http://localhost:9200/endpoint", max_retries: 10)
    class JsonHTTP
      def initialize(url:, max_retries: 0, logger: nil)
        @endpoint = URI(url)
        @logger = logger

        @max_retries = max_retries || 2
        @http_client = Net::HTTP.new(@endpoint.host, @endpoint.port)
      end

      def call(run_data:, node_data:, resources_data:)
        log "=============== #{self.class.name} ==============="
        log ""
        log "Processing #{resources_data.size} resources."
        log "Target: #{@endpoint.to_s}"

        resources_data.each do |tracked|
          _path = @endpoint.path == "" ? "/" : @endpoint.path
          post_request = Net::HTTP::Post.new(_path, "Content-Type" => "application/json")

          payload = tracked.to_h.merge(node_data).merge(run_data)
          payload["@timestamp"] = Time.parse(payload[:chef_resource_started_at]).iso8601(3)

          post_request.body = payload.to_json

          call_with_retries(post_request)
        end

        log "All resources processed."
        log ""
      end

      def call_with_retries(nethttp_request)
        _retry = 0
        begin
          @http_client.request(nethttp_request)
        rescue
          if _retry < @max_retries
            _retry += 1
            sleep 2
            retry
          else
            raise
          end
        end
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
