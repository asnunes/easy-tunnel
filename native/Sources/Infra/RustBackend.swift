import Combine
import Foundation

final class RustBackend: BackendClient {
  private let queue = DispatchQueue(label: "dev.easytunnel.backend")
  private var handle: OpaquePointer?

  var events: AnyPublisher<Data, Never> { nativeEvents.eraseToAnyPublisher() }

  init() {
    guard let identifier = Bundle.main.bundleIdentifier else { return }
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[
      0
    ]
    .appendingPathComponent(identifier).path
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    handle = support.withCString { data in
      home.withCString { home in easy_tunnel_create(data, home, receiveTunnelEvent) }
    }
  }

  func request(_ data: Data, completion: @escaping (Result<Data, Error>) -> Void) {
    queue.async { [self] in
      let result: Result<Data, Error>
      if let handle, let input = String(data: data, encoding: .utf8),
        let output = input.withCString({ easy_tunnel_request(handle, $0) })
      {
        let response = Data(String(cString: output).utf8)
        easy_tunnel_free_string(output)
        result = .success(response)
      } else {
        result = .failure(BackendError.unavailable)
      }
      DispatchQueue.main.async { completion(result) }
    }
  }

  func shutdown() {
    queue.sync {
      guard let handle else { return }
      easy_tunnel_destroy(handle)
      self.handle = nil
    }
  }
}

private enum BackendError: LocalizedError {
  case unavailable
  var errorDescription: String? { "The tunnel backend is not running." }
}

private let nativeEvents = PassthroughSubject<Data, Never>()

private func receiveTunnelEvent(_ json: UnsafePointer<CChar>?) {
  guard let json else { return }
  let data = Data(String(cString: json).utf8)
  DispatchQueue.main.async { nativeEvents.send(data) }
}
