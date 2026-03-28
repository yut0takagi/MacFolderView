import Foundation
import AppKit
import Combine
import QuickLookUI

@MainActor
final class FolderViewModel: ObservableObject {
    @Published var items: [FileItem] = []
    @Published var currentPath: URL
    @Published var pathHistory: [URL] = []
    @Published var forwardHistory: [URL] = []
    @Published var showHiddenFiles = false
    @Published var searchText = ""
    @Published var sortOrder: SortOrder = .name
    @Published var sortAscending = true
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedItem: FileItem?
    @Published var showSidebar = true
    @Published var navigationDirection: NavigationDirection = .none
    @Published var renamingItem: FileItem?
    @Published var renameText = ""
    @Published var selectedItems: Set<URL> = []
    @Published var recentFolders: [URL] = []
    @Published var pinnedFolders: [URL] = []

    enum SortOrder: String, CaseIterable {
        case name = "名前"
        case date = "日付"
        case size = "サイズ"
        case kind = "種類"
    }

    enum NavigationDirection {
        case none, forward, backward
    }

    struct FavoriteFolder: Identifiable, Equatable {
        let id: String  // パスをIDとして使用
        let name: String
        let icon: String
        let url: URL

        init(name: String, icon: String, url: URL) {
            self.id = url.path
            self.name = name
            self.icon = icon
            self.url = url
        }
    }

    @Published var favorites: [FavoriteFolder] = []

    private static let favoritesKey = "customFavorites"

