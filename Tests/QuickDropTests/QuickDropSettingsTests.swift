import AppKit
@testable import QuickDropCore
import XCTest

final class QuickDropSettingsTests: XCTestCase {
    @MainActor
    private func makeIsolatedSettings() -> (QuickDropSettings, String) {
        let suiteName = "QuickDropTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (QuickDropSettings(defaults: defaults), suiteName)
    }

    @MainActor
    func testDefaultValues() async {
        let (settings, suite) = makeIsolatedSettings()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        XCTAssertTrue(settings.isEnabled)
        XCTAssertEqual(settings.colorPreset, .airDropBlue)
        XCTAssertEqual(settings.intensity, .subtle)
        XCTAssertTrue(settings.avoidHotCorners)
        XCTAssertEqual(settings.hitThicknessPreset, .standard)
        XCTAssertEqual(settings.enabledEdges, Set(ScreenEdge.allCases))
        XCTAssertTrue(settings.excludeAdjacentScreenEdges)
        XCTAssertEqual(settings.modifierMode, .always)
        XCTAssertTrue(settings.hapticFeedbackEnabled)
        XCTAssertFalse(settings.allowWebAndImageDrags)
    }

    @MainActor
    func testModifierActivationModesAndExcludedApps() async {
        let (settings, suite) = makeIsolatedSettings()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        XCTAssertTrue(settings.shouldAllowDrag(modifierFlags: [], frontmostBundleIdentifier: "com.apple.finder"))

        settings.modifierMode = .disableWhileHoldingOption
        XCTAssertTrue(settings.shouldAllowDrag(modifierFlags: [], frontmostBundleIdentifier: "com.apple.finder"))
        XCTAssertFalse(settings.shouldAllowDrag(modifierFlags: [.option], frontmostBundleIdentifier: "com.apple.finder"))

        settings.modifierMode = .requireOptionKey
        XCTAssertFalse(settings.shouldAllowDrag(modifierFlags: [], frontmostBundleIdentifier: "com.apple.finder"))
        XCTAssertTrue(settings.shouldAllowDrag(modifierFlags: [.option], frontmostBundleIdentifier: "com.apple.finder"))

        settings.modifierMode = .always
        settings.toggleExcludedApp(bundleIdentifier: "com.figma.Desktop", displayName: "Figma")
        XCTAssertFalse(settings.shouldAllowDrag(modifierFlags: [], frontmostBundleIdentifier: "com.figma.Desktop"))
        XCTAssertTrue(settings.shouldAllowDrag(modifierFlags: [], frontmostBundleIdentifier: "com.apple.finder"))

        settings.removeExcludedApp(bundleIdentifier: "com.figma.Desktop")
        XCTAssertTrue(settings.shouldAllowDrag(modifierFlags: [], frontmostBundleIdentifier: "com.figma.Desktop"))
    }

    @MainActor
    func testEdgeToggleRequiresAtLeastOneEnabledEdgeToAllowDrag() async {
        let (settings, suite) = makeIsolatedSettings()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }

        settings.toggleEdge(.top)
        XCTAssertEqual(settings.enabledEdges, [.left, .right])
        XCTAssertTrue(settings.shouldAllowDrag(modifierFlags: [], frontmostBundleIdentifier: nil))

        settings.toggleEdge(.left)
        settings.toggleEdge(.right)
        XCTAssertTrue(settings.enabledEdges.isEmpty)
        XCTAssertFalse(settings.shouldAllowDrag(modifierFlags: [], frontmostBundleIdentifier: nil))
    }
}
