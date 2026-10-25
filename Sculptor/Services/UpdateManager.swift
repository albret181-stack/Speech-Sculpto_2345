import Foundation
import AppKit
import Combine
import CryptoKit

/// Public GitHub Releases updater. No GitHub CLI or login required.
/// Experimental updater: user must explicitly approve installation.
@MainActor
final class UpdateManager: ObservableObject {
    struct Asset: Decodable, Sendable {
        let name: String
        let browserDownloadUrl: URL
    }
    struct Release: Decodable, Sendable {
        let tagName: String
        let name: String
        let body: String?
        let assets: [Asset]
        func asset(_ name: String) -> Asset? { assets.first { $0.name == name } }
    }

    static let repo = "albret181-stack/Speech-Sculpto_2345"
    static let zipName = "SpeechSculptor-macOS-development.zip"
    static let digestName = "SHA256SUMS.txt"
    static let apiURL = URL(string: "https://api.github.com/repos/albret181-stack/Speech-Sculpto_2345/releases/latest")!

    @Published var release: Release?
    @Published var checking = false
    @Published var installing = false
    @Published var statusMessage: String?
    @Published var lastChecked: Date?
    @Published var autoCheck = UserDefaults.standard.object(forKey: "updatesAutoCheck") as? Bool ?? true {
        didSet { UserDefaults.standard.set(autoCheck, forKey: "updatesAutoCheck") }
    }

    var current: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0" }
    var hasUpdate: Bool { release != nil }
    var canInstall: Bool {
        guard let release else { return false }
        return release.asset(Self.zipName) != nil && release.asset(Self.digestName) != nil
    }

    func check(silent: Bool = false) async {
        guard !checking && !installing else { return }
        checking = true
        defer { checking = false; lastChecked = Date() }
        do {
            let item = try await PublicReleases.latest()
            let remote = item.tagName.replacingOccurrences(of: "v", with: "", options: [.anchored])
            release = Self.isNewer(remote, than: current) ? item : nil
            if !silent {
                statusMessage = release == nil ? "Обновлений нет. Установлена версия \(current)." : "Доступна версия \(item.tagName)."
            }
        } catch PublicReleases.Error.noReleases {
            release = nil
            if !silent { statusMessage = "В GitHub ещё нет опубликованных релизов. Обновление появится после первого выпуска." }
        } catch {
            if !silent { statusMessage = "Не удалось проверить обновления: \(error.localizedDescription)" }
        }
    }

    func install() async {
        guard let release, canInstall, !installing else {
            statusMessage = "Релиз не содержит установочного ZIP и контрольной суммы."
            return
        }
        installing = true
        defer { installing = false }
        do {
            let candidate = try await PublicReleases.fetchVerifiedApp(release)
            let target = Bundle.main.bundleURL
            guard let info = Bundle(url: candidate),
                  info.bundleIdentifier == Bundle.main.bundleIdentifier,
                  let version = info.infoDictionary?["CFBundleShortVersionString"] as? String,
                  version == release.tagName.replacingOccurrences(of: "v", with: "", options: [.anchored])
            else { throw PublicReleases.Error.invalidApp }

            guard target.pathExtension == "app",
                  FileManager.default.isWritableFile(atPath: target.deletingLastPathComponent().path)
            else {
                NSWorkspace.shared.activateFileViewerSelecting([candidate])
                statusMessage = "Обновление скачано и проверено. Автоматическая замена недоступна для текущего расположения программы. Открываю файл в Finder."
                return
            }
            // Do not install without explicit user action.
            try Self.launchReplacement(stage: candidate, installed: target)
            NSApp.terminate(nil)
        } catch {
            statusMessage = "Не удалось установить обновление: \(error.localizedDescription)"
        }
    }

