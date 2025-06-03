require 'logger'
require 'json'

module PokerCalendar
  module Utils
    class StructuredLogger
      def initialize(output = STDOUT, level = Logger::INFO)
        @logger = Logger.new(output)
        @logger.level = level
        @logger.formatter = proc do |severity, datetime, progname, msg|
          log_entry = {
            timestamp: datetime.iso8601,
            level: severity,
            message: msg.is_a?(String) ? msg : msg.to_s,
            progname: progname
          }
          "#{log_entry.to_json}\n"
        end
      end

      def info(message, **metadata)
        log_with_metadata(:info, message, metadata)
      end

      def warn(message, **metadata)
        log_with_metadata(:warn, message, metadata)
      end

      def error(message, **metadata)
        log_with_metadata(:error, message, metadata)
      end

      def debug(message, **metadata)
        log_with_metadata(:debug, message, metadata)
      end

      private

      def log_with_metadata(level, message, metadata)
        if metadata.any?
          enhanced_message = {
            message: message,
            metadata: metadata
          }
          @logger.send(level, enhanced_message.to_json)
        else
          @logger.send(level, message)
        end
      end
    end
  end
end
