<img src="icons/icon.png" alt="Easy Tunnel logo" width="128" height="128">

# Easy Tunnel

A native macOS menu bar app for SSH tunnels. Pick a host from `~/.ssh/config`, save any number of local port forwards, and turn the connection on or off.

The panel uses an AppKit popover with SwiftUI controls, following the system appearance, materials, and keyboard behavior. A Rust backend manages the connections and SSH processes.

## Use

Open **Easy Tunnel.app**. Click its menu bar icon to show or hide the panel.

- **Add connection** selects an SSH host and its port mappings.
- The switch starts or stops all mappings for that connection in one SSH process.
- Click a connection name to edit it. Disconnect first to change or delete it.
- Closing the panel leaves tunnels running. **Quit Easy Tunnel** stops them.

Set up and verify the host in Terminal first (`ssh your-host`). Accept its host key there and load passphrase-protected keys into your SSH agent. Easy Tunnel uses `/usr/bin/ssh`, public-key authentication, and the existing SSH configuration; it does not store or prompt for passwords or private keys.

Local forwards bind to `127.0.0.1`. The destination host is resolved from the SSH server: `localhost` means the remote server itself. IPv6 destinations are accepted without brackets in the editor.

Named `Host` aliases and `Include` files are discovered from `~/.ssh/config`; wildcard and negated host patterns are not selectable. OpenSSH resolves the selected host's settings, including jump hosts. Existing forwarding directives in the SSH configuration also apply.

Saved connections live at:

```text
~/Library/Application Support/dev.easytunnel.desktop/connections.json
```

Tunnels do not start automatically when the app launches. There is no automatic reconnection, update service, account, or backend server.

## Develop

Requires macOS 13+, Xcode Command Line Tools with Swift, Rust, and Python 3. `just` is optional.

```sh
native/build.sh
open "target/release/bundle/macos/Easy Tunnel.app"
```

Or use `just dev`. The build links the Rust static library into the native app and applies a local ad-hoc signature. No Node.js, browser runtime, or frontend dependency installation is needed.

The release profile disables stripping because Rust 1.97.1 encountered an upstream [Mach-O debug stripping issue](https://github.com/rust-lang/rust/issues/157750) on the development machine.

The app is in `target/release/bundle/macos/`. The personal build has no Developer ID signing or notarization. For a lightweight GitHub release:

```sh
ditto -c -k --sequesterRsrc --keepParent "target/release/bundle/macos/Easy Tunnel.app" "target/release/bundle/Easy-Tunnel-macos.zip"
```

## Architecture

The project follows Farol's domain-oriented layout. The UI and backend are linked into one native process.

```text
native/
  Sources/
    EasyTunnelApp.swift  AppKit status item, system popover, and lifecycle
    Wiring.swift         Native composition root
    Presentation/        SwiftUI views, presentation state, and transport models
    Infra/               Rust static-library adapter
  Bridge/                C ABI declarations
  Tests/                 Native draft, presentation, and bridge checks
src/
  desktop/
    wiring.rs            Rust composition root
    application/         Operation dispatch with domain values
    infra/               Worker, C ABI, and native event callback
    presentation/        Command and response DTOs
  connections/
    domain/              Entities, value objects, and ports
    application/         Connection use cases
    infra/               JSON storage and SSH configuration reader
    presentation/        Connection input and output models
  tunnels/
    domain/              Tunnel state and process/event ports
    application/         Connect/disconnect and state monitoring
    infra/               OpenSSH process adapter
    presentation/        Tunnel event models
```

Native commands run off the UI thread. The Rust worker owns the application and its SSH children. `MonitorTunnels` publishes changes through a domain port; the native callback copies the event data and updates SwiftUI on the main queue. Quitting waits for Rust to stop and reap its children before releasing the backend.

## Checks

```sh
just check
```

Focused checks are also available:

```sh
cargo test --lib
native/test.sh
cargo clippy --lib -- -D warnings
cargo fmt --check
python3 scripts/check_layers.py
```

The SSH integration test launches a temporary local `sshd` with disposable keys. Native tests exercise Swift draft validation, presentation updates, and the actual C ABI save/load/delete flow. They do not modify your SSH config, keys, or known hosts.
