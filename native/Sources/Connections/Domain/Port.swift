struct Port: Equatable, Hashable {
  private let rawValue: Int
  var value: Int { rawValue }
  init(_ value: Int) throws {
    guard (1...65535).contains(value) else { throw AppError("Ports must be between 1 and 65535.") }
    self.rawValue = value
  }
}
