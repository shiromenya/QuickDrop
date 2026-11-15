import Foundation

public enum ZipArchiverError: LocalizedError {
    case compressionFailed(Int32)

    public var errorDescription: String? {
        switch self {
        case .compressionFailed(let status):
            return L10n.fmt("zip.error.failed", status)
        }
    }
}

public struct ZipArchiveResult: Sendable {
    public let zipURL: URL
    public let temporaryCleanupURLs: [URL]
}

/// Non-destructively packages files or directories into a temporary `.zip` archive via `/usr/bin/ditto`
/// so original items remain untouched at their source locations.
public enum ZipArchiver {
    public static func shouldArchive(
        urls: [URL],
        behavior: ZipArchiveBehavior,
        shiftPressed: Bool,
        fileManager: FileManager = .default
    ) -> Bool {
        guard !urls.isEmpty else { return false }
        if shiftPressed {
            return true
        }
        switch behavior {
        case .off:
            return false
        case .alwaysForFiles:
            return true
        case .whenMultipleOrDirectory:
            if urls.count > 1 { return true }
            var isDirectory: ObjCBool = false
            if let first = urls.first,
               fileManager.fileExists(atPath: first.path, isDirectory: &isDirectory) {
                return isDirectory.boolValue
            }
            return false
        }
    }

    public static func archive(urls: [URL]) async throws -> ZipArchiveResult {
        try await Task.detached(priority: .userInitiated) {
            try createArchiveSynchronously(urls: urls)
        }.value
    }

    private static func createArchiveSynchronously(urls: [URL]) throws -> ZipArchiveResult {
        let fm = FileManager.default
        let workDir = fm.temporaryDirectory
            .appendingPathComponent("QuickDrop-Zip-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try fm.createDirectory(at: workDir, withIntermediateDirectories: true)

        let archiveName = defaultArchiveName(for: urls)
        let zipURL = workDir.appendingPathComponent(archiveName)

        if urls.count == 1, let singleURL = urls.first {
            try runDitto(sourcePath: singleURL.path, destinationZipPath: zipURL.path, keepParent: true)
            return ZipArchiveResult(zipURL: zipURL, temporaryCleanupURLs: [workDir])
        }

        let stagingDir = workDir.appendingPathComponent("Items", isDirectory: true)
        try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        var usedNames: Set<String> = []
        for url in urls {
            let uniqueName = uniqueFileName(for: url.lastPathComponent, usedNames: &usedNames)
            let targetURL = stagingDir.appendingPathComponent(uniqueName)
            // Prefer hard-linking (instant & zero extra disk space on same volume); fall back to copy.
            do {
                try fm.linkItem(at: url, to: targetURL)
            } catch {
                try fm.copyItem(at: url, to: targetURL)
            }
        }

        try runDitto(sourcePath: stagingDir.path, destinationZipPath: zipURL.path, keepParent: false)
        return ZipArchiveResult(zipURL: zipURL, temporaryCleanupURLs: [workDir])
    }

    private static func defaultArchiveName(for urls: [URL]) -> String {
        if urls.count == 1, let first = urls.first {
            let base = first.deletingPathExtension().lastPathComponent
            let cleanBase = base.isEmpty ? "Archive" : base
            return "\(cleanBase).zip"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "QuickDrop-\(formatter.string(from: Date())).zip"
    }

    private static func uniqueFileName(for candidate: String, usedNames: inout Set<String>) -> String {
        let baseName = candidate.isEmpty ? "Item" : candidate
        if usedNames.insert(baseName).inserted {
            return baseName
        }
        let nsName = baseName as NSString
        let stem = nsName.deletingPathExtension
        let ext = nsName.pathExtension
        var counter = 2
        while true {
            let next = ext.isEmpty ? "\(stem) (\(counter))" : "\(stem) (\(counter)).\(ext)"
            if usedNames.insert(next).inserted {
                return next
            }
            counter += 1
        }
    }

    private static func runDitto(sourcePath: String, destinationZipPath: String, keepParent: Bool) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        var args = ["-c", "-k", "--sequesterRsrc"]
        if keepParent {
            args.append("--keepParent")
        }
        args.append(sourcePath)
        args.append(destinationZipPath)
        process.arguments = args

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw ZipArchiverError.compressionFailed(process.terminationStatus)
        }
    }
}
