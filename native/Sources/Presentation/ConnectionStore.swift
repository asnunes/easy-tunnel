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
    eventSubscription = backend.events.sink { [weak self] tunnels in self?.tunnels = tunnels }
  }

  func refresh() { perform(.snapshot) }

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
    perform(active ? .disconnect(connection.identifier) : .connect(connection.identifier))
  }

  func save(_ draft: ConnectionDraft) {
    do { perform(.save(try draft.input().connection()), closeEditor: true) } catch {
      self.error = error.localizedDescription
    }
  }

  func remove(_ id: String) {
    do { perform(.remove(try ConnectionID(id)), closeEditor: true) } catch {
      self.error = error.localizedDescription
    }
  }

  func tunnel(for id: String) -> Tunnel? { tunnels.first { $0.connectionId == id } }
  func shutdown() { backend.shutdown() }

  private func perform(_ command: DesktopCommand, closeEditor: Bool = false) {
    guard !busy else { return }
    busy = true
    error = nil
    backend.perform(command) { [weak self] result in
      guard let self else { return }
      busy = false
      loading = false
      switch result {
      case .success(let snapshot):
        connections = snapshot.connections
        hosts = snapshot.hosts
        hostError = snapshot.hostError
        tunnels = snapshot.tunnels
        if closeEditor { editor = nil }
      case .failure(let failure): error = failure.localizedDescription
      }
    }
  }
}
