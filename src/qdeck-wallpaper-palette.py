#!/usr/bin/env python3
"""
QDeck Theme & Wallpaper Color Extractor
Parses the active theme's colors.toml accurately (Nord, Gruvbox, Catppuccin, etc.)
and harmonizes with wallpaper presence for authentic glassmorphism.
"""

import sys
import os
import re
import json
import hashlib
from PIL import Image

def get_wallpaper_palette(wallpaper_path=None, theme_colors_path=None):
    home = os.environ.get("HOME", "/home/ribs")
    if not wallpaper_path:
        wallpaper_path = os.path.join(home, ".config/themes/current/default.png")
    
    if not theme_colors_path:
        theme_colors_path = os.path.join(home, ".config/themes/current/colors.toml")

    # Resolve real path to follow symlinks accurately
    real_theme_path = os.path.realpath(theme_colors_path) if os.path.exists(theme_colors_path) else ""
    real_wp_path = os.path.realpath(wallpaper_path) if os.path.exists(wallpaper_path) else ""

    theme_tokens = {}
    if real_theme_path and os.path.exists(real_theme_path):
        try:
            with open(real_theme_path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#") or line.startswith(";"):
                        continue
                    m = re.match(r"^([a-zA-Z0-9_-]+)\s*=\s*[\"']?([#0-9a-zA-Z]+)", line)
                    if m:
                        val = m.group(2)
                        if not val.startswith("#") and len(val) in (3, 6, 8):
                            val = f"#{val}"
                        theme_tokens[m.group(1)] = val
        except Exception:
            pass

    # Fallbacks if a key is missing
    accent = theme_tokens.get("accent", "#88c0d0")
    background = theme_tokens.get("background", "#2e3440")
    dark_background = theme_tokens.get("dark_background", "#242933")
    lighter_background = theme_tokens.get("lighter_background", "#3b4252")
    selection = theme_tokens.get("selection", "#3b4252")
    foreground = theme_tokens.get("foreground", "#d8dee9")
    muted = theme_tokens.get("muted", "#616e88")

    # Fast cache check using resolved file path and mtime
    try:
        wp_mtime = os.path.getmtime(real_wp_path) if real_wp_path else 0
        th_mtime = os.path.getmtime(real_theme_path) if real_theme_path else 0
    except OSError:
        wp_mtime = 0
        th_mtime = 0
        
    cache_key = hashlib.md5(f"{real_theme_path}:{th_mtime}:{real_wp_path}:{wp_mtime}".encode()).hexdigest()
    cache_path = f"/tmp/qs-palette-{cache_key}.json"
    
    if os.path.exists(cache_path):
        try:
            with open(cache_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass

    dominant = "#88c0d0"
    wallpaper_tint = None

    if real_wp_path and os.path.exists(real_wp_path):
        try:
            with Image.open(real_wp_path) as im:
                im.thumbnail((128, 128))
                im_rgb = im.convert("RGB")
                pal_img = im_rgb.convert("P", palette=Image.ADAPTIVE, colors=8)
                raw_pal = pal_img.getpalette()[:24]

                colors = []
                for i in range(0, len(raw_pal), 3):
                    r, g, b = raw_pal[i], raw_pal[i+1], raw_pal[i+2]
                    colors.append(f"#{r:02x}{g:02x}{b:02x}")

                if colors:
                    dominant = colors[0]
                    wallpaper_tint = colors[-1]
        except Exception:
            pass

    def hex_to_rgb(h):
        h = h.lstrip("#")
        if len(h) == 3:
            h = "".join(c * 2 for c in h)
        return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

    def blend_hex(h1, h2, w1=0.5):
        try:
            rgb1 = hex_to_rgb(h1)
            rgb2 = hex_to_rgb(h2)
            w2 = 1.0 - w1
            r = int(rgb1[0] * w1 + rgb2[0] * w2)
            g = int(rgb1[1] * w1 + rgb2[1] * w2)
            b = int(rgb1[2] * w1 + rgb2[2] * w2)
            return f"#{r:02x}{g:02x}{b:02x}"
        except Exception:
            return h1

    glass_tint = blend_hex(accent, dominant, 0.40)
    glass_surface = blend_hex(dominant, background, 0.28)
    glass_crest = blend_hex(dominant, "#ffffff", 0.35)
    glass_border = blend_hex(accent, dominant, 0.60)

    data = {
        "wallpaper": real_wp_path,
        "accent": accent,
        "dominant": dominant,
        "background": background,
        "dark_background": dark_background,
        "lighter_background": lighter_background,
        "selection": selection,
        "foreground": foreground,
        "muted": muted,
        "border": accent,
        "wallpaper_tint": wallpaper_tint or dark_background,
        "glass_tint": glass_tint,
        "glass_surface": glass_surface,
        "glass_crest": glass_crest,
        "glass_border": glass_border
    }

    try:
        with open(cache_path, "w", encoding="utf-8") as f:
            json.dump(data, f)
    except Exception:
        pass

    return data

if __name__ == "__main__":
    wp = sys.argv[1] if len(sys.argv) > 1 else None
    result = get_wallpaper_palette(wp)
    print(json.dumps(result))
