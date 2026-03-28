import SwiftUI

struct FolderBrowserView: View {
    @StateObject private var viewModel = FolderViewModel()
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

                    // File list
                    fileListView
                        .id(transitionId)
                        .transition(.opacity)
                }
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
        .focusable()
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
}
