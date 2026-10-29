import Foundation

@main
struct NativeTests {
  static func main() throws {
    try draftValidation()
    try bridgeRoundTrip()
    storeFlow()
    print(
      "Native tests passed: draft validation, Swift/Rust round trip, and native presentation flow.")
  }

  private static func storeFlow() {
    let backend = TestBackend()
    let store = ConnectionStore(backend: backend)
    store.refresh()
    precondition(!store.loading && !store.busy)
    precondition(store.connections[0].name == "Home lab")
    store.toggle(store.connections[0])
    precondition(backend.requests.contains("disconnect"))
    store.edit(store.connections[0])
    precondition(store.editor?.name == "Home lab")
    backend.failure = "Could not save"
    store.save(store.editor!)
    precondition(store.error == "Could not save" && store.editor != nil)
    backend.failure = nil
    store.save(store.editor!)
    precondition(store.editor == nil)
    backend.subject.send(
      Data(
        "[{\"connectionId\":\"lab\",\"status\":\"failed\",\"error\":\"Permission denied\"}]".utf8))
    precondition(store.tunnel(for: "lab")?.error == "Permission denied")
    store.shutdown()
    precondition(backend.stopped)
  }

  private static func draftValidation() throws {
    var draft = ConnectionDraft(connection: nil, hosts: ["lab"])
    draft.name = " Lab "
    draft.forwards[0].localPort = "8080"
    draft.forwards[0].destinationPort = "3000"
    let input = try draft.input()
    precondition(input.name == "Lab" && input.sshHostAlias == "lab")
    precondition(input.forwards[0].localPort == 8080)
    for invalid in ["0", "65536", "abc", ""] {
      draft.forwards[0].localPort = invalid
      do {
        _ = try draft.input()
        fatalError("Invalid port was accepted")
      } catch { precondition(error.localizedDescription.contains("Ports")) }
    }
    draft.forwards = []
    do {
      _ = try draft.input()
      fatalError("Empty forwards were accepted")
    } catch { precondition(error.localizedDescription.contains("at least one")) }
  }

  private static func bridgeRoundTrip() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let handle = directory.path.withCString { easy_tunnel_create($0, $0, nil) }!
    defer { easy_tunnel_destroy(handle) }
    var draft = ConnectionDraft(connection: nil, hosts: ["lab"])
    draft.name = "Native test"
    draft.forwards[0].localPort = "8080"
    draft.forwards[0].destinationPort = "3000"
    let saved = try request(
      handle, NativeRequest(command: "save_connection", connection: try draft.input()))
    precondition(saved.error == nil)
    let snapshot = try request(handle, NativeRequest(command: "snapshot")).snapshot!
    precondition(snapshot.connections.count == 1)
    let connection = snapshot.connections[0]
    precondition(connection.name == "Native test")
    precondition(connection.forwards[0].destinationPort == 3000)
    precondition(snapshot.tunnels.isEmpty)
    let deleted = try request(
      handle, NativeRequest(command: "remove_connection", id: connection.id))
    precondition(deleted.error == nil)
    let empty = try request(handle, NativeRequest(command: "snapshot")).snapshot!
    precondition(empty.connections.isEmpty)
  }

  private static func request(_ handle: OpaquePointer, _ request: NativeRequest) throws
    -> NativeResponse
  {
    let data = try JSONEncoder().encode(request)
    let output = String(data: data, encoding: .utf8)!.withCString {
      easy_tunnel_request(handle, $0)
    }!
    defer { easy_tunnel_free_string(output) }
    return try JSONDecoder().decode(NativeResponse.self, from: Data(String(cString: output).utf8))
  }
}
