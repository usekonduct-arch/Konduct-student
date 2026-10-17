{{flutter_js}}
{{flutter_build_config}}

// CanvasKit is served from this site (build/web/canvaskit/) rather than Google's CDN, so the app
// opens offline once installed and draws exactly the same everywhere.
_flutter.loader.load({
  config: { canvasKitBaseUrl: "canvaskit/" },
});

// Our own service worker (sw.js), not Flutter's offline-first one: network first, so a new
// deploy is picked up on the next launch, with the cached copy as the offline fallback.
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("sw.js").catch((e) => console.warn("service worker:", e));
  });
}
