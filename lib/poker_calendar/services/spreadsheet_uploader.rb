require 'csv'
require_relative '../errors/poker_calendar_errors'

module PokerCalendar
  module Services
    class SpreadsheetUploader
      def initialize(google_drive_client:, file_repository:, logger:)
        @google_drive_client = google_drive_client
        @file_repository = file_repository
        @logger = logger
      end

      def upload_csv(csv_file, spreadsheet_key)
        @logger.info("Starting spreadsheet upload", csv_file: csv_file, spreadsheet_key: spreadsheet_key)
        
        csv_content = @file_repository.read(File.basename(csv_file))
        csv_data = CSV.parse(csv_content, encoding: 'UTF-8')
        
        @google_drive_client.upload_to_spreadsheet(csv_data, spreadsheet_key)
        
        @logger.info("Spreadsheet upload completed successfully")
      end
    end
  end
end
