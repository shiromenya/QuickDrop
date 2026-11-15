import Foundation

extension Bundle {
    /// Resolves QuickDropCore's localized resource bundle reliably whether launched from
    /// `swift run` / `swift test` or packaged inside `QuickDrop.app/Contents/Resources`.
    static let quickDropResources: Bundle = {
        let bundleName = "QuickDrop_QuickDropCore"
        if let resourceURL = Bundle.main.resourceURL,
           let bundle = Bundle(url: resourceURL.appendingPathComponent("\(bundleName).bundle")) {
            return bundle
        }
        if let bundle = Bundle(url: Bundle.main.bundleURL.appendingPathComponent("\(bundleName).bundle")) {
            return bundle
        }
        return .module
    }()
}

public enum L10n {
    public static func tr(_ key: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: .quickDropResources, comment: "")
    }

    public static func fmt(_ key: String, _ args: CVarArg...) -> String {
        let format = tr(key)
        return String(format: format, locale: Locale.current, arguments: args)
    }
}
