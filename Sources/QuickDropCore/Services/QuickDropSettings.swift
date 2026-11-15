import AppKit
import Combine
import ServiceManagement

public enum GlowColorPreset: String, CaseIterable {
    case airDropBlue
    case mint
    case pureWhite
    case custom

    public var displayName: String {
        switch self {
        case .airDropBlue: return L10n.tr("color.airdrop_blue")
        case .mint: return L10n.tr("color.mint")
        case .pureWhite: return L10n.tr("color.pure_white")
        case .custom: return L10n.tr("color.custom")
        }
    }

    public var primaryColor: NSColor {
        switch self {
        case .airDropBlue:
            return NSColor(calibratedRed: 0.16, green: 0.58, blue: 1.0, alpha: 1.0)
        case .mint:
            return NSColor(calibratedRed: 0.22, green: 0.86, blue: 0.58, alpha: 1.0)
        case .pureWhite:
            return NSColor(calibratedWhite: 0.96, alpha: 1.0)
        case .custom:
            return NSColor(calibratedRed: 0.56, green: 0.38, blue: 1.0, alpha: 1.0)
        }
    }
}

public enum GlowIntensity: String, CaseIterable {
    case subtle
    case medium
    case vivid

    public var displayName: String {
        switch self {
        case .subtle: return L10n.tr("intensity.subtle")
        case .medium: return L10n.tr("intensity.medium")
        case .vivid: return L10n.tr("intensity.vivid")
        }
    }

    public var idleAlpha: CGFloat {
        switch self {
        case .subtle: return 0.24
        case .medium: return 0.36
        case .vivid: return 0.52
        }
    }

    public var hoveredAlpha: CGFloat {
        switch self {
        case .subtle: return 0.72
        case .medium: return 0.88
        case .vivid: return 1.0
        }
    }
}

public enum DropHitThicknessPreset: String, CaseIterable {
    case narrow
    case standard
    case wide

    public var displayName: String {
        switch self {
        case .narrow: return L10n.tr("thickness.narrow")
        case .standard: return L10n.tr("thickness.standard")
        case .wide: return L10n.tr("thickness.wide")
        }
    }

    public var points: CGFloat {
        switch self {
        case .narrow: return 8
        case .standard: return 14
        case .wide: return 24
        }
    }
}

public enum ModifierActivationMode: String, CaseIterable {
    case always
    case disableWhileHoldingOption
    case requireOptionKey

    public var displayName: String {
        switch self {
        case .always: return L10n.tr("modifier.always")
        case .disableWhileHoldingOption: return L10n.tr("modifier.disable_option")
        case .requireOptionKey: return L10n.tr("modifier.require_option")
        }
    }
}

public enum ShareBehavior: String, CaseIterable {
    case airDropDirectly
    case systemSharePicker

    public var displayName: String {
        switch self {
        case .airDropDirectly: return L10n.tr("share_mode.airdrop")
        case .systemSharePicker: return L10n.tr("share_mode.picker")
        }
    }
}

public enum DisplayGlowScope: String, CaseIterable {
    case allDisplays
    case cursorDisplayOnly

    public var displayName: String {
        switch self {
        case .allDisplays: return L10n.tr("display_scope.all")
        case .cursorDisplayOnly: return L10n.tr("display_scope.cursor_only")
        }
    }
}

public enum HoverDelayPreset: String, CaseIterable {
    case immediate
    case short
    case medium

    public var displayName: String {
        switch self {
        case .immediate: return L10n.tr("hover_delay.immediate")
        case .short: return L10n.tr("hover_delay.short")
        case .medium: return L10n.tr("hover_delay.medium")
        }
    }

    public var seconds: TimeInterval {
        switch self {
        case .immediate: return 0
        case .short: return 0.12
        case .medium: return 0.25
        }
    }
}

public enum EdgeAction: String, CaseIterable {
    case useDefault
    case airDropDirectly
    case systemSharePicker

