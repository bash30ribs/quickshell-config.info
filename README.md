# QuickShell Dotfiles

> A modern, minimalist, Apple/visionOS-inspired liquid glassmorphism desktop shell for **Hyprland** on Linux, built with **QuickShell** (QtQuick / QML).

---

## 🌟 Origin & Credits

This configuration is built upon and inspired by **[qdeck](https://github.com/)**, an exceptional QuickShell desktop suite. Full credit and appreciation go to the original creators and contributors of the **qdeck** project for providing the foundational architecture, modular service patterns, and QML conventions.

This repository serves as an active learning exploration into:
- Declarative desktop UI design with **QtQuick / QML** and modern ECMAScript.
- Native Wayland compositor integration with **Hyprland** (Layer Shell, Foreign Toplevel, Focus Grab).
- Hardware-accelerated **liquid glassmorphism** with seamless curvature and dynamic wallpaper harmony.

---

## ✨ Features

- **Liquid Glassmorphism:** Single-surface frosted glass utilizing native compositor dual-kawase GPU blur with zero fake stacked plates.
- **Dynamic Wallpaper Harmony:** Integrated color engine dynamically attunes glass borders and crest highlights to wallpaper colorways.
- **High-Contrast Typography:** Controls and metrics sit inside recessed inset glass wells, guaranteeing legibility across light and dark backdrops.
- **Snappy Springboard Physics:** Hardware-accelerated spring curves (`Easing.OutBack`) for punchy, fluid popup interactions.
- **Seamless Curvature:** Full-width diffuse sheens naturally follow the border radius with zero detached highlight lines.

---

## 🧩 Widget Ecosystem

- **🔋 Battery:** Live bar capacity indicator (`🗲 80%`), detailed battery telemetry well (Wh capacity, health, charge cycles, wattage), and interactive power profile switcher (`Power-saver`, `Balanced`, `Performance`).
- **🖥️ Display:** Smooth brightness slider, stepped notch text size slider, display scale presets, and refresh rate switcher.
- **🔊 Audio:** PipeWire volume controls, mute toggles, default sink/source selector, and individual application stream sliders.
- **🌐 Network:** Instant DNS provider selector (`DHCP`, `Cloudflare`, `Google`), Wi-Fi network scanner with inline password entry, and QR code sharing.
- **📶 Bluetooth:** Device pairing, connection management, and battery levels.
- **📅 Clock & Calendar:** Date, multi-month calendar, and ISO week numbering.
- **🗂️ Workspaces:** Active indicator capsule with occupancy dots and mouse-wheel switching.

---

## 🛠️ IPC Quick Reference

Control popups and theme reload directly from terminal, keybindings, or scripts using `qs ipc`:

```bash
# Toggle widgets
qs ipc call barpopups toggle battery
qs ipc call barpopups toggle monitor
qs ipc call barpopups toggle audio
qs ipc call barpopups toggle network
qs ipc call barpopups toggle bluetooth
qs ipc call barpopups toggle clock

# Bar visibility
qs ipc call bar toggle

# Reload theme & wallpaper palette
qs ipc call theme reload
qs ipc call theme reloadWallpaper
```

---

## 📂 Architecture

```
~/.config/quickshell/
├── shell.qml                 # Shell root entry point
├── bar/
│   └── Bar.qml               # Top bar container (floating / wide / islands modes)
├── components/
│   ├── PopupCard.qml         # Single-surface liquid frosted glass popup container
│   ├── BarButton.qml         # Unified icon button component with active states
│   └── ToggleSwitch.qml      # Fluid toggle switch component
├── widgets/
│   ├── BatteryWidget.qml     # Battery telemetry & power profiles
│   ├── MonitorWidget.qml     # Brightness, text size, scale, and refresh rate
│   ├── AudioWidget.qml       # PipeWire volume, sinks, sources, streams
│   ├── NetworkWidget.qml     # NetworkManager Wi-Fi, DNS, hotspot
│   ├── BluetoothWidget.qml   # BlueZ pairing, devices, state
│   ├── ClockWidget.qml       # Time, calendar, week numbering
│   └── WorkspacesWidget.qml  # Hyprland workspace indicator capsule
├── services/                 # C++ / QML service backends
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
- **Quickshell:** Built with the [Quickshell](https://quickshell.org/) desktop shell engine.
- **Hyprland:** Blurring and window management powered by [Hyprland](https://hyprland.org/).
