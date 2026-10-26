import Foundation

struct ProgressWindow {
    let days: Int
    let recordings: Int
    let analyzed: Int
    let words: Int
    let fillerCount: Int
    let fillersPer100: Double?
    let lessons: Int
    let activeDays: Int
    let change: Double?
    let comparisonNote: String
}

enum ProgressAnalytics {
    static func window(_ sessions: [SpeechSession], days: Int, now: Date = Date(), calendar: Calendar = .current) -> ProgressWindow {
        let end = now
        let start = calendar.date(byAdding: .day, value: -(days-1), to: calendar.startOfDay(for: now)) ?? now
        let recent = sessions.filter { $0.createdAt >= start && $0.createdAt <= end }
        let ordinary = recent.filter { !$0.isPractice }
        let usable = ordinary.filter { $0.report != nil && ($0.report?.metrics.words ?? 0) >= 20 &&
                                      !($0.report?.transcript.isEmpty ?? true) }
        let words = usable.reduce(0) { $0 + ($1.report?.metrics.words ?? 0) }
        let fillers = usable.reduce(0) { $0 + ($1.report?.metrics.fillerCount ?? 0) }
        let aggregate = words > 0 ? Double(fillers)*100/Double(words) : nil
        let boundary = calendar.date(byAdding: .day, value: -(days/2), to: calendar.startOfDay(for: now)) ?? now
        let before = usable.filter { $0.createdAt < boundary }
        let after = usable.filter { $0.createdAt >= boundary }
        func rate(_ records: [SpeechSession]) -> Double? {
            let wc = records.reduce(0) { $0 + ($1.report?.metrics.words ?? 0) }
            let fc = records.reduce(0) { $0 + ($1.report?.metrics.fillerCount ?? 0) }
            return wc > 0 ? Double(fc)*100/Double(wc) : nil
        }
        let change = before.count >= 2 && after.count >= 2 && rate(before) != nil && rate(after) != nil
            ? rate(after)! - rate(before)! : nil
        let note = change == nil ? "Для динамики нужны минимум две качественно распознанные записи в каждой половине периода."
            : "Изменение частоты потенциальных заполнителей, п.п. Сравнивать лучше записи одного типа и сходной длины."
        let exercises = recent.filter { $0.isPractice && $0.report != nil &&
                                       ($0.report?.metrics.words ?? 0) >= 12 &&
                                       !($0.report?.transcript.isEmpty ?? true) }
        let daysActive = Set(recent.map { calendar.startOfDay(for: $0.createdAt) }).count
        return ProgressWindow(days: days, recordings: ordinary.count, analyzed: usable.count,
                              words: words, fillerCount: fillers, fillersPer100: aggregate,
                              lessons: exercises.count, activeDays: daysActive,
                              change: change, comparisonNote: note)
    }
    static func daily(_ sessions: [SpeechSession], days: Int, now: Date = Date(),
                      calendar: Calendar = .current) -> [Double?] {
        (0..<days).map { index in
            let day = calendar.date(byAdding: .day, value: index-days+1, to: calendar.startOfDay(for: now))!
            let inDay = sessions.filter {
                !$0.isPractice && calendar.isDate($0.createdAt, inSameDayAs: day) &&
                ($0.report?.metrics.words ?? 0) >= 20
            }
            let words = inDay.reduce(0) { $0 + ($1.report?.metrics.words ?? 0) }
            let fillers = inDay.reduce(0) { $0 + ($1.report?.metrics.fillerCount ?? 0) }
            return words > 0 ? Double(fillers) * 100 / Double(words) : nil
        }
    }
}
