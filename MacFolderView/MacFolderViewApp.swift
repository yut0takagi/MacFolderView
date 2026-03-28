import SwiftUI
import AppKit
import Sparkle
import Carbon.HIToolbox

@main
struct MacFolderViewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

// キーイベントを受け取れるNSPanel
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: KeyablePanel!
    private var clickMonitor: Any?
    private var updaterController: SPUStandardUpdaterController!
    private var clipboardPanel: NSPanel?

    // ViewModelを共有するためにここで保持
    static var sharedViewModel: FolderViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Sparkle auto-update
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            updateStatusItemIcon(button)
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // ダーク/ライトモード切替を監視
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(appearanceChanged),
            name: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )

        let content = NSHostingView(rootView: FolderBrowserView().frame(width: 560, height: 580))
        panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 580),
            styleMask: [.titled, .closable, .fullSizeContentView],
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
        // キーイベントを受け取れるようにする
        panel.becomesKeyOnlyIfNeeded = false

        // グローバルホットキー登録
        registerGlobalHotkeys()
    }

    // MARK: - Global Hotkeys

    private var hotkeyRefs: [EventHotKeyRef] = []

    private func registerGlobalHotkeys() {
        // Carbon Event Handler（全ホットキー共通）
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotkeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                            EventParamType(typeEventHotKeyID), nil,
                            MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)
            Task { @MainActor in
                switch hotkeyID.id {
                case 1: AppDelegate.showClipboardPopup()
                case 2: AppDelegate.showQuickOpen()
                default: break
                }
            }
            return noErr
        }, 1, &eventType, nil, nil)

        // Cmd+Shift+V: クリップボード履歴
        registerHotkey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey), id: 1)
        // Cmd+P: クイックオープン
        registerHotkey(keyCode: UInt32(kVK_ANSI_P), modifiers: UInt32(cmdKey), id: 2)
    }

    private func registerHotkey(keyCode: UInt32, modifiers: UInt32, id: UInt32) {
        let hotkeyID = EventHotKeyID(signature: OSType(0x4D465657), id: id)
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotkeyID,
                                          GetApplicationEventTarget(), 0, &hotKeyRef)
        if status == noErr, let ref = hotKeyRef {
            hotkeyRefs.append(ref)
        }
    }

    @MainActor
    static func ensurePanelVisible() {
        let appDelegate = NSApp.delegate as? AppDelegate
        if let panel = appDelegate?.panel, !panel.isVisible {
            appDelegate?.togglePanel()
        }
    }

    @MainActor
    static func showClipboardPopup() {
        guard let viewModel = sharedViewModel else { return }
        viewModel.showClipboardHistory.toggle()
        ensurePanelVisible()
    }

    @MainActor
    static func showQuickOpen() {
        guard let viewModel = sharedViewModel else { return }
        viewModel.showQuickOpen = true
        ensurePanelVisible()
    }

    private func startClickMonitor() {
        guard clickMonitor == nil else { return }
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

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showStatusMenu()
        } else {
            togglePanel()
        }
    }

    private func togglePanel() {
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
            NSApp.activate(ignoringOtherApps: true)
            startClickMonitor()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()

        let updateItem = NSMenuItem(title: "アップデートを確認...", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "MacFolderView を終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    @objc private func appearanceChanged() {
        if let button = statusItem.button {
            updateStatusItemIcon(button)
        }
    }

    private func updateStatusItemIcon(_ button: NSStatusBarButton) {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: "MacFolderView")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        button.image = image
    }
}
