import { useState } from "react";
import { toDatetimeLocal } from "../lib/time";

// デバッグ時刻が有効なときだけ画面上部に出る赤いバー
export function DebugBar({ time, onSet }: { time: Date; onSet: (value: string | null) => void }) {
  const [value, setValue] = useState(toDatetimeLocal(time));
  return (
    <div className="flex flex-wrap items-center gap-2 border-b-2 border-red-500 bg-slate-950 px-3 py-1.5 font-mono text-[13px] text-red-400">
      <span className="font-bold">DEBUG: {time.toLocaleString("ja-JP")}</span>
      <input
        type="datetime-local"
        step={60}
        value={value}
        onChange={(e) => setValue(e.target.value)}
        className="rounded border border-slate-600 bg-slate-800 px-1.5 py-0.5 text-white"
      />
      <button type="button" onClick={() => value && onSet(value)} className="rounded bg-red-500 px-2.5 py-0.5 text-xs text-white">適用</button>
      <button type="button" onClick={() => onSet(null)} className="rounded bg-slate-600 px-2.5 py-0.5 text-xs text-white">解除</button>
    </div>
  );
}
