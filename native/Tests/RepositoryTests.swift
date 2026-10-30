import Foundation

enum RepositoryTests {
  static func run() throws {
    try test("JSON repository reads, edits and removes saved connections") {
      let directory = try temporaryDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }
      let repository = JSONConnectionRepository(
        file: directory.appendingPathComponent("data/connections.json"))
      try expect(repository.load().isEmpty)
      let original = try fixtureConnection()
      try repository.save([original])
      try expect(repository.load() == [original])
      let data = try Data(contentsOf: repository.file)
      let object = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
      try expect(object[0]["sshHostAlias"] as? String == "fixture")
      let forward = (object[0]["forwards"] as! [[String: Any]])[0]
      try expect(forward["destinationPort"] as? Int == 5432)
      let updated = try fixtureConnection(name: "Updated")
      try repository.save([updated])
      try expect(repository.load() == [updated])
      try repository.save([])
      try expect(repository.load().isEmpty)
    }
    try test("Invalid stored values are rejected without overwriting the file") {
      let directory = try temporaryDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }
      let repository = JSONConnectionRepository(
        file: directory.appendingPathComponent("connections.json"))
      for content in [
        "broken",
        "[{\"id\":\"lab\",\"name\":\"Lab\",\"sshHostAlias\":\"lab\",\"forwards\":[{\"localPort\":0,\"destinationHost\":\"localhost\",\"destinationPort\":5432}]}]",
      ] {
        try Data(content.utf8).write(to: repository.file)
        try expectFailure { try repository.load() }
        try expect(String(contentsOf: repository.file, encoding: .utf8) == content)
      }
    }
  }
}
