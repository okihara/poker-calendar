# encoding: utf-8

require 'time'
require_relative './loggable'

module PokerCalendar
  class PokerfansScraper
    include Loggable

    BASE_URL = 'https://pokerfans.jp'

    def initialize(data_dir, date)
      @data_dir = data_dir
      @date = date
      @date_str = date.strftime("%Y/%m/%d")
    end

    def fetch_daily_tournaments
      all_events = []
      page = 0

      while page <= 10
        log "Fetching pokerfans event list page #{page} for #{@date_str}"
        html_content = fetch_daily_page(page)
        events = extract_event_ids(html_content)

        break if events.empty?

        all_events.concat(events)
        log "Found #{events.size} events on page #{page} (total: #{all_events.size})"

        break if events.size < 50  # 50件未満なら最後のページ

        page += 1
        sleep(1)
      end

      all_events.uniq { |e| e[:id] }
    end

    def fetch_tournaments(events)
      log "Fetching #{events.size} pokerfans events"
      events.each_with_index do |event, index|
        log "Fetching event #{index + 1}/#{events.size}: #{event[:id]}"
        fetch_event_info(event)
      end
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
      html = `curl -L --compressed -s -X GET "#{url}"`
      html.force_encoding('UTF-8')
    end

    def extract_event_ids(html_content)
      # profile-event ブロックごとにイベントIDとタイトルを抽出
      events = []
      html_content.scan(/<div class="profile-event">(.*?)<\/div>\s*<\/div>\s*<\/div>/m).each do |match|
        block = match[0]
        id_match = block.match(/href="\/events\/(\d+)"/)
        title_match = block.match(/data-original-title="([^"]+)"/)
        if id_match
          events << {
            id: id_match[1],
            title: title_match ? title_match[1] : ''
          }
        end
      end
      events.uniq { |e| e[:id] }
    end

    def fetch_event_info(event)
      event_id = event[:id]
      title = event[:title]

      # タイトルに「リング」または「ring」が含まれる場合はスキップ
      if title =~ /リング|ring/i
        log "SKIP: Ring game excluded - #{title}"
        return
      end

      # タイトルに「コイン」または「coin」が含まれていない場合はスキップ
      unless title =~ /コイン|coin|サテ|現金/i
        log "SKIP: No coin keyword - #{title}"
        return
      end

      file_path = make_info_file_path(event_id)
      if File.exist?(file_path)
        log "SKIP: Event info already exists for #{event_id}"
        return
      end

      sleep(1)
      url = "#{BASE_URL}/events/#{event_id}"
      html = `curl -L --compressed -s -X GET "#{url}"`
      # イベント情報部分のみ抽出して保存
      event_section = extract_event_section(html)
      File.write(file_path, event_section, encoding: 'UTF-8')
    end

    def extract_event_section(html)
      html = html.force_encoding('UTF-8')
      # job-description クラスがイベント詳細を含む
      match = html.match(/<div class="job-description">.*?<\/div>\s*<!--=== End Job Description ===/m)
      match ? match[0] : html
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
  scraper = PokerCalendar::PokerfansScraper.new(PokerCalendar::Settings::DATA_DIR, date)

  puts "Fetching pokerfans events for #{date.strftime('%Y-%m-%d')}..."
  event_ids = scraper.fetch_daily_tournaments
  puts "Found #{event_ids.size} events"

  scraper.fetch_tournaments(event_ids)
  puts "Done."
end
