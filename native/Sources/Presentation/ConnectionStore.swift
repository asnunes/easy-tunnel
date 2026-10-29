import Combine
import Foundation

final class ConnectionStore: ObservableObject {
  @Published private(set) var connections: [Connection] = []
  @Published private(set) var hosts: [String] = []
  @Published private(set) var tunnels: [Tunnel] = []
  @Published private(set) var hostError: String?
  @Published private(set) var busy = false
  @Published private(set) var loading = true
  @Published var error: String?
  @Published var editor: ConnectionDraft?

  private let backend: BackendClient
  private var eventSubscription: AnyCancellable?

  init(backend: BackendClient) {
    self.backend = backend
    eventSubscription = backend.events.sink { [weak self] data in self?.receive(data) }
  }

  func refresh() {
    guard !busy else { return }
    perform(NativeRequest(command: "snapshot"))
  }

  func edit(_ connection: Connection? = nil) {
    error = nil
    editor = ConnectionDraft(connection: connection, hosts: hosts)
  }

  func closeEditor() {
    editor = nil
    error = nil
  }

  func toggle(_ connection: Connection) {
    let active = tunnel(for: connection.id)?.isActive ?? false
    perform(NativeRequest(command: active ? "disconnect" : "connect", id: connection.id))
  }

  func save(_ draft: ConnectionDraft) {
    do {
      perform(
        NativeRequest(command: "save_connection", connection: try draft.input()), closeEditor: true)
    } catch { self.error = error.localizedDescription }
  }

  func remove(_ id: String) {
    perform(NativeRequest(command: "remove_connection", id: id), closeEditor: true)
  }

  func tunnel(for id: String) -> Tunnel? { tunnels.first { $0.connectionId == id } }
  func shutdown() { backend.shutdown() }

  func receive(_ data: Data) {
    do { tunnels = try JSONDecoder().decode([Tunnel].self, from: data) } catch {
      self.error = "Could not read tunnel status: \(error.localizedDescription)"
    }
  }

  private func perform(_ request: NativeRequest, closeEditor: Bool = false) {
    guard !busy else { return }
    busy = true
    error = nil
    send(request) { [weak self] response in
      guard let self else { return }
      if let error = response.error {
        self.error = error
        busy = false
        loading = false
        return
      }
      if closeEditor { editor = nil }
      if let snapshot = response.snapshot {
        apply(snapshot)
        busy = false
        loading = false
        return
      }
      send(NativeRequest(command: "snapshot")) { [weak self] response in
        guard let self else { return }
        if let snapshot = response.snapshot { apply(snapshot) }
        error = response.error
        busy = false
        loading = false
      }
    }
  }

  private func send(_ request: NativeRequest, completion: @escaping (NativeResponse) -> Void) {
    do {
      let data = try JSONEncoder().encode(request)
      backend.request(data) { result in
        do { completion(try JSONDecoder().decode(NativeResponse.self, from: result.get())) } catch {
          completion(NativeResponse(snapshot: nil, error: error.localizedDescription))
        }
      }
    } catch { completion(NativeResponse(snapshot: nil, error: error.localizedDescription)) }
  }

  private func apply(_ snapshot: Snapshot) {
    connections = snapshot.connections
    hosts = snapshot.hosts
    hostError = snapshot.hostError
    tunnels = snapshot.tunnels
  }
}
