# encoding: utf-8

require 'time'
require_relative './loggable'

module PokerCalendar
  class TournamentScraper
    include Loggable

    BASE_URL = 'https://pokerguild.jp'

    def initialize(data_dir, date)
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

    def fetch_tournaments(tournament_links)
      log "Fetching #{tournament_links.size} tournaments"
      tournament_links.each_with_index do |link, index|
        log "Fetching tournament #{index + 1}/#{tournament_links.size}: #{link}"
        fetch_tournament_info(link)
      end
    end

    def make_info_file_path(tourney_link)
      filename = make_info_file_name(tourney_link)
      File.join(@data_dir, filename)
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
      # 新しいサイト構造: data-no 属性からトーナメントIDを抽出
      html_content.scan(/class="list_item"[^>]*data-no="(\d+)"/)
                 .flatten
                 .uniq
    end

    def fetch_tournament_info(tourney_no)
      file_path = make_info_file_path(tourney_no)
      if File.exist?(file_path)
        log "SKIP: Tournament info already exists for #{tourney_no}"
        return
      end

      sleep(1)
      # 新しいサイト構造: POST リクエストで個別ページを取得
      html = `curl -L --compressed -s -X POST "#{BASE_URL}/tournament" -d "no=#{tourney_no}"`
      # トーナメント情報部分のみ抽出して保存
      tournament_section = extract_tournament_section(html)
      File.write(file_path, tournament_section, encoding: 'UTF-8')
    end

    def extract_tournament_section(html)
      html = html.force_encoding('UTF-8')
      match = html.match(/<div id="scn_tournament_page".*?<\/article>/m)
      match ? match[0] : html
    end

    def make_info_file_name(tourney_no)
      "pg-#{@date_str}-tourney-#{tourney_no}.txt"
    end
  end
end

if __FILE__ == $0
  require_relative '../../config/settings'

  date = ARGV[0] ? Time.parse(ARGV[0]) : Time.now
  scraper = PokerCalendar::TournamentScraper.new(PokerCalendar::Settings::DATA_DIR, date)

  puts "Fetching tournaments for #{date.strftime('%Y-%m-%d')}..."
  tournament_links = scraper.fetch_daily_tournaments
  puts "Found #{tournament_links.size} tournaments"

  scraper.fetch_tournaments(tournament_links)
  puts "Done."
end
