import { useCallback, useEffect, useMemo, useState } from "react";
import { DebugBar } from "./components/DebugBar";
import { ExternalDialog } from "./components/ExternalDialog";
import { FilterSheet } from "./components/FilterSheet";
import { Toolbar } from "./components/Toolbar";
import { TournamentList } from "./components/TournamentList";
import { TournamentTable } from "./components/TournamentTable";
import { rowKey, type RowContext, type Section } from "./components/rowProps";
import { fetchTournaments, type Tournament } from "./lib/data";
import {
  DEFAULT_FILTERS,
  filterCounts,
  filterRows,
  filtersFromURL,
  filtersToURL,
  isExpired,
  sortRows,
  type Filters,
  type SortKey,
} from "./lib/filters";
import { getDebugTime, getNow, parseDebugTime, setDebugTime } from "./lib/time";

const HIGH_ROLLER_KEY = "highRollerMode";
const FAVORITES_KEY = "favoriteShops";

function loadHighRoller() {
  try {
    return localStorage.getItem(HIGH_ROLLER_KEY) === "1";
  } catch {
    return false;
  }
}

function loadFavorites(): Set<string> {
  try {
    return new Set(JSON.parse(localStorage.getItem(FAVORITES_KEY) || "[]"));
  } catch {
    return new Set();
  }
}

// URLの debug_time はモジュール読み込み時に反映（初回描画から有効にするため）
setDebugTime(parseDebugTime(new URLSearchParams(location.search).get("debug_time")));

