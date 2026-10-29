import SwiftUI

struct ConnectionList: View {
  @ObservedObject var store: ConnectionStore

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Easy Tunnel").font(.headline)
        Spacer()
        Button {
          store.refresh()
        } label: {
          Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(.borderless)
        .help("Refresh SSH hosts")
        .accessibilityLabel("Refresh SSH hosts")
        .disabled(store.busy)
      }
      if store.loading {
        Text("Loading connections…").foregroundStyle(.secondary)
          .padding(.vertical, 6)
      } else if store.connections.isEmpty {
        Text("No saved connections.").foregroundStyle(.secondary)
          .padding(.vertical, 6)
      } else {
        ScrollView {
          VStack(spacing: 6) {
            ForEach(store.connections) { connection in
              ConnectionRow(connection: connection, store: store)
            }
          }
        }
        .frame(height: min(listHeight, 260))
      }
      Divider()
      Button {
        store.edit()
      } label: {
        Label("Add connection", systemImage: "plus")
      }
      .buttonStyle(.borderless)
      .disabled(store.loading || store.busy)
      Divider()
      Button("Quit Easy Tunnel") { NSApplication.shared.terminate(nil) }
        .buttonStyle(.borderless)
        .keyboardShortcut("q")
    }
  }

  private var listHeight: CGFloat {
    store.connections.reduce(0) { total, connection in
      total + (store.tunnel(for: connection.id)?.error == nil ? 34 : 92)
    }
  }
}
