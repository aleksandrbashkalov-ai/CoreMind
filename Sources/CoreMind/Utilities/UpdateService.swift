import Foundation
import AppKit
import UserNotifications

// MARK: - GitHub Release models

private struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL?
    let publishedAt: String?
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case assets
    }
}

private struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadURL: URL
    let contentType: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case contentType = "content_type"
        case size
    }
}

// MARK: - Error types

enum UpdateError: LocalizedError {
    case noReleaseFound
    case noDownloadAsset
    case downloadFailed(String)
    case installationFailed(String)
    case networkError(String)
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .noReleaseFound: return "No releases found on GitHub"
        case .noDownloadAsset: return "No downloadable .app.zip asset found in the latest release"
        case .downloadFailed(let detail): return "Download failed: \(detail)"
        case .installationFailed(let detail): return "Installation failed: \(detail)"
        case .networkError(let detail): return "Network error: \(detail)"
        case .rateLimited: return "GitHub API rate limit exceeded. Try again later."
        }
    }
}

// MARK: - Version helpers

private func parseVersion(_ version: String) -> [Int] {
    version
        .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        .split(separator: ".")
        .compactMap { Int($0) }
}

private func isVersionNewer(_ remote: String, than local: String) -> Bool {
    let localParts = parseVersion(local)
    let remoteParts = parseVersion(remote)

    guard localParts.count >= 2, remoteParts.count >= 2 else {
        return remote.compare(local, options: .numeric) == .orderedDescending
    }

    let paddedLocal = localParts + [0, 0, 0]
    let paddedRemote = remoteParts + [0, 0, 0]

    for i in 0..<3 {
        if paddedRemote[i] != paddedLocal[i] {
            return paddedRemote[i] > paddedLocal[i]
        }
    }
    return false
}

// MARK: - Update Service

@MainActor
final class UpdateService: ObservableObject {
    static let shared = UpdateService()

    // MARK: - Configuration
    let repo: String
    let currentVersion: String
    let appBundleID: String
    let appName: String

    // MARK: - Published State
    @Published private(set) var isChecking = false
    @Published private(set) var isDownloading = false
    @Published private(set) var downloadProgress: Double = 0
    @Published private(set) var latestVersion: String?
    @Published private(set) var updateAvailable = false
    @Published private(set) var lastCheckDate: Date?
    @Published var lastError: String?
    @Published private(set) var releaseNotes: String?
    @Published private(set) var lastCheckResult: String?

    // MARK: - Private
    private var latestRelease: GitHubRelease?
    private var checkTask: Task<Void, Never>?
    private let defaultsCheckKey: String

    init(
        repo: String = Constants.githubRepo,
        currentVersion: String = Constants.appVersion,
        appBundleID: String = Constants.appBundleID,
        appName: String = Constants.appName
    ) {
        self.repo = repo
        self.currentVersion = currentVersion
        self.appBundleID = appBundleID
        self.appName = appName
        self.defaultsCheckKey = "lastUpdateCheck_\(appBundleID)"
        self.lastCheckDate = UserDefaults.standard.object(forKey: defaultsCheckKey) as? Date
    }

    // MARK: - Public API

    /// Check for updates. Skips if already checked within 24 hours.
    func checkForUpdates() async {
        guard !isChecking else { return }
        checkTask?.cancel()
        checkTask = Task { [weak self] in
            await self?.performCheck(force: false)
        }
        _ = await checkTask?.value
    }

    /// Force an immediate check, ignoring the daily interval.
    func forceCheck() async {
        guard !isChecking else { return }
        checkTask?.cancel()
        checkTask = Task { [weak self] in
            await self?.performCheck(force: true)
        }
        _ = await checkTask?.value
    }

    /// Returns `true` if more than 24 hours since last check.
    nonisolated func shouldCheckToday() -> Bool {
        guard let lastDate = UserDefaults.standard.object(forKey: defaultsCheckKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastDate) > 86400
    }

    /// Download and install the latest release.
    func downloadAndInstall() async throws {
        guard let release = latestRelease else {
            throw UpdateError.noReleaseFound
        }

        let zipAsset = release.assets.first(where: { $0.name.hasSuffix(".app.zip") })
            ?? release.assets.first(where: { $0.name.hasSuffix(".zip") })
        guard let asset = zipAsset else {
            throw UpdateError.noDownloadAsset
        }

        isDownloading = true
        downloadProgress = 0
        lastError = nil

        defer {
            isDownloading = false
            downloadProgress = 0
        }

        // Temp directory
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(appName)Update-\(UUID().uuidString)")
        try? FileManager.default.removeItem(at: tempDir)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Download
        let zipURL = tempDir.appendingPathComponent(asset.name)
        Log.info("Downloading update from \(asset.browserDownloadURL.absoluteString)")
        try await downloadFile(from: asset.browserDownloadURL, to: zipURL)
        Log.info("Downloaded \(asset.name) (\(asset.size) bytes)")

        // Unzip
        let unzipDir = tempDir.appendingPathComponent("Extracted")
        try FileManager.default.createDirectory(at: unzipDir, withIntermediateDirectories: true)
        try await unzipFile(at: zipURL, to: unzipDir)

        // Find the .app bundle
        guard let appBundle = findAppBundle(in: unzipDir) else {
            throw UpdateError.installationFailed("Could not find .app bundle in the downloaded archive")
        }

        let currentAppURL = Bundle.main.bundleURL
        Log.info("Current app: \(currentAppURL.path), New app: \(appBundle.path)")
        try scheduleInstallation(newApp: appBundle, currentApp: currentAppURL)
    }

