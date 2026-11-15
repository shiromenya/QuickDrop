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
        XCTAssertEqual(settings.shareBehavior, .airDropDirectly)
        XCTAssertTrue(settings.isEffectivelyEnabled)
        XCTAssertFalse(settings.isSnoozed)
        XCTAssertNil(settings.remainingSnoozeMinutes)
    }

    @MainActor
    func testShareBehaviorPersistence() async {
        let suiteName = "QuickDropTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = QuickDropSettings(defaults: defaults)
        settings.shareBehavior = .systemSharePicker

        let reloaded = QuickDropSettings(defaults: defaults)
        XCTAssertEqual(reloaded.shareBehavior, .systemSharePicker)
    }

    @MainActor
    func testSnoozeDisablesActivationAndCancelsCleanly() async {
        let suiteName = "QuickDropTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = QuickDropSettings(defaults: defaults)
        settings.snooze(for: 30 * 60)

        XCTAssertTrue(settings.isSnoozed)
        XCTAssertFalse(settings.isEffectivelyEnabled)
        XCTAssertNotNil(settings.remainingSnoozeMinutes)
        XCTAssertLessThanOrEqual(settings.remainingSnoozeMinutes ?? 99, 30)
        XCTAssertFalse(settings.shouldAllowDrag(modifierFlags: [], frontmostBundleIdentifier: "com.apple.finder"))

        settings.cancelSnooze()

        XCTAssertFalse(settings.isSnoozed)
        XCTAssertTrue(settings.isEffectivelyEnabled)
        XCTAssertNil(settings.remainingSnoozeMinutes)
        XCTAssertTrue(settings.shouldAllowDrag(modifierFlags: [], frontmostBundleIdentifier: "com.apple.finder"))

        settings.snooze(for: 60 * 60)
        XCTAssertTrue(settings.isSnoozed)
        settings.isEnabled = false
        XCTAssertFalse(settings.isSnoozed)

        defaults.set(Date().addingTimeInterval(-60).timeIntervalSince1970, forKey: "QuickDrop.snoozedUntil")
        XCTAssertFalse(settings.isSnoozed)
        XCTAssertNil(settings.snoozedUntil)
    }

    func testLocalizationResolvesKnownKeys() {
        let enable = L10n.tr("menu.enable")
        let settingsTitle = L10n.tr("settings.window_title")
        let remaining = L10n.fmt("menu.snoozed_resume", 15)
        let cursorOnly = L10n.tr("display_scope.cursor_only")
        let onboarding = L10n.tr("onboarding.get_started")

        XCTAssertFalse(enable.isEmpty)
        XCTAssertNotEqual(enable, "menu.enable")
        XCTAssertFalse(settingsTitle.isEmpty)
        XCTAssertNotEqual(settingsTitle, "settings.window_title")
        XCTAssertTrue(remaining.contains("15"))
        XCTAssertNotEqual(remaining, "menu.snoozed_resume")
        XCTAssertNotEqual(cursorOnly, "display_scope.cursor_only")
        XCTAssertNotEqual(onboarding, "onboarding.get_started")
    }

    @MainActor
    func testDisplayScopeExcludedDisplaysHoverDelayAndFeedbackSettings() async {
        let suiteName = "QuickDropTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = QuickDropSettings(defaults: defaults)
        XCTAssertEqual(settings.displayGlowScope, .allDisplays)
        XCTAssertTrue(settings.excludedDisplayIDs.isEmpty)
        XCTAssertTrue(settings.isDisplayEnabled(42))
        XCTAssertEqual(settings.hoverDelayPreset, .immediate)
        XCTAssertEqual(settings.hoverDelayPreset.seconds, 0, accuracy: 0.0001)
        XCTAssertFalse(settings.soundFeedbackEnabled)
        XCTAssertTrue(settings.autoCheckForUpdates)
        XCTAssertFalse(settings.hasCompletedOnboarding)

        settings.displayGlowScope = .cursorDisplayOnly
        settings.toggleExcludedDisplay(42)
        settings.hoverDelayPreset = .short
        settings.soundFeedbackEnabled = true
        settings.autoCheckForUpdates = false
        settings.hasCompletedOnboarding = true

        XCTAssertFalse(settings.isDisplayEnabled(42))
        XCTAssertEqual(settings.hoverDelayPreset.seconds, 0.12, accuracy: 0.0001)

        let reloaded = QuickDropSettings(defaults: defaults)
        XCTAssertEqual(reloaded.displayGlowScope, .cursorDisplayOnly)
        XCTAssertEqual(reloaded.excludedDisplayIDs, [42])
        XCTAssertEqual(reloaded.hoverDelayPreset, .short)
        XCTAssertTrue(reloaded.soundFeedbackEnabled)
        XCTAssertFalse(reloaded.autoCheckForUpdates)
        XCTAssertTrue(reloaded.hasCompletedOnboarding)

        reloaded.clearExcludedDisplays()
        XCTAssertTrue(reloaded.isDisplayEnabled(42))
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

    @MainActor
    func testCustomColorEdgeActionsAndZipBehaviorSettings() async {
        let suiteName = "QuickDropTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = QuickDropSettings(defaults: defaults)
        XCTAssertEqual(settings.zipArchiveBehavior, .off)
        XCTAssertEqual(settings.edgeActionOverride(for: .left), .useDefault)
        XCTAssertEqual(settings.resolvedShareBehavior(for: .left), .airDropDirectly)

        settings.shareBehavior = .airDropDirectly
        settings.setEdgeAction(.systemSharePicker, for: .left)
        settings.zipArchiveBehavior = .whenMultipleOrDirectory
        settings.colorPreset = .custom
        settings.customGlowColorHex = "#FF6B35"

        XCTAssertEqual(settings.resolvedShareBehavior(for: .left), .systemSharePicker)
        XCTAssertEqual(settings.resolvedShareBehavior(for: .top), .airDropDirectly)
        XCTAssertEqual(settings.activeGlowColor.quickDropHexString, "#FF6B35")

        let reloaded = QuickDropSettings(defaults: defaults)
        XCTAssertEqual(reloaded.zipArchiveBehavior, .whenMultipleOrDirectory)
        XCTAssertEqual(reloaded.edgeActionOverride(for: .left), .systemSharePicker)
        XCTAssertEqual(reloaded.colorPreset, .custom)
        XCTAssertEqual(reloaded.customGlowColorHex, "#FF6B35")
    }
}
