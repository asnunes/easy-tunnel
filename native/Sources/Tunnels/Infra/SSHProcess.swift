import Darwin
import Foundation

final class SSHProcess: TunnelProcess {
  private let connectionID: String
  private let process = Process()
  private let stderr = Pipe()
  private var pending = Data()
  private var messages: [String] = []
  private var connected = false
  private var stopped = false
  private var launched = false

  init(connectionID: String, arguments: [String]) throws {
    self.connectionID = connectionID
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
    process.arguments = arguments
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = stderr
    let descriptor = stderr.fileHandleForReading.fileDescriptor
    guard fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL) | O_NONBLOCK) != -1 else {
      throw AppError("Could not configure SSH output.")
    }
    try process.run()
    launched = true
    try stderr.fileHandleForWriting.close()
  }

  func snapshot() throws -> Tunnel {
    try readMessages()
    if !process.isRunning {
      process.waitUntilExit()
      try readMessages()
      if stopped {
        return Tunnel(connectionId: connectionID, status: .disconnected, processId: nil, error: nil)
      }
      let detail = messages.joined(separator: "\n")
      return Tunnel(
        connectionId: connectionID, status: .failed, processId: nil,
        error: detail.isEmpty
          ? "SSH exited (\(process.terminationStatus)). Check this host in Terminal." : detail)
    }
    return Tunnel(
      connectionId: connectionID, status: connected ? .connected : .connecting,
      processId: process.processIdentifier, error: nil)
  }

  func stop() {
    guard launched else { return }
    if process.isRunning { process.terminate() }
    process.waitUntilExit()
    stopped = true
  }

  private func readMessages() throws {
    var buffer = [UInt8](repeating: 0, count: 4096)
    while true {
      let count = Darwin.read(stderr.fileHandleForReading.fileDescriptor, &buffer, buffer.count)
      if count < 0 {
        if errno == EAGAIN || errno == EWOULDBLOCK { break }
        throw AppError("Could not read SSH output: \(String(cString: strerror(errno)))")
      }
      if count == 0 {
        if !pending.isEmpty {
          consume(String(decoding: pending, as: UTF8.self))
          pending.removeAll()
        }
        break
      }
      pending.append(contentsOf: buffer.prefix(count))
      while let end = pending.firstIndex(of: 10) {
        consume(String(decoding: pending[..<end], as: UTF8.self))
        pending.removeSubrange(...end)
      }
    }
  }

  private func consume(_ line: String) {
    if line.contains("Entering interactive session.") { connected = true }
    guard !line.hasPrefix("debug") else { return }
    messages.append(line)
    if messages.count > 8 { messages.removeFirst() }
  }

  deinit { stop() }
}
