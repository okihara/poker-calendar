module PokerCalendar
  module Models
    class Tournament
      attr_reader :shop_name, :address, :area, :title, :date, :start_time,
                  :late_registration_time, :entry_fee, :reentry_fee, :add_on,
                  :prize_list, :total_prize, :prize_text, :guaranteed_amount,
                  :is_jopt_prize, :is_coin_prize, :link

      def initialize(data, link)
        @shop_name = data["shop_name"]
        @address = data["address"]
        @area = data["area"]
        @title = data["title"]
        @date = data["date"]
        @start_time = data["start_time"]
        @late_registration_time = data["late_registration_time"]
        @entry_fee = data["entry_fee"]
        @reentry_fee = data["reentry_fee"]
        @add_on = data["add_on"]
        @prize_list = data["prize_list"]
        @total_prize = data["total_prize"]
        @prize_text = data["prize_text"]
        @guaranteed_amount = data["guaranteed_amount"]
        @is_jopt_prize = data["is_jopt_prize"]
        @is_coin_prize = data["is_coin_prize"]
        @link = link
      end

      def valid?
        !@shop_name.nil? && !@shop_name.empty? &&
        !@date.nil? && !@date.empty?
      end

      def to_csv_row(index)
        [
          index + 1,
          @shop_name,
          @address,
          @area,
          @title,
          @date,
          format_time(@start_time),
          format_time(@late_registration_time) || format_time(@start_time),
          format_money(@entry_fee),
          format_money(@add_on),
          format_prize_list(@prize_list),
          format_money(@total_prize),
          format_money(@guaranteed_amount),
          @prize_text,
          "https://pokerguild.jp#{@link}",
        ]
      end

      private

      def format_time(time)
        return nil unless time
        return "" unless time.is_a?(String)
        time.scan(/\d{2}:\d{2}/)[0]
      end

      def format_money(value)
        return nil unless value
        value = value.to_s.gsub("円", "").gsub(",", "").gsub("\\", "").to_i
        return nil if value.zero? || value >= 5000000
        value
      end

      def format_prize_list(prize_list)
        prize_list && prize_list.compact.sum
      rescue
        nil
      end
    end
  end
end
