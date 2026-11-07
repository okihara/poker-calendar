# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

```bash
npm install
npm run dev     # http://localhost:5173
npm run build   # tsc -b && vite build → dist/
```

## Architecture Overview

Vite + React + TypeScript + Tailwind CSS v4. Single page, no router, no global state library — `App.tsx` holds all state in `useState`.

### Data Flow
1. **Fetch** (`src/lib/data.ts`): JSON from Vercel Blob (`JSON_URL`, uploaded twice daily by the poker-calender scraper repo). Falls back to the Google Sheets CSV via PapaParse (dynamic import) if the fetch fails
2. **Normalize** (`normalizeRow`): raw string rows → `Tournament` (dates parsed, fees as numbers, `multiplier` = total prize / (entry fee + add-on), `searchText` for keyword search)
3. **Filter / sort** (`src/lib/filters.ts`): pure functions over a `Filters` object; `filterCounts()` computes the per-chip counts. Filters sync to URL query params (`area`, `mult`, `title`, `search`, `closing`, `showLate`, `sort`=mult|late, `date`; legacy `sortMult=1` is still read) for sharing
4. **Render**: `TournamentList` (mobile, < 768px / `md`) and `TournamentTable` (PC) render the same rows

### UI
- Header (logo, title, ♦10K+ high-roller toggle saved in localStorage) → sticky `Toolbar` (今日/明日 tabs, sort tabs 開始順/倍率順/締切が近い from `SORT_TABS`, 絞り込み button, 締切1時間以内 quick chip, applied-filter chips with ×) → list/table
- Favorite shops (★ on each row, localStorage `favoriteShops`) are grouped into a "★ お気に入りの店" section at the top; `App.tsx` builds `sections` and a shared `RowContext` (`components/rowProps.ts`) for both list and table
- Row labels: LIVE = started and late reg still open (`isLive`); 🏆 最高倍率 = highest multiplier among the shown, non-expired rows (`bestKey`)
- `FilterSheet`: native `<dialog>`; changes apply immediately, the bottom button only closes it
- Multiplier emphasis lives in `Badges.tsx` (green 10x / blue 20x / violet 30x / rose 40x / amber 50x+), graduated by tier: `MULT_STYLES` (badge: tinted for 10x, solid + larger for 20x+; row: left color bar, plus background tint for 30x+ via `multRowClass`) and `MULT_COLORS` (filter chips)
- Tapping a shop name toggles a search for that shop; tapping a row opens the link (pokerfans in a new tab, others in `ExternalDialog` iframe)

### Notes
- Date tabs: a "day" is late-reg time within 00:00 → next day 06:00
- Prize parsing handles 万, 千, k, x2 multipliers; multiplier ≥ 500 is treated as invalid; satellites have no multiplier
- `public/sw.js` is a hand-written service worker (navigation network-first, assets cache-first). Bump `CACHE_NAME` when changing its logic
- All time references use `getNow()` instead of `new Date()` to support debug time override

## Debug: Time Override
Hidden feature to override the current time for testing date filters and late registration logic.

### How to activate
1. **URL param** — URLに `?debug_time=` を追加:
   ```
   http://localhost:5173/?debug_time=2026-02-14T23:30
   ```
2. **Browser console** — コンソールから直接呼び出し:
   ```js
   __setDebugTime('2026-02-14T23:30')  // 任意の日時を設定
   __clearDebugTime()                   // 解除して実時刻に戻す
   ```
3. **Debug bar UI** — 起動後に画面上部に表示される赤いバーから datetime picker で変更・解除が可能

### What it affects
- `getNow()` が返す値（アプリ内の全 `new Date()` を置換済み）
- 日付タブ（「今日」「明日」）のフィルタリング結果
- レイトレジストレーション期限切れ判定
- 日付タブのラベル表示（例: 2/14(土) → 設定日に変化）

### Example use cases
```
# 深夜帯のレイトレジ表示テスト
?debug_time=2026-02-15T01:30

# 明日タブの動作確認
?debug_time=2026-02-14T10:00

# 他のフィルターと併用
?debug_time=2026-02-14T23:00&area=六本木
```