struct SaveConnection {
  let repository: ConnectionRepository
  let runtime: ConnectionRuntime

  func execute(_ connection: Connection, reconnect: Bool = false) throws {
    guard reconnect || !runtime.isRunning(connection.identifier) else {
      throw AppError("Use Save and reconnect to update an active tunnel.")
    }
    var connections = try repository.load()
    if let index = connections.firstIndex(where: { $0.id == connection.id }) {
      connections[index] = connection
    } else {
      connections.append(connection)
    }
    try repository.save(connections)
    guard reconnect else { return }
    runtime.stop(connection.identifier)
    do { try runtime.start(connection) } catch {
      throw AppError(
        "Changes were saved, but the tunnel could not reconnect: \(error.localizedDescription)")
    }
  }
}
