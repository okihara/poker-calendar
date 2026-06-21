require_relative '../lib/poker_calendar/tournament_scraper'
require_relative '../lib/poker_calendar/pokerfans_scraper'
require_relative '../lib/poker_calendar/tournament_analyzer'
require_relative '../lib/poker_calendar/tournament_parser'
require_relative '../lib/poker_calendar/google_spreadsheet_uploader'
require_relative '../lib/poker_calendar/data_cleaner'
require_relative '../config/settings'

include PokerCalendar

def generate_csv(date)
  date_str = date.strftime("%Y-%m-%d")
  output_file = File.join(Settings::DATA_DIR, "tourney_info_#{date_str}.csv")
  parser = TournamentParser.new(Settings::DATA_DIR)
  parser.parse_tournaments(date, output_file)
  output_file
end

def process_date(date, api_key)
  date_str = date.strftime("%Y-%m-%d")
  puts "Processing date: #{date_str}"

  # pokerguild スクレイピングの実行
  pg_scraper = TournamentScraper.new(Settings::DATA_DIR, date)
  pg_tournaments = pg_scraper.fetch_daily_tournaments
  pg_scraper.fetch_tournaments(pg_tournaments)

  # pokerfans スクレイピングは一時停止中（IPブロック対応）。
  # 再開する場合は以下のコメントを外す。
  # フェッチ間隔は Settings::POKERFANS_FETCH_INTERVAL で調整可能。
  # pf_scraper = PokerfansScraper.new(
  #   Settings::DATA_DIR,
  #   date,
  #   fetch_interval: Settings::POKERFANS_FETCH_INTERVAL
  # )
  # pf_events = pf_scraper.fetch_daily_tournaments
  # pf_scraper.fetch_tournaments(pf_events)

  # AI解析の実行（該当日付の全 .txt ファイルを処理）
  analyzer = TournamentAnalyzer.new(api_key, Settings::DATA_DIR)
  analyzer.process_tournaments(date)

  # CSVファイルの作成（該当日付の全 .json ファイルを処理）
  generate_csv(date)
end

def main
  # --csv-only: スクレイピング・AI解析を行わず、既存JSONからCSV生成とアップロードのみ実行
  csv_only = ARGV.include?('--csv-only')

  # 実行前にtest.logを削除
  File.delete('test.log') if File.exist?('test.log')

  today = Time.now
  yesterday = today - (24 * 60 * 60)  # 1日前
  tomorrow = today + (24 * 60 * 60)  # 1日後

  csv_files = []
  if csv_only
    [yesterday, today, tomorrow].each do |date|
      csv_files << generate_csv(date)
    end
  else
    api_key = File.read(".env").strip

    # 昨日はCSV作成のみ（スクレイピング・AI解析は処理済み）
    csv_files << generate_csv(yesterday)

    # 今日と明日はスクレイピングからフル処理
    [today, tomorrow].each do |date|
      csv_files << process_date(date, api_key)
    end
  end

  # Google Spreadsheetへのアップロード（複数CSVファイル）
  uploader = GoogleSpreadsheetUploader.new(Settings::CONFIG_PATH)
  uploader.upload_csv(csv_files, Settings::SPREADSHEET_KEY)

  # 古いデータのクリーンアップ（csv-only時はスキップ）
  unless csv_only
    cleaner = DataCleaner.new(Settings::DATA_DIR, Settings::DATA_RETENTION_DAYS)
    cleaner.clean
  end
end

main if __FILE__ == $0
