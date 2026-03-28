import SwiftUI

struct FolderBrowserView: View {
    @StateObject private var viewModel: FolderViewModel = {
        let vm = FolderViewModel()
        AppDelegate.sharedViewModel = vm
        return vm
    }()
    @State private var transitionId = UUID()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbarView

            Divider()

            // Main content
            HStack(spacing: 0) {
                // Sidebar
                if viewModel.showSidebar {
                    SidebarView(viewModel: viewModel)
                    Divider()
                }

                // File browser
                VStack(spacing: 0) {
                    // Breadcrumb
                    BreadcrumbView(path: viewModel.currentPath) { url in
                        if url != viewModel.currentPath {
                            viewModel.navigateTo(url)
                        }
                    }
                    .frame(height: 28)
                    .background(Color(nsColor: .windowBackgroundColor))

                    Divider()

                    // Search bar
                    searchBar

                    Divider()

                    // File list + Preview panel
                    HStack(spacing: 0) {
                        fileListView
                            .id(transitionId)
                            .transition(.opacity)

                        if viewModel.showPreviewPanel {
                            Divider()
                            previewPanel
                                .frame(width: 200)
                        }
                    }
                }
            }

            // Stage tray
            Divider()
            stageView

            // Clipboard history
            if viewModel.showClipboardHistory {
                Divider()
                clipboardHistoryView
            }

            Divider()

