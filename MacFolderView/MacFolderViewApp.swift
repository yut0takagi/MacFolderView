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

    // 独立ポップアップ
    private var clipboardPopupPanel: KeyablePanel?
    private var quickOpenPanel: KeyablePanel?
    private var popupClickMonitor: Any?

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
        panel.becomesKeyOnlyIfNeeded = false

        // グローバルホットキー登録
        registerGlobalHotkeys()
    }

    // MARK: - Global Hotkeys

    private var hotkeyRefs: [EventHotKeyRef] = []

    private func registerGlobalHotkeys() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotkeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                            EventParamType(typeEventHotKeyID), nil,
                            MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)
            Task { @MainActor in
                let appDelegate = NSApp.delegate as? AppDelegate
                switch hotkeyID.id {
                case 1: appDelegate?.toggleClipboardPopup()
                case 2: appDelegate?.toggleQuickOpenPopup()
                default: break
                }
            }
            return noErr
        }, 1, &eventType, nil, nil)

        // Cmd+Shift+V: クリップボード履歴
        registerHotkey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey), id: 1)
        // Cmd+Shift+P: クイックオープン（Cmd+Pは他アプリの印刷と競合するため）
        registerHotkey(keyCode: UInt32(kVK_ANSI_P), modifiers: UInt32(cmdKey | shiftKey), id: 2)
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

    // MARK: - Clipboard Popup

    private func toggleClipboardPopup() {
        if let existing = clipboardPopupPanel, existing.isVisible {
            dismissPopup(existing)
            return
        }
        guard let viewModel = AppDelegate.sharedViewModel else { return }

        let view = ClipboardPopupView(viewModel: viewModel) { [weak self] in
            if let p = self?.clipboardPopupPanel { self?.dismissPopup(p) }
        }
        let panel = makePopupPanel(content: view, width: 360, height: 400)
        clipboardPopupPanel = panel
        showPopupAtCenter(panel)
    }

    // MARK: - Quick Open Popup

    private func toggleQuickOpenPopup() {
        if let existing = quickOpenPanel, existing.isVisible {
            dismissPopup(existing)
            return
        }
        guard let viewModel = AppDelegate.sharedViewModel else { return }

        let view = QuickOpenPopupView(viewModel: viewModel) { [weak self] in
            if let p = self?.quickOpenPanel { self?.dismissPopup(p) }
        }
        let panel = makePopupPanel(content: view, width: 440, height: 52)
        quickOpenPanel = panel
        showPopupAtCenter(panel)
    }

    // MARK: - Popup Helpers

    private func makePopupPanel<V: View>(content: V, width: CGFloat, height: CGFloat) -> KeyablePanel {
        let hosting = NSHostingView(rootView: content.frame(width: width, height: height))
        let p = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.contentView = hosting
        p.isFloatingPanel = true
        p.level = .popUpMenu
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isMovable = false
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.animationBehavior = .utilityWindow
        p.isReleasedWhenClosed = false
        p.becomesKeyOnlyIfNeeded = false
        return p
    }

    private func showPopupAtCenter(_ popup: KeyablePanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - popup.frame.width / 2
        let y = screenFrame.midY + 100
        popup.setFrameOrigin(NSPoint(x: x, y: y))
        popup.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // 外をクリックしたら閉じる
        startPopupClickMonitor(for: popup)
    }

    private func dismissPopup(_ popup: KeyablePanel) {
        popup.orderOut(nil)
        stopPopupClickMonitor()
    }

    private func startPopupClickMonitor(for popup: KeyablePanel) {
        stopPopupClickMonitor()
        popupClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self, weak popup] _ in
            guard let popup, popup.isVisible else { return }
            let point = NSEvent.mouseLocation
            if !popup.frame.contains(point) {
                self?.dismissPopup(popup)
            }
        }
    }

    private func stopPopupClickMonitor() {
        if let monitor = popupClickMonitor {
            NSEvent.removeMonitor(monitor)
            popupClickMonitor = nil
        }
    }

    // MARK: - Main Panel

    func openMainPanel() {
        if !panel.isVisible {
            togglePanel()
        }
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

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let versionItem = NSMenuItem(title: "MacFolderView v\(version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        menu.addItem(.separator())

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
