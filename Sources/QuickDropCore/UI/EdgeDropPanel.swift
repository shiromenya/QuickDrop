import AppKit

/// Thin, non-activating drop target strip placed along one active edge of a screen.
/// Uses a near-invisible non-zero alpha background so WindowServer hit-tests drag events reliably.
@MainActor
final class EdgeDropPanel: NSPanel {
    let edge: ScreenEdge
    let dropView: EdgeDropView

    init(edge: ScreenEdge, frame: NSRect) {
        self.edge = edge
        self.dropView = EdgeDropView(edge: edge, frame: NSRect(origin: .zero, size: frame.size))

        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        // Alpha >= 2/255 avoids 8-bit WindowServer alpha quantization rounding down to transparent 0.
        backgroundColor = NSColor.white.withAlphaComponent(0.008)
        hasShadow = false
        hidesOnDeactivate = false
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]

        contentView = dropView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class EdgeDropView: NSView {
    let edge: ScreenEdge
    var isDropEnabled = false
    var allowWebAndImageDrags = false

    var onHoverChanged: ((ScreenEdge, Bool, NSPoint?) -> Void)?
    var onPrefetchRequested: ((DraggedPayload) -> Void)?
    var onFilesDropped: ((DraggedPayload, ScreenEdge, NSPoint) -> Void)?

    init(edge: ScreenEdge, frame: NSRect) {
        self.edge = edge
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL, .URL, .tiff, .png])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        isDropEnabled ? self : nil
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard isDropEnabled,
              let payload = DraggedPayload.extract(
                from: sender.draggingPasteboard,
                allowWebAndImageDrags: allowWebAndImageDrags
              ),
              let operation = nonDestructiveOperation(for: sender) else {
            return []
        }
        onPrefetchRequested?(payload)
        onHoverChanged?(edge, true, NSEvent.mouseLocation)
        return operation
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard isDropEnabled,
              DraggedPayload.canAccept(
                pasteboard: sender.draggingPasteboard,
                allowWebAndImageDrags: allowWebAndImageDrags
              ),
              let operation = nonDestructiveOperation(for: sender) else {
            return []
        }
        onHoverChanged?(edge, true, NSEvent.mouseLocation)
        return operation
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onHoverChanged?(edge, false, nil)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDropEnabled && DraggedPayload.canAccept(
            pasteboard: sender.draggingPasteboard,
            allowWebAndImageDrags: allowWebAndImageDrags
        )
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard isDropEnabled,
              let payload = DraggedPayload.extract(
                from: sender.draggingPasteboard,
                allowWebAndImageDrags: allowWebAndImageDrags
              ) else {
            return false
        }

        let targetEdge = edge
        let dropPoint = NSEvent.mouseLocation
        // Defer overlay teardown and AirDrop launch to the next run-loop turn so AppKit
        // finishes concludeDragOperation cleanly before the drop panel is ordered out.
        DispatchQueue.main.async { [weak self] in
            self?.onFilesDropped?(payload, targetEdge, dropPoint)
        }
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        onHoverChanged?(edge, false, nil)
    }

    // MARK: - Helpers

    /// Always negotiates `.copy` (or `.generic` fallback) and NEVER `.move`.
    /// This guarantees Finder leaves the dragged file untouched at its original location.
    private func nonDestructiveOperation(for sender: NSDraggingInfo) -> NSDragOperation? {
        let mask = sender.draggingSourceOperationMask
        if mask.contains(.copy) {
            return .copy
        }
        if mask.contains(.generic) {
            return .generic
        }
        return nil
    }
}
