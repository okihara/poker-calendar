# encoding: utf-8

require 'json'
require_relative './loggable'

module PokerCalendar
  class TournamentAnalyzer
    include Loggable

    def initialize(openai_client, data_dir)
      @client = openai_client
      @data_dir = data_dir
    end

    def process_tournaments(date)
      date_str = date.strftime("%Y-%m-%d")
      # pg-YYYY-MM-DD-*.txt と pf-YYYY-MM-DD-*.txt を対象
      info_files = Dir.glob(File.join(@data_dir, "*-#{date_str}-*.txt"))
      log "Analyzing #{info_files.size} tournament files for #{date_str}"

      info_files.each_with_index do |info_file, index|
        process_tournament(info_file, index, info_files.size)
      end
    end

    private

    def process_tournament(info_file, index, total)
      res_file_path = make_response_file_path(info_file)
      if File.exist?(res_file_path)
        log "SKIP: Tournament analysis already exists for #{File.basename(info_file)}"
        return
      end

      info_html = File.read(info_file, encoding: 'utf-8')

      begin
        sleep(0.7)
        log "Analyzing tournament #{index + 1}/#{total}: #{File.basename(info_file)}"
        response = analyze(info_html)
        File.write(res_file_path, response, encoding: 'UTF-8')
      rescue => e
        log "Error analyzing tournament: #{e.message}"
      end
    end

    def make_response_file_path(info_file)
      dir = File.dirname(info_file)
      basename = File.basename(info_file)
      File.join(dir, "res-#{basename}.json")
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
      - date as string(YYYY/MM/DD)
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
