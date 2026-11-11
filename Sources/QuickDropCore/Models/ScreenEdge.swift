import AppKit

/// Active screen edges where QuickDrop displays an ambient glow and accepts dropped items.
/// Bottom edge is intentionally omitted so it never collides with the macOS Dock.
public enum ScreenEdge: String, CaseIterable, Hashable, Codable {
    case left
    case top
    case right

    public var displayName: String {
        switch self {
        case .left: return "左辺"
        case .top: return "上辺"
        case .right: return "右辺"
        }
    }

    /// Returns the edges that should be active on `screenFrame`, excluding any edge
    /// bordered directly by another connected display when `excludeAdjacentScreenEdges` is enabled.
    public static func activeEdges(
        for screenFrame: NSRect,
        allScreenFrames: [NSRect],
        enabledEdges: Set<ScreenEdge>,
        excludeAdjacentScreenEdges: Bool
    ) -> Set<ScreenEdge> {
        var result = enabledEdges
        guard excludeAdjacentScreenEdges else { return result }

        let adjacencyTolerance: CGFloat = 2.0
        let minimumSharedSpan: CGFloat = 20.0

        for other in allScreenFrames {
            if other.equalTo(screenFrame) { continue }

            let verticalOverlap = overlapSpan(
                minA: screenFrame.minY, maxA: screenFrame.maxY,
                minB: other.minY, maxB: other.maxY
            )
            if verticalOverlap > minimumSharedSpan {
                if abs(other.maxX - screenFrame.minX) <= adjacencyTolerance {
                    result.remove(.left)
                }
                if abs(other.minX - screenFrame.maxX) <= adjacencyTolerance {
                    result.remove(.right)
                }
            }

            let horizontalOverlap = overlapSpan(
                minA: screenFrame.minX, maxA: screenFrame.maxX,
                minB: other.minX, maxB: other.maxX
            )
            if horizontalOverlap > minimumSharedSpan,
               abs(other.minY - screenFrame.maxY) <= adjacencyTolerance {
                result.remove(.top)
            }
        }

        return result
    }

    /// Computes the thin outer drop-target rectangle in global screen coordinates.
    public func dropRect(in screenFrame: NSRect, hitThickness: CGFloat, cornerInset: CGFloat) -> NSRect {
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
    public func pillFrame(
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

    private static func overlapSpan(minA: CGFloat, maxA: CGFloat, minB: CGFloat, maxB: CGFloat) -> CGFloat {
        max(0, min(maxA, maxB) - max(minA, minB))
    }
}