    private static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").compactMap { Int($0) }
        let b = current.split(separator: ".").compactMap { Int($0) }
        guard a.count == 3 && b.count == 3 else { return false }
        for index in 0..<3 {
            if a[index] != b[index] { return a[index] > b[index] }
        }
        return false
    }

    private static func launchReplacement(stage: URL, installed: URL) throws {
        // Wait for the original app to exit, keep one backup, and restart.
        let bash = #"""
        set -euo pipefail
        NEW="$1"; OLD="$2"; PID="$3"
        for i in $(seq 1 80); do
          if ! kill -0 "$PID" 2>/dev/null; then break; fi
          sleep 0.5
        done
        if kill -0 "$PID" 2>/dev/null; then exit 1; fi
        BACKUP="$OLD.previous"
        [ ! -e "$BACKUP" ] || rm -rf "$BACKUP"
        mv "$OLD" "$BACKUP"
        if mv "$NEW" "$OLD"; then open "$OLD"; else mv "$BACKUP" "$OLD"; exit 1; fi
        """#
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/bash")
        helper.arguments = ["-c", bash, "sculptor-update", stage.path, installed.path, String(ProcessInfo.processInfo.processIdentifier)]
        helper.standardOutput = FileHandle.nullDevice
        helper.standardError = FileHandle.nullDevice
        try helper.run()
    }
}

private enum PublicReleases {
    enum Error: LocalizedError {
        case noReleases, missingAssets, badChecksum, invalidApp, http(Int), badVersionTag
        var errorDescription: String? {
            switch self {
            case .noReleases: return "В GitHub пока нет релизов."
            case .missingAssets: return "В релизе отсутствует ZIP или SHA256SUMS.txt."
            case .badChecksum: return "Контрольная сумма ZIP не совпала. Установка отменена."
            case .invalidApp: return "Архив не содержит приложение с ожидаемым идентификатором и версией."
            case .http(let status): return "GitHub вернул HTTP \(status)."
            case .badVersionTag: return "Некорректный номер версии релиза."
            }
        }
    }

    static func request(_ url: URL) -> URLRequest {
        var r = URLRequest(url: url)
        r.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        r.setValue("SpeechSculptor-Mac-Updater", forHTTPHeaderField: "User-Agent")
        r.timeoutInterval = 60
        return r
    }

    static func latest() async throws -> UpdateManager.Release {
        let (data, response) = try await URLSession.shared.data(for: request(UpdateManager.apiURL))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404 { throw Error.noReleases }
        guard status == 200 else { throw Error.http(status) }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(UpdateManager.Release.self, from: data)
    }

    static func fetchVerifiedApp(_ release: UpdateManager.Release) async throws -> URL {
        guard release.tagName.range(of: #"^v[0-9]+\.[0-9]+\.[0-9]+$"#, options: .regularExpression) != nil
        else { throw Error.badVersionTag }
        guard let archive = release.asset(UpdateManager.zipName),
              let checksums = release.asset(UpdateManager.digestName) else { throw Error.missingAssets }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("sculptor-update-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        do {
            let (tempArchive, zipResponse) = try await URLSession.shared.download(for: request(archive.browserDownloadUrl))
            guard (zipResponse as? HTTPURLResponse)?.statusCode == 200 else { throw Error.missingAssets }
            let zip = root.appendingPathComponent(UpdateManager.zipName)
            try FileManager.default.moveItem(at: tempArchive, to: zip)

            let (data, checksumResponse) = try await URLSession.shared.data(for: request(checksums.browserDownloadUrl))
            guard (checksumResponse as? HTTPURLResponse)?.statusCode == 200,
                  let list = String(data: data, encoding: .utf8) else { throw Error.missingAssets }
            let expected = list.split(separator: "\n").compactMap { line -> String? in
                let parts = line.split(whereSeparator: { $0.isWhitespace })
                guard parts.count >= 2,
                      String(parts.last!).hasSuffix(UpdateManager.zipName) else { return nil }
                return String(parts[0]).lowercased()
            }.first
            guard let expected, expected.count == 64 else { throw Error.badChecksum }
            let reader = try FileHandle(forReadingFrom: zip)
            defer { try? reader.close() }
            var hash = SHA256()
            while true {
                let part = try reader.read(upToCount: 1024 * 1024) ?? Data()
                if part.isEmpty { break }
                hash.update(data: part)
            }
            guard hash.finalize().map({ String(format: "%02x", $0) }).joined() == expected
            else { throw Error.badChecksum }

            let destination = root.appendingPathComponent("contents", isDirectory: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            let extractor = Process()
            extractor.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            extractor.arguments = ["-x", "-k", zip.path, destination.path]
            try extractor.run()
            extractor.waitUntilExit()
            guard extractor.terminationStatus == 0 else { throw Error.invalidApp }
            let candidate = destination.appendingPathComponent("SpeechSculptor.app")
            guard FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Contents/Info.plist").path)
            else { throw Error.invalidApp }
            return candidate
        } catch {
            try? FileManager.default.removeItem(at: root)
            throw error
        }
    }
}
