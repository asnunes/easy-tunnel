struct Connect {
  let repository: ConnectionRepository
  let tunnels: Tunnels

  func execute(_ id: ConnectionID) throws {
    guard let connection = try repository.load().first(where: { $0.identifier == id }) else {
      throw AppError("Connection not found.")
    }
    try tunnels.start(connection)
  }
}
