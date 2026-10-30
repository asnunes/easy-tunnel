import AppKit
import SwiftUI

@main
struct Preview {
  static func main() {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)
    let backend = TestBackend()
    let store = ConnectionStore(backend: backend)
    store.refresh()
    for (name, appearance) in [
      ("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua),
    ] {
      render(
        MenuPanel(store: store), appearance: appearance, path: "target/native-list-\(name).png")
      let refusal = "channel 7: open failed: connect failed: Connection refused"
      backend.subject.send([
        Tunnel(
          connectionId: "lab", status: .failed, processId: nil, error: "\(refusal)\n\(refusal)")
      ])
      render(
        ConnectionList(store: store).controlSize(.small).padding(14).frame(width: 300),
        appearance: appearance, path: "target/native-error-\(name).png")
      store.refresh()
      store.edit(store.connections[0])
      render(
        MenuPanel(store: store), appearance: appearance, path: "target/native-editor-\(name).png")
      store.closeEditor()
    }
  }

  private static func render<Content: View>(
    _ content: Content, appearance: NSAppearance.Name, path: String
  ) {
    let view = NSHostingView(rootView: content.background(Color(nsColor: .windowBackgroundColor)))
    view.appearance = NSAppearance(named: appearance)
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 430, height: 500), styleMask: .borderless,
      backing: .buffered, defer: false)
    window.contentView = view
    view.layoutSubtreeIfNeeded()
    let size = view.fittingSize
    view.setFrameSize(size)
    window.setContentSize(size)
    view.layoutSubtreeIfNeeded()
    guard let image = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
      fatalError("Could not render view")
    }
    view.cacheDisplay(in: view.bounds, to: image)
    try! image.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    print("Rendered \(path): \(size)")
  }
}
