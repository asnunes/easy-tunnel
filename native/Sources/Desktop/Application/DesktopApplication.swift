final class DesktopApplication {
  private let repository: ConnectionRepository
  private let hosts: HostSource
  private let tunnels: Tunnels
  private let monitor: MonitorTunnels

  init(
    repository: ConnectionRepository, hosts: HostSource, tunnels: Tunnels, monitor: MonitorTunnels
  ) {
    self.repository = repository
    self.hosts = hosts
    self.tunnels = tunnels
    self.monitor = monitor
  }

  func execute(_ command: DesktopCommand) throws -> Snapshot {
    switch command {
    case .snapshot: break
    case .save(let connection):
      try SaveConnection(repository: repository, runtime: tunnels).execute(connection)
    case .saveAndReconnect(let connection):
      try SaveConnection(repository: repository, runtime: tunnels).execute(
        connection, reconnect: true)
    case .remove(let id):
      try RemoveConnection(repository: repository, activity: tunnels).execute(id)
    case .connect(let id): try Connect(repository: repository, tunnels: tunnels).execute(id)
    case .disconnect(let id): Disconnect(tunnels: tunnels).execute(id)
    }
    let saved = try ListConnections(repository: repository, hosts: hosts).execute()
    return Snapshot(
      connections: saved.connections, hosts: saved.hosts, hostError: saved.hostError,
      tunnels: tunnels.snapshots())
  }

  func poll() { monitor.execute(tunnels) }
  func shutdown() { tunnels.shutdown() }
}

enum DesktopCommand {
  case snapshot
  case save(Connection)
  case saveAndReconnect(Connection)
  case remove(ConnectionID)
  case connect(ConnectionID)
  case disconnect(ConnectionID)
}

struct Snapshot {
  let connections: [Connection]
  let hosts: [String]
  let hostError: String?
  let tunnels: [Tunnel]
}
