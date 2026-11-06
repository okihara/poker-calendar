import { AREAS, MULT_TIERS, SORT_TABS, countActive, sortTabId, type Filters } from "../lib/filters";
import { fmtDateShort } from "../lib/time";
import { Chip } from "./Chip";

type Props = {
  now: Date;
  filters: Filters;
  onChange: (patch: Partial<Filters>) => void;
  onOpenSheet: () => void;
  closingSoonCount: number;
  areaCounts: Record<string, number>;
  resultCount: number;
};

// 画面上部に固定する日付タブ＋並べ替えタブ＋チップ行
export function Toolbar({ now, filters: f, onChange, onOpenSheet, closingSoonCount, areaCounts, resultCount }: Props) {
  const tomorrow = new Date(now.getTime() + 24 * 3600_000);
  const active = countActive(f);
  const currentSort = sortTabId(f.sort);

  // 適用中の条件をチップで表示（× で解除）
  const applied: { label: string; clear: () => void }[] = [];
  if (f.search.trim()) applied.push({ label: `「${f.search.trim()}」`, clear: () => onChange({ search: "" }) });
  if (f.mult) applied.push({ label: MULT_TIERS.find((m) => m.key === f.mult)!.label, clear: () => onChange({ mult: null }) });
  if (f.keyword) applied.push({ label: f.keyword, clear: () => onChange({ keyword: null }) });
  if (f.showExpired) applied.push({ label: "レイト終了も表示", clear: () => onChange({ showExpired: false }) });

  const tab = (key: Filters["date"], label: string, date: Date) => (
    <button
      type="button"
      onClick={() => onChange({ date: key })}
      className={`border-b-2 px-1 pb-2 pt-2.5 text-sm ${f.date === key ? "border-slate-900 font-bold text-slate-900" : "border-transparent text-slate-500"}`}
    >
      {label} <span className="tabular-nums">{fmtDateShort(date)}</span>
    </button>
  );

  return (
    <div className="sticky top-0 z-10 border-b border-slate-200 bg-white">
      <div className="flex items-end gap-5 px-4">
        {tab("today", "今日", now)}
        {tab("tomorrow", "明日", tomorrow)}
      </div>

      <div className="flex items-center gap-2 border-t border-slate-100 px-4 pt-2">
        <div className="flex rounded-lg bg-slate-100 p-0.5 text-xs">
          {SORT_TABS.map((s) => (
            <button
              key={s.id}
              type="button"
              aria-pressed={currentSort === s.id}
              onClick={() => onChange({ sort: s.sort })}
              className={`rounded-md px-3 py-1.5 font-semibold ${currentSort === s.id ? "bg-white text-slate-900 shadow-sm" : "text-slate-500"}`}
            >
              {s.label}
            </button>
          ))}
        </div>
        <span className="ml-auto text-xs text-slate-500 tabular-nums">{resultCount}件</span>
      </div>

      <div className="flex gap-1.5 overflow-x-auto px-4 py-2 [scrollbar-width:none]">
        <Chip active={active > 0} onClick={onOpenSheet}>
          <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
            <path d="M4 6h16M7 12h10M10 18h4" strokeLinecap="round" />
          </svg>
          絞り込み{active > 0 && ` ${active}`}
        </Chip>
        <Chip active={f.closingSoon} onClick={() => onChange({ closingSoon: !f.closingSoon })}>
          締切1時間以内 <span className="font-normal opacity-70">{closingSoonCount}</span>
        </Chip>
        {applied.map((a) => (
          <Chip key={a.label} onClick={a.clear} colorClass="bg-slate-100 text-slate-800 ring-slate-200">
            {a.label}
            <span aria-label="解除" className="text-slate-400">×</span>
          </Chip>
        ))}
        {AREAS.map((a) => (
          <Chip key={a} active={f.area === a} onClick={() => onChange({ area: f.area === a ? null : a })}>
            {a} <span className="font-normal opacity-70">{areaCounts[a]}</span>
          </Chip>
        ))}
      </div>
    </div>
  );
}
