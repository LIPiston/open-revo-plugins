"""Scan the WebView2 user-data folder for the host's real frontend CSS/JS text.

Looks for marker strings in three forms:
  * raw ASCII
  * raw UTF-16 little endian
  * gzip streams found inside the file (decompressed then re-searched)
Also reports the biggest readable-text hits so we can spot the stylesheet bundle.
"""
import os
import re
import sys
import zlib

ROOT = r"C:\Users\LIPis\AppData\Local\com.openrevo.controlcenter\EBWebView"

MARKERS = [
    "acrylic-container",
    "nav-tab",
    "data-skin",
    "openrevo-custom-skin",
    "mech-titlebar",
    "glass-card",
    "--accent-color",
    "index-C535NsqC",
    "mini-drawer-root",
]

CONTEXT = 260


def printable(buf):
    return "".join(chr(c) if 32 <= c < 127 else "." for c in buf)


def search(buf, markers):
    out = []
    for m in markers:
        for enc, pat in (("ascii", m.encode("ascii")), ("utf16", m.encode("utf-16-le"))):
            start = 0
            found = 0
            while found < 2:
                i = buf.find(pat, start)
                if i < 0:
                    break
                out.append((m, enc, i, printable(buf[max(0, i - 90): i + 200])))
                start = i + 1
                found += 1
    return out


def main():
    total_files = 0
    total_bytes = 0
    hits = []
    gzips = 0
    for dirpath, _dirs, files in os.walk(ROOT):
        for name in files:
            p = os.path.join(dirpath, name)
            try:
                if os.path.getsize(p) > 80 * 1024 * 1024:
                    continue
                buf = open(p, "rb").read()
            except Exception:
                continue
            total_files += 1
            total_bytes += len(buf)
            rel = os.path.relpath(p, ROOT)
            for h in search(buf, MARKERS):
                hits.append((rel, len(buf)) + h)
            # gzip members inside cache entries
            idx = 0
            tries = 0
            while tries < 4:
                idx = buf.find(b"\x1f\x8b\x08", idx)
                if idx < 0:
                    break
                try:
                    dec = zlib.decompressobj(16 + zlib.MAX_WBITS).decompress(buf[idx:], 8 * 1024 * 1024)
                except Exception:
                    dec = b""
                if dec and len(dec) > 200:
                    gzips += 1
                    for h in search(dec, MARKERS):
                        hits.append((rel + " [gunzip]", len(dec)) + h)
                idx += 3
                tries += 1

    print("scanned files=%d bytes=%.1fMB gzip-members-decoded=%d" % (total_files, total_bytes / 1048576.0, gzips))
    print("hits=%d" % len(hits))
    seen = set()
    for rel, size, marker, enc, off, ctx in hits:
        key = (marker, ctx[:120])
        if key in seen:
            continue
        seen.add(key)
        print("\n--- %s  size=%d  marker=%s/%s @%d" % (rel, size, marker, enc, off))
        print("    " + ctx)


if __name__ == "__main__":
    sys.exit(main())
