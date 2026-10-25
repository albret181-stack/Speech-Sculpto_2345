import Foundation

/// A candidate phrase in its textual context, not an assertion of a speech error.
struct SpeechCue {
    enum Interpretation {
        case possibleFiller
        case contextual
    }
    let phrase: String
    let excerpt: String
    let timestamp: Double?
    let interpretation: Interpretation
    let explanation: String
    let range: NSRange
}

enum SpeechContext {
    private static let words = [
        "как бы", "по факту", "на самом деле", "вот это вот", "в целом",
        "собственно", "соответственно", "получается", "то есть",
        "ну", "вот", "короче", "типа", "эээ", "эм", "ммм", "значит"
    ]

    private static let wordPattern = try! NSRegularExpression(
        pattern: #"\p{L}+(?:[-’']\p{L}+)*|\p{N}+"#
    )

    static func analyze(_ text: String, segments: [SpeechSegment] = []) -> [SpeechCue] {
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        var used: [NSRange] = []
        var matches: [(phrase: String, range: NSRange)] = []
        for phrase in words.sorted(by: { $0.count > $1.count }) {
            let escaped = NSRegularExpression.escapedPattern(for: phrase)
                .replacingOccurrences(of: "\\ ", with: #"\s+"#)
            guard let regex = try? NSRegularExpression(
                pattern: #"(?<![\p{L}\p{N}])"# + escaped + #"(?![\p{L}\p{N}])"#,
                options: .caseInsensitive
            ) else { continue }
            for found in regex.matches(in: text, range: fullRange) {
                guard !used.contains(where: { NSIntersectionRange($0, found.range).length > 0 }) else { continue }
                used.append(found.range)
                matches.append((phrase: phrase, range: found.range))
            }
        }
        matches.sort {
            $0.range.location == $1.range.location
                ? $0.range.length > $1.range.length
                : $0.range.location < $1.range.location
        }

        let timedWords: [(word: String, at: Double)] = segments.flatMap { segment in
            tokens(segment.word).map { ($0, segment.start) }
        }
        var cursor = 0

        return matches.compactMap { item in
            guard let r = Range(item.range, in: text) else { return nil }
            let preceding = String(text[..<r.lowerBound])
            let following = String(text[r.upperBound...])
            let previous = tokens(preceding).last ?? ""
            let next = tokens(following).first ?? ""
            let (interpretation, reason) = classify(item.phrase, previous: previous, next: next)
            let matchWords = tokens(String(text[r]))
            var at: Double?
            if !timedWords.isEmpty && !matchWords.isEmpty && matchWords.count <= timedWords.count {
                // Preserve order. Never guess the time when matching is uncertain.
                if cursor <= timedWords.count - matchWords.count {
                    for index in cursor...(timedWords.count - matchWords.count) {
                        if (0..<matchWords.count).allSatisfy({ timedWords[index + $0].word == matchWords[$0] }) {
                            at = timedWords[index].at
                            cursor = index + matchWords.count
                            break
                        }
                    }
                }
            }
            let excerpt = contextualExcerpt(in: text, at: r)
            return SpeechCue(phrase: item.phrase, excerpt: excerpt,
                             timestamp: at, interpretation: interpretation,
                             explanation: reason, range: item.range)
        }
    }

    static func likelyBreakdown(_ text: String, segments: [SpeechSegment] = []) -> [String: Int] {
        var breakdown: [String: Int] = [:]
        for cue in analyze(text, segments: segments) where cue.interpretation == .possibleFiller {
            breakdown[cue.phrase, default: 0] += 1
        }
        return breakdown
    }

    private static func tokens(_ value: String) -> [String] {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return wordPattern.matches(in: value, range: range).compactMap {
            Range($0.range, in: value).map { String(value[$0]).lowercased() }
        }
    }

    private static func contextualExcerpt(in text: String, at range: Range<String.Index>) -> String {
        // Prefer boundaries close to the phrase and avoid splitting Unicode scalars.
        let beginning = text.index(range.lowerBound, offsetBy: -54, limitedBy: text.startIndex) ?? text.startIndex
        let ending = text.index(range.upperBound, offsetBy: 68, limitedBy: text.endIndex) ?? text.endIndex
        let left = beginning == text.startIndex ? "" : "…"
        let right = ending == text.endIndex ? "" : "…"
        return left + String(text[beginning..<ending]).trimmingCharacters(in: .whitespacesAndNewlines) + right
    }

    private static func classify(_ phrase: String, previous: String, next: String) -> (SpeechCue.Interpretation, String) {
        switch phrase {
        case "то есть":
            return (.contextual, "Может вводить необходимое пояснение. Проверь, добавляет ли фраза смысл.")
        case "на самом деле", "в целом", "по факту", "собственно", "соответственно", "получается":
            return (.contextual, "Возможное вводное выражение; без полного контекста нельзя признать его ошибкой.")
        case "вот":
            if ["это", "эта", "этот", "эти", "здесь", "там", "он", "она", "они", "так"].contains(next) {
                return (.contextual, "Может указывать на предмет или ситуацию, а не заполнять паузу.")
            }
            return (.possibleFiller, "Возможно, слово заполняет паузу. Послушай фрагмент перед выводом.")
        case "короче":
            if ["стал", "стала", "стало", "был", "была", "будет", "маршрут", "путь", "текст", "ответ", "срок", "фраза"].contains(previous) {
                return (.contextual, "Вероятно, сравнительная форма прилагательного, а не вводное слово.")
            }
            return (.possibleFiller, "Может предварять вывод. Попробуй сразу назвать главный тезис.")
        case "типа":
            if ["такого", "этого", "данного", "разного", "нового"].contains(previous) {
                return (.contextual, "Может обозначать разновидность, а не речевой заполнитель.")
            }
            return (.possibleFiller, "Возможно, заменяет точное описание. Проверь, нельзя ли назвать пример прямо.")
        case "как бы":
            if ["ты", "вы", "он", "она", "они", "я", "мы"].contains(next) {
                return (.contextual, "Может быть частью условного оборота, а не словом-паразитом.")
            }
            return (.possibleFiller, "Проверь, делает ли оборот высказывание неопределённым без необходимости.")
        case "значит":
            if ["это", "что", "слово", "термин"].contains(previous) {
                return (.contextual, "Может обозначать следствие или значение.")
            }
            return (.possibleFiller, "Может использоваться перед новой мыслью вместо короткой паузы.")
        case "эээ", "эм", "ммм":
            return (.possibleFiller, "Похоже на звуковой заполнитель паузы; распознавание таких звуков неточно.")
        case "ну":
            return (.possibleFiller, "Частица может быть естественной; проверь её повторяемость в данном контексте.")
        case "вот это вот":
            return (.possibleFiller, "Оборот может быть избыточным. Попробуй назвать предмет или действие прямо.")
        default:
            return (.contextual, "Употребление зависит от смысла высказывания.")
        }
    }
}
