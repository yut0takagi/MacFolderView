import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: FolderViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // お気に入り
            SidebarSectionHeader(title: "お気に入り")

            ForEach(viewModel.favorites) { fav in
                SidebarRow(
                    name: fav.name,
                    icon: fav.icon,
                    isActive: viewModel.currentPath == fav.url
                ) {
                    viewModel.navigateTo(fav.url)
                }
            }

            // 最近のフォルダ
            if !viewModel.recentFolders.isEmpty {
                SidebarSectionHeader(title: "最近")
                    .padding(.top, 8)

                ForEach(viewModel.recentFolders, id: \.self) { url in
                    SidebarRow(
                        name: url.lastPathComponent,
                        icon: "clock.arrow.circlepath",
                        isActive: viewModel.currentPath == url
                    ) {
                        viewModel.navigateTo(url)
                    }
                }
            }

            Spacer()

            // ツール
            Divider()
                .padding(.horizontal, 8)

            SidebarRow(name: "ターミナル", icon: "terminal", isActive: false) {
                viewModel.openTerminalHere()
            }
            .padding(.bottom, 6)
        }
        .frame(width: 120)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}

private struct SidebarSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }
}

private struct SidebarRow: View {
    let name: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                    .frame(width: 16)
                Text(name)
                    .font(.system(size: 12))
                    .foregroundStyle(isActive ? .primary : .secondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.accentColor.opacity(0.12) :
                            isHovered ? Color.primary.opacity(0.05) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = h
            }
        }
    }
}
