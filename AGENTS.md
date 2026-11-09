# Autonomous Development Protocol & Operating Standards

This document establishes the mandatory operational protocol for any agent working in this codebase. These standards apply automatically whenever an existing file is modified or a new file is created.

---

## 1. Automated Verification & Self-Healing Loop
Every file modification or addition must be verified before the task is concluded:
- **QML Syntax & Formatting**: Automatically validate changed files using `qmlformat <file>`. Run `./scripts/verify.sh --all` to ensure no regression.
- **Runtime Diagnostics**: Inspect QuickShell logs (`qs log -t 20`) to confirm zero QML warnings, binding loops, or anchor errors.
- **Immediate Self-Correction**: If any syntax error, binding loop, or layout warning occurs, fix it immediately without reporting partial or broken states.

---

## 2. Production Architecture Standards (Anti-Vibe-Coding)
- **Zero Mock / Placeholder Data**: Never commit hardcoded fake arrays, simulated telemetry data, or `TODO`/`FIXME` stubs. Connect components directly to real D-Bus services, IPC sockets, NetworkManager, or system APIs.
- **Modular Layering**: Strictly maintain domain boundaries:
  - `bar/`: Panel geometry, layout modes (`floating`, `islands`, `wide`, `compact`), and IPC interfaces.
  - `widgets/`: Discrete status modules (Workspaces, Media Pill, Clock, Network, Audio, Battery, Monitor, Bluetooth).
  - `components/`: Reusable primitives (`GlassPanel`, `GlassButton`, `GlassSelectionPill`, `PopupCard`, `BarButton`).
  - `services/`: Backend communication layer (D-Bus, PipeWire, sysfs, Hyprland socket).
  - `theme/`: Centralized optical tokens, colors, and typography (`Appearance.qml`, `Theme.qml`, `Icons.qml`).
- **Explicit Typing**: Declare explicit property and parameter types. Avoid untyped or loose variables.
- **Unidirectional Reactive Flow**: Bindings must be pure and free of side effects. Never reassign a property from inside its own evaluation expression.

---

## 3. Mornye Liquid Glass UI Fidelity
- **Material Tiers**: Every surface must support the 3 Mornye quality modes (`liquid`, `frosted`, `flat`) defined in `components/GlassPanel.qml`.
- **Optical Consistency**: Adhere to centralized optical tokens (`glassClarity: 0.75`, `glassRimIllumination: 0.45`, `glassSpecularIntensity: 0.70`, `glassRefractionStrength: 0.85`).
- **Spring Physics**: Interactive elements must replicate physical spring simulation ($m=1.0, k=420.0, c=24.0$) with hover elevation (`1.025`), compression on press (`0.965`), and damped harmonic release.

---

## 4. Mandatory Git Hygiene & Privacy Guardrails
- **Immediate Commit & Push**: Every batch of completed work must be committed and pushed immediately to `origin/main`.
- **Minimalist Conventional Commits**: Use clean, concise commit messages (`feat(...)`, `fix(...)`, `chore(...)`, `docs(...)`).
- **STRICT PRIVACY CONSTRAINT**: NEVER include laptop models, processor specs, hardware identifiers, or personal device info in commits, code comments, or documentation.
