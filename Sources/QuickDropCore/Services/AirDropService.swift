import AppKit

/// Presents the native macOS AirDrop sharing panel for dropped files, web URLs, or images
/// without moving or altering any existing files on disk.
@MainActor
final class AirDropService: NSObject, NSSharingServiceDelegate {
    private var activeService: NSSharingService?
    private var temporaryFilesToCleanup: [URL] = []
    private lazy var anchorWindow: NSWindow = makeAnchorWindow()

    func share(payload: DraggedPayload, on screen: NSScreen?) {
        let prepared = prepareShareItems(from: payload)
        guard !prepared.items.isEmpty else { return }

        guard let service = NSSharingService(named: .sendViaAirDrop),
              service.canPerform(withItems: prepared.items) else {
            cleanupTemporaryFiles(prepared.temporaryURLs)
            presentUnavailableAlert()
            return
        }

        // Clean up any leftover temp files from an earlier session before starting a new one.
        cleanupTemporaryFiles(temporaryFilesToCleanup)
        temporaryFilesToCleanup = prepared.temporaryURLs

        positionAnchorWindow(on: screen ?? NSScreen.main ?? NSScreen.screens.first)
        anchorWindow.orderFrontRegardless()
        NSApp.activateQuickDrop()

        activeService = service
        service.delegate = self
        service.perform(withItems: prepared.items)
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

    private func prepareShareItems(from payload: DraggedPayload) -> (items: [Any], temporaryURLs: [URL]) {
        switch payload {
        case .files(let urls):
            let localFiles = deduplicatedLocalFiles(from: urls)
            return (localFiles, [])

        case .webURLs(let urls):
            return (urls, [])

        case .images(let images):
            var tempURLs: [URL] = []
            for image in images {
                if let url = writeTemporaryPNG(for: image) {
                    tempURLs.append(url)
                }
            }
            if !tempURLs.isEmpty {
                return (tempURLs, tempURLs)
            }
            return (images, [])
        }
    }

    private func writeTemporaryPNG(for image: NSImage) -> URL? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }

        let filename = "QuickDrop-\(UUID().uuidString.prefix(8)).png"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try pngData.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            return nil
        }
    }

    private func cleanupSession() {
        anchorWindow.orderOut(nil)
        activeService = nil
        cleanupTemporaryFiles(temporaryFilesToCleanup)
        temporaryFilesToCleanup.removeAll()
    }

    private func cleanupTemporaryFiles(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
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
        alert.informativeText = "Wi-Fi と Bluetooth がオンになっているか、または AirDrop で共有可能なアイテムか確認してください。"
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
