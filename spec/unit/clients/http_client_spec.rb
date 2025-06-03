require 'spec_helper'

RSpec.describe PokerCalendar::Clients::HttpClient do
  let(:logger) { instance_double(PokerCalendar::Utils::StructuredLogger) }
  let(:client) { described_class.new(logger: logger, request_delay: 0.1, max_retries: 1) }

  before do
    allow(logger).to receive(:info)
    allow(logger).to receive(:error)
  end

  describe '#get' do
    let(:url) { 'https://example.com/test' }

    context 'when request is successful' do
      before do
        stub_request(:get, url).to_return(status: 200, body: 'success')
      end

      it 'returns the response body' do
        expect(client.get(url)).to eq('success')
      end

      it 'logs the request' do
        expect(logger).to receive(:info).with("HTTP GET request", url: url)
        expect(logger).to receive(:info).with("HTTP GET success", url: url, status: "200")
        client.get(url)
      end
    end

    context 'when request fails' do
      before do
        stub_request(:get, url).to_return(status: 500)
      end

      it 'raises NetworkError' do
        expect { client.get(url) }.to raise_error(PokerCalendar::NetworkError)
      end

      it 'logs the error' do
        expect(logger).to receive(:error).with("HTTP GET failed", url: url, error: anything)
        expect { client.get(url) }.to raise_error(PokerCalendar::NetworkError)
      end
    end
  end
end
