# encoding: utf-8

require 'json'
require 'net/http'
require 'uri'
require_relative './loggable'
require_relative './html_cleaner'

module PokerCalendar
  class TournamentAnalyzer
    include Loggable

    # OpenAI互換のエンドポイント。ローカルLLM(LM Studio)を既定にする。
    # 例: LM Studio -> http://localhost:1234/v1/chat/completions
    #     OpenAI    -> https://api.openai.com/v1/chat/completions
    API_URL = URI(ENV.fetch('LLM_API_URL', 'http://localhost:1234/v1/chat/completions'))
    # LM Studioではロード中のモデル名を指定する（未指定でもロード済みモデルが使われることが多い）
    MODEL = ENV.fetch('LLM_MODEL', ENV.fetch('OPENAI_MODEL', 'local-model'))

    # HTTPタイムアウトとリトライ回数（暴走生成や一過性のネットワークエラー対策）。
    # 既定のread_timeout(60s)ではモデルが生成を止められない時に長時間ハングするため明示する。
    OPEN_TIMEOUT = Integer(ENV.fetch('LLM_OPEN_TIMEOUT', '15'))
    READ_TIMEOUT = Integer(ENV.fetch('LLM_READ_TIMEOUT', '120'))
    MAX_RETRIES  = Integer(ENV.fetch('LLM_MAX_RETRIES', '2'))

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

      # 未解析のファイルが1件でもある時だけ、LLMが応答する状態か事前確認する。
      # モデル未ロードのまま全件エラー→空データで本番を上書きする事故を防ぐ。
      ensure_llm_ready! if info_files.any? { |f| !File.exist?(make_response_file_path(f)) }

      info_files.each_with_index do |info_file, index|
        process_tournament(info_file, index, info_files.size, year)
      end
    end

    private

    # 極小のcompletionを投げてモデルがロード済みか確認する。
    # /v1/models はダウンロード済みモデルも返すため、ロード状態の判定には使えない。
    def ensure_llm_ready!
      post_chat({ model: MODEL, messages: [{ role: "user", content: "ping" }],
                  max_tokens: 1, temperature: 0 })
      log "LLM ready check: OK (#{MODEL})"
    rescue => e
      raise "ローカルLLMが利用できません（モデル未ロードの可能性）。" \
            "LM Studioでモデルをロードしてから再実行してください: #{e.message}"
    end

    def process_tournament(info_file, index, total, year)
      res_file_path = make_response_file_path(info_file)
      if File.exist?(res_file_path)
        log "SKIP: Tournament analysis already exists for #{File.basename(info_file)}"
        return
      end

      info_html = File.read(info_file, encoding: 'utf-8')

      attempts = 0
      begin
        attempts += 1
        sleep(0.7)
        log "Analyzing tournament #{index + 1}/#{total}: #{File.basename(info_file)}"
        response = analyze(info_html, year)
        File.write(res_file_path, response, encoding: 'UTF-8')
      rescue => e
        if attempts <= MAX_RETRIES
          log "Retry #{attempts}/#{MAX_RETRIES} for #{File.basename(info_file)}: #{e.message}"
          retry
        end
        log "Error analyzing tournament (#{File.basename(info_file)}): #{e.message}"
      end
    end

    def make_response_file_path(info_file)
      dir = File.dirname(info_file)
      basename = File.basename(info_file)
      File.join(dir, "res-#{basename}.json")
    end

    def analyze(info_html, year)
      # LLMに渡す前にノイズタグ・属性を除去してトークンを削減し、解析精度を上げる
      cleaned_html = HtmlCleaner.clean(info_html)
      year_instruction = "※日付の年は必ず#{year}年としてください。\n\n"
      body = {
        model: MODEL,
        response_format: response_format,
        messages: [{ role: "user", content: year_instruction + PROMPT + cleaned_html }],
        temperature: 0,
      }

      parsed = post_chat(body)
      message = parsed.dig("choices", 0, "message") || {}
      content = message["content"].to_s
      # 推論モデル(thinking on)はJSON本体をcontentではなくreasoning_contentに出すことがある
      content = message["reasoning_content"].to_s if content.strip.empty?
      content
    end

    # Chat Completions APIを叩いてパース済みレスポンスを返す。タイムアウトは明示する。
    def post_chat(body)
      http = Net::HTTP.new(API_URL.host, API_URL.port)
      http.use_ssl = (API_URL.scheme == 'https')
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      request = Net::HTTP::Post.new(API_URL)
      # ローカルLLMはAPIキー不要。値がある場合のみAuthorizationヘッダを付与する。
      request['Authorization'] = "Bearer #{@api_key}" unless @api_key.to_s.strip.empty?
      request['Content-Type'] = 'application/json'
      request.body = JSON.generate(body)

      response = http.request(request)
      raise "LLM API error: #{response.code} #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    # response_formatの選択。LLM_RESPONSE_FORMATで切替可能。
    #   json_schema (既定): Structured Outputsで型を強制（OpenAI / LM Studioが対応）
    #   json_object       : JSONの妥当性のみ保証（型強制なし）
    #   text              : 素のテキスト（プロンプトのjson指示に依存）
    def response_format
      case ENV.fetch('LLM_RESPONSE_FORMAT', 'json_schema')
      when 'json_object' then { type: "json_object" }
      when 'text'        then { type: "text" }
      else RESPONSE_FORMAT
      end
    end

    # Structured Outputsで型を強制する（prize_listに文字列が混ざる等の事故を防ぐ）
    RESPONSE_FORMAT = {
      type: "json_schema",
      json_schema: {
        name: "tournament_info",
        strict: true,
        schema: {
          type: "object",
          additionalProperties: false,
          properties: {
            shop_name: { type: "string" },
            address: { type: "string" },
            area: { type: "string" },
            title: { type: "string" },
            date: { type: "string" },
            start_time: { type: "string" },
            late_registration_time: { type: ["string", "null"] },
            late_reentry_time: { type: ["string", "null"] },
            entry_fee: { type: "integer" },
            reentry_fee: { type: "integer" },
            add_on: { type: "integer" },
            prize_list: { type: "array", items: { type: "integer" } },
            total_prize: { type: "integer" },
            prize_text: { type: "string" },
            guaranteed_amount: { type: "integer" },
            is_jopt_prize: { type: "boolean" },
            is_coin_prize: { type: "boolean" },
          },
          required: %w[
            shop_name address area title date start_time
            late_registration_time late_reentry_time
            entry_fee reentry_fee add_on
            prize_list total_prize prize_text guaranteed_amount
            is_jopt_prize is_coin_prize
          ],
        },
      },
    }.freeze

    PROMPT = <<~PROMPT
      以下はポーカールームのトーナメント情報です

     【重要な注意事項】
      - 1つのトーナメント情報のみを抽出してください
      - 複数のトーナメントが並列で記載されている場合は、最初の1つだけを抽出してください
      - 1日に複数回開催される場合も、1つのトーナメントとして扱ってください
      - json 形式で出力してください

     【プライズ抽出ルール】
      - prize_list: 順位ごとの賞金額を1位から順に整数で並べる。円・コイン・プル・ポイント・活動支援など数値で金額が明示されたものだけを対象とする（「250,000 活動支援」のように単位が円でなくても数値が明示されていれば対象）
        - チケット・物品・割引券・無料券・ドリンク券など金額が書かれていないプライズはprize_listに入れない（0や文字列も入れない）
        - 「参加人数×1000」のような変動式の賞金も入れない
        - 金額が明示された賞金が1つもない場合は空配列 [] にする
      - total_prize: ページに賞金総額が明記されていればその数値。明記がなければprize_listの合計。どちらも無ければ0
        - 「最大」「〜相当」「保証」の金額はtotal_prizeではなく、保証額ならguaranteed_amountに入れる
      - prize_text: プライズ内容の簡潔な要約（チケット・物品など金額が無いものもここに必ず書く）。記載が無ければ空文字
      - guaranteed_amount: プライズの保証額（「◯◯保証」「GTD」等）。無ければ0

      抽出フィールド:
      - shop_name as string
      - address as string
      - area as string(必ず住所(address)から判定すること。店名や雰囲気で推測しない。次のリストに該当があればその表記を使う: 新宿,渋谷,六本木,西麻布,赤坂,新橋,銀座,秋葉原,上野,湯島,浅草,浅草橋,人形町,池袋,五反田,恵比寿,目黒,蒲田,大森,下北沢,中野,練馬,吉祥寺,金町,葛西,国分寺,立川,八王子,町田,宇都宮,名古屋,京都,大阪,金沢。リストにない場合は最寄り駅名か市区名を1語で。住所が不明な場合のみ店名から判定し、それも不明なら空文字)
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

  api_key = File.exist?(".env") ? File.read(".env").strip : ""
  analyzer = PokerCalendar::TournamentAnalyzer.new(api_key, File.dirname(file))

  html = File.read(file, encoding: 'utf-8')
  year = file[/(\d{4})-\d{2}-\d{2}/, 1]&.to_i || Time.now.year

  response = analyzer.send(:analyze, html, year)
  puts JSON.pretty_generate(JSON.parse(response))
end
