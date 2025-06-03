require_relative '../errors/poker_calendar_errors'

module PokerCalendar
  module Parsers
    class HtmlParser
      def initialize(logger:)
        @logger = logger
      end

      def extract_tournament_links(html_content)
        @logger.debug("Extracting tournament links from HTML")
        
        main_content = html_content.scan(/<main>.*?<\/main>/m).join
        links = main_content.scan(/\/tourneys\/\d+/).uniq
        
        @logger.info("Extracted tournament links", count: links.size)
        links
      rescue => e
        @logger.error("Failed to extract tournament links", error: e.message)
        raise ParsingError, "Failed to extract tournament links: #{e.message}"
      end
    end
  end
end
