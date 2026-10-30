<img src="icons/icon.png" alt="Easy Tunnel logo" width="128" height="128">

# Easy Tunnel

A native macOS menu bar app for SSH tunnels. Pick a host from `~/.ssh/config`, save any number of local port forwards, and turn the connection on or off.

The panel uses a declarative SwiftUI App and MenuBarExtra with native controls, following the system appearance, materials, and keyboard behavior. The app is written entirely in Swift, including connection storage and SSH process management.

## Use

Open **Easy Tunnel.app**. Click its menu bar icon to show or hide the panel. The app does not programmatically open the panel on launch or reopen.

- **Add connection** selects an SSH host and its port mappings.
- The switch starts or stops all mappings for that connection in one SSH process.
- Click a connection name to edit it, even while connected. **Save and reconnect** disconnects the active tunnel and starts it with the saved changes. Cancel leaves it running unchanged. Disconnect before deleting a connection.
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

Requires macOS 13+ and Xcode Command Line Tools with Swift. `just` and Python 3 are only needed for the combined check command.

```sh
native/build.sh
open "target/release/bundle/macos/Easy Tunnel.app"
```

Or use `just dev`. The build compiles Swift sources and applies a local ad-hoc signature. There are no third-party runtime dependencies.

The app is in `target/release/bundle/macos/`. The personal build has no Developer ID signing or notarization. For a lightweight GitHub release:

```sh
ditto -c -k --sequesterRsrc --keepParent "target/release/bundle/macos/Easy Tunnel.app" "target/release/bundle/Easy-Tunnel-macos.zip"
```

## Architecture

The project follows Farol's domain-oriented layout within one Swift application.

```text
native/Sources/
  EasyTunnelApp.swift     SwiftUI App, MenuBarExtra, and termination lifecycle
  Wiring.swift            Composition root
  Connections/
    Domain/               Connections, value objects, and repository protocols
    Application/          Save, remove, and list use cases
    Infra/                JSON records and SSH configuration reader
  Tunnels/
    Domain/               Tunnel states and process/event protocols
    Application/          Connect, disconnect, and state monitoring
    Infra/                OpenSSH process adapter
  Desktop/
    Application/          Typed operation dispatch
    Infra/                Background queue, polling, and event publication
  Presentation/           SwiftUI views, drafts, and presentation state
  Infra/                  Native application menu
  Shared/                 Application errors
native/Tests/             Swift tests and native layout previews
```

Value objects validate at construction. Domain types have no serialization behavior; JSON is used only for saved connection records. The UI calls the application with typed Swift commands and receives typed snapshots and tunnel events.

The backend queue owns the SSH processes and reads their output without blocking. State changes return to the main queue through Combine. Quitting stops and waits for all owned SSH children before returning.

## Checks

```sh
just check
```

Focused checks are also available:

```sh
native/test.sh
native/build.sh
python3 scripts/check_layers.py
```

The SSH integration test launches a temporary local `sshd` with disposable keys. Tests cover value objects, JSON storage, SSH config Includes, application operations, presentation updates, real tunnel traffic, occupied ports, connection failures, and process cleanup. They do not modify your SSH config, keys, or known hosts.
