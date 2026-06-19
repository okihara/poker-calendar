module PokerCalendar
  module Settings
    SPREADSHEET_KEY = "17qhppvCNRnIX2wagimoAl6YHmaTaC0Re3ndwToletc0"
    CONFIG_PATH = "config.json"
    DATA_DIR = "./data"
    DATA_RETENTION_DAYS = 7

    # pokerfans スクレイピングで各フェッチの間隔（秒）。
    # IPブロックを避けたい場合はこの値を大きくする。
    POKERFANS_FETCH_INTERVAL = 2
  end
end
