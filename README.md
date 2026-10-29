<img src="icons/icon.png" alt="Easy Tunnel logo" width="128" height="128">

# Easy Tunnel

A small macOS menu bar app for SSH tunnels. Pick a host from `~/.ssh/config`, save any number of local port forwards, and turn the connection on or off.

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

Requires macOS 12+, Xcode Command Line Tools, Rust, and Node.js with npm.

```sh
npm --prefix web ci
npm --prefix web run desktop -- dev
```

Build a local app:

```sh
npm --prefix web run desktop -- build
```

On this machine, Rust 1.97.1 encountered the upstream [Mach-O debug stripping issue](https://github.com/rust-lang/rust/issues/157750). The release profile disables stripping so the build works with that toolchain.

The app is in `target/release/bundle/macos/`. The personal build has no Developer ID signing or notarization. For a lightweight GitHub release, zip the app:

```sh
ditto -c -k --sequesterRsrc --keepParent "target/release/bundle/macos/Easy Tunnel.app" "target/release/bundle/Easy-Tunnel-macos.zip"
```

## Architecture

The project follows Farol's domain-oriented layout. Rust lives at the root and the React/TypeScript frontend lives in `web/`.

```text
src/
  desktop/
    wiring.rs    Composition root only
    application/ Operation dispatch with domain values and application results
    infra/       Worker thread, Tauri lifecycle, tray, panel, and event adapter
    presentation/ Tauri commands and web DTOs
  connections/   Saved connections, port mappings, and SSH host discovery
    domain/      Entities and ports
    application/ Use cases
    infra/       JSON storage and SSH configuration reader
    presentation/ Input and output models
  tunnels/       Running SSH processes
    domain/      Tunnel state and process ports
    application/ Connect/disconnect, state monitoring, and execution service
    infra/       OpenSSH process adapter
    presentation/ Tunnel event models
web/src/
  connections/   Compact list and connection editor
  hooks/         UI state and event subscription
  api.ts         Typed Tauri boundary
```

`desktop/wiring.rs` constructs concrete dependencies. Tauri handlers translate input and invoke application use cases. The tunnel module consumes the connection domain's repository contract; connections depend on an activity port to prevent edits to a running tunnel.

The desktop application has no Tauri, channel, or serialization dependencies. Commands convert web input to domain values before dispatch and map application results to DTOs on return. `MonitorTunnels` compares domain snapshots and publishes changes through the `TunnelEvents` port; the Tauri adapter handles the event payload.

A worker thread owns the application and its SSH children. Desktop requests pass through a channel, and tunnel state changes return through Tauri events. No process handle or filesystem access is exposed to the webview. Dropping the worker's processes on normal app exit kills and reaps its SSH children.

## Checks

```sh
just check
```

Or run focused checks directly:

```sh
cargo test --lib
cargo clippy --lib -- -D warnings
cargo fmt --check
npm --prefix web test
npm --prefix web run build
```

The SSH integration test launches a temporary local `sshd` with disposable keys. It verifies forwarded traffic, an occupied local port, and process cleanup without touching your SSH config, keys, or known hosts.
