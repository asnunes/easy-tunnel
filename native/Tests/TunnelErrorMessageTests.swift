import Foundation

enum TunnelErrorMessageTests {
  static func run() throws {
    try test("Refused forwarding channels show one actionable message") {
      let line = "channel 7: open failed: connect failed: Connection refused"
      let message = TunnelErrorMessage("\(line)\r\n\(line)\n\(line)")
      try expect(
        message.summary
          == "Destination refused the connection.\nCheck the destination host, port and service.")
      try expect(message.details == line && message.hasDetails)
      let otherChannel = TunnelErrorMessage(
        "channel 12: open failed: connect failed: Connection refused")
      try expect(otherChannel.summary == message.summary)
    }
    try test("SSH server refusal is not described as a forwarding destination failure") {
      let line = "ssh: connect to host example.test port 22: Connection refused"
      let message = TunnelErrorMessage(line)
      try expect(message.summary == line && !message.hasDetails)
    }
    try test("Unknown errors retain distinct details in their original order") {
      let message = TunnelErrorMessage(
        "Permission denied (publickey).\nConnection closed.\nPermission denied (publickey).")
      try expect(message.summary == "SSH connection failed.")
      try expect(message.details == "Permission denied (publickey).\nConnection closed.")
      try expect(message.hasDetails)
    }
    try test("Empty SSH errors have a readable message without empty details") {
      let message = TunnelErrorMessage(" \n\r\n")
      try expect(message.summary == "SSH connection failed." && !message.hasDetails)
    }
  }
}
