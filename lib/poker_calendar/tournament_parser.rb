require 'json'
require 'csv'
require_relative './loggable'

module PokerCalendar
  class TournamentParser
    include Loggable

    def initialize(data_dir, scraper)
      @data_dir = data_dir
      @scraper = scraper
    end

    def parse_tournaments(tournament_links, output_file)
      CSV.open(output_file, "w", encoding: 'UTF-8') do |csv|
        write_header(csv)
        process_tournaments(csv, tournament_links)
      end
    end

    private

    def write_header(csv)
      csv << [
        "ID",
        "shop_name",
        "address",
        "area",
        "title",
        "date",
        "start_time",
        "late_registration_time",
        "entry_fee",
        "add_on",
        "prize_list",
        "total_prize",
        "guaranteed_amount",
        "prize_text",
        "link",
      ]
    end

    def process_tournaments(csv, tournament_links)
      tournament_links.each_with_index do |link, index|
        process_tournament(csv, link, index)
      end
    end

    def process_tournament(csv, link, index)
      res_file_name = @scraper.make_response_file_path(link)
      raise "error: res file not found: ##{res_file_name}" unless File.exist?(res_file_name)

      tournament_data = JSON.parse(File.read(res_file_name, encoding: 'UTF-8'))
      unless valid_tournament?(tournament_data)
        log "Invalid tournament data for #{link}"
        return
      end

      write_tournament_data(csv, tournament_data, index, link)
    end

    def valid_tournament?(data)
      data["shop_name"] && data["date"]
    end

    def write_tournament_data(csv, data, index, link)
      # log "#{index + 1} #{data["shop_name"]} #{data["title"]} #{link}"

      csv << [
        index + 1,
        data["shop_name"],
        data["address"],
        data["area"],
        data["title"],
        data["date"],
        format_time(data["start_time"]),
        format_time(data["late_registration_time"]) || format_time(data["start_time"]),
        format_money(data["entry_fee"]),
        format_money(data["add_on"]),
        format_prize_list(data["prize_list"]),
        format_money(data["total_prize"]),
        format_money(data["guaranteed_amount"]),
        data["prize_text"],
        "#{TournamentScraper::BASE_URL}#{link}",
      ]
    end

    def make_res_filename(link)
      "res-pg#{link.gsub("/", "-")}.json"
    end

    def format_time(time)
      return nil unless time
      return "" unless time.is_a?(String)
      time.scan(/\d{2}:\d{2}/)[0]
    end

    def format_money(value)
      return nil unless value
      value = value.to_s.gsub("円", "").gsub(",", "").gsub("\\", "").to_i
      return nil if value.zero? || value >= 5000000
      value
    end

    def format_prize_list(prize_list)
      prize_list && prize_list.compact.sum
    rescue
      nil
    end
  end
end
