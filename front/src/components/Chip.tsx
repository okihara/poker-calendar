import type { ReactNode } from "react";

type Props = {
  active?: boolean;
  onClick?: () => void;
  // 未選択時の色（倍率チップなど）。選択時は濃色で塗る
  colorClass?: string;
  children: ReactNode;
};

export function Chip({ active, onClick, colorClass, children }: Props) {
  const base = "inline-flex shrink-0 items-center gap-1 whitespace-nowrap rounded-full px-3 py-1.5 text-[13px] font-semibold ring-1 ring-inset transition-colors";
  const look = active
    ? "bg-slate-900 text-white ring-slate-900"
    : (colorClass ?? "bg-white text-slate-700 ring-slate-300") + " hover:brightness-95";
  return (
    <button type="button" aria-pressed={active} onClick={onClick} className={`${base} ${look}`}>
      {children}
    </button>
  );
}
