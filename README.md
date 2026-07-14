# Poker Calendar

pokerguild.jp と pokerfans.jp からポーカートーナメント情報をスクレイピングし、OpenAI API で構造化データに変換して Google Spreadsheet にアップロードするツール。

## セットアップ

### 必要なもの

- Ruby (arm64-darwin)
- Bundler
- OpenAI API キー
- Google Cloud Service Account の認証情報

### インストール

```bash
bundle install
```

### 設定ファイル

#### `.env`

OpenAI API キーを記述:

```
sk-proj-xxxxx
```

#### `config.json`

Google Service Account の認証情報 JSON を配置。対象の Google Spreadsheet に対してサービスアカウントの編集権限を付与しておくこと。

Spreadsheet のキーは [config/settings.rb](config/settings.rb) で設定。

## 使い方

### メイン実行（今日・明日のトーナメント情報を取得してスプレッドシートに反映）

```bash
ruby bin/update_calendar.rb
```

### 単体テスト（1ファイルの AI 解析結果を確認）

```bash
ruby lib/poker_calendar/tournament_analyzer.rb data/<file>.txt
```

### スクレイパー単体実行

```bash
ruby lib/poker_calendar/tournament_scraper.rb [YYYY-MM-DD]
ruby lib/poker_calendar/pokerfans_scraper.rb [YYYY-MM-DD]
```

### cron による定期実行

`crontab.txt` を参考に設定。毎時実行で最新情報を反映する。

## アーキテクチャ

```
pokerguild.jp / pokerfans.jp
        │
        ▼
  TournamentScraper / PokerfansScraper   ... HTML取得 → data/*.txt
                                             （pokerfans は robots.txt で /events/ が
                                              Disallow のため一覧ページのみ取得し、
                                              一覧に載る範囲の情報だけを保存する。
                                              プライズ内訳は取得できない）
        │
        ▼
  TournamentAnalyzer                     ... OpenAI API (GPT-4o-mini) → data/res-*.json
        │
        ▼
  TournamentParser                       ... JSON → CSV (data/tourney_info_*.csv)
        │
        ▼
  GoogleSpreadsheetUploader              ... CSV → Google Spreadsheet
```

### 主要ファイル

| ファイル | 役割 |
|---------|------|
| [bin/update_calendar.rb](bin/update_calendar.rb) | メインエントリーポイント |
| [lib/poker_calendar/tournament_scraper.rb](lib/poker_calendar/tournament_scraper.rb) | pokerguild.jp スクレイパー |
| [lib/poker_calendar/pokerfans_scraper.rb](lib/poker_calendar/pokerfans_scraper.rb) | pokerfans.jp スクレイパー |
| [lib/poker_calendar/tournament_analyzer.rb](lib/poker_calendar/tournament_analyzer.rb) | OpenAI API による構造化データ抽出 |
| [lib/poker_calendar/tournament_parser.rb](lib/poker_calendar/tournament_parser.rb) | JSON → CSV 変換 |
| [lib/poker_calendar/google_spreadsheet_uploader.rb](lib/poker_calendar/google_spreadsheet_uploader.rb) | Google Spreadsheet アップロード |
| [config/settings.rb](config/settings.rb) | 定数定義 |

### 抽出フィールド

| フィールド | 型 | 説明 |
|-----------|------|------|
| shop_name | string | 店舗名 |
| address | string | 住所 |
| area | string | エリア（渋谷, 六本木, 新宿 等） |
| title | string | トーナメント名 |
| date | string | 日付 (YYYY/MM/DD) |
| start_time | string | 開始時刻 (YYYY/MM/DD HH:MM) |
| late_registration_time | string | レイトレジストレーション締切 |
| late_reentry_time | string | リエントリ締切 |
| entry_fee | integer | 参加費 |
| reentry_fee | integer | リエントリ費 |
| add_on | integer | アドオン費 |
| prize_list | list\<integer\> | 順位別賞金 |
| total_prize | integer | 賞金総額 |
| prize_text | text | 賞金テキスト（原文） |
| guaranteed_amount | integer | コイン保証額 |
| is_jopt_prize | boolean | JOPT賞品の有無 |
| is_coin_prize | boolean | コイン賞品の有無 |

### データファイル命名規則

| パターン | 内容 |
|---------|------|
| `pg-YYYY-MM-DD-tourney-{id}.txt` | pokerguild.jp の HTML |
| `pf-YYYY-MM-DD-event-{id}.txt` | pokerfans.jp の一覧から整形したイベント情報 |
| `res-{上記ファイル名}.json` | OpenAI API レスポンス |
| `tourney_info_YYYY-MM-DD.csv` | 生成された CSV |
