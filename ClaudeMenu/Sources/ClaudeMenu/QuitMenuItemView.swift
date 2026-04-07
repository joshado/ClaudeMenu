import SwiftUI

struct QuitMenuItemView: NSViewRepresentable {
    func makeNSView(context: Context) -> QuitTrackingView {
        QuitTrackingView()
    }

    func updateNSView(_ nsView: QuitTrackingView, context: Context) {}
}

class QuitTrackingView: NSView {
    private var isHighlighted = false
    private var trackingArea: NSTrackingArea?

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 22)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func draw(_ dirtyRect: NSRect) {
        if isHighlighted {
            NSColor.controlAccentColor.withAlphaComponent(0.8).setFill()
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 1), xRadius: 4, yRadius: 4)
            path.fill()
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuFont(ofSize: 13),
            .foregroundColor: isHighlighted ? NSColor.white : NSColor.secondaryLabelColor
        ]
        let text = NSAttributedString(string: "Quit", attributes: attributes)
        let textSize = text.size()
        let textRect = NSRect(
            x: 6,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect)
    }

    override func mouseEntered(with event: NSEvent) {
        isHighlighted = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHighlighted = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        NSApplication.shared.terminate(nil)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
