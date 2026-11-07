import type { Tournament } from "../lib/data";

// 一覧の区切り（お気に入りの店 / その他）。title が null なら見出しなし
export type Section = { title: string | null; rows: Tournament[] };

// スマホ一覧・PC表で共通の行まわりの情報と操作
export type RowContext = {
  now: Date;
  bestKey: string | null; // 最高倍率の行（rowKey）
  favorites: Set<string>; // お気に入りの店名
  onToggleFavorite: (shopName: string) => void;
  onOpen: (t: Tournament) => void;
  onShopClick: (shopName: string) => void;
};

export const rowKey = (t: Tournament) => t.id + t.title;
