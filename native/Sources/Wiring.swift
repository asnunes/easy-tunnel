import Foundation

struct Wiring {
  static func makeStore() -> ConnectionStore {
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[
      0
    ]
    .appendingPathComponent(Bundle.main.bundleIdentifier!)
    let repository = JSONConnectionRepository(
      file: support.appendingPathComponent("connections.json"))
    let hosts = SSHConfig(home: FileManager.default.homeDirectoryForCurrentUser)
    let events = MainQueueTunnelEvents()
    let tunnels = Tunnels(launcher: OpenSSH())
    let monitor = MonitorTunnels(events: events)
    let application = DesktopApplication(
      repository: repository, hosts: hosts, tunnels: tunnels, monitor: monitor)
    return ConnectionStore(
      backend: SwiftBackend(application: application, events: events.publisher))
  }
}
