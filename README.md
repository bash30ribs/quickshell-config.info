# QDeck · Mornye Liquid Glass Desktop Shell

> A next-generation, Apple-grade translucent liquid glass desktop environment for **Hyprland** on Linux, powered by **QuickShell** (Qt 6 / QML).

---

## 💎 What We Are Building

**QDeck** is a modern, high-fidelity desktop shell engineered to bring the optical sophistication and tactile physics of **Apple visionOS and macOS Liquid Glass** to modern Linux Wayland environments.

Built natively on top of the **QuickShell** engine and deeply integrated with the **Hyprland** Wayland compositor, QDeck replaces traditional flat panels and widgets with true translucent optical glass surfaces, real-time spring dynamics, and an intelligent wallpaper color-harmony engine that works seamlessly across all themes.

---

## 🌟 Key Architecture & Pillars

```
┌────────────────────────────────────────────────────────────────────────┐
│                        QUICKSHELL RUNTIME ROOT                         │
│                              (shell.qml)                               │
└────┬──────────────┬──────────────┬─────────────┬─────────────┬─────────┘
     │              │              │             │             │
┌────▼────┐    ┌────▼────┐    ┌────▼────┐   ┌────▼────┐   ┌────▼────┐
│   BAR   │    │   OSD   │    │LAUNCHER │   │ POWER   │   │ AUDIT   │
│ (4 Modes)    │ (Short- │    │ (4-Mode │   │ & THEME │   │ PROTOCOL│
│         │    │  cuts)  │    │ Search) │   │  MENU   │   │(Daemon) │
└────┬────┘    └────┬────┘    └────┬────┘   └────┬────┘   └────┬────┘
     │              │              │             │             │
┌────▼──────────────▼──────────────▼─────────────▼─────────────▼─────────┐
│            CENTRAL MORNYE LIQUID GLASS DESIGN SYSTEM                   │
│        (GlassPanel · Theme · Appearance · Fonts · Icons · Effects)     │
└────┬─────────────────────────────┬───────────────────────────┬─────────┘
     │                             │                           │
┌────▼──────────────┐   ┌──────────▼──────────────┐   ┌────────▼─────────┐
│ HYPRLAND LAYERS   │   │  LINUX SYSTEM BACKENDS  │   │ DYNAMIC HARMONY  │
│ Dual-Kawase Blur  │   │ PipeWire · BlueZ · D-Bus│   │ Wallpaper Palette│
│ Layershell V1     │   │ Sysfs · NetworkManager  │   │ Luminance Engine │
└───────────────────┘   └─────────────────────────┘   └──────────────────┘
```

### 1. Mornye Liquid Glass Material System
- **Authentic Compositor Dual-Kawase Blur**: Instead of simulated blur or flat opaque backgrounds, surfaces request native compositor dual-kawase GPU blur through Wayland layer shell rules (`namespace = "^quickshell-.*"`).
- **Physical Optical Tokens**: Every surface supports fine-tuned optical properties:
  - `glassClarity: 0.75` — Translucent body allowing blurred background windows and wallpapers to glow through.
  - `glassRimIllumination: 0.50` — Subtle 1px specular illuminated perimeter rim definition.
  - `glassSpecularIntensity: 0.75` — Apple Control Center directional top diffuse sheen.
  - `glassRefractionStrength: 0.85` — Edge chromatic refraction and optical depth.
- **Three Material Tiers**:
  - `liquid`: Full specular crest, top diffuse sheen, translucent body, and illuminated rim.
  - `frosted`: Pure diffused translucent gradient over compositor blur.
  - `flat`: Ultra-low-overhead solid surface for battery preservation.
- **Harmonic Spring Physics**: Interactive buttons and pills replicate real-world physical spring dynamics ($m=1.0, k=420.0, c=24.0$) with subtle hover elevation (`1.025`), compression on press (`0.965`), and damped harmonic release.

---

