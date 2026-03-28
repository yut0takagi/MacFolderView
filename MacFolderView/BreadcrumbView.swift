import SwiftUI

struct BreadcrumbView: View {
    let path: URL
    let onNavigate: (URL) -> Void

    @State private var hoveredIndex: Int?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(Array(pathComponents.enumerated()), id: \.offset) { index, component in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.quaternary)
                                .padding(.horizontal, 1)
                        }
                        Button(action: {
                            onNavigate(component.url)
                        }) {
                            HStack(spacing: 3) {
                                if index == 0 {
                                    Image(systemName: component.name == "~" ? "house.fill" : "externaldrive.fill")
                                        .font(.system(size: 9))
                                }
                                Text(component.name)
                                    .font(.system(size: 11, weight: index == pathComponents.count - 1 ? .semibold : .regular))
                            }
                            .foregroundStyle(index == pathComponents.count - 1 ? .primary : .secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(hoveredIndex == index ? Color.primary.opacity(0.08) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .onHover { h in
                            withAnimation(.easeInOut(duration: 0.1)) {
                                hoveredIndex = h ? index : nil
                            }
                        }
                        .id(index)
                    }
                }
                .padding(.horizontal, 6)
            }
            .onChange(of: path) {
                withAnimation {
                    proxy.scrollTo(pathComponents.count - 1, anchor: .trailing)
                }
            }
        }
    }

    private var pathComponents: [(name: String, url: URL)] {
        var components: [(name: String, url: URL)] = []
        var url = path
        let home = FileManager.default.homeDirectoryForCurrentUser

        var urls: [URL] = []
        while url.path != "/" {
            urls.insert(url, at: 0)
            url = url.deletingLastPathComponent()
        }
        urls.insert(URL(fileURLWithPath: "/"), at: 0)

        for u in urls {
            if u.path == "/" {
                components.append(("/", u))
            } else if u == home {
                components = [("~", u)]
            } else {
                components.append((u.lastPathComponent, u))
            }
        }
        return components
    }
}
