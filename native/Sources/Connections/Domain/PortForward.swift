struct PortForward: Equatable {
  private let localValue: Port
  private let destinationValue: DestinationHost
  private let remoteValue: Port

  init(local: Port, destination: DestinationHost, remote: Port) {
    localValue = local
    destinationValue = destination
    remoteValue = remote
  }

  var local: Port { localValue }
  var destination: DestinationHost { destinationValue }
  var remote: Port { remoteValue }
  var localPort: Int { local.value }
  var destinationHost: String { destination.value }
  var destinationPort: Int { remote.value }
}
