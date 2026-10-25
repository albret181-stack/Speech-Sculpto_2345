import Foundation
import Combine

struct CoachingLesson: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let instruction: String
    let focus: String
    let baselineID: UUID?
    let baselineRate: Double?
    let createdAt: Date
}

struct CoachingAttempt: Codable, Identifiable, Hashable {
    var id: UUID
    var lessonID: String
    var sessionID: UUID
    var createdAt: Date
}

enum LessonPlanner {
    static func recommended(from session: SpeechSession?) -> CoachingLesson {
        let issue = session?.report?.issues.first
        let kind = issue?.kind ?? "clarity"
        let spec: (String, String, String)
        switch kind {
        case "filler": spec = ("Осознанная пауза", "Расскажи об одной идее 45–60 секунд. Перед следующей мыслью делай небольшую паузу вместо лишнего вводного слова.", "filler")
        case "intonation": spec = ("Интонационный акцент", "Расскажи за минуту о важном решении. Выдели голосом ключевое слово в каждом смысловом блоке.", "intonation")
        case "pause": spec = ("Смысловые паузы", "Объясни идею по схеме: проблема — пауза — предложение — пауза — результат.", "pause")
        case "clarity": spec = ("Тезис, аргумент, вывод", "За минуту изложи одну мысль. Начни с тезиса, затем приведи аргумент и заверши выводом.", "clarity")
        default: spec = ("Чёткая мысль", "За минуту сформулируй одну идею: проблема — решение — результат.", "clarity")
        }
        return CoachingLesson(id: spec.2, title: spec.0, instruction: spec.1, focus: spec.2,
                              baselineID: session?.id, baselineRate: session?.report?.metrics.fillersPer100,
                              createdAt: Date())
    }
}

@MainActor
final class CoachingStore: ObservableObject {
    static let shared = CoachingStore()
    @Published private(set) var lessons: [CoachingLesson] = []
    @Published private(set) var attempts: [CoachingAttempt] = []
    @Published var message: String?

    private struct Snapshot: Codable {
        var lessons: [CoachingLesson]
        var attempts: [CoachingAttempt]
    }
    private let file: URL
    private init() {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SpeechSculptor", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        file = root.appendingPathComponent("coaching-progress.json")
        if let data = try? Data(contentsOf: file),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            lessons = snapshot.lessons
            attempts = snapshot.attempts
        }
    }
    private func persist(_ newLessons: [CoachingLesson], _ newAttempts: [CoachingAttempt]) -> Bool {
        do {
            try JSONEncoder().encode(Snapshot(lessons: newLessons, attempts: newAttempts))
                .write(to: file, options: .atomic)
            lessons = newLessons
            attempts = newAttempts
            message = nil
            return true
        } catch {
            message = "Не удалось сохранить прогресс: \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func select(_ lesson: CoachingLesson) -> Bool {
        var new = lessons.filter { $0.id != lesson.id }
        new.insert(lesson, at: 0)
        return persist(new, attempts)
    }

    @discardableResult
    func link(sessionID: UUID, to lessonID: String) -> Bool {
        guard lessons.contains(where: { $0.id == lessonID }) else { return false }
        let item = CoachingAttempt(id: UUID(), lessonID: lessonID, sessionID: sessionID, createdAt: Date())
        return persist(lessons, [item] + attempts.filter { $0.sessionID != sessionID })
    }

    func completed(_ sessions: [SpeechSession]) -> [CoachingAttempt] {
        attempts.filter { attempt in
            sessions.contains {
                $0.id == attempt.sessionID && $0.isPractice &&
                ($0.report?.metrics.words ?? 0) > 0
            }
        }
    }

    func attempts(for id: String, sessions: [SpeechSession]) -> [(CoachingAttempt, SpeechSession)] {
        attempts.filter { $0.lessonID == id }.compactMap { attempt in
            guard let session = sessions.first(where: { $0.id == attempt.sessionID }) else { return nil }
            return (attempt, session)
        }
    }
}
