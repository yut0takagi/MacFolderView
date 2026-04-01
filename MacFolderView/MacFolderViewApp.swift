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

    var onKeyDown: (@MainActor (UInt16) -> Bool)?

    override func keyDown(with event: NSEvent) {
        if let handler = onKeyDown {
            let keyCode = event.keyCode
            let handled = MainActor.assumeIsolated { handler(keyCode) }
            if handled { return }
        }
        super.keyDown(with: event)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: KeyablePanel!
    private var clickMonitor: Any?
    private var updaterController: SPUStandardUpdaterController!

    private var documentWindow: NSWindow?

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

    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?

    private func registerGlobalHotkeys() {
        // アクセシビリティ権限を確認・要求
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if trusted {
            installMonitors()
        } else {
            // 権限が付与されるまで待つ
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    DispatchQueue.main.async {
                        self?.installMonitors()
                    }
                }
            }
        }
    }

    private func installMonitors() {
        // グローバル（他のアプリにフォーカスがある時）
        if globalKeyMonitor == nil {
            globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleGlobalKey(event)
            }
        }

        // ローカル（自分のアプリにフォーカスがある時）
        if localKeyMonitor == nil {
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if self?.handleGlobalKey(event) == true {
                    return nil
                }
                return event
            }
        }
    }

    @discardableResult
    private func handleGlobalKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // ⌘⇧V: クリップボード履歴
        if event.keyCode == UInt16(kVK_ANSI_V) && flags == [.command, .shift] {
            Task { @MainActor in self.toggleClipboardPopup() }
            return true
        }

        // ⌥Space: クイックオープン
        if event.keyCode == UInt16(kVK_Space) && flags == [.option] {
            Task { @MainActor in self.toggleQuickOpenPopup() }
            return true
        }

        return false
    }

    // MARK: - Clipboard Popup

    private func toggleClipboardPopup() {
        if let existing = clipboardPopupPanel, existing.isVisible {
            dismissPopup(existing)
            return
        }
        guard let viewModel = AppDelegate.sharedViewModel else { return }
        MainActor.assumeIsolated { viewModel.clipboardSelectedIndex = 0 }
        let view = ClipboardPopupView(viewModel: viewModel) { [weak self] in
            if let p = self?.clipboardPopupPanel { self?.dismissPopup(p) }
        }
        let panel = makePopupPanel(content: view, width: 360, height: 400)

        // NSPanelレベルでキーイベント処理
        panel.onKeyDown = { @MainActor [weak self] keyCode in
            guard let self else { return false }
            guard let viewModel = AppDelegate.sharedViewModel else { return false }
            let count = viewModel.clipboardHistory.count
            switch keyCode {
            case 126: // ↑
                if viewModel.clipboardSelectedIndex > 0 { viewModel.clipboardSelectedIndex -= 1 }
                return true
            case 125: // ↓
                if viewModel.clipboardSelectedIndex < count - 1 { viewModel.clipboardSelectedIndex += 1 }
                return true
            case 36: // Enter
                if viewModel.clipboardSelectedIndex < count {
                    let entry = viewModel.clipboardHistory[viewModel.clipboardSelectedIndex]
                    viewModel.copyFromHistory(entry)
                    self.dismissPopup(panel)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.simulatePaste()
                    }
                }
                return true
            case 53: // Escape
                self.dismissPopup(panel)
                return true
            default:
                return false
            }
        }

        clipboardPopupPanel = panel
        showPopupAtCenter(panel)
    }

    private func simulatePaste() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - Quick Open Popup

    private var quickOpenTextField: NSTextField?

    private func toggleQuickOpenPopup() {
        if let existing = quickOpenPanel, existing.isVisible {
            dismissPopup(existing)
            return
        }

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 48),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovable = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = false

        // AppKitでUI構築
        let container = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 440, height: 48))
        container.material = .popover
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 12

        let icon = NSImageView(frame: NSRect(x: 14, y: 12, width: 24, height: 24))
        icon.image = NSImage(systemSymbolName: "folder.badge.magnifyingglass", accessibilityDescription: nil)
        icon.contentTintColor = .controlAccentColor
        container.addSubview(icon)

        let textField = NSTextField(frame: NSRect(x: 46, y: 12, width: 320, height: 24))
        textField.placeholderString = "パスを入力... ~/Desktop, /usr/local"
        textField.isBordered = false
        textField.drawsBackground = false
        textField.font = .systemFont(ofSize: 15)
        textField.focusRingType = .none
        textField.target = self
        textField.action = #selector(quickOpenSubmit(_:))
        container.addSubview(textField)
        quickOpenTextField = textField

        let badge = NSTextField(labelWithString: "⌥Space")
        badge.font = .systemFont(ofSize: 10, weight: .medium)
        badge.textColor = .tertiaryLabelColor
        badge.frame = NSRect(x: 380, y: 16, width: 50, height: 16)
        container.addSubview(badge)

        panel.contentView = container

        panel.onKeyDown = { @MainActor [weak self] keyCode in
            if keyCode == 53 { // Escape
                if let p = self?.quickOpenPanel { self?.dismissPopup(p) }
                return true
            }
            return false
        }

        quickOpenPanel = panel

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - 220
        let y = screenFrame.midY + 100
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeFirstResponder(textField)
        startPopupClickMonitor(for: panel)
        previousApp = NSWorkspace.shared.frontmostApplication
    }

    @objc private func quickOpenSubmit(_ sender: NSTextField) {
        let path = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return }
        guard let viewModel = AppDelegate.sharedViewModel else { return }

        let expanded = NSString(string: path).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return }

        MainActor.assumeIsolated {
            if isDir.boolValue {
                viewModel.navigateTo(url)
            } else {
                viewModel.navigateTo(url.deletingLastPathComponent())
            }
        }

        if let p = quickOpenPanel { dismissPopup(p) }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.openMainPanel()
        }
    }

    @MainActor private func executeQuickOpen() {
        guard let panel = quickOpenPanel, let viewModel = AppDelegate.sharedViewModel else { return }

        // テキストフィールドの値を取得
        let text = getTextFieldValue(in: panel.contentView) ?? ""
        let path = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return }

        let expanded = NSString(string: path).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return }

        if isDir.boolValue {
            viewModel.navigateTo(url)
        } else {
            viewModel.navigateTo(url.deletingLastPathComponent())
        }

        dismissPopup(panel)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.openMainPanel()
        }
    }

    private func getTextFieldValue(in view: NSView?) -> String? {
        guard let view else { return nil }
        for subview in view.subviews {
            if let tf = subview as? NSTextField, tf.isEditable {
                return tf.stringValue
            }
            if let result = getTextFieldValue(in: subview) {
                return result
            }
        }
        return nil
    }

    // MARK: - Popup Helpers

    private func makePopupPanel<V: View>(content: V, width: CGFloat, height: CGFloat) -> KeyablePanel {
        let hosting = NSHostingView(rootView: content.frame(width: width, height: height))
        let p = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .fullSizeContentView],
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
        // 元のアプリを記憶
        previousApp = NSWorkspace.shared.frontmostApplication

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - popup.frame.width / 2
        let y = screenFrame.midY + 100
        popup.setFrameOrigin(NSPoint(x: x, y: y))
        popup.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // テキストフィールドに自動フォーカス
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if let contentView = popup.contentView {
                self.focusFirstTextField(in: contentView)
            }
        }

        // 外をクリックしたら閉じる
        startPopupClickMonitor(for: popup)
    }

    private var previousApp: NSRunningApplication?

    private func dismissPopup(_ popup: KeyablePanel) {
        popup.orderOut(nil)
        stopPopupClickMonitor()
        // 元のアプリにフォーカスを戻す
        previousApp?.activate()
        previousApp = nil
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

    private func focusFirstTextField(in view: NSView) {
        for subview in view.subviews {
            if let textField = subview as? NSTextField, textField.isEditable {
                view.window?.makeFirstResponder(textField)
                return
            }
            focusFirstTextField(in: subview)
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

        let docItem = NSMenuItem(title: "ドキュメント", action: #selector(showDocument), keyEquivalent: "")
        docItem.target = self
        menu.addItem(docItem)

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

    @objc private func showDocument() {
        if let window = documentWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MacFolderView ドキュメント"
        window.contentView = NSHostingView(rootView: DocumentView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        documentWindow = window
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
