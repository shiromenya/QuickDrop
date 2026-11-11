import AppKit

/// Active screen edges where QuickDrop displays an ambient glow and accepts dropped files.
/// Bottom edge is intentionally omitted so it never collides with the macOS Dock.
enum ScreenEdge: String, CaseIterable, Hashable {
    case left
    case top
    case right

    /// Computes the thin outer drop-target rectangle in global screen coordinates.
    func dropRect(in screenFrame: NSRect, hitThickness: CGFloat, cornerInset: CGFloat) -> NSRect {
        let topHeight = hitThickness
        let clampedInset = min(cornerInset, min(screenFrame.width, screenFrame.height) * 0.25)

        switch self {
        case .top:
            return NSRect(
                x: screenFrame.minX + clampedInset,
                y: screenFrame.maxY - topHeight,
                width: max(1, screenFrame.width - clampedInset * 2),
                height: topHeight
            )

        case .left:
            let topOffset = max(topHeight, clampedInset)
            let bottomOffset = clampedInset
            return NSRect(
                x: screenFrame.minX,
                y: screenFrame.minY + bottomOffset,
                width: hitThickness,
                height: max(1, screenFrame.height - topOffset - bottomOffset)
            )

        case .right:
            let topOffset = max(topHeight, clampedInset)
            let bottomOffset = clampedInset
            return NSRect(
                x: screenFrame.maxX - hitThickness,
                y: screenFrame.minY + bottomOffset,
                width: hitThickness,
                height: max(1, screenFrame.height - topOffset - bottomOffset)
            )
        }
    }

    /// Computes the floating AirDrop pill frame inside the screen-sized glow view.
    func pillFrame(
        in bounds: NSRect,
        pillSize: NSSize,
        cursorLocalPoint: NSPoint?
    ) -> NSRect {
        let edgeMargin: CGFloat = 18
        let safeEdgeMargin: CGFloat = 56

        let x: CGFloat
        let y: CGFloat

        switch self {
        case .left:
            x = edgeMargin
            let targetY = (cursorLocalPoint?.y ?? bounds.midY) - pillSize.height / 2
            y = min(max(targetY, safeEdgeMargin), bounds.height - pillSize.height - safeEdgeMargin)

        case .right:
            x = bounds.width - pillSize.width - edgeMargin
            let targetY = (cursorLocalPoint?.y ?? bounds.midY) - pillSize.height / 2
            y = min(max(targetY, safeEdgeMargin), bounds.height - pillSize.height - safeEdgeMargin)

        case .top:
            let targetX = (cursorLocalPoint?.x ?? bounds.midX) - pillSize.width / 2
            x = min(max(targetX, safeEdgeMargin), bounds.width - pillSize.width - safeEdgeMargin)
            // Keep clear of the macOS menu bar / notch area when hovering the top edge.
            y = bounds.height - pillSize.height - 46
        }

        return NSRect(origin: NSPoint(x: x, y: y), size: pillSize)
    }
}
