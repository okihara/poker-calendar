require 'openai'
require_relative '../lib/poker_calendar/tournament_scraper'
require_relative '../lib/poker_calendar/tournament_parser'
require_relative '../lib/poker_calendar/google_spreadsheet_uploader'
require_relative '../config/settings'

include PokerCalendar

def main
  today = Time.now
  openai_client = OpenAI::Client.new(access_token: File.read(".env").strip)

  # スクレイピングの実行
  scraper = TournamentScraper.new(openai_client, Settings::DATA_DIR)
  tournament_links = scraper.fetch_daily_tournaments(today)
  scraper.process_tournaments(tournament_links)

  # CSVファイルの作成
  output_file = File.join(Settings::DATA_DIR, "tourney_info_#{today.strftime("%Y-%m-%d")}.csv")
  parser = TournamentParser.new(Settings::DATA_DIR)
  parser.parse_tournaments(tournament_links, output_file)

  # Google Spreadsheetへのアップロード
  uploader = GoogleSpreadsheetUploader.new(Settings::CONFIG_PATH)
  uploader.upload_csv(output_file, Settings::SPREADSHEET_KEY)
end

main if __FILE__ == $0
