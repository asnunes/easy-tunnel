import Foundation

struct SSHHostAlias: Equatable, Hashable {
  private let rawValue: String
  var value: String { rawValue }
  init(_ value: String) throws {
    guard !(value.isEmpty || value.hasPrefix("-") || !validHostCharacters(value)) else {
      throw AppError("Select a valid SSH host alias.")
    }
    self.rawValue = value
  }
}