    private static var defaultFavorites: [FavoriteFolder] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            FavoriteFolder(name: "ホーム", icon: "house.fill", url: home),
            FavoriteFolder(name: "デスクトップ", icon: "menubar.dock.rectangle", url: home.appending(path: "Desktop")),
            FavoriteFolder(name: "書類", icon: "doc.fill", url: home.appending(path: "Documents")),
            FavoriteFolder(name: "ダウンロード", icon: "arrow.down.circle.fill", url: home.appending(path: "Downloads")),
            FavoriteFolder(name: "開発", icon: "chevron.left.forwardslash.chevron.right", url: home.appending(path: "Develop")),
            FavoriteFolder(name: "ピクチャ", icon: "photo.fill", url: home.appending(path: "Pictures")),
        ].filter { FileManager.default.fileExists(atPath: $0.url.path) }
    }

    private func loadFavorites() {
        guard let saved = UserDefaults.standard.array(forKey: Self.favoritesKey) as? [[String: String]] else {
            favorites = Self.defaultFavorites
            return
        }
        favorites = saved.compactMap { dict in
            guard let name = dict["name"], let icon = dict["icon"], let path = dict["path"] else { return nil }
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            return FavoriteFolder(name: name, icon: icon, url: url)
        }
        if favorites.isEmpty { favorites = Self.defaultFavorites }
    }

    private func saveFavorites() {
        let data = favorites.map { ["name": $0.name, "icon": $0.icon, "path": $0.url.path] }
        UserDefaults.standard.set(data, forKey: Self.favoritesKey)
    }

    func moveFavorite(from source: IndexSet, to destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
        saveFavorites()
    }

    func removeFavorite(_ fav: FavoriteFolder) {
        favorites.removeAll { $0.id == fav.id }
        saveFavorites()
    }

    func addFavorite(_ url: URL) {
        guard !favorites.contains(where: { $0.url == url }) else { return }
        favorites.append(FavoriteFolder(name: url.lastPathComponent, icon: "folder.fill", url: url))
        saveFavorites()
    }

    func isFavorite(_ url: URL) -> Bool {
        favorites.contains { $0.url == url }
    }

    func resetFavorites() {
        UserDefaults.standard.removeObject(forKey: Self.favoritesKey)
        favorites = Self.defaultFavorites
    }

    var filteredItems: [FileItem] {
        var result = items
        if !showHiddenFiles {
            result = result.filter { !$0.isHidden }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result.sorted { a, b in
            if a.isDirectory != b.isDirectory {
                return a.isDirectory
            }
            let asc = sortAscending
            switch sortOrder {
            case .name:
                let cmp = a.name.localizedStandardCompare(b.name) == .orderedAscending
                return asc ? cmp : !cmp
            case .date:
                let cmp = a.modificationDate > b.modificationDate
                return asc ? cmp : !cmp
            case .size:
                let cmp = a.size > b.size
                return asc ? cmp : !cmp
            case .kind:
                if a.kindDescription == b.kindDescription {
                    return a.name.localizedStandardCompare(b.name) == .orderedAscending
                }
                let cmp = a.kindDescription < b.kindDescription
                return asc ? cmp : !cmp
            }
        }
    }

    var canGoBack: Bool { !pathHistory.isEmpty }
    var canGoForward: Bool { !forwardHistory.isEmpty }
    var canGoUp: Bool { currentPath.path != "/" }

    var itemCount: (folders: Int, files: Int) {
        let folders = filteredItems.filter(\.isDirectory).count
        return (folders, filteredItems.count - folders)
    }

    var totalSize: Int64 {
        filteredItems.filter { !$0.isDirectory }.reduce(0) { $0 + $1.size }
    }

    var formattedTotalSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }

    private static let pinnedFoldersKey = "pinnedFolders"

    init(path: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.currentPath = path
        if let paths = UserDefaults.standard.stringArray(forKey: Self.pinnedFoldersKey) {
            self.pinnedFolders = paths.map { URL(fileURLWithPath: $0) }
        }
        loadFavorites()
        loadItems()
    }

    func loadItems() {
        isLoading = true
        errorMessage = nil
        let fm = FileManager.default
        do {
            let keys: Set<URLResourceKey> = [
                .isDirectoryKey, .fileSizeKey, .contentModificationDateKey,
                .isHiddenKey, .isSymbolicLinkKey, .isPackageKey
            ]
            let urls = try fm.contentsOfDirectory(
                at: currentPath,
                includingPropertiesForKeys: Array(keys),
                options: []
            )
            items = urls.compactMap { url in
                guard let r = try? url.resourceValues(forKeys: keys) else { return nil }
                return FileItem(
                    url: url,
                    name: url.lastPathComponent,
                    isDirectory: r.isDirectory ?? false,
                    size: Int64(r.fileSize ?? 0),
                    modificationDate: r.contentModificationDate ?? Date.distantPast,
                    isHidden: r.isHidden ?? false,
                    isSymlink: r.isSymbolicLink ?? false,
                    isPackage: r.isPackage ?? false
                )
            }
        } catch {
            items = []
            errorMessage = "読み取れません"
        }
        isLoading = false
    }

    func navigateTo(_ url: URL) {
        navigationDirection = .forward
        pathHistory.append(currentPath)
        forwardHistory.removeAll()
        addToRecent(currentPath)
        currentPath = url
        selectedItem = nil
        selectedItems.removeAll()
        searchText = ""
        loadItems()
    }

    func goBack() {
        guard let previous = pathHistory.popLast() else { return }
        navigationDirection = .backward
        forwardHistory.append(currentPath)
        currentPath = previous
        selectedItem = nil
        searchText = ""
        loadItems()
    }

    func goForward() {
        guard let next = forwardHistory.popLast() else { return }
        navigationDirection = .forward
        pathHistory.append(currentPath)
        currentPath = next
        selectedItem = nil
        searchText = ""
        loadItems()
    }

    func goUp() {
        let parent = currentPath.deletingLastPathComponent()
        navigateTo(parent)
    }

    func goHome() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        if currentPath != home {
            navigateTo(home)
        }
    }

    func selectNext() {
        let list = filteredItems
        guard !list.isEmpty else { return }
        if let current = selectedItem, let idx = list.firstIndex(of: current) {
            let next = min(idx + 1, list.count - 1)
            selectedItem = list[next]
        } else {
            selectedItem = list.first
        }
    }

    func selectPrevious() {
        let list = filteredItems
        guard !list.isEmpty else { return }
        if let current = selectedItem, let idx = list.firstIndex(of: current) {
            let prev = max(idx - 1, 0)
            selectedItem = list[prev]
        } else {
            selectedItem = list.last
        }
    }

    func openSelected() {
        guard let item = selectedItem else { return }
        if item.isDirectory {
            navigateTo(item.url)
        } else {
            openFile(item.url)
        }
    }

    func openInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openFile(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    // MARK: - File Operations

    func moveItem(_ sourceURL: URL, to destinationFolder: URL) {
        let dest = destinationFolder.appending(path: sourceURL.lastPathComponent)
        do {
            try FileManager.default.moveItem(at: sourceURL, to: dest)
            loadItems()
        } catch {
            errorMessage = "移動できません: \(error.localizedDescription)"
        }
    }

    func copyItemsHere(_ urls: [URL]) {
        let fm = FileManager.default
        for url in urls {
            // 同一フォルダ内の場合はスキップ
            if url.deletingLastPathComponent() == currentPath { continue }
            var dest = currentPath.appending(path: url.lastPathComponent)
            // 名前が重複する場合はリネーム
            var counter = 2
            let name = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            while fm.fileExists(atPath: dest.path) {
                let newName = ext.isEmpty ? "\(name) \(counter)" : "\(name) \(counter).\(ext)"
                dest = currentPath.appending(path: newName)
                counter += 1
            }
            do {
                try fm.copyItem(at: url, to: dest)
            } catch {
                errorMessage = "コピーできません: \(error.localizedDescription)"
                break
            }
        }
        loadItems()
    }

    func moveItemsToTrash(_ urls: [URL]) {
        for url in urls {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            } catch {
                errorMessage = "ゴミ箱に入れられません"
                return
            }
        }
        selectedItem = nil
        loadItems()
    }

    func trashSelected() {
        guard let item = selectedItem else { return }
        moveItemsToTrash([item.url])
    }

    func duplicateItem(_ url: URL) {
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()
        let name = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        var dest: URL
        var counter = 2
        repeat {
            let newName = ext.isEmpty ? "\(name) \(counter)" : "\(name) \(counter).\(ext)"
            dest = dir.appending(path: newName)
            counter += 1
        } while fm.fileExists(atPath: dest.path)

        do {
            try fm.copyItem(at: url, to: dest)
            loadItems()
        } catch {
            errorMessage = "複製できません"
        }
    }

    func startRename() {
        guard let item = selectedItem else { return }
        renamingItem = item
        // 拡張子を除いた名前を初期値にする
        if item.isDirectory {
            renameText = item.name
        } else {
            let ext = item.url.pathExtension
            renameText = ext.isEmpty ? item.name : String(item.name.dropLast(ext.count + 1))
        }
    }

    func commitRename() {
        guard let item = renamingItem else { return }
        let newName: String
        if !item.isDirectory && !item.url.pathExtension.isEmpty {
            newName = renameText + "." + item.url.pathExtension
        } else {
            newName = renameText
        }
        let dest = item.url.deletingLastPathComponent().appending(path: newName)
        guard dest != item.url else {
            renamingItem = nil
            return
        }
        do {
            try FileManager.default.moveItem(at: item.url, to: dest)
            renamingItem = nil
            loadItems()
            // 新しいURLで選択状態を維持
            selectedItem = filteredItems.first { $0.url == dest }
        } catch {
            errorMessage = "名前を変更できません"
            renamingItem = nil
        }
    }

    func cancelRename() {
        renamingItem = nil
    }

    func createNewFolder() {
        let fm = FileManager.default
        var name = "新規フォルダ"
        var dest = currentPath.appending(path: name)
        var counter = 2
        while fm.fileExists(atPath: dest.path) {
            name = "新規フォルダ \(counter)"
            dest = currentPath.appending(path: name)
            counter += 1
        }
        do {
            try fm.createDirectory(at: dest, withIntermediateDirectories: false)
            loadItems()
            // 作成したフォルダを選択してリネームモードに
            selectedItem = filteredItems.first { $0.url == dest }
            if let newItem = selectedItem {
                renamingItem = newItem
                renameText = name
            }
        } catch {
            errorMessage = "フォルダを作成できません"
        }
    }

    func openInCursor(_ url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Cursor", url.path]
        try? process.run()
    }

    func openTerminalHere() {
        let path = currentPath.path
        let escaped = path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"Terminal\"\nactivate\ndo script \"cd \\\"" + escaped + "\\\"\"\nend tell"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error {
                // AppleScript失敗時はopen -aでフォールバック
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                process.arguments = ["-a", "Terminal", currentPath.path]
                try? process.run()
            }
        }
    }

    // MARK: - Multi-selection

    func toggleSelection(_ item: FileItem) {
        if selectedItems.contains(item.url) {
            selectedItems.remove(item.url)
        } else {
            selectedItems.insert(item.url)
        }
        selectedItem = item
    }

    func extendSelection(to item: FileItem) {
        let list = filteredItems
        guard let targetIdx = list.firstIndex(of: item) else { return }
        let anchorIdx: Int
        if let current = selectedItem, let idx = list.firstIndex(of: current) {
            anchorIdx = idx
        } else {
            anchorIdx = 0
        }
        let range = min(anchorIdx, targetIdx)...max(anchorIdx, targetIdx)
        selectedItems = Set(range.map { list[$0].url })
        selectedItem = item
    }

    func trashSelectedItems() {
        if !selectedItems.isEmpty {
            moveItemsToTrash(Array(selectedItems))
            selectedItems.removeAll()
        } else {
            trashSelected()
        }
    }

    // MARK: - Pinned Folders

    func isPinned(_ url: URL) -> Bool {
        pinnedFolders.contains(url)
    }

    func togglePin(_ url: URL) {
        if let idx = pinnedFolders.firstIndex(of: url) {
            pinnedFolders.remove(at: idx)
        } else {
            pinnedFolders.append(url)
        }
        savePinnedFolders()
    }

    func movePinnedFolder(from source: IndexSet, to destination: Int) {
        pinnedFolders.move(fromOffsets: source, toOffset: destination)
        savePinnedFolders()
    }

    private func savePinnedFolders() {
        UserDefaults.standard.set(pinnedFolders.map(\.path), forKey: Self.pinnedFoldersKey)
    }

    // MARK: - Recent Folders

    private func addToRecent(_ url: URL) {
        recentFolders.removeAll { $0 == url }
        recentFolders.insert(url, at: 0)
        if recentFolders.count > 5 {
            recentFolders = Array(recentFolders.prefix(5))
        }
    }

    func quickLookSelected() {
        guard let item = selectedItem else { return }
        let url = item.url as NSURL
        let urls = [url] as [QLPreviewItem]
        let panel = QLPreviewPanel.shared()!
        QuickLookCoordinator.shared.items = urls
        panel.dataSource = QuickLookCoordinator.shared
        if panel.isVisible {
            panel.reloadData()
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }
}

final class QuickLookCoordinator: NSObject, QLPreviewPanelDataSource {
    static let shared = QuickLookCoordinator()
    var items: [QLPreviewItem] = []

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        items.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        items[index]
    }
}
