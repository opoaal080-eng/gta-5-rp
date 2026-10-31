#!/usr/bin/env python3
"""Read-only LAN HTTP Range server for personally owned Five Star Port WEB assets.
This is an exploratory asset server, NOT a GTA5RP multiplayer server. Private networks only.
"""
import argparse
import mimetypes
import pathlib
import re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote, urlsplit
RANGE = re.compile(r"^bytes=(\d*)-(\d*)$")
def make_handler(root):
    root = pathlib.Path(root).resolve(strict=True)
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self): self.serve(False)
        def do_HEAD(self): self.serve(True)
        def serve(self, head):
            name = unquote(urlsplit(self.path).path)
            parts = name.lstrip("/").split("/")
            if not name.startswith("/") or "\\" in name or any(x in ("", ".", "..") for x in parts):
                self.send_error(400); return
            file = root.joinpath(*parts).resolve()
            if not file.is_relative_to(root) or not file.is_file():
                self.send_error(404); return
            size = file.stat().st_size
            first, last, partial = 0, size-1, False
            if self.headers.get("Range"):
                m = RANGE.fullmatch(self.headers["Range"].strip())
                if not m or not any(m.groups()):
                    self.reject_range(size); return
                a,b = m.groups()
                if a: first,last=int(a),int(b) if b else size-1
                else: first,last=max(0,size-int(b)),size-1
                if first >= size or last < first:
                    self.reject_range(size);return
                last=min(last,size-1)
                partial=True
            count=last-first+1 if size else 0
            self.send_response(206 if partial else 200)
            self.send_header("Content-Length",str(count))
            self.send_header("Accept-Ranges","bytes")
            self.send_header("Content-Type",mimetypes.guess_type(file.name)[0] or "application/octet-stream")
            if partial: self.send_header("Content-Range",f"bytes {first}-{last}/{size}")
            self.end_headers()
            if head:return
            with file.open("rb") as stream:
                stream.seek(first)
                while count:
                    block=stream.read(min(count,1024*1024))
                    if not block:break
                    self.wfile.write(block);count-=len(block)
        def reject_range(self,size):
            self.send_response(416)
            self.send_header("Content-Range",f"bytes */{size}")
            self.send_header("Content-Length","0")
            self.end_headers()
    return Handler
if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--game-root",required=True)
    p.add_argument("--bind",default="127.0.0.1")
    p.add_argument("--port",type=int,default=8765)
    args=p.parse_args()
    root=pathlib.Path(args.game_root)
    if not (root/"data").is_dir() or not (root/"b").is_dir():
        p.error("Expected web game build root containing data/ and b/")
    app=ThreadingHTTPServer((args.bind,args.port),make_handler(root))
    print("TEST ONLY: http://%s:%d/ (private network, do not expose publicly)"%(args.bind,args.port))
    try:app.serve_forever()
    except KeyboardInterrupt:pass
    finally:app.server_close()
