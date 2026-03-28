import SwiftUI

struct FileRowView: View {
    let item: FileItem
    let isSelected: Bool
    let isMultiSelected: Bool
    let isRenaming: Bool
    let onNavigate: () -> Void
    let onOpen: () -> Void
    let onRevealInFinder: () -> Void
    let onSelect: () -> Void
    let onCmdSelect: () -> Void
    let onShiftSelect: () -> Void
    let onMoveHere: ((URL) -> Void)?
    let onTrash: () -> Void
    let onDuplicate: () -> Void
    let onStartRename: () -> Void
    @Binding var renameText: String
    let onCommitRename: () -> Void
    let onCancelRename: () -> Void

    @State private var isHovered = false
    @State private var isDropTarget = false
    @FocusState private var isRenameFieldFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: iconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
                .shadow(color: .black.opacity(0.08), radius: 1, y: 1)

            VStack(alignment: .leading, spacing: 3) {
                // 名前 or リネームフィールド
                if isRenaming {
                    TextField("", text: $renameText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(Color.accentColor, lineWidth: 1.5)
                                )
                        )
                        .focused($isRenameFieldFocused)
                        .onSubmit { onCommitRename() }
                        .onExitCommand { onCancelRename() }
                        .onAppear { isRenameFieldFocused = true }
                } else {
                    HStack(spacing: 4) {
                        Text(item.name)
                            .font(.system(size: 13, weight: highlighted ? .semibold : .regular))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(highlighted ? .white : .primary)

                        if item.isSymlink {
                            Image(systemName: "arrow.turn.right.up")
                                .font(.system(size: 8))
                                .foregroundStyle(highlighted ? Color.white.opacity(0.7) : Color.gray)
                        }
                    }
                }

                HStack(spacing: 5) {
                    Text(item.kindDescription)
                        .font(.system(size: 10))
                        .foregroundStyle(highlighted ? .white.opacity(0.7) : .secondary)

                    if item.isDirectory, let count = item.formattedChildCount {
                        Circle()
                            .fill(highlighted ? Color.white.opacity(0.4) : Color.gray.opacity(0.4))
                            .frame(width: 3, height: 3)
                        Text(count)
                            .font(.system(size: 10))
                            .foregroundStyle(highlighted ? Color.white.opacity(0.7) : Color.secondary)
                    }

                    if !item.isDirectory && item.size > 0 {
                        Circle()
                            .fill(highlighted ? Color.white.opacity(0.4) : Color.gray.opacity(0.4))
                            .frame(width: 3, height: 3)
                        Text(item.formattedSize)
                            .font(.system(size: 10))
                            .foregroundStyle(highlighted ? Color.white.opacity(0.7) : Color.secondary)
                    }

                    Circle()
                        .fill(highlighted ? Color.white.opacity(0.4) : Color.gray.opacity(0.4))
                        .frame(width: 3, height: 3)
                    Text(item.formattedDate)
                        .font(.system(size: 10))
                        .foregroundStyle(highlighted ? Color.white.opacity(0.7) : Color.secondary)
                }
            }

            Spacer(minLength: 4)

            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(highlighted ? Color.white.opacity(0.6) : Color.gray.opacity(0.4))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundStyle)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(Color.accentColor, lineWidth: 2)
                .opacity(isDropTarget && item.isDirectory ? 1 : 0)
        )
        .background(HoverTracker(isHovered: $isHovered))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onOpen()
        }
        .onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                onCmdSelect()
            } else if NSEvent.modifierFlags.contains(.shift) {
                onShiftSelect()
            } else {
                onSelect()
            }
        }
        .draggable(item.url) {
            HStack(spacing: 6) {
                Image(nsImage: iconImage)
                    .resizable()
                    .frame(width: 20, height: 20)
                Text(item.name)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
            .padding(6)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard item.isDirectory, let source = urls.first else { return false }
            if source == item.url { return false }
            if source.deletingLastPathComponent() == item.url { return false }
            onMoveHere?(source)
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                isDropTarget = targeted
            }
        }
        .contextMenu {
            Button { onOpen() } label: {
                Label("開く", systemImage: "arrow.up.forward")
            }
            Button { onRevealInFinder() } label: {
                Label("Finderで表示", systemImage: "folder")
            }
            Divider()
            Button { onStartRename() } label: {
                Label("名前を変更", systemImage: "pencil")
            }
            Button { onDuplicate() } label: {
                Label("複製", systemImage: "plus.square.on.square")
            }
            Divider()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.url.path, forType: .string)
            } label: {
                Label("パスをコピー", systemImage: "doc.on.doc")
            }
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.name, forType: .string)
            } label: {
                Label("名前をコピー", systemImage: "textformat")
            }
            Divider()
            Button(role: .destructive) { onTrash() } label: {
                Label("ゴミ箱に入れる", systemImage: "trash")
            }
        }
    }

    private var highlighted: Bool {
        isSelected || isMultiSelected
    }

    private var iconImage: NSImage {
        let img = item.nsImage
        img.size = NSSize(width: 28, height: 28)
        return img
    }

    @ViewBuilder
    private var backgroundStyle: some View {
        if isSelected || isMultiSelected {
            RoundedRectangle(cornerRadius: 7)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color.accentColor.opacity(0.3), radius: 3, y: 1)
        } else if isDropTarget && item.isDirectory {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.accentColor.opacity(0.1))
        } else if isHovered {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.primary.opacity(0.06))
        } else {
            Color.clear
        }
    }
}
