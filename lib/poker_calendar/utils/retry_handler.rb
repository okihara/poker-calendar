module PokerCalendar
  module Utils
    class RetryHandler
      DEFAULT_RETRIES = 3
      DEFAULT_DELAY = 1.0
      DEFAULT_BACKOFF_MULTIPLIER = 2.0

      def self.with_retry(max_retries: DEFAULT_RETRIES, 
                         initial_delay: DEFAULT_DELAY,
                         backoff_multiplier: DEFAULT_BACKOFF_MULTIPLIER,
                         retryable_errors: [StandardError])
        retries = 0
        delay = initial_delay

        begin
          yield
        rescue *retryable_errors => e
          retries += 1
          
          if retries <= max_retries
            sleep(delay)
            delay *= backoff_multiplier
            retry
          else
            raise e
          end
        end
      end
    end
  end
end
