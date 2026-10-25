import Foundation

/// An evidence-linked exercise, based on the latest ordinary recording.
/// Exercises are guidance, not a diagnosis or proof of improvement.
struct CoachLesson: Identifiable {
    let kind: String
    let title: String
    let reason: String
    let instruction: String
    let steps: [String]
    let targetSeconds: Int
    let howToReview: String
    let sourceSessionID: UUID?
    var id: String { kind }
}

struct CoachAttempt: Codable, Identifiable, Hashable {
    var sessionID: UUID
    var kind: String
    var sourceSessionID: UUID?
    var createdAt: Date
    var reflection: String?
    var id: UUID { sessionID }
}

enum CoachEngine {
    static let kinds = ["filler", "clarity", "intonation", "pause", "practice"]

    static func kindTitle(_ kind: String) -> String {
        switch kind {
        case "filler": "Слова-паразиты"
        case "clarity": "Ясность мысли"
        case "intonation": "Выразительность"
        case "pause": "Осознанные паузы"
        default: "Краткое объяснение"
        }
    }

    static func source(in sessions: [SpeechSession]) -> SpeechSession? {
        sessions.filter { !$0.isPractice && $0.report != nil }
            .max(by: { $0.createdAt < $1.createdAt })
    }

    static func recommendedKind(in sessions: [SpeechSession]) -> String {
        let issues = source(in: sessions)?.report?.issues ?? []
        return issues.first(where: { kinds.contains($0.kind) && $0.kind != "practice" })?.kind ?? "practice"
    }

    static func lesson(kind: String, sessions: [SpeechSession]) -> CoachLesson {
        let source = source(in: sessions)
        let actual = kinds.contains(kind) ? kind : "practice"
        let matching = source?.report?.issues.first(where: { $0.kind == actual })
        let reason = matching.map { "\($0.heading): \($0.explanation)" } ??
            "Потренируй навык отдельно. В последнем разборе эта проблема не выделена как основная."
        let id = source?.id

        switch actual {
        case "filler":
            return CoachLesson(kind: actual, title: "Говори без лишних заполнителей",
                reason: reason,
                instruction: "За 45–60 секунд предложи идею. Вместо ненужных «ну», «вот», «как бы» выдерживай короткую паузу.",
                steps: ["Выбери одну идею", "Расскажи её без спешки", "Прослушай паузы и повторы"],
                targetSeconds: 60, howToReview: "Потенциальные заполнители на 100 слов; проверь спорные случаи на слух.",
                sourceSessionID: id)
        case "clarity":
            return CoachLesson(kind: actual, title: "Одна мысль — короткий тезис",
                reason: reason,
                instruction: "За минуту объясни решение по схеме «тезис → один аргумент → вывод». Разделяй длинные предложения.",
                steps: ["Назови тезис", "Добавь один аргумент", "Заверши выводом"],
                targetSeconds: 60, howToReview: "Сравни длину самой длинной фразы и понятность формулировки.",
                sourceSessionID: id)
        case "intonation":
            return CoachLesson(kind: actual, title: "Сделай смысловые акценты",
                reason: reason,
                instruction: "Произнеси одну идею несколько раз, выделяя голосом главное слово. Не нужно искусственно повышать тон.",
                steps: ["Определи ключевое слово", "Выдели его интонацией", "Сравни звучание"],
                targetSeconds: 45, howToReview: "Интонационный диапазон — только ориентир; оцени естественность на слух.",
                sourceSessionID: id)
        case "pause":
            return CoachLesson(kind: actual, title: "Пауза перед выводом",
                reason: reason,
                instruction: "Объясни решение: проблема — пауза — предложение — пауза — результат.",
                steps: ["Обозначь проблему", "Сделай паузу перед решением", "Заверши выводом"],
                targetSeconds: 60, howToReview: "Частота акустических пауз — ориентир, не чем больше, тем лучше.",
                sourceSessionID: id)
        default:
            return CoachLesson(kind: "practice", title: "Сформулируй главное за минуту",
                reason: source == nil
                    ? "Сначала можно сделать тренировочную запись. После обычного разговора появятся персональные рекомендации."
                    : "Потренируй связную речь на основе предыдущего разбора.",
                instruction: "Расскажи об одной идее за 45–60 секунд: «проблема → решение → результат».",
                steps: ["Выбери одну тему", "Скажи главную мысль", "Сформулируй ясный вывод"],
                targetSeconds: 60, howToReview: "Прослушай запись: понятна ли мысль без дополнительных пояснений?",
                sourceSessionID: id)
        }
    }

    static func completed(_ attempt: CoachAttempt, sessions: [SpeechSession]) -> Bool {
        guard let report = sessions.first(where: { $0.id == attempt.sessionID })?.report else { return false }
        return report.metrics.words >= 12 && !report.transcript.isEmpty
    }

    static func comparison(for attempt: CoachAttempt, sessions: [SpeechSession]) -> String {
        guard let baseID = attempt.sourceSessionID,
              let baseline = sessions.first(where: { $0.id == baseID })?.report,
              let after = sessions.first(where: { $0.id == attempt.sessionID })?.report,
              baseline.metrics.words >= 20, after.metrics.words >= 12,
              !baseline.transcript.isEmpty, !after.transcript.isEmpty else {
            return "Для сопоставления нужны две успешно распознанные записи. Повтор можно прослушать вручную."
        }
        switch attempt.kind {
        case "filler":
            return String(format: "Потенциальных заполнителей: %.1f → %.1f на 100 слов. Разные темы и длительность ограничивают сравнение.",
                          baseline.metrics.fillersPer100, after.metrics.fillersPer100)
        case "clarity":
            return "Самая длинная фраза: \(longestSentence(baseline.transcript)) → \(longestSentence(after.transcript)) слов. Число не измеряет понятность."
        case "intonation":
            if baseline.metrics.reliablePitchSamples >= 15,
               after.metrics.reliablePitchSamples >= 15,
               let before = baseline.metrics.pitchRangeSemitones,
               let next = after.metrics.pitchRangeSemitones {
                return String(format: "Диапазон высоты голоса: %.1f → %.1f полутона. Более широкий диапазон сам по себе не означает лучший результат.", before, next)
            }
            return "Для сопоставления интонации не хватает качественных голосовых участков; прослушай обе записи."
        case "pause":
            if baseline.metrics.measuredSpeechSeconds > 15 && after.metrics.measuredSpeechSeconds > 15 {
                return String(format: "Найдено пауз в минуту: %.1f → %.1f. Важнее их уместность, а не количество.",
                              baseline.metrics.pausesPerMinute, after.metrics.pausesPerMinute)
            }
            return "Недостаточно пригодного аудио для сопоставления пауз; оцени их расположение на слух."
        default:
            return "Переслушай обе записи и оцени наличие тезиса, довода и вывода. Автоматической проверки смысла пока нет."
        }
    }

    private static func longestSentence(_ text: String) -> Int {
        text.split(whereSeparator: { ".!?…".contains($0) })
            .map { Scoring.countWords(String($0)) }.max() ?? 0
    }
}
