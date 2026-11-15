import AppKit

/// Presents either the native macOS AirDrop panel or the system sharing picker for dropped items
/// without moving or altering existing files on disk.
@MainActor
final class AirDropService: NSObject, NSSharingServiceDelegate, NSSharingServicePickerDelegate {
    private var activeService: NSSharingService?
    private var activePicker: NSSharingServicePicker?
    private var temporaryFilesToCleanup: [URL] = []
    private weak var lastTargetScreen: NSScreen?
    private lazy var anchorWindow: NSWindow = makeAnchorWindow()

    func share(
        payload: DraggedPayload,
        behavior: ShareBehavior,
        zipBehavior: ZipArchiveBehavior = .off,
        shiftPressed: Bool = false,
        on screen: NSScreen?,
        recentHistory: RecentShareHistory? = nil
    ) {
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first
        lastTargetScreen = targetScreen

        if case .files(let rawURLs) = payload {
            let localFiles = deduplicatedLocalFiles(from: rawURLs)
            guard !localFiles.isEmpty else {
                ToastHUDPresenter.shared.show(message: L10n.tr("toast.files_missing"), on: targetScreen)
                return
            }

            if ZipArchiver.shouldArchive(
                urls: localFiles,
                behavior: zipBehavior,
                shiftPressed: shiftPressed
            ) {
                ToastHUDPresenter.shared.show(
                    message: L10n.tr("toast.zipping"),
                    style: .info,
                    on: targetScreen
                )
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        let archived = try await ZipArchiver.archive(urls: localFiles)
                        recentHistory?.record(payload: .files(localFiles), behavior: behavior)
                        self.dispatchShare(
                            items: [archived.zipURL],
                            tempURLs: archived.temporaryCleanupURLs,
                            behavior: behavior,
                            on: targetScreen
                        )
                    } catch {
                        ToastHUDPresenter.shared.show(
                            message: L10n.fmt("toast.share_failed", error.localizedDescription),
                            on: targetScreen
                        )
                    }
                }
                return
            }

            recentHistory?.record(payload: .files(localFiles), behavior: behavior)
            dispatchShare(items: localFiles, tempURLs: [], behavior: behavior, on: targetScreen)
            return
        }

        let prepared = prepareShareItems(from: payload)
        guard !prepared.items.isEmpty else { return }
        recentHistory?.record(payload: payload, behavior: behavior)
        dispatchShare(
            items: prepared.items,
            tempURLs: prepared.temporaryURLs,
            behavior: behavior,
            on: targetScreen
        )
    }

    private func dispatchShare(
        items: [Any],
        tempURLs: [URL],
        behavior: ShareBehavior,
        on targetScreen: NSScreen?
    ) {
        switch behavior {
        case .airDropDirectly:
            shareViaAirDrop(items: items, tempURLs: tempURLs, on: targetScreen)
        case .systemSharePicker:
            shareViaSystemPicker(items: items, tempURLs: tempURLs, on: targetScreen)
        }
    }

    // MARK: - Share Flows

    private func shareViaAirDrop(items: [Any], tempURLs: [URL], on screen: NSScreen?) {
        guard let service = NSSharingService(named: .sendViaAirDrop),
              service.canPerform(withItems: items) else {
            cleanupTemporaryFiles(tempURLs)
            ToastHUDPresenter.shared.show(message: L10n.tr("toast.airdrop_unavailable"), on: screen)
            return
        }

        beginAnchorSession(tempURLs: tempURLs, on: screen)
        activeService = service
        service.delegate = self
        service.perform(withItems: items)
    }

    private func shareViaSystemPicker(items: [Any], tempURLs: [URL], on screen: NSScreen?) {
        beginAnchorSession(tempURLs: tempURLs, on: screen)
        guard let contentView = anchorWindow.contentView else {
            cleanupSession()
            return
        }

        let picker = NSSharingServicePicker(items: items)
        picker.delegate = self
        activePicker = picker

        let anchorRect = NSRect(
            x: contentView.bounds.midX - 1,
            y: contentView.bounds.midY - 1,
            width: 2,
            height: 2
        )
        picker.show(relativeTo: anchorRect, of: contentView, preferredEdge: .minY)
    }

    private func beginAnchorSession(tempURLs: [URL], on screen: NSScreen?) {
        cleanupTemporaryFiles(temporaryFilesToCleanup)
        temporaryFilesToCleanup = tempURLs

        positionAnchorWindow(on: screen)
        anchorWindow.orderFrontRegardless()
        NSApp.activateQuickDrop()
    }

    // MARK: - NSSharingServicePickerDelegate

    func sharingServicePicker(
        _ sharingServicePicker: NSSharingServicePicker,
        didChoose service: NSSharingService?
    ) {
        sharingServicePicker.delegate = nil
        activePicker = nil

        guard let service else {
            cleanupSession()
            return
        }
        activeService = service
        service.delegate = self
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
            let message = L10n.fmt("toast.share_failed", error.localizedDescription)
            ToastHUDPresenter.shared.show(message: message, on: lastTargetScreen)
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
        activePicker = nil
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
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 340))
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
}
