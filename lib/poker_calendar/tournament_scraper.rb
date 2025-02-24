# encoding: utf-8

require 'time'
require 'json'
require 'openai'
require_relative './loggable'

module PokerCalendar
  class TournamentScraper
    include Loggable

    BASE_URL = 'https://pokerguild.jp'
    
    def initialize(openai_client, data_dir, date)
      @client = openai_client
      @data_dir = data_dir
      @date = date
      @date_str = date.strftime("%Y-%m-%d")
    end

    def fetch_daily_tournaments
      daily_file = File.join(@data_dir, "pg-#{@date_str}.html")
      
      fetch_daily_page(daily_file)
      
      html_content = File.read(daily_file, encoding: 'utf-8')
      extract_tournament_links(html_content)
    end

    def process_tournaments(tournament_links)
      log "Processing #{tournament_links.size} tournaments"
      tournament_links.each_with_index do |link, index|
        log "Processing tournament #{index + 1}/#{tournament_links.size}: #{link}"
        fetch_tournament_info(link)
        process_tournament_info(link)
      end
    end

    def make_response_file_path(tourney_link)
      filename = "res-#{make_info_file_name(tourney_link)}.json"
      File.join(@data_dir, filename)
    end
    private

    def fetch_daily_page(file_path)
      log "Fetching daily tournament list for #{@date_str}"
      `curl -L --compressed -X GET "#{BASE_URL}/?date=#{@date_str}" > #{file_path}`
    end

    def extract_tournament_links(html_content)
      html_content.scan(/<main>.*?<\/main>/m).join
                 .scan(/\/tourneys\/\d+/)
                 .uniq
    end

    def fetch_tournament_info(tourney_link)
      file_path = make_info_file_path(tourney_link)
      if File.exist?(file_path)
        log "SKIP: Tournament info already exists for #{tourney_link}"
        return
      end

      sleep(1)
      url = "#{BASE_URL}#{tourney_link}"
      `curl -L --compressed -X GET "#{url}" > #{file_path}`
    end

    def process_tournament_info(link)
      res_file_path = make_response_file_path(link)
      if File.exist?(res_file_path)
        log "SKIP: Tournament analysis already exists for #{link}"
        return
      end

      info_html = File.read(make_info_file_path(link), encoding: 'utf-8')
      
      begin
        sleep(0.7)
        log "Processing tournament info for #{link}"
        response = post_to_openai(info_html)
        File.write(res_file_path, response, encoding: 'UTF-8')
      rescue => e
        log "Error processing tournament: #{e.message}"
      end
    end


    def make_info_file_path(tourney_link)
      # TODO: 違う日でも同じIDがありえるのでファイル名に日付を付ける
      filename = make_info_file_name(tourney_link)
      File.join(@data_dir, filename)
    end

    def make_info_file_name(tourney_link)
      "pg-#{@date_str}-#{tourney_link.gsub("/", "-")}.txt"
    end


    def post_to_openai(info_html)
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
  end
end
