# Working on Easy Tunnel

Keep code, comments, UI, documentation, and commit messages in English.

## Scope

This is a personal macOS SSH tunnel utility written entirely in Swift. Preserve the compact menu and one-row-per-forward editor. Do not add reconnection, migration, rollout, locking, or update infrastructure without a request.

## Architecture

Use a declarative SwiftUI App and MenuBarExtra with native controls and system editing commands. Keep AppKit lifecycle integration limited to termination cleanup. All application code lives in `native/Sources`.

Follow the Farol topology: `Connections` and `Tunnels` have `Domain`, `Application`, and `Infra`. Domain protocols belong in `Domain`. Value objects validate at construction and keep stored values private. Domain types do not conform to Codable; persistence records belong in infrastructure. Use cases expose `execute`.

`Desktop/Application` dispatches typed operations. `Desktop/Infra` owns the background queue, timer, and event publisher. Process handles, file IO and SSH config parsing stay in infrastructure. Application and domain do not import UI, Combine, or dispatch APIs. `Presentation` holds native views, drafts and presentation state; its backend interface passes Swift values, not JSON.

`Wiring.swift` is the composition root. It injects repositories, host discovery, process launcher, event sink, application, and backend. The backend queue owns every SSH process and polls their nonblocking output. It delivers results on the main queue. Quitting waits for all owned SSH processes to stop.

A file opens with its main exported item after imports. Helpers and private types follow it. Prefer early exits.

## Verification

Use focused Swift tests. `just check` checks architecture, Swift tests, and the signed app build. The local SSH integration test uses disposable keys and a temporary sshd; never substitute a user's remote host as a fixture.

## Design context

The audience is a developer using their own configured SSH keys on macOS. The job is switching saved groups of forwards on and off from the menu bar. Use the actual system popover, fonts, switches, fields, pickers, and dialogs. The visual tone is quiet and compact: connection name plus switch, with details in the editor. Avoid dashboards, redundant status text, and stacked mapping cards.
