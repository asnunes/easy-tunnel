import SwiftUI

struct TunnelErrorView: View {
  let error: String
  @State private var showingDetails = false

  var body: some View {
    let message = TunnelErrorMessage(error)
    VStack(alignment: .leading, spacing: 4) {
      Text(message.summary)
        .font(.caption)
        .foregroundStyle(.red)
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
      if message.hasDetails {
        Button("SSH details…") { showingDetails = true }
          .font(.caption)
          .buttonStyle(.borderless)
          .popover(isPresented: $showingDetails) {
            VStack(alignment: .leading, spacing: 8) {
              Text("SSH details").font(.headline)
              Text(message.details)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 320, alignment: .leading)
            .padding(12)
          }
      }
    }
  }
}