    public var displayName: String {
        switch self {
        case .useDefault: return L10n.tr("edge_action.default")
        case .airDropDirectly: return L10n.tr("share_mode.airdrop")
        case .systemSharePicker: return L10n.tr("share_mode.picker")
        }
    }
}

public enum ZipArchiveBehavior: String, CaseIterable {
    case off
    case whenMultipleOrDirectory
    case alwaysForFiles

    public var displayName: String {
        switch self {
        case .off: return L10n.tr("zip_mode.off")
        case .whenMultipleOrDirectory: return L10n.tr("zip_mode.multi_or_dir")
        case .alwaysForFiles: return L10n.tr("zip_mode.always")
        }
    }
}

public struct ExcludedApp: Codable, Equatable, Hashable, Identifiable {
    public let bundleIdentifier: String
    public let displayName: String

    public var id: String { bundleIdentifier }

    public init(bundleIdentifier: String, displayName: String) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
    }
}

@MainActor
public final class QuickDropSettings: ObservableObject {
    private enum Keys {
        static let isEnabled = "QuickDrop.isEnabled"
        static let snoozedUntil = "QuickDrop.snoozedUntil"
        static let colorPreset = "QuickDrop.colorPreset"
        static let customGlowColorHex = "QuickDrop.customGlowColorHex"
        static let intensity = "QuickDrop.intensity"
        static let avoidHotCorners = "QuickDrop.avoidHotCorners"
        static let hitThicknessPreset = "QuickDrop.hitThicknessPreset"
        static let enabledEdges = "QuickDrop.enabledEdges"
        static let edgeActions = "QuickDrop.edgeActions"
        static let excludeAdjacentScreenEdges = "QuickDrop.excludeAdjacentScreenEdges"
        static let displayGlowScope = "QuickDrop.displayGlowScope"
        static let excludedDisplayIDs = "QuickDrop.excludedDisplayIDs"
        static let modifierMode = "QuickDrop.modifierMode"
        static let shareBehavior = "QuickDrop.shareBehavior"
        static let zipArchiveBehavior = "QuickDrop.zipArchiveBehavior"
        static let hoverDelayPreset = "QuickDrop.hoverDelayPreset"
        static let excludedApps = "QuickDrop.excludedApps"
        static let hapticFeedbackEnabled = "QuickDrop.hapticFeedbackEnabled"
        static let soundFeedbackEnabled = "QuickDrop.soundFeedbackEnabled"
        static let allowWebAndImageDrags = "QuickDrop.allowWebAndImageDrags"
        static let autoCheckForUpdates = "QuickDrop.autoCheckForUpdates"
        static let lastUpdateCheckTimestamp = "QuickDrop.lastUpdateCheckTimestamp"
        static let hasCompletedOnboarding = "QuickDrop.hasCompletedOnboarding"
    }

    private let defaults: UserDefaults
    private var snoozeTimer: Timer?

