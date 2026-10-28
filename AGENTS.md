# Working on Easy Tunnel

Keep code, comments, UI, documentation, and commit messages in English.

## Scope

This is a personal macOS SSH tunnel utility. Preserve the compact menu and one-row-per-forward editor. Do not add reconnection, migration, rollout, locking, or update infrastructure without a request.

## Architecture

Follow the Farol topology: `connections` and `tunnels` have `domain`, `application`, `infra`, and `presentation`. Domain ports belong in `domain`. Use cases expose `execute`. Concrete dependencies are assembled in `src/desktop/wiring.rs`.

Only `src/desktop/` references Tauri. Infrastructure implements domain ports; business decisions stay in application/domain. Cross-module use cases depend on domain contracts, not another module's infrastructure. The worker owns running SSH children and publishes snapshots through desktop events.

A file opens with its main exported item after imports. Helpers and private types follow it. Prefer early exits.

## Verification

Use focused Rust and frontend tests. `just check` runs this small project's checks. The local SSH integration test uses disposable keys and a temporary sshd; never substitute a user's remote host as a fixture.

## Design context

The audience is a developer using their own configured SSH keys on macOS. The job is switching saved groups of forwards on and off from the menu bar. The visual tone is quiet, compact, and native: connection name plus switch, with details in the editor. Avoid dashboards, redundant status text, and stacked mapping cards.
