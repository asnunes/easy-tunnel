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
  func load() throws -> [Connection] { connections }
  func save(_ connections: [Connection]) throws { self.connections = connections }
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
  func launch(_ connection: Connection) throws -> TunnelProcess {
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
