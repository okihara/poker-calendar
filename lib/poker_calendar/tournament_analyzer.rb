# encoding: utf-8

require 'json'
require_relative './loggable'

module PokerCalendar
  class TournamentAnalyzer
    include Loggable

    def initialize(openai_client)
      @client = openai_client
    end

    def process_tournaments(tournament_links, scraper)
      log "Analyzing #{tournament_links.size} tournaments"
      tournament_links.each_with_index do |link, index|
        process_tournament(link, scraper, index, tournament_links.size)
      end
    end

    private

    def process_tournament(link, scraper, index, total)
      res_file_path = scraper.make_response_file_path(link)
      if File.exist?(res_file_path)
        log "SKIP: Tournament analysis already exists for #{link}"
        return
      end

      info_html = File.read(scraper.make_info_file_path(link), encoding: 'utf-8')

      begin
        sleep(0.7)
        log "Analyzing tournament #{index + 1}/#{total}: #{link}"
        response = analyze(info_html)
        File.write(res_file_path, response, encoding: 'UTF-8')
      rescue => e
        log "Error analyzing tournament: #{e.message}"
      end
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
