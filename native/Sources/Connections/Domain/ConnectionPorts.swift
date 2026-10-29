protocol ConnectionRepository {
  func load() throws -> [Connection]
  func save(_ connections: [Connection]) throws
}

protocol HostSource {
  func list() throws -> [String]
}

protocol ConnectionActivity {
  func isRunning(_ id: ConnectionID) -> Bool
}
