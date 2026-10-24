import Foundation

struct SpeechSegment: Codable, Hashable {
    var word: String
    var start: Double
    var duration: Double
}

struct Issue: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var kind: String
    var heading: String
    var evidence: String
    var explanation: String
    var exercise: String
    var timestamp: Double?
}

struct VoiceMetrics: Codable, Hashable {
    var words: Int
    var fillerCount: Int
    var fillersPer100: Double
    var wordsPerMinute: Double
    var pauseCount: Int
    var pausesPerMinute: Double
    var pitchRangeSemitones: Double?
    var measuredSpeechSeconds: Double
    var reliablePitchSamples: Int
}

struct SpeechReport: Codable, Hashable {
    var createdAt: Date
    var transcript: String
    var segments: [SpeechSegment]
    var metrics: VoiceMetrics
    var fillerBreakdown: [String: Int]
    var issues: [Issue]
    var verdict: String
    var caveats: [String]
    var aiComment: String?
}

struct SpeechSession: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var createdAt: Date
    var duration: Double
    var relativeAudioPath: String
    var isPractice: Bool
    var report: SpeechReport?

    var durationLabel: String {
        let seconds = max(0, Int(duration))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

enum Scoring {
    static let dictionary: [String] = [
        "как бы", "по факту", "на самом деле", "вот это вот", "в целом", "собственно",
        "соответственно", "получается", "то есть",
        "ну", "вот", "короче", "типа", "эээ", "эм", "ммм", "значит"
    ]

    static func countWords(_ text: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: #"[\p{L}\p{N}]+(?:[-’'][\p{L}\p{N}]+)*"#) else { return 0 }
        return regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    static func fillers(_ text: String) -> [String: Int] {
        // Longest-first, non-overlapping. Word boundaries are Unicode-aware.
        let patterns = dictionary.sorted { $0.count > $1.count }
        var claimed: [NSRange] = []
        var result: [String: Int] = [:]
        for phrase in patterns {
            let escaped = NSRegularExpression.escapedPattern(for: phrase).replacingOccurrences(of: "\\ ", with: #"\s+"#)
            guard let matcher = try? NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}])" + escaped + "(?![\\p{L}\\p{N}])", options: [.caseInsensitive]) else { continue }
            for match in matcher.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                if claimed.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) { continue }
                claimed.append(match.range)
                result[phrase, default: 0] += 1
            }
        }
        return result
    }

    static func makeReport(text: String, segments: [SpeechSegment], duration: Double, acoustic: AcousticValues) -> SpeechReport {
        let count = countWords(text)
        let breakdown = fillers(text)
        let fillers = breakdown.values.reduce(0, +)
        let elapsed = acoustic.speechSeconds > 0 ? acoustic.speechSeconds : duration
        let wpm = count > 0 && elapsed > 0 ? Double(count) / elapsed * 60 : 0
        let rate = count > 0 ? Double(fillers) / Double(count) * 100 : 0
        let pausesPerMinute = duration > 0 ? Double(acoustic.pauses) * 60 / duration : 0
        let m = VoiceMetrics(words: count, fillerCount: fillers, fillersPer100: rate,
                             wordsPerMinute: wpm, pauseCount: acoustic.pauses,
                             pausesPerMinute: pausesPerMinute,
                             pitchRangeSemitones: acoustic.pitchRange,
                             measuredSpeechSeconds: acoustic.speechSeconds,
                             reliablePitchSamples: acoustic.pitchSamples)
        var issues: [Issue] = []
        if fillers >= 3 && rate >= 2.5 {
            let summary = breakdown.sorted { $0.value > $1.value }.prefix(3).map { "«\($0.key)» — \($0.value)" }.joined(separator: ", ")
            issues.append(Issue(kind: "filler", heading: "Повторяющиеся вводные слова", evidence: summary,
                                explanation: "Часть выражений может быть уместной. Послушай отмеченные слова и попробуй заменить ненужные короткой паузой.",
                                exercise: "За 45 секунд объясни одну мысль, сознательно заменяя лишние «ну» и «вот» паузами.",
                                timestamp: findFirstFiller(in: segments)))
        }
        let sentences = text.split(whereSeparator: { ".!?…".contains($0) })
        if let longest = sentences.max(by: { countWords(String($0)) < countWords(String($1)) }), countWords(String(longest)) >= 38 {
            let snippet = String(longest).trimmingCharacters(in: .whitespacesAndNewlines)
            issues.append(Issue(kind: "clarity", heading: "Слишком длинная мысль", evidence: String(snippet.prefix(170)) + (snippet.count > 170 ? "…" : ""),
                                explanation: "Длинную фразу сложнее воспринимать на слух. Сначала назови тезис, затем его объяснение.",
                                exercise: "Перескажи выделенную мысль двумя короткими предложениями: тезис → аргумент.", timestamp: nil))
        }
        if acoustic.pitchSamples >= 15, let range = acoustic.pitchRange, range < 2.7 {
            issues.append(Issue(kind: "intonation", heading: "Небольшие изменения высоты голоса", evidence: "Интонационный диапазон на пригодных участках: \(String(format: "%.1f", range)) полутона.",
                                explanation: "Это возможный признак ровной подачи, а не доказательство плохой речи. Значение может искажаться шумом и выбором фраз.",
                                exercise: "Выбери главное слово в одной фразе и произнеси её повторно с осознанным интонационным акцентом.", timestamp: nil))
        }
        if acoustic.speechSeconds > 30 && acoustic.pauses < Int(duration / 20) {
            issues.append(Issue(kind: "pause", heading: "Мало заметных пауз", evidence: "Обнаружено пауз: \(acoustic.pauses) за \(Int(duration / 60)) мин. (оценка по уровню звука).",
                                explanation: "Измерение ориентировочное. Перед важным выводом короткая пауза часто делает структуру понятнее.",
                                exercise: "Объясни решение за одну минуту: проблема — пауза — предложение — пауза — результат.", timestamp: nil))
        }
        if issues.isEmpty {
            issues.append(Issue(kind: "practice", heading: "Закрепи ясность речи", evidence: "Выраженной проблемы по доступным измерениям не обнаружено.",
                                explanation: "Это не означает, что речь идеальна: автоматический анализ ограничен качеством звука и контекстом.",
                                exercise: "Сформулируй одну идею за 45 секунд по схеме «проблема → решение → результат».", timestamp: nil))
        }
        let ranked = Array(issues.prefix(3))
        var caveats = ["Автоматические замечания — подсказки для тренировки, не объективная оценка личности или дикции."]
        if acoustic.pitchSamples < 15 { caveats.append("Недостаточно надёжных голосовых участков для оценки интонации.") }
        caveats.append("Для разговора с несколькими людьми метрики могут включать реплики собеседников. Разделение голосов пока не реализовано.")
        let verdict: String
        if rate > 5 { verdict = "Стоит поработать над вводными словами и ясностью формулировок." }
        else if ranked.contains(where: { $0.kind == "intonation" }) { verdict = "Начни с интонационных акцентов на важных словах." }
        else if ranked.contains(where: { $0.kind == "clarity" }) { verdict = "Попробуй делать выводы короче и конкретнее." }
        else { verdict = "Сделай короткую тренировку и сравни результат с новой записью." }
        return SpeechReport(createdAt: Date(), transcript: text, segments: segments, metrics: m,
                            fillerBreakdown: breakdown, issues: ranked, verdict: verdict, caveats: caveats, aiComment: nil)
    }

    private static func findFirstFiller(in segments: [SpeechSegment]) -> Double? {
        for segment in segments {
            let lower = segment.word.lowercased()
            if dictionary.contains(where: { $0 == lower }) { return segment.start }
        }
        return nil
    }
}

struct AcousticValues {
    var speechSeconds: Double = 0
    var pauses: Int = 0
    var pitchRange: Double? = nil
    var pitchSamples: Int = 0
}
