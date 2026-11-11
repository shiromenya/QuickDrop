import AppKit

/// Monitors system-wide file drag sessions by correlating mouse drag events with
/// changes to macOS's shared `.drag` pasteboard.
@MainActor
final class GlobalDragMonitor {
    var onDragStateChanged: ((Bool) -> Void)?
    var onCursorMoved: ((NSPoint) -> Void)?

    private let dragPasteboard = NSPasteboard(name: .drag)
    private var globalMonitor: Any?
    private var watchdogTimer: Timer?

    private var isMonitoring = false
    private var isDraggingFiles = false
    private var baselineChangeCount: Int

    init() {
        self.baselineChangeCount = dragPasteboard.changeCount
    }

    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        baselineChangeCount = dragPasteboard.changeCount

        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            let eventType = event.type
            Task { @MainActor [weak self] in
                self?.handleGlobalEvent(type: eventType)
            }
        }
    }

    func stop() {
        guard isMonitoring else { return }
        isMonitoring = false

        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        endDragSessionIfNeeded()
    }

    /// Forces the current drag session to close (e.g. immediately after a file drop completes).
    func notifyDragEnded() {
        endDragSessionIfNeeded()
    }

    private func handleGlobalEvent(type: NSEvent.EventType) {
        switch type {
        case .leftMouseDown:
            // Snapshot the drag pasteboard count before a potential drag begins so stale
            // items from previous drags do not trigger false positives when moving windows.
            baselineChangeCount = dragPasteboard.changeCount

        case .leftMouseDragged:
            if isDraggingFiles {
                onCursorMoved?(NSEvent.mouseLocation)
                return
            }

            let currentCount = dragPasteboard.changeCount
            guard currentCount != baselineChangeCount else { return }

            if hasFileURLs(in: dragPasteboard) {
                beginDragSession()
            } else {
                // Non-file drag (e.g. text selection drag): ignore this session.
                baselineChangeCount = currentCount
            }

        case .leftMouseUp:
            endDragSessionIfNeeded()

        default:
            break
        }
    }

    private func beginDragSession() {
        guard !isDraggingFiles else { return }
        isDraggingFiles = true
        startWatchdogTimer()
        onDragStateChanged?(true)
        onCursorMoved?(NSEvent.mouseLocation)
    }

    private func endDragSessionIfNeeded() {
        stopWatchdogTimer()
        baselineChangeCount = dragPasteboard.changeCount

        guard isDraggingFiles else { return }
        isDraggingFiles = false
        onDragStateChanged?(false)
    }

    private func startWatchdogTimer() {
        stopWatchdogTimer()
        // Global monitors miss .leftMouseUp when the release happens inside our own drop panel
        // or when another subsystem finishes the drag, so poll button state while dragging.
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let leftButtonPressed = (NSEvent.pressedMouseButtons & 1) != 0
                if !leftButtonPressed {
                    self.endDragSessionIfNeeded()
                } else if self.isDraggingFiles {
                    self.onCursorMoved?(NSEvent.mouseLocation)
                }
            }
        }
    }

    private func stopWatchdogTimer() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }

    private func hasFileURLs(in pasteboard: NSPasteboard) -> Bool {
        pasteboard.canReadObject(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
    }
}
