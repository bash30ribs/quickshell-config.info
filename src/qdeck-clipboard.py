#!/usr/bin/env python3
"""
QDeck Clipboard & Screenshot History Engine
Monitors Wayland clipboard (wl-paste --watch) and screenshot captures,
maintains deduplicated in-place JSON history for QuickShell FileView watchers,
generates cached Lanczos thumbnails, and handles copy/paste/pin/delete operations.
"""

import os
import re
import sys
import time
import json
import fcntl
import signal
import hashlib
import subprocess
from contextlib import contextmanager
from PIL import Image, ImageOps

HOME = os.path.expanduser("~")
STATE_DIR = os.path.join(
    os.environ.get("XDG_STATE_HOME", os.path.join(HOME, ".local", "state")),
    "qdeck",
    "clipboard",
)
IMAGES_DIR = os.path.join(STATE_DIR, "images")
HISTORY_FILE = os.path.join(STATE_DIR, "history.json")
LOCK_FILE = os.path.join(STATE_DIR, "history.lock")
PID_FILE = os.path.join(STATE_DIR, "daemon.pid")
DISMISSED_FILE = os.path.join(STATE_DIR, "dismissed.json")
SELF_COPY_FILE = os.path.join(STATE_DIR, "self_copy.json")

THUMB_DIR = os.path.join(
    os.environ.get("XDG_CACHE_HOME", os.path.join(HOME, ".cache")),
    "qdeck",
    "clipboard-thumbs",
)
THUMB_SIZE = (320, 200)
MAX_UNPINNED = 60
MAX_TEXT_BYTES = 512 * 1024

TERMINAL_CLASSES = {
    "kitty",
    "foot",
    "footclient",
    "alacritty",
    "org.wezfurlong.wezterm",
    "wezterm",
    "com.mitchellh.ghostty",
    "ghostty",
    "konsole",
    "org.kde.konsole",
    "gnome-terminal",
    "gnome-terminal-server",
    "tilix",
    "terminator",
    "st",
    "st-256color",
    "xterm",
}

HEX_COLOR_RE = re.compile(r"^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$")
URL_RE = re.compile(r"^https?://\S+$")


def ensure_dirs():
    os.makedirs(STATE_DIR, exist_ok=True)
    os.makedirs(IMAGES_DIR, exist_ok=True)
    os.makedirs(THUMB_DIR, exist_ok=True)


def resolve_screenshot_dirs():
    dirs = []
    for cand in (
        os.environ.get("XDG_SCREENSHOTS_DIR", ""),
        os.path.join(HOME, "Pictures", "Screenshot"),
        os.path.join(HOME, "Pictures", "Screenshots"),
    ):
        if cand and os.path.isdir(cand) and cand not in dirs:
            dirs.append(cand)
    return dirs


@contextmanager
def history_lock():
    ensure_dirs()
    lock_fd = open(LOCK_FILE, "a+", encoding="utf-8")
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX)
        yield
    finally:
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
        finally:
            lock_fd.close()


def read_history_unlocked():
    if not os.path.isfile(HISTORY_FILE):
        return []
    try:
        with open(HISTORY_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict) and isinstance(data.get("items"), list):
            return data["items"]
        if isinstance(data, list):
            return data
    except Exception:
        pass
    return []


def read_dismissed_unlocked():
    if not os.path.isfile(DISMISSED_FILE):
        return set()
    try:
        with open(DISMISSED_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, list):
            return {str(x) for x in data if x}
    except Exception:
        pass
    return set()


def write_dismissed_unlocked(ids_iterable):
    ensure_dirs()
    keep = list(dict.fromkeys(str(x) for x in ids_iterable if x))[-200:]
    with open(DISMISSED_FILE, "w", encoding="utf-8") as f:
        json.dump(keep, f)


def mark_self_copy_unlocked(item_id):
    ensure_dirs()
    payload = {"id": item_id, "until": time.time() + 2.5}
    with open(SELF_COPY_FILE, "w", encoding="utf-8") as f:
        json.dump(payload, f)


