import Foundation

struct Wiring {
  static func makeStore() -> ConnectionStore {
    ConnectionStore(backend: RustBackend())
  }
}
