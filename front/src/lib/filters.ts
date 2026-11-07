import type { Tournament } from "./data";

export const AREAS = ["六本木", "渋谷", "新宿", "秋葉原", "新橋", "赤坂", "中野", "上野", "池袋"];
export const KEYWORDS = ["JOPT", "戦国", "SPADIE", "サテ", "祝勝", "PLO"];

export const MULT_TIERS = [
  { key: "10-19", label: "x10", min: 10, max: 20 },
  { key: "20-29", label: "x20", min: 20, max: 30 },
  { key: "30-39", label: "x30", min: 30, max: 40 },
  { key: "40-49", label: "x40", min: 40, max: 50 },
  { key: "50plus", label: "x50+", min: 50, max: Infinity },
] as const;
export type MultKey = (typeof MULT_TIERS)[number]["key"];

export type SortKey = "start" | "lateReg" | "area" | "shopName" | "title" | "entryFee" | "addOn" | "totalPrize" | "multiplier";
export type Sort = { key: SortKey; dir: "asc" | "desc" };

export const HIGH_ROLLER_MIN_FEE = 10000;
export const CLOSING_SOON_MS = 60 * 60 * 1000;

export type Filters = {
  date: "today" | "tomorrow";
  area: string | null;
  mult: MultKey | null;
  keyword: string | null;
  search: string;
  closingSoon: boolean;
  showExpired: boolean;
  sort: Sort;
};

export const DEFAULT_SORT: Sort = { key: "start", dir: "asc" };
export const MULT_SORT: Sort = { key: "multiplier", dir: "desc" };
export const LATE_SORT: Sort = { key: "lateReg", dir: "asc" };

// 並べ替えタブ（id はURLの sort= の値）
export const SORT_TABS = [
  { id: "start", label: "開始順", sort: DEFAULT_SORT },
  { id: "mult", label: "倍率順", sort: MULT_SORT },
  { id: "late", label: "締切が近い", sort: LATE_SORT },
] as const;

export function sortTabId(sort: Sort) {
  return SORT_TABS.find((t) => t.sort.key === sort.key && t.sort.dir === sort.dir)?.id ?? null;
}

export const DEFAULT_FILTERS: Filters = {
  date: "today",
  area: null,
  mult: null,
  keyword: null,
  search: "",
  closingSoon: false,
  showExpired: false,
  sort: DEFAULT_SORT,
};

// 「絞り込み」ボタンに出す件数（日付・並び順は除く）
export function countActive(f: Filters): number {
  return [f.area, f.mult, f.keyword, f.search.trim(), f.closingSoon, f.showExpired].filter(Boolean).length;
}

export function multTier(m: number | null) {
  if (m == null) return null;
  return MULT_TIERS.find((t) => m >= t.min && m < t.max) ?? null;
}

export function isExpired(t: Tournament, now: Date) {
  return !!t.lateReg && t.lateReg < now;
}

// レイト受付中（開始済み・締切前）
export function isLive(t: Tournament, now: Date) {
  return !!t.start && !!t.lateReg && t.start <= now && now <= t.lateReg;
}

export function isClosingSoon(t: Tournament, now: Date) {
  return !!t.lateReg && t.lateReg >= now && t.lateReg.getTime() - now.getTime() <= CLOSING_SOON_MS;
}

// エリア判定: タイトルに他エリア名が含まれると誤マッチするため、エリア・住所・店名のみで判定
export function matchesArea(t: Tournament, area: string) {
  return [t.area, t.address, t.shopName].some((v) => v.includes(area));
}

type Skip = { area?: boolean; mult?: boolean; closingSoon?: boolean };

