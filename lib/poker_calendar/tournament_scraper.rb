require 'time'
require 'json'
require 'openai'

module PokerCalendar
  class TournamentScraper
    BASE_URL = 'https://pokerguild.jp'
    
    def initialize(openai_client, data_dir)
      @client = openai_client
      @data_dir = data_dir
    end

    def fetch_daily_tournaments(date)
      date_str = date.strftime("%Y-%m-%d")
      daily_file = File.join(@data_dir, "pg-#{date_str}.html")
      
      if File.exist?(daily_file)
        puts "SKIP: Daily tournament list already exists for #{date_str}"
      else
        fetch_daily_page(date_str, daily_file)
      end
      
      html_content = File.read(daily_file)
      extract_tournament_links(html_content)
    end

    def process_tournaments(tournament_links)
      tournament_links.each do |link|
        fetch_tournament_info(link)
        process_tournament_info(link)
      end
    end

    private

    def fetch_daily_page(date_str, file_path)
      puts "Fetching daily tournament list for #{date_str}"
      `curl -X GET "#{BASE_URL}/?date=#{date_str}" > #{file_path}`
    end

    def extract_tournament_links(html_content)
      html_content.scan(/<main>.*?<\/main>/m).join
                 .scan(/\/tourneys\/\d+/)
                 .uniq
    end

    def fetch_tournament_info(tourney_link)
      file_path = make_info_file_path(tourney_link)
      if File.exist?(file_path)
        puts "SKIP: Tournament info already exists for #{tourney_link}"
        return
      end

      sleep(1)
      url = "#{BASE_URL}#{tourney_link}"
      `curl -X GET "#{url}" > #{file_path}`
    end

    def process_tournament_info(link)
      res_file_path = make_response_file_path(link)
      if File.exist?(res_file_path)
        puts "SKIP: Tournament analysis already exists for #{link}"
        return
      end

      info_html = File.read(make_info_file_path(link))
      
      begin
        sleep(0.7)
        puts "Processing tournament info for #{link}"
        response = post_to_openai(info_html)
        File.write(res_file_path, response)
      rescue => e
        puts "Error processing tournament: #{e.message}"
      end
    end

    def make_info_file_path(tourney_link)
      filename = "pg#{tourney_link.gsub("/", "-")}.txt"
      File.join(@data_dir, filename)
    end

    def make_response_file_path(link)
      filename = "res-pg#{link.gsub("/", "-")}.json"
      File.join(@data_dir, filename)
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
      - shop_name
      - address
      - title
      - date
      - start_time
      - late_registration_time
      - entry_fee(integer)
      - reentry_fee(integer)
      - add_on(integer)
      - prize_list(list<integer>)
      - total_prize(integer)
      - prize_text(text)
      - guaranteed_amount:保証額(integer)
      - is_jopt_prize(boolean)
      - is_coin_prize(boolean)
      を抜き出してjsonで返してください
      ---
    PROMPT
  end
end
