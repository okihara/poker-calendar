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

    # JOPT Games / JG Free / JGFR / JOPTゲームズ 等の表記ゆれ
    KEYWORD_PATTERN = /JOPT\s*Games|JOPT\s*ゲームズ|\bJG\s*(?:Free|フリー|FR\b)|\bJGFR\b/i
    RIGHTS_PATTERN = /(\d[\d,]*)\s*権利/
    RANK_PATTERN = /\d+\s*位|優勝|\d+\s*(?:st|nd|rd|th)\b/i

    # 換算した円を返す。該当する記載が無ければ0。
    # 順位ごとに書かれていれば合計し、そうでなければ（タイトルと本文に同じ総数が
    # 重ねて書かれることがあるため）最大の権利数を総額とみなす。
    def extract_yen(html)
      ranked = []
      others = []
      in_block = false

      lines(html).each do |line|
        next if line.empty?

        keyword = line.match?(KEYWORD_PATTERN)
        rank = line.match?(RANK_PATTERN)
        in_block = keyword || (in_block && rank)
        next unless in_block

        rights = line[RIGHTS_PATTERN, 1]&.delete(",")&.to_i
        next if rights.nil? || rights.zero?

        (rank ? ranked : others) << rights
      end

      total = ranked.empty? ? others.max.to_i : ranked.sum
      total * YEN_PER_RIGHT
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
