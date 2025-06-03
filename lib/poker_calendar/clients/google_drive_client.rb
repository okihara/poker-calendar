require 'google_drive'
require_relative '../errors/poker_calendar_errors'
require_relative '../utils/retry_handler'

module PokerCalendar
  module Clients
    class GoogleDriveClient
      def initialize(config_path:, logger:)
        @config_path = config_path
        @logger = logger
        @session = nil
      end

      def upload_to_spreadsheet(csv_data, spreadsheet_key)
        @logger.info("Uploading to Google Spreadsheet", spreadsheet_key: spreadsheet_key)
        
        Utils::RetryHandler.with_retry(
          max_retries: 3,
          retryable_errors: [Google::Apis::AuthorizationError, Google::Apis::ServerError, Google::Apis::ClientError]
        ) do
          session = get_session
          spreadsheet = session.spreadsheet_by_key(spreadsheet_key)
          worksheet = spreadsheet.worksheets.first

          clear_worksheet(worksheet)
          upload_data(worksheet, csv_data)
          
          worksheet.save
          @logger.info("Upload to Google Spreadsheet successful", spreadsheet_key: spreadsheet_key)
        end
      rescue Google::Apis::AuthorizationError => e
        @logger.error("Google Drive authentication failed", error: e.message)
        raise UploadError, "Google Drive authentication failed: #{e.message}"
      rescue Google::Apis::ServerError, Google::Apis::ClientError => e
        @logger.error("Google Drive API error", error: e.message)
        raise UploadError, "Google Drive API error: #{e.message}"
      rescue StandardError => e
        @logger.error("Unexpected error during upload", error: e.message)
        raise UploadError, "Unexpected error during upload: #{e.message}"
      end

      private

      def get_session
        @session ||= GoogleDrive::Session.from_service_account_key(@config_path)
      end

      def clear_worksheet(worksheet)
        worksheet.rows.each_with_index do |_, row_index|
          (1..worksheet.num_cols).each do |col_index|
            worksheet[row_index + 1, col_index] = ""
          end
        end
      end

      def upload_data(worksheet, csv_data)
        @logger.info("Uploading CSV data", rows: csv_data.count)

        csv_data.each_with_index do |row, row_index|
          @logger.debug("Uploading row", row_number: row_index + 1, shop_name: row[3])
          row.each_with_index do |cell, col_index|
            worksheet[row_index + 1, col_index + 1] = cell
          end
        end
      end
    end
  end
end
