// Bump CACHE on every change you ship, or installed phones keep the old version.
const CACHE = "pax-v23";
const SHELL = ["./", "index.html", "pax-db.js", "config.js", "manifest.webmanifest", "illustrations/tomato.png", "illustrations/peas.png", "illustrations/carrots.png", "icon-192.png", "apple-touch-icon.png"];

self.addEventListener("install", e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting())); });
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
// The app shell: network first so updates land, cache when offline. Supabase calls are never cached.
self.addEventListener("fetch", e => {
  const url = new URL(e.request.url);
  if (e.request.method !== "GET" || url.origin !== location.origin) return;
  e.respondWith(fetch(e.request).then(res => {
    const copy = res.clone(); caches.open(CACHE).then(c => c.put(e.request, copy)); return res;
  }).catch(() => caches.match(e.request).then(r => r || caches.match("index.html"))));
});
