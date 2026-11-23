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
- **Luminance Adaptivity**: Analyzes top-edge wallpaper luminance. When running over light skies or bright wallpapers, it dynamically adapts glass opacity and reinforces optical rim contrast, ensuring 100% legibility with zero text blindness.
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
- **⚡ Minimalist Performance Mode & Governor Controller**:
  - **What It Is**: An ultra-compact (260px) Mornye Liquid Glass power management and real-time hardware telemetry dashboard.
  - **Why We Built It**: Traditional system monitors consume excessive screen space with bulky ASCII graphs or heavy dialogs. Power users need instantaneous, distraction-free governor management and rapid answers to why their machine is working hard without launching a heavy GUI or terminal.
  - **How It Helps You**:
    - **Zero-Menu Bar Controls**: Right-click the bar icon to toggle Turbo boost instantly with an animated OSD toast; scroll your mouse wheel or swipe the icon to cycle `Saver` $\rightarrow$ `Balanced` $\rightarrow$ `Turbo` on the fly.
    - **One-Tap Governor Switcher**: Fluid segmented pill switcher (`[ 🌱 Saver ]`, `[ ⚖️ Bal ]`, `[ ⚡ Turbo ]`) backed natively by `powerprofilesctl`.
    - **Slim Telemetry Tracks**: High-contrast, 4px progress tracks for CPU Load, Memory (used / total GB), and Core Temperature with dynamic color alerting (Green $\rightarrow$ Amber $\rightarrow$ Red).
    - **🔥 Real-Time Top Task Detection**: Live background monitoring dynamically detects the single highest CPU-consuming task (e.g. `Top Task: chrome · 14%`), providing immediate diagnostic clarity.
    - **Integrated System Monitor Shortcut**: A discreet `[ 󰆍 System Monitor (btop) ]` quick action to launch a terminal monitor whenever deep inspection is required.
- **🔋 Battery**: Real-time capacity indicator with persistent percentage readout, charging wattage, health percentage, cycle counts, and an interactive power profile selector.
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
- **High-Contrast Optical Typography**: Crisp sub-pixel anti-aliased Inter typography with calibrated weights and optical letter spacing, ensuring razor-sharp legibility over both dark wallpapers and luminous glass surfaces without artificial drop-shadow distortion.
- **Volume & Mute OSD**: Real-time percentage track and volume level glyphs with mute state alerts.
- **Brightness OSD**: Smooth hardware backlight adjustment bar with fine-step tuning.
- **Lock-State Toasts**: Zero-latency status toasts for Caps Lock, Num Lock, and Touchpad states powered by the native `qdeck-lockstate-monitor` daemon (0.0% CPU overhead).
- **Display Refresh Rate**: Instant on-screen confirmation when toggling display frequencies.

---

### 📋 3-Stage Gesture Shelf & Drag-and-Drop Drawer (ClipBar)
Move your pointer to the top bar and glide two fingers downward (trackpad natural scroll or 2-finger touch drag) to drop a spring-animated liquid glass workspace shelf:
- **What It Is**: A multi-stage pull-down workspace shelf integrating screenshot captures, clipboard text history, and local file staging into one fluid surface.
- **Why We Built It**: Modern creative and coding workflows require constant juggling between taking screenshots, copying code snippets, and dragging files between apps. Opening separate file managers or clipboard utilities interrupts cognitive flow.
- **How It Helps You**:
  - **3-Stage Unified Organization**: Seamlessly switch between dedicated stages:
    - `Screenshots`: Captures from `~/Pictures/Screenshots` and clipboard images with Lanczos thumbnails.
    - `Text`: Clipboard text history, URLs, and code snippets with click-to-paste into focused windows.
    - `Files`: Dedicated file staging shelf for rapid drag-and-drop.
  - **Progressive Upward Gesture Navigation**: Swiping upward on `Files` moves back to `Text`, then to `Screenshots`, then smoothly dismisses the drawer.
  - **3-Finger Quick Dismiss**: An outward 3-finger upward swipe dismisses the drawer immediately from any active stage (`closeAtOnce`).
  - **Wayland Drag-and-Drop**: Drag any file or screenshot past `8px` to initiate native Wayland `text/uri-list` drag-and-drop into chat apps, browsers, or code editors.
  - **Self-Healing Storage**: Automatically prunes deleted screenshot records and gracefully falls back to placeholder cards so the UI never crashes or shows broken images.

---

### 🧵 Suspended Screenshot Notifications & Hanging Thread Physics
- **What It Is**: A tactile notification presentation that renders new screenshot captures as physical cards suspended from top bar clasps with metallic eyelets and dual thread lines.
- **Why We Built It**: Standard notification toasts are flat, generic, and easily dismissed by accident. A screenshot is an active, tactile creative asset that deserves distinct visual importance and physical presence.
- **How It Helps You**:
  - **Damped Pendulum Dynamics**: New captures swing into view with a physical $-3.2^\circ$ release oscillation and subtle spring rebound, responding dynamically to mouse hover gestures.
  - **Corner Grommet Architecture**: Authentic liquid glass surface detailed with metallic perimeter eyelets and top-bar mounting clasps.
  - **Inline Workflow Actions**: Instant access to `[ Open ]`, `[ Annotate ]` (via `swappy`), and `[ Copy ]` directly from the suspended card.

