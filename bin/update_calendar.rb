require_relative '../lib/poker_calendar/container'

def main
  container = PokerCalendar::Container.new
  today = Time.now
  
  # スクレイピングの実行
  scraper = container.tournament_scraper
  tournament_links = scraper.fetch_daily_tournaments(today)
  scraper.process_tournaments(tournament_links, today)

  # CSVファイルの作成
  output_file = File.join(container.settings.data_dir, "tourney_info_#{today.strftime("%Y-%m-%d")}.csv")
  parser = container.tournament_parser
  parser.parse_tournaments(tournament_links, output_file, today)

  # Google Spreadsheetへのアップロード
  uploader = container.spreadsheet_uploader
  uploader.upload_csv(output_file, container.settings.spreadsheet_key)
end

main if __FILE__ == $0
