import Foundation
@testable import QuickDropCore
import XCTest

final class RecentShareHistoryTests: XCTestCase {
    @MainActor
    func testRecordDeduplicatesCapsAtMaxAndClears() async {
        let history = RecentShareHistory(maxEntries: 5)
        XCTAssertTrue(history.entries.isEmpty)

        for idx in 1...6 {
            let url = URL(fileURLWithPath: "/tmp/file\(idx).txt")
            history.record(payload: .files([url]), behavior: .airDropDirectly)
        }

        XCTAssertEqual(history.entries.count, 5)
        XCTAssertEqual(history.entries.first?.title, "file6.txt")
        XCTAssertEqual(history.entries.last?.title, "file2.txt")

        // Recording an already-present item moves it back to the top without duplicating
        let duplicateURL = URL(fileURLWithPath: "/tmp/file3.txt")
        history.record(payload: .files([duplicateURL]), behavior: .systemSharePicker)
        XCTAssertEqual(history.entries.count, 5)
        XCTAssertEqual(history.entries.first?.title, "file3.txt")
        XCTAssertEqual(history.entries.first?.behavior, .systemSharePicker)

        history.clear()
        XCTAssertTrue(history.entries.isEmpty)
    }

    func testDisplayTitleFormatting() {
        let single = DraggedPayload.files([URL(fileURLWithPath: "/tmp/photo.png")])
        XCTAssertEqual(RecentShareHistory.displayTitle(for: single), "photo.png")

        let multi = DraggedPayload.files([
            URL(fileURLWithPath: "/tmp/one.pdf"),
            URL(fileURLWithPath: "/tmp/two.pdf"),
            URL(fileURLWithPath: "/tmp/three.pdf")
        ])
        let multiTitle = RecentShareHistory.displayTitle(for: multi)
        XCTAssertTrue(multiTitle.contains("one.pdf"))
        XCTAssertTrue(multiTitle.contains("2"))
    }
}
