require 'json'
require 'csv'
require_relative './loggable'

module PokerCalendar
  class TournamentParser
    include Loggable

    PG_BASE_URL = 'https://pokerguild.jp'.freeze
    PF_BASE_URL = 'https://pokerfans.jp'.freeze

    def initialize(data_dir)
      @data_dir = data_dir
    end

    def parse_tournaments(date, output_file)
      date_str = date.strftime("%Y-%m-%d")
      # res-pg-YYYY-MM-DD-*.json と res-pf-YYYY-MM-DD-*.json を対象
      res_files = Dir.glob(File.join(@data_dir, "res-*-#{date_str}-*.json"))
      log "Parsing #{res_files.size} response files for #{date_str}"

      CSV.open(output_file, "w", encoding: 'UTF-8') do |csv|
        write_header(csv)
        res_files.each_with_index do |res_file, index|
          process_tournament(csv, res_file, index)
        end
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

    def process_tournament(csv, res_file, index)
      tournament_data = JSON.parse(File.read(res_file, encoding: 'UTF-8'))
      reason = invalid_reason(tournament_data)
      if reason
        log "Skip: #{File.basename(res_file)} (#{reason})"
        return
      end

      write_tournament_data(csv, tournament_data, index, res_file)
    end

    def invalid_reason(data)
      return "missing shop_name or date" unless data["shop_name"] && data["date"]
      shop_name = data["shop_name"].to_s
      return "shop_name contains JOPT" if shop_name.include?("JOPT")
      return "shop_name contains ベルサール" if shop_name.include?("ベルサール")
      nil
    end

    def write_tournament_data(csv, data, index, res_file)
      csv << [
        index + 1,
        data["shop_name"],
        data["address"],
        data["area"],
        data["title"],
        data["date"],
        data["start_time"],
        data["late_registration_time"] || data["start_time"],
        format_money(data["entry_fee"]),
        format_money(data["add_on"]),
        format_prize_list(data["prize_list"]),
        format_money(data["total_prize"]),
        format_money(data["guaranteed_amount"]),
        data["prize_text"],
        make_tournament_link(res_file),
      ]
    end

    def make_tournament_link(res_file)
      basename = File.basename(res_file)
      # res-pg-2025-01-01-tourney-12345.txt.json -> pg, 12345
      # res-pf-2025-01-01-event-12345.txt.json -> pf, 12345
      if basename =~ /^res-(pg|pf)-\d{4}-\d{2}-\d{2}-(?:tourney|event)-(\d+)\.txt\.json$/
        source = $1
        id = $2
        case source
        when 'pg'
          "#{PG_BASE_URL}/tournament?no=#{id}"
        when 'pf'
          "#{PF_BASE_URL}/events/#{id}"
        else
          ""
        end
      else
        ""
      end
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
