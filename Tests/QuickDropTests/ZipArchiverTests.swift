import Foundation
@testable import QuickDropCore
import XCTest

final class ZipArchiverTests: XCTestCase {
    func testShouldArchiveDecisionMatrix() throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("QuickDropZipTests-\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let fileA = tempDir.appendingPathComponent("a.txt")
        let fileB = tempDir.appendingPathComponent("b.txt")
        let subDir = tempDir.appendingPathComponent("folder", isDirectory: true)
        try Data("hello".utf8).write(to: fileA)
        try Data("world".utf8).write(to: fileB)
        try fm.createDirectory(at: subDir, withIntermediateDirectories: true)

        // Empty list never archives
        XCTAssertFalse(ZipArchiver.shouldArchive(urls: [], behavior: .alwaysForFiles, shiftPressed: true))

        // Off mode only archives when Shift is pressed
        XCTAssertFalse(ZipArchiver.shouldArchive(urls: [fileA], behavior: .off, shiftPressed: false))
        XCTAssertFalse(ZipArchiver.shouldArchive(urls: [fileA, fileB], behavior: .off, shiftPressed: false))
        XCTAssertTrue(ZipArchiver.shouldArchive(urls: [fileA], behavior: .off, shiftPressed: true))

        // Multiple or directory mode
        XCTAssertFalse(ZipArchiver.shouldArchive(urls: [fileA], behavior: .whenMultipleOrDirectory, shiftPressed: false))
        XCTAssertTrue(ZipArchiver.shouldArchive(urls: [fileA, fileB], behavior: .whenMultipleOrDirectory, shiftPressed: false))
        XCTAssertTrue(ZipArchiver.shouldArchive(urls: [subDir], behavior: .whenMultipleOrDirectory, shiftPressed: false))

        // Always mode
        XCTAssertTrue(ZipArchiver.shouldArchive(urls: [fileA], behavior: .alwaysForFiles, shiftPressed: false))
    }
}
