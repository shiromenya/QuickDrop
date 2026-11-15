import AppKit
import Combine
import Foundation

public struct RecentShareEntry: Identifiable {
    public let id: UUID
    public let title: String
    public let payload: DraggedPayload
    public let behavior: ShareBehavior
    public let sharedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        payload: DraggedPayload,
        behavior: ShareBehavior,
        sharedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.payload = payload
        self.behavior = behavior
        self.sharedAt = sharedAt
    }
}

/// Keeps a volatile, in-memory-only list of recently shared items for quick one-click resending.
@MainActor
public final class RecentShareHistory: ObservableObject {
    @Published public private(set) var entries: [RecentShareEntry] = []
    public let maxEntries: Int

    public init(maxEntries: Int = 5) {
        self.maxEntries = max(1, maxEntries)
    }

    public func record(payload: DraggedPayload, behavior: ShareBehavior) {
        let title = Self.displayTitle(for: payload)
        let dedupKey = Self.deduplicationKey(for: payload)

        entries.removeAll { Self.deduplicationKey(for: $0.payload) == dedupKey }
        let entry = RecentShareEntry(
            title: title,
            payload: payload,
            behavior: behavior
        )
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
    }

    public func clear() {
        entries.removeAll()
    }

    nonisolated public static func displayTitle(for payload: DraggedPayload) -> String {
        switch payload {
        case .files(let urls):
            guard let first = urls.first else { return L10n.tr("recent.unknown_item") }
            if urls.count == 1 {
                return first.lastPathComponent
            }
            return L10n.fmt("recent.multiple_files", first.lastPathComponent, urls.count - 1)

        case .images(let images):
            if images.count <= 1 {
                return L10n.tr("recent.single_image")
            }
            return L10n.fmt("recent.multiple_images", images.count)

        case .webURLs(let urls):
            guard let first = urls.first else { return L10n.tr("recent.unknown_item") }
            let host = first.host ?? first.absoluteString
            if urls.count == 1 {
                return host
            }
            return L10n.fmt("recent.multiple_links", host, urls.count - 1)
        }
    }

    private static func deduplicationKey(for payload: DraggedPayload) -> String {
        switch payload {
        case .files(let urls):
            return "files:" + urls.map { $0.standardizedFileURL.path }.joined(separator: "|")
        case .webURLs(let urls):
            return "urls:" + urls.map(\.absoluteString).joined(separator: "|")
        case .images(let images):
            return "images:\(images.count):\(ObjectIdentifier(images.first as AnyObject).hashValue)"
        }
    }
}
