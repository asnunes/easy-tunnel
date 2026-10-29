final class Tunnels: ConnectionActivity {
  private let launcher: TunnelLauncher
  private var processes: [String: TunnelProcess] = [:]
  private var states: [String: Tunnel] = [:]

  init(launcher: TunnelLauncher) { self.launcher = launcher }

  func start(_ connection: Connection) throws {
    guard !isRunning(connection.identifier) else {
      throw AppError("This connection is already running.")
    }
    let process = try launcher.launch(connection)
    states[connection.id] = try process.snapshot()
    processes[connection.id] = process
  }

  func stop(_ id: ConnectionID) {
    processes.removeValue(forKey: id.value)?.stop()
    states[id.value] = Tunnel(
      connectionId: id.value, status: .disconnected, processId: nil, error: nil)
  }

  func isRunning(_ id: ConnectionID) -> Bool { processes[id.value] != nil }

  func snapshots() -> [Tunnel] {
    var finished: [String] = []
    for (id, process) in processes {
      let snapshot: Tunnel
      do { snapshot = try process.snapshot() } catch {
        snapshot = Tunnel(
          connectionId: id, status: .failed, processId: nil, error: error.localizedDescription)
      }
      states[id] = snapshot
      if !snapshot.isActive { finished.append(id) }
    }
    for id in finished { processes.removeValue(forKey: id)?.stop() }
    return states.values.sorted { $0.connectionId < $1.connectionId }
  }

  func shutdown() {
    for process in processes.values { process.stop() }
    processes.removeAll()
  }

  deinit { shutdown() }
}
