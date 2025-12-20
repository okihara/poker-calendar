# encoding: utf-8

require 'json'
require_relative './loggable'

module PokerCalendar
  class TournamentAnalyzer
    include Loggable

    def initialize(openai_client)
      @client = openai_client
    end

    def analyze(info_html)
      response = @client.chat(
        parameters: {
          model: "gpt-4o-mini",
          response_format: { type: "json_object" },
          messages: [{ role: "user", content: PROMPT + info_html }],
          temperature: 0.7,
        }
      )
      response.dig("choices", 0, "message", "content")
    end

    private

    PROMPT = <<~PROMPT
      以下はポーカールームのトーナメント情報です
      - shop_name as string
      - address as string
      - area as string(渋谷,六本木,新宿,etc...)
      - title as string
      - date as string
      - start_time as string(YYYY/MM/DD HH:MM)
      - late_registration_time as string(YYYY/MM/DD HH:MM)
      - late_reentry_time as string(YYYY/MM/DD HH:MM)
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
  end
end
