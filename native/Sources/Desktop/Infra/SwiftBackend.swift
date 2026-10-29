import Combine
import Foundation

final class SwiftBackend: BackendClient {
  let events: AnyPublisher<[Tunnel], Never>
  private let queue = DispatchQueue(label: "dev.easytunnel.backend")
  private let application: DesktopApplication
  private let timer: DispatchSourceTimer
  private var stopped = false

  init(application: DesktopApplication, events: AnyPublisher<[Tunnel], Never>) {
    self.application = application
    self.events = events
    timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now(), repeating: .milliseconds(150))
    timer.setEventHandler { [weak self] in self?.application.poll() }
    timer.resume()
  }

  func perform(_ command: DesktopCommand, completion: @escaping (Result<Snapshot, Error>) -> Void) {
    queue.async { [self] in
      let result = Result {
        guard !stopped else { throw AppError("The tunnel backend is not running.") }
        return try application.execute(command)
      }
      DispatchQueue.main.async { completion(result) }
    }
  }

  func shutdown() {
    queue.sync {
      stopped = true
      timer.cancel()
      application.shutdown()
    }
  }

  deinit { timer.cancel() }
}