// skip: 件数表示のために、そのフィルター自体は適用せずに絞り込む
export function filterRows(rows: Tournament[], f: Filters, now: Date, highRoller: boolean, skip: Skip = {}) {
  // 1日の定義: 当日00:00 〜 翌日06:00 にレイト締切が含まれるもの
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const dayStart = new Date(todayStart.getTime() + (f.date === "tomorrow" ? 24 : 0) * 3600_000);
  const dayEnd = new Date(dayStart.getTime() + 30 * 3600_000);
  const search = f.search.trim().toLowerCase();
  const keyword = f.keyword?.toLowerCase();

  return rows.filter((t) => {
    if (highRoller && !(t.entryFee != null && t.entryFee >= HIGH_ROLLER_MIN_FEE)) return false;
    if (!t.lateReg || t.lateReg < dayStart || t.lateReg >= dayEnd) return false;
    if (!skip.area && f.area && !matchesArea(t, f.area)) return false;
    if (keyword && !t.searchText.includes(keyword)) return false;
    if (search && !t.searchText.includes(search)) return false;
    if (!f.showExpired && isExpired(t, now)) return false;
    if (!skip.closingSoon && f.closingSoon && !isClosingSoon(t, now)) return false;
    if (!skip.mult && f.mult && multTier(t.multiplier)?.key !== f.mult) return false;
    return true;
  });
}

export function filterCounts(rows: Tournament[], f: Filters, now: Date, highRoller: boolean) {
  const byArea = filterRows(rows, f, now, highRoller, { area: true });
  const byMult = filterRows(rows, f, now, highRoller, { mult: true });
  const byClosing = filterRows(rows, f, now, highRoller, { closingSoon: true });
  return {
    area: Object.fromEntries(AREAS.map((a) => [a, byArea.filter((t) => matchesArea(t, a)).length])),
    mult: Object.fromEntries(MULT_TIERS.map((m) => [m.key, byMult.filter((t) => multTier(t.multiplier)?.key === m.key).length])),
    closingSoon: byClosing.filter((t) => isClosingSoon(t, now)).length,
  };
}

export function sortRows(rows: Tournament[], sort: Sort) {
  const mul = sort.dir === "desc" ? -1 : 1;
  const value = (t: Tournament) => {
    const v = t[sort.key];
    if (v instanceof Date) return v.getTime();
    return v ?? -Infinity;
  };
  return [...rows].sort((a, b) => {
    const va = value(a);
    const vb = value(b);
    if (typeof va === "string" && typeof vb === "string") return va.localeCompare(vb, "ja") * mul;
    if (va < vb) return -1 * mul;
    if (va > vb) return 1 * mul;
    return 0;
  });
}

// URLクエリ ⇔ フィルター（共有リンク用。キー名は旧版と互換）
export function filtersFromURL(search: string): Filters {
  const p = new URLSearchParams(search);
  const mult = p.get("mult");
  const area = p.get("area");
  const keyword = p.get("title");
  return {
    date: p.get("date") === "tomorrow" ? "tomorrow" : "today",
    area: area && AREAS.includes(area) ? area : null,
    mult: MULT_TIERS.some((m) => m.key === mult) ? (mult as MultKey) : null,
    keyword: keyword && KEYWORDS.includes(keyword) ? keyword : null,
    search: p.get("search") || "",
    closingSoon: p.get("closing") === "1",
    showExpired: p.get("showLate") === "1",
    // sortMult=1 は旧版の共有リンク互換
    sort: SORT_TABS.find((t) => t.id === p.get("sort"))?.sort ?? (p.get("sortMult") === "1" ? MULT_SORT : DEFAULT_SORT),
  };
}

export function filtersToURL(f: Filters, base: URLSearchParams): string {
  const p = new URLSearchParams();
  const debug = base.get("debug_time");
  if (debug) p.set("debug_time", debug);
  if (f.date === "tomorrow") p.set("date", "tomorrow");
  if (f.area) p.set("area", f.area);
  if (f.mult) p.set("mult", f.mult);
  if (f.keyword) p.set("title", f.keyword);
  if (f.search.trim()) p.set("search", f.search.trim());
  if (f.closingSoon) p.set("closing", "1");
  if (f.showExpired) p.set("showLate", "1");
  const tab = sortTabId(f.sort);
  if (tab && tab !== "start") p.set("sort", tab);
  return p.toString();
}
