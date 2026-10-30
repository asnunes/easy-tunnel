struct RemoveConnection {
  let repository: ConnectionRepository
  let activity: ConnectionActivity

  func execute(_ id: ConnectionID) throws {
    guard !activity.isRunning(id) else {
      throw AppError("Disconnect before deleting this connection.")
    }
    let connections = try repository.load().filter { $0.identifier != id }
    try repository.save(connections)
  }
}
