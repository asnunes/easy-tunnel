import Combine
import Foundation

protocol BackendClient: AnyObject {
  var events: AnyPublisher<Data, Never> { get }
  func request(_ data: Data, completion: @escaping (Result<Data, Error>) -> Void)
  func shutdown()
}
