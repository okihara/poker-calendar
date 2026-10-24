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

    # 絵文字・記号類。qwen等のローカルLLMがこれらのトークン境界で生成を暴走させ
    # （縮退した繰り返しループに陥り）、JSONを閉じないまま不完全な結果を吐くことがある。
    # タイトル等では装飾が主目的で、除去しても抽出情報は欠けないため、LLMに渡す前に落とす。
    # 対象: 主要な絵文字/象形記号・各種シンボル・囲み記号・異体字セレクタ/ZWJ/キーキャップ。
    EMOJI_PATTERN = /[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{2300}-\u{23FF}\u{FE00}-\u{FE0F}\u{200D}\u{20E3}]/

    # 制御文字（タブ・改行以外）。暴走生成の産物（ 等）が入力に紛れ込むのを防ぐ保険。
    CONTROL_PATTERN = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/

    def clean(html)
      frag = Nokogiri::HTML::DocumentFragment.parse(html)

      frag.css(NOISE_TAGS.join(', ')).each(&:remove)
      frag.xpath('.//comment()').each(&:remove)

      # 全要素から属性（class/style/id/data-* 等）を除去
      frag.traverse do |node|
        node.attribute_nodes.each(&:remove) if node.element?
      end

      remove_empty_nodes(frag)

      collapse_whitespace(strip_symbols(frag.to_html))
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

    # LLMの暴走を誘発しうる絵文字と、暴走の産物である制御文字を除去する。
    def strip_symbols(text)
      text.gsub(EMOJI_PATTERN, '').gsub(CONTROL_PATTERN, '')
    end

    def collapse_whitespace(text)
      text.gsub(/[ \t]*\n[ \t\n]*/, "\n").gsub(/[ \t]{2,}/, ' ').strip
    end
  end
end
