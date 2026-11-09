# Production Architecture & Anti-Vibe-Coding Standards

This workspace enforces strict production-grade engineering practices. All code and modifications must adhere to the following non-negotiable architectural constraints.

---

## 1. Zero Hardcoded Mocks & Placeholder Artifacts
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
