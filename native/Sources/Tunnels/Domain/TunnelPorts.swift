protocol TunnelProcess: AnyObject {
  func snapshot() throws -> Tunnel
  func stop()
}

protocol TunnelLauncher {
  func launch(_ connection: Connection) throws -> TunnelProcess
}

protocol TunnelEvents {
  func changed(_ tunnels: [Tunnel])
}
