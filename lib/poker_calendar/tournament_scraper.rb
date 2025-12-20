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

    def make_info_file_name(tourney_link)
      "pg-#{@date_str}-#{tourney_link.gsub("/", "-")}.txt"
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
