/**
 * Mordecai's Maximus — Service Worker
 *
 * HOW TO TEST UPDATES:
 * 1. Load app in browser, ensure SW is active (check DevTools → Application → Service Workers)
 * 2. Change CACHE_NAME below to mordecai-maximus-cache-v2 (bump the version)
 * 3. Restart server (or ensure sw.js is not cached by server/CDN)
 * 4. Reload the page — "Update available" toast should appear
 * 5. Tap the toast → page reloads with the new version
 * 6. (Optional) Tap the × to dismiss — toast hides, no reload
 *
 * FLOW: On deploy, bump CACHE_NAME version → browser detects new sw.js byte-diff →
 * new SW installs but stays "waiting" (no skipWaiting in install) → page shows toast →
 * user taps → postMessage('skipWaiting') → new SW activates → controllerchange → reload.
 *
 * TRUE push notifications: receive & show alerts even when app is closed.
 * The browser's push service delivers to this SW; we display the notification.
 */

// Keep this in sync with asset query versions in index.html.
const CACHE_NAME = "mordecai-maximus-cache-v5";
const ASSET_VERSION = "6";
const RUNTIME_CONFIG_VERSION = "2";
const STATIC_ASSETS = [
  "/",
  "/index.html",
  `/css/base.css?v=${ASSET_VERSION}`,
  `/css/mordecai.css?v=${ASSET_VERSION}`,
  `/js/backend-url.js?v=${ASSET_VERSION}`,
  `/js/mordecai.js?v=${ASSET_VERSION}`,
  `/js/push-client.js?v=${ASSET_VERSION}`,
  `/js/runtime-config.js?v=${RUNTIME_CONFIG_VERSION}`,
  "/manifest.json",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_ASSETS).catch((err) => {
        console.error("[SW] Precache failed:", err);
        throw err;
      });
    })
  );
  // Do NOT call skipWaiting() here — we want the new SW to stay "waiting"
  // until the user taps the update toast and we postMessage('skipWaiting')
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((names) => {
      return Promise.all(
        names.filter((n) => n !== CACHE_NAME).map((n) => caches.delete(n))
      );
    })
  );
  self.clients.claim();
});

// Listen for skipWaiting request from the page (when user taps update toast)
self.addEventListener("message", (event) => {
  if (event.data?.type === "skipWaiting") {
    self.skipWaiting();
  }
});

self.addEventListener("push", (event) => {
  // Handle push even when app/tab is closed — this is TRUE push notification
  let data = { title: "Mordecai's Maximus", body: "New notification" };
  if (event.data) {
    try {
      data = { ...data, ...JSON.parse(event.data.text()) };
    } catch (_) {}
  }
  const options = {
    body: data.body,
    tag: data.tag || "mordecai",
    icon: "/icon-192.png",
    badge: "/icon-192.png",
    vibrate: [200, 100, 200], // Vibration for mobile — ensures you notice
    requireInteraction: false,
    data: { url: data.url || "/" },
  };
  event.waitUntil(
    self.registration.showNotification(data.title || "Mordecai's Maximus", options)
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const path = event.notification.data?.url || "/";
  const fullUrl = path.startsWith("http") ? path : new URL(path, self.registration.scope).href;
  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((clients) => {
      for (const client of clients) {
        if (client.url.startsWith(self.registration.scope) && "focus" in client) {
          client.navigate(fullUrl);
          return client.focus();
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(fullUrl);
      }
    })
  );
});

self.addEventListener("fetch", (event) => {
  // API, sw.js, manifest, HTML — always network (no cache). Ensures fresh content.
  if (
    event.request.url.includes("/api/") ||
    event.request.url.includes("/sw.js") ||
    event.request.url.includes("/manifest.json") ||
    event.request.url.includes("/js/runtime-config.js") ||
    event.request.mode === "navigate"
  ) {
    event.respondWith(fetch(event.request));
    return;
  }
  // Static assets: cache-first with network fallback + cache update.
  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) return cached;
      return fetch(event.request).then((res) => {
        if (
          res &&
          res.ok &&
          event.request.method === "GET" &&
          event.request.url.startsWith(self.location.origin)
        ) {
          const copy = res.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, copy).catch(() => {});
          });
        }
        return res;
      });
    })
  );
});
