import Combine

protocol BackendClient: AnyObject {
  var events: AnyPublisher<[Tunnel], Never> { get }
  func perform(_ command: DesktopCommand, completion: @escaping (Result<Snapshot, Error>) -> Void)
  func shutdown()
}
