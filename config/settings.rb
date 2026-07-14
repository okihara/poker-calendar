module PokerCalendar
  module Settings
    SPREADSHEET_KEY = "17qhppvCNRnIX2wagimoAl6YHmaTaC0Re3ndwToletc0"
    CONFIG_PATH = "config.json"
    DATA_DIR = "./data"
    DATA_RETENTION_DAYS = 7

    # pokerfans の一覧ページを1ページ取得するごとに空ける間隔（秒）。
    # robots.txt により個別イベントページは取得しないため、1日あたりの
    # リクエストは一覧の数ページ分のみ。IPブロックを避けたい場合はこの値を大きくする。
    POKERFANS_FETCH_INTERVAL = 10
  end
end
