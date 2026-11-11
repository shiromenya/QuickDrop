import AppKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

/// Provides zero-latency icons and previews for the drop float-out animation, opportunistically
/// upgrading file items to QuickLook thumbnails if prefetched while hovering the edge.
@MainActor
final class FilePreviewProvider {
    private var prefetchedURL: URL?
    private var prefetchedThumbnail: NSImage?
    private var prefetchTask: Task<Void, Never>?

    func prefetch(payload: DraggedPayload) {
        let urls = payload.fileURLs
        guard let firstURL = urls.first?.standardizedFileURL else { return }
        if prefetchedURL == firstURL, prefetchedThumbnail != nil {
            return
        }

        prefetchTask?.cancel()
        prefetchedURL = firstURL
        prefetchedThumbnail = nil

        let scale = NSScreen.screens.map(\.backingScaleFactor).max() ?? 2.0
        let request = QLThumbnailGenerator.Request(
            fileAt: firstURL,
            size: CGSize(width: 84, height: 84),
            scale: scale,
            representationTypes: .thumbnail
        )

        prefetchTask = Task { [weak self] in
            guard let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request),
                  !Task.isCancelled else {
                return
            }
            guard let self, self.prefetchedURL == firstURL else { return }
            self.prefetchedThumbnail = representation.nsImage
        }
    }

    func previewImage(for payload: DraggedPayload) -> NSImage {
        switch payload {
        case .files(let urls):
            if urls.count == 1,
               let first = urls.first?.standardizedFileURL,
               prefetchedURL == first,
               let cached = prefetchedThumbnail {
                return cached
            }
            if urls.count > 1 {
                return NSWorkspace.shared.icon(forFiles: urls.map(\.path))
            }
            if let first = urls.first {
                return NSWorkspace.shared.icon(forFile: first.path)
            }
            return fallbackIcon(symbolName: "doc.fill")

        case .images(let images):
            return images.first ?? fallbackIcon(symbolName: "photo.fill")

        case .webURLs:
            return NSWorkspace.shared.icon(for: .internetLocation)
        }
    }

    func clear() {
        prefetchTask?.cancel()
        prefetchTask = nil
        prefetchedURL = nil
        prefetchedThumbnail = nil
    }

    private func fallbackIcon(symbolName: String) -> NSImage {
        NSImage(systemSymbolName: symbolName, accessibilityDescription: "QuickDrop") ?? NSImage()
    }
}
