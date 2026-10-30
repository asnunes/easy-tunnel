import Combine
import Darwin
import Foundation

enum OpenSSHTests {
  static func run() throws {
    try test("SSH arguments bind locally, preserve IPv6 and use public keys") {
      let connection = try fixtureConnection(localPort: 8080, destination: "::1", remotePort: 80)
      let arguments = OpenSSH().arguments(connection)
      try expect(arguments.contains("127.0.0.1:8080:[::1]:80"))
      try expect(arguments.contains("BatchMode=yes"))
      try expect(arguments.contains("ControlPath=none"))
      try expect(arguments.last == "fixture")
    }
    try test("Real SSH forwards traffic, reports occupied ports and releases sockets") {
      let fixture = try SSHFixture()
      let destination = try ListeningSocket()
      let localPort = try ListeningSocket.freePort()
      let connection = try fixtureConnection(
        localPort: localPort, destination: "127.0.0.1", remotePort: destination.port)
      let secondPort = try ListeningSocket.freePort()
      let multiConnection = try Connection(
        id: connection.identifier, name: ConnectionName(connection.name),
        host: SSHHostAlias(connection.sshHostAlias),
        forwards: connection.forwards + [
          PortForward(
            local: Port(secondPort), destination: DestinationHost("127.0.0.1"),
            remote: Port(destination.port))
        ])
      let launcher = OpenSSH(configurationFile: fixture.config)
      let process = try launcher.launch(multiConnection)
      defer { process.stop() }
      _ = try wait(process, for: .connected)

      let client = try connectedSocket(port: localPort)
      defer { Darwin.close(client) }
      let message = Array("hello tunnel".utf8)
      try expect(
        message.withUnsafeBytes { Darwin.write(client, $0.baseAddress, $0.count) } == message.count)
      let server = Darwin.accept(destination.descriptor, nil, nil)
      guard server >= 0 else { throw AppError("Forward did not reach destination") }
      defer { Darwin.close(server) }
      setReadTimeout(server)
      var received = [UInt8](repeating: 0, count: message.count)
      let count = Darwin.read(server, &received, received.count)
      try expect(count == message.count && received == message)
      try expect(Darwin.write(server, "ok", 2) == 2)
      var response = [UInt8](repeating: 0, count: 2)
      try expect(Darwin.read(client, &response, 2) == 2 && response == Array("ok".utf8))

      let secondClient = try connectedSocket(port: secondPort)
      defer { Darwin.close(secondClient) }
      try expect(Darwin.write(secondClient, "second", 6) == 6)
      let secondServer = Darwin.accept(destination.descriptor, nil, nil)
      guard secondServer >= 0 else { throw AppError("Second forward did not reach destination") }
      defer { Darwin.close(secondServer) }
      setReadTimeout(secondServer)
      var secondMessage = [UInt8](repeating: 0, count: 6)
      try expect(
        Darwin.read(secondServer, &secondMessage, 6) == 6 && secondMessage == Array("second".utf8))

      let occupied = try launcher.launch(multiConnection)
      defer { occupied.stop() }
      let failure = try wait(occupied, for: .failed)
      try expect(failure.error?.contains("Address already in use") == true)
      process.stop()
      try expect(process.snapshot().status == .disconnected)
      try expectFailure {
        let socket = try connectedSocket(port: localPort)
        Darwin.close(socket)
      }

      var restarted: TunnelProcess? = try launcher.launch(multiConnection)
      _ = try wait(restarted!, for: .connected)
      restarted = nil
      try expectFailure {
        let socket = try connectedSocket(port: localPort)
        Darwin.close(socket)
      }
    }
    try test("Background Swift backend publishes real SSH states and cleans up on shutdown") {
      let fixture = try SSHFixture()
      let repository = JSONConnectionRepository(
        file: fixture.directory.appendingPathComponent("connections.json"))
      let events = MainQueueTunnelEvents()
      let application = DesktopApplication(
        repository: repository, hosts: SSHConfig(home: fixture.directory),
        tunnels: Tunnels(launcher: OpenSSH(configurationFile: fixture.config)),
        monitor: MonitorTunnels(events: events))
      let backend = SwiftBackend(application: application, events: events.publisher)
      var latest: [Tunnel] = []
      let subscription = events.publisher.sink { values in
        precondition(Thread.isMainThread)
        latest = values
      }
      defer {
        backend.shutdown()
        withExtendedLifetime(subscription) {}
      }
      let port = try ListeningSocket.freePort()
      let connection = try fixtureConnection(localPort: port)
      _ = try perform(backend, .save(connection))
      _ = try perform(backend, .connect(connection.identifier))
      let deadline = Date().addingTimeInterval(5)
      while latest.first?.status != .connected && Date() < deadline {
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
      }
      try expect(latest.first?.status == .connected)
      backend.shutdown()
      try expectFailure {
        let socket = try connectedSocket(port: port)
        Darwin.close(socket)
      }
    }
    try test("SSH connection failures surface as errors instead of connected states") {
      let fixture = try SSHFixture()
      let connection = try fixtureConnection(localPort: ListeningSocket.freePort())
      fixture.stop()
      let process = try OpenSSH(configurationFile: fixture.config).launch(connection)
      defer { process.stop() }
      let failure = try wait(process, for: .failed)
      try expect(failure.error?.contains("Connection refused") == true)
    }
  }

