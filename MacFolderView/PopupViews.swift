import SwiftUI
import AppKit

// MARK: - Clipboard Popup (⌘⇧V)

struct ClipboardPopupView: View {
    @ObservedObject var viewModel: FolderViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Image(systemName: "clipboard")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("クリップボード")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("⌘⇧V")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.06)))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if viewModel.clipboardHistory.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "clipboard")
                        .font(.system(size: 28))
                        .foregroundStyle(.quaternary)
                    Text("まだ履歴がありません")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                    Text("何かコピーすると自動で記録されます")
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(Array(viewModel.clipboardHistory.enumerated()), id: \.element.id) { index, entry in
                                ClipboardPopupRow(
                                    entry: entry,
                                    isSelected: index == viewModel.clipboardSelectedIndex,
                                    index: index,
                                    onSelect: {
                                        viewModel.clipboardSelectedIndex = index
                                        viewModel.copyFromHistory(entry)
                                        onDismiss()
                                    },
                                    onPin: {
                                        viewModel.togglePinEntry(entry)
                                    },
                                    onNavigate: entry.isFilePath ? {
                                        viewModel.navigateToEntry(entry)
                                        onDismiss()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            (NSApp.delegate as? AppDelegate)?.openMainPanel()
                                        }
                                    } : nil,
                                    onStage: entry.type == .files || entry.isFilePath ? {
                                        for url in entry.fileURLs {
                                            viewModel.stageFile(url)
                                        }
                                        if let url = entry.fileURL {
                                            viewModel.stageFile(url)
                                        }
                                    } : nil
                                )
                                .id(entry.id)
                            }
                        }
                        .padding(6)
                    }
                    .onChange(of: viewModel.clipboardSelectedIndex) { _, newValue in
                        if newValue < viewModel.clipboardHistory.count {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                proxy.scrollTo(viewModel.clipboardHistory[newValue].id, anchor: .center)
                            }
                        }
                    }
                }
            }

            Divider()

            // フッター
            HStack(spacing: 12) {
                let pinCount = viewModel.clipboardHistory.filter(\.isPinned).count
                if pinCount > 0 {
                    Label("\(pinCount) ピン", systemImage: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                }
                Text("\(viewModel.clipboardHistory.count) 件")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                if !viewModel.clipboardHistory.isEmpty {
                    Button {
                        viewModel.clearClipboardHistory()
                    } label: {
                        Text("クリア(ピン以外)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Text("↑↓ 選択  ⏎ ペースト  Esc 閉じる")
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}

private struct ClipboardPopupRow: View {
    let entry: FolderViewModel.ClipboardEntry
    let isSelected: Bool
    let index: Int
    let onSelect: () -> Void
    var onPin: (() -> Void)?
    var onNavigate: (() -> Void)?
    var onStage: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // ピンまたは番号
                if entry.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                        .frame(width: 18, height: 18)
                } else {
                    Text("\(index + 1)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(isSelected ? Color.white : Color.secondary)
                        .frame(width: 18, height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
                        )
                }

                // サムネイルまたはアイコン
                if let thumb = entry.thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                } else {
                    Image(systemName: entry.icon)
                        .font(.system(size: 11))
                        .foregroundStyle(entryColor)
                        .frame(width: 20)
                }

                // 内容
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.preview)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    // ファイルパスのメタ情報
                    if entry.isFilePath, let url = entry.fileURL {
                        Text(url.deletingLastPathComponent().path)
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // ホバー時のアクション
                if isHovered {
                    HStack(spacing: 4) {
                        if let onNavigate {
                            Button { onNavigate() } label: {
                                Image(systemName: "arrow.right.circle")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help("フォルダに移動")
                        }
                        if let onStage {
                            Button { onStage() } label: {
                                Image(systemName: "tray.and.arrow.down")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("ステージに追加")
                        }
                        if let onPin {
                            Button { onPin() } label: {
                                Image(systemName: entry.isPinned ? "pin.slash" : "pin")
                                    .font(.system(size: 10))
                                    .foregroundStyle(entry.isPinned ? .orange : .secondary)
                            }
                            .buttonStyle(.plain)
                            .help(entry.isPinned ? "ピン解除" : "ピン留め")
                        }
                    }
                } else {
                    // タイプバッジ + 時刻
                    HStack(spacing: 4) {
                        Text(typeBadge)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(entryColor.opacity(0.8))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(entryColor.opacity(0.1))
                            )
                        Text(entry.date.formatted(.dateTime.hour().minute()))
                            .font(.system(size: 9))
                            .foregroundStyle(.quaternary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) :
                            isHovered ? Color.primary.opacity(0.04) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { h in isHovered = h }
    }

    private var typeBadge: String {
        switch entry.type {
        case .text: return "TXT"
        case .filePath: return "PATH"
        case .image: return "IMG"
        case .files: return "FILE"
        }
    }

    private var entryColor: Color {
        switch entry.type {
        case .text: return .secondary
        case .filePath: return .blue
        case .image: return .purple
        case .files: return .green
        }
    }
}

// MARK: - Quick Open Popup (⌥Space)

struct QuickOpenPopupView: View {
    @ObservedObject var viewModel: FolderViewModel
    let onDismiss: () -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.badge.magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(Color.accentColor)

            TextField("パスを入力... ~/Desktop, /usr/local", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($isFocused)
                .onSubmit {
                    navigateToPath()
                }
                .onExitCommand {
                    onDismiss()
                }

            Text("⌥Space")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.06)))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .onAppear { isFocused = true }
        .focusable()
    }

    private func navigateToPath() {
        let path = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return }
        let expanded = NSString(string: path).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
            if isDir.boolValue {
                viewModel.navigateTo(url)
            } else {
                viewModel.navigateTo(url.deletingLastPathComponent())
            }
            onDismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.openMainPanel()
                }
            }
        } else {
            onDismiss()
        }
    }
}
