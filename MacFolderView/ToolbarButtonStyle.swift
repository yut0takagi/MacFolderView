import SwiftUI

struct ToolbarIconButton: View {
    let icon: String
    let help: String
    let disabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    init(_ icon: String, help: String, disabled: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.help = help
        self.disabled = disabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(disabled ? .quaternary : isHovered ? .primary : .secondary)
                .frame(width: 26, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isHovered && !disabled ? Color.primary.opacity(0.08) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(help)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = h
            }
        }
    }
}
