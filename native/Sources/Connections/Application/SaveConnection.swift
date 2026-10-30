struct SaveConnection {
  let repository: ConnectionRepository
  let activity: ConnectionActivity

  func execute(_ connection: Connection) throws {
    guard !activity.isRunning(connection.identifier) else {
      throw AppError("Disconnect before editing this connection.")
    }
    var connections = try repository.load()
    if let index = connections.firstIndex(where: { $0.id == connection.id }) {
      connections[index] = connection
    } else {
      connections.append(connection)
    }
    try repository.save(connections)
  }
}
