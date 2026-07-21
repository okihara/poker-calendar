require_relative '../lib/poker_calendar/tournament_scraper'
require_relative '../lib/poker_calendar/pokerfans_scraper'
require_relative '../lib/poker_calendar/tournament_analyzer'
require_relative '../lib/poker_calendar/tournament_parser'
require_relative '../lib/poker_calendar/google_spreadsheet_uploader'
require_relative '../lib/poker_calendar/vercel_blob_uploader'
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

  # pokerfans スクレイピングの実行。
  # robots.txt で /events/ が Disallow のため一覧ページのみ取得し、
  # 一覧に載っている情報だけをイベント情報として保存する。
  # 一覧の取得間隔は Settings::POKERFANS_FETCH_INTERVAL で調整可能。
  pf_scraper = PokerfansScraper.new(
    Settings::DATA_DIR,
    date,
    fetch_interval: Settings::POKERFANS_FETCH_INTERVAL
  )
  pf_events = pf_scraper.fetch_daily_tournaments
  pf_scraper.save_tournaments(pf_events)

  # AI解析の実行（該当日付の全 .txt ファイルを処理）
  analyzer = TournamentAnalyzer.new(api_key, Settings::DATA_DIR)
  analyzer.process_tournaments(date)

  # CSVファイルの作成（該当日付の全 .json ファイルを処理）
  generate_csv(date)
end

# スクレイプ済みtxtに対する解析(res)の充足率。閾値を下回る日があればアップロードを中止する。
# モデル未ロード等で解析が全滅→空データで本番を上書きする事故を防ぐ。
COVERAGE_THRESHOLD = 0.5

def analysis_coverage_ok?(date)
  date_str = date.strftime("%Y-%m-%d")
  txt = Dir.glob(File.join(Settings::DATA_DIR, "*-#{date_str}-*.txt")).size
  res = Dir.glob(File.join(Settings::DATA_DIR, "res-*-#{date_str}-*.json")).size
  return true if txt.zero?  # スクレイプ0件の日は判定対象外
  res.to_f / txt >= COVERAGE_THRESHOLD
end

def vercel_blob_token
  token = ENV["BLOB_READ_WRITE_TOKEN"].to_s.strip
  return token unless token.empty?
  return File.read(Settings::VERCEL_BLOB_TOKEN_PATH).strip if File.exist?(Settings::VERCEL_BLOB_TOKEN_PATH)

  nil
end

def upload_to_vercel_blob(csv_files)
  token = vercel_blob_token
  if token.nil? || token.empty?
    # 未設定でもスプレッドシート運用は継続できるよう、エラーにせずスキップする
    puts "Vercel Blobトークンが未設定のためスキップします" \
         "（環境変数 BLOB_READ_WRITE_TOKEN か #{Settings::VERCEL_BLOB_TOKEN_PATH} で設定）"
    return
  end

  blob_uploader = VercelBlobUploader.new(token)
  blob_uploader.upload_csv_as_json(csv_files, Settings::VERCEL_BLOB_PATHNAME)
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
    # ローカルLLM(LM Studio)はAPIキー不要。.envがあれば読む。
    api_key = File.exist?(".env") ? File.read(".env").strip : ""

    # 昨日はCSV作成のみ（スクレイピング・AI解析は処理済み）
    csv_files << generate_csv(yesterday)

    # 今日と明日はスクレイピングからフル処理
    [today, tomorrow].each do |date|
      csv_files << process_date(date, api_key)
    end
  end

  # フル処理した日の解析が著しく不足していればアップロードを中止する（空データ上書き防止）
  unless csv_only
    bad_dates = [today, tomorrow].reject { |date| analysis_coverage_ok?(date) }
    unless bad_dates.empty?
      dates = bad_dates.map { |d| d.strftime("%Y-%m-%d") }.join(", ")
      abort "AI解析結果が不足しているためアップロードを中止します（対象日: #{dates}）。" \
            "ローカルLLMのモデルがロードされているか確認してください。"
    end
  end

  # Google Spreadsheetへのアップロード（複数CSVファイル）
  # データ確認用としてBlob移行後も残す
  uploader = GoogleSpreadsheetUploader.new(Settings::CONFIG_PATH)
  uploader.upload_csv(csv_files, Settings::SPREADSHEET_KEY)

  # Vercel Blobへのアップロード（フロントエンドの読み込み元）
  upload_to_vercel_blob(csv_files)

  # 古いデータのクリーンアップ（csv-only時はスキップ）
  unless csv_only
    cleaner = DataCleaner.new(Settings::DATA_DIR, Settings::DATA_RETENTION_DAYS)
    cleaner.clean
  end
end

main if __FILE__ == $0
