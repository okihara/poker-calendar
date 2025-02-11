module PokerCalendar
  module Loggable
    private

    def log(message)
      puts "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] #{message}"
    end
  end
end
