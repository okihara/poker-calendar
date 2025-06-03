require 'spec_helper'

RSpec.describe PokerCalendar::Parsers::HtmlParser do
  let(:logger) { instance_double(PokerCalendar::Utils::StructuredLogger) }
  let(:parser) { described_class.new(logger: logger) }

  before do
    allow(logger).to receive(:debug)
    allow(logger).to receive(:info)
    allow(logger).to receive(:error)
  end

  describe '#extract_tournament_links' do
    let(:html_content) do
      <<~HTML
        <html>
          <main>
            <a href="/tourneys/123">Tournament 1</a>
            <a href="/tourneys/456">Tournament 2</a>
            <a href="/other/789">Other Link</a>
          </main>
        </html>
      HTML
    end

    it 'extracts tournament links from HTML' do
      links = parser.extract_tournament_links(html_content)
      expect(links).to eq(['/tourneys/123', '/tourneys/456'])
    end

    it 'logs the extraction process' do
      expect(logger).to receive(:debug).with("Extracting tournament links from HTML")
      expect(logger).to receive(:info).with("Extracted tournament links", count: 2)
      parser.extract_tournament_links(html_content)
    end

    context 'when HTML parsing fails' do
      it 'raises ParsingError and logs error' do
        allow(html_content).to receive(:scan).and_raise(StandardError, "parsing failed")
        expect(logger).to receive(:error).with("Failed to extract tournament links", error: "parsing failed")
        expect { parser.extract_tournament_links(html_content) }.to raise_error(PokerCalendar::ParsingError)
      end
    end
  end
end
