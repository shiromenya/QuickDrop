import AppKit
@testable import QuickDropCore
import XCTest

final class DraggedPayloadTests: XCTestCase {
    func testFilterWebURLsAcceptsHttpAndHttpsOnly() {
        let candidates = [
            URL(string: "https://example.com/file.png")!,
            URL(string: "http://localhost:8080")!,
            URL(fileURLWithPath: "/tmp/local.txt"),
            URL(string: "mailto:test@example.com")!
        ]

        let filtered = DraggedPayload.filterWebURLs(candidates)
        XCTAssertEqual(filtered.map(\.absoluteString), [
            "https://example.com/file.png",
            "http://localhost:8080"
        ])
    }

    func testExtractFileURLsFromPasteboard() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }

        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("quickdrop-test-\(UUID().uuidString).txt")
        try Data("quickdrop".utf8).write(to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        pasteboard.clearContents()
        pasteboard.writeObjects([tempFile as NSURL])

        let payload = DraggedPayload.extract(from: pasteboard, allowWebAndImageDrags: false)
        XCTAssertEqual(payload?.fileURLs, [tempFile])
        XCTAssertEqual(payload?.itemCount, 1)
    }

    func testWebAndImageDragsRespectToggle() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }

        let webURL = URL(string: "https://github.com")!
        pasteboard.clearContents()
        pasteboard.writeObjects([webURL as NSURL])

        XCTAssertFalse(DraggedPayload.canAccept(pasteboard: pasteboard, allowWebAndImageDrags: false))
        XCTAssertTrue(DraggedPayload.canAccept(pasteboard: pasteboard, allowWebAndImageDrags: true))
    }
}
