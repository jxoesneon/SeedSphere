/* SeedSphere Gardener PWA service worker */
const CACHE_NAME = 'gardener-cache-v1'
const PRECACHE_URLS = [
  '/gardener/',
  '/gardener/manifest.webmanifest',
  '/assets/gardener-background.svg',
]

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    try {
      const cache = await caches.open(CACHE_NAME)
      await cache.addAll(PRECACHE_URLS)
    } catch (_) {}
    self.skipWaiting()
  })())
})

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    try {
      const keys = await caches.keys()
      await Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    } catch (_) {}
    await self.clients.claim()
  })())
})

// Offline-first for gardener-scoped GET requests; network-first for others
self.addEventListener('fetch', (event) => {
  const req = event.request
  if (req.method !== 'GET') return
  const url = new URL(req.url)
  const isGardenerAsset = url.pathname.startsWith('/gardener/') || url.pathname.startsWith('/assets/')
  if (!isGardenerAsset) return
  event.respondWith((async () => {
    try {
      const cache = await caches.open(CACHE_NAME)
      // Stale-while-revalidate
      const cached = await cache.match(req)
      const networkPromise = fetch(req).then((res) => { try { cache.put(req, res.clone()) } catch (_) {}; return res })
      return cached || networkPromise
    } catch (_) {
      try { const cache = await caches.open(CACHE_NAME); const fallback = await cache.match(req); if (fallback) return fallback } catch (_) {}
      return fetch(req).catch(() => new Response('Offline', { status: 503 }))
    }
  })())
})
