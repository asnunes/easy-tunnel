import Foundation

enum SSHConfigTests {
  static func run() throws {
    try test("SSH config discovers Includes, quoted aliases and aliases with equals") {
      let directory = try temporaryDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }
      try FileManager.default.createDirectory(
        at: directory.appendingPathComponent(".ssh/hosts"), withIntermediateDirectories: true)
      try Data(
        "Host lab lab-alias *.work !excluded\nInclude hosts/*\nHost=nas # comment\nHost \"quoted-host\"\n"
          .utf8
      ).write(to: directory.appendingPathComponent(".ssh/config"))
      try Data("Host dev\nInclude config\n".utf8).write(
        to: directory.appendingPathComponent(".ssh/hosts/dev"))
      try expect(
        SSHConfig(home: directory).list() == ["dev", "lab", "lab-alias", "nas", "quoted-host"])
    }
    try test("SSH config handles missing files and reports malformed quotes") {
      let directory = try temporaryDirectory()
      defer { try? FileManager.default.removeItem(at: directory) }
      let source = SSHConfig(home: directory)
      try expect(source.list().isEmpty)
      try FileManager.default.createDirectory(
        at: directory.appendingPathComponent(".ssh"), withIntermediateDirectories: true)
      try Data("Host \"unfinished".utf8).write(to: directory.appendingPathComponent(".ssh/config"))
      try expectFailure { try source.list() }
    }
  }
}
