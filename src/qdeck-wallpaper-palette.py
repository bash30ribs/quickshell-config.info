#!/usr/bin/env python3
"""
QDeck Dynamic Wallpaper & Harmony Color Extractor
Extracts dominant, vibrant, and optical tokens from the active wallpaper
and harmonizes with the theme colors for authentic glassmorphism across
ALL themes (Gruvbox, Everforest, Tokyo-Night, Nord, Catppuccin, etc.).
"""

import sys
import os
import re
import json
import hashlib
import colorsys
import subprocess
from PIL import Image
from collections import Counter


def hex_to_rgb(h):
    h = h.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def rgb_to_hex(r, g, b):
    return f"#{int(r):02x}{int(g):02x}{int(b):02x}"


def blend_hex(h1, h2, w1=0.5):
    try:
        rgb1 = hex_to_rgb(h1)
        rgb2 = hex_to_rgb(h2)
        w2 = 1.0 - w1
        r = int(rgb1[0] * w1 + rgb2[0] * w2)
        g = int(rgb1[1] * w1 + rgb2[1] * w2)
        b = int(rgb1[2] * w1 + rgb2[2] * w2)
        return rgb_to_hex(r, g, b)
    except Exception:
        return h1


def detect_active_wallpaper():
    home = os.environ.get("HOME", "/home/ribs")
    # 1. Check awww query if daemon is running
    try:
        out = subprocess.check_output(["awww", "query"], stderr=subprocess.DEVNULL, text=True)
        for line in out.splitlines():
            if "image:" in line:
                p = line.split("image:")[-1].strip()
                if os.path.exists(p):
                    return os.path.realpath(p)
    except Exception:
        pass

    # 2. Check swww query if daemon is running
    try:
        out = subprocess.check_output(["swww", "query"], stderr=subprocess.DEVNULL, text=True)
        for line in out.splitlines():
            if "image:" in line:
                p = line.split("image:")[-1].strip()
                if os.path.exists(p):
                    return os.path.realpath(p)
    except Exception:
        pass

    # 3. Check current theme default.png symlink
    default_link = os.path.join(home, ".config/themes/current/default.png")
    if os.path.exists(default_link):
        return os.path.realpath(default_link)

    return ""


