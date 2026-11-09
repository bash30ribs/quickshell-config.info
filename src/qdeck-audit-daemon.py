#!/usr/bin/env python3
"""
QDeck System Audit & Application Activity Protocol Daemon
--------------------------------------------------------------------------------
Silently monitors application lifecycles (opens, active focus time, closes)
via the Wayland compositor event socket.

Generates and maintains ready-to-read session audit reports so administrators
and system owners can inspect exactly which applications were accessed, at what
time, and for how long.

Runs 100% headless in the background without auto-launching GUI popups.
"""

import argparse
import atexit
import datetime
import json
import os
import pathlib
import select
import signal
import socket
import subprocess
import sys
import time
from typing import Dict, Any, Optional

# Base audit state directory
STATE_DIR = pathlib.Path.home() / ".local" / "state" / "qdeck" / "audit"
PID_FILE = STATE_DIR / "daemon.pid"
CURRENT_SESSION_FILE = STATE_DIR / "current_session.json"
CURRENT_REPORT_FILE = STATE_DIR / "current_session_report.txt"
LAST_SESSION_FILE = STATE_DIR / "last_session.json"
LAST_REPORT_FILE = STATE_DIR / "last_session_report.txt"
ACTIVITY_LOG_FILE = STATE_DIR / "activity.log"


def get_hypr_socket_path() -> Optional[str]:
    """Resolve Hyprland IPC event socket path."""
    inst = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    if not inst:
        # Search runtime directory for active hyprland instance
        hypr_dir = pathlib.Path(runtime) / "hypr"
        if hypr_dir.exists():
            for d in hypr_dir.iterdir():
                sock = d / ".socket2.sock"
                if sock.is_socket():
                    return str(sock)
        return None
    sock = pathlib.Path(runtime) / "hypr" / inst / ".socket2.sock"
    return str(sock) if sock.is_socket() else None


def format_duration(seconds: float) -> str:
    """Format duration in seconds into human-readable string."""
    s = int(round(seconds))
    if s < 60:
        return f"{s}s"
    m, s = divmod(s, 60)
    if m < 60:
        return f"{m}m {s:02d}s"
    h, m = divmod(m, 60)
    return f"{h}h {m:02d}m {s:02d}s"


def format_timestamp(dt: datetime.datetime) -> str:
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def format_time_only(dt: datetime.datetime) -> str:
    return dt.strftime("%H:%M:%S")


