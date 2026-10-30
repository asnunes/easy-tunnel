import SwiftUI

struct MenuPanel: View {
  @ObservedObject var store: ConnectionStore

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if let draft = store.editor {
        ConnectionEditor(store: store, draft: draft).id(draft.id)
      } else {
        ConnectionList(store: store)
      }
      if let error = store.error ?? store.hostError {
        Text(error).font(.caption).foregroundStyle(.red)
          .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
      }
    }
    .controlSize(.small)
    .padding(14)
    .frame(width: store.editor == nil ? 300 : 430)
    .fixedSize(horizontal: false, vertical: true)
    .onAppear { store.refresh() }
  }
}
