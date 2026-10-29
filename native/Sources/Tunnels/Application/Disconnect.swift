struct Disconnect {
  let tunnels: Tunnels
  func execute(_ id: ConnectionID) { tunnels.stop(id) }
}