    public var onChange: (() -> Void)?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        scheduleSnoozeExpirationIfNeeded()
    }

    deinit {
        snoozeTimer?.invalidate()
    }

    public var isEnabled: Bool {
        get { defaults.object(forKey: Keys.isEnabled) as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: Keys.isEnabled)
            if !newValue {
                cancelSnooze(notify: false)
            }
            notifyChanged()
        }
    }

    public var snoozedUntil: Date? {
        let timestamp = defaults.double(forKey: Keys.snoozedUntil)
        guard timestamp > 0 else { return nil }
        let date = Date(timeIntervalSince1970: timestamp)
        if date <= Date() {
            defaults.removeObject(forKey: Keys.snoozedUntil)
            return nil
        }
        return date
    }

    public var isSnoozed: Bool {
        snoozedUntil != nil
    }

    public var remainingSnoozeMinutes: Int? {
        guard let until = snoozedUntil else { return nil }
        let seconds = max(0, until.timeIntervalSinceNow)
        return max(1, Int(ceil(seconds / 60)))
    }

    public var isEffectivelyEnabled: Bool {
        isEnabled && !isSnoozed
    }

    public func snooze(for duration: TimeInterval) {
        guard duration > 0 else { return }
        let until = Date().addingTimeInterval(duration)
        defaults.set(until.timeIntervalSince1970, forKey: Keys.snoozedUntil)
        scheduleSnoozeExpirationIfNeeded()
        notifyChanged()
    }

    public func cancelSnooze() {
        cancelSnooze(notify: true)
    }

    public var colorPreset: GlowColorPreset {
        get {
            guard let raw = defaults.string(forKey: Keys.colorPreset),
                  let preset = GlowColorPreset(rawValue: raw) else {
                return .airDropBlue
            }
            return preset
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.colorPreset)
            notifyChanged()
        }
    }

    public var customGlowColorHex: String {
        get { defaults.string(forKey: Keys.customGlowColorHex) ?? "#8F61FF" }
        set {
            defaults.set(newValue, forKey: Keys.customGlowColorHex)
            notifyChanged()
        }
    }

    public var activeGlowColor: NSColor {
        if colorPreset == .custom {
            return NSColor.quickDropFromHex(customGlowColorHex) ?? GlowColorPreset.custom.primaryColor
        }
        return colorPreset.primaryColor
    }

    public var intensity: GlowIntensity {
        get {
            guard let raw = defaults.string(forKey: Keys.intensity),
                  let value = GlowIntensity(rawValue: raw) else {
                return .subtle
            }
            return value
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.intensity)
            notifyChanged()
        }
    }

    public var avoidHotCorners: Bool {
        get { defaults.object(forKey: Keys.avoidHotCorners) as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: Keys.avoidHotCorners)
            notifyChanged()
        }
    }

    public var cornerInset: CGFloat {
        avoidHotCorners ? 32 : 0
    }

    public var hitThicknessPreset: DropHitThicknessPreset {
        get {
            guard let raw = defaults.string(forKey: Keys.hitThicknessPreset),
                  let value = DropHitThicknessPreset(rawValue: raw) else {
                return .standard
            }
            return value
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.hitThicknessPreset)
            notifyChanged()
        }
    }

    public var enabledEdges: Set<ScreenEdge> {
        get {
            guard let rawList = defaults.stringArray(forKey: Keys.enabledEdges) else {
                return Set(ScreenEdge.allCases)
            }
            return Set(rawList.compactMap(ScreenEdge.init(rawValue:)))
        }
        set {
            defaults.set(newValue.map(\.rawValue).sorted(), forKey: Keys.enabledEdges)
            notifyChanged()
        }
    }

    public func toggleEdge(_ edge: ScreenEdge) {
        var current = enabledEdges
        if current.contains(edge) {
            current.remove(edge)
        } else {
            current.insert(edge)
        }
        enabledEdges = current
    }

    public var excludeAdjacentScreenEdges: Bool {
        get { defaults.object(forKey: Keys.excludeAdjacentScreenEdges) as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: Keys.excludeAdjacentScreenEdges)
            notifyChanged()
        }
    }

    public var modifierMode: ModifierActivationMode {
        get {
            guard let raw = defaults.string(forKey: Keys.modifierMode),
                  let mode = ModifierActivationMode(rawValue: raw) else {
                return .always
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.modifierMode)
            notifyChanged()
        }
    }

    public var shareBehavior: ShareBehavior {
        get {
            guard let raw = defaults.string(forKey: Keys.shareBehavior),
                  let behavior = ShareBehavior(rawValue: raw) else {
                return .airDropDirectly
            }
            return behavior
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.shareBehavior)
            notifyChanged()
        }
    }

    public var excludedApps: [ExcludedApp] {
        get {
            guard let data = defaults.data(forKey: Keys.excludedApps),
                  let decoded = try? JSONDecoder().decode([ExcludedApp].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                defaults.set(encoded, forKey: Keys.excludedApps)
            }
            notifyChanged()
        }
    }

    public func isAppExcluded(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return excludedApps.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    public func toggleExcludedApp(bundleIdentifier: String, displayName: String) {
        var list = excludedApps
        if let index = list.firstIndex(where: { $0.bundleIdentifier == bundleIdentifier }) {
            list.remove(at: index)
        } else {
            list.append(ExcludedApp(bundleIdentifier: bundleIdentifier, displayName: displayName))
            list.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
        excludedApps = list
    }

    public func removeExcludedApp(bundleIdentifier: String) {
        var list = excludedApps
        list.removeAll { $0.bundleIdentifier == bundleIdentifier }
        excludedApps = list
    }

    public func clearExcludedApps() {
        excludedApps = []
    }

    public var hapticFeedbackEnabled: Bool {
        get { defaults.object(forKey: Keys.hapticFeedbackEnabled) as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: Keys.hapticFeedbackEnabled)
            notifyChanged()
        }
    }

    public var soundFeedbackEnabled: Bool {
        get { defaults.object(forKey: Keys.soundFeedbackEnabled) as? Bool ?? false }
        set {
            defaults.set(newValue, forKey: Keys.soundFeedbackEnabled)
            notifyChanged()
        }
    }

    public var hoverDelayPreset: HoverDelayPreset {
        get {
            guard let raw = defaults.string(forKey: Keys.hoverDelayPreset),
                  let preset = HoverDelayPreset(rawValue: raw) else {
                return .immediate
            }
            return preset
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.hoverDelayPreset)
            notifyChanged()
        }
    }

    public var displayGlowScope: DisplayGlowScope {
        get {
            guard let raw = defaults.string(forKey: Keys.displayGlowScope),
                  let scope = DisplayGlowScope(rawValue: raw) else {
                return .allDisplays
            }
            return scope
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.displayGlowScope)
            notifyChanged()
        }
    }

    public var excludedDisplayIDs: Set<UInt32> {
        get {
            let rawNumbers = defaults.array(forKey: Keys.excludedDisplayIDs) as? [NSNumber] ?? []
            return Set(rawNumbers.map(\.uint32Value))
        }
        set {
            let sorted = newValue.sorted().map { NSNumber(value: $0) }
            defaults.set(sorted, forKey: Keys.excludedDisplayIDs)
            notifyChanged()
        }
    }

    public func isDisplayEnabled(_ displayID: UInt32?) -> Bool {
        guard let displayID else { return true }
        return !excludedDisplayIDs.contains(displayID)
    }

    public func toggleExcludedDisplay(_ displayID: UInt32) {
        var set = excludedDisplayIDs
        if set.contains(displayID) {
            set.remove(displayID)
        } else {
            set.insert(displayID)
        }
        excludedDisplayIDs = set
    }

    public func clearExcludedDisplays() {
        excludedDisplayIDs = []
    }

    public var autoCheckForUpdates: Bool {
        get { defaults.object(forKey: Keys.autoCheckForUpdates) as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: Keys.autoCheckForUpdates)
            objectWillChange.send()
        }
    }

    public var lastUpdateCheckDate: Date? {
        get {
            let timestamp = defaults.double(forKey: Keys.lastUpdateCheckTimestamp)
            return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
        }
        set {
            if let newValue {
                defaults.set(newValue.timeIntervalSince1970, forKey: Keys.lastUpdateCheckTimestamp)
            } else {
                defaults.removeObject(forKey: Keys.lastUpdateCheckTimestamp)
            }
        }
    }

    public var hasCompletedOnboarding: Bool {
        get { defaults.object(forKey: Keys.hasCompletedOnboarding) as? Bool ?? false }
        set {
            defaults.set(newValue, forKey: Keys.hasCompletedOnboarding)
            objectWillChange.send()
        }
    }

    public func notifyDisplayConfigurationChanged() {
        objectWillChange.send()
    }

    public var allowWebAndImageDrags: Bool {
        get { defaults.object(forKey: Keys.allowWebAndImageDrags) as? Bool ?? false }
        set {
            defaults.set(newValue, forKey: Keys.allowWebAndImageDrags)
            notifyChanged()
        }
    }

    public var zipArchiveBehavior: ZipArchiveBehavior {
        get {
            guard let raw = defaults.string(forKey: Keys.zipArchiveBehavior),
                  let mode = ZipArchiveBehavior(rawValue: raw) else {
                return .off
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.zipArchiveBehavior)
            notifyChanged()
        }
    }

    public func edgeActionOverride(for edge: ScreenEdge) -> EdgeAction {
        guard let dict = defaults.dictionary(forKey: Keys.edgeActions) as? [String: String],
              let raw = dict[edge.rawValue],
              let action = EdgeAction(rawValue: raw) else {
            return .useDefault
        }
        return action
    }

    public func setEdgeAction(_ action: EdgeAction, for edge: ScreenEdge) {
        var dict = defaults.dictionary(forKey: Keys.edgeActions) as? [String: String] ?? [:]
        if action == .useDefault {
            dict.removeValue(forKey: edge.rawValue)
        } else {
            dict[edge.rawValue] = action.rawValue
        }
        defaults.set(dict, forKey: Keys.edgeActions)
        notifyChanged()
    }

    public func resolvedShareBehavior(for edge: ScreenEdge) -> ShareBehavior {
        switch edgeActionOverride(for: edge) {
        case .useDefault:
            return shareBehavior
        case .airDropDirectly:
            return .airDropDirectly
        case .systemSharePicker:
            return .systemSharePicker
        }
    }

    public func shouldAllowDrag(
        modifierFlags: NSEvent.ModifierFlags,
        frontmostBundleIdentifier: String?
    ) -> Bool {
        guard isEffectivelyEnabled, !enabledEdges.isEmpty else { return false }
        guard !isAppExcluded(bundleIdentifier: frontmostBundleIdentifier) else { return false }

        let optionPressed = modifierFlags.contains(.option)
        switch modifierMode {
        case .always:
            return true
        case .disableWhileHoldingOption:
            return !optionPressed
        case .requireOptionKey:
            return optionPressed
        }
    }

    // MARK: - Launch at Login

    public var canConfigureLaunchAtLogin: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    public var launchAtLoginStatus: SMAppService.Status {
        guard canConfigureLaunchAtLogin else { return .notRegistered }
        return SMAppService.mainApp.status
    }

    public var isLaunchAtLoginEnabled: Bool {
        launchAtLoginStatus == .enabled
    }

    public var requiresLaunchAtLoginApproval: Bool {
        launchAtLoginStatus == .requiresApproval
    }

    public func setLaunchAtLogin(_ enabled: Bool) throws {
        guard canConfigureLaunchAtLogin else { return }
        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else if SMAppService.mainApp.status == .enabled
                    || SMAppService.mainApp.status == .requiresApproval {
            try SMAppService.mainApp.unregister()
        }
        notifyChanged()
    }

    public func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    // MARK: - Private

    private func notifyChanged() {
        objectWillChange.send()
        onChange?()
    }

    private func cancelSnooze(notify: Bool) {
        snoozeTimer?.invalidate()
        snoozeTimer = nil
        defaults.removeObject(forKey: Keys.snoozedUntil)
        if notify {
            notifyChanged()
        }
    }

    private func scheduleSnoozeExpirationIfNeeded() {
        snoozeTimer?.invalidate()
        snoozeTimer = nil

        guard let until = snoozedUntil else { return }
        let remaining = until.timeIntervalSinceNow
        guard remaining > 0 else {
            defaults.removeObject(forKey: Keys.snoozedUntil)
            return
        }

        snoozeTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.cancelSnooze(notify: true)
            }
        }
    }
}

extension NSColor {
    public static func quickDropFromHex(_ hexString: String) -> NSColor? {
        let cleaned = hexString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let rgb = UInt32(cleaned, radix: 16) else {
            return nil
        }
        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }

    public var quickDropHexString: String {
        guard let srgb = usingColorSpace(.sRGB) else { return "#8F61FF" }
        let r = Int(round(min(max(srgb.redComponent, 0), 1) * 255))
        let g = Int(round(min(max(srgb.greenComponent, 0), 1) * 255))
        let b = Int(round(min(max(srgb.blueComponent, 0), 1) * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
