"""Serves the web build like GitHub Pages does.

    python tools/serve_web.py                  # build/web at http://localhost:5180/
    python tools/serve_web.py --base /tikky_takka/

Python's http.server takes MIME types from the Windows registry, where .js
is often text/plain; module scripts (CanvasKit) and service workers then
fail to load. Here the types are fixed. With --base the build is served
under that path, as on Pages (build with the same --base-href).
"""

import argparse
import functools
import http.server

TYPES = {
    ".js": "text/javascript",
    ".mjs": "text/javascript",
    ".wasm": "application/wasm",
    ".json": "application/json",
    ".html": "text/html",
    ".css": "text/css",
    ".png": "image/png",
    ".ttf": "font/ttf",
    ".otf": "font/otf",
}


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map, **TYPES}
    base = "/"

    def translate_path(self, path):
        if self.base != "/":
            if not path.startswith(self.base):
                return ""  # outside the base: 404
            path = "/" + path[len(self.base):]
        return super().translate_path(path)

    def end_headers(self):
        # Like a fresh deploy: no stale files while testing.
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=5180)
    parser.add_argument("--bind", default="0.0.0.0")
    parser.add_argument("--dir", default="build/web")
    parser.add_argument("--base", default="/")
    args = parser.parse_args()
    base = "/" + args.base.strip("/") + "/" if args.base.strip("/") else "/"
    handler = type("BaseHandler", (Handler,), {"base": base})
    handler = functools.partial(handler, directory=args.dir)
    print(f"http://localhost:{args.port}{base}")
    http.server.ThreadingHTTPServer((args.bind, args.port), handler).serve_forever()


if __name__ == "__main__":
    main()
