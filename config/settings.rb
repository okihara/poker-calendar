module PokerCalendar
  module Settings
    SPREADSHEET_KEY = "17qhppvCNRnIX2wagimoAl6YHmaTaC0Re3ndwToletc0"
    CONFIG_PATH = "config.json"

    # Vercel Blob 連携。トークンは環境変数 BLOB_READ_WRITE_TOKEN か、
    # このファイルパスに置いたトークン文字列のどちらかで渡す（ファイルはgitignore済み）
    VERCEL_BLOB_TOKEN_PATH = ".vercel_blob_token"
    VERCEL_BLOB_PATHNAME = "tournaments.json"
    DATA_DIR = "./data"
    DATA_RETENTION_DAYS = 7

    # pokerfans の一覧ページを1ページ取得するごとに空ける間隔（秒）。
    # robots.txt により個別イベントページは取得しないため、1日あたりの
    # リクエストは一覧の数ページ分のみ。IPブロックを避けたい場合はこの値を大きくする。
    POKERFANS_FETCH_INTERVAL = 10
  end
end
