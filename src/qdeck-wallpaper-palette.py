#!/usr/bin/env python3
"""
QDeck Wallpaper & Theme Palette Extractor
Fast, cached color extractor that harmonizes wallpaper colors with theme tokens.
Designed for 165Hz smooth dynamic bar and widget theming.
"""

import sys
import os
import json
import hashlib
import colorsys
from PIL import Image

def get_wallpaper_palette(wallpaper_path=None, theme_colors_path=None):
    home = os.environ.get("HOME", "/home/ribs")
    if not wallpaper_path:
        wallpaper_path = os.path.join(home, ".config/themes/current/default.png")
    
    if not os.path.exists(wallpaper_path):
        # Fallback if no wallpaper found
        return {
            "wallpaper": "",
            "accent": "#7daea3",
            "dominant": "#a29972",
            "background": "#232420",
            "dark_background": "#1a1b18",
            "lighter_background": "#33352d",
            "border": "#7daea3"
        }
    
    real_path = os.path.realpath(wallpaper_path)
    
    # Fast cache check using file path and mtime
    try:
        mtime = os.path.getmtime(real_path)
    except OSError:
        mtime = 0
        
    cache_key = hashlib.md5(f"{real_path}:{mtime}".encode()).hexdigest()
    cache_path = f"/tmp/qs-palette-{cache_key}.json"
    
    if os.path.exists(cache_path):
        try:
            with open(cache_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass

    # Read current theme accent as fallback / blend anchor if available
    theme_accent = None
    if not theme_colors_path:
        theme_colors_path = os.path.join(home, ".config/themes/current/colors.toml")
    if os.path.exists(theme_colors_path):
        try:
            with open(theme_colors_path, "r", encoding="utf-8") as f:
                for line in f:
                    if line.strip().startswith("accent"):
                        parts = line.split("=")
                        if len(parts) > 1:
                            val = parts[1].split("#")[0].split(";")[0].strip().strip('"\'')
                            if val:
                                theme_accent = val if val.startswith("#") else f"#{val}"
                                break
        except Exception:
            pass

    try:
        with Image.open(real_path) as im:
            # Fast downsampling for high-performance extraction (<100ms)
            im.thumbnail((128, 128))
            im_rgb = im.convert("RGB")
            pal_img = im_rgb.convert("P", palette=Image.ADAPTIVE, colors=16)
            raw_pal = pal_img.getpalette()[:48]

            colors = []
            for i in range(0, len(raw_pal), 3):
                r, g, b = raw_pal[i], raw_pal[i+1], raw_pal[i+2]
                h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
                colors.append({
                    "hex": f"#{r:02x}{g:02x}{b:02x}",
                    "r": r, "g": g, "b": b,
                    "h": h, "s": s, "v": v
                })

            # 1. Best vibrant accent from wallpaper
            accent_candidates = [c for c in colors if c["s"] > 0.18 and c["v"] > 0.35]
            if accent_candidates:
                best_accent = max(accent_candidates, key=lambda c: c["s"] * 0.65 + c["v"] * 0.35)["hex"]
            elif theme_accent:
                best_accent = theme_accent
            else:
                best_accent = max(colors, key=lambda c: c["v"])["hex"]

            # 2. Dominant tone from wallpaper
            dominant = colors[0]["hex"]

            # 3. Darkest tone for rich wallpaper-tinted dark background
            dark_candidates = sorted(colors, key=lambda c: c["v"])
            darkest = dark_candidates[0]

            # Blend 35% darkest wallpaper tone with 65% deep charcoal (#181818) for ultra-clean UI contrast
            bg_r = int(darkest["r"] * 0.35 + 24 * 0.65)
            bg_g = int(darkest["g"] * 0.35 + 24 * 0.65)
            bg_b = int(darkest["b"] * 0.35 + 24 * 0.65)
            bg_hex = f"#{bg_r:02x}{bg_g:02x}{bg_b:02x}"

            # Secondary elevated dark surface (for widget pills / cards)
            dark_bg_r = max(0, int(bg_r * 0.72))
            dark_bg_g = max(0, int(bg_g * 0.72))
            dark_bg_b = max(0, int(bg_b * 0.72))
            dark_bg_hex = f"#{dark_bg_r:02x}{dark_bg_g:02x}{dark_bg_b:02x}"

            # Hover & active surface
            light_bg_r = min(255, int(bg_r * 1.35 + 12))
            light_bg_g = min(255, int(bg_g * 1.35 + 12))
            light_bg_b = min(255, int(bg_b * 1.35 + 12))
            light_bg_hex = f"#{light_bg_r:02x}{light_bg_g:02x}{light_bg_b:02x}"

            data = {
                "wallpaper": real_path,
                "accent": best_accent,
                "dominant": dominant,
                "background": bg_hex,
                "dark_background": dark_bg_hex,
                "lighter_background": light_bg_hex,
                "border": best_accent
            }

            try:
                with open(cache_path, "w", encoding="utf-8") as f:
                    json.dump(data, f)
            except Exception:
                pass

            return data

    except Exception as e:
        return {
            "wallpaper": real_path if "real_path" in locals() else "",
            "accent": theme_accent or "#7daea3",
            "dominant": "#a29972",
            "background": "#232420",
            "dark_background": "#1a1b18",
            "lighter_background": "#33352d",
            "border": theme_accent or "#7daea3",
            "error": str(e)
        }

if __name__ == "__main__":
    wp = sys.argv[1] if len(sys.argv) > 1 else None
    result = get_wallpaper_palette(wp)
    print(json.dumps(result))
