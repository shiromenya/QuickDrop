import AppKit

public enum QuickDropRunner {
    @MainActor
    public static func run() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = QuickDropSettings()
    private lazy var dragMonitor = GlobalDragMonitor(settings: settings)
    private let airDropService = AirDropService()

    private var overlayCoordinator: EdgeOverlayCoordinator?
    private var menuBarController: MenuBarController?
    private var screenObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep QuickDrop in the menu bar without adding an icon to the Dock.
        NSApp.setActivationPolicy(.accessory)

        let coordinator = EdgeOverlayCoordinator(settings: settings)
        self.overlayCoordinator = coordinator
        self.menuBarController = MenuBarController(settings: settings)

        wireCallbacks(coordinator: coordinator)
        observeScreenChanges()
        syncMonitoringState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        dragMonitor.stop()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    private func wireCallbacks(coordinator: EdgeOverlayCoordinator) {
        dragMonitor.onDragStateChanged = { [weak self] isDragging in
            self?.overlayCoordinator?.setDraggingActive(isDragging)
        }

        dragMonitor.onCursorMoved = { [weak self] point in
            self?.overlayCoordinator?.updateCursorPosition(point)
        }

        coordinator.onDropCommitted = { [weak self] in
            self?.dragMonitor.notifyDragEnded()
        }

        coordinator.onPayloadDropped = { [weak self] payload, screen in
            self?.airDropService.share(payload: payload, on: screen)
        }

        settings.onChange = { [weak self] in
            self?.syncMonitoringState()
            self?.overlayCoordinator?.applySettings()
            self?.dragMonitor.refreshActiveEvaluationIfNeeded()
        }
    }

    private func syncMonitoringState() {
        if settings.isEnabled {
            dragMonitor.start()
        } else {
            dragMonitor.stop()
            overlayCoordinator?.setDraggingActive(false)
        }
    }

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.overlayCoordinator?.rebuildOverlays()
            }
        }
    }
}

extension NSApplication {
    @MainActor
    func activateQuickDrop() {
        if #available(macOS 14.0, *) {
            activate()
        } else {
            activate(ignoringOtherApps: true)
        }
    }
}
