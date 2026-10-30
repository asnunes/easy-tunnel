struct ListConnections {
  let repository: ConnectionRepository
  let hosts: HostSource

  func execute() throws -> ConnectionListing {
    let connections = try repository.load()
    do {
      return ConnectionListing(connections: connections, hosts: try hosts.list(), hostError: nil)
    } catch {
      return ConnectionListing(
        connections: connections, hosts: [], hostError: error.localizedDescription)
    }
  }
}

struct ConnectionListing {
  let connections: [Connection]
  let hosts: [String]
  let hostError: String?
}