export default function App() {
  const [data, setData] = useState<Tournament[]>([]);
  const [status, setStatus] = useState<"loading" | "error" | "ok">("loading");
  const [filters, setFilters] = useState<Filters>(() => filtersFromURL(location.search));
  const [highRoller, setHighRoller] = useState(loadHighRoller);
  const [favorites, setFavorites] = useState(loadFavorites);
  const [now, setNow] = useState(getNow);
  const [debugTime, setDebugTimeState] = useState(getDebugTime);
  const [sheetOpen, setSheetOpen] = useState(false);
  const [externalUrl, setExternalUrl] = useState<string | null>(null);

  useEffect(() => {
    fetchTournaments()
      .then((rows) => {
        setData(rows);
        setStatus("ok");
      })
      .catch((e) => {
        console.error(e);
        setStatus("error");
      });
  }, []);

  // 1分ごとに現在時刻を更新（レイト終了・締切間近の判定用）
  useEffect(() => {
    const id = setInterval(() => setNow(getNow()), 60_000);
    return () => clearInterval(id);
  }, [debugTime]);

  const applyDebugTime = useCallback((value: string | null) => {
    const d = parseDebugTime(value);
    if (value && !d) return console.error("[Debug] Invalid date:", value);
    setDebugTime(d);
    setDebugTimeState(d);
    setNow(getNow());
    const p = new URLSearchParams(location.search);
    if (d) p.set("debug_time", value!);
    else p.delete("debug_time");
    history.replaceState({}, "", p.toString() ? `?${p}` : location.pathname);
  }, []);

  // コンソールからのデバッグ時刻操作
  useEffect(() => {
    Object.assign(window, {
      __setDebugTime: (s: string | null) => applyDebugTime(s),
      __clearDebugTime: () => applyDebugTime(null),
    });
  }, [applyDebugTime]);

  // フィルター状態をURLに反映（共有用）
  useEffect(() => {
    const qs = filtersToURL(filters, new URLSearchParams(location.search));
    history.replaceState({}, "", qs ? `?${qs}` : location.pathname);
  }, [filters]);

  useEffect(() => {
    try {
      localStorage.setItem(HIGH_ROLLER_KEY, highRoller ? "1" : "0");
    } catch {
      /* localStorage不可でも動作継続 */
    }
  }, [highRoller]);

  useEffect(() => {
    try {
      localStorage.setItem(FAVORITES_KEY, JSON.stringify([...favorites]));
    } catch {
      /* localStorage不可でも動作継続 */
    }
  }, [favorites]);

  const rows = useMemo(() => sortRows(filterRows(data, filters, now, highRoller), filters.sort), [data, filters, now, highRoller]);

  // お気に入りの店があれば先頭にまとめる
  const sections = useMemo<Section[]>(() => {
    const fav = rows.filter((t) => favorites.has(t.shopName));
    if (fav.length === 0) return [{ title: null, rows }];
    const others = rows.filter((t) => !favorites.has(t.shopName));
    return [
      { title: "★ お気に入りの店", rows: fav },
      ...(others.length ? [{ title: "その他の店", rows: others }] : []),
    ];
  }, [rows, favorites]);

  // 表示中（レイト終了を除く）で倍率が一番高いもの
  const bestKey = useMemo(() => {
    let best: Tournament | null = null;
    for (const t of rows) {
      if (t.multiplier != null && !isExpired(t, now) && (!best || t.multiplier > best.multiplier!)) best = t;
    }
    return best ? rowKey(best) : null;
  }, [rows, now]);
  const counts = useMemo(() => filterCounts(data, filters, now, highRoller), [data, filters, now, highRoller]);

  const change = (patch: Partial<Filters>) => setFilters((f) => ({ ...f, ...patch }));
  const reset = () => setFilters((f) => ({ ...DEFAULT_FILTERS, date: f.date, sort: f.sort }));
  const toggleFavorite = (shop: string) =>
    setFavorites((prev) => {
      const next = new Set(prev);
      if (next.has(shop)) next.delete(shop);
      else next.add(shop);
      return next;
    });
  const onShopClick = (shop: string) => change({ search: filters.search === shop ? "" : shop });
  const onSort = (key: SortKey) =>
    change({ sort: filters.sort.key === key ? { key, dir: filters.sort.dir === "asc" ? "desc" : "asc" } : { key, dir: "asc" } });
  const onOpen = (t: Tournament) => {
    // pokerfans は iframe 表示を拒否するため別タブで開く
    if (t.link.includes("pokerfans")) window.open(t.link, "_blank", "noopener");
    else setExternalUrl(t.link);
  };

  const ctx: RowContext = { now, bestKey, favorites, onToggleFavorite: toggleFavorite, onOpen, onShopClick };
  const closeExternal = useCallback(() => setExternalUrl(null), []);

  return (
    <>
      {debugTime && <DebugBar key={debugTime.getTime()} time={debugTime} onSet={applyDebugTime} />}

      <header className={`flex items-center gap-3 px-4 py-2.5 text-white ${highRoller ? "bg-amber-900" : "bg-slate-900"}`}>
        <div className="h-9 w-9 shrink-0 overflow-hidden rounded-full bg-white">
          <img src="/images/logo.png" alt="" className="-ml-[30%] -mt-[30%] h-[140%] w-[140%] max-w-none object-cover" />
        </div>
        <h1 className="text-lg font-extrabold tracking-wide">ポーカートナメ検索</h1>
        <button
          type="button"
          aria-pressed={highRoller}
          title="バイイン10,000以上のみ表示"
          onClick={() => setHighRoller((v) => !v)}
          className={`ml-auto rounded-full px-3 py-1 text-xs font-bold ring-1 ring-inset ${
            highRoller ? "bg-amber-400 text-amber-950 ring-amber-400" : "text-amber-300 ring-amber-300/60"
          }`}
        >
          ♦ 10K+
        </button>
      </header>

      <Toolbar
        now={now}
        filters={filters}
        onChange={change}
        onOpenSheet={() => setSheetOpen(true)}
        closingSoonCount={counts.closingSoon}
        areaCounts={counts.area}
        resultCount={rows.length}
      />

      <main className="pb-10 md:px-4 md:pt-3">
        {status === "loading" && (
          <div className="flex items-center gap-2 p-4 text-sm text-slate-500">
            <div className="h-5 w-5 animate-spin rounded-full border-2 border-slate-200 border-t-slate-700" />
            読み込み中...
          </div>
        )}
        {status === "error" && <p className="p-4 text-sm text-red-600">読み込みに失敗しました。ネットワークを確認してください。</p>}
        {status === "ok" && rows.length === 0 && (
          <p className="p-8 text-center text-sm text-slate-500">該当するトーナメントがありません</p>
        )}
        {status === "ok" && rows.length > 0 && (
          <>
            <div className="md:hidden">
              <TournamentList sections={sections} ctx={ctx} />
            </div>
            <div className="hidden md:block">
              <TournamentTable sections={sections} ctx={ctx} sort={filters.sort} onSort={onSort} />
            </div>
          </>
        )}
      </main>

      <FilterSheet
        open={sheetOpen}
        onClose={() => setSheetOpen(false)}
        filters={filters}
        onChange={change}
        onReset={reset}
        counts={counts}
        resultCount={rows.length}
      />
      <ExternalDialog url={externalUrl} onClose={closeExternal} />
    </>
  );
}
