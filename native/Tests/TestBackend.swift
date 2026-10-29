import Combine
import Foundation

final class TestBackend: BackendClient {
  let subject = PassthroughSubject<Data, Never>()
  var events: AnyPublisher<Data, Never> { subject.eraseToAnyPublisher() }
  var requests: [String] = []
  var failure: String?
  var stopped = false

  func request(_ data: Data, completion: @escaping (Result<Data, Error>) -> Void) {
    let object = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    let command = object["command"] as! String
    requests.append(command)
    let response: [String: Any]
    if let failure {
      response = ["error": failure]
    } else if command == "snapshot" {
      response = [
        "snapshot": [
          "connections": [
            [
              "id": "lab", "name": "Home lab", "sshHostAlias": "homelab",
              "forwards": [
                ["localPort": 5433, "destinationHost": "localhost", "destinationPort": 5432],
                ["localPort": 8080, "destinationHost": "localhost", "destinationPort": 3000],
              ],
            ]
          ], "hosts": ["homelab", "dev-box"],
          "tunnels": [["connectionId": "lab", "status": "connected", "processId": 123]],
        ]
      ]
    } else {
      response = [:]
    }
    completion(.success(try! JSONSerialization.data(withJSONObject: response)))
  }

  func shutdown() { stopped = true }
}
