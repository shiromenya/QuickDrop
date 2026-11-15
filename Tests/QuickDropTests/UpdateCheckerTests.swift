import Foundation
@testable import QuickDropCore
import XCTest

final class UpdateCheckerTests: XCTestCase {
    func testAppVersionParsingAndOrdering() {
        XCTAssertEqual(AppVersion("v0.1.0"), AppVersion(major: 0, minor: 1, patch: 0))
        XCTAssertEqual(AppVersion("1.2"), AppVersion(major: 1, minor: 2, patch: 0))
        XCTAssertEqual(AppVersion("v1.0.0-beta.2"), AppVersion(major: 1, minor: 0, patch: 0))
        XCTAssertNil(AppVersion("invalid"))
        XCTAssertNil(AppVersion("1.2.3.4"))

        XCTAssertLessThan(AppVersion("0.1.0")!, AppVersion("v0.2.0")!)
        XCTAssertLessThan(AppVersion("0.9.9")!, AppVersion("1.0.0")!)
        XCTAssertFalse(AppVersion("1.0.0")! < AppVersion("1.0.0")!)
    }

    func testParseLatestReleaseOutcomes() throws {
        let json = """
        {
          "tag_name": "v0.2.0",
          "html_url": "https://github.com/shiromenya/QuickDrop/releases/tag/v0.2.0",
          "name": "QuickDrop 0.2.0"
        }
        """.data(using: .utf8)!

        let available = try UpdateChecker.parseLatestRelease(data: json, currentVersionString: "0.1.0")
        switch available {
        case .updateAvailable(let current, let latest):
            XCTAssertEqual(current, AppVersion(major: 0, minor: 1, patch: 0))
            XCTAssertEqual(latest.version, AppVersion(major: 0, minor: 2, patch: 0))
            XCTAssertEqual(latest.tagName, "v0.2.0")
        case .upToDate:
            XCTFail("Expected updateAvailable")
        }

        let upToDate = try UpdateChecker.parseLatestRelease(data: json, currentVersionString: "0.2.0")
        XCTAssertEqual(upToDate, .upToDate(current: AppVersion(major: 0, minor: 2, patch: 0)))
    }
}
