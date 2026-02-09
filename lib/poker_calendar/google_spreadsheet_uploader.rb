require 'google_drive'
require 'csv'
require_relative './loggable'

module PokerCalendar
  class GoogleSpreadsheetUploader
    include Loggable

    def initialize(config_path)
      @session = GoogleDrive::Session.from_service_account_key(config_path)
    end

    def upload_csv(csv_files, spreadsheet_key)
      csv_files = Array(csv_files)  # 単一ファイルでも配列でも対応
      log "Uploading #{csv_files.size} CSV file(s) to Google Spreadsheet..."
      begin
        spreadsheet = @session.spreadsheet_by_key(spreadsheet_key)
        worksheet = spreadsheet.worksheets.first

        clear_worksheet(worksheet)
        upload_multiple_data(worksheet, csv_files)

        worksheet.save
        log "CSV files uploaded to Google Spreadsheet successfully."
      rescue Google::Apis::AuthorizationError => e
        log "認証エラーが発生しました: #{e.message}"
        raise
      rescue Google::Apis::ServerError, Google::Apis::ClientError => e
        log "Google APIエラーが発生しました: #{e.message}"
        raise
      rescue StandardError => e
        log "予期せぬエラーが発生しました: #{e.message}"
        raise
      end
    end

    private

    def clear_worksheet(worksheet)
      worksheet.rows.each_with_index do |_, row_index|
        (1..worksheet.num_cols).each do |col_index|
          worksheet[row_index + 1, col_index] = ""
        end
      end
    end

    def upload_multiple_data(worksheet, csv_files)
      current_row = 1
      header_written = false

      csv_files.each do |csv_file|
        next unless File.exist?(csv_file)

        log "Processing: #{csv_file}"
        csv_data = CSV.read(csv_file, encoding: 'UTF-8')

        csv_data.each_with_index do |row, index|
          # ヘッダー行は最初のファイルのみ書き込む
          if index == 0
            if header_written
              next
            else
              header_written = true
            end
          end

          log "Uploading row #{current_row} #{row[3]} #{row[14]}"
          row.each_with_index do |cell, col_index|
            worksheet[current_row, col_index + 1] = cell
          end
          current_row += 1
        end
      end

      log "Total rows uploaded: #{current_row - 1}"
    end
  end
end
