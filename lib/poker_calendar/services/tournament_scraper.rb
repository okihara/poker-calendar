require_relative '../models/tournament'
require_relative '../parsers/html_parser'
require_relative '../parsers/ai_analyzer'
require_relative '../errors/poker_calendar_errors'

module PokerCalendar
  module Services
    class TournamentScraper
      def initialize(http_client:, file_repository:, ai_analyzer:, html_parser:, logger:, base_url:)
        @http_client = http_client
        @file_repository = file_repository
        @ai_analyzer = ai_analyzer
        @html_parser = html_parser
        @logger = logger
        @base_url = base_url
      end

      def fetch_daily_tournaments(date)
        date_str = date.strftime("%Y-%m-%d")
        daily_file = "pg-#{date_str}.html"
        
        @logger.info("Fetching daily tournaments", date: date_str)
        
        @file_repository.delete_if_exists('test.log')
        
        daily_url = "#{@base_url}/?date=#{date_str}"
        html_content = @http_client.get(daily_url)
        @file_repository.write(daily_file, html_content)
        
        tournament_links = @html_parser.extract_tournament_links(html_content)
        
        @logger.info("Found tournaments", count: tournament_links.size, date: date_str)
        tournament_links
      end

      def process_tournaments(tournament_links, date)
        @logger.info("Processing tournaments", count: tournament_links.size)
        
        tournament_links.each_with_index do |link, index|
          @logger.info("Processing tournament", 
                      index: index + 1, 
                      total: tournament_links.size, 
                      link: link)
          
          fetch_tournament_info(link, date)
          process_tournament_info(link, date)
        end
      end

      def make_response_file_path(tourney_link, date)
        filename = "res-#{make_info_file_name(tourney_link, date)}.json"
        filename
      end

      private

      def fetch_tournament_info(tourney_link, date)
        file_name = make_info_file_name(tourney_link, date)
        
        if @file_repository.exists?(file_name)
          @logger.info("Tournament info already exists", link: tourney_link)
          return
        end

        url = "#{@base_url}#{tourney_link}"
        html_content = @http_client.get(url)
        @file_repository.write(file_name, html_content)
      end

      def process_tournament_info(link, date)
        res_file_name = make_response_file_path(link, date)
        
        if @file_repository.exists?(res_file_name)
          @logger.info("Tournament analysis already exists", link: link)
          return
        end

        info_file_name = make_info_file_name(link, date)
        info_html = @file_repository.read(info_file_name)
        
        analysis_result = @ai_analyzer.analyze_tournament_html(info_html)
        @file_repository.write(res_file_name, analysis_result.to_json)
      end

      def make_info_file_name(tourney_link, date)
        date_str = date.strftime("%Y-%m-%d")
        "pg-#{date_str}-#{tourney_link.gsub("/", "-")}.txt"
      end
    end
  end
end