---

### 🖐️ Continuous Touchpad Gestures
- **What It Is**: Deep Wayland continuous touchpad gesture integration powered by Hyprland and QuickShell IPC.
- **Why We Built It**: Reaching for hardware function keys or memorizing complex modifier keybinds takes hands away from the typing flow. Continuous trackpad swipes provide instantaneous physical control over desktop environment parameters.
- **How It Helps You**:
  - **4-Finger Horizontal Brightness Control**: Swipe left-to-right to smoothly raise display brightness, or right-to-left to lower it, with finely calibrated sensitivity (`THRESHOLD = 9`) matched to volume adjustments.
  - **3-Finger Vertical Drawer Navigation**: Pull down on the top bar to reveal the shelf; swipe up to progress through stages or dismiss at once.

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
- **Wallpaper Switcher & Transition Bloom**: Grid carousel of available wallpapers featuring:
  - **Circular Bloom Reveal**: Smooth radial shader transition eliminating abrupt cuts on wallpaper change.
  - **Surface Cache Optimization**: Pre-cached background surfaces eliminating grey-tint loading flicker.
  - **Clean Immersive Gallery**: Streamlined wallpaper cards without distracting badge overlays.

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
qs ipc call barpopups toggleControlCenter # Toggle minimalist performance card
qs ipc call bar toggle perf              # Alternate performance toggle

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
qs ipc call osd brightness raise-fine   # Fine brightness raise (+2%)
qs ipc call osd brightness lower-fine   # Fine brightness lower (-2%)
qs ipc call osd trigger "⚡" "Turbo"    # Display custom OSD toast notification
qs ipc call osd refreshRate 60Hz        # Display refresh rate confirmation

# ── Multi-Stage Workspace Shelf & Clipboard Drawer ───────────────────────────
qs ipc call clipboard toggle            # Pull down or dismiss workspace shelf
qs ipc call clipboard showScreenshots   # Switch directly to Screenshots stage
qs ipc call clipboard showText          # Switch directly to Text history stage
qs ipc call clipboard showFiles         # Switch directly to Files shelf stage
qs ipc call clipboard stepBack          # Progressive outward navigation step
qs ipc call clipboard closeAtOnce       # Instant 3-finger drawer dismissal
qs ipc call clipboard refresh           # Sync latest clipboard and screenshot entries
qs ipc call barpopups toggle clipboard  # Alternate clipboard drawer toggle

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
│   ├── BatteryWidget.qml         # Battery telemetry & persistent percentage
│   ├── ControlCenterWidget.qml   # Minimalist performance mode, governor switcher & top task monitor
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
├── clipboard/
│   ├── ClipboardDrawer.qml       # ClipBar: 3-stage pull-down workspace shelf (Screenshots, Text, Files)
│   ├── ClipboardImageCard.qml    # Clean liquid glass screenshot card with metadata
│   └── ClipboardTextCard.qml     # Text snippet card with syntax highlighting & click-to-paste
├── launcher/
│   ├── AppLauncher.qml           # Spotlight-style 4-mode application launcher
│   └── LauncherModel.js          # Desktop entry parsing & search index
├── powermenu/
│   └── PowerMenu.qml             # Session, theme, and wallpaper switcher
├── polkit/
│   └── Polkit.qml                # Centered polkit authentication dialog
├── notifications/
│   ├── Notifications.qml         # Desktop notification manager
│   ├── NotificationCard.qml      # Suspended screenshot card with hanging string physics & eyelets
│   └── NotificationLogic.js      # Notification snapshotting & lifetime logic
├── services/                     # Backend communication layer
│   ├── AudioService.qml          # PipeWire native integration
│   ├── AuditService.qml          # Audit protocol IPC bridge
│   ├── BatteryService.qml        # UPower / sysfs integration
│   ├── BluetoothService.qml      # BlueZ D-Bus integration
│   ├── BrightnessService.qml     # Backlight / brightnessctl integration
│   ├── ClipboardService.qml      # Wayland clipboard & screenshot history state service
│   ├── HardwareService.qml       # Hardware telemetry, power profile switcher & top CPU detector
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
│   ├── qdeck-clipboard.py        # Wayland wl-paste watcher, paste injector & thumbnailer
│   ├── qdeck-lockstate-monitor.c # High-efficiency C sysfs LED monitor (0.0% CPU)
│   ├── qdeck-wallpaper-palette.py# Multi-theme dynamic wallpaper palette extractor
│   └── qdeck-wallpaper-thumbs.py # High-speed cached carousel thumbnail generator
└── scripts/
    ├── ralph                     # Native Antigravity Ralph Loop CLI & PRD runner
    ├── ralph-stop-hook.py        # Antigravity Stop-hook verification loop controller
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
