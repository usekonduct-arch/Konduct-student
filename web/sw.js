// Konduct web app service worker: makes the app installable and lets it open without a connection.
//
// Network first for everything on this site, so riders always run the latest deploy when online;
// each answer is kept, and served when the network is down. Other sites (Firebase, the backend,
// Bachs) are never touched. Push notifications are handled by firebase-messaging-sw.js.
const CACHE = "konduct-web-v1";

self.addEventListener("install", () => self.skipWaiting());

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      for (const key of await caches.keys()) if (key !== CACHE) await caches.delete(key);
      await self.clients.claim();
    })(),
  );
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;
  if (url.pathname.endsWith("/sw.js") || url.pathname.endsWith("/firebase-messaging-sw.js")) return;

  event.respondWith(
    (async () => {
      try {
        const res = await fetch(req);
        // Keeping a copy is best effort: storage can be full or off (private browsing).
        if (res.ok && res.type === "basic") {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => {});
        }
        return res;
      } catch (e) {
        // Offline. A page load with a shortcut's ?action=… still gets the app shell.
        const match = (r, o) => caches.match(r, { cacheName: CACHE, ...o }).catch(() => undefined);
        const hit = await match(req, { ignoreSearch: req.mode === "navigate" });
        if (hit) return hit;
        if (req.mode === "navigate") {
          const shell = (await match("./")) || (await match("index.html"));
          if (shell) return shell;
        }
        throw e;
      }
    })(),
  );
});
