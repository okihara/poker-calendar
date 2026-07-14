# encoding: utf-8

require 'cgi'
require 'time'
require_relative './loggable'

module PokerCalendar
  class PokerfansScraper
    include Loggable

    BASE_URL = 'https://pokerfans.jp'
    # 素の curl UA だとボット判定されIPブロックされやすいため、ブラウザ相当のUAを付ける
    USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'

    # pokerfans の robots.txt は User-agent: * に対して /events/ を Disallow している。
    # そのため個別イベントページは取得せず、許可されているトップページの一覧
    # （クエリ付きの "/"）だけを取得し、一覧の1件分のHTMLブロックをそのまま
    # イベント情報として保存する。取得できる項目は一覧に載っている範囲
    # （タイトル・店名・住所・開始/締切時刻・参加費・定員）に限られ、
    # 詳細ページにあったプライズ内訳は取得できない。

    # デフォルトの各フェッチ間隔（秒）。呼び出し側で上書き可能。
    DEFAULT_FETCH_INTERVAL = 2

    def initialize(data_dir, date, fetch_interval: DEFAULT_FETCH_INTERVAL)
      @data_dir = data_dir
      @date = date
      @date_str = date.strftime("%Y/%m/%d")
      @fetch_interval = fetch_interval
    end

    def fetch_daily_tournaments
      all_events = []
      page = 0

      while page <= 10
        log "Fetching pokerfans event list page #{page} for #{@date_str}"
        html_content = fetch_daily_page(page)
        events = extract_events(html_content)

        break if events.empty?

        all_events.concat(events)
        log "Found #{events.size} events on page #{page} (total: #{all_events.size})"

        break if events.size < 50  # 50件未満なら最後のページ

        page += 1
        sleep(@fetch_interval)
      end

      all_events.uniq { |e| e[:id] }
    end

    # 一覧から抜き出したブロックを保存する。個別ページへのアクセスは行わないため
    # ここでのHTTPリクエストは発生しない。
    def save_tournaments(events)
      log "Saving #{events.size} pokerfans events from the event list"
      events.each { |event| save_event_info(event) }
    end

    def make_info_file_path(event_id)
      filename = make_info_file_name(event_id)
      File.join(@data_dir, filename)
    end

    def make_response_file_path(event_id)
      filename = "res-#{make_info_file_name(event_id)}.json"
      File.join(@data_dir, filename)
    end

    private

    def fetch_daily_page(page = 0)
      url = "#{BASE_URL}/?startDate=#{@date_str}&weekly=false&prize=&clubId=&location=%E6%9D%B1%E4%BA%AC%E9%83%BD&withEndTime=false&applyEndTime=&size=50&page=#{page}"
      html = `curl -L --compressed -s -A "#{USER_AGENT}" -X GET "#{url}"`
      html.force_encoding('UTF-8')
    end

    def extract_events(html_content)
      # profile-event ブロックごとにイベントID・タイトル・ブロックHTMLを抽出
      events = []
      html_content.scan(/<div class="profile-event">(.*?)<\/div>\s*<\/div>\s*<\/div>/m).each do |match|
        block = match[0]
        id_match = block.match(/href="\/events\/(\d+)"/)
        title_match = block.match(/data-original-title="([^"]+)"/)
        next unless id_match

        events << {
          id: id_match[1],
          title: title_match ? CGI.unescapeHTML(title_match[1]) : '',
          html: block
        }
      end
      events.uniq { |e| e[:id] }
    end

    def save_event_info(event)
      event_id = event[:id]
      title = event[:title]

      # タイトルに「リング」または「ring」が含まれる場合はスキップ
      if title =~ /リング|ring/i
        log "SKIP: Ring game excluded - #{title}"
        return
      end

      # タイトルに「コイン」または「coin」が含まれていない場合はスキップ
      unless title =~ /コイン|coin|サテ|現金|協賛/i
        log "SKIP: No coin keyword - #{title}"
        return
      end

      file_path = make_info_file_path(event_id)
      if File.exist?(file_path)
        log "SKIP: Event info already exists for #{event_id}"
        return
      end

      File.write(file_path, build_event_section(event), encoding: 'UTF-8')
    end

    # 一覧のブロックから項目を取り出し、ラベル付きテキストに整形する。
    # 生のマークアップをそのままAIに渡すと定員やステータスラベル（Opening等）を
    # 賞金・アドオン額と誤読するため、必要な項目だけを明示的に組み立てる。
    def build_event_section(event)
      block = event[:html]
      start_time, deadline = extract_times(block)

      lines = ["タイトル: #{event[:title]}"]
      lines << "開催日: #{@date_str}"
      lines << "店舗: #{extract_venue(block)}"
      lines << "開始時刻: #{start_time}" if start_time
      lines << "レイトレジストレーション締切: #{deadline}" if deadline
      lines << "参加費: #{extract_fee(block)}"
      lines << "定員: #{extract_capacity(block)}"
      lines << "プライズ: 一覧に記載なし（タイトルに保証額等の記載があればそれを使う）"
      lines.join("\n") + "\n"
    end

    def extract_venue(block)
      match = block.match(/fa-home[^>]*><\/span>\s*<span>(.*?)<\/span>/m)
      match ? CGI.unescapeHTML(match[1].strip) : ''
    end

    # 一覧の日時表記は当日なら「今日(Tue) 21:00 (Deadline22:30)」、
    # それ以外は「7月16日(Thu) 21:00 (Deadline22:30)」。
    # 締切が開始時刻より前の場合は日をまたいでいるので翌日として扱う。
    def extract_times(block)
      match = block.match(/fa-clock-o[^>]*><\/i>\s*<strong[^>]*>(.*?)<\/strong>/m)
      return [nil, nil] unless match

      text = match[1]
      start_match = text.match(/(\d{1,2}):(\d{2})/)
      return [nil, nil] unless start_match

      start_at = Time.new(@date.year, @date.month, @date.day, start_match[1].to_i, start_match[2].to_i)
      deadline_match = text.match(/Deadline\s*(\d{1,2}):(\d{2})/)
      return [format_time(start_at), nil] unless deadline_match

      deadline_at = Time.new(@date.year, @date.month, @date.day, deadline_match[1].to_i, deadline_match[2].to_i)
      deadline_at += 24 * 60 * 60 if deadline_at < start_at

      [format_time(start_at), format_time(deadline_at)]
    end

    def format_time(time)
      time.strftime("%Y/%m/%d %H:%M")
    end

    # 「3,100(E)」「1,500(R/A/E)」「Free」等。括弧内の記号は Entry/Rebuy/Add-on の
    # 有無を示すだけで金額ではないため、金額部分だけを渡す。
    def extract_fee(block)
      match = block.match(/ion-social-yen-outline.*?<span>(.*?)<\/span>/m)
      return '不明' unless match

      fee = match[1].strip
      return '0円（無料）' if fee =~ /free/i

      amount = fee[/[\d,]+/]
      amount ? "#{amount}円" : fee
    end

    def extract_capacity(block)
      match = block.match(/icon-users.*?<span>\s*(\d+)\s*\/\s*<\/span>\s*<span>\s*(\d+)\s*<\/span>/m)
      return '不明' unless match

      "#{match[2]}人（現在のエントリー数 #{match[1]}人。これは定員であり賞金額ではない）"
    end

    def make_info_file_name(event_id)
      date_str = @date.strftime("%Y-%m-%d")
      "pf-#{date_str}-event-#{event_id}.txt"
    end
  end
end

if __FILE__ == $0
  require_relative '../../config/settings'

  date = ARGV[0] ? Time.parse(ARGV[0]) : Time.now
  scraper = PokerCalendar::PokerfansScraper.new(
    PokerCalendar::Settings::DATA_DIR,
    date,
    fetch_interval: PokerCalendar::Settings::POKERFANS_FETCH_INTERVAL
  )

  puts "Fetching pokerfans events for #{date.strftime('%Y-%m-%d')}..."
  events = scraper.fetch_daily_tournaments
  puts "Found #{events.size} events"

  scraper.save_tournaments(events)
  puts "Done."
end
