import Foundation

struct ConnectionName: Equatable, Hashable {
  private let rawValue: String
  var value: String { rawValue }
  init(_ value: String) throws {
    let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !(value.isEmpty) else { throw AppError("Give this connection a name.") }
    self.rawValue = value
  }
}
