import { multTier, type MultKey } from "../lib/filters";

// 倍率帯ごとの色（フィルターチップの未選択時）
export const MULT_COLORS: Record<MultKey, string> = {
  "10-19": "bg-emerald-50 text-emerald-700 ring-emerald-200",
  "20-29": "bg-blue-50 text-blue-700 ring-blue-200",
  "30-39": "bg-violet-50 text-violet-700 ring-violet-200",
  "40-49": "bg-rose-50 text-rose-700 ring-rose-200",
  "50plus": "bg-amber-50 text-amber-800 ring-amber-300",
};

// 倍率が高いほど目立つよう段階的に強調する
//   badge: 倍率バッジ（x10 は淡色、x20 以上は塗りつぶし）
//   row:   一覧の行（左端の色帯＋x30 以上は背景色）
const MULT_STYLES: Record<MultKey, { badge: string; row: string }> = {
  "10-19": {
    badge: "bg-emerald-50 text-emerald-700 ring-emerald-300",
    row: "border-l-emerald-400",
  },
  "20-29": {
    badge: "bg-blue-600 text-white ring-blue-600",
    row: "border-l-blue-500",
  },
  "30-39": {
    badge: "bg-violet-600 text-white ring-violet-600",
    row: "border-l-violet-500 bg-violet-50",
  },
  "40-49": {
    badge: "bg-rose-600 text-white ring-rose-600",
    row: "border-l-rose-500 bg-rose-50",
  },
  "50plus": {
    badge: "bg-amber-400 text-amber-950 ring-amber-500",
    row: "border-l-amber-400 bg-amber-50",
  },
};

// 行に付けるクラス。倍率なし・x10未満は色帯なし（幅は揃えるため透明の帯を付ける）
export function multRowClass(multiplier: number | null) {
  const tier = multTier(multiplier);
  return `border-l-4 ${tier ? MULT_STYLES[tier.key].row : "border-l-transparent"}`;
}

const pill = "inline-block whitespace-nowrap rounded-md ring-1 ring-inset font-bold tabular-nums";

export function MultBadge({ multiplier }: { multiplier: number | null }) {
  if (multiplier == null) return null;
  const tier = multTier(multiplier);
  if (!tier) return <span className={`${pill} px-1.5 py-0.5 text-xs font-semibold bg-slate-50 text-slate-500 ring-slate-200`}>x{multiplier.toFixed(1)}</span>;
  // x20 以上は文字も大きく
  const size = tier.min >= 20 ? "px-2 py-0.5 text-sm" : "px-1.5 py-0.5 text-xs";
  return <span className={`${pill} ${size} ${MULT_STYLES[tier.key].badge}`}>x{multiplier.toFixed(1)}</span>;
}

export function SatelliteBadge() {
  return <span className={`${pill} px-1.5 py-0.5 text-xs font-semibold bg-teal-50 text-teal-700 ring-teal-200`}>サテ</span>;
}

// レイト受付中（開始済み・締切前）
export function LiveBadge() {
  return (
    <span className={`${pill} inline-flex items-center gap-1 px-1.5 py-0.5 text-[11px] bg-red-50 text-red-600 ring-red-200`}>
      <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-red-500" />
      LIVE
    </span>
  );
}

// 表示中で倍率が一番高いトーナメントに付けるラベル
export function BestLabel() {
  return <span className={`${pill} px-1.5 py-0.5 text-[11px] bg-amber-400 text-amber-950 ring-amber-500`}>🏆 最高倍率</span>;
}

// お気に入りの店の切り替え（★/☆）
export function FavoriteButton({ active, onClick }: { active: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      aria-label={active ? "お気に入りから外す" : "お気に入りに追加"}
      aria-pressed={active}
      onClick={(e) => {
        e.stopPropagation();
        onClick();
      }}
      className={`-my-1 -ml-1 px-1 py-1 text-base leading-none ${active ? "text-amber-500" : "text-slate-300 hover:text-slate-500"}`}
    >
      {active ? "★" : "☆"}
    </button>
  );
}
