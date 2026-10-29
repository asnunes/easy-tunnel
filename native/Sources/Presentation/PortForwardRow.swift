import SwiftUI

struct PortForwardRow: View {
  @Binding var forward: ForwardDraft
  let index: Int
  let remove: () -> Void

  var body: some View {
    HStack(spacing: 6) {
      TextField("5433", text: $forward.localPort)
        .frame(width: 60).accessibilityLabel("Local port \(index + 1)")
      Image(systemName: "arrow.right").foregroundStyle(.secondary).frame(width: 14)
      TextField("localhost", text: $forward.destinationHost)
        .accessibilityLabel("Destination host \(index + 1)")
      TextField("5432", text: $forward.destinationPort)
        .frame(width: 60).accessibilityLabel("Remote port \(index + 1)")
      Button(action: remove) { Image(systemName: "minus.circle") }
        .buttonStyle(.borderless).foregroundStyle(.secondary)
        .frame(width: 20).help("Remove port")
        .accessibilityLabel("Remove port \(index + 1)")
    }
    .textFieldStyle(.roundedBorder)
  }
}
