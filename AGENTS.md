# Autonomous Development Protocol & Operating Standards

This document establishes the mandatory operational protocol for any agent working in this codebase. These standards apply automatically whenever an existing file is modified or a new file is created.

---

## 0. The Engineering Creed: Precision & Rigor Over Speed
- **Never Rush**: Never prioritize speed of completion over precision. Take all the time needed to design, implement, and rigorously verify every single detail.
- **Zero Unasked Features & Unwanted Extras**: Implement strictly what is requested. Do not introduce unasked-for side effects, non-standard behaviors, or arbitrary extras that create technical debt and user friction.
- **Deep Cross-Checking**: Even for small or single-line changes, perform complete cross-verification:
  - Check for unintended visual, binding, or layout regressions.
  - Check for binding loops, memory leaks, and listener leaks.
  - Verify syntax, linting, and compile/runtime logs (`qs log -t 20`).
  - Never declare a task complete until verified live.

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

## 3. Visual & Aesthetic Standards (No "Vibe Coding")
- **NEVER use purple gradients**, violet glow clichés, or generic AI neon templates. Use curated, intentional, domain-specific palettes (e.g., Obsidian Midnight Navy `#07111e` + Distress Amber `#f59e0b` + Horizon Steel `#94a3b8`).
- **NEVER use over-the-top scroll animations**, aggressive parallax warping, or gimmicky custom cursor animations. Keep motion purposeful, subtle, and responsive.
- **NEVER use wheel-shift buttons** or non-standard UI gimmicks.
- **NO emoji icons in hero titles or main headings** (use clean, crisp SVGs or modern typography).
- **NO excessive em-dashes (`—`)** or AI-hallmarked copywriting clichés.

---

## 4. Integrity & Content Standards (No Fake Proof)
- **NEVER use fake reviews**, fabricated user testimonials, or fake customer counters.
- **NEVER use fake metrics** or arbitrary placeholder numbers masquerading as real statistics.
- **NEVER use AI stock slur photos** or generic AI illustration tropes.
- **NEVER use AI slur copy**, boilerplate buzzwords, or pretentious AI intros.
- **ALWAYS remove any "Made with AI" / "Powered by AI" tags or badges**.

---

## 5. Mandatory Production Launch Checklist
Before launching or declaring production readiness:
1. **Favicon**: High-contrast, sharp vector/SVG or PNG favicon linked in `<head>`.
2. **Legal Pages**: Dedicated **Privacy Policy** and **Terms & Conditions** accessible from the footer and navigation.
3. **Custom Domain & SEO**: Production canonical domain support, proper meta descriptions, OpenGraph tags, and semantic HTML5.
4. **Zero Mistakes**: Flawless functionality across all API routers, database models, modals, and responsive views.

---

## 6. Mornye Liquid Glass UI Fidelity
- **Material Tiers**: Every surface must support the 3 Mornye quality modes (`liquid`, `frosted`, `flat`) defined in `components/GlassPanel.qml`.
- **Optical Consistency**: Adhere to centralized optical tokens (`glassClarity: 0.75`, `glassRimIllumination: 0.45`, `glassSpecularIntensity: 0.70`, `glassRefractionStrength: 0.85`).
- **Spring Physics**: Interactive elements must replicate physical spring simulation ($m=1.0, k=420.0, c=24.0$) with hover elevation (`1.025`), compression on press (`0.965`), and damped harmonic release.

---

## 7. Mandatory Git Hygiene & Privacy Guardrails
- **Immediate Commit & Push**: Every batch of completed work must be committed and pushed immediately to `origin/main`.
- **Minimalist Conventional Commits**: Use clean, concise commit messages (`feat(...)`, `fix(...)`, `chore(...)`, `docs(...)`).
- **STRICT PRIVACY CONSTRAINT**: NEVER include laptop models, processor specs, hardware identifiers, or personal device info in commits, code comments, or documentation.
