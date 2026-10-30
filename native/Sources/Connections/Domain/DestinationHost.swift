import Foundation

struct DestinationHost: Equatable, Hashable {
  private let rawValue: String
  var value: String { rawValue }
  init(_ value: String) throws {
    guard !(value.isEmpty || !validHostCharacters(value)) else {
      throw AppError("Enter a destination hostname or IP address.")
    }
    self.rawValue = value
  }
}
