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
- guaranteed_amount:保証額(integer)
- is_jopt_prize(boolean)
- is_coin_prize(boolean)
を抜き出してjsonで返してください
---
" ""

def make_tourney_info_filename(tourney_link)
  "pg#{tourney_link.gsub("/", "-")}.txt"
end

def make_res_filename(link)
  "res-#{make_tourney_info_filename(link)}.json"
end

def fetch_tourney_info(tourney_link)
  file_name = make_tourney_info_filename(tourney_link)
  file_path = "./data/#{file_name}"
  unless File.exist?(file_path)
    sleep(1)
    url = "https://pokerguild.jp#{tourney_link}"
    `curl -X GET "#{url}" > #{file_path}`
  end

  File.read(file_path)
end

def post_to_chat(client, link)
  filename = "./data/" + make_tourney_info_filename(link)
  res_file_name = "./data/" + make_res_filename(link)
  info_html = File.read(filename)

  return if File.exist?(res_file_name)

  begin
    sleep(0.7)
    puts "post to chat #{link}"
    response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
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

def format_money(value)
  ret = value.to_s.gsub("円", "").gsub(",", "").gsub("\\", "").to_i
  return nil if ret.zero?

  # 500万以上はおかしいのでnilを返す
  return nil if ret >= 5000000

  ret
end