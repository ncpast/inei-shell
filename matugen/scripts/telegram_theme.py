#!/usr/bin/env python3
"""Pack matugen's Telegram colours into an installable .tdesktop-theme (post_hook of [templates.telegram]).

matugen writes   ~/.cache/matugen/telegram/colors-raw.txt   (not importable on purpose)
this makes       ~/.cache/matugen/matugen.tdesktop-theme   (zip: colors + a solid chat background) <- the one to import

The chat background is a 1x1 png in the window background colour (windowBg), so the chat area is the
same flat colour as the rest of the app instead of Telegram's wallpaper. Same trick as Telegram's
own night theme.
"""
import os, re, struct, sys, zipfile, zlib

cache = os.path.expanduser("~/.cache/matugen")
src = os.path.join(cache, "telegram", "colors-raw.txt")
out = os.path.join(cache, "matugen.tdesktop-theme")

colors = open(src).read()
m = re.search(r"^windowBg:\s*#([0-9a-fA-F]{6})", colors, re.M)
if not m:
    sys.exit("telegram_theme: windowBg not found in " + src)
r, g, b = (int(m.group(1)[i:i + 2], 16) for i in (0, 2, 4))

def chunk(tag, data):
    body = tag + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

png = (b"\x89PNG\r\n\x1a\n"
       + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))     # 1x1, 8-bit RGB
       + chunk(b"IDAT", zlib.compress(bytes([0, r, g, b])))
       + chunk(b"IEND", b""))

with zipfile.ZipFile(out + ".tmp", "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("colors.tdesktop-theme", colors)
    z.writestr("background.png", png)
os.replace(out + ".tmp", out)
print("telegram theme:", out)
