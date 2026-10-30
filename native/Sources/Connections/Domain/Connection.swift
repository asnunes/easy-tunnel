struct Connection: Identifiable, Equatable {
  private let connectionID: ConnectionID
  private let connectionName: ConnectionName
  private let host: SSHHostAlias
  private let portForwards: [PortForward]

  init(id: ConnectionID, name: ConnectionName, host: SSHHostAlias, forwards: [PortForward]) throws {
    guard !forwards.isEmpty else { throw AppError("Add at least one port.") }
    var ports = Set<Port>()
    for forward in forwards {
      guard ports.insert(forward.local).inserted else {
        throw AppError("Local port \(forward.localPort) is used twice.")
      }
    }
    connectionID = id
    connectionName = name
    self.host = host
    portForwards = forwards
  }

  var identifier: ConnectionID { connectionID }
  var forwards: [PortForward] { portForwards }
  var id: String { identifier.value }
  var name: String { connectionName.value }
  var sshHostAlias: String { host.value }
}
