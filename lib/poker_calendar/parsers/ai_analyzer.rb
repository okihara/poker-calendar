require 'json'
require_relative '../errors/poker_calendar_errors'

module PokerCalendar
  module Parsers
    class AiAnalyzer
      PROMPT = <<~PROMPT
        以下はポーカールームのトーナメント情報です
        - shop_name as string
        - address as string
        - area as string(渋谷,六本木,新宿,etc...)
        - title as string
        - date as string
        - start_time as string
        - late_registration_time as string
        - entry_fee as integer(参加費)
        - reentry_fee as integer(リエントリ費)
        - add_on as integer(アドオン費)
        - prize_list as list<integer>
        - total_prize as integer
        - prize_text as text
        - guaranteed_amount as integer(コイン保証額)
        - is_jopt_prize as boolean
        - is_coin_prize as boolean
        を抜き出してjsonで返してください
        ---
      PROMPT

      def initialize(openai_client:, logger:)
        @openai_client = openai_client
        @logger = logger
      end

      def analyze_tournament_html(html_content)
        @logger.debug("Analyzing tournament HTML with AI")
        
        response_json = @openai_client.analyze_tournament_html(html_content, PROMPT)
        
        begin
          parsed_data = JSON.parse(response_json)
          @logger.info("AI analysis successful", shop_name: parsed_data["shop_name"])
          parsed_data
        rescue JSON::ParserError => e
          @logger.error("Failed to parse AI response as JSON", error: e.message)
          raise ParsingError, "Invalid JSON response from AI: #{e.message}"
        end
      end
    end
  end
end
