struct Tunnel: Equatable {
  let connectionId: String
  let status: TunnelStatus
  let processId: Int32?
  let error: String?

  var isActive: Bool { status == .connecting || status == .connected }
}

enum TunnelStatus {
  case connecting, connected, disconnected, failed
}
