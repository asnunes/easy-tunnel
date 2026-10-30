import Foundation

struct TunnelErrorMessage {
  let summary: String
  let details: String

  init(_ error: String) {
    var seen = Set<String>()
    let lines = error.components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty && seen.insert($0).inserted }
    details = lines.joined(separator: "\n")
    let destinationRefused = lines.contains {
      $0.range(
        of: #"^channel \d+: open failed: connect failed: Connection refused$"#,
        options: .regularExpression
      ) != nil
    }
    if destinationRefused {
      summary = "Destination refused the connection.\nCheck the destination host, port and service."
      return
    }
    summary = lines.count == 1 ? lines[0] : "SSH connection failed."
  }

  var hasDetails: Bool { !details.isEmpty && details != summary }
}
