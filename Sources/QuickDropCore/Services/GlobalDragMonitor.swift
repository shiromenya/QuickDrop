import AppKit

/// Monitors system-wide file (and optionally web/image) drag sessions by correlating
/// mouse drag events with changes to macOS's shared `.drag` pasteboard.
@MainActor
final class GlobalDragMonitor {
    var onDragStateChanged: ((Bool) -> Void)?
    var onCursorMoved: ((NSPoint) -> Void)?

    private let settings: QuickDropSettings
    private let dragPasteboard = NSPasteboard(name: .drag)
    private var globalMonitor: Any?
    private var watchdogTimer: Timer?

    private var isMonitoring = false
    private var hasActiveSupportedPasteboardDrag = false
    private var isOverlayActive = false
    private var baselineChangeCount: Int

    init(settings: QuickDropSettings) {
        self.settings = settings
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

    func refreshActiveEvaluationIfNeeded() {
        guard hasActiveSupportedPasteboardDrag else { return }
        syncOverlayVisibilityForCurrentContext()
    }

    private func handleGlobalEvent(type: NSEvent.EventType) {
        switch type {
        case .leftMouseDown:
            // Snapshot the drag pasteboard count before a potential drag begins so stale
            // items from previous drags do not trigger false positives when moving windows.
            baselineChangeCount = dragPasteboard.changeCount

        case .leftMouseDragged:
            if hasActiveSupportedPasteboardDrag {
                syncOverlayVisibilityForCurrentContext()
                if isOverlayActive {
                    onCursorMoved?(NSEvent.mouseLocation)
                }
                return
            }

            let currentCount = dragPasteboard.changeCount
            guard currentCount != baselineChangeCount else { return }

            if DraggedPayload.canAccept(
                pasteboard: dragPasteboard,
                allowWebAndImageDrags: settings.allowWebAndImageDrags
            ) {
                beginDragSession()
            } else {
                // Unsupported drag (e.g. plain text selection): ignore this session.
                baselineChangeCount = currentCount
            }

        case .leftMouseUp:
            endDragSessionIfNeeded()

        default:
            break
        }
    }

    private func beginDragSession() {
        guard !hasActiveSupportedPasteboardDrag else { return }
        hasActiveSupportedPasteboardDrag = true
        startWatchdogTimer()
        syncOverlayVisibilityForCurrentContext()
        if isOverlayActive {
            onCursorMoved?(NSEvent.mouseLocation)
        }
    }

    private func endDragSessionIfNeeded() {
        stopWatchdogTimer()
        baselineChangeCount = dragPasteboard.changeCount
        hasActiveSupportedPasteboardDrag = false

        guard isOverlayActive else { return }
        isOverlayActive = false
        onDragStateChanged?(false)
    }

    private func syncOverlayVisibilityForCurrentContext() {
        let frontmostID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let allowed = settings.shouldAllowDrag(
            modifierFlags: NSEvent.modifierFlags,
            frontmostBundleIdentifier: frontmostID
        )
        if allowed != isOverlayActive {
            isOverlayActive = allowed
            onDragStateChanged?(allowed)
        }
    }

    private func startWatchdogTimer() {
        stopWatchdogTimer()
        // Global monitors miss .leftMouseUp when the release happens inside our own drop panel,
        // and checking NSEvent.modifierFlags here avoids registering a global .flagsChanged monitor.
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let leftButtonPressed = (NSEvent.pressedMouseButtons & 1) != 0
                if !leftButtonPressed {
                    self.endDragSessionIfNeeded()
                } else if self.hasActiveSupportedPasteboardDrag {
                    self.syncOverlayVisibilityForCurrentContext()
                    if self.isOverlayActive {
                        self.onCursorMoved?(NSEvent.mouseLocation)
                    }
                }
            }
        }
    }

    private func stopWatchdogTimer() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }
}
