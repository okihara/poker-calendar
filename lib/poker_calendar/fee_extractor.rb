# encoding: utf-8

require 'nokogiri'

module PokerCalendar
  # pokerguildのトーナメントページから参加費・アドオン費をHTMLから直接取り出す。
  # AIはスタートスタック「50,000点」を参加費と取り違えることがあるため、
  # ページに明記された金額で上書きする用途に使う。
  #
  # サイトの見た目の変更に耐えるよう、class名やタグの入れ子には依存せず
  # 「見出し(th)のテキスト」と「その隣のセル(td)の最初の◯円」だけを見る。
  # 取れなかった項目はnilを返し、呼び出し側でAIの値にフォールバックさせる。
  module FeeExtractor
    module_function

    FIELD_LABELS = {
      "entry_fee" => "エントリ",
      "add_on" => "アドオン",
    }.freeze

    # 取れた項目だけを { "entry_fee" => 15000, ... } の形で返す
    def extract(html)
      doc = Nokogiri::HTML::DocumentFragment.parse(html)
      FIELD_LABELS.each_with_object({}) do |(field, label), fees|
        amount = amount_for(doc, label)
        fees[field] = amount unless amount.nil?
      end
    end

    # 詳細欄に店舗が書いた表が続くことがあるため、最初に現れる見出し（上部の情報欄）を使う
    def amount_for(doc, label)
      th = doc.css("th").find { |node| normalize(node.text) == label }
      td = th&.at_xpath("following-sibling::td[1]")
      return nil unless td

      parse_amount(normalize(td.text))
    end

    # 「15,000円 50,000点 早割…」のように金額・スタック・注記が並ぶので、先頭の金額だけを見る
    def parse_amount(text)
      return 0 if text.start_with?("無料")

      yen = text[/\A([\d,]+)\s*円/, 1] || text[/\A[¥￥]\s*([\d,]+)/, 1]
      yen&.delete(",")&.to_i
    end

    def normalize(text)
      text.to_s.gsub(/[[:space:]]+/, " ").strip
    end
  end
end
