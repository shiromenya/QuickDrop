import AppKit
import QuickLookThumbnailing

/// Provides zero-latency file icons for the drop float-out animation, opportunistically
/// upgrading to a QuickLook thumbnail if prefetched while hovering the edge.
@MainActor
final class FilePreviewProvider {
    private var prefetchedURL: URL?
    private var prefetchedThumbnail: NSImage?
    private var prefetchTask: Task<Void, Never>?

    func prefetch(urls: [URL]) {
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

    func previewImage(for urls: [URL]) -> NSImage {
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

        return NSImage(
            systemSymbolName: "doc.fill",
            accessibilityDescription: "File"
        ) ?? NSImage()
    }

    func clear() {
        prefetchTask?.cancel()
        prefetchTask = nil
        prefetchedURL = nil
        prefetchedThumbnail = nil
    }
}
