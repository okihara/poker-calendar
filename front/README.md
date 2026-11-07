# ポーカートナメ検索

ポーカートーナメント情報を一覧・絞り込みできるフロントエンド（https://poker-search.vercel.app/）。

- データ元: Vercel Blob 上の JSON（`~/work/poker-calender` のスクレイパーが1日2回更新）。取得失敗時は Google スプレッドシートの公開CSVにフォールバック
- 構成: Vite + React + TypeScript + Tailwind CSS v4

## 開発

```sh
npm install
npm run dev      # http://localhost:5173
npm run build    # 型チェック + dist/ に出力
```

Vercel では `vercel.json` の設定で `npm run build` → `dist/` を配信します。

## ファイル構成

```
index.html               エントリ（OGP・PWAのmeta）
public/                  そのまま配信される静的ファイル（manifest.json, sw.js, images/）
src/
  App.tsx                画面全体と状態（フィルター・データ・デバッグ時刻・ハイローラー）
  lib/data.ts            取得（JSON/CSV）と正規化（倍率計算・日時パース）
  lib/filters.ts         フィルター定義・絞り込み・件数集計・ソート・URL同期
  lib/time.ts            getNow()（デバッグ時刻対応）と日時フォーマット
  components/
    Toolbar.tsx          上部固定の日付タブ＋チップ行
    FilterSheet.tsx      絞り込みシート（スマホは下から、PCは中央）
    TournamentList.tsx   スマホ用リスト
    TournamentTable.tsx  PC用テーブル（768px以上）
    Badges.tsx, Chip.tsx 倍率バッジ・チップ
    ExternalDialog.tsx   大会ページの iframe 表示
    DebugBar.tsx         デバッグ時刻バー
```

## カスタマイズ

- エリア・キーワード・倍率帯の追加: `src/lib/filters.ts` の `AREAS` / `KEYWORDS` / `MULT_TIERS`
- フィルター条件の追加: `Filters` 型と `filterRows()` に追加し、`FilterSheet.tsx` にUIを足す
- URLクエリ（共有リンク）: `filtersFromURL()` / `filtersToURL()`

## ライセンス

MIT
