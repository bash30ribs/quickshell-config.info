# QuickShell: Predator Helios Neo 16 Edition (`phn-16`)

> A modern, ultra-fluid, Apple/visionOS-inspired liquid glassmorphism desktop shell for **Hyprland** on Linux, built with **QuickShell** (QtQuick / QML).

---

## 🌟 Project Origin & Credits

This configuration is built upon and inspired by **[qdeck](https://github.com/)**, an exceptional QuickShell desktop suite. Full credit and appreciation go to the original creators and contributors of the **qdeck** project for providing the foundational architecture, modular service patterns, and QML conventions.

### My Learning & Customization Journey
This repository represents an active learning exploration into:
- Advanced declarative UI design with **QtQuick / QML** and modern ECMAScript.
- Deep compositor integration with **Hyprland Wayland Protocols** (Layer Shell, Foreign Toplevel, Focus Grab).
- Engineering real-time, hardware-accelerated **liquid glassmorphism** optimized specifically for my laptop hardware: the **Acer Predator Helios Neo 16 (`phn-16`)**.

---

## 💻 Hardware Profile: Acer Predator Helios Neo 16 (`phn-16`)

This setup has been fine-tuned and benchmarked specifically for the hardware characteristics of the `phn-16`:

| Component | Specification | Optimization in this Setup |
| :--- | :--- | :--- |
| **Display** | 16-inch WUXGA/WQXGA 165Hz IPS (`eDP-1`) | 165Hz hardware-accelerated spring animations; 60Hz/165Hz instant toggles |
| **Graphics** | NVIDIA GeForce RTX 40-Series + Intel Iris Xe | Hardware dual-kawase blur (`size = 10`, `passes = 4`, `vibrancy = 0.60`) |
| **Battery** | 90Wh 4-Cell Lithium-Ion | High-contrast battery telemetry (capacity, health %, cycle count, wattage) |
| **Power Engine** | `power-profiles-daemon` | Direct kernel power profile switching (Power-saver, Balanced, Performance) |
| **Compositor** | Hyprland 0.40+ (Lua Configuration) | Single-surface layer shell with zero CPU overhead and native sub-millisecond blur |

---

## ✨ Key Features & Design Philosophy

### 1. VisionOS-Grade Liquid Glassmorphism
- **Authentic Compositor Dual-Kawase Blur:** No simulated stacked plates or stepped stair borders. A single, unified glass card lets Hyprland's GPU blur pass smoothly through the surface.
- **Calibrated Glass Translucency:** Refined refraction gradient ($0.16\alpha \text{ top sheen} \to 0.36\alpha \to 0.42\alpha \to 0.48\alpha$) allows the vibrant colors of wallpapers and blurred windows to shine through cleanly.
- **Structured Inset Glass Wells:** Controls, stats, and sliders sit inside recessed dark glass wells (`Qt.rgba(0, 0, 0, 0.25)`, border `Qt.rgba(255, 255, 255, 0.08)`), guaranteeing razor-sharp contrast and legibility across both dark and foggy/light backgrounds.
- **Seamless Curvature Sheens:** Specular top highlights naturally hug the exact border radius of the card, completely eliminating artificial detached lines.

### 2. Snappy Springboard Physics (165Hz Optimized)
- **Opening Animation:** Popups emerge from $0.85\times$ scale with a $-12\text{px}$ vertical offset, springing open with a tuned `Easing.OutBack` curve (`overshoot: 1.32`, $190\text{ms}$).
- **Dismiss Animation:** On close or outside click, cards snap down cleanly in $120\text{ms}$ (`Easing.InCubic`) without lag or lingering artifacts.

### 3. Dynamic Wallpaper Color Harmony
- Built-in Python color extraction engine (`src/qdeck-wallpaper-palette.py`) reads the current wallpaper and generates real-time harmonious palette tokens (`glass_tint`, `glass_surface`, `glass_crest`, `glass_border`).
- Glass borders and crest highlights dynamically adapt to wallpaper transitions.

---

## 🧩 Widget Ecosystem

- **🔋 Battery Widget (`BatteryWidget.qml`):**
  - Live capacity percentage displayed directly on the top bar button (`🗲 80%`).
  - Detailed telemetry well: Battery size (Wh), Health %, Charge cycles, Power source, Charging rate.
  - Interactive Power Profile selector (`Power-saver`, `Balanced`, `Performance`).
- **🖥️ Display & Refresh Rate Widget (`MonitorWidget.qml`):**
  - Smooth brightness slider with OSD inhibition.
  - Stepped notch text size slider.
  - Display scale preset pills (`1x`, `1.25x`, `1.6x`, `2x`, `3x`, `4x`).
  - Refresh rate switcher (`60 Hz` / `165 Hz (Max)`).
- **🔊 Audio & Stream Controller (`AudioWidget.qml`):**
  - Output and Input volume sliders with mute toggles.
  - Dedicated sink and source selector.
  - Per-application audio stream volume controls.
- **🌐 Network & Wi-Fi (`NetworkWidget.qml`):**
  - Instant DNS provider selector (`DHCP`, `Cloudflare`, `Google`).
  - Active network details, signal strength, and QR code sharing.
  - Saved networks and nearby network scanner with inline password entry.
- **📶 Bluetooth (`BluetoothWidget.qml`):**
  - Connected device list with battery levels and disconnect actions.
  - Paired device history and one-click scanner.
- **📅 Clock & Calendar (`ClockWidget.qml`):**
  - Multi-month navigation, week numbers, and date format options.
- **🗂️ Workspaces (`WorkspacesWidget.qml`):**
  - Dynamic active capsule with occupancy dots and wheel-scroll workspace switching.

---

## 🛠️ IPC Commands Quick Reference

Control popups and theme reload directly from terminal, keybindings, or scripts using the `qs ipc` CLI:

```bash
# Toggle widgets
qs ipc call barpopups toggle battery
qs ipc call barpopups toggle monitor
qs ipc call barpopups toggle audio
qs ipc call barpopups toggle network
qs ipc call barpopups toggle bluetooth
qs ipc call barpopups toggle clock

# Top bar control
qs ipc call bar toggle
qs ipc call bar isVisible

# Reload theme & wallpaper harmony palette
qs ipc call theme reload
qs ipc call theme reloadWallpaper
```

---

## 📂 Project Architecture

```
~/.config/quickshell/
├── shell.qml                 # Shell root entry point
├── bar/
│   └── Bar.qml               # Top bar container (floating / wide / islands modes)
├── components/
│   ├── PopupCard.qml         # Single-surface liquid frosted glass popup container
│   ├── BarButton.qml         # Unified icon button component with active states
│   └── ToggleSwitch.qml      # Apple-style fluid toggle switch
├── widgets/
│   ├── BatteryWidget.qml     # Battery telemetry & power profiles
│   ├── MonitorWidget.qml     # Brightness, text size, scale, and 165Hz switching
│   ├── AudioWidget.qml       # PipeWire volume, sinks, sources, streams
│   ├── NetworkWidget.qml     # NetworkManager Wi-Fi, DNS, hotspot
│   ├── BluetoothWidget.qml   # BlueZ pairing, devices, state
│   ├── ClockWidget.qml       # Time, calendar, week numbering
│   └── WorkspacesWidget.qml  # Hyprland workspace indicator capsule
├── services/                 # C++ / QML service backends (PipeWire, NM, Brightness, Hyprland)
├── theme/
│   ├── Theme.qml             # Central color tokens, glassmorphism parameters, and IPC
│   ├── Appearance.qml        # Sizing, padding, corner radii, and animation timings
│   ├── Fonts.qml             # Typography definitions
│   └── Icons.qml             # Nerd Font glyph mappings
└── src/
    └── qdeck-wallpaper-palette.py # Dynamic wallpaper color extraction
```

---

## 📜 Acknowledgments

- **qdeck Project:** Sincere gratitude to the creators of `qdeck` for the inspiration, foundation, and initial architecture.
- **Quickshell:** Built with the awesome [Quickshell](https://quickshell.org/) desktop shell engine.
- **Hyprland:** Blurring and window management powered by [Hyprland](https://hyprland.org/).
