require 'net/http'
require 'uri'
require 'json'
require 'csv'
require 'time'
require_relative './loggable'

module PokerCalendar
  # 生成済みCSVをJSONに変換して Vercel Blob にアップロードする。
  # フロントエンドは Google Spreadsheet の公開CSVの代わりにこのJSONを読む。
  # スプレッドシートへのアップロードはデータ確認用として並行して残す。
  class VercelBlobUploader
    include Loggable

    API_ORIGIN = "https://blob.vercel-storage.com"
    # CDNキャッシュ秒数。データ更新は1日2回だが、更新後に反映が遅れすぎないよう5分にする
    CACHE_MAX_AGE = 300

    def initialize(token)
      @token = token
    end

    # csv_files を結合してJSON化し、pathname (例: "tournaments.json") へ上書きアップロードする
    def upload_csv_as_json(csv_files, pathname)
      tournaments = load_tournaments(Array(csv_files))
      if tournaments.empty?
        raise "アップロード対象のデータ行が0件のため、Vercel Blobへのアップロードを中止しました。"
      end

      payload = JSON.generate({
        updated_at: Time.now.iso8601,
        count: tournaments.size,
        tournaments: tournaments,
      })

      url = put_blob(pathname, payload)
      log "Uploaded #{tournaments.size} tournaments to Vercel Blob: #{url}"
      url
    end

    private

    def load_tournaments(csv_files)
      csv_files.select { |f| File.exist?(f) }.flat_map do |file|
        CSV.read(file, encoding: 'UTF-8', headers: true).map do |row|
          # PapaParse(フロントエンド)は空セルを "" で返すため、nil を "" に揃える
          row.to_h.transform_values { |v| v.nil? ? "" : v }
        end
      end
    end

    def put_blob(pathname, body)
      uri = URI("#{API_ORIGIN}/#{pathname}")
      req = Net::HTTP::Put.new(uri)
      req['Authorization'] = "Bearer #{@token}"
      # x-api-version は指定しない。'11' を送るとAPIが "Invalid pathname" を返すため、
      # サーバー既定のバージョンに任せる（未指定で正常にアップロードできることを確認済み）
      req['x-content-type'] = 'application/json'
      req['x-add-random-suffix'] = '0'   # 固定URLで配信するためサフィックスなし
      req['x-allow-overwrite'] = '1'     # 毎回同じパスに上書き
      req['x-cache-control-max-age'] = CACHE_MAX_AGE.to_s
      req.body = body

      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 60) do |http|
        http.request(req)
      end

      unless res.is_a?(Net::HTTPSuccess)
        raise "Vercel Blobへのアップロードに失敗しました: HTTP #{res.code} #{res.body}"
      end

      JSON.parse(res.body)["url"]
    end
  end
end
