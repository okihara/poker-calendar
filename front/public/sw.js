const CACHE_NAME = 'poker-search-v3';
// JS/CSS はビルドごとにファイル名が変わるため、ここでは固定ファイルのみ事前キャッシュする
const STATIC_ASSETS = [
  '/',
  '/manifest.json',
  '/images/logo.png',
  '/images/icon-192.png',
  '/images/icon-512.png',
];

// Install: cache static assets
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(STATIC_ASSETS))
  );
  self.skipWaiting();
});

// Activate: clean up old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))
      )
    )
  );
  self.clients.claim();
});

// Fetch: network-first for CSV data, cache-first for static assets
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Only handle http(s) GET requests. Skip chrome-extension:// and other
  // unsupported schemes that the Cache API cannot store.
  if (event.request.method !== 'GET' || !url.protocol.startsWith('http')) {
    return;
  }

  // Network-first for tournament data (Vercel Blob JSON / Google Sheets CSV)
  if (
    url.hostname.includes('google') ||
    url.hostname.includes('googleapis') ||
    url.hostname.endsWith('vercel-storage.com')
  ) {
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
          return response;
        })
        .catch(() => caches.match(event.request))
    );
    return;
  }

  // Network-first for page navigations (新しいビルドの index.html を優先して取得)
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put('/', clone));
          return response;
        })
        .catch(() => caches.match('/'))
    );
    return;
  }

  // Cache-first for static assets
  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) {
        // Background update
        fetch(event.request).then((response) => {
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, response));
        }).catch(() => {});
        return cached;
      }
      return fetch(event.request).then((response) => {
        const clone = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
        return response;
      });
    })
  );
});
