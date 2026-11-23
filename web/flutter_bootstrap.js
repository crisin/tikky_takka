{{flutter_js}}
{{flutter_build_config}}

// No serviceWorkerSettings: Flutter's own service worker is deprecated and
// only unregisters itself – it would also remove ours (same scope). Ours is
// registered in index.html.
_flutter.loader.load();
