import Foundation

struct ConnectionInput {
  let id: String?
  let name: String
  let sshHostAlias: String
  let forwards: [ForwardInput]

  func connection() throws -> Connection {
    try Connection(
      id: ConnectionID(id ?? UUID().uuidString), name: ConnectionName(name),
      host: SSHHostAlias(sshHostAlias), forwards: forwards.map { try $0.forward() })
  }
}

struct ForwardInput {
  let localPort: Int
  let destinationHost: String
  let destinationPort: Int

  func forward() throws -> PortForward {
    try PortForward(
      local: Port(localPort), destination: DestinationHost(destinationHost),
      remote: Port(destinationPort))
  }
}
