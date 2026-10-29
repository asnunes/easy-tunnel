final class MonitorTunnels {
  private let events: TunnelEvents
  private var previous: [Tunnel] = []

  init(events: TunnelEvents) { self.events = events }

  func execute(_ tunnels: Tunnels) {
    let current = tunnels.snapshots()
    guard current != previous else { return }
    events.changed(current)
    previous = current
  }
}
