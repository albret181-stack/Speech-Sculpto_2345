import Foundation

enum AnalysisDiagnostics {
    static var logURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SpeechSculptor", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("analysis-diagnostics.log")
    }
    static func short(_ error: Error) -> String {
        let ns = error as NSError
        return "\(ns.domain) code=\(ns.code): \(ns.localizedDescription)"
    }
    static func event(sessionID: UUID, stage: String, info: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) [\(sessionID.uuidString.prefix(8))] \(stage): \(info)\n"
        guard let data = line.data(using: .utf8) else { return }
        let file = logURL
        if !FileManager.default.fileExists(atPath: file.path) {
            try? data.write(to: file, options: .atomic)
        } else if let handle = try? FileHandle(forWritingTo: file) {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        }
    }
    static func error(sessionID: UUID, stage: String, error: Error) {
        event(sessionID: sessionID, stage: stage, info: short(error))
    }
}