class AuditDaemon:
    def __init__(self):
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        self.running = True
        self.session_data: Dict[str, Any] = {}
        self.active_windows: Dict[str, Dict[str, Any]] = {}
        self.history: list = []
        self.current_focus_address: Optional[str] = None
        self.last_focus_time: float = time.time()
        self.sock: Optional[socket.socket] = None

    def log_activity(self, action: str, details: str) -> None:
        """Append an entry to the persistent chronological audit log."""
        now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        entry = f"[{now_str}] [{action.upper():<7}] {details}\n"
        try:
            with open(ACTIVITY_LOG_FILE, "a", encoding="utf-8") as f:
                f.write(entry)
        except OSError:
            pass

    def rotate_session(self) -> None:
        """Archive previous session if present and initialize a fresh audit session."""
        if CURRENT_SESSION_FILE.exists():
            try:
                with open(CURRENT_SESSION_FILE, "r", encoding="utf-8") as f:
                    old_data = json.load(f)
                old_data["session_ended"] = datetime.datetime.now().isoformat()
                old_data["state"] = "Closed"
                # Save as last session
                with open(LAST_SESSION_FILE, "w", encoding="utf-8") as f:
                    json.dump(old_data, f, indent=2)
                # Generate text report for last session
                last_report = self.build_report_text(old_data, is_last=True)
                with open(LAST_REPORT_FILE, "w", encoding="utf-8") as f:
                    f.write(last_report)
            except Exception:
                pass

        now = datetime.datetime.now()
        user = os.environ.get("USER", "user")
        self.session_data = {
            "session_id": f"sess_{int(now.timestamp())}",
            "user": user,
            "session_started": now.isoformat(),
            "session_ended": None,
            "state": "Active",
            "windows": [],
        }
        self.history = []
        self.active_windows = {}

        self.log_activity("SESSION", f"User '{user}' logged in; audit protocol started.")
        self.save_current_session()

    def save_current_session(self) -> None:
        """Persist current session state and formatted text report to disk."""
        all_windows = list(self.history)
        for win in self.active_windows.values():
            all_windows.append(win)

        self.session_data["windows"] = all_windows
        try:
            with open(CURRENT_SESSION_FILE, "w", encoding="utf-8") as f:
                json.dump(self.session_data, f, indent=2)
            report = self.build_report_text(self.session_data, is_last=False)
            with open(CURRENT_REPORT_FILE, "w", encoding="utf-8") as f:
                f.write(report)
        except OSError:
            pass

    def build_report_text(self, data: Dict[str, Any], is_last: bool = False) -> str:
        """Build formatted human-readable report."""
        user = data.get("user", "user")
        start_iso = data.get("session_started")
        start_dt = datetime.datetime.fromisoformat(start_iso) if start_iso else datetime.datetime.now()
        end_iso = data.get("session_ended")
        end_dt = datetime.datetime.fromisoformat(end_iso) if end_iso else datetime.datetime.now()

        state = data.get("state", "Active")
        if is_last:
            elapsed = (end_dt - start_dt).total_seconds()
            state_str = f"Finalized / Closed (Session Duration: {format_duration(elapsed)})"
        else:
            elapsed = (datetime.datetime.now() - start_dt).total_seconds()
            state_str = f"ACTIVE (Running for {format_duration(elapsed)})"

        windows = data.get("windows", [])
        total_apps = len(windows)
        active_count = sum(1 for w in windows if w.get("closed_at") is None)
        closed_count = total_apps - active_count

        lines = [
            "╔════════════════════════════════════════════════════════════════════════════════════════════════════════════╗",
            f"║                       QDECK SYSTEM AUDIT & APPLICATION ACTIVITY REPORT                             ║",
            "╚════════════════════════════════════════════════════════════════════════════════════════════════════════════╝",
            f"  Session Type   : {'PREVIOUS LOGIN REPORT' if is_last else 'CURRENT LOGIN AUDIT'}",
            f"  Logged In User : {user}",
            f"  Session Start  : {format_timestamp(start_dt)}",
            f"  Report Time    : {format_timestamp(datetime.datetime.now())}",
            f"  Session Status : {state_str}",
            f"  Total Apps Seen: {total_apps} ({active_count} active, {closed_count} closed)",
            f"  Audit Log Path : {ACTIVITY_LOG_FILE}",
            "",
            "─" * 104,
            f"  {'APPLICATION':<18} {'WINDOW TITLE':<34} {'OPENED':<10} {'CLOSED / STATUS':<16} {'DURATION':<11} {'FOCUSED':<9}",
            "─" * 104,
        ]

        if not windows:
            lines.append("  (No application activity recorded yet)")
        else:
            for w in windows:
                app_name = (w.get("class") or "unknown")[:17]
                title = (w.get("title") or "untitled")[:33]

                open_ts = w.get("opened_at_time", "")
                if not open_ts and w.get("opened_at"):
                    try:
                        open_ts = format_time_only(datetime.datetime.fromisoformat(w["opened_at"]))
                    except Exception:
                        open_ts = w.get("opened_at")[:8]

                closed_at = w.get("closed_at")
                if closed_at:
                    try:
                        close_ts = format_time_only(datetime.datetime.fromisoformat(closed_at))
                    except Exception:
                        close_ts = str(closed_at)[:8]
                else:
                    close_ts = "🟢 ACTIVE NOW"

                duration_sec = w.get("duration_seconds", 0)
                if not closed_at and w.get("opened_at_epoch"):
                    duration_sec = time.time() - w["opened_at_epoch"]
                dur_str = format_duration(duration_sec)

                focused_sec = w.get("focus_seconds", 0)
                foc_str = format_duration(focused_sec)

                lines.append(f"  {app_name:<18} {title:<34} {open_ts:<10} {close_ts:<16} {dur_str:<11} {foc_str:<9}")

        lines.append("─" * 104)
        lines.append(f"  Generated by QDeck System Audit Protocol at {format_timestamp(datetime.datetime.now())}")
        lines.append("")
        return "\n".join(lines)

    def import_initial_clients(self) -> None:
        """Register any windows already open when the daemon started."""
        try:
            out = subprocess.check_output(["hyprctl", "clients", "-j"], timeout=3).decode("utf-8")
            clients = json.loads(out)
            now = datetime.datetime.now()
            now_iso = now.isoformat()
            now_epoch = time.time()
            now_time = format_time_only(now)

            for c in clients:
                addr = c.get("address")
                if not addr or addr in self.active_windows:
                    continue
                app_class = c.get("class") or c.get("initialClass") or "unknown"
                title = c.get("title") or c.get("initialTitle") or ""
                pid = c.get("pid", 0)

                win_info = {
                    "address": addr,
                    "class": app_class,
                    "title": title,
                    "pid": pid,
                    "opened_at": now_iso,
                    "opened_at_epoch": now_epoch,
                    "opened_at_time": now_time,
                    "closed_at": None,
                    "duration_seconds": 0,
                    "focus_seconds": 0,
                }
                self.active_windows[addr] = win_info
                self.log_activity("RUNNING", f"Existing app: '{app_class}' | Title: '{title}' | PID: {pid}")

            self.save_current_session()
        except Exception:
            pass

    def handle_open_window(self, payload: str) -> None:
        """Handle openwindow>>ADDRESS,WORKSPACE,CLASS,TITLE"""
        parts = payload.split(",", 3)
        if len(parts) < 3:
            return
        addr = parts[0].strip()
        workspace = parts[1].strip()
        app_class = parts[2].strip()
        title = parts[3].strip() if len(parts) > 3 else ""

        now = datetime.datetime.now()
        win_info = {
            "address": addr,
            "workspace": workspace,
            "class": app_class,
            "title": title,
            "opened_at": now.isoformat(),
            "opened_at_epoch": time.time(),
            "opened_at_time": format_time_only(now),
            "closed_at": None,
            "duration_seconds": 0,
            "focus_seconds": 0,
        }
        self.active_windows[addr] = win_info
        self.log_activity("OPEN", f"App: '{app_class}' | Title: '{title}' | Workspace: {workspace}")
        self.save_current_session()

    def handle_close_window(self, payload: str) -> None:
        """Handle closewindow>>ADDRESS"""
        addr = payload.strip()
        win = self.active_windows.pop(addr, None)
        now = datetime.datetime.now()
        now_epoch = time.time()

        if win:
            dur = max(0.0, now_epoch - win.get("opened_at_epoch", now_epoch))
            win["closed_at"] = now.isoformat()
            win["closed_at_time"] = format_time_only(now)
            win["duration_seconds"] = dur
            self.history.append(win)
            self.log_activity(
                "CLOSE",
                f"App: '{win.get('class')}' | Title: '{win.get('title')}' | Duration: {format_duration(dur)} | Focused: {format_duration(win.get('focus_seconds', 0))}"
            )
        else:
            self.log_activity("CLOSE", f"Window address: {addr}")

        self.save_current_session()

    def handle_active_window(self, payload: str) -> None:
        """Update focus time tracking when active window changes."""
        now = time.time()
        delta = now - self.last_focus_time
        if self.current_focus_address and self.current_focus_address in self.active_windows:
            self.active_windows[self.current_focus_address]["focus_seconds"] += delta

        self.last_focus_time = now

        # payload is CLASS,TITLE
        parts = payload.split(",", 1)
        active_class = parts[0].strip()
        # Find matching address in active windows
        for addr, w in self.active_windows.items():
            if w.get("class") == active_class:
                self.current_focus_address = addr
                break

    def handle_active_window_v2(self, payload: str) -> None:
        """Handle activewindowv2>>ADDRESS"""
        now = time.time()
        delta = now - self.last_focus_time
        if self.current_focus_address and self.current_focus_address in self.active_windows:
            self.active_windows[self.current_focus_address]["focus_seconds"] += delta

        self.last_focus_time = now
        addr = payload.strip()
        self.current_focus_address = addr if addr in self.active_windows else None

    def handle_title_change(self, payload: str) -> None:
        """Handle windowtitle>>ADDRESS or title change"""
        parts = payload.split(",", 1)
        if len(parts) >= 2:
            addr = parts[0].strip()
            title = parts[1].strip()
            if addr in self.active_windows:
                self.active_windows[addr]["title"] = title

    def dispatch_event(self, line: str) -> None:
        """Dispatch a single event line from Hyprland socket."""
        line = line.strip()
        if not line or ">>" not in line:
            return
        event, payload = line.split(">>", 1)
        if event == "openwindow":
            self.handle_open_window(payload)
        elif event == "closewindow":
            self.handle_close_window(payload)
        elif event == "activewindow":
            self.handle_active_window(payload)
        elif event == "activewindowv2":
            self.handle_active_window_v2(payload)
        elif event == "windowtitle":
            self.handle_title_change(payload)

    def run(self) -> None:
        """Main daemon event loop."""
        with open(PID_FILE, "w", encoding="utf-8") as f:
            f.write(str(os.getpid()))

        def cleanup_handler(*args):
            self.running = False

        signal.signal(signal.SIGTERM, cleanup_handler)
        signal.signal(signal.SIGINT, cleanup_handler)

        self.rotate_session()
        self.import_initial_clients()

        sock_path = get_hypr_socket_path()
        last_flush = time.time()

        while self.running:
            if not sock_path or not os.path.exists(sock_path):
                time.sleep(1.0)
                sock_path = get_hypr_socket_path()
                continue

            try:
                self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                self.sock.connect(sock_path)
                self.sock.setblocking(True)
                self.log_activity("SYSTEM", "Connected to Wayland compositor event stream.")

                buffer = ""
                while self.running:
                    # Select with timeout so we periodically update active durations
                    r, _, _ = select.select([self.sock], [], [], 3.0)
                    if r:
                        chunk = self.sock.recv(4096)
                        if not chunk:
                            break
                        buffer += chunk.decode("utf-8", errors="replace")
                        while "\n" in buffer:
                            line, buffer = buffer.split("\n", 1)
                            self.dispatch_event(line)

                    # Update focused window timing periodically
                    now = time.time()
                    if now - last_flush > 5.0:
                        delta = now - self.last_focus_time
                        if self.current_focus_address and self.current_focus_address in self.active_windows:
                            self.active_windows[self.current_focus_address]["focus_seconds"] += delta
                        self.last_focus_time = now
                        self.save_current_session()
                        last_flush = now

            except (OSError, socket.error):
                time.sleep(1.5)
            finally:
                if self.sock:
                    try:
                        self.sock.close()
                    except Exception:
                        pass
                    self.sock = None

        # Clean shutdown
        now = datetime.datetime.now()
        now_epoch = time.time()
        for addr, win in list(self.active_windows.items()):
            dur = max(0.0, now_epoch - win.get("opened_at_epoch", now_epoch))
            win["closed_at"] = now.isoformat()
            win["closed_at_time"] = format_time_only(now)
            win["duration_seconds"] = dur
            self.history.append(win)

        self.active_windows.clear()
        self.session_data["session_ended"] = now.isoformat()
        self.session_data["state"] = "Closed"
        self.save_current_session()
        self.log_activity("SESSION", "Audit protocol daemon gracefully terminated.")

        if PID_FILE.exists():
            try:
                PID_FILE.unlink()
            except OSError:
                pass


