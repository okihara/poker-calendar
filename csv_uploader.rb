require 'google_drive'
require 'csv'

def upload_csv(csv_file)
  puts "Uploading CSV file to Google Spreadsheet...#{csv_file}"
  # Authenticate with Google Drive
  session = GoogleDrive::Session.from_service_account_key("config.json")

  # Open or create a spreadsheet
  spreadsheet = session.spreadsheet_by_key("17qhppvCNRnIX2wagimoAl6YHmaTaC0Re3ndwToletc0")

  # Select the first worksheet
  worksheet = spreadsheet.worksheets.first
  p worksheet

  # シート全体をクリア
  worksheet.rows.each_with_index do |_, row_index|
    (1..worksheet.num_cols).each do |col_index|
      worksheet[row_index + 1, col_index] = "" # 1行目・1列目からクリア
    end
  end

  # Read the CSV file
  csv_data = CSV.read(csv_file)
  puts csv_data.count

  # Upload the CSV data to the worksheet
  csv_data.each_with_index do |row, row_index|
    puts row_index
    row.each_with_index do |cell, col_index|
      worksheet[row_index + 1, col_index + 1] = cell
    end
  end

  # Save the changes
  worksheet.save

  puts "CSV file uploaded to Google Spreadsheet successfully."
end

if __FILE__ == $0
  csv_file = "./data/tourney_info_2025-01-17.csv"
  upload_csv(csv_file)
end
