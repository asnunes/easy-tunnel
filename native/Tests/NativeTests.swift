import Foundation

@main
struct NativeTests {
  static func main() throws {
    try DomainTests.run()
    try RepositoryTests.run()
    try SSHConfigTests.run()
    try ApplicationTests.run()
    try presentationFlow()
    try TunnelErrorMessageTests.run()
    try OpenSSHTests.run()
    print("All Swift tests passed.")
  }

  private static func presentationFlow() throws {
    try test("Native presentation handles errors, edits and typed tunnel events") {
      let backend = TestBackend()
      let store = ConnectionStore(backend: backend)
      store.refresh()
      try expect(!store.loading && !store.busy)
      try expect(store.connections[0].name == "Home lab")
      store.toggle(store.connections[0])
      try expect(backend.requests.contains("disconnect"))
      let requestsBeforeEditing = backend.requests.count
      store.edit(store.connections[0])
      try expect(store.editor?.name == "Home lab")
      try expect(backend.requests.count == requestsBeforeEditing)
      store.closeEditor()
      try expect(backend.requests.count == requestsBeforeEditing)
      store.edit(store.connections[0])
      var invalid = store.editor!
      invalid.forwards[0].localPort = "0"
      store.save(invalid)
      try expect(backend.requests.count == requestsBeforeEditing && store.editor != nil)
      backend.failure = "Could not save"
      store.save(store.editor!)
      try expect(store.error == "Could not save" && store.editor != nil)
      try expect(backend.requests.last == "saveAndReconnect")
      backend.failure = nil
      store.save(store.editor!)
      try expect(store.editor == nil)
      backend.subject.send([
        Tunnel(connectionId: "lab", status: .failed, processId: nil, error: "Permission denied")
      ])
      try expect(store.tunnel(for: "lab")?.error == "Permission denied")
      store.edit()
      var newConnection = store.editor!
      newConnection.name = "New connection"
      newConnection.forwards[0].localPort = "8080"
      newConnection.forwards[0].destinationPort = "3000"
      store.save(newConnection)
      try expect(backend.requests.last == "save")
      store.shutdown()
      try expect(backend.stopped)
    }
  }
}

func test(_ name: String, _ body: () throws -> Void) throws {
  do {
    try body()
    print("PASS: \(name)")
  } catch {
    print("FAIL: \(name): \(error)")
    throw error
  }
}

func expect(
  _ value: @autoclosure () throws -> Bool, _ message: String = "Expectation failed",
  file: StaticString = #filePath, line: UInt = #line
) throws {
  guard try value() else { throw AppError("\(message) at \(file):\(line)") }
}

func expectFailure<T>(_ body: () throws -> T) throws {
  do { _ = try body() } catch { return }
  throw AppError("Expected operation to fail")
}

func temporaryDirectory() throws -> URL {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  return url
}

func fixtureConnection(
  id: String = "lab", name: String = "Lab", localPort: Int = 5433,
  destination: String = "localhost", remotePort: Int = 5432
) throws -> Connection {
  try ConnectionInput(
    id: id, name: name, sshHostAlias: "fixture",
    forwards: [
      ForwardInput(localPort: localPort, destinationHost: destination, destinationPort: remotePort)
    ]
  ).connection()
}
