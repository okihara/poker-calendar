require 'json'
require 'csv'
require 'time'
require_relative './loggable'

module PokerCalendar
  class TournamentParser
    include Loggable

    PG_BASE_URL = 'https://pokerguild.jp'.freeze
    PF_BASE_URL = 'https://pokerfans.jp'.freeze

    # AIが返すareaは誤判定がある（新橋の店が新宿になる等）ため、
    # 住所・店名にエリア名が含まれていればそちらを優先する。
    # 部分一致で判定するので、紛らわしいもの（浅草橋 vs 浅草）は先に置く。
    AREA_RULES = [
      ['浅草橋', '浅草橋'],
      ['歌舞伎町', '新宿'],
      ['新宿', '新宿'],
      ['新橋', '新橋'],
      ['渋谷', '渋谷'],
      ['六本木', '六本木'],
      ['西麻布', '西麻布'],
      ['赤坂', '赤坂'],
      ['秋葉原', '秋葉原'],
      ['上野', '上野'],
      ['湯島', '湯島'],
      ['池袋', '池袋'],
      ['銀座', '銀座'],
      ['五反田', '五反田'],
      ['恵比寿', '恵比寿'],
      ['人形町', '人形町'],
      ['浅草', '浅草'],
      ['蒲田', '蒲田'],
      ['大森', '大森'],
      ['目黒', '目黒'],
      ['下北沢', '下北沢'],
      ['中野', '中野'],
      ['練馬', '練馬'],
      ['吉祥寺', '吉祥寺'],
      ['金町', '金町'],
      ['葛西', '葛西'],
      ['国分寺', '国分寺'],
      ['立川', '立川'],
      ['八王子', '八王子'],
      ['町田', '町田'],
      ['宇都宮', '宇都宮'],
      ['名古屋', '名古屋'],
      ['京都', '京都'],
      ['大阪', '大阪'],
      ['金沢', '金沢'],
    ].freeze

    def initialize(data_dir)
      @data_dir = data_dir
    end

    def parse_tournaments(date, output_file)
      date_str = date.strftime("%Y-%m-%d")
      # res-pg-YYYY-MM-DD-*.json と res-pf-YYYY-MM-DD-*.json を対象
      res_files = Dir.glob(File.join(@data_dir, "res-*-#{date_str}-*.json")).sort
      log "Parsing #{res_files.size} response files for #{date_str}"

      tournaments = res_files.filter_map { |res_file| load_tournament(res_file) }
      tournaments = dedupe_tournaments(tournaments)

      CSV.open(output_file, "w", encoding: 'UTF-8') do |csv|
        write_header(csv)
        tournaments.each_with_index do |tournament, index|
          write_tournament_data(csv, tournament[:data], index, tournament[:res_file])
        end
      end
    end

    private

    def write_header(csv)
      csv << [
        "ID",
        "shop_name",
        "address",
        "area",
        "title",
        "date",
        "start_time",
        "late_registration_time",
        "entry_fee",
        "add_on",
        "prize_list",
        "total_prize",
        "guaranteed_amount",
        "prize_text",
        "link",
      ]
    end

    def load_tournament(res_file)
      tournament_data = JSON.parse(File.read(res_file, encoding: 'UTF-8'))
      reason = invalid_reason(tournament_data)
      if reason
        log "Skip: #{File.basename(res_file)} (#{reason})"
        return nil
      end

      { data: tournament_data, res_file: res_file }
    end

    # 同じイベントがpokerguildとpokerfansの両方に登録されていることがあるため、
    # 「店名（表記ゆれを正規化）+ 開始日時」が一致し、かつタイトルが十分似ている行は
    # 同一イベントとみなし、情報量（埋まっているフィールド数）が多い方を残す。
    def dedupe_tournaments(tournaments)
      tournaments.group_by { |t| dedupe_key(t[:data]) }.flat_map do |key, group|
        next group if key.nil? || group.size == 1

        dedupe_group(group)
      end
    end

    # 同じ店・同じ開始時刻でも別イベントのことがある（リーグ戦の同時開催など）ため、
    # タイトルが似ているものだけをまとめる
    def dedupe_group(group)
      clusters = []
      group.each do |t|
        cluster = clusters.find { |c| same_title?(c.first[:data], t[:data]) }
        cluster ? cluster << t : clusters << [t]
      end

      clusters.map do |cluster|
        best = cluster.max_by { |t| completeness_score(t[:data]) }
        (cluster - [best]).each do |t|
          log "Duplicate dropped: #{File.basename(t[:res_file])} " \
              "(#{t[:data]['shop_name']} #{t[:data]['start_time']}) " \
              "-> kept #{File.basename(best[:res_file])}"
        end
        best
      end
    end

    # 店名・開始日時が欠けている場合はnilを返し、重複排除の対象外とする
    def dedupe_key(data)
      shop = normalize_shop_name(data["shop_name"])
      start_time = data["start_time"].to_s.strip
      return nil if shop.empty? || start_time.empty?

      [shop, start_time]
    end

    # 全角英数字→半角、空白除去、小文字化してソース間の表記ゆれを吸収する
    def normalize_shop_name(name)
      name.to_s
          .tr("０-９Ａ-Ｚａ-ｚ", "0-9A-Za-z")
          .gsub(/[[:space:]]/, "")
          .downcase
    end

    TITLE_SIMILARITY_THRESHOLD = 0.5

    def same_title?(a, b)
      ta = normalize_title(a["title"])
      tb = normalize_title(b["title"])
      # タイトル不明の場合は店名・開始時刻の一致を信用してまとめる
      return true if ta.empty? || tb.empty?

      bigram_similarity(ta, tb) >= TITLE_SIMILARITY_THRESHOLD
    end

    # 記号・空白を除去して文字種を揃える（「50,000保証」と「50000保証」を一致させる）
    def normalize_title(title)
      title.to_s
           .tr("０-９Ａ-Ｚａ-ｚ", "0-9A-Za-z")
           .downcase
           .gsub(/[^[:alnum:]]/, "")
    end

    # 文字バイグラムのDice係数（0.0〜1.0）
    def bigram_similarity(a, b)
      return a == b ? 1.0 : 0.0 if a.size < 2 || b.size < 2

      bigrams_a = a.chars.each_cons(2).map(&:join).uniq
      bigrams_b = b.chars.each_cons(2).map(&:join).uniq
      2.0 * (bigrams_a & bigrams_b).size / (bigrams_a.size + bigrams_b.size)
    end

    def completeness_score(data)
      %w[address title late_registration_time entry_fee add_on
         prize_list total_prize guaranteed_amount prize_text].count do |field|
        value = data[field]
        value.respond_to?(:empty?) ? !value.empty? : !value.nil?
      end
    end

    def invalid_reason(data)
      return "missing shop_name or date" unless data["shop_name"] && data["date"]
      shop_name = data["shop_name"].to_s
      return "shop_name contains JOPT" if shop_name.include?("JOPT")
      return "shop_name contains ベルサール" if shop_name.include?("ベルサール")
      nil
    end

    def write_tournament_data(csv, data, index, res_file)
      title = data["title"].to_s
      has_saidai = title.include?("最大")

      late_time = fix_late_registration_time(data["start_time"], data["late_registration_time"])
      area = normalize_area(data)
      if area != data["area"]
        log "Area corrected: #{data['shop_name']} (#{data['area']} -> #{area})"
      end

      csv << [
        index + 1,
        data["shop_name"],
        data["address"],
        area,
        data["title"],
        data["date"],
        data["start_time"],
        late_time,
        format_money(data["entry_fee"]),
        format_money(data["add_on"]),
        has_saidai ? 0 : format_prize_list(data["prize_list"]),
        has_saidai ? 0 : format_money(data["total_prize"]),
        format_money(data["guaranteed_amount"]),
        has_saidai ? 0 : data["prize_text"],
        make_tournament_link(res_file),
      ]
    end

    # 住所→店名の順でエリア名を探し、見つかればAIのareaより優先する
    def normalize_area(data)
      [data["address"], data["shop_name"]].each do |text|
        next if text.nil? || text.empty?
        # 「東京都」が「京都」に部分一致してしまうので先に除去
        text = text.to_s.gsub("東京都", "")
        AREA_RULES.each do |keyword, area|
          return area if text.include?(keyword)
        end
      end
      data["area"]
    end

    def fix_late_registration_time(start_time_str, late_time_str)
      return start_time_str unless late_time_str && !late_time_str.empty?

      begin
        start_time = Time.strptime(start_time_str, "%Y/%m/%d %H:%M")
        late_time = Time.strptime(late_time_str, "%Y/%m/%d %H:%M")
      rescue ArgumentError, TypeError
        return start_time_str
      end

      return late_time_str if late_time >= start_time

      # 開始が18時以降でレイトが6時以前 → 翌日の深夜イベント
      if start_time.hour >= 18 && late_time.hour <= 6
        next_day = late_time + 86400
        return next_day.strftime("%Y/%m/%d %H:%M")
      end

      # それ以外の逆転 → 開始時間にフォールバック
      start_time_str
    end

    def make_tournament_link(res_file)
      basename = File.basename(res_file)
      # res-pg-2025-01-01-tourney-12345.txt.json -> pg, 12345
      # res-pf-2025-01-01-event-12345.txt.json -> pf, 12345
      if basename =~ /^res-(pg|pf)-\d{4}-\d{2}-\d{2}-(?:tourney|event)-(\d+)\.txt\.json$/
        source = $1
        id = $2
        case source
        when 'pg'
          "#{PG_BASE_URL}/tournament?no=#{id}"
        when 'pf'
          "#{PF_BASE_URL}/events/#{id}"
        else
          ""
        end
      else
        ""
      end
    end

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
