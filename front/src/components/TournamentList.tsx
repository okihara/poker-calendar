import type { Tournament } from "../lib/data";
import { isClosingSoon, isExpired, isLive } from "../lib/filters";
import { fmtHM } from "../lib/time";
import { BestLabel, FavoriteButton, LiveBadge, MultBadge, SatelliteBadge, multRowClass } from "./Badges";
import { rowKey, type RowContext, type Section } from "./rowProps";

// 100000 → "10万", 505000 → "50.5万"
function fmtMan(n: number) {
  return n >= 10000 ? `${Math.round(n / 1000) / 10}万` : n.toLocaleString();
}

// スマホ用の高密度リスト（1件2〜3行）
export function TournamentList({ sections, ctx }: { sections: Section[]; ctx: RowContext }) {
  return (
    <div className="bg-white">
      {sections.map((s) => (
        <section key={s.title ?? "all"}>
          {s.title && (
            <h2 className="border-b border-slate-200 bg-slate-100 px-4 py-1 text-xs font-semibold text-slate-600">{s.title}</h2>
          )}
          <ul className="divide-y divide-slate-200">
            {s.rows.map((t) => (
              <Row key={rowKey(t)} t={t} ctx={ctx} />
            ))}
          </ul>
        </section>
      ))}
    </div>
  );
}

function Row({ t, ctx }: { t: Tournament; ctx: RowContext }) {
  const { now } = ctx;
  const closing = isClosingSoon(t, now);
  return (
    <li
      onClick={() => t.link && ctx.onOpen(t)}
      className={`flex gap-3 py-2.5 pl-3 pr-4 ${multRowClass(t.multiplier)} ${t.link ? "cursor-pointer active:bg-slate-100" : ""} ${isExpired(t, now) ? "opacity-45" : ""}`}
    >
      <div className="w-12 shrink-0 pt-0.5 text-center leading-tight tabular-nums">
        <div className="text-[17px] font-bold">{fmtHM(t.start)}</div>
        {t.lateReg && (
          <div className={`mt-0.5 text-xs ${closing ? "font-bold text-red-600" : "text-orange-600"}`}>
            <div className="text-[10px] font-normal text-slate-400">締切</div>
            {fmtHM(t.lateReg)}
          </div>
        )}
      </div>

      <div className="min-w-0 flex-1">
        {ctx.bestKey === rowKey(t) && (
          <div className="mb-1">
            <BestLabel />
          </div>
        )}
        <div className="line-clamp-2 text-[15px] font-semibold leading-snug">{t.title || "タイトルなし"}</div>
        <div className="mt-0.5 flex flex-wrap items-center gap-x-1.5 text-xs text-slate-500">
          <span className="flex min-w-0 max-w-full items-center">
            <FavoriteButton active={ctx.favorites.has(t.shopName)} onClick={() => ctx.onToggleFavorite(t.shopName)} />
            <button
              type="button"
              onClick={(e) => {
                e.stopPropagation();
                ctx.onShopClick(t.shopName);
              }}
              className="truncate text-left text-slate-600 underline decoration-slate-300 underline-offset-2"
            >
              {t.shopName}
            </button>
          </span>
          {t.area && <span>· {t.area}</span>}
          {t.entryFee != null && <span className="tabular-nums">· ¥{t.entryFee.toLocaleString()}</span>}
          {t.totalPrize != null && <span className="tabular-nums">· 賞金{fmtMan(t.totalPrize)}</span>}
        </div>
      </div>

      <div className="flex shrink-0 flex-col items-end gap-1 pt-0.5">
        <MultBadge multiplier={t.multiplier} />
        {t.isSatellite && <SatelliteBadge />}
        {isLive(t, now) && <LiveBadge />}
      </div>
    </li>
  );
}
