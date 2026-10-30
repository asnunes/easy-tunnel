import Combine
import Foundation

final class MainQueueTunnelEvents: TunnelEvents {
  private let subject = PassthroughSubject<[Tunnel], Never>()
  var publisher: AnyPublisher<[Tunnel], Never> { subject.eraseToAnyPublisher() }

  func changed(_ tunnels: [Tunnel]) {
    DispatchQueue.main.async { [subject] in subject.send(tunnels) }
  }
}