### 2. Universal Dynamic Wallpaper Harmony
- **Intelligent Color Engine (`qdeck-wallpaper-palette.py`)**: Quantizes thumbnail samples of the active wallpaper using weighted HSV perceptual scoring ($V \ge 0.88, S \ge 0.58$), extracting vibrant accents while strictly eliminating muddy browns.
- **Luminance Adaptivity**: Analyzes top-edge wallpaper luminance. When running over light skies or bright wallpapers, it dynamically reinforces text drop shadows (`Text.Raised`) and adapts glass opacity, ensuring 100% legibility with zero text blindness.
- **Zero-Latency State Synchronization**: Color tokens are written atomically to `~/.local/state/qdeck/wallpaper-palette.json` and consumed via native QuickShell `FileView` watchers, providing instantaneous palette updates across all themes (Gruvbox, Everforest, Tokyo-Night, Nord, Catppuccin).

---

### 3. Modular Geometry Modes
The status bar supports 4 instant layout modes toggled via IPC or config:
- **`floating`** *(Default)*: Full-width floating bar with rounded bottom corners and outer margins.
- **`islands`**: Three discrete floating glass capsules separating Workspaces & Media, Center Date/Clock, and Hardware Controls.
- **`wide`**: Centered 72% monitor width surface with high screen efficiency.
- **`compact`**: Snug, centered status pill dynamically conforming to active content width.

---

## 🧩 Complete Desktop Shell Suite

### 📊 Status Modules & Popups
- **🔋 Battery**: Real-time capacity indicator, charging wattage, health percentage, cycle counts, and an interactive power profile selector (`Power-saver`, `Balanced`, `Performance`).
- **🔊 PipeWire Audio Mixer**: Master volume slider, mute toggle, default sink/source selector, and individual per-application audio stream controls.
- **🌐 Network & Wi-Fi**: Instant DNS provider selector (`DHCP`, `Cloudflare`, `Google`), live Wi-Fi network scanner with inline password entry, and Wi-Fi QR code generator.
- **📶 Bluetooth Manager**: Device discovery, pairing, connection toggling, and battery level telemetry.
- **📅 Clock & Calendar**: Clean hero time display, year progress rail with percentage, active date pill, ISO week numbering, and smooth multi-month scrolling.
- **🗂️ Workspaces**: Sleek capsule indicator with occupied dot states, active pill expansion, and mouse-wheel switching.
- **🎵 Media Pill**: Compact status bar playback indicator with animated equalizer bars and full media popup.

---

### ⚡ Transparent Shortcut OSD Engine
Volume, brightness, caps lock, and refresh rate adjustments display through a dedicated translucent liquid glass OSD engineered for zero visual distortion:
- **Pill Squircle Geometry & Specular Sheen Clipping**: Implements adaptive corner geometry (`isPill: effectiveTopLeftRadius >= height * 0.42`) with `clip: true` on the master glass surface. Automatically suppresses flat horizontal specular sheens on pill structures to eliminate corner protrusions, rendering a 100% mathematically continuous perimeter rim.
- **Authentic Liquid Glass Translucency**: Calibrated multi-stop lens gradient (`0.18` / `0.22` / `0.28` alpha density) allowing Hyprland dual-kawase compositor blur to shine through vibrantly without muddy brown opaque backings.
- **High-Contrast Raised Typography**: Icons and numerical readouts use `Text.Raised` drop-shadow styling (`Qt.rgba(0, 0, 0, 0.70)`), ensuring razor-sharp legibility over both dark wallpapers and luminous skies.
- **Volume & Mute OSD**: Real-time percentage track and volume level glyphs with mute state alerts.
- **Brightness OSD**: Smooth hardware backlight adjustment bar with fine-step tuning.
- **Lock-State Toasts**: Zero-latency status toasts for Caps Lock, Num Lock, and Touchpad states powered by the native `qdeck-lockstate-monitor` daemon (0.0% CPU overhead).
- **Display Refresh Rate**: Instant on-screen confirmation when toggling display frequencies.

---

### 🚀 Spotlight-Style Application Launcher
A fast, unified modal launcher (`AppLauncher.qml`) featuring 4 modes:
1. **Applications**: Categorized desktop applications with icons and launch tracking.
2. **Run Command**: Direct terminal command execution.
3. **File Search**: Real-time local file discovery.
4. **Active Windows**: Instant window switcher with workspace jumping.

