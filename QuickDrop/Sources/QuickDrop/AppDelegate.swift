import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = QuickDropSettings()
    private let dragMonitor = GlobalDragMonitor()
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

        coordinator.onFilesDropped = { [weak self] fileURLs, screen in
            guard let self else { return }
            self.airDropService.share(fileURLs: fileURLs, on: screen)
        }

        settings.onChange = { [weak self] in
            self?.syncMonitoringState()
            self?.overlayCoordinator?.applySettings()
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
