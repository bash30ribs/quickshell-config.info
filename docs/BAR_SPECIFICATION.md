# QuickShell Liquid Glass Status Bar — Architectural Specification & Reference

This document provides a comprehensive technical breakdown of the QuickShell Liquid Glass Status Bar, mapping the web-based interactive reference (`bar.html`) to the native Qt 6 / QML / Wayland implementation.

---

## 1. System Overview & Protocol Architecture

| Parameter | QuickShell QML Implementation | Web Reference (`bar.html`) Analogue |
| :--- | :--- | :--- |
| **Compositor Protocol** | `wlr-layer-shell` via `quickshell-bar` | Fixed viewport grid (`.bar-zone`) |
| **Layer Level** | `WlrLayer.Top` (sits above normal application windows) | `z-index: 1` over wallpaper canvas |
| **Keyboard Focus** | `WlrKeyboardFocus.None` (passive, transparent to keybindings) | Non-blocking background DOM |
| **Exclusion Mode** | `ExclusionMode.Auto` (reserves desktop panel strut) | Natural document flow spacing |
| **Compositor Blur** | Hyprland dual-kawase hardware blur (`ignore_alpha = 0.05`) | CSS `backdrop-filter: blur(14px) saturate(190%)` |

---

## 2. Liquid Glass Material & Quality Tiers

