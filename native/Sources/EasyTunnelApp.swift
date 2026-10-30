import AppKit
import SwiftUI

@main
struct EasyTunnelApp: App {
  @NSApplicationDelegateAdaptor(ApplicationLifecycle.self) private var lifecycle

  var body: some Scene {
    MenuBarExtra {
      MenuPanel(store: lifecycle.store)
    } label: {
      Image(nsImage: trayIcon)
        .accessibilityLabel("Easy Tunnel")
    }
    .menuBarExtraStyle(.window)
    .commands {
      TextEditingCommands()
    }
  }

  private var trayIcon: NSImage {
    let image = NSImage(contentsOf: Bundle.main.url(forResource: "tray", withExtension: "png")!)!
    image.size = NSSize(width: 18, height: 18)
    image.isTemplate = true
    return image
  }
}

private final class ApplicationLifecycle: NSObject, NSApplicationDelegate {
  let store = Wiring.makeStore()

  func applicationWillTerminate(_ notification: Notification) {
    store.shutdown()
  }
}