---

### 🛡️ Silent System Activity Audit Protocol (`qdeck-audit`)
An enterprise-grade, background security protocol tracking application activity across login sessions:
- **Zero GUI Interruption**: Runs silently as a low-overhead background daemon without auto-launching any popups.
- **Audit Tracking**: Logs application launches, window title changes, workspace relocations, foreground focus duration, and close timestamps.
- **Command-Line Interface**:
  ```bash
  qdeck report        # View comprehensive session audit report
  qdeck report --last # View previous session audit report
  qdeck audit status  # Inspect daemon health and log paths
  qdeck audit log     # View raw structured activity log
  ```

---

### 🔒 Polkit Authentication Agent
Native Wayland polkit agent rendered as a centered liquid glass dialog, featuring masked password inputs, error shake animations, and PAM cancellation support.

---

### ⚙️ Unified Power & Theme Switcher
Bottom modal dashboard combining:
- **Power Session Actions**: Shutdown, Reboot, Suspend, Lock, and Logout with confirmation overlays.
- **Theme Switcher**: Instant switching between system color schemes with live wallpaper updates.
- **Wallpaper Switcher**: Grid carousel of available wallpapers with instant dynamic palette harmonization.

---

## 🛠️ IPC Command Reference

Control any part of the shell programmatically using `qs ipc`:

```bash
# ── Bar Popups & Layout ───────────────────────────────────────────────────────
qs ipc call barpopups toggle clock      # Toggle calendar popup
qs ipc call barpopups toggle audio      # Toggle audio mixer popup
qs ipc call barpopups toggle network    # Toggle network popup
qs ipc call barpopups toggle bluetooth  # Toggle bluetooth popup
qs ipc call barpopups toggle battery    # Toggle battery popup
qs ipc call barpopups toggle monitor    # Toggle display popup

qs ipc call barpopups setMode floating  # Switch to floating bar
qs ipc call barpopups setMode islands   # Switch to islands bar
qs ipc call barpopups setMode wide      # Switch to wide bar
qs ipc call barpopups setMode compact   # Switch to compact bar
qs ipc call barpopups getMode           # Query active bar mode

# ── Bar Visibility ────────────────────────────────────────────────────────────
qs ipc call bar toggle                  # Toggle bar visibility
qs ipc call bar hide                    # Hide bar
qs ipc call bar show                    # Show bar

# ── Shortcut OSD ──────────────────────────────────────────────────────────────
qs ipc call osd outputVolume raise      # Raise volume (+5%)
qs ipc call osd outputVolume lower      # Lower volume (-5%)
qs ipc call osd outputVolume mute-toggle# Toggle mute
qs ipc call osd brightness raise        # Raise brightness (+5%)
qs ipc call osd brightness lower        # Lower brightness (-5%)
qs ipc call osd refreshRate 60Hz        # Display refresh rate confirmation

# ── Launcher & Power Menu ─────────────────────────────────────────────────────
qs ipc call launcher toggle             # Toggle application launcher
qs ipc call powermenu toggle            # Toggle power & unified menu

# ── Theme & Dynamic Wallpaper ─────────────────────────────────────────────────
qs ipc call theme reload                # Reload theme colors.toml
qs ipc call theme reloadWallpaper       # Re-extract active wallpaper palette
qs ipc call theme setWallpaper "/path"  # Set specific wallpaper and sync palette
qs ipc call theme getPalette            # Return active palette JSON
qs ipc call theme toggleBlur            # Toggle compositor blur state

# ── System Activity Audit ─────────────────────────────────────────────────────
qs ipc call audit report                # Query formatted session audit report
qs ipc call audit status                # Query daemon running state
```

---

## 📁 Repository Structure

