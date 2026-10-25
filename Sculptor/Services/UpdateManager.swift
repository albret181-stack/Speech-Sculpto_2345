import Foundation
import AppKit
import Combine
import CryptoKit

/// Authenticated updater for the user's private repository.
/// Uses GitHub CLI authentication; never embeds a GitHub token.
@MainActor
final class UpdateManager: ObservableObject {
    struct Asset: Decodable { let name: String }
    struct Release: Decodable {
        let tagName: String
        let name: String
        let body: String
        let assets: [Asset]
    }

    static let repo = "albret181-stack/Speech-Sculpto_2345"
    static let zipName = "SpeechSculptor-macOS-development.zip"
    static let digestName = "SHA256SUMS.txt"

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
        return release.assets.contains { $0.name == Self.zipName } &&
               release.assets.contains { $0.name == Self.digestName }
    }

    func check(silent: Bool = false) async {
        guard !checking && !installing else { return }
        checking = true
        defer { checking = false; lastChecked = Date() }
        do {
            let item: Release = try await Task.detached(priority: .utility) {
                let data = try GitHubCLI.execute(["release", "view", "--repo", UpdateManager.repo,
                                                  "--json", "tagName,name,body,assets"])
                return try JSONDecoder().decode(Release.self, from: data)
            }.value
            let remote = item.tagName.replacingOccurrences(of: "v", with: "", options: [.anchored])
            let a = remote.split(separator: ".").compactMap { Int($0) }
            let b = current.split(separator: ".").compactMap { Int($0) }
            release = a.count == 3 && b.count == 3 && a.lexicographicallyPrecedes(b) == false && a != b ? item : nil
            if !silent { statusMessage = release == nil ? "Обновлений нет. Версия \(current)." : "Доступна версия \(item.tagName)." }
        } catch {
            release = nil
            if !silent { statusMessage = error.localizedDescription }
        }
    }

    func install() async {
        guard let release, canInstall, !installing else {
            statusMessage = "В релизе нет архива и контрольной суммы для установки."
            return
        }
        installing = true
        defer { installing = false }
        do {
            let candidate = try await Task.detached(priority: .userInitiated) {
                try GitHubCLI.verifiedReleaseApp(tag: release.tagName)
            }.value
            let target = Bundle.main.bundleURL
            guard target.pathExtension == "app",
                  FileManager.default.isWritableFile(atPath: target.deletingLastPathComponent().path) else {
                NSWorkspace.shared.activateFileViewerSelecting([candidate])
                statusMessage = "Скачано. Приложение нельзя заменить автоматически в текущей папке. Открываю файл в Finder."
                return
            }
            guard let info = Bundle(url: candidate),
                  info.bundleIdentifier == Bundle.main.bundleIdentifier,
                  info.infoDictionary?["CFBundleShortVersionString"] as? String ==
                    release.tagName.replacingOccurrences(of: "v", with: "", options: [.anchored]) else {
                throw GitHubCLI.Failure.invalidBundle
            }
            let helper = Process()
            helper.executableURL = URL(fileURLWithPath: "/bin/bash")
            let script = #"""
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
            if mv "$NEW" "$OLD"; then
              open "$OLD"
            else
              mv "$BACKUP" "$OLD"
              exit 1
            fi
            """#
            helper.arguments = ["-c", script, "sculptor-update",
                                candidate.path, target.path,
                                String(ProcessInfo.processInfo.processIdentifier)]
            helper.standardOutput = FileHandle.nullDevice
            helper.standardError = FileHandle.nullDevice
            try helper.run()
            NSApp.terminate(nil)
        } catch {
            statusMessage = "Не удалось установить обновление: \(error.localizedDescription)"
        }
    }
}

private enum GitHubCLI {
    enum Failure: LocalizedError {
        case noCLI, invalidBundle, invalidChecksum, releaseFilesMissing, failed(String)
        var errorDescription: String? {
            switch self {
            case .noCLI: return "Требуется GitHub CLI. Установи: brew install gh, затем gh auth login."
            case .invalidBundle: return "Неверная версия или структура приложения в релизе."
            case .invalidChecksum: return "Контрольная сумма SHA-256 не совпала — обновление остановлено."
            case .releaseFilesMissing: return "В GitHub Releases отсутствуют нужные файлы."
            case .failed(let text): return text
            }
        }
    }

    static func execute(_ arguments: [String]) throws -> Data {
        guard let executable = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw Failure.noCLI
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        let out = Pipe(), err = Pipe()
        task.standardOutput = out
        task.standardError = err
        try task.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let stderr = err.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            throw Failure.failed(String((String(data: stderr, encoding: .utf8) ?? "GitHub недоступен.").prefix(360)))
        }
        return data
    }

    static func verifiedReleaseApp(tag: String) throws -> URL {
        guard tag.range(of: #"^v[0-9]+\.[0-9]+\.[0-9]+$"#, options: .regularExpression) != nil else {
            throw Failure.invalidBundle
        }
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("sculptor-update-\(UUID().uuidString)")
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        do {
            for file in [UpdateManager.zipName, UpdateManager.digestName] {
                _ = try execute(["release", "download", tag, "--repo", UpdateManager.repo,
                                 "--pattern", file, "--dir", base.path])
            }
            let zip = base.appendingPathComponent(UpdateManager.zipName)
            let digestFile = base.appendingPathComponent(UpdateManager.digestName)
            guard fm.fileExists(atPath: zip.path), fm.fileExists(atPath: digestFile.path) else {
                throw Failure.releaseFilesMissing
            }
            let lines = try String(contentsOf: digestFile, encoding: .utf8).split(separator: "\n")
            let expected = lines.compactMap { line -> String? in
                let parts = line.split(whereSeparator: { $0.isWhitespace })
                guard parts.count >= 2, String(parts.last!).hasSuffix(UpdateManager.zipName) else { return nil }
                return String(parts[0]).lowercased()
            }.first
            guard let expected, expected.count == 64 else { throw Failure.invalidChecksum }
            let reader = try FileHandle(forReadingFrom: zip)
            defer { try? reader.close() }
            var hash = SHA256()
            while true {
                let chunk = try reader.read(upToCount: 1024 * 1024) ?? Data()
                if chunk.isEmpty { break }
                hash.update(data: chunk)
            }
            let actual = hash.finalize().map { String(format: "%02x", $0) }.joined()
            guard expected == actual else { throw Failure.invalidChecksum }
            let unpacked = base.appendingPathComponent("extracted", isDirectory: true)
            try fm.createDirectory(at: unpacked, withIntermediateDirectories: true)
            let ditto = Process()
            ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            ditto.arguments = ["-x", "-k", zip.path, unpacked.path]
            try ditto.run()
            ditto.waitUntilExit()
            let candidate = unpacked.appendingPathComponent("SpeechSculptor.app")
            guard ditto.terminationStatus == 0,
                  fm.fileExists(atPath: candidate.appendingPathComponent("Contents/Info.plist").path)
            else { throw Failure.invalidBundle }
            return candidate
        } catch {
            try? fm.removeItem(at: base)
            throw error
        }
    }
}
