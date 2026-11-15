import AppKit

/// Active screen edges where QuickDrop displays an ambient glow and accepts dropped items.
/// Bottom edge is intentionally omitted so it never collides with the macOS Dock.
public enum ScreenEdge: String, CaseIterable, Hashable, Codable {
    case left
    case top
    case right

    public var displayName: String {
        switch self {
        case .left: return L10n.tr("edge.left")
        case .top: return L10n.tr("edge.top")
        case .right: return L10n.tr("edge.right")
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

    /// Returns the index in `screenFrames` containing `globalPoint`, falling back to the
    /// nearest display boundary so points clamped along `maxX` / `maxY` edges resolve reliably.
    public static func screenIndex(for globalPoint: NSPoint, in screenFrames: [NSRect]) -> Int? {
        if let exactIndex = screenFrames.firstIndex(where: { $0.contains(globalPoint) }) {
            return exactIndex
        }
        return screenFrames.enumerated().min { lhs, rhs in
            squaredDistance(from: globalPoint, to: lhs.element)
                < squaredDistance(from: globalPoint, to: rhs.element)
        }?.offset
    }

    private static func squaredDistance(from point: NSPoint, to rect: NSRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }
}

extension NSScreen {
    /// Persistent `CGDirectDisplayID` backing this screen when available.
    public var quickDropDisplayID: UInt32? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

public struct ConnectedDisplayInfo: Identifiable, Sendable {
    public let id: UInt32
    public let name: String
    public let resolutionText: String

    @MainActor
    public static func current() -> [ConnectedDisplayInfo] {
        NSScreen.screens.enumerated().compactMap { index, screen in
            guard let id = screen.quickDropDisplayID else { return nil }
            let fallbackName = L10n.fmt("display.fallback_name", index + 1)
            let name = screen.localizedName.isEmpty ? fallbackName : screen.localizedName
            let resolution = "\(Int(screen.frame.width))×\(Int(screen.frame.height))"
            return ConnectedDisplayInfo(id: id, name: name, resolutionText: resolution)
        }
    }
}
