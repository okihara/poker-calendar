module PokerCalendar
  class PokerCalendarError < StandardError; end
  
  class ConfigurationError < PokerCalendarError; end
  class ScrapingError < PokerCalendarError; end
  class ParsingError < PokerCalendarError; end
  class UploadError < PokerCalendarError; end
  class NetworkError < PokerCalendarError; end
  class ValidationError < PokerCalendarError; end
end
