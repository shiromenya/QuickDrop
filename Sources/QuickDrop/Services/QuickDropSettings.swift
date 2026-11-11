import AppKit
import ServiceManagement

enum GlowColorPreset: String, CaseIterable {
    case airDropBlue
    case mint
    case pureWhite

    var displayName: String {
        switch self {
        case .airDropBlue: return "AirDrop ブルー"
        case .mint: return "ミントグリーン"
        case .pureWhite: return "ピュアホワイト"
        }
    }

    var primaryColor: NSColor {
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

enum GlowIntensity: String, CaseIterable {
    case subtle
    case medium
    case vivid

    var displayName: String {
        switch self {
        case .subtle: return "ひかえめ"
        case .medium: return "標準"
        case .vivid: return "くっきり"
        }
    }

    var idleAlpha: CGFloat {
        switch self {
        case .subtle: return 0.24
        case .medium: return 0.36
        case .vivid: return 0.52
        }
    }

    var hoveredAlpha: CGFloat {
        switch self {
        case .subtle: return 0.72
        case .medium: return 0.88
        case .vivid: return 1.0
        }
    }
}

@MainActor
final class QuickDropSettings {
    private enum Keys {
        static let isEnabled = "QuickDrop.isEnabled"
        static let colorPreset = "QuickDrop.colorPreset"
        static let intensity = "QuickDrop.intensity"
        static let avoidHotCorners = "QuickDrop.avoidHotCorners"
    }

    private let defaults: UserDefaults

    var onChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        get {
            defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        }
        set {
            defaults.set(newValue, forKey: Keys.isEnabled)
            onChange?()
        }
    }

    var colorPreset: GlowColorPreset {
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

    var intensity: GlowIntensity {
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

    var avoidHotCorners: Bool {
        get {
            defaults.object(forKey: Keys.avoidHotCorners) as? Bool ?? true
        }
        set {
            defaults.set(newValue, forKey: Keys.avoidHotCorners)
            onChange?()
        }
    }

    var cornerInset: CGFloat {
        avoidHotCorners ? 32 : 0
    }

    var canConfigureLaunchAtLogin: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    var launchAtLoginStatus: SMAppService.Status {
        guard canConfigureLaunchAtLogin else { return .notRegistered }
        return SMAppService.mainApp.status
    }

    var isLaunchAtLoginEnabled: Bool {
        launchAtLoginStatus == .enabled
    }

    var requiresLaunchAtLoginApproval: Bool {
        launchAtLoginStatus == .requiresApproval
    }

    func setLaunchAtLogin(_ enabled: Bool) throws {
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

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
