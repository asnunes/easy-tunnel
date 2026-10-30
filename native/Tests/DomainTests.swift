import Foundation

enum DomainTests {
  static func run() throws {
    try test("Ports validate lower and upper boundaries") {
      try expect(Port(1).value == 1)
      try expect(Port(65535).value == 65535)
      for value in [-1, 0, 65536] { try expectFailure { try Port(value) } }
    }
    try test("Names, IDs and hosts are valid at construction") {
      try expectFailure { try ConnectionID("") }
      try expectFailure { try ConnectionName("  ") }
      try expect(ConnectionName(" Lab ").value == "Lab")
      for host in ["", "host with spaces", "$(command)", "é"] {
        try expectFailure { try SSHHostAlias(host) }
        try expectFailure { try DestinationHost(host) }
      }
      try expectFailure { try SSHHostAlias("-option") }
      try expect(DestinationHost("::1").value == "::1")
    }
    try test("Connections require distinct local ports and at least one forward") {
      let connection = try fixtureConnection()
      try expectFailure {
        try Connection(
          id: ConnectionID("lab"), name: ConnectionName("Lab"), host: SSHHostAlias("lab"),
          forwards: [])
      }
      try expectFailure {
        try Connection(
          id: ConnectionID("lab"), name: ConnectionName("Lab"), host: SSHHostAlias("lab"),
          forwards: connection.forwards + connection.forwards)
      }
    }
    try test("Native drafts validate numeric input and preserve multiple mappings") {
      var draft = ConnectionDraft(connection: nil, hosts: ["lab"])
      draft.name = " Lab "
      draft.forwards[0].localPort = "8080"
      draft.forwards[0].destinationPort = "3000"
      let connection = try draft.input().connection()
      try expect(connection.name == "Lab" && connection.forwards[0].localPort == 8080)
      for invalid in ["0", "65536", "abc", ""] {
        draft.forwards[0].localPort = invalid
        try expectFailure { try draft.input() }
      }
      draft.forwards = []
      try expectFailure { try draft.input() }
    }
  }
}
