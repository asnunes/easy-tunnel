import SwiftUI

struct ConnectionEditor: View {
  @ObservedObject var store: ConnectionStore
  @State private var draft: ConnectionDraft
  @State private var confirmingDelete = false

  init(store: ConnectionStore, draft: ConnectionDraft) {
    self.store = store
    _draft = State(initialValue: draft)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(draft.connectionID == nil ? "Add connection" : "Edit connection").font(.headline)
        Spacer()
        Button {
          store.closeEditor()
        } label: {
          Image(systemName: "xmark")
        }
        .buttonStyle(.borderless).help("Back to connections")
        .accessibilityLabel("Back to connections")
      }
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Name").font(.caption).foregroundStyle(.secondary)
          TextField("Home lab", text: $draft.name).textFieldStyle(.roundedBorder)
            .accessibilityLabel("Connection name")
        }
        VStack(alignment: .leading, spacing: 4) {
          Text("SSH host").font(.caption).foregroundStyle(.secondary)
          Picker("SSH host", selection: $draft.host) {
            if hosts.isEmpty { Text("No hosts found").tag("") }
            ForEach(hosts, id: \.self) { Text($0).tag($0) }
          }.labelsHidden().frame(maxWidth: .infinity)
        }
      }
      .disabled(disabled)
      if hosts.isEmpty {
        Text("Add a named Host to ~/.ssh/config, then refresh the host list.")
          .font(.caption).foregroundStyle(.secondary)
      }
      if active {
        Text("Disconnect this tunnel before editing.")
          .font(.caption).foregroundStyle(.secondary)
      }
      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 6) {
          Text("Local port").frame(width: 60, alignment: .leading)
          Spacer().frame(width: 14)
          Text("Destination").frame(maxWidth: .infinity, alignment: .leading)
          Text("Port").frame(width: 60, alignment: .leading)
          Spacer().frame(width: 20)
        }
        .font(.caption).foregroundStyle(.secondary)
        ScrollView {
          VStack(spacing: 6) {
            ForEach($draft.forwards) { $forward in
              PortForwardRow(
                forward: $forward,
                index: draft.forwards.firstIndex(where: { $0.id == forward.id }) ?? 0
              ) {
                draft.forwards.removeAll { $0.id == forward.id }
              }
            }
          }.padding(.vertical, 2)
        }
        .frame(height: min(CGFloat(draft.forwards.count) * 30 + 4, 240))
        Button {
          draft.forwards.append(ForwardDraft())
        } label: {
          Label("Add port", systemImage: "plus")
        }.buttonStyle(.borderless)
      }
      .disabled(disabled)
      Divider()
      HStack {
        if let id = draft.connectionID {
          Button("Delete", role: .destructive) { confirmingDelete = true }
            .buttonStyle(.borderless).disabled(disabled)
            .confirmationDialog("Delete \(draft.name)?", isPresented: $confirmingDelete) {
              Button("Delete connection", role: .destructive) { store.remove(id) }
            }
        }
        Spacer()
        Button("Cancel") { store.closeEditor() }.keyboardShortcut(.cancelAction)
          .disabled(store.busy)
        Button("Save") { store.save(draft) }.keyboardShortcut(.defaultAction)
          .disabled(disabled || draft.host.isEmpty)
      }
    }
  }

  private var active: Bool {
    draft.connectionID.flatMap { store.tunnel(for: $0) }?.isActive ?? false
  }
  private var disabled: Bool { store.busy || active }
  private var hosts: [String] {
    Array(Set(store.hosts + (draft.host.isEmpty ? [] : [draft.host]))).sorted()
  }
}
