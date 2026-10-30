import Foundation

struct OpenSSH: TunnelLauncher {
  var configurationFile: URL?

  func launch(_ connection: Connection) throws -> TunnelProcess {
    try SSHProcess(connectionID: connection.id, arguments: arguments(connection))
  }

  func arguments(_ connection: Connection) -> [String] {
    var args = [
      "-N", "-T", "-v", "-o", "BatchMode=yes", "-o", "PreferredAuthentications=publickey", "-o",
      "ExitOnForwardFailure=yes", "-o", "StrictHostKeyChecking=yes", "-o", "ControlMaster=no", "-o",
      "ControlPath=none", "-o", "ForkAfterAuthentication=no", "-o", "PermitLocalCommand=no", "-o",
      "ConnectTimeout=10",
    ]
    if let configurationFile { args += ["-F", configurationFile.path] }
    for forward in connection.forwards {
      let host =
        forward.destinationHost.contains(":")
        ? "[\(forward.destinationHost)]" : forward.destinationHost
      args += ["-L", "127.0.0.1:\(forward.localPort):\(host):\(forward.destinationPort)"]
    }
    return args + [connection.sshHostAlias]
  }
}