```
~/.config/quickshell/
├── shell.qml                     # Shell root & service composition
├── bar/
│   └── Bar.qml                   # Status bar with 4 layout modes
├── components/
│   ├── GlassPanel.qml            # Primary Mornye Liquid Glass primitive
│   ├── BarButton.qml             # Translucent status bar button
│   ├── GlassButton.qml           # General-purpose glass action button
│   ├── GlassSelectionPill.qml    # Pill indicator component
│   ├── PopupCard.qml             # Floating liquid glass popup surface
│   ├── PowerConfirmDialog.qml    # Modal confirmation dialog
│   ├── Slider.qml                # Tactile glass slider
│   └── ToggleSwitch.qml          # Smooth fluid toggle switch
├── widgets/
│   ├── BatteryWidget.qml         # Battery telemetry & power profiles
│   ├── MonitorWidget.qml         # Brightness, display scale, refresh rate
│   ├── AudioWidget.qml           # PipeWire volume & stream mixer
│   ├── NetworkWidget.qml         # NetworkManager Wi-Fi & DNS manager
│   ├── BluetoothWidget.qml       # BlueZ Bluetooth device controls
│   ├── ClockWidget.qml           # Calendar & year progress rail
│   ├── WorkspacesWidget.qml      # Hyprland workspace switcher capsule
│   ├── MediaPill.qml             # Media playback pill
│   └── MediaPopup.qml            # Media controller popup
├── osd/
│   ├── Osd.qml                   # Translucent liquid glass shortcut OSD
│   ├── OsdService.qml            # Volume & brightness rate-limiting service
│   └── OsdModel.js               # OSD state mapping logic
├── launcher/
│   ├── AppLauncher.qml           # Spotlight-style 4-mode application launcher
│   └── LauncherModel.js          # Desktop entry parsing & search index
├── powermenu/
│   └── PowerMenu.qml             # Session, theme, and wallpaper switcher
├── polkit/
│   └── Polkit.qml                # Centered polkit authentication dialog
├── notifications/
│   └── Notifications.qml         # Desktop notification manager
├── services/                     # Backend communication layer
│   ├── AudioService.qml          # PipeWire native integration
│   ├── AuditService.qml          # Audit protocol IPC bridge
│   ├── BatteryService.qml        # UPower / sysfs integration
│   ├── BluetoothService.qml      # BlueZ D-Bus integration
│   ├── BrightnessService.qml     # Backlight / brightnessctl integration
│   ├── NetworkService.qml        # NetworkManager D-Bus service
│   ├── PowerService.qml          # systemd login1 power actions
│   ├── ThemeSwitcherService.qml  # Theme management service
│   ├── WallpaperSwitcherService.qml # Wallpaper management service
│   └── WorkspacesService.qml     # Hyprland IPC socket listener
├── theme/
│   ├── Theme.qml                 # Central color tokens, dynamic harmony, and IPC
│   ├── Appearance.qml            # Geometry tokens, corner radii, spring physics
│   ├── Fonts.qml                 # Font families & sizing scales
│   └── Icons.qml                 # Unified icon glyph mappings
├── src/
│   ├── qdeck-audit-daemon.py     # Background application activity auditor
│   ├── qdeck-lockstate-monitor.c # High-efficiency C sysfs LED monitor (0.0% CPU)
│   ├── qdeck-wallpaper-palette.py# Multi-theme dynamic wallpaper palette extractor
│   └── qdeck-wallpaper-thumbs.py # High-speed cached carousel thumbnail generator
└── scripts/
    └── verify.sh                 # Autonomous syntax & shader verification pipeline
```

---

## ⚡ Performance Standards

- **Zero Mock Data**: Never uses simulated telemetry or placeholder stubs; directly bound to live Linux kernel sysfs, PipeWire, BlueZ, NetworkManager, and D-Bus APIs.
- **Ultra-Low Resource Footprint**: 
  - `qs` idle CPU: **< 0.5%**
  - `qdeck-lockstate-monitor` CPU: **0.0%**
  - `qdeck-audit-daemon` CPU: **0.0%**
- **Non-Blocking Architecture**: Background queries are executed asynchronously through rate-limited queues, completely eliminating NetworkManager, polkit, or D-Bus lockups.

---

## 📜 License & Credits

- Built with [QuickShell](https://quickshell.org/) and [Hyprland](https://hyprland.org/).
- Inspired by the foundational architecture of **qdeck** and Apple's visionOS/macOS Liquid Glass visual design language.
