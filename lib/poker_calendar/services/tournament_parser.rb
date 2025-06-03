require 'csv'
require 'json'
require_relative '../models/tournament'
require_relative '../errors/poker_calendar_errors'

module PokerCalendar
  module Services
    class TournamentParser
      CSV_HEADERS = [
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
      ].freeze

      def initialize(file_repository:, tournament_scraper:, logger:)
        @file_repository = file_repository
        @tournament_scraper = tournament_scraper
        @logger = logger
      end

      def parse_tournaments(tournament_links, output_file, date)
        @logger.info("Parsing tournaments to CSV", output_file: output_file)
        
        tournaments = load_tournaments(tournament_links, date)
        write_csv(tournaments, output_file)
        
        @logger.info("CSV parsing completed", 
                    tournaments_count: tournaments.size,
                    output_file: output_file)
      end

      private

      def load_tournaments(tournament_links, date)
        tournaments = []
        
        tournament_links.each_with_index do |link, index|
          begin
            tournament = load_tournament(link, index, date)
            tournaments << tournament if tournament&.valid?
          rescue => e
            @logger.error("Failed to load tournament", link: link, error: e.message)
          end
        end
        
        tournaments
      end

      def load_tournament(link, index, date)
        res_file_name = @tournament_scraper.make_response_file_path(link, date)
        
        unless @file_repository.exists?(res_file_name)
          @logger.warn("Response file not found", file: res_file_name)
          return nil
        end

        tournament_data_json = @file_repository.read(res_file_name)
        tournament_data = JSON.parse(tournament_data_json)
        
        Models::Tournament.new(tournament_data, link)
      rescue JSON::ParserError => e
        @logger.error("Invalid JSON in response file", file: res_file_name, error: e.message)
        nil
      end

      def write_csv(tournaments, output_file)
        csv_data = [CSV_HEADERS]
        
        tournaments.each_with_index do |tournament, index|
          csv_data << tournament.to_csv_row(index)
        end
        
        csv_content = CSV.generate(encoding: 'UTF-8') do |csv|
          csv_data.each { |row| csv << row }
        end
        
        @file_repository.write(File.basename(output_file), csv_content)
      end
    end
  end
end
