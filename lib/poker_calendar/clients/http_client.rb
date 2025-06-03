require 'net/http'
require 'uri'
require_relative '../errors/poker_calendar_errors'
require_relative '../utils/retry_handler'

module PokerCalendar
  module Clients
    class HttpClient
      def initialize(logger:, request_delay: 1.0, max_retries: 3)
        @logger = logger
        @request_delay = request_delay
        @max_retries = max_retries
      end

      def get(url, headers: {})
        @logger.info("HTTP GET request", url: url)
        
        Utils::RetryHandler.with_retry(
          max_retries: @max_retries,
          retryable_errors: [Net::TimeoutError, Net::HTTPError, SocketError]
        ) do
          sleep(@request_delay) if @request_delay > 0
          
          uri = URI(url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == 'https'
          http.read_timeout = 30
          http.open_timeout = 10
          
          request = Net::HTTP::Get.new(uri)
          headers.each { |key, value| request[key] = value }
          
          response = http.request(request)
          
          unless response.is_a?(Net::HTTPSuccess)
            raise NetworkError, "HTTP request failed: #{response.code} #{response.message}"
          end
          
          @logger.info("HTTP GET success", url: url, status: response.code)
          response.body
        end
      rescue => e
        @logger.error("HTTP GET failed", url: url, error: e.message)
        raise NetworkError, "Failed to fetch #{url}: #{e.message}"
      end
    end
  end
end
