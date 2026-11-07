// 現在時刻の取得はすべて getNow() を経由する（デバッグ用の時刻上書きに対応するため）
// URL: ?debug_time=2026-02-14T23:30 / Console: __setDebugTime('2026-02-14T23:30'), __clearDebugTime()
let debugTime: Date | null = null;

export function getNow(): Date {
  return debugTime ? new Date(debugTime.getTime()) : new Date();
}

export function getDebugTime(): Date | null {
  return debugTime;
}

export function setDebugTime(d: Date | null) {
  debugTime = d;
}

export function parseDebugTime(s: string | null | undefined): Date | null {
  if (!s) return null;
  const d = new Date(s);
  return isNaN(d.getTime()) ? null : d;
}

const WEEKDAYS = ["日", "月", "火", "水", "木", "金", "土"];

export function pad2(n: number) {
  return String(n).padStart(2, "0");
}

// "14:40"（デバッグ時刻有効時は日付も付ける: "2/14 14:40"）
export function fmtTime(d: Date | null): string {
  if (!d) return "";
  const hm = `${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
  return debugTime ? `${d.getMonth() + 1}/${d.getDate()} ${hm}` : hm;
}

// "10/24(土)"
export function fmtDateShort(d: Date): string {
  return `${d.getMonth() + 1}/${d.getDate()}(${WEEKDAYS[d.getDay()]})`;
}

// datetime-local input 用 "2026-02-14T23:30"
export function toDatetimeLocal(d: Date): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}T${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

// 常に "14:40"（一覧の時刻表示用）
export function fmtHM(d: Date | null): string {
  return d ? `${pad2(d.getHours())}:${pad2(d.getMinutes())}` : "";
}
