#!/usr/bin/env python3
"""
QDeck Wallpaper Thumbnail Generator
Pre-generates lightweight 392x220 JPEG thumbnails for theme and wallpaper
carousels in ~/.cache/qdeck/thumbs/ so carousel rendering is instantaneous.
"""

import os
import sys
import json
import hashlib
from PIL import Image, ImageOps

THUMB_SIZE = (392, 220)


def get_thumb_dir():
    cache_home = os.environ.get("XDG_CACHE_HOME", os.path.join(os.path.expanduser("~"), ".cache"))
    thumb_dir = os.path.join(cache_home, "qdeck", "thumbs")
    os.makedirs(thumb_dir, exist_ok=True)
    return thumb_dir


def generate_thumb(src_path, thumb_dir):
    try:
        real_path = os.path.realpath(src_path)
        if not os.path.isfile(real_path):
            return src_path

        st = os.stat(real_path)
        key_str = f"{real_path}:{int(st.st_mtime)}:{st.st_size}"
        digest = hashlib.md5(key_str.encode("utf-8")).hexdigest()
        thumb_path = os.path.join(thumb_dir, f"{digest}.jpg")

        if os.path.isfile(thumb_path):
            return thumb_path

        with Image.open(real_path) as img:
            if img.mode not in ("RGB", "L"):
                img = img.convert("RGB")
            elif img.mode == "L":
                img = img.convert("RGB")
            fitted = ImageOps.fit(img, THUMB_SIZE, method=Image.Resampling.LANCZOS)
            tmp_path = thumb_path + ".tmp"
            fitted.save(tmp_path, format="JPEG", quality=88, optimize=True)
            os.replace(tmp_path, thumb_path)

        return thumb_path
    except Exception:
        return src_path


def main():
    thumb_dir = get_thumb_dir()
    paths = []

    if len(sys.argv) > 1:
        paths = sys.argv[1:]
    else:
        raw = sys.stdin.read().strip()
        if raw:
            try:
                parsed = json.loads(raw)
                if isinstance(parsed, list):
                    paths = [str(p) for p in parsed if p]
            except Exception:
                paths = [line.strip() for line in raw.splitlines() if line.strip()]

    result = {}
    for p in paths:
        result[p] = generate_thumb(p, thumb_dir)

    print(json.dumps(result))


if __name__ == "__main__":
    main()

