import AppKit
import SwiftUI

@main
struct EasyTunnelApp {
  static func main() {
    let application = NSApplication.shared
    let delegate = ApplicationDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    application.run()
    withExtendedLifetime(delegate) {}
  }
}

private final class ApplicationDelegate: NSObject, NSApplicationDelegate {
  private let store = Wiring.makeStore()
  private var statusItem: NSStatusItem?
  private let popover = NSPopover()

  func applicationDidFinishLaunching(_ notification: Notification) {
    ApplicationMenu.install()
    let controller = NSHostingController(rootView: MenuPanel(store: store))
    controller.sizingOptions = [.preferredContentSize]
    popover.contentViewController = controller
    popover.behavior = .transient
    popover.animates = true
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    if let button = statusItem?.button {
      let image = NSImage(contentsOf: Bundle.main.url(forResource: "tray", withExtension: "png")!)!
      image.size = NSSize(width: 18, height: 18)
      image.isTemplate = true
      button.image = image
      button.toolTip = "Easy Tunnel"
      button.setAccessibilityLabel("Easy Tunnel")
      button.target = self
      button.action = #selector(togglePanel)
    }
    store.refresh()
    showPanel()
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    showPanel()
    return false
  }

  func applicationWillTerminate(_ notification: Notification) {
    store.shutdown()
  }

  @objc private func togglePanel() {
    if popover.isShown {
      popover.performClose(nil)
      return
    }
    showPanel()
  }

  private func showPanel() {
    guard let button = statusItem?.button else { return }
    NSApp.activate(ignoringOtherApps: true)
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    popover.contentViewController?.view.window?.makeKey()
  }
}
