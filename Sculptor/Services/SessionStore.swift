import Foundation

final class SessionStore {
    static let shared = SessionStore()
    private let fm = FileManager.default
    let root: URL

    private init() {
        root = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SpeechSculptor", isDirectory: true)
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
    }
    func audioURL(_ session: SpeechSession) -> URL { root.appendingPathComponent(session.relativeAudioPath) }
    func newAudioURL(_ id: UUID, ext: String = "m4a") throws -> URL {
        let folder = root.appendingPathComponent("Recordings").appendingPathComponent(id.uuidString)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("audio.\(ext)")
    }
    func load() -> [SpeechSession] {
        let file = root.appendingPathComponent("sessions.json")
        guard let data = try? Data(contentsOf: file), let sessions = try? JSONDecoder().decode([SpeechSession].self, from: data) else { return [] }
        return sessions.sorted { $0.createdAt > $1.createdAt }
    }
    func save(_ sessions: [SpeechSession]) throws {
        let data = try JSONEncoder().encode(sessions)
        try data.write(to: root.appendingPathComponent("sessions.json"), options: .atomic)
    }
    func delete(_ item: SpeechSession) throws {
        let folder = audioURL(item).deletingLastPathComponent()
        if fm.fileExists(atPath: folder.path) { try fm.removeItem(at: folder) }
    }
}