  private static func perform(_ backend: SwiftBackend, _ command: DesktopCommand) throws -> Snapshot
  {
    var response: Result<Snapshot, Error>?
    backend.perform(command) { response = $0 }
    let deadline = Date().addingTimeInterval(5)
    while response == nil && Date() < deadline {
      RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }
    guard let response else { throw AppError("Background command timed out") }
    return try response.get()
  }

  private static func wait(_ process: TunnelProcess, for status: TunnelStatus) throws -> Tunnel {
    let deadline = Date().addingTimeInterval(8)
    while Date() < deadline {
      let state = try process.snapshot()
      if state.status == status { return state }
      if state.status == .failed { throw AppError(state.error ?? "SSH failed") }
      Thread.sleep(forTimeInterval: 0.02)
    }
    throw AppError("Timed out waiting for SSH state \(status)")
  }
}

private final class SSHFixture {
  let directory: URL
  let config: URL
  private let daemon = Process()

  init() throws {
    directory = try temporaryDirectory()
    config = directory.appendingPathComponent("config")
    for name in ["host", "identity"] {
      let keygen = Process()
      keygen.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
      keygen.arguments = [
        "-q", "-t", "ed25519", "-N", "", "-f", directory.appendingPathComponent(name).path,
      ]
      try keygen.run()
      keygen.waitUntilExit()
      try expect(keygen.terminationStatus == 0)
    }
    try FileManager.default.copyItem(
      at: directory.appendingPathComponent("identity.pub"),
      to: directory.appendingPathComponent("authorized_keys"))
    let port = try ListeningSocket.freePort()
    let key = try String(contentsOf: directory.appendingPathComponent("host.pub"), encoding: .utf8)
    try Data("[127.0.0.1]:\(port) \(key)".utf8).write(
      to: directory.appendingPathComponent("known_hosts"))
    let root = directory.path
    let daemonConfig =
      "Port \(port)\nListenAddress 127.0.0.1\nHostKey \(root)/host\nPidFile \(root)/pid\nAuthorizedKeysFile \(root)/authorized_keys\nPasswordAuthentication no\nUsePAM no\nStrictModes no\nAllowTcpForwarding yes\n"
    try Data(daemonConfig.utf8).write(to: directory.appendingPathComponent("sshd_config"))
    try Data(
      "Host fixture\n HostName 127.0.0.1\n Port \(port)\n IdentityFile \(root)/identity\n IdentitiesOnly yes\n UserKnownHostsFile \(root)/known_hosts\n"
        .utf8
    ).write(to: config)
    daemon.executableURL = URL(fileURLWithPath: "/usr/sbin/sshd")
    daemon.arguments = ["-D", "-e", "-f", directory.appendingPathComponent("sshd_config").path]
    daemon.standardOutput = FileHandle.nullDevice
    daemon.standardError = FileHandle.nullDevice
    try daemon.run()
    let deadline = Date().addingTimeInterval(3)
    while Date() < deadline {
      if let socket = try? connectedSocket(port: port) {
        Darwin.close(socket)
        return
      }
      Thread.sleep(forTimeInterval: 0.02)
    }
    stop()
    throw AppError("Local SSH fixture did not start")
  }

  func stop() {
    if daemon.isRunning { daemon.terminate() }
    daemon.waitUntilExit()
  }

  deinit {
    stop()
    try? FileManager.default.removeItem(at: directory)
  }
}

private final class ListeningSocket {
  let descriptor: Int32
  let port: Int

  init() throws {
    let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
    guard socket >= 0 else { throw AppError("Could not create test socket") }
    var address = socketAddress(port: 0)
    let result = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Darwin.bind(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    guard result == 0 && Darwin.listen(socket, 4) == 0 else {
      Darwin.close(socket)
      throw AppError("Could not bind test socket")
    }
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    _ = withUnsafeMutablePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(socket, $0, &length) }
    }
    descriptor = socket
    port = Int(UInt16(bigEndian: address.sin_port))
    setReadTimeout(socket)
  }

  static func freePort() throws -> Int { try ListeningSocket().port }
  deinit { Darwin.close(descriptor) }
}

private func connectedSocket(port: Int) throws -> Int32 {
  let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
  var address = socketAddress(port: port)
  let result = withUnsafePointer(to: &address) { pointer in
    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
      Darwin.connect(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
    }
  }
  guard result == 0 else {
    Darwin.close(socket)
    throw AppError("Could not connect test socket")
  }
  setReadTimeout(socket)
  return socket
}

private func socketAddress(port: Int) -> sockaddr_in {
  var address = sockaddr_in()
  address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
  address.sin_family = sa_family_t(AF_INET)
  address.sin_port = UInt16(port).bigEndian
  address.sin_addr.s_addr = inet_addr("127.0.0.1")
  return address
}

private func setReadTimeout(_ socket: Int32) {
  var timeout = timeval(tv_sec: 3, tv_usec: 0)
  _ = setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
}
