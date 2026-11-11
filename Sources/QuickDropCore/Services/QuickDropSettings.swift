import AppKit
import ServiceManagement

public enum GlowColorPreset: String, CaseIterable {
    case airDropBlue
    case mint
    case pureWhite

    public var displayName: String {
        switch self {
        case .airDropBlue: return "AirDrop ブルー"
        case .mint: return "ミントグリーン"
        case .pureWhite: return "ピュアホワイト"
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
        }
    }
}

public enum GlowIntensity: String, CaseIterable {
    case subtle
    case medium
    case vivid

    public var displayName: String {
        switch self {
        case .subtle: return "ひかえめ"
        case .medium: return "標準"
        case .vivid: return "くっきり"
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
        case .narrow: return "狭い (8pt)"
        case .standard: return "標準 (14pt)"
        case .wide: return "広い (24pt)"
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
        case .always:
            return "常に有効（修飾キー不要）"
        case .disableWhileHoldingOption:
            return "Option (⌥) 押下中は一時無効"
        case .requireOptionKey:
            return "Option (⌥) 押下中のみ有効"
        }
    }
}

public struct ExcludedApp: Codable, Equatable, Hashable {
    public let bundleIdentifier: String
    public let displayName: String

    public init(bundleIdentifier: String, displayName: String) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
    }
}

@MainActor
public final class QuickDropSettings {
    private enum Keys {
        static let isEnabled = "QuickDrop.isEnabled"
        static let colorPreset = "QuickDrop.colorPreset"
        static let intensity = "QuickDrop.intensity"
        static let avoidHotCorners = "QuickDrop.avoidHotCorners"
        static let hitThicknessPreset = "QuickDrop.hitThicknessPreset"
        static let enabledEdges = "QuickDrop.enabledEdges"
        static let excludeAdjacentScreenEdges = "QuickDrop.excludeAdjacentScreenEdges"
        static let modifierMode = "QuickDrop.modifierMode"
        static let excludedApps = "QuickDrop.excludedApps"
        static let hapticFeedbackEnabled = "QuickDrop.hapticFeedbackEnabled"
        static let allowWebAndImageDrags = "QuickDrop.allowWebAndImageDrags"
    }

    private let defaults: UserDefaults

    public var onChange: (() -> Void)?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var isEnabled: Bool {
        get { defaults.object(forKey: Keys.isEnabled) as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: Keys.isEnabled)
            onChange?()
        }
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
            onChange?()
        }
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
            onChange?()
        }
    }

    public var avoidHotCorners: Bool {
        get { defaults.object(forKey: Keys.avoidHotCorners) as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: Keys.avoidHotCorners)
            onChange?()
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
            onChange?()
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
            onChange?()
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
            onChange?()
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
            onChange?()
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
            onChange?()
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
            onChange?()
        }
    }

    public var allowWebAndImageDrags: Bool {
        get { defaults.object(forKey: Keys.allowWebAndImageDrags) as? Bool ?? false }
        set {
            defaults.set(newValue, forKey: Keys.allowWebAndImageDrags)
            onChange?()
        }
    }

    public func shouldAllowDrag(
        modifierFlags: NSEvent.ModifierFlags,
        frontmostBundleIdentifier: String?
    ) -> Bool {
        guard isEnabled, !enabledEdges.isEmpty else { return false }
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
    }

    public func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
