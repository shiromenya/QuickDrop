import AppKit

/// Presents the native macOS AirDrop sharing panel for dropped file URLs without moving
/// or altering the original files on disk.
@MainActor
final class AirDropService: NSObject, NSSharingServiceDelegate {
    private var activeService: NSSharingService?
    private lazy var anchorWindow: NSWindow = makeAnchorWindow()

    func share(fileURLs: [URL], on screen: NSScreen?) {
        let localFiles = deduplicatedLocalFiles(from: fileURLs)
        guard !localFiles.isEmpty else { return }

        guard let service = NSSharingService(named: .sendViaAirDrop),
              service.canPerform(withItems: localFiles) else {
            presentUnavailableAlert()
            return
        }

        positionAnchorWindow(on: screen ?? NSScreen.main ?? NSScreen.screens.first)
        anchorWindow.orderFrontRegardless()
        NSApp.activateQuickDrop()

        activeService = service
        service.delegate = self
        service.perform(withItems: localFiles)
    }

    // MARK: - NSSharingServiceDelegate

    func sharingService(
        _ sharingService: NSSharingService,
        sourceWindowForShareItems items: [Any],
        sharingContentScope: UnsafeMutablePointer<NSSharingService.SharingContentScope>
    ) -> NSWindow? {
        sharingContentScope.pointee = .full
        return anchorWindow
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        cleanupSession()
    }

    func sharingService(
        _ sharingService: NSSharingService,
        didFailToShareItems items: [Any],
        error: Error
    ) {
        cleanupSession()

        let nsError = error as NSError
        let isUserCancelled =
            nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError
        if !isUserCancelled {
            presentShareErrorAlert(error)
        }
    }

    // MARK: - Private Helpers

    private func cleanupSession() {
        anchorWindow.orderOut(nil)
        activeService = nil
    }

    private func makeAnchorWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 340),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        return window
    }

    private func positionAnchorWindow(on screen: NSScreen?) {
        guard let screen else { return }
        let frame = screen.visibleFrame
        let size = anchorWindow.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2
        )
        anchorWindow.setFrameOrigin(origin)
    }

    private func deduplicatedLocalFiles(from urls: [URL]) -> [URL] {
        var seen = Set<URL>()
        var result: [URL] = []
        for url in urls where url.isFileURL {
            let standardized = url.standardizedFileURL
            if seen.insert(standardized).inserted {
                result.append(standardized)
            }
        }
        return result
    }

    private func presentUnavailableAlert() {
        NSApp.activateQuickDrop()
        let alert = NSAlert()
        alert.messageText = "AirDrop を起動できませんでした"
        alert.informativeText = "Wi-Fi と Bluetooth がオンになっているか、または AirDrop で共有可能なファイルか確認してください。"
        alert.alertStyle = .informational
        alert.runModal()
    }

    private func presentShareErrorAlert(_ error: Error) {
        NSApp.activateQuickDrop()
        let alert = NSAlert()
        alert.messageText = "AirDrop の共有に失敗しました"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}
