import Combine
import Foundation

final class TestBackend: BackendClient {
  let subject = PassthroughSubject<[Tunnel], Never>()
  var events: AnyPublisher<[Tunnel], Never> { subject.eraseToAnyPublisher() }
  var requests: [String] = []
  var failure: String?
  var stopped = false

  func perform(_ command: DesktopCommand, completion: @escaping (Result<Snapshot, Error>) -> Void) {
    switch command {
    case .snapshot: requests.append("snapshot")
    case .save: requests.append("save")
    case .saveAndReconnect: requests.append("saveAndReconnect")
    case .remove: requests.append("remove")
    case .connect: requests.append("connect")
    case .disconnect: requests.append("disconnect")
    }
    if let failure {
      completion(.failure(AppError(failure)))
      return
    }
    let connection = try! ConnectionInput(
      id: "lab", name: "Home lab", sshHostAlias: "homelab",
      forwards: [
        ForwardInput(localPort: 5433, destinationHost: "localhost", destinationPort: 5432),
        ForwardInput(localPort: 8080, destinationHost: "localhost", destinationPort: 3000),
      ]
    ).connection()
    completion(
      .success(
        Snapshot(
          connections: [connection], hosts: ["homelab", "dev-box"], hostError: nil,
          tunnels: [Tunnel(connectionId: "lab", status: .connected, processId: 123, error: nil)])))
  }

  func shutdown() { stopped = true }
}
