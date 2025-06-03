require 'spec_helper'

RSpec.describe 'Tournament Workflow Integration' do
  let(:container) { PokerCalendar::Container.new('test') }
  let(:date) { Time.new(2024, 1, 1) }

  before do
    allow(File).to receive(:exist?).with('.env').and_return(true)
    allow(File).to receive(:read).with('.env').and_return('test-token')
    
    stub_request(:get, "https://pokerguild.jp/?date=2024-01-01")
      .to_return(status: 200, body: daily_page_html)
    
    stub_request(:get, "https://pokerguild.jp/tourneys/123")
      .to_return(status: 200, body: tournament_page_html)
  end

  it 'processes tournaments end-to-end', :vcr do
    scraper = container.tournament_scraper
    parser = container.tournament_parser
    
    tournament_links = scraper.fetch_daily_tournaments(date)
    expect(tournament_links).to include('/tourneys/123')
    
    scraper.process_tournaments(tournament_links, date)
    
    output_file = File.join(container.settings.data_dir, "tourney_info_2024-01-01.csv")
    parser.parse_tournaments(tournament_links, output_file, date)
    
    expect(container.file_repository.exists?("tourney_info_2024-01-01.csv")).to be true
  end

  private

  def daily_page_html
    <<~HTML
      <html>
        <main>
          <a href="/tourneys/123">Tournament 1</a>
        </main>
      </html>
    HTML
  end

  def tournament_page_html
    <<~HTML
      <html>
        <body>
          <h1>Test Tournament</h1>
          <p>Shop: Test Poker Room</p>
          <p>Date: 2024-01-01</p>
        </body>
      </html>
    HTML
  end
end
