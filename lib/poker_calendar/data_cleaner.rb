# encoding: utf-8

require 'time'
require_relative './loggable'

module PokerCalendar
  class DataCleaner
    include Loggable

    DATE_PATTERN = /(\d{4}-\d{2}-\d{2})/

    def initialize(data_dir, retention_days)
      @data_dir = data_dir
      @retention_days = retention_days
    end

    def clean
      cutoff_date = Time.now - (@retention_days * 24 * 60 * 60)
      cutoff_str = cutoff_date.strftime("%Y-%m-%d")
      log "Cleaning data older than #{cutoff_str} (#{@retention_days} days retention)"

      deleted = 0
      Dir.glob(File.join(@data_dir, "*")).each do |file_path|
        next unless File.file?(file_path)

        date_str = File.basename(file_path)[DATE_PATTERN, 1]
        next unless date_str

        if date_str < cutoff_str
          File.delete(file_path)
          deleted += 1
        end
      end

      log "Deleted #{deleted} old files"
    end
  end
end
