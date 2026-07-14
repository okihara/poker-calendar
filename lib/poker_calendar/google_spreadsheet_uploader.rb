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

      # データ行が0件なら、既存シートをクリア・上書きしない（空データ事故で本番を消さない）
      data_rows = count_data_rows(csv_files)
      if data_rows.zero?
        raise "アップロード対象のデータ行が0件のため、スプレッドシートの上書きを中止しました。"
      end

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

    # 全CSVのデータ行数（各ファイルのヘッダー1行を除いた合計）
    def count_data_rows(csv_files)
      csv_files.select { |f| File.exist?(f) }.sum do |f|
        rows = CSV.read(f, encoding: 'UTF-8').size
        rows.positive? ? rows - 1 : 0
      end
    end

    # XML 1.0 で無効な制御文字を除去する
    # 許可されるのは Tab(0x09)/LF(0x0A)/CR(0x0D) と 0x20 以上の文字のみ
    def sanitize_cell(cell)
      return cell unless cell.is_a?(String)

      cell.gsub(/[^\u{9}\u{A}\u{D}\u{20}-\u{D7FF}\u{E000}-\u{FFFD}\u{10000}-\u{10FFFF}]/, '')
    end

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
            worksheet[current_row, col_index + 1] = sanitize_cell(cell)
          end
          current_row += 1
        end
      end

      log "Total rows uploaded: #{current_row - 1}"
    end
  end
end
