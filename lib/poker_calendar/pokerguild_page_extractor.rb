# encoding: utf-8

require 'nokogiri'

module PokerCalendar
  # pokerguildのトーナメントページ上部の情報欄（主催・開催日・時刻・料金の表）から
  # 項目をHTMLで直接取り出す。AIは店名に本文中の会場名を拾ったり、参加費とスタートスタック
  # 「50,000点」を取り違えたりするため、ページに明記された値で上書きする用途に使う。
  #
  # サイトの見た目の変更に耐えるよう、class名やタグの入れ子には依存せず
  # 「見出し(th)のテキスト」と「その隣のセル(td)」、タイトルは最初のh1だけを見る。
  # 取れなかった項目は結果に含めず、呼び出し側でAIの値にフォールバックさせる。
  module PokerguildPageExtractor
    module_function

    FEE_LABELS = {
      "entry_fee" => "エントリ",
      "add_on" => "アドオン",
    }.freeze

    # 取れた項目だけを { "title" => "...", "entry_fee" => 15000, ... } の形で返す。
    # 日時はAIの出力と同じ "YYYY/MM/DD" / "YYYY/MM/DD HH:MM" 形式にそろえる。
    def extract(html)
      doc = Nokogiri::HTML::DocumentFragment.parse(html)
      fields = {}

      title = normalize(doc.at_css("h1")&.text)
      fields["title"] = title unless title.empty?

      shop_name = shop_name_for(doc)
      fields["shop_name"] = shop_name if shop_name

      date = parse_date(cell_text(doc, "開催日"))
      if date
        fields["date"] = date
        { "start_time" => "開始時間", "late_registration_time" => "受付締切" }.each do |field, label|
          time = parse_time(cell_text(doc, label))
          fields[field] = "#{date} #{time}" if time
        end
      end

      FEE_LABELS.each do |field, label|
        text = cell_text(doc, label)
        amount = text && parse_amount(text)
        fields[field] = amount unless amount.nil?
      end
      fields
    end

    # 主催が店舗ではなく大会（JOPT・EPT等、行に data-ownertype="event"）の場合は
    # 店名として使えないので取らない
    def shop_name_for(doc)
      th = find_th(doc, "主催")
      return nil if th.nil? || th.parent&.[]("data-ownertype") == "event"

      name = normalize(th.at_xpath("following-sibling::td[1]")&.text)
      name.empty? ? nil : name
    end

    # 詳細欄に店舗が書いた表が続くことがあるため、最初に現れる見出し（上部の情報欄）を使う
    def cell_text(doc, label)
      td = find_th(doc, label)&.at_xpath("following-sibling::td[1]")
      td && normalize(td.text)
    end

    def find_th(doc, label)
      doc.css("th").find { |node| normalize(node.text) == label }
    end

    # 「2026.10.24」→「2026/10/24」
    def parse_date(text)
      m = text.to_s.match(/\A(\d{4})[.\/-](\d{1,2})[.\/-](\d{1,2})/)
      m && format("%s/%02d/%02d", m[1], m[2].to_i, m[3].to_i)
    end

    # 「12:00」→「12:00」（深夜の「27:00」等もそのまま返し、日付の繰り上げは呼び出し側に任せる）
    def parse_time(text)
      m = text.to_s.match(/\A(\d{1,2}):(\d{2})/)
      m && format("%02d:%s", m[1].to_i, m[2])
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
