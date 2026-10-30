import Foundation

struct JSONConnectionRepository: ConnectionRepository {
  let file: URL

  func load() throws -> [Connection] {
    let data: Data
    do { data = try Data(contentsOf: file) } catch let error as CocoaError
      where error.code == .fileReadNoSuchFile
    { return [] } catch {
      throw AppError("Could not read saved connections: \(error.localizedDescription)")
    }
    do {
      return try JSONDecoder().decode([ConnectionRecord].self, from: data).map {
        try $0.connection()
      }
    } catch { throw AppError("Could not parse \(file.path): \(error.localizedDescription)") }
  }

  func save(_ connections: [Connection]) throws {
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(connections.map(ConnectionRecord.init)).write(to: file)
  }
}

private struct ConnectionRecord: Codable {
  let id: String
  let name: String
  let sshHostAlias: String
  let forwards: [ForwardRecord]

  init(_ connection: Connection) {
    id = connection.id
    name = connection.name
    sshHostAlias = connection.sshHostAlias
    forwards = connection.forwards.map(ForwardRecord.init)
  }

  func connection() throws -> Connection {
    try Connection(
      id: ConnectionID(id), name: ConnectionName(name), host: SSHHostAlias(sshHostAlias),
      forwards: forwards.map { try $0.forward() })
  }
}

private struct ForwardRecord: Codable {
  let localPort: Int
  let destinationHost: String
  let destinationPort: Int

  init(_ forward: PortForward) {
    localPort = forward.localPort
    destinationHost = forward.destinationHost
    destinationPort = forward.destinationPort
  }

  func forward() throws -> PortForward {
    try PortForward(
      local: Port(localPort), destination: DestinationHost(destinationHost),
      remote: Port(destinationPort))
  }
}
