require 'openai'
require_relative '../errors/poker_calendar_errors'
require_relative '../utils/retry_handler'

module PokerCalendar
  module Clients
    class OpenaiClient
      def initialize(access_token:, model:, temperature:, rate_limit_delay:, logger:)
        @client = OpenAI::Client.new(access_token: access_token)
        @model = model
        @temperature = temperature
        @rate_limit_delay = rate_limit_delay
        @logger = logger
      end

      def analyze_tournament_html(html_content, prompt)
        @logger.info("OpenAI analysis request", model: @model)
        
        Utils::RetryHandler.with_retry(
          max_retries: 3,
          initial_delay: @rate_limit_delay,
          retryable_errors: [OpenAI::Error]
        ) do
          sleep(@rate_limit_delay) if @rate_limit_delay > 0
          
          response = @client.chat(
            parameters: {
              model: @model,
              response_format: { type: "json_object" },
              messages: [{ role: "user", content: prompt + html_content }],
              temperature: @temperature,
            }
          )
          
          content = response.dig("choices", 0, "message", "content")
          @logger.info("OpenAI analysis success", model: @model)
          content
        end
      rescue OpenAI::Error => e
        @logger.error("OpenAI analysis failed", model: @model, error: e.message)
        raise ParsingError, "OpenAI analysis failed: #{e.message}"
      end
    end
  end
end