def is_daemon_running() -> Optional[int]:
    """Check if the audit daemon process is currently running."""
    if not PID_FILE.exists():
        return None
    try:
        pid = int(PID_FILE.read_text().strip())
        os.kill(pid, 0)
        return pid
    except (OSError, ValueError):
        return None


def cmd_start() -> None:
    """Start audit daemon in background if not already running."""
    pid = is_daemon_running()
    if pid:
        print(f"QDeck Audit Protocol daemon is already running (PID {pid}).")
        return

    # Check if hyprland is active
    if not get_hypr_socket_path():
        print("Note: Wayland compositor socket not active yet. Daemon will wait.")

    # Fork process to run headless
    cmd = [sys.executable, str(pathlib.Path(__file__).resolve()), "--daemon"]
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        stdin=subprocess.DEVNULL,
        start_new_session=True,
    )
    time.sleep(0.3)
    print(f"QDeck System Audit Protocol daemon started (PID {proc.pid}).")
    print(f"  Activity log: {ACTIVITY_LOG_FILE}")
    print(f"  Live report : {CURRENT_REPORT_FILE}")


def cmd_stop() -> None:
    """Stop the running audit daemon."""
    pid = is_daemon_running()
    if not pid:
        print("QDeck Audit Protocol daemon is not running.")
        return
    try:
        os.kill(pid, signal.SIGTERM)
        for _ in range(30):
            time.sleep(0.1)
            if not is_daemon_running():
                break
        else:
            # Force kill if still lingering
            try:
                os.kill(pid, signal.SIGKILL)
            except OSError:
                pass
        print(f"QDeck Audit Protocol daemon (PID {pid}) stopped.")
    except OSError as e:
        print(f"Error stopping daemon: {e}")