            // Status bar
            statusBarView
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: viewModel.currentPath) {
            withAnimation(.easeInOut(duration: 0.15)) {
                transitionId = UUID()
            }
        }
        .onKeyPress(.upArrow) {
            viewModel.selectPrevious()
            return .handled
        }
        .onKeyPress(.downArrow) {
            viewModel.selectNext()
            return .handled
        }
        .onKeyPress(.return) {
            viewModel.openSelected()
            return .handled
        }
        .onKeyPress(.escape) {
            if !viewModel.searchText.isEmpty {
                viewModel.searchText = ""
            } else if viewModel.selectedItem != nil {
                viewModel.selectedItem = nil
            } else if viewModel.canGoBack {
                viewModel.goBack()
            }
            return .handled
        }
        .onKeyPress(.space) {
            viewModel.quickLookSelected()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            viewModel.goBack()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if let item = viewModel.selectedItem, item.isDirectory {
                viewModel.navigateTo(item.url)
            } else {
                viewModel.goForward()
            }
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "f"), phases: .down) { press in
            if press.modifiers.contains(.command) {
                isSearchFocused = true
                return .handled
            }
            return .ignored
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "d"), phases: .down) { press in
            if press.modifiers.contains(.command), let item = viewModel.selectedItem {
                viewModel.duplicateItem(item.url)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.deleteForward, phases: .down) { press in
            if press.modifiers.contains(.command) {
                viewModel.trashSelectedItems()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "n"), phases: .down) { press in
            if press.modifiers.contains(.command) && press.modifiers.contains(.shift) {
                viewModel.createNewFolder()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.init(Character(UnicodeScalar(NSF2FunctionKey)!)), phases: .down) { _ in
            viewModel.startRename()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "c"), phases: .down) { press in
            if press.modifiers.contains(.command) {
                viewModel.copySelectedFiles()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "v"), phases: .down) { press in
            if press.modifiers.contains(.command) {
                viewModel.pasteFiles()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "p"), phases: .down) { press in
            if press.modifiers.contains(.command) {
                viewModel.showQuickOpen = true
                return .handled
            }
            return .ignored
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "i"), phases: .down) { press in
            if press.modifiers.contains(.command) {
                viewModel.showPreviewPanel.toggle()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "v"), phases: .down) { press in
            if press.modifiers.contains(.command) && press.modifiers.contains(.shift) {
                viewModel.showClipboardHistory.toggle()
                return .handled
            }
            return .ignored
        }
        .focusable()
        .overlay {
            if viewModel.showQuickOpen {
                quickOpenOverlay
            }
        }
    }

    // MARK: - Toolbar

    private var toolbarView: some View {
        HStack(spacing: 2) {
            ToolbarIconButton("sidebar.left", help: "サイドバー") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.showSidebar.toggle()
                }
            }

            Divider()
                .frame(height: 14)
                .padding(.horizontal, 4)

            ToolbarIconButton("chevron.left", help: "戻る (←)", disabled: !viewModel.canGoBack) {
                viewModel.goBack()
            }

            ToolbarIconButton("chevron.right", help: "進む (→)", disabled: !viewModel.canGoForward) {
                viewModel.goForward()
            }

            ToolbarIconButton("chevron.up", help: "上のフォルダ", disabled: !viewModel.canGoUp) {
                viewModel.goUp()
            }

            Divider()
                .frame(height: 14)
                .padding(.horizontal, 4)

            ToolbarIconButton("house", help: "ホーム") {
                viewModel.goHome()
            }

            Spacer()

            // Sort
            Menu {
                ForEach(FolderViewModel.SortOrder.allCases, id: \.self) { order in
                    Button {
                        if viewModel.sortOrder == order {
                            viewModel.sortAscending.toggle()
                        } else {
                            viewModel.sortOrder = order
                            viewModel.sortAscending = true
                        }
                    } label: {
                        HStack {
                            Text(order.rawValue)
                            if viewModel.sortOrder == order {
                                Image(systemName: viewModel.sortAscending ? "chevron.up" : "chevron.down")
                            }
                        }
                    }
                }
                Divider()
                Toggle("隠しファイルを表示", isOn: $viewModel.showHiddenFiles)
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 11, weight: .medium))
                    Text(viewModel.sortOrder.rawValue)
                        .font(.system(size: 10))
                }
                .foregroundStyle(.secondary)
                .frame(height: 22)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("並び替え")

            ToolbarIconButton("plus.rectangle.on.folder", help: "新規フォルダ (⌘⇧N)") {
                viewModel.createNewFolder()
            }

            ToolbarIconButton("terminal", help: "ターミナルで開く") {
                viewModel.openTerminalHere()
            }

            ToolbarIconButton("cursorarrow.click.2", help: "Cursorで開く") {
                viewModel.openInCursor(viewModel.currentPath)
            }

            ToolbarIconButton("sidebar.right", help: "プレビュー (⌘I)") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.showPreviewPanel.toggle()
                }
            }

            ToolbarIconButton("arrow.clockwise", help: "再読み込み") {
                viewModel.loadItems()
            }

            ToolbarIconButton("arrow.up.forward.square", help: "Finderで開く") {
                viewModel.openInFinder(viewModel.currentPath)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.bar)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(isSearchFocused ? .secondary : .tertiary)
            TextField("フィルター (⌘F)...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isSearchFocused)
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)

                Text("\(viewModel.filteredItems.count)件")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.accentColor.opacity(0.7)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isSearchFocused ? Color.accentColor.opacity(0.04) : Color.clear)
        .animation(.easeInOut(duration: 0.15), value: isSearchFocused)
    }

    // MARK: - File List

    private var fileListView: some View {
        Group {
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.7)
                    Spacer()
                }
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.1))
                            .frame(width: 56, height: 56)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.orange)
                    }
                    Text(error)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Button {
                        viewModel.goBack()
                    } label: {
                        Text("戻る")
                            .font(.system(size: 12))
                            .padding(.horizontal, 12)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Spacer()
                }
            } else if viewModel.filteredItems.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.08))
                            .frame(width: 56, height: 56)
                        Image(systemName: viewModel.searchText.isEmpty ? "folder" : "magnifyingglass")
                            .font(.system(size: 22))
                            .foregroundStyle(.tertiary)
                    }
                    Text(viewModel.searchText.isEmpty ? "空のフォルダ" : "一致する項目なし")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    if !viewModel.searchText.isEmpty {
                        Text("「\(viewModel.searchText)」")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(viewModel.filteredItems) { item in
                                FileRowView(
                                    item: item,
                                    isSelected: viewModel.selectedItem == item,
                                    isMultiSelected: viewModel.selectedItems.contains(item.url),
                                    isRenaming: viewModel.renamingItem == item,
                                    onNavigate: {
                                        viewModel.navigateTo(item.url)
                                    },
                                    onOpen: {
                                        if item.isDirectory {
                                            viewModel.navigateTo(item.url)
                                        } else {
                                            viewModel.openFile(item.url)
                                        }
                                    },
                                    onRevealInFinder: {
                                        viewModel.openInFinder(item.url)
                                    },
                                    onOpenInCursor: item.isDirectory ? {
                                        viewModel.openInCursor(item.url)
                                    } : nil,
                                    isPinned: viewModel.isPinned(item.url),
                                    onTogglePin: item.isDirectory ? {
                                        viewModel.togglePin(item.url)
                                    } : nil,
                                    isFavorite: viewModel.isFavorite(item.url),
                                    onToggleFavorite: item.isDirectory ? {
                                        if viewModel.isFavorite(item.url) {
                                            if let fav = viewModel.favorites.first(where: { $0.url == item.url }) {
                                                viewModel.removeFavorite(fav)
                                            }
                                        } else {
                                            viewModel.addFavorite(item.url)
                                        }
                                    } : nil,
                                    customApps: viewModel.customApps,
                                    onOpenWith: { app in
                                        viewModel.openWith(app, url: item.url)
                                    },
                                    onCompress: {
                                        viewModel.selectedItem = item
                                        viewModel.compressSelected()
                                    },
                                    onStage: {
                                        viewModel.stageFile(item.url)
                                    },
                                    onSelect: {
                                        viewModel.selectedItems.removeAll()
                                        viewModel.selectedItem = item
                                    },
                                    onCmdSelect: {
                                        viewModel.toggleSelection(item)
                                    },
                                    onShiftSelect: {
                                        viewModel.extendSelection(to: item)
                                    },
                                    onMoveHere: item.isDirectory ? { sourceURL in
                                        viewModel.moveItem(sourceURL, to: item.url)
                                    } : nil,
                                    onTrash: {
                                        viewModel.moveItemsToTrash([item.url])
                                    },
                                    onDuplicate: {
                                        viewModel.duplicateItem(item.url)
                                    },
                                    onStartRename: {
                                        viewModel.selectedItem = item
                                        viewModel.startRename()
                                    },
                                    renameText: $viewModel.renameText,
                                    onCommitRename: {
                                        viewModel.commitRename()
                                    },
                                    onCancelRename: {
                                        viewModel.cancelRename()
                                    }
                                )
                                .id(item.id)
                            }
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 4)
                    }
                    .onChange(of: viewModel.selectedItem) { _, newValue in
                        if let item = newValue {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                proxy.scrollTo(item.id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            let external = urls.filter { $0.deletingLastPathComponent() != viewModel.currentPath }
            guard !external.isEmpty else { return false }
            viewModel.copyItemsHere(external)
            return true
        }
    }

    // MARK: - Status Bar

    private var statusBarView: some View {
        HStack(spacing: 0) {
            let counts = viewModel.itemCount

            if counts.folders > 0 {
                Label("\(counts.folders)", systemImage: "folder.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            if counts.folders > 0 && counts.files > 0 {
                Text(" · ")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
            }

            if counts.files > 0 {
                Label("\(counts.files)", systemImage: "doc.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            if counts.folders == 0 && counts.files == 0 {
                Text("項目なし")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            if viewModel.totalSize > 0 {
                Text(" · ")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
                Text(viewModel.formattedTotalSize)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if viewModel.selectedItems.count > 1 {
                Text("\(viewModel.selectedItems.count)項目を選択中")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            } else if let selected = viewModel.selectedItem {
                Text(selected.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 180)
                    .transition(.opacity)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.showClipboardHistory.toggle()
                }
            } label: {
                Image(systemName: "clipboard")
                    .font(.system(size: 11))
                    .foregroundStyle(viewModel.showClipboardHistory ? Color.accentColor : Color.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help("クリップボード履歴")

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("終了")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.bar)
    }

    // MARK: - Quick Open

    @FocusState private var isQuickOpenFocused: Bool

    private var quickOpenOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .onTapGesture {
                    viewModel.showQuickOpen = false
                    viewModel.quickOpenText = ""
                }

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    TextField("パスを入力 (~/Desktop, /usr/local...)", text: $viewModel.quickOpenText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .focused($isQuickOpenFocused)
                        .onSubmit {
                            viewModel.performQuickOpen()
                        }
                        .onExitCommand {
                            viewModel.showQuickOpen = false
                            viewModel.quickOpenText = ""
                        }
                }
                .padding(12)
                .background(.ultraThickMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                .frame(maxWidth: 400)
                .padding(.top, 80)

                Spacer()
            }
        }
        .onAppear { isQuickOpenFocused = true }
    }

    // MARK: - Preview Panel

    private var previewPanel: some View {
        VStack(spacing: 0) {
            if let item = viewModel.selectedItem {
                // アイコン
                VStack(spacing: 10) {
                    Image(nsImage: {
                        let img = item.nsImage
                        img.size = NSSize(width: 64, height: 64)
                        return img
                    }())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)

                    Text(item.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .padding(.horizontal, 12)

                Divider()
                    .padding(.vertical, 10)

                // 詳細情報
                VStack(alignment: .leading, spacing: 6) {
                    previewInfoRow("種類", item.kindDescription)
                    if !item.isDirectory {
                        previewInfoRow("サイズ", item.formattedSize)
                    } else if let count = item.formattedChildCount {
                        previewInfoRow("項目数", count)
                    }
                    previewInfoRow("変更日", item.formattedDate)
                    previewInfoRow("パス", item.url.path)
                }
                .padding(.horizontal, 12)

                Spacer()
            } else {
                Spacer()
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
                Text("ファイルを選択")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Clipboard History

    private var clipboardHistoryView: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "clipboard")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("クリップボード履歴")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                if !viewModel.clipboardHistory.isEmpty {
                    Button {
                        viewModel.clearClipboardHistory()
                    } label: {
                        Text("クリア")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    viewModel.showClipboardHistory = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)

            if viewModel.clipboardHistory.isEmpty {
                Text("まだ履歴がありません")
                    .font(.system(size: 10))
                    .foregroundStyle(.quaternary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(viewModel.clipboardHistory) { entry in
                            ClipboardHistoryRow(entry: entry) {
                                viewModel.copyFromHistory(entry)
                            } onDelete: {
                                viewModel.removeClipboardEntry(entry)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 4)
                }
                .frame(maxHeight: 140)
            }
        }
        .background(.bar)
    }

    // MARK: - Stage Tray

    @State private var isStageDropTarget = false

    private var stageView: some View {
        VStack(spacing: 0) {
            if viewModel.stagedFiles.isEmpty && !isStageDropTarget {
                // 空の時: 最小限のドロップゾーン
                HStack(spacing: 5) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 9))
                        .foregroundStyle(.quaternary)
                    Text("ドロップでステージ")
                        .font(.system(size: 9))
                        .foregroundStyle(.quaternary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
            } else if !viewModel.stagedFiles.isEmpty {
                // ファイルがある時: フル表示
                HStack {
                    Image(systemName: "tray.full")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("ステージ (\(viewModel.stagedFiles.count))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        viewModel.pasteStageHere()
                    } label: {
                        Text("ここにコピー")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button {
                        viewModel.moveStageHere()
                    } label: {
                        Text("ここに移動")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button {
                        viewModel.clearStage()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("クリア")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(viewModel.stagedFiles, id: \.self) { url in
                            HStack(spacing: 4) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                    .resizable()
                                    .frame(width: 14, height: 14)
                                Text(url.lastPathComponent)
                                    .font(.system(size: 10))
                                    .lineLimit(1)
                                Button {
                                    viewModel.unstageFile(url)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.primary.opacity(0.06))
                            )
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 5)
                }
            }
        }
        .background(.bar)
        .dropDestination(for: URL.self) { urls, _ in
            for url in urls {
                viewModel.stageFile(url)
            }
            return !urls.isEmpty
        } isTargeted: { targeted in
            isStageDropTarget = targeted
        }
        .overlay {
            if isStageDropTarget {
                stageDropPopup
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.25), value: isStageDropTarget)
    }

    private var stageDropPopup: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.accentColor)
            }
            Text("ドロップしてステージ")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
            if !viewModel.stagedFiles.isEmpty {
                Text("現在 \(viewModel.stagedFiles.count) 件")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1.5)
        )
    }

    private func previewInfoRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .truncationMode(.middle)
        }
    }
}

// MARK: - Clipboard History Row

private struct ClipboardHistoryRow: View {
    let entry: FolderViewModel.ClipboardEntry
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: entry.icon)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(width: 14)

            Text(entry.preview)
                .font(.system(size: 10))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isHovered {
                Button {
                    onCopy()
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help("コピー")

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Text(entry.date.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 8))
                    .foregroundStyle(.quaternary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        )
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = h
            }
        }
        .onTapGesture {
            onCopy()
        }
    }
}
