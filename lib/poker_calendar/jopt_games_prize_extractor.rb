# encoding: utf-8

require 'nokogiri'

module PokerCalendar
  # JOPT Games Free Roll（JG Free 等）の推薦枠は「250権利」のように権利数で書かれる。
  # 1権利=1000円として扱えるので、ページ本文から権利数を拾って円に換算する。
  # 「ENPC1権利」「SPADIE権利」のような大会の参加権（金額換算できない）を拾わないよう、
  # JOPT Games を指す語と同じ行に書かれた権利数、またはその語の直後に続く順位行の権利数だけを見る。
  module JoptGamesPrizeExtractor
    module_function

    YEN_PER_RIGHT = 1000
    # 「JG Free Platinum：2権利」「JG Free Gold：5権利」の上位権利。公式の換算額は見つからず、
    # タイトルの「600k」「1,000K」と権利数の合計が一致する値を使っている。
    GOLD_YEN_PER_RIGHT = 10_000
    PLATINUM_YEN_PER_RIGHT = 100_000

    # JOPT Games / JG Free / JGFR / JOPTゲームズ 等の表記ゆれ
    KEYWORD_PATTERN = /JOPT\s*Games|JOPT\s*ゲームズ|\bJG\s*(?:Free|フリー|FR\b)|\bJGFR\b/i
    RIGHTS_PATTERN = /(\d[\d,]*)\s*権利/
    RANK_PATTERN = /\d+\s*位|優勝|\d+\s*(?:st|nd|rd|th)\b/i

    # 換算した円を返す。該当する記載が無ければ0。
    # 順位ごとに書かれていれば合計し、そうでなければ（タイトルと本文に同じ総数が
    # 重ねて書かれることがあるため）最大の権利数を総額とみなす。
    # 「1位」の見出し行の下に「活動支援」等を挟んで「JG Free 5権利」が続く書き方も多いため、
    # 順位の行が出た後の権利はすべて順位ごととして扱う。
    def extract_yen(html)
      ranked = []
      others = []
      in_block = false
      under_rank = false

      lines(html).each do |line|
        next if line.empty?

        keyword = line.match?(KEYWORD_PATTERN)
        rank = line.match?(RANK_PATTERN)
        in_block = keyword || (in_block && rank)
        under_rank ||= rank
        next unless in_block

        rights = line[RIGHTS_PATTERN, 1]&.delete(",")&.to_i
        next if rights.nil? || rights.zero?

        (under_rank ? ranked : others) << rights * yen_per_right(line)
      end

      ranked.empty? ? others.max.to_i : ranked.sum
    end

    def yen_per_right(line)
      case line
      when /Platinum|プラチナ/i then PLATINUM_YEN_PER_RIGHT
      when /Gold|ゴールド/i then GOLD_YEN_PER_RIGHT
      else YEN_PER_RIGHT
      end
    end

    # 全角数字・記号をそろえ、改行やブロック要素の区切りを行として残したテキストにする
    def lines(html)
      doc = Nokogiri::HTML::DocumentFragment.parse(html.to_s)
      doc.css("br").each { |node| node.replace("\n") }
      doc.css("p, div, li, tr, td, th, h1, h2, h3, h4").each { |node| node.add_next_sibling("\n") }
      doc.text.unicode_normalize(:nfkc).split("\n").map(&:strip)
    end
  end
end
