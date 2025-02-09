require 'google_drive'
require 'csv'

module PokerCalendar
  class GoogleSpreadsheetUploader
    def initialize(config_path)
      @session = GoogleDrive::Session.from_service_account_key(config_path)
    end

    def upload_csv(csv_file, spreadsheet_key)
      puts "Uploading CSV file to Google Spreadsheet...#{csv_file}"
      spreadsheet = @session.spreadsheet_by_key(spreadsheet_key)
      worksheet = spreadsheet.worksheets.first

      clear_worksheet(worksheet)
      upload_data(worksheet, csv_file)
      
      worksheet.save
      puts "CSV file uploaded to Google Spreadsheet successfully."
    end

    private

    def clear_worksheet(worksheet)
      worksheet.rows.each_with_index do |_, row_index|
        (1..worksheet.num_cols).each do |col_index|
          worksheet[row_index + 1, col_index] = ""
        end
      end
    end

    def upload_data(worksheet, csv_file)
      csv_data = CSV.read(csv_file)
      puts "Total rows to upload: #{csv_data.count}"

      csv_data.each_with_index do |row, row_index|
        puts "Uploading row #{row_index + 1} #{row[3]}"
        row.each_with_index do |cell, col_index|
          worksheet[row_index + 1, col_index + 1] = cell
        end
      end
    end
  end
end
