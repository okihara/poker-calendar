require 'spec_helper'

RSpec.describe PokerCalendar::Models::Tournament do
  let(:tournament_data) do
    {
      "shop_name" => "Test Poker Room",
      "address" => "Tokyo, Japan",
      "area" => "渋谷",
      "title" => "Daily Tournament",
      "date" => "2024-01-01",
      "start_time" => "19:00",
      "late_registration_time" => "20:00",
      "entry_fee" => 5000,
      "reentry_fee" => 3000,
      "add_on" => 2000,
      "prize_list" => [10000, 5000, 3000],
      "total_prize" => 18000,
      "prize_text" => "1st: 10,000円",
      "guaranteed_amount" => 20000,
      "is_jopt_prize" => false,
      "is_coin_prize" => true
    }
  end
  let(:link) { "/tourneys/123" }
  let(:tournament) { described_class.new(tournament_data, link) }

  describe '#valid?' do
    it 'returns true when shop_name and date are present' do
      expect(tournament.valid?).to be true
    end

    it 'returns false when shop_name is missing' do
      tournament_data["shop_name"] = nil
      expect(tournament.valid?).to be false
    end

    it 'returns false when date is missing' do
      tournament_data["date"] = ""
      expect(tournament.valid?).to be false
    end
  end

  describe '#to_csv_row' do
    it 'returns properly formatted CSV row' do
      row = tournament.to_csv_row(0)
      expect(row[0]).to eq(1) # ID
      expect(row[1]).to eq("Test Poker Room") # shop_name
      expect(row[2]).to eq("Tokyo, Japan") # address
      expect(row[14]).to eq("https://pokerguild.jp/tourneys/123") # link
    end

    it 'formats time correctly' do
      row = tournament.to_csv_row(0)
      expect(row[6]).to eq("19:00") # start_time
      expect(row[7]).to eq("20:00") # late_registration_time
    end

    it 'formats money correctly' do
      row = tournament.to_csv_row(0)
      expect(row[8]).to eq(5000) # entry_fee
      expect(row[9]).to eq(2000) # add_on
    end
  end
end