def is_recent_self_copy_unlocked(item_id):
    if not os.path.isfile(SELF_COPY_FILE):
        return False
    try:
        with open(SELF_COPY_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        return (
            isinstance(data, dict)
            and data.get("id") == item_id
            and float(data.get("until", 0)) >= time.time()
        )
    except Exception:
        return False


def write_history_unlocked(items):
    """
    Write in-place (truncate + flush) so Quickshell FileView's Linux inotify
    watch never loses track of the inode across updates.
    """
    ensure_dirs()
    pinned = [it for it in items if it.get("pinned")]
    unpinned = [it for it in items if not it.get("pinned")]
    unpinned.sort(key=lambda x: x.get("timestamp", 0), reverse=True)
    unpinned = unpinned[:MAX_UNPINNED]

    merged = pinned + unpinned
    merged.sort(key=lambda x: (1 if x.get("pinned") else 0, x.get("timestamp", 0)), reverse=True)

    # Clean up unreferenced cached blobs inside IMAGES_DIR & THUMB_DIR
    keep_paths = {it.get("path") for it in merged if it.get("path")}
    keep_thumbs = {it.get("thumbPath") for it in merged if it.get("thumbPath")}

    for fname in os.listdir(IMAGES_DIR):
        fpath = os.path.join(IMAGES_DIR, fname)
        if fpath not in keep_paths:
            try:
                os.remove(fpath)
            except OSError:
                pass

    for fname in os.listdir(THUMB_DIR):
        tpath = os.path.join(THUMB_DIR, fname)
        if tpath not in keep_thumbs:
            try:
                os.remove(tpath)
            except OSError:
                pass

    payload = {"items": merged, "updatedAt": int(time.time())}
    if os.path.exists(HISTORY_FILE):
        with open(HISTORY_FILE, "r+", encoding="utf-8") as f:
            f.seek(0)
            json.dump(payload, f, ensure_ascii=False, indent=2)
            f.truncate()
            f.flush()
    else:
        with open(HISTORY_FILE, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
            f.flush()
    return merged


def generate_thumbnail(img_path, key_id):
    thumb_path = os.path.join(THUMB_DIR, f"{key_id}.jpg")
    if os.path.isfile(thumb_path):
        try:
            with Image.open(img_path) as im:
                return thumb_path, im.width, im.height
        except Exception:
            pass
    try:
        with Image.open(img_path) as im:
            w, h = im.width, im.height
            rgb = im.convert("RGB") if im.mode != "RGB" else im
            fitted = ImageOps.fit(rgb, THUMB_SIZE, method=Image.Resampling.LANCZOS)
            tmp = thumb_path + ".tmp"
            fitted.save(tmp, format="JPEG", quality=88, optimize=True)
            os.replace(tmp, thumb_path)
            return thumb_path, w, h
    except Exception:
        return img_path, 0, 0


def find_matching_screenshot(sha_hex):
    for sdir in resolve_screenshot_dirs():
        try:
            entries = sorted(os.scandir(sdir), key=lambda e: e.stat().st_mtime, reverse=True)[:30]
        except OSError:
            continue
        for entry in entries:
            if not entry.is_file():
                continue
            if os.path.splitext(entry.name)[1].lower() not in (".png", ".jpg", ".jpeg", ".webp"):
                continue
            try:
                h = hashlib.sha256()
                with open(entry.path, "rb") as f:
                    while chunk := f.read(65536):
                        h.update(chunk)
                if h.hexdigest() == sha_hex:
                    return entry.path
            except OSError:
                pass
    return None


def upsert_image(raw_bytes, preferred_path=None, ts=None, source="clipboard"):
    if not raw_bytes or len(raw_bytes) < 32:
        return False
    sha_hex = hashlib.sha256(raw_bytes).hexdigest()
    item_id = f"img-{sha_hex[:16]}"
    now = ts if ts is not None else time.time()

    with history_lock():
        dismissed = read_dismissed_unlocked()
        if source == "screenshot" and item_id in dismissed:
            return False
        if source == "clipboard" and ts is None and is_recent_self_copy_unlocked(item_id):
            return True
        if source == "clipboard" and item_id in dismissed:
            dismissed.discard(item_id)
            write_dismissed_unlocked(dismissed)

        items = read_history_unlocked()
        for it in items:
            if it.get("id") == item_id:
                existing_path = it.get("path", "")
                if existing_path and os.path.isfile(existing_path):
                    # Preserve explicit timestamp unless clipboard capture is newer
                    if ts is None or now > it.get("timestamp", 0):
                        it["timestamp"] = now
                    if preferred_path and os.path.isfile(preferred_path):
                        it["path"] = preferred_path
                        it["title"] = os.path.basename(preferred_path)
                    write_history_unlocked(items)
                    return True

        img_path = preferred_path
        if not img_path or not os.path.isfile(img_path):
            matched = find_matching_screenshot(sha_hex)
            if matched:
                img_path = matched
            else:
                img_path = os.path.join(IMAGES_DIR, f"{sha_hex[:16]}.png")
                with open(img_path, "wb") as f:
                    f.write(raw_bytes)

        thumb_path, w, h = generate_thumbnail(img_path, sha_hex[:16])
        entry = {
            "id": item_id,
            "type": "image",
            "mime": "image/png",
            "path": img_path,
            "thumbPath": thumb_path,
            "width": w,
            "height": h,
            "sizeBytes": len(raw_bytes),
            "title": os.path.basename(img_path),
            "timestamp": now,
            "pinned": False,
            "source": source,
        }
        items.insert(0, entry)
        write_history_unlocked(items)
        return True


def upsert_text(text, ts=None):
    if not text or not text.strip():
        return False
    raw = text.encode("utf-8", errors="replace")
    if len(raw) > MAX_TEXT_BYTES:
        return False

    sha_hex = hashlib.sha256(b"text:" + raw).hexdigest()
    item_id = f"txt-{sha_hex[:16]}"
    now = ts if ts is not None else time.time()

    stripped = text.strip()
    lines = text.splitlines()
    collapsed = " ".join(stripped.split())
    preview = collapsed[:220] + ("…" if len(collapsed) > 220 else "")
    is_color = bool(HEX_COLOR_RE.match(stripped))
    is_url = bool(URL_RE.match(stripped))
    is_code = (
        not is_url
        and not is_color
        and (
            len(lines) > 1
            or any(tok in text for tok in ("{", "}", "=>", "function ", "def ", "import ", "const ", "return "))
        )
    )

    with history_lock():
        if ts is None and is_recent_self_copy_unlocked(item_id):
            return True
        items = read_history_unlocked()
        for it in items:
            if it.get("id") == item_id:
                it["timestamp"] = now
                write_history_unlocked(items)
                return True

        entry = {
            "id": item_id,
            "type": "text",
            "mime": "text/plain",
            "text": text,
            "preview": preview,
            "isColor": is_color,
            "colorHex": stripped if is_color else "",
            "isUrl": is_url,
            "isCode": is_code,
            "lineCount": max(1, len(lines)),
            "charCount": len(text),
            "timestamp": now,
            "pinned": False,
        }
        items.insert(0, entry)
        write_history_unlocked(items)
        return True


def capture_clipboard():
    try:
        res = subprocess.run(
            ["wl-paste", "--list-types"],
            capture_output=True,
            text=True,
            timeout=1.5,
        )
        if res.returncode != 0:
            return
        mime_types = [m.strip() for m in res.stdout.splitlines() if m.strip()]
    except Exception:
        return

    if not mime_types:
        return

    # Respect KDE/Wayland secret password manager hint
    if "x-kde-passwordManagerHint" in mime_types:
        try:
            sec = subprocess.run(
                ["wl-paste", "--type", "x-kde-passwordManagerHint"],
                capture_output=True,
                text=True,
                timeout=1.0,
            )
            if "secret" in sec.stdout.lower():
                return
        except Exception:
            return

    # Check if image payload should be captured
    image_mime = None
    for cand in ("image/png", "image/jpeg", "image/webp"):
        if cand in mime_types:
            image_mime = cand
            break

    plain_mime = None
    for cand in ("text/plain;charset=utf-8", "UTF8_STRING", "text/plain"):
        if cand in mime_types:
            plain_mime = cand
            break

    plain_text = ""
    if plain_mime:
        try:
            txt_res = subprocess.run(
                ["wl-paste", "--no-newline", "--type", plain_mime],
                capture_output=True,
                timeout=1.5,
            )
            if txt_res.returncode == 0:
                plain_text = txt_res.stdout.decode("utf-8", errors="replace")
        except Exception:
            pass

    if image_mime and (not plain_text.strip() or plain_text.startswith("file://")):
        try:
            img_res = subprocess.run(
                ["wl-paste", "--type", image_mime],
                capture_output=True,
                timeout=3.0,
            )
            if img_res.returncode == 0 and img_res.stdout:
                upsert_image(img_res.stdout, source="clipboard")
                return
        except Exception:
            pass

    if plain_text.strip():
        upsert_text(plain_text)


def sync_screenshots(limit=12):
    """Index existing/new screenshots cleanly into clipboard history."""
    for sdir in resolve_screenshot_dirs():
        try:
            entries = sorted(
                (e for e in os.scandir(sdir) if e.is_file()),
                key=lambda e: e.stat().st_mtime,
                reverse=True,
            )[:limit]
        except OSError:
            continue

        # Process oldest-to-newest within window so newest gets highest position
        for entry in reversed(entries):
            ext = os.path.splitext(entry.name)[1].lower()
            if ext not in (".png", ".jpg", ".jpeg", ".webp"):
                continue
            try:
                st = entry.stat()
                if st.st_size > 25 * 1024 * 1024 or st.st_size < 64:
                    continue
                with open(entry.path, "rb") as f:
                    raw = f.read()
                upsert_image(raw, preferred_path=entry.path, ts=st.st_mtime, source="screenshot")
            except OSError:
                continue


def copy_item(item_id, promote=False):
    with history_lock():
        items = read_history_unlocked()
        target = next((it for it in items if it.get("id") == item_id), None)
        if not target:
            return False

        mark_self_copy_unlocked(item_id)
        if promote:
            target["timestamp"] = time.time()
            write_history_unlocked(items)

    # IMPORTANT: wl-copy forks into background and inherits pipes unless detached to DEVNULL
    if target.get("type") == "image":
        path = target.get("path", "")
        if not path or not os.path.isfile(path):
            return False
        with open(path, "rb") as f:
            data = f.read()
        mime = "image/png"
        ext = os.path.splitext(path)[1].lower()
        if ext in (".jpg", ".jpeg"):
            mime = "image/jpeg"
        elif ext == ".webp":
            mime = "image/webp"
        proc = subprocess.Popen(
            ["wl-copy", "--type", mime],
            stdin=subprocess.PIPE,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        proc.stdin.write(data)
        proc.stdin.close()
        proc.wait(timeout=2.0)
        return True
    else:
        text = target.get("text", "")
        proc = subprocess.Popen(
            ["wl-copy"],
            stdin=subprocess.PIPE,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        proc.stdin.write(text.encode("utf-8"))
        proc.stdin.close()
        proc.wait(timeout=2.0)
        return True


def paste_item(item_id):
    if not copy_item(item_id):
        return False

    time.sleep(0.08)
    mods = "CTRL"
    active_addr = ""
    try:
        aw = subprocess.run(["hyprctl", "activewindow", "-j"], capture_output=True, text=True, timeout=1.0)
        if aw.returncode == 0 and aw.stdout.strip():
            info = json.loads(aw.stdout)
            active_addr = str(info.get("address") or "").strip()
            win_class = str(info.get("class") or info.get("initialClass") or "").lower()
            if win_class in TERMINAL_CLASSES or "term" in win_class:
                mods = "CTRL SHIFT"
    except Exception:
        pass

    # Support Hyprland Lua mode (v0.57+) cleanly
    try:
        win_arg = f', window = "address:{active_addr}"' if active_addr else ""
        res = subprocess.run(
            ["hyprctl", "dispatch", f'hl.dsp.send_shortcut({{ mods = "{mods}", key = "V"{win_arg} }})'],
            capture_output=True,
            text=True,
            timeout=1.0,
        )
        if res.returncode != 0 or "error:" in (res.stdout + res.stderr).lower():
            subprocess.run(
                ["hyprctl", "dispatch", "sendshortcut", f"{mods}, V,{(' address:' + active_addr) if active_addr else ''}"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=1.0,
            )
    except Exception:
        pass
    return True


def toggle_pin(item_id):
    with history_lock():
        items = read_history_unlocked()
        for it in items:
            if it.get("id") == item_id:
                it["pinned"] = not bool(it.get("pinned"))
                write_history_unlocked(items)
                return True
    return False


def delete_item(item_id):
    with history_lock():
        dismissed = read_dismissed_unlocked()
        dismissed.add(item_id)
        write_dismissed_unlocked(dismissed)

        items = read_history_unlocked()
        new_items = [it for it in items if it.get("id") != item_id]
        if len(new_items) != len(items):
            write_history_unlocked(new_items)
            return True
    return False


def clear_unpinned():
    with history_lock():
        items = read_history_unlocked()
        pinned = [it for it in items if it.get("pinned")]
        write_history_unlocked(pinned)


def run_daemon():
    ensure_dirs()
    # Replace stale daemon cleanly
    if os.path.isfile(PID_FILE):
        try:
            old_pid = int(open(PID_FILE, "r").read().strip())
            if old_pid != os.getpid():
                os.kill(old_pid, 0)
                # Alive; keep existing single daemon
                return
        except Exception:
            pass

    with open(PID_FILE, "w", encoding="utf-8") as f:
        f.write(str(os.getpid()))

    running = True
    watch_proc = None

    def handle_stop(signum, frame):
        nonlocal running
        running = False
        if watch_proc and watch_proc.poll() is None:
            watch_proc.terminate()

    signal.signal(signal.SIGTERM, handle_stop)
    signal.signal(signal.SIGINT, handle_stop)

    # Initial sync of existing screenshots & active clipboard
    sync_screenshots(limit=14)
    capture_clipboard()

    script_self = os.path.realpath(__file__)
    last_mtimes = {}

    try:
        while running:
            if watch_proc is None or watch_proc.poll() is not None:
                try:
                    watch_proc = subprocess.Popen(
                        ["wl-paste", "--watch", sys.executable, script_self, "capture"],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                except Exception:
                    watch_proc = None

            # Lightweight directory mtime check for save-only screenshots (0.0% CPU)
            changed = False
            for sdir in resolve_screenshot_dirs():
                try:
                    mt = os.stat(sdir).st_mtime
                    if last_mtimes.get(sdir) != mt:
                        last_mtimes[sdir] = mt
                        changed = True
                except OSError:
                    pass
            if changed:
                sync_screenshots(limit=6)

            time.sleep(1.5)
    finally:
        if watch_proc and watch_proc.poll() is None:
            watch_proc.terminate()
        try:
            if os.path.isfile(PID_FILE) and open(PID_FILE).read().strip() == str(os.getpid()):
                os.remove(PID_FILE)
        except OSError:
            pass


def ensure_daemon_running():
    ensure_dirs()
    if os.path.isfile(PID_FILE):
        try:
            old_pid = int(open(PID_FILE, "r", encoding="utf-8").read().strip())
            os.kill(old_pid, 0)
            return
        except Exception:
            pass
    try:
        subprocess.Popen(
            [sys.executable, os.path.realpath(__file__), "daemon"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except Exception:
        pass


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "daemon":
        run_daemon()
    elif cmd == "capture":
        capture_clipboard()
    elif cmd == "sync":
        ensure_daemon_running()
        sync_screenshots(limit=14)
        capture_clipboard()
    elif cmd == "list":
        with history_lock():
            items = read_history_unlocked()
        print(json.dumps({"items": items}, ensure_ascii=False))
    elif cmd == "copy" and len(sys.argv) > 2:
        copy_item(sys.argv[2])
    elif cmd == "paste" and len(sys.argv) > 2:
        paste_item(sys.argv[2])
    elif cmd == "pin" and len(sys.argv) > 2:
        toggle_pin(sys.argv[2])
    elif cmd == "delete" and len(sys.argv) > 2:
        delete_item(sys.argv[2])
    elif cmd == "clear":
        clear_unpinned()
    else:
        print(f"Usage: {sys.argv[0]} {{daemon|capture|sync|list|copy|paste|pin|delete|clear}}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
