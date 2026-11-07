import { useEffect, useRef, useState } from "react";

// 大会ページを iframe のモーダルで表示する
export function ExternalDialog({ url, onClose }: { url: string | null; onClose: () => void }) {
  const ref = useRef<HTMLDialogElement>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    if (url) {
      setLoading(true);
      if (!d.open) d.showModal();
    } else if (d.open) {
      d.close();
    }
  }, [url]);

  // 外部サイトから戻ったときにダイアログを閉じる
  useEffect(() => {
    window.addEventListener("pageshow", onClose);
    return () => window.removeEventListener("pageshow", onClose);
  }, [onClose]);

  return (
    <dialog
      ref={ref}
      onClose={onClose}
      onClick={(e) => e.target === ref.current && onClose()}
      className="m-auto h-[90dvh] w-[94vw] max-w-[900px] overflow-hidden rounded-xl bg-white p-0"
    >
      <div className="relative flex h-full flex-col">
        {loading && (
          <div className="absolute inset-0 bottom-12 flex items-center justify-center bg-white">
            <div className="h-8 w-8 animate-spin rounded-full border-4 border-slate-200 border-t-slate-700" />
          </div>
        )}
        {url && (
          <iframe src={url} onLoad={() => setLoading(false)} sandbox="allow-scripts allow-same-origin allow-popups" className="w-full flex-1 border-0" />
        )}
        <button type="button" onClick={onClose} className="shrink-0 bg-slate-800 py-3.5 text-base font-semibold text-white hover:bg-slate-700">
          閉じる
        </button>
      </div>
    </dialog>
  );
}
