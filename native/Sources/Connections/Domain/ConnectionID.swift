import Foundation

struct ConnectionID: Equatable, Hashable {
  private let rawValue: String
  var value: String { rawValue }
  init(_ value: String) throws {
    guard !(value.isEmpty) else { throw AppError("Give this connection an ID.") }
    self.rawValue = value
  }
}
