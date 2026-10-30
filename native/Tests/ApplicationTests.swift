import Combine
import Foundation

enum ApplicationTests {
  static func run() throws {
    try test("Application dispatches operations and protects running configurations") {
      let repository = MemoryRepository()
      let events = RecordingEvents()
      let launcher = RecordingLauncher()
      let tunnels = Tunnels(launcher: launcher)
      let application = DesktopApplication(
        repository: repository, hosts: UnreadableHosts(), tunnels: tunnels,
        monitor: MonitorTunnels(events: events))
      let connection = try fixtureConnection()
      let saved = try application.execute(.save(connection))
      try expect(saved.connections == [connection] && saved.hostError == "Unreadable hosts")
      try expectFailure { try application.execute(.connect(ConnectionID("missing"))) }
      _ = try application.execute(.connect(connection.identifier))
      try expectFailure { try application.execute(.connect(connection.identifier)) }
      try expectFailure { try application.execute(.save(connection)) }
      try expectFailure { try application.execute(.remove(connection.identifier)) }
      application.poll()
      application.poll()
      try expect(events.snapshots.count == 1)
      launcher.process?.status = .failed
      application.poll()
      try expect(events.snapshots.count == 2 && events.snapshots.last?[0].status == .failed)
      try expect(!tunnels.isRunning(connection.identifier) && launcher.process!.stopped)
      _ = try application.execute(.save(connection))
      _ = try application.execute(.connect(connection.identifier))
      _ = try application.execute(.disconnect(connection.identifier))
      try expect(launcher.process!.stopped)
      _ = try application.execute(.remove(connection.identifier))
      try expect(repository.connections.isEmpty)
      _ = try application.execute(.save(connection))
      _ = try application.execute(.connect(connection.identifier))
      application.shutdown()
      try expect(launcher.process!.stopped)
    }
    try test("Save and reconnect replaces only the selected running connection") {
      let repository = MemoryRepository()
      let launcher = RecordingLauncher()
      let tunnels = Tunnels(launcher: launcher)
      let application = DesktopApplication(
        repository: repository, hosts: UnreadableHosts(), tunnels: tunnels,
        monitor: MonitorTunnels(events: RecordingEvents()))
      let original = try fixtureConnection()
      let other = try fixtureConnection(id: "other", localPort: 6000)
      _ = try application.execute(.save(original))
      _ = try application.execute(.save(other))
      _ = try application.execute(.connect(original.identifier))
      let oldProcess = launcher.process!
      _ = try application.execute(.connect(other.identifier))
      let otherProcess = launcher.process!
      let updated = try fixtureConnection(name: "Updated", localPort: 8080, remotePort: 3000)
      let snapshot = try application.execute(.saveAndReconnect(updated))
      try expect(oldProcess.stopped && !otherProcess.stopped)
      try expect(launcher.connections.last == updated)
      try expect(snapshot.connections.first(where: { $0.id == original.id }) == updated)
      try expect(snapshot.tunnels.filter(\.isActive).count == 2)
      application.shutdown()
    }
    try test("Saving failure leaves the current tunnel running") {
      let repository = MemoryRepository()
      let launcher = RecordingLauncher()
      let tunnels = Tunnels(launcher: launcher)
      let application = DesktopApplication(
        repository: repository, hosts: UnreadableHosts(), tunnels: tunnels,
        monitor: MonitorTunnels(events: RecordingEvents()))
      let original = try fixtureConnection()
      _ = try application.execute(.save(original))
      _ = try application.execute(.connect(original.identifier))
      let process = launcher.process!
      repository.failSave = true
      try expectFailure {
        try application.execute(.saveAndReconnect(fixtureConnection(name: "Updated")))
      }
      try expect(!process.stopped && launcher.connections.count == 1)
      try expect(repository.connections == [original])
      application.shutdown()
    }
    try test("Reconnect launch failure keeps saved changes and does not retry") {
      let repository = MemoryRepository()
      let launcher = RecordingLauncher()
      let tunnels = Tunnels(launcher: launcher)
      let application = DesktopApplication(
        repository: repository, hosts: UnreadableHosts(), tunnels: tunnels,
        monitor: MonitorTunnels(events: RecordingEvents()))
      let original = try fixtureConnection()
      _ = try application.execute(.save(original))
      _ = try application.execute(.connect(original.identifier))
      let process = launcher.process!
      launcher.failLaunch = true
      let updated = try fixtureConnection(name: "Updated")
      do {
        _ = try application.execute(.saveAndReconnect(updated))
        throw AppError("Expected reconnect to fail")
      } catch {
        try expect(
          error.localizedDescription.contains(
            "Changes were saved, but the tunnel could not reconnect"))
      }
      try expect(process.stopped && !tunnels.isRunning(original.identifier))
      try expect(repository.connections == [updated] && launcher.connections.count == 2)
      application.shutdown()
    }
    try test("Background backend delivers typed snapshots on the main thread") {
      let events = MainQueueTunnelEvents()
      let launcher = RecordingLauncher()
      let application = DesktopApplication(
        repository: MemoryRepository(), hosts: UnreadableHosts(),
        tunnels: Tunnels(launcher: launcher), monitor: MonitorTunnels(events: events))
      let backend = SwiftBackend(application: application, events: events.publisher)
      let connection = try fixtureConnection()
      var response: Result<Snapshot, Error>?
      backend.perform(.save(connection)) { value in
        precondition(Thread.isMainThread)
        response = value
      }
      let deadline = Date().addingTimeInterval(3)
      while response == nil && Date() < deadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
      }
      try expect(response != nil)
      try expect(response!.get().connections == [connection])
      backend.shutdown()
    }
  }
}

private final class MemoryRepository: ConnectionRepository {
  var connections: [Connection] = []
  var failSave = false
  func load() throws -> [Connection] { connections }
  func save(_ connections: [Connection]) throws {
    if failSave { throw AppError("Disk unavailable") }
    self.connections = connections
  }
}

private struct UnreadableHosts: HostSource {
  func list() throws -> [String] { throw AppError("Unreadable hosts") }
}

private final class RecordingEvents: TunnelEvents {
  var snapshots: [[Tunnel]] = []
  func changed(_ tunnels: [Tunnel]) { snapshots.append(tunnels) }
}

private final class RecordingLauncher: TunnelLauncher {
  var process: RecordingProcess?
  var connections: [Connection] = []
  var failLaunch = false
  func launch(_ connection: Connection) throws -> TunnelProcess {
    connections.append(connection)
    if failLaunch { throw AppError("Could not start SSH") }
    let process = RecordingProcess(id: connection.id)
    self.process = process
    return process
  }
}

private final class RecordingProcess: TunnelProcess {
  let id: String
  var status: TunnelStatus = .connected
  var stopped = false
  init(id: String) { self.id = id }
  func snapshot() throws -> Tunnel {
    Tunnel(
      connectionId: id, status: status, processId: 123,
      error: status == .failed ? "Connection lost" : nil)
  }
  func stop() { stopped = true }
}