def cmd_report(which: str = "current") -> None:
    """Display the formatted activity report."""
    target_file = LAST_REPORT_FILE if which == "last" else CURRENT_REPORT_FILE
    if not target_file.exists():
        print(f"No {which} session report found at {target_file}.")
        return
    try:
        with open(target_file, "r", encoding="utf-8") as f:
            print(f.read())
    except OSError as e:
        print(f"Error reading report: {e}")


def cmd_log(lines: int = 50) -> None:
    """Display the raw chronological activity log."""
    if not ACTIVITY_LOG_FILE.exists():
        print("No activity log found.")
        return
    try:
        with open(ACTIVITY_LOG_FILE, "r", encoding="utf-8") as f:
            all_lines = f.readlines()
        print("".join(all_lines[-lines:]))
    except OSError as e:
        print(f"Error reading log: {e}")


def cmd_status() -> None:
    """Display audit protocol daemon status."""
    pid = is_daemon_running()
    print("=== QDeck System Audit Protocol ===")
    if pid:
        print(f"  Status   : ACTIVE (PID {pid})")
    else:
        print("  Status   : INACTIVE (stopped)")
    print(f"  Log File : {ACTIVITY_LOG_FILE} ({'exists' if ACTIVITY_LOG_FILE.exists() else 'none'})")
    print(f"  Current  : {CURRENT_REPORT_FILE} ({'ready' if CURRENT_REPORT_FILE.exists() else 'none'})")
    print(f"  Last Sess: {LAST_REPORT_FILE} ({'ready' if LAST_REPORT_FILE.exists() else 'none'})")


def main():
    parser = argparse.ArgumentParser(description="QDeck System Audit & Application Lifecycle Protocol")
    parser.add_argument("command", nargs="?", default="report", choices=["start", "stop", "restart", "status", "report", "log"])
    parser.add_argument("--last", action="store_true", help="Show last/previous login session report")
    parser.add_argument("--daemon", action="store_true", help="Internal daemon worker mode")
    parser.add_argument("-n", "--lines", type=int, default=50, help="Number of log lines to show")

    args = parser.parse_args()

    if args.daemon:
        daemon = AuditDaemon()
        daemon.run()
        return

    if args.command == "start":
        cmd_start()
    elif args.command == "stop":
        cmd_stop()
    elif args.command == "restart":
        cmd_stop()
        time.sleep(0.5)
        cmd_start()
    elif args.command == "status":
        cmd_status()
    elif args.command == "log":
        cmd_log(lines=args.lines)
    elif args.command == "report":
        which = "last" if args.last else "current"
        cmd_report(which=which)


if __name__ == "__main__":
    main()
