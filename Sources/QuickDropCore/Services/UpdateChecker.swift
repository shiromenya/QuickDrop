import AppKit
import Combine
import Foundation

/// Parsed semantic version supporting strings such as `"0.1.0"`, `"v1.2.3"`, and `"v1.2.3-beta.1"`.
public struct AppVersion: Comparable, Equatable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init?(_ rawString: String) {
        let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutPrefix = trimmed.hasPrefix("v") || trimmed.hasPrefix("V")
            ? String(trimmed.dropFirst())
            : trimmed
        let core = withoutPrefix.split(separator: "-", maxSplits: 1).first.map(String.init) ?? withoutPrefix
        let parts = core.split(separator: ".").map(String.init)
        guard !parts.isEmpty, parts.count <= 3 else { return nil }

        var values: [Int] = []
        for part in parts {
            guard let num = Int(part), num >= 0 else { return nil }
            values.append(num)
        }
        while values.count < 3 {
            values.append(0)
        }
        self.major = values[0]
        self.minor = values[1]
        self.patch = values[2]
    }

    public var displayString: String {
        "\(major).\(minor).\(patch)"
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

public struct GitHubReleaseInfo: Equatable, Sendable {
    public let tagName: String
    public let version: AppVersion
    public let htmlURL: URL
    public let releaseName: String
}

public enum UpdateCheckOutcome: Equatable, Sendable {
    case upToDate(current: AppVersion)
    case updateAvailable(current: AppVersion, latest: GitHubReleaseInfo)
}

public enum UpdateCheckerError: LocalizedError {
    case invalidResponse
    case invalidVersion

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return L10n.tr("updates.error.invalid_response")
        case .invalidVersion:
            return L10n.tr("updates.error.invalid_version")
        }
    }
}

/// Checks GitHub Releases for newer versions of QuickDrop without intrusive background popups.
@MainActor
public final class UpdateChecker: ObservableObject {
    nonisolated public static let latestReleaseEndpoint = URL(
        string: "https://api.github.com/repos/shiromenya/QuickDrop/releases/latest"
    )!
    nonisolated public static let releasesPageURL = URL(
        string: "https://github.com/shiromenya/QuickDrop/releases/latest"
    )!

    @Published public private(set) var isChecking = false
    @Published public private(set) var lastOutcome: UpdateCheckOutcome?
    @Published public private(set) var lastErrorMessage: String?

    private let settings: QuickDropSettings
    private let session: URLSession

    public var currentVersionString: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.1.0"
    }

    public init(settings: QuickDropSettings, session: URLSession = .shared) {
        self.settings = settings
        self.session = session
    }

    public func automaticCheckIfDue() {
        guard settings.autoCheckForUpdates, !isChecking else { return }
        let now = Date()
        if let lastCheck = settings.lastUpdateCheckDate,
           now.timeIntervalSince(lastCheck) < 24 * 60 * 60 {
            return
        }
        checkForUpdates(userInitiated: false)
    }

    public func checkForUpdates(userInitiated: Bool) {
        guard !isChecking else { return }
        isChecking = true
        lastErrorMessage = nil

        let endpoint = Self.latestReleaseEndpoint
        let currentVersion = currentVersionString

        Task { [weak self] in
            guard let self else { return }
            defer { self.isChecking = false }

            do {
                var request = URLRequest(url: endpoint)
                request.timeoutInterval = 10
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("QuickDrop/\(currentVersion)", forHTTPHeaderField: "User-Agent")

                let (data, response) = try await self.session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode) else {
                    throw UpdateCheckerError.invalidResponse
                }

                let outcome = try Self.parseLatestRelease(
                    data: data,
                    currentVersionString: currentVersion
                )
                self.settings.lastUpdateCheckDate = Date()
                self.lastOutcome = outcome
                self.lastErrorMessage = nil

                if userInitiated {
                    self.presentUserInitiatedResult(outcome)
                } else if case .updateAvailable(_, let latest) = outcome {
                    ToastHUDPresenter.shared.show(
                        message: L10n.fmt("updates.toast_available", latest.version.displayString),
                        style: .info
                    )
                }
            } catch {
                self.lastErrorMessage = error.localizedDescription
                if userInitiated {
                    self.presentCheckError(error.localizedDescription)
                }
            }
        }
    }

    nonisolated public static func parseLatestRelease(
        data: Data,
        currentVersionString: String
    ) throws -> UpdateCheckOutcome {
        struct Payload: Decodable {
            let tag_name: String
            let html_url: String
            let name: String?
        }

        let decoded = try JSONDecoder().decode(Payload.self, from: data)
        guard let current = AppVersion(currentVersionString),
              let latestVersion = AppVersion(decoded.tag_name),
              let htmlURL = URL(string: decoded.html_url) else {
            throw UpdateCheckerError.invalidVersion
        }

        if latestVersion > current {
            let info = GitHubReleaseInfo(
                tagName: decoded.tag_name,
                version: latestVersion,
                htmlURL: htmlURL,
                releaseName: decoded.name ?? decoded.tag_name
            )
            return .updateAvailable(current: current, latest: info)
        }
        return .upToDate(current: current)
    }

    public func openReleasePage(url: URL = UpdateChecker.releasesPageURL) {
        NSWorkspace.shared.open(url)
    }

    private func presentUserInitiatedResult(_ outcome: UpdateCheckOutcome) {
        NSApp.activateQuickDrop()
        let alert = NSAlert()
        switch outcome {
        case .upToDate(let current):
            alert.messageText = L10n.tr("updates.up_to_date.title")
            alert.informativeText = L10n.fmt("updates.up_to_date.body", current.displayString)
            alert.alertStyle = .informational
            alert.addButton(withTitle: L10n.tr("alert.close"))
            alert.runModal()

        case .updateAvailable(let current, let latest):
            alert.messageText = L10n.fmt("updates.available.title", latest.version.displayString)
            alert.informativeText = L10n.fmt(
                "updates.available.body",
                current.displayString,
                latest.version.displayString
            )
            alert.alertStyle = .informational
            alert.addButton(withTitle: L10n.tr("updates.open_release_page"))
            alert.addButton(withTitle: L10n.tr("alert.close"))
            if alert.runModal() == .alertFirstButtonReturn {
                openReleasePage(url: latest.htmlURL)
            }
        }
    }

    private func presentCheckError(_ reason: String) {
        ToastHUDPresenter.shared.show(
            message: L10n.fmt("updates.toast_error", reason),
            style: .warning
        )
    }
}
