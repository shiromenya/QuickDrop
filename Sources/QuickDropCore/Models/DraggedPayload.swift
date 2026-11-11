import AppKit

/// Represents the validated items extracted from a macOS drag pasteboard.
public enum DraggedPayload {
    case files([URL])
    case images([NSImage])
    case webURLs([URL])

    public var itemCount: Int {
        switch self {
        case .files(let urls): return urls.count
        case .images(let images): return images.count
        case .webURLs(let urls): return urls.count
        }
    }

    public var fileURLs: [URL] {
        if case .files(let urls) = self {
            return urls
        }
        return []
    }

    public static func canAccept(pasteboard: NSPasteboard, allowWebAndImageDrags: Bool) -> Bool {
        if pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) {
            return true
        }

        guard allowWebAndImageDrags else { return false }

        if hasImageTypes(in: pasteboard),
           pasteboard.canReadObject(forClasses: [NSImage.self], options: nil) {
            return true
        }

        if let urls = readWebURLs(from: pasteboard), !urls.isEmpty {
            return true
        }

        return false
    }

    public static func extract(from pasteboard: NSPasteboard, allowWebAndImageDrags: Bool) -> DraggedPayload? {
        if let fileURLs = readFileURLs(from: pasteboard), !fileURLs.isEmpty {
            return .files(fileURLs)
        }

        guard allowWebAndImageDrags else { return nil }

        // Prefer image data over a backing image URL when browsers attach both,
        // so dragging an image transfers the picture itself via AirDrop.
        if hasImageTypes(in: pasteboard),
           let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           !images.isEmpty {
            return .images(images)
        }

        if let webURLs = readWebURLs(from: pasteboard), !webURLs.isEmpty {
            return .webURLs(webURLs)
        }

        return nil
    }

    /// Filters a mixed URL list down to supported web (`http`/`https`) links.
    public static func filterWebURLs(_ urls: [URL]) -> [URL] {
        urls.filter { url in
            guard !url.isFileURL,
                  let scheme = url.scheme?.lowercased() else {
                return false
            }
            return scheme == "http" || scheme == "https"
        }
    }

    private static func readFileURLs(from pasteboard: NSPasteboard) -> [URL]? {
        guard let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] else {
            return nil
        }
        let filtered = urls.filter(\.isFileURL)
        return filtered.isEmpty ? nil : filtered
    }

    private static func readWebURLs(from pasteboard: NSPasteboard) -> [URL]? {
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return nil
        }
        let filtered = filterWebURLs(urls)
        return filtered.isEmpty ? nil : filtered
    }

    private static func hasImageTypes(in pasteboard: NSPasteboard) -> Bool {
        guard let types = pasteboard.types else { return false }
        return types.contains(.tiff) || types.contains(.png)
    }
}