def get_wallpaper_palette(wallpaper_path=None, theme_colors_path=None):
    home = os.environ.get("HOME", "/home/ribs")
    if not wallpaper_path:
        wallpaper_path = detect_active_wallpaper()

    if not theme_colors_path:
        theme_colors_path = os.path.join(home, ".config/themes/current/colors.toml")

    real_theme_path = os.path.realpath(theme_colors_path) if os.path.exists(theme_colors_path) else ""
    real_wp_path = os.path.realpath(wallpaper_path) if (wallpaper_path and os.path.exists(wallpaper_path)) else ""

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

    # Base theme fallback tokens
    theme_accent = theme_tokens.get("accent", "#7daea3")
    background = theme_tokens.get("background", "#282828")
    dark_background = theme_tokens.get("dark_background", "#1d2021")
    lighter_background = theme_tokens.get("lighter_background", "#3c3836")
    selection = theme_tokens.get("selection", "#3c3836")
    foreground = theme_tokens.get("foreground", "#ebdbb2")
    muted = theme_tokens.get("muted", "#7c6f64")

    # Fast cache check using resolved file paths and mtimes
    try:
        wp_mtime = os.path.getmtime(real_wp_path) if real_wp_path else 0
        th_mtime = os.path.getmtime(real_theme_path) if real_theme_path else 0
    except OSError:
        wp_mtime = 0
        th_mtime = 0

    cache_key = hashlib.md5(f"dyn-v3:{real_theme_path}:{th_mtime}:{real_wp_path}:{wp_mtime}".encode()).hexdigest()
    cache_path = f"/tmp/qs-palette-{cache_key}.json"

    if os.path.exists(cache_path):
        try:
            with open(cache_path, "r", encoding="utf-8") as f:
                cached_data = json.load(f)
                # Keep persistent state file synchronized
                try:
                    persistent_dir = os.path.join(home, ".local/state/qdeck")
                    os.makedirs(persistent_dir, exist_ok=True)
                    persistent_file = os.path.join(persistent_dir, "wallpaper-palette.json")
                    with open(persistent_file, "w", encoding="utf-8") as pf:
                        json.dump(cached_data, pf, indent=2)
                        pf.flush()
                except Exception:
                    pass
                return cached_data
        except Exception:
            pass

    extracted_accent = None
    dominant_color = None
    top_area_luminance = 45.0  # Default dark background

    if real_wp_path and os.path.exists(real_wp_path):
        try:
            with Image.open(real_wp_path) as im:
                im_rgb = im.convert("RGB")
                w, h = im_rgb.size

                # Measure top bar region luminance to adapt glass opacity & prevent blindness
                top_crop = im_rgb.crop((0, 0, w, min(60, h)))
                top_crop.thumbnail((80, 20))
                top_data = list(top_crop.get_flattened_data() if hasattr(top_crop, "get_flattened_data") else top_crop.getdata())
                if top_data:
                    lum_sum = sum(0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2] for p in top_data)
                    top_area_luminance = lum_sum / len(top_data)

                # Quantize thumbnail for dominant and accent extraction
                im_thumb = im_rgb.copy()
                im_thumb.thumbnail((160, 160))
                quantized = im_thumb.quantize(colors=32, method=Image.MEDIANCUT)
                raw_palette = quantized.getpalette()[:32*3]
                raw_data = quantized.get_flattened_data() if hasattr(quantized, "get_flattened_data") else quantized.getdata()
                color_counts = Counter(raw_data)

                candidates = []
                max_count = 0

                for idx, count in color_counts.items():
                    r = raw_palette[idx*3]
                    g = raw_palette[idx*3 + 1]
                    b = raw_palette[idx*3 + 2]
                    h_val, s_val, v_val = colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)

                    if count > max_count:
                        max_count = count
                        dominant_color = rgb_to_hex(r, g, b)

                    # Filter for viable UI accent colors
                    if s_val >= 0.12 and v_val >= 0.15:
                        # Scoring gives high weight to color identity (saturation) so we don't pick mud
                        sat_weight = (s_val ** 0.8)
                        val_weight = 1.0 - abs(v_val - 0.72)
                        score = (count ** 0.5) * (sat_weight * 2.2 + val_weight)
                        candidates.append((score, r, g, b, h_val, s_val, v_val, count))

                candidates.sort(key=lambda x: x[0], reverse=True)

                if candidates:
                    best = candidates[0]
                    h_val, s_val, v_val = best[4], best[5], best[6]

                    # Harmonize & tune:
                    # Never produce muddy, washed-out low contrast brown (V must be >= 0.86, S >= 0.58)
                    s_tuned = max(0.58, min(0.85, s_val * 1.45))
                    v_tuned = max(0.88, min(0.96, v_val + 0.28))

                    r_f, g_f, b_f = colorsys.hsv_to_rgb(h_val, s_tuned, v_tuned)
                    extracted_accent = rgb_to_hex(r_f * 255, g_f * 255, b_f * 255)
        except Exception:
            pass

    final_accent = extracted_accent or theme_accent
    final_dominant = dominant_color or background

    # High-contrast glass tokens
    is_light_top = top_area_luminance > 95.0
    final_selection = blend_hex(final_accent, dark_background, 0.28)
    glass_tint = blend_hex(final_accent, final_dominant, 0.35)
    glass_crest = blend_hex(final_accent, "#ffffff", 0.35)
    glass_border = blend_hex(final_accent, "#ffffff", 0.30)
    glass_surface = blend_hex(final_dominant, dark_background, 0.25)

    data = {
        "wallpaper": real_wp_path,
        "accent": final_accent,
        "dominant": final_dominant,
        "background": background,
        "dark_background": dark_background,
        "lighter_background": lighter_background,
        "selection": final_selection,
        "foreground": foreground,
        "muted": muted,
        "border": final_accent,
        "wallpaper_tint": final_dominant,
        "glass_tint": glass_tint,
        "glass_surface": glass_surface,
        "glass_crest": glass_crest,
        "glass_border": glass_border,
        "top_area_luminance": round(top_area_luminance, 1),
        "is_light_wallpaper": is_light_top
    }

    try:
        with open(cache_path, "w", encoding="utf-8") as f:
            json.dump(data, f)
    except Exception:
        pass

    # Write to canonical persistent state file for Quickshell FileView reactive watchers
    try:
        persistent_dir = os.path.join(home, ".local/state/qdeck")
        os.makedirs(persistent_dir, exist_ok=True)
        persistent_file = os.path.join(persistent_dir, "wallpaper-palette.json")
        with open(persistent_file, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
            f.flush()
    except Exception:
        pass

    return data


if __name__ == "__main__":
    wp = sys.argv[1] if len(sys.argv) > 1 else None
    result = get_wallpaper_palette(wp)
    print(json.dumps(result))
