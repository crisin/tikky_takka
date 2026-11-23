// Offline service worker for the web build.
//
// `tools/web_pwa.dart` fills in the placeholders after `flutter build web`
// (build version, engine revision, the files to precache). Unfilled – as in
// `flutter run -d chrome` – the worker removes itself and intercepts nothing.
//
// * The app files go into one cache per build ("tikky-<version>"), the
//   CanvasKit renderer into one cache per engine revision, so an app update
//   does not download CanvasKit again.
// * Everything is served cache first; a new build becomes active on the next
//   start (the browser checks sw.js for changes on every start).
// * Which CanvasKit variant the browser loads is only known in the page, so
//   the page reports the files it loaded ("cache" message) and they are
//   cached here.
'use strict';

const VERSION = '__TIKKY_VERSION__';
const ENGINE = '__TIKKY_ENGINE__';
const CORE = [/* __TIKKY_CORE__ */];

const filled = !VERSION.startsWith('__');
const APP_CACHE = `tikky-${VERSION}`;
const RENDERER_CACHE = `tikky-canvaskit-${ENGINE}`;
const scope = new URL('./', self.location).href;

const cacheFor = (url) =>
  url.startsWith(`${scope}canvaskit/`) ? RENDERER_CACHE : APP_CACHE;

self.addEventListener('install', (event) => {
  self.skipWaiting();
  if (!filled) return;
  event.waitUntil(
    caches.open(APP_CACHE).then((cache) =>
      // Bypass the HTTP cache: a stale main.dart.js must not end up in the
      // cache of a newer version.
      cache.addAll(CORE.map((path) => new Request(path, { cache: 'reload' }))),
    ),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      if (!filled) {
        await self.registration.unregister();
        return;
      }
      const keep = [APP_CACHE, RENDERER_CACHE];
      for (const key of await caches.keys()) {
        if (key.startsWith('tikky-') && !keep.includes(key)) {
          await caches.delete(key);
        }
      }
      await self.clients.claim();
    })(),
  );
});

async function fromCacheOrNetwork(request) {
  const cache = await caches.open(cacheFor(request.url));
  const hit = await cache.match(request);
  if (hit) return hit;
  const response = await fetch(request);
  if (response.ok && response.type === 'basic') {
    await cache.put(request, response.clone());
  }
  return response;
}

async function appShell(request) {
  const cache = await caches.open(APP_CACHE);
  const hit = await cache.match(scope);
  if (hit) return hit;
  return fetch(request);
}

self.addEventListener('fetch', (event) => {
  if (!filled) return;
  const request = event.request;
  if (request.method !== 'GET' || !request.url.startsWith(scope)) return;
  // The worker file itself always comes from the network.
  if (request.url === self.location.href) return;
  if (request.mode === 'navigate') {
    event.respondWith(appShell(request));
    return;
  }
  event.respondWith(fromCacheOrNetwork(request));
});

self.addEventListener('message', (event) => {
  if (!filled || event.data?.type !== 'cache') return;
  const urls = (event.data.urls ?? []).filter(
    (url) => typeof url === 'string' && url.startsWith(scope),
  );
  event.waitUntil(
    Promise.all(
      urls.map(async (url) => {
        const cache = await caches.open(cacheFor(url));
        if (await cache.match(url)) return;
        try {
          const response = await fetch(url);
          if (response.ok) await cache.put(url, response);
        } catch (_) {
          // Offline: try again on the next start.
        }
      }),
    ),
  );
});
