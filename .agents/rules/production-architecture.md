# Production Architecture & Anti-Vibe-Coding Standards

This workspace enforces strict production-grade engineering practices. All code and modifications must adhere to the following non-negotiable architectural constraints.

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

## 1. Visual & Aesthetic Standards (No "Vibe Coding")
- **NEVER use purple gradients**, violet glow clichés, or generic AI neon templates. Use curated, intentional, domain-specific palettes (e.g., Obsidian Midnight Navy `#07111e` + Distress Amber `#f59e0b` + Horizon Steel `#94a3b8`).
- **NEVER use over-the-top scroll animations**, aggressive parallax warping, or gimmicky custom cursor animations. Keep motion purposeful, subtle, and responsive.
- **NEVER use wheel-shift buttons** or non-standard UI gimmicks.
- **NO emoji icons in hero titles or main headings** (use clean, crisp SVGs or modern typography).
- **NO excessive em-dashes (`—`)** or AI-hallmarked copywriting clichés.

---

## 2. Integrity & Content Standards (No Fake Proof)
- **NEVER use fake reviews**, fabricated user testimonials, or fake customer counters.
- **NEVER use fake metrics** or arbitrary placeholder numbers masquerading as real statistics.
- **NEVER use AI stock slur photos** or generic AI illustration tropes.
- **NEVER use AI slur copy**, boilerplate buzzwords, or pretentious AI intros.
- **ALWAYS remove any "Made with AI" / "Powered by AI" tags or badges**.

---

## 3. Mandatory Production Launch Checklist
Before launching or declaring production readiness:
1. **Favicon**: High-contrast, sharp vector/SVG or PNG favicon linked in `<head>`.
2. **Legal Pages**: Dedicated **Privacy Policy** and **Terms & Conditions** accessible from the footer and navigation.
3. **Custom Domain & SEO**: Production canonical domain support, proper meta descriptions, OpenGraph tags, and semantic HTML5.
4. **Zero Mistakes**: Flawless functionality across all API routers, database models, modals, and responsive views.

---

## 4. Zero Hardcoded Mocks & Placeholder Artifacts
- **No Mock Arrays or Stub Data**: Never commit hardcoded fake data, simulated telemetry arrays, or temporary dummy state in place of real backend services, D-Bus interfaces, IPC sockets, or system APIs.
- **No Placeholder Comments**: Avoid `// TODO: implement later`, `// fixme`, or incomplete stub implementations. Deliver complete, production-ready logic.
- **Real Data Sources**: All data consumed by UI components must originate from verified services, real system daemons, hardware interfaces, or persistent configuration files.

---

## 2. Modular Architecture & Clean Separation of Concerns
- **No Monolithic Single-File Dumps**: Never dump presentation, business logic, state handling, and styling into a single sprawling file.
- **Layered Architecture**:
  - **Presentation Layer**: Pure UI components, declarative layouts, and visual styling.
  - **Service Layer**: Dedicated services managing external communication (IPC, D-Bus, network, file I/O).
  - **State Management**: Predictable, reactive single-source-of-truth state.
  - **Design System / Tokens**: Centralized theme palettes, spacing, typography, and optical constants.
- **Reusable Components**: Abstract common patterns into dedicated, reusable component primitives.

---

## 3. Strict Typing & Explicit Interfaces
- **Explicit Property & Argument Types**: Declare explicit data types across all interfaces, components, and functions. Avoid loose untyped variables, implicit `any`, or dynamic conversions where concrete types are available.
- **Typed Signals & Methods**: All signals, callbacks, and functions must specify typed parameter signatures and return types.
- **Validation**: Enforce schema validation and boundaries at all external I/O entry points.

---

## 4. Robust Real State Management & Reactive Data Flow
- **Single Source of Truth**: State must be held by authoritative service providers or dedicated controllers, never duplicated across transient UI elements.
- **Loop-Free Bindings**: Ensure reactive bindings and property updates are strictly unidirectional without circular dependencies or side-effects inside evaluation expressions.
- **Lifecycle Cleanliness**: Properly initialize, tear down, and unbind listeners, timers, and watchers when components unmount to prevent resource leaks.

---

## 5. Comprehensive Error Handling & Resilient Fallbacks
- **Graceful Degradation**: When a hardware daemon, external service, or network connection is unavailable, components must gracefully transition to documented fallback states rather than crashing or hanging.
- **Explicit Failure Recovery**: Handle timeouts, unexpected disconnections, and process restarts automatically.
- **Structured Logging**: Emit informative, non-spammy diagnostic logs for critical events and failures. Never swallow errors silently.