    /// Open the GitHub releases page in the browser.
    func openReleasePage() {
        let urlString = "https://github.com/\(repo)/releases"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Private: Check

    private func performCheck(force: Bool) async {
        isChecking = true
        lastError = nil

        defer { isChecking = false }

        if !force && !shouldCheckToday() {
            lastCheckResult = "Already checked today"
            Log.info("Update check skipped — already checked today")
            return
        }

        do {
            let release = try await fetchLatestRelease()

            guard !Task.isCancelled else { return }

            let version = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            latestVersion = version
            latestRelease = release
            releaseNotes = release.body

            if isVersionNewer(version, than: currentVersion) {
                updateAvailable = true
                lastCheckResult = "Version \(version) available"
                Log.info("Update available: \(version) (current: \(currentVersion))")
                postUpdateNotification(version: version, release: release)
            } else {
                updateAvailable = false
                lastCheckResult = "You're up to date (v\(currentVersion))"
                Log.info("No update available. Latest: \(version), current: \(currentVersion)")
            }

            lastCheckDate = Date()
            UserDefaults.standard.set(lastCheckDate, forKey: defaultsCheckKey)
        } catch {
            if let updateErr = error as? UpdateError {
                lastError = updateErr.localizedDescription
                lastCheckResult = "Check failed: \(updateErr.localizedDescription)"
            } else {
                lastError = error.localizedDescription
                lastCheckResult = "Check failed: \(error.localizedDescription)"
            }
            Log.warning("Update check failed: \(lastError ?? "?")")
        }
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        let urlString = "https://api.github.com/repos/\(repo)/releases/latest"
        guard let url = URL(string: urlString) else {
            throw UpdateError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("\(appName)/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UpdateError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateError.networkError("Invalid server response")
        }

        switch httpResponse.statusCode {
        case 200: break
        case 403 where httpResponse.allHeaderFields["X-RateLimit-Remaining"] as? String == "0":
            throw UpdateError.rateLimited
        case 403:
            throw UpdateError.networkError("Access denied (HTTP 403)")
        case 404:
            throw UpdateError.noReleaseFound
        default:
            throw UpdateError.networkError("HTTP \(httpResponse.statusCode)")
        }

        do {
            return try JSONDecoder().decode(GitHubRelease.self, from: data)
        } catch {
            throw UpdateError.networkError("Failed to parse release: \(error.localizedDescription)")
        }
    }

    // MARK: - Private: Download

    private func downloadFile(from url: URL, to destination: URL) async throws {
        let (tempURL, response) = try await URLSession.shared.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateError.downloadFailed("Server returned error")
        }

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: tempURL, to: destination)
    }

    // MARK: - Private: Unzip

    private func unzipFile(at source: URL, to destination: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", source.path, destination.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: errData, encoding: .utf8) ?? "Unknown error"
            throw UpdateError.installationFailed("Unzip failed: \(msg)")
        }
    }

    // MARK: - Private: Find .app

    private func findAppBundle(in directory: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "app" {
            return fileURL
        }
        return nil
    }

    // MARK: - Private: Install

    private func scheduleInstallation(newApp: URL, currentApp: URL) throws {
        let scriptDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(appName)Updater-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scriptDir, withIntermediateDirectories: true)

        let scriptPath = scriptDir.appendingPathComponent("updater.sh")
        let newAppParent = newApp.deletingLastPathComponent().deletingLastPathComponent()

        let script = """
        #!/bin/bash
        sleep 3
        rm -rf "\(currentApp.path)"
        ditto "\(newApp.path)" "\(currentApp.path)"
        rm -rf "\(newAppParent.path)"
        rm -rf "\(scriptDir.path)"
        open "\(currentApp.path)"
        exit 0
        """

        try script.write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: scriptPath.path
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath.path]

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin"
        process.environment = env

        try process.run()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - Notification

    private func postUpdateNotification(version: String, release: GitHubRelease) {
        let content = UNMutableNotificationContent()
        content.title = "\(appName) Update Available"
        content.subtitle = "Version \(version)"
        if let body = release.body?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) {
            content.body = String(body.prefix(150))
        } else {
            content.body = "A new version is ready to install."
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(appBundleID).update.\(version)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
