# encoding: utf-8

require 'nokogiri'

module PokerCalendar
  # スクレイピングしたHTMLから、LLM解析に不要なノイズ（スクリプト・装飾タグ・
  # class/style等の属性・空要素）を取り除く。タグ構造（見出し・表・リスト）は
  # 残してラベルと値の対応を保ちつつ、トークン数を大幅に削減する。
  module HtmlCleaner
    module_function

    # 丸ごと削除するノイズタグ（中身も含めて不要なもの）
    NOISE_TAGS = %w[
      script style svg img button i form noscript iframe link
      br hr input select textarea picture source video audio
    ].freeze

    # 中身が空（テキストを持たない）なら削除する入れ物タグ
    EMPTY_REMOVABLE_TAGS = %w[div span a p strong b em ul ol li].freeze

    def clean(html)
      frag = Nokogiri::HTML::DocumentFragment.parse(html)

      frag.css(NOISE_TAGS.join(', ')).each(&:remove)
      frag.xpath('.//comment()').each(&:remove)

      # 全要素から属性（class/style/id/data-* 等）を除去
      frag.traverse do |node|
        node.attribute_nodes.each(&:remove) if node.element?
      end

      remove_empty_nodes(frag)

      collapse_whitespace(frag.to_html)
    end

    # テキストを持たない入れ物タグを内側から削除する。削除により親が空になる
    # こともあるため、変化が無くなるまで繰り返す。
    def remove_empty_nodes(frag)
      loop do
        removed = false
        frag.css(EMPTY_REMOVABLE_TAGS.join(', ')).each do |node|
          if node.text.strip.empty?
            node.remove
            removed = true
          end
        end
        break unless removed
      end
    end

    def collapse_whitespace(text)
      text.gsub(/[ \t]*\n[ \t\n]*/, "\n").gsub(/[ \t]{2,}/, ' ').strip
    end
  end
end
