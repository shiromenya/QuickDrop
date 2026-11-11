import AppKit
@testable import QuickDropCore
import XCTest

final class ScreenEdgeTests: XCTestCase {
    func testSingleDisplayKeepsAllEnabledEdges() {
        let main = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let active = ScreenEdge.activeEdges(
            for: main,
            allScreenFrames: [main],
            enabledEdges: Set(ScreenEdge.allCases),
            excludeAdjacentScreenEdges: true
        )
        XCTAssertEqual(active, [.left, .top, .right])
    }

    func testSideBySideDisplaysExcludeSharedVerticalBorder() {
        let leftScreen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let rightScreen = NSRect(x: 1440, y: 0, width: 1920, height: 1080)
        let all = [leftScreen, rightScreen]

        let leftActive = ScreenEdge.activeEdges(
            for: leftScreen,
            allScreenFrames: all,
            enabledEdges: Set(ScreenEdge.allCases),
            excludeAdjacentScreenEdges: true
        )
        let rightActive = ScreenEdge.activeEdges(
            for: rightScreen,
            allScreenFrames: all,
            enabledEdges: Set(ScreenEdge.allCases),
            excludeAdjacentScreenEdges: true
        )

        XCTAssertEqual(leftActive, [.left, .top])
        XCTAssertEqual(rightActive, [.top, .right])
    }

    func testStackedDisplaysExcludeSharedTopBorder() {
        let bottomScreen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let topScreen = NSRect(x: 0, y: 900, width: 1440, height: 900)
        let all = [bottomScreen, topScreen]

        let bottomActive = ScreenEdge.activeEdges(
            for: bottomScreen,
            allScreenFrames: all,
            enabledEdges: Set(ScreenEdge.allCases),
            excludeAdjacentScreenEdges: true
        )
        let topActive = ScreenEdge.activeEdges(
            for: topScreen,
            allScreenFrames: all,
            enabledEdges: Set(ScreenEdge.allCases),
            excludeAdjacentScreenEdges: true
        )

        XCTAssertEqual(bottomActive, [.left, .right])
        XCTAssertEqual(topActive, [.left, .top, .right])
    }

    func testAdjacentBordersKeptWhenExclusionDisabled() {
        let leftScreen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let rightScreen = NSRect(x: 1440, y: 0, width: 1920, height: 1080)

        let leftActive = ScreenEdge.activeEdges(
            for: leftScreen,
            allScreenFrames: [leftScreen, rightScreen],
            enabledEdges: [.left, .right],
            excludeAdjacentScreenEdges: false
        )

        XCTAssertEqual(leftActive, [.left, .right])
    }

    func testDropRectsDoNotOverlapWithCornerInset() {
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let topRect = ScreenEdge.top.dropRect(in: screen, hitThickness: 14, cornerInset: 32)
        let leftRect = ScreenEdge.left.dropRect(in: screen, hitThickness: 14, cornerInset: 32)
        let rightRect = ScreenEdge.right.dropRect(in: screen, hitThickness: 14, cornerInset: 32)

        XCTAssertFalse(topRect.intersects(leftRect))
        XCTAssertFalse(topRect.intersects(rightRect))
        XCTAssertEqual(topRect.maxY, 900)
        XCTAssertEqual(leftRect.minX, 0)
        XCTAssertEqual(rightRect.maxX, 1440)
    }

    func testPillFrameStaysClampedWithinScreenBounds() {
        let bounds = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let pillSize = NSSize(width: 150, height: 34)

        let topPill = ScreenEdge.top.pillFrame(
            in: bounds,
            pillSize: pillSize,
            cursorLocalPoint: NSPoint(x: 10, y: 895)
        )
        XCTAssertGreaterThanOrEqual(topPill.minX, 56)
        XCTAssertLessThanOrEqual(topPill.maxY, bounds.height - 46)
    }
}
