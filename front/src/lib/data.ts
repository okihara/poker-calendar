// Vercel Blob 上の事前生成JSON（スクレイパーが1日2回更新）。
// 取得失敗時は従来のスプレッドシート公開CSVにフォールバックする。
const JSON_URL = "https://y3gbbf6hwsj8orxh.public.blob.vercel-storage.com/tournaments.json";
const CSV_URL =
  "https://docs.google.com/spreadsheets/d/e/2PACX-1vQzRfrIH1vQwDxdZqaoE8t7Q33O5Hxig_18xijgI77yRhfgGUOEUsioJ9zD08hoNuMklZXOxqmmejfq/pub?gid=1600443875&single=true&output=csv";

// JSON/CSV の1行（値はすべて文字列）
export type RawRow = {
  ID?: string;
  shop_name?: string;
  address?: string;
  area?: string;
  title?: string;
  date?: string;
  start_time?: string;
  late_registration_time?: string;
  entry_fee?: string;
  add_on?: string;
  prize_list?: string;
  total_prize?: string;
  guaranteed_amount?: string;
  prize_text?: string;
  link?: string;
};

export type Tournament = {
  id: string;
  shopName: string;
  address: string;
  area: string;
  title: string;
  link: string;
  prizeText: string;
  date: Date | null;
  start: Date | null;
  lateReg: Date | null;
  entryFee: number | null;
  addOn: number | null;
  totalPrize: number | null;
  multiplier: number | null;
  isSatellite: boolean;
  // 全文検索・キーワードフィルター用に全カラムを小文字で連結したもの
  searchText: string;
};

export async function fetchTournaments(): Promise<Tournament[]> {
  return (await fetchRows()).map(normalizeRow);
}

async function fetchRows(): Promise<RawRow[]> {
  try {
    const res = await fetch(JSON_URL);
    if (!res.ok) throw new Error(`JSON fetch failed: HTTP ${res.status}`);
    const json = await res.json();
    if (!Array.isArray(json.tournaments)) throw new Error("JSON format error: tournaments missing");
    return json.tournaments;
  } catch (e) {
    console.warn("JSONの取得に失敗したためCSVにフォールバックします", e);
  }
  const Papa = (await import("papaparse")).default;
  return new Promise((resolve, reject) => {
    Papa.parse<RawRow>(CSV_URL, {
      download: true,
      header: true,
      skipEmptyLines: true,
      complete: (results) => resolve(results.data || []),
      error: (err) => reject(err),
    });
  });
}

function parseIntSafe(v: string | undefined): number | null {
  if (v == null) return null;
  const s = String(v).replace(/[,\s円]/g, "");
  if (s === "") return null;
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}

// prize_list の金額を合計する。
// 例: "50000/30000/20000", "5k, 3k, 2k", "5,000円 ×2 / 2,500", "1万/5千", "50,000 + Ticket"（非数値は無視）
function parsePrizeListSum(text: string | undefined): number | null {
  if (!text) return null;
  const s = String(text).replace(/［|］|【|】/g, "");
  let sum = 0;
  let found = false;
  const re = /(\d{1,3}(?:[,\d]{0,3})*(?:\.\d+)?|\d+(?:\.\d+)?)\s*(万|千|k|K|m|M|円)?\s*(?:[x×]\s*(\d+))?/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(s)) !== null) {
    let base = Number(m[1].replace(/,/g, ""));
    if (!Number.isFinite(base)) continue;
    switch (m[2] || "") {
      case "万": base *= 10000; break;
      case "千":
      case "k":
      case "K": base *= 1000; break;
      case "m":
      case "M": base *= 1000000; break;
    }
    const times = m[3] ? Number(m[3]) : 1;
    if (Number.isFinite(times) && times > 0) base *= times;
    sum += base;
    found = true;
  }
  return found ? Math.round(sum) : null;
}

// "2025/08/19 13:00" または "2025/08/19"
function parseDateTimeJP(s: string | undefined): Date | null {
  if (!s) return null;
  const [datePart, timePart] = String(s).trim().split(/\s+/);
  if (!datePart) return null;
  const [yy, mm, dd] = datePart.split(/[/-]/).map(Number);
  if (!yy || !mm || !dd) return null;
  if (timePart) {
    const [HH, MM = 0] = timePart.split(":").map(Number);
    return new Date(yy, mm - 1, dd, HH || 0, MM || 0);
  }
  return new Date(yy, mm - 1, dd);
}

function normalizeRow(row: RawRow): Tournament {
  const entryFee = parseIntSafe(row.entry_fee);
  const addOn = parseIntSafe(row.add_on);
  const guaranteed = parseIntSafe(row.guaranteed_amount);
  // prize_list の合計 → total_prize → guaranteed_amount の順で、正の値を採用
  const fromList = parsePrizeListSum(row.prize_list || row.prize_text);
  const prizeRaw = fromList || parseIntSafe(row.total_prize);
  const totalPrize = prizeRaw != null && prizeRaw > 0 ? prizeRaw : guaranteed;

  // 倍率 = 賞金総額 / (参加費 + アドオン)。サテライトは対象外、500以上は異常値として扱わない
  const title = row.title || "";
  const isSatellite = title.includes("サテ");
  const cost = (entryFee || 0) + (addOn || 0);
  let multiplier = !isSatellite && totalPrize != null && cost > 0 ? totalPrize / cost : null;
  if (multiplier != null && (!isFinite(multiplier) || multiplier <= 0 || multiplier >= 500)) multiplier = null;

  return {
    id: row.ID || "",
    shopName: row.shop_name || "",
    address: row.address || "",
    area: row.area || "",
    title,
    link: row.link || "",
    prizeText: (row.prize_text || "").replace(/\n+/g, " / "),
    date: parseDateTimeJP(row.date),
    start: parseDateTimeJP(row.start_time),
    lateReg: parseDateTimeJP(row.late_registration_time),
    entryFee,
    addOn,
    totalPrize,
    multiplier,
    isSatellite,
    searchText: Object.values(row).filter((v) => v != null).join("\n").toLowerCase(),
  };
}
