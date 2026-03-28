import SwiftUI
import AppKit

@main
struct MacFolderViewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var clickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: "MacFolderView")
            button.action = #selector(togglePanel)
            button.target = self
        }

        let content = NSHostingView(rootView: FolderBrowserView().frame(width: 560, height: 580))
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 580),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = content
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.isMovable = false
        panel.animationBehavior = .utilityWindow
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
    }

    private func startClickMonitor() {
        guard clickMonitor == nil else { return }
        // グローバルクリック（他アプリ上のクリック）を監視
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.panel.isVisible else { return }
            let screenPoint = NSEvent.mouseLocation
            if !self.panel.frame.contains(screenPoint) {
                self.panel.orderOut(nil)
            }
        }
    }

    private func stopClickMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    @objc private func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
            stopClickMonitor()
        } else {
            if let button = statusItem.button {
                let buttonRect = button.window!.convertToScreen(button.convert(button.bounds, to: nil))
                let x = buttonRect.midX - panel.frame.width / 2
                let y = buttonRect.minY - panel.frame.height - 4
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }
            panel.makeKeyAndOrderFront(nil)
            startClickMonitor()
        }
    }
}
