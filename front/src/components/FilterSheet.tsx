import { useEffect, useRef, type ReactNode } from "react";
import { AREAS, KEYWORDS, MULT_TIERS, type Filters, type filterCounts } from "../lib/filters";
import { MULT_COLORS } from "./Badges";
import { Chip } from "./Chip";

type Props = {
  open: boolean;
  onClose: () => void;
  filters: Filters;
  onChange: (patch: Partial<Filters>) => void;
  onReset: () => void;
  counts: ReturnType<typeof filterCounts>;
  resultCount: number;
};

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="py-3">
      <h3 className="mb-2 text-xs font-semibold text-slate-500">{title}</h3>
      <div className="flex flex-wrap gap-1.5">{children}</div>
    </section>
  );
}

function Toggle({ label, checked, onChange }: { label: string; checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <label className="flex cursor-pointer items-center justify-between py-3 text-sm">
      {label}
      <input type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} className="peer sr-only" />
      <span className="relative h-6 w-10 rounded-full bg-slate-300 transition-colors after:absolute after:left-0.5 after:top-0.5 after:h-5 after:w-5 after:rounded-full after:bg-white after:transition-transform peer-checked:bg-slate-900 peer-checked:after:translate-x-4" />
    </label>
  );
}

// 絞り込みシート（スマホは下から、PCは中央に表示）。変更は即時反映し、ボタンは閉じるだけ
export function FilterSheet({ open, onClose, filters: f, onChange, onReset, counts, resultCount }: Props) {
  const ref = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    if (open && !d.open) d.showModal();
    if (!open && d.open) d.close();
  }, [open]);

  return (
    <dialog
      ref={ref}
      onClose={onClose}
      onClick={(e) => e.target === ref.current && onClose()}
      className="m-0 mt-auto max-h-[88dvh] w-full max-w-none rounded-t-2xl bg-white p-0 text-slate-900 md:m-auto md:max-w-lg md:rounded-2xl"
    >
      <div className="flex max-h-[88dvh] flex-col">
        <header className="flex items-center justify-between border-b border-slate-200 px-4 py-3">
          <h2 className="text-base font-bold">絞り込み</h2>
          <button type="button" onClick={onClose} aria-label="閉じる" className="rounded-full px-2 text-2xl leading-none text-slate-500">×</button>
        </header>

        <div className="flex-1 divide-y divide-slate-100 overflow-y-auto px-4">
          <div className="py-3">
            <input
              type="search"
              value={f.search}
              onChange={(e) => onChange({ search: e.target.value })}
              placeholder="店名・タイトル・エリアで検索"
              className="w-full rounded-lg bg-slate-100 px-3 py-2.5 text-base outline-none ring-slate-400 focus:ring-2"
            />
          </div>

          <Section title="エリア">
            {AREAS.map((a) => (
              <Chip key={a} active={f.area === a} onClick={() => onChange({ area: f.area === a ? null : a })}>
                {a} <span className="font-normal opacity-70">{counts.area[a]}</span>
              </Chip>
            ))}
          </Section>

          <Section title="賞金総額比率">
            {MULT_TIERS.map((m) => (
              <Chip key={m.key} active={f.mult === m.key} colorClass={MULT_COLORS[m.key]} onClick={() => onChange({ mult: f.mult === m.key ? null : m.key })}>
                {m.label} <span className="font-normal opacity-70">{counts.mult[m.key]}</span>
              </Chip>
            ))}
          </Section>

          <Section title="種類">
            {KEYWORDS.map((k) => (
              <Chip key={k} active={f.keyword === k} onClick={() => onChange({ keyword: f.keyword === k ? null : k })}>
                {k}
              </Chip>
            ))}
          </Section>

          <div>
            <Toggle label={`レイト締切まで1時間以内のみ（${counts.closingSoon}件）`} checked={f.closingSoon} onChange={(v) => onChange({ closingSoon: v })} />
            <Toggle label="レイト終了したものも表示" checked={f.showExpired} onChange={(v) => onChange({ showExpired: v })} />
          </div>
        </div>

        <footer className="flex gap-2 border-t border-slate-200 px-4 py-3 pb-[max(0.75rem,env(safe-area-inset-bottom))]">
          <button type="button" onClick={onReset} className="rounded-lg px-4 py-3 text-sm font-semibold text-slate-600 ring-1 ring-inset ring-slate-300">
            リセット
          </button>
          <button type="button" onClick={onClose} className="flex-1 rounded-lg bg-slate-900 py-3 text-sm font-bold text-white">
            {resultCount}件を表示
          </button>
        </footer>
      </div>
    </dialog>
  );
}
