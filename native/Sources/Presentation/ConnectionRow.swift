import SwiftUI

struct ConnectionRow: View {
  let connection: Connection
  @ObservedObject var store: ConnectionStore

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 8) {
        Button {
          store.edit(connection)
        } label: {
          HStack {
            Text(connection.name).lineLimit(1)
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Edit \(connection.name)")
        if tunnel?.status == .connecting {
          ProgressView().controlSize(.mini).accessibilityLabel("Connecting")
        }
        Toggle(
          "Tunnel for \(connection.name)",
          isOn: Binding(
            get: { tunnel?.isActive ?? false },
            set: { _ in store.toggle(connection) }
          )
        )
        .labelsHidden()
        .toggleStyle(.switch)
        .controlSize(.mini)
        .disabled(store.busy)
      }
      .frame(minHeight: 28)
      if let error = tunnel?.error {
        TunnelErrorView(error: error)
      }
    }
  }

  private var tunnel: Tunnel? { store.tunnel(for: connection.id) }
}
