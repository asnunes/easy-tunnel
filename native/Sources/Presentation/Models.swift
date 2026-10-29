import Foundation

struct Connection: Codable, Identifiable, Equatable {
  let id: String
  let name: String
  let sshHostAlias: String
  let forwards: [PortForward]
}

struct PortForward: Codable, Equatable {
  let localPort: Int
  let destinationHost: String
  let destinationPort: Int
}

struct ConnectionInput: Encodable {
  let id: String?
  let name: String
  let sshHostAlias: String
  let forwards: [PortForward]
}

struct Tunnel: Decodable, Equatable {
  let connectionId: String
  let status: String
  let processId: Int?
  let error: String?

  var isActive: Bool { status == "connected" || status == "connecting" }
}

struct Snapshot: Decodable {
  let connections: [Connection]
  let hosts: [String]
  let hostError: String?
  let tunnels: [Tunnel]
}

struct NativeResponse: Decodable {
  let snapshot: Snapshot?
  let error: String?
}

struct NativeRequest: Encodable {
  let command: String
  var id: String? = nil
  var connection: ConnectionInput? = nil
}
