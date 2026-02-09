# encoding: utf-8

require 'json'
require 'net/http'
require 'uri'
require_relative './loggable'

module PokerCalendar
  class TournamentAnalyzer
    include Loggable

    OPENAI_API_URL = URI('https://api.openai.com/v1/chat/completions')

    def initialize(api_key, data_dir)
      @api_key = api_key
      @data_dir = data_dir
    end

    def process_tournaments(date)
      date_str = date.strftime("%Y-%m-%d")
      year = date.year
      # pg-YYYY-MM-DD-*.txt と pf-YYYY-MM-DD-*.txt を対象
      info_files = Dir.glob(File.join(@data_dir, "*-#{date_str}-*.txt"))
      log "Analyzing #{info_files.size} tournament files for #{date_str}"

      info_files.each_with_index do |info_file, index|
        process_tournament(info_file, index, info_files.size, year)
      end
    end

    private

    def process_tournament(info_file, index, total, year)
      res_file_path = make_response_file_path(info_file)
      if File.exist?(res_file_path)
        log "SKIP: Tournament analysis already exists for #{File.basename(info_file)}"
        return
      end

      info_html = File.read(info_file, encoding: 'utf-8')

      begin
        sleep(0.7)
        log "Analyzing tournament #{index + 1}/#{total}: #{File.basename(info_file)}"
        response = analyze(info_html, year)
        File.write(res_file_path, response, encoding: 'UTF-8')
      rescue => e
        log "Error analyzing tournament: #{e.message}"
      end
    end

    def make_response_file_path(info_file)
      dir = File.dirname(info_file)
      basename = File.basename(info_file)
      File.join(dir, "res-#{basename}.json")
    end

    def analyze(info_html, year)
      year_instruction = "※日付の年は必ず#{year}年としてください。\n\n"
      body = {
        model: "gpt-4.1-nano",
        response_format: { type: "json_object" },
        messages: [{ role: "user", content: year_instruction + PROMPT + info_html }],
        temperature: 0.7,
      }

      http = Net::HTTP.new(OPENAI_API_URL.host, OPENAI_API_URL.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(OPENAI_API_URL)
      request['Authorization'] = "Bearer #{@api_key}"
      request['Content-Type'] = 'application/json'
      request.body = JSON.generate(body)

      response = http.request(request)
      raise "OpenAI API error: #{response.code} #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      parsed = JSON.parse(response.body)
      parsed.dig("choices", 0, "message", "content")
    end

    PROMPT = <<~PROMPT
      以下はポーカールームのトーナメント情報です

     【重要な注意事項】
      - 1つのトーナメント情報のみを抽出してください
      - 複数のトーナメントが並列で記載されている場合は、最初の1つだけを抽出してください
      - prize_listには順位ごとの賞金を個別に記載してください
      - 1日に複数回開催される場合も、1つのトーナメントとして扱ってください
      - json 形式で出力してください

      抽出フィールド:
      - shop_name as string
      - shop_name as string
      - address as string
      - area as string(渋谷,六本木,新宿,etc...)
      - title as string
      - date as string(YYYY/MM/DD)
      - start_time as string(YYYY/MM/DD HH:MM)
      - late_registration_time as string(YYYY/MM/DD HH:MM)
      - late_reentry_time as string(YYYY/MM/DD HH:MM)
      - entry_fee as integer(参加費)
      - reentry_fee as integer(リエントリ費)
      - add_on as integer(アドオン費)
      - prize_list as list<integer>
      - total_prize as integer
      - prize_text as text
      - guaranteed_amount as integer(コイン保証額)
      - is_jopt_prize as boolean
      - is_coin_prize as boolean
      を抜き出してjsonで返してください
      ---
    PROMPT
  end
end

if __FILE__ == $0
  file = ARGV[0]
  unless file
    puts "Usage: ruby #{$0} <tournament_file.txt>"
    exit 1
  end

  unless File.exist?(file)
    puts "File not found: #{file}"
    exit 1
  end

  api_key = File.read(".env").strip
  analyzer = PokerCalendar::TournamentAnalyzer.new(api_key, File.dirname(file))

  html = File.read(file, encoding: 'utf-8')
  year = file[/(\d{4})-\d{2}-\d{2}/, 1]&.to_i || Time.now.year

  response = analyzer.send(:analyze, html, year)
  puts JSON.pretty_generate(JSON.parse(response))
end
