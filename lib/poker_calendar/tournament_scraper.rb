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
      @date_param = date.strftime("%Y%m%d")  # API用パラメータ（ハイフンなし）
    end

    def fetch_daily_tournaments
      all_tournament_ids = []
      page = 1

      while page <= 10
        log "Fetching daily tournament list page #{page} for #{@date_str}"
        html_content = fetch_daily_page(page)
        tournament_ids = extract_tournament_links(html_content)

        break if tournament_ids.empty?

        all_tournament_ids.concat(tournament_ids)
        log "Found #{tournament_ids.size} tournaments on page #{page} (total: #{all_tournament_ids.size})"

        break if tournament_ids.size < 40  # 40件未満なら最後のページ

        page += 1
        sleep(1)
      end

      all_tournament_ids.uniq
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

    def fetch_daily_page(page = 1)
      html = if page == 1
        `curl -L --compressed -s -X GET "#{BASE_URL}/?d=#{@date_param}"`
      else
        `curl -L --compressed -s -X POST "#{BASE_URL}/" -d "d=#{@date_param}&p=#{page}"`
      end
      html.force_encoding('UTF-8')
    end

    def extract_tournament_links(html_content)
      # サイト構造: data-itemkey 属性からトーナメントIDを抽出
      html_content.scan(/class="list_item"[^>]*data-itemkey="(\d+)"/)
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