The glass rendering system is implemented in [`components/GlassPanel.qml`](file:///home/ribs/.config/quickshell/components/GlassPanel.qml) and configured centrally via [`theme/Appearance.qml`](file:///home/ribs/.config/quickshell/theme/Appearance.qml).

### Optical Parameters
- **Clarity (`0.75`)**: Governs translucent surface alpha and background visibility.
- **Rim Illumination (`0.45`)**: Defines brightness of the thin outer edge border and top specular highlight line.
- **Specular Intensity (`0.70`)**: Controls intensity of the directional downward sheen gradient across the curved top edge.
- **Refraction Strength (`0.85`)**: Simulates chromatic dispersion and lens edge distortion.

### The 3 Quality Modes
1. **Liquid Mode (`Mode C`)**:
   - **QML**: Directional top specular sheen + 4-stop refraction gradient + $1\text{px}$ illuminated rim highlight.
   - **HTML Reference**: `[data-quality="liquid"] .glass-surface` with `hue-rotate()`, saturation boost, and overlay pseudos (`::before`, `::after`).
2. **Frosted Mode (`Mode B`)**:
   - **QML**: Clean dual-kawase blur pass through semi-transparent smoked background stops.
   - **HTML Reference**: `[data-quality="frosted"] .glass-surface` with increased blur ($22\text{px}$) and reduced specular sheen.
3. **Flat Mode (`Mode A`)**:
   - **QML**: High-performance solid fallback (`Theme.darker_background`) without alpha gradients.
   - **HTML Reference**: `[data-quality="flat"] .glass-surface` with solid `#0c121e` surface and simple border stroke.

---

## 3. Interactive Spring Physics

Both the native QML components ([`components/BarButton.qml`](file:///home/ribs/.config/quickshell/components/BarButton.qml), [`components/GlassButton.qml`](file:///home/ribs/.config/quickshell/components/GlassButton.qml)) and the reference preview replicate Mornye's physical spring simulation ($m=1.0, k=420.0, c=24.0$):

- **Resting Scale**: `1.0`
- **Hover Scale**: `1.025` (+ subtle brightness & border illumination boost)
- **Press Scale**: `0.965` (physical compression)
- **Release Oscillation**: Smooth harmonic return without linear snapping (`Easing.OutBack` with overshoot $1.25$ in QML; `--spring: cubic-bezier(0.34, 1.56, 0.64, 1)` in CSS).

---

## 4. Layout Modes & Presentation

The bar supports 4 presentation modes that can be dynamically toggled via IPC or file watcher:

| Mode | QML Implementation ([`bar/Bar.qml`](file:///home/ribs/.config/quickshell/bar/Bar.qml)) | HTML Preview Analogue |
| :--- | :--- | :--- |
| **`floating`** | Centered capsule with horizontal margins and bottom squircle curvature (`radius: 16`). | `width: min(1080px, calc(100vw - 32px))` |
| **`islands`** | Unifies 3 independent floating glass capsules (Left, Center, Right). | `glass-surface` transfers from `.bar-zone` to `.bar-section` |
| **`wide`** | Expands to span 72% monitor width for expansive displays. | `width: 72vw` |
| **`compact`** | Wraps strictly around content items with minimal padding. | `width: fit-content` |

---

## 5. Widget Directory & Service Bindings

| Widget | File | Service & Source | Core Interactions |
| :--- | :--- | :--- | :--- |
| **Workspaces** | [`widgets/WorkspacesWidget.qml`](file:///home/ribs/.config/quickshell/widgets/WorkspacesWidget.qml) | `WorkspacesService` (Hyprland UNIX socket) | Click to switch workspace; scroll wheel to cycle. Active workspace renders liquid specular sheen. |
| **Media Pill** | [`widgets/NowBarPill.qml`](file:///home/ribs/.config/quickshell/widgets/NowBarPill.qml) | `AudioService` (MPRIS D-Bus) | Displays album art, track title, artist, and animated visualizer waves. Click opens media player popup. |
| **Clock** | [`widgets/ClockWidget.qml`](file:///home/ribs/.config/quickshell/widgets/ClockWidget.qml) | System Clock + `PowerService` | Shows weekday, date, and clock time. Click opens Calendar and system power controls. |
| **Bluetooth** | [`widgets/BluetoothWidget.qml`](file:///home/ribs/.config/quickshell/widgets/BluetoothWidget.qml) | `BluetoothService` (BlueZ D-Bus) | Connection glyph. Click opens device scan, pair, and power management popup. |
| **Network** | [`widgets/NetworkWidget.qml`](file:///home/ribs/.config/quickshell/widgets/NetworkWidget.qml) | `NetworkService` (NetworkManager) | Strict Ethernet priority (`Metric 50`). Live throughput speeds. Click opens DNS selector & Wi-Fi scanner. |
| **Audio** | [`widgets/AudioWidget.qml`](file:///home/ribs/.config/quickshell/widgets/AudioWidget.qml) | `AudioService` (PipeWire / WirePlumber) | Speaker/headphone glyph & volume %. Scroll adjusts volume; click opens sink/source & mixer popup. |
| **Monitor** | [`widgets/MonitorWidget.qml`](file:///home/ribs/.config/quickshell/widgets/MonitorWidget.qml) | `BrightnessService` (sysfs backlight) | Brightness level %. Scroll adjusts level; click opens brightness slider & refresh rate picker. |
| **Battery** | [`widgets/BatteryWidget.qml`](file:///home/ribs/.config/quickshell/widgets/BatteryWidget.qml) | `BatteryService` (UPower) | Dynamic charging glyph & %. Click opens power profiles (Power-Saver, Balanced, Performance) & health. |

---

## 6. External Control & IPC Interface

External applications, scripts, or hotkeys interact with the bar via `qs ipc`:

```bash
# Toggle Popups
qs ipc call barpopups toggle audio
qs ipc call barpopups toggle clock
qs ipc call barpopups toggle network
qs ipc call barpopups toggle bluetooth
qs ipc call barpopups toggle battery
qs ipc call barpopups toggle monitor

# Switch Layout Modes
qs ipc call barpopups setMode floating
qs ipc call barpopups setMode islands
qs ipc call barpopups setMode wide
qs ipc call barpopups setMode compact

# Bar Visibility Control
qs ipc call barpopups toggleBar
qs ipc call barpopups showBar
qs ipc call barpopups hideBar
qs ipc call barpopups isBarVisible
```

---

## 7. Tuning & Implementation Guidelines

1. **Native Compositor Sampling**: The web preview (`bar.html`) samples a background wallpaper `div`. In actual Wayland execution, Hyprland's `hl.layer_rule` samples live windows and desktop backgrounds under the bar using GPU dual-kawase shaders.
2. **True Squircle Radii**: QML utilizes native hardware antialiased continuous corner curvature (`topLeftRadius`, `bottomLeftRadius`, etc.) configured via `Appearance.barRadius`.
3. **Reference-Only Scope**: Use `bar.html` and this document as structural and visual references. Never degrade native QML performance or break clean decoupling between services and presentation widgets.
