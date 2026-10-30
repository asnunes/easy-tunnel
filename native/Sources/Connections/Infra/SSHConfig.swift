import Darwin
import Foundation

struct SSHConfig: HostSource {
  let home: URL

  func list() throws -> [String] {
    var visited = Set<String>()
    var hosts = Set<String>()
    try read(home.appendingPathComponent(".ssh/config"), visited: &visited, hosts: &hosts)
    return hosts.sorted()
  }

  private func read(_ file: URL, visited: inout Set<String>, hosts: inout Set<String>) throws {
    let canonical = file.resolvingSymlinksInPath().standardizedFileURL
    guard visited.insert(canonical.path).inserted else { return }
    let text: String
    do { text = try String(contentsOf: canonical, encoding: .utf8) } catch let error as CocoaError
      where error.code == .fileReadNoSuchFile
    { return } catch { throw AppError("Could not read SSH config: \(error.localizedDescription)") }
    for rawLine in text.components(separatedBy: .newlines) {
      let line = rawLine.trimmingCharacters(in: .whitespaces)
      guard !line.hasPrefix("#"),
        let split = line.firstIndex(where: { $0.isWhitespace || $0 == "=" })
      else { continue }
      let key = line[..<split].lowercased()
      guard key == "host" || key == "include" else { continue }
      let rest = line[split...].drop(while: { $0.isWhitespace || $0 == "=" })
      let values = try tokens(String(rest))
      if key == "host" {
        hosts.formUnion(
          values.filter { !$0.isEmpty && !$0.contains(where: { "*?!".contains($0) }) })
        continue
      }
      for value in values {
        let pattern: String
        if value.hasPrefix("~/") {
          pattern = home.appendingPathComponent(String(value.dropFirst(2))).path
        } else if value.hasPrefix("/") {
          pattern = value
        } else {
          pattern = home.appendingPathComponent(".ssh").appendingPathComponent(value).path
        }
        var paths = glob_t()
        let result = pattern.withCString { Darwin.glob($0, 0, nil, &paths) }
        defer { globfree(&paths) }
        guard result != GLOB_NOMATCH else { continue }
        guard result == 0 else { throw AppError("Could not expand SSH Include: \(value)") }
        for index in 0..<Int(paths.gl_pathc) {
          if let path = paths.gl_pathv[index] {
            try read(URL(fileURLWithPath: String(cString: path)), visited: &visited, hosts: &hosts)
          }
        }
      }
    }
  }

  private func tokens(_ line: String) throws -> [String] {
    var result: [String] = []
    var token = ""
    var quote: Character?
    var escaped = false
    var started = false
    for character in line {
      if escaped {
        token.append(character)
        escaped = false
        started = true
        continue
      }
      if character == "\\" && quote != "'" {
        escaped = true
        started = true
        continue
      }
      if let currentQuote = quote {
        if character == currentQuote { quote = nil } else { token.append(character) }
        continue
      }
      if character == "#" { break }
      if character == "\"" || character == "'" {
        quote = character
        started = true
        continue
      }
      if character.isWhitespace {
        if started {
          result.append(token)
          token = ""
          started = false
        }
        continue
      }
      token.append(character)
      started = true
    }
    guard quote == nil && !escaped else { throw AppError("Invalid quoting in SSH config.") }
    if started { result.append(token) }
    return result
  }
}
