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
    private let recentHistory = RecentShareHistory()
    private lazy var dragMonitor = GlobalDragMonitor(settings: settings)
    private lazy var updateChecker = UpdateChecker(settings: settings)
    private lazy var onboardingController = OnboardingWindowController(settings: settings) { [weak self] in
        self?.overlayCoordinator?.showPreviewGlow()
    }
    private lazy var settingsWindowController = SettingsWindowController(
        settings: settings,
        updateChecker: updateChecker,
        onPreviewGlow: { [weak self] in
            self?.overlayCoordinator?.showPreviewGlow()
        },
        onShowOnboarding: { [weak self] in
            self?.onboardingController.showWindow()
        }
    )
    private let airDropService = AirDropService()

    private var overlayCoordinator: EdgeOverlayCoordinator?
    private var menuBarController: MenuBarController?
    private var screenObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep QuickDrop in the menu bar without adding an icon to the Dock.
        NSApp.setActivationPolicy(.accessory)

        let coordinator = EdgeOverlayCoordinator(settings: settings)
        self.overlayCoordinator = coordinator
        self.menuBarController = MenuBarController(
            settings: settings,
            recentHistory: recentHistory,
            onResendRecent: { [weak self] entry in
                guard let self else { return }
                self.airDropService.share(
                    payload: entry.payload,
                    behavior: entry.behavior,
                    zipBehavior: self.settings.zipArchiveBehavior,
                    shiftPressed: false,
                    on: NSScreen.main,
                    recentHistory: self.recentHistory
                )
            },
            onOpenSettings: { [weak self] in
                self?.settingsWindowController.showWindow()
            },
            onPreviewGlow: { [weak self] in
                self?.overlayCoordinator?.showPreviewGlow()
            },
            onCheckForUpdates: { [weak self] in
                self?.updateChecker.checkForUpdates(userInitiated: true)
            },
            onShowOnboarding: { [weak self] in
                self?.onboardingController.showWindow()
            }
        )

        wireCallbacks(coordinator: coordinator)
        observeScreenChanges()
        syncMonitoringState()

        if !settings.hasCompletedOnboarding {
            onboardingController.showWindow()
        }
        updateChecker.automaticCheckIfDue()
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

        coordinator.onPayloadDropped = { [weak self] payload, resolvedBehavior, shiftPressed, screen in
            guard let self else { return }
            self.airDropService.share(
                payload: payload,
                behavior: resolvedBehavior,
                zipBehavior: self.settings.zipArchiveBehavior,
                shiftPressed: shiftPressed,
                on: screen,
                recentHistory: self.recentHistory
            )
        }

        settings.onChange = { [weak self] in
            self?.syncMonitoringState()
            self?.menuBarController?.refreshStatusAppearance()
            self?.overlayCoordinator?.applySettings()
            self?.dragMonitor.refreshActiveEvaluationIfNeeded()
        }
    }

    private func syncMonitoringState() {
        if settings.isEffectivelyEnabled {
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
                self?.settings.notifyDisplayConfigurationChanged()
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
