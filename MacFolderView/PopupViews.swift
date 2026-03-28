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
                Text("クリップボード履歴")
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
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(viewModel.clipboardHistory.enumerated()), id: \.element.id) { index, entry in
                            ClipboardPopupRow(
                                entry: entry,
                                isSelected: index == viewModel.clipboardSelectedIndex,
                                index: index
                            ) {
                                viewModel.clipboardSelectedIndex = index
                                viewModel.copyFromHistory(entry)
                                onDismiss()
                            }
                        }
                    }
                    .padding(6)
                }
            }

            Divider()

            // フッター
            HStack(spacing: 12) {
                Text("\(viewModel.clipboardHistory.count) 件")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                if !viewModel.clipboardHistory.isEmpty {
                    Button {
                        viewModel.clearClipboardHistory()
                    } label: {
                        Text("すべてクリア")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    onDismiss()
                } label: {
                    Text("Esc で閉じる")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
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

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // 番号
                Text("\(index + 1)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                    .frame(width: 18, height: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
                    )

                Image(systemName: entry.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 14)

                Text(entry.preview)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(entry.date.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
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
            // ポップアップ閉じてからメインパネルを開く
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
