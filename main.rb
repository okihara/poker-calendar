require 'openai'
require 'time'

today_str = Time.now.strftime("%Y-%m-%d")
today_str = "2025-01-16"

puts "hello"

# Set up the OpenAI client with your API key
OPENAI_KEY = ''

# Define the PROMPT
PROMPT = "" "
以下はポーカールームのトーナメント情報です
- shop_name
- address
- title
- date
- start_time
- late_registration_time
- entry_fee(integer)
- reentry_fee(integer)
- add_on(integer)
- prize_list(list<integer>)
- total_prize(integer)
- prize_text(text)
- is_jopt_prize(boolean)
- is_coin_prize(boolean)
を抜き出してjsonで返してください
---
" ""

def make_tourney_info_filename(tourney_link)
  "pg#{tourney_link.gsub("/", "-")}.txt"
end

def fetch_tourney_info(tourney_link)
  file_name = make_tourney_info_filename(tourney_link)
  unless File.exist?(file_name)
    sleep(1)
    url = "https://pokerguild.jp#{tourney_link}"
    `curl -X GET "#{url}" > #{file_name}`
  end

  File.read(file_name)
end

def make_res_filename(link)
  "res-#{make_tourney_info_filename(link)}.json"
end

def post_to_chat(client, link)
  filename = make_tourney_info_filename(link)
  res_file_name = make_res_filename(link)
  info_html = File.read(filename)

  return if File.exist?(res_file_name)

  begin
    sleep(1)
    puts "post to chat #{link}"
    response = client.chat(
      parameters: {
        model: "gpt-4o",
        response_format: { type: "json_object" },
        messages: [{ role: "user", content: PROMPT + info_html }],
        temperature: 0.7,
      }
    )
    res = response.dig("choices", 0, "message", "content")
    File.write(res_file_name, res)
  rescue => e
    pp e
  end
end

def format_time(time)
  return nil unless time

  time.scan(/\d{2}:\d{2}/)[0]
end

# ---
client = OpenAI::Client.new(access_token: OPENAI_KEY)

today_file_name = "pg-#{today_str}.html"

unless File.exist?(today_file_name)
  puts "ファイルが存在しないので取得します#{today_file_name}"
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

require 'csv'
# csv に書き出し
csv = CSV.open("tourney_info_#{today_str}.csv", "w")
csv << ["ID", "shop_name", "address", "title", "date", "start_time", "late_registration_time", "entry_fee", "add_on", "prize_list", "total_prize", "prize_text"]

def format_money(value)
  ret = value.to_s.gsub("円", "").gsub(",", "").gsub("\\", "").to_i
  return nil if ret.zero?

  # 500万以上はおかしいのでnilを返す
  return nil if ret >= 5000000

  ret
end

tourney_links.each_with_index do |link, i|
  res_file_name = make_res_filename(link)
  raise "ファイルが存在しません #{res_file_name}" unless File.exist?(res_file_name)

  res = JSON.parse(File.read(res_file_name))
  next unless res["shop_name"]

  puts "#{i + 1} #{res["shop_name"]} #{res["title"]} #{link}"

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
    res["prize_list"] && res["prize_list"].compact.sum,
    format_money(res["total_prize"]),
    res["prize_text"],
  ]
end
