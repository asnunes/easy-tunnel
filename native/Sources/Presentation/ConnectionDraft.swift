import Foundation

struct ConnectionDraft: Identifiable {
  let id = UUID()
  let connectionID: String?
  var name: String
  var host: String
  var forwards: [ForwardDraft]

  init(connection: Connection?, hosts: [String]) {
    connectionID = connection?.id
    name = connection?.name ?? ""
    host = connection?.sshHostAlias ?? hosts.first ?? ""
    forwards = connection?.forwards.map(ForwardDraft.init) ?? [ForwardDraft()]
  }

  func input() throws -> ConnectionInput {
    let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { throw DraftError.invalid("Give this connection a name.") }
    guard !host.isEmpty else { throw DraftError.invalid("Select an SSH host.") }
    guard !forwards.isEmpty else { throw DraftError.invalid("Add at least one port.") }
    return ConnectionInput(
      id: connectionID, name: name, sshHostAlias: host,
      forwards: try forwards.map { try $0.input() })
  }
}

struct ForwardDraft: Identifiable {
  let id = UUID()
  var localPort = ""
  var destinationHost = "localhost"
  var destinationPort = ""

  init() {}

  init(_ forward: PortForward) {
    localPort = String(forward.localPort)
    destinationHost = forward.destinationHost
    destinationPort = String(forward.destinationPort)
  }

  func input() throws -> ForwardInput {
    guard let local = Int(localPort), let remote = Int(destinationPort),
      (1...65535).contains(local), (1...65535).contains(remote)
    else {
      throw DraftError.invalid("Ports must be between 1 and 65535.")
    }
    return ForwardInput(
      localPort: local,
      destinationHost: destinationHost.trimmingCharacters(in: .whitespacesAndNewlines),
      destinationPort: remote)
  }
}

private enum DraftError: LocalizedError {
  case invalid(String)
  var errorDescription: String? {
    if case .invalid(let message) = self { return message }
    return nil
  }
}
