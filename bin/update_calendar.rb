require 'openai'
require_relative '../lib/poker_calendar/tournament_scraper'
require_relative '../lib/poker_calendar/pokerfans_scraper'
require_relative '../lib/poker_calendar/tournament_analyzer'
require_relative '../lib/poker_calendar/tournament_parser'
require_relative '../lib/poker_calendar/google_spreadsheet_uploader'
require_relative '../config/settings'

include PokerCalendar

def main
  # 実行前にtest.logを削除
  File.delete('test.log') if File.exist?('test.log')

  today = Time.now
  tomorrow = today + 24 * 60 * 60  # 明日
  target_dates = [today, tomorrow]

  openai_client = OpenAI::Client.new(access_token: File.read(".env").strip)
  analyzer = TournamentAnalyzer.new(openai_client, Settings::DATA_DIR)

  # 今日と明日の両方をスクレイピング・解析
  target_dates.each do |date|
    date_str = date.strftime("%Y-%m-%d")
    puts "Processing date: #{date_str}"

    # pokerguild スクレイピングの実行
    pg_scraper = TournamentScraper.new(Settings::DATA_DIR, date)
    pg_tournaments = pg_scraper.fetch_daily_tournaments
    pg_scraper.fetch_tournaments(pg_tournaments)

    # pokerfans スクレイピングの実行
    pf_scraper = PokerfansScraper.new(Settings::DATA_DIR, date)
    pf_events = pf_scraper.fetch_daily_tournaments
    pf_scraper.fetch_tournaments(pf_events)

    # AI解析の実行（該当日付の全 .txt ファイルを処理）
    analyzer.process_tournaments(date)
  end

  # CSVファイルの作成（今日と明日の全 .json ファイルを処理）
  output_file = File.join(Settings::DATA_DIR, "tourney_info_#{today.strftime("%Y-%m-%d")}.csv")
  parser = TournamentParser.new(Settings::DATA_DIR)
  parser.parse_tournaments_for_dates(target_dates, output_file)

  # Google Spreadsheetへのアップロード
  uploader = GoogleSpreadsheetUploader.new(Settings::CONFIG_PATH)
  uploader.upload_csv(output_file, Settings::SPREADSHEET_KEY)
end

main if __FILE__ == $0
