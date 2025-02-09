require 'openai'
require 'time'
require 'json'
require 'csv'
load 'info_fetcher.rb'
load 'csv_uploader.rb'

today_str = Time.now.strftime("%Y-%m-%d")
# today_str = "2025-02-06"

# ---
client = OpenAI::Client.new(access_token: File.read(".env").strip)

today_file_name = "./data/pg-#{today_str}.html"

unless File.exist?(today_file_name)
  puts "ファイルが存在しないので取得します #{today_file_name}"
  `curl -X GET "https://pokerguild.jp/?date=#{today_str}" > #{today_file_name}`
end
html_content = File.read(today_file_name)

# 正規表現で /tourneys/数字 にマッチするリンクを抽出
# <main> から </main> までの間にあるリンクを取得
tourney_links = html_content.scan(/<main>.*?<\/main>/m).join
                            .scan(/\/tourneys\/\d+/)
                            .uniq

# 先頭の10件を取得
# tourney_links = tourney_links[0, 10]

# トーナメント情報を取得
tourney_links.each do |link|
  fetch_tourney_info(link)
end

# トーナメント情報をOpenAIに投げて結果を保存
tourney_links.each do |link|
  post_to_chat(client, link)
end

# csv に書き出し
csv = CSV.open("./data/tourney_info_#{today_str}.csv", "w")
csv << ["ID", "shop_name", "address", "title", "date", "start_time", "late_registration_time", "entry_fee", "add_on", "prize_list", "total_prize", "prize_text"]

tourney_links.each_with_index do |link, i|
  res_file_name = './data/' + make_res_filename(link)
  raise "ファイルが存在しません #{res_file_name}" unless File.exist?(res_file_name)

  res = JSON.parse(File.read(res_file_name))
  next unless res["shop_name"]
  next unless res["date"]


  puts "#{i + 1} #{res["shop_name"]} #{res["title"]} #{link}"

  def format_prize_list(prize_list)
    prize_list && prize_list.compact.sum
  rescue => e
    nil
  end

  csv << [
    i + 1,
    res["shop_name"],
    res["address"],
    res["title"],
    res["date"],
    format_time(res["start_time"]),
    format_time(res["late_registration_time"]) || format_time(res["start_time"]),
    format_money(res["entry_fee"]),
    format_money(res["add_on"]),
    format_prize_list(res["prize_list"]),
    format_money(res["total_prize"]),
    res["prize_text"],
  ]
end

csv.close

upload_csv("./data/tourney_info_#{today_str}.csv")
