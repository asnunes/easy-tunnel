# Working on Easy Tunnel

Keep code, comments, UI, documentation, and commit messages in English.

## Scope

This is a personal macOS SSH tunnel utility. Preserve the compact menu and one-row-per-forward editor. Do not add reconnection, migration, rollout, locking, or update infrastructure without a request.

## Architecture

The UI is native SwiftUI/AppKit in `native/`; do not recreate macOS controls or materials with web rendering. Rust is a static library containing the backend.

Follow the Farol topology: `connections` and `tunnels` have `domain`, `application`, `infra`, and `presentation`. Domain ports belong in `domain`. Value objects validate at construction and keep their fields private. Serialization belongs in presentation DTOs or infrastructure records, never in domain types. Use cases expose `execute`. Concrete Rust dependencies are assembled in `src/desktop/wiring.rs`.

Desktop presentation parses inputs and maps DTOs; desktop application dispatches use cases without C ABI types, channels, or serialization. Desktop infrastructure owns the worker, callback adapter, and C boundary. Tunnel monitoring compares domain snapshots in application and publishes through the domain event port. Keep wiring limited to dependency composition.

Native SwiftUI views and their presentation state live in `native/Sources/Presentation`. The C bridge belongs in `native/Sources/Infra`. `Wiring` injects the backend into the presentation store. Native callbacks copy their borrowed strings before returning and update presentation state on the main queue. The Rust worker owns all SSH children and is shut down before the backend is freed.

A file opens with its main exported item after imports. Helpers and private types follow it. Prefer early exits.

## Verification

Use focused Rust and native tests. `just check` checks architecture, Rust tests, Swift presentation/bridge tests, formatting, clippy, and the signed native app build. The local SSH integration test uses disposable keys and a temporary sshd; never substitute a user's remote host as a fixture.

## Design context

The audience is a developer using their own configured SSH keys on macOS. The job is switching saved groups of forwards on and off from the menu bar. Use the actual system popover, fonts, switches, fields, pickers, and dialogs. The visual tone is quiet and compact: connection name plus switch, with details in the editor. Avoid dashboards, redundant status text, and stacked mapping cards.
