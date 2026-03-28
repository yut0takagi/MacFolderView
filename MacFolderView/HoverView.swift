import SwiftUI
import AppKit

/// NSTrackingArea を使って行全体のホバーを確実に検出する背景ビュー
struct HoverTracker: NSViewRepresentable {
    @Binding var isHovered: Bool

    func makeNSView(context: Context) -> HoverTrackingNSView {
        let view = HoverTrackingNSView()
        view.onHoverChanged = { [self] hovering in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.12)) {
                    self.isHovered = hovering
                }
            }
        }
        return view
    }

    func updateNSView(_ nsView: HoverTrackingNSView, context: Context) {
        nsView.onHoverChanged = { [self] hovering in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.12)) {
                    self.isHovered = hovering
                }
            }
        }
    }
}

final class HoverTrackingNSView: NSView {
    var onHoverChanged: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

    // マウスイベントはSwiftUI側に通過させる
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
