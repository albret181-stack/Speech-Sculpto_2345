import Foundation
import AppKit
import AVFoundation
import Combine

@MainActor
final class StudioController: ObservableObject {
    @Published var sessions: [SpeechSession] = SessionStore.shared.load()
    @Published var isRecording = false
    @Published var isBusy = false
    @Published var processingID: UUID?
    @Published var selectedID: UUID?
    @Published var elapsed: TimeInterval = 0
    @Published var message: String?
    @Published var currentIsPractice = false
    @Published var aiBusy = false
    @Published var batchActive = false
    @Published var batchTotal = 0
    @Published var batchProcessed = 0
    @Published var batchSucceeded = 0
    @Published var batchCurrentFile = ""
    @Published var batchSummary = ""


    private let store = SessionStore.shared
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var startTime: Date?
    private var pendingID: UUID?

    var selected: SpeechSession? { sessions.first(where: { $0.id == selectedID }) }
    var totalRecordings: Int { sessions.filter { !$0.isPractice }.count }
    var totalFillers: Int { sessions.filter { !$0.isPractice }.compactMap { $0.report?.metrics.fillerCount }.reduce(0,+) }
    var completedLessons: Int { sessions.filter { $0.isPractice && ($0.report?.metrics.words ?? 0) > 0 }.count }
    var latestReport: SpeechReport? { sessions.first(where: { !$0.isPractice && $0.report != nil })?.report }

    func start(practice: Bool = false) async {
        guard !isRecording && !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        let hasPermission = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVCaptureDevice.requestAccess(for: .audio) { continuation.resume(returning: $0) }
        }
        guard hasPermission else {
            message = "Нужен доступ к микрофону. Открой Настройки системы → Конфиденциальность и безопасность → Микрофон."
            return
        }
        do {
            let id = UUID()
            let url = try store.newAudioURL(id)
            let config: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128_000
            ]
            let audio = try AVAudioRecorder(url: url, settings: config)
            guard audio.prepareToRecord(), audio.record() else {
                message = "Не удалось начать запись. Проверь доступ к микрофону."
                return
            }
            recorder = audio
            pendingID = id
            currentIsPractice = practice
            startTime = Date()
            elapsed = 0
            isRecording = true
            message = nil
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let start = self.startTime else { return }
                    self.elapsed = Date().timeIntervalSince(start)
                }
            }
        } catch { message = "Ошибка микрофона: \(error.localizedDescription)" }
    }

    @discardableResult
    func stop() async -> UUID? {
        guard isRecording else { return nil }
        timer?.invalidate()
        timer = nil
        let duration = max(0, recorder?.currentTime ?? elapsed)
        recorder?.stop()
        recorder = nil
        isRecording = false
        elapsed = 0
        defer { pendingID = nil; startTime = nil }
        guard let id = pendingID else { return nil }
        let isPractice = currentIsPractice
        let session = SpeechSession(
            id: id,
            title: (isPractice ? "Упражнение" : "Запись") + " · " + Date().formatted(date: .abbreviated, time: .shortened),
            createdAt: Date(), duration: duration,
            relativeAudioPath: "Recordings/\(id.uuidString)/audio.m4a",
            isPractice: isPractice, report: nil
        )
        sessions.insert(session, at: 0)
        selectedID = id
        do { try store.save(sessions) }
        catch { message = "Запись сохранена, но индекс не записан: \(error.localizedDescription)" }
        return id
    }

    enum ImportError: LocalizedError {
        case unsupportedExtension
        var errorDescription: String? {
            "Поддерживаются M4A, MP3, WAV, CAF и AIFF."
        }
    }

    private func importSingle(_ url: URL) async throws -> UUID {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.lowercased()
        guard ["m4a", "mp3", "wav", "caf", "aiff", "aif"].contains(ext) else {
            throw ImportError.unsupportedExtension
        }
        let id = UUID()
        let destination = try store.newAudioURL(id, ext: ext)
        do {
            try FileManager.default.copyItem(at: url, to: destination)
            let asset = AVURLAsset(url: destination)
            let duration = (try? await asset.load(.duration).seconds) ?? 0
            let item = SpeechSession(
                id: id,
                title: url.deletingPathExtension().lastPathComponent,
                createdAt: Date(), duration: duration.isFinite ? max(0, duration) : 0,
                relativeAudioPath: "Recordings/\(id.uuidString)/audio.\(ext)",
                isPractice: false, report: nil
            )
            let updated = [item] + sessions
            try store.save(updated)
            sessions = updated
            selectedID = id
            return id
        } catch {
            // Don't leave half-imported recordings after a failed file copy or metadata write.
            try? FileManager.default.removeItem(at: destination.deletingLastPathComponent())
            throw error
        }
    }

    func importAudio(_ url: URL) async {
        guard !isRecording && !isBusy && processingID == nil else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await importSingle(url)
            message = "Файл импортирован. Нажми «Анализировать», чтобы получить разбор."
        } catch {
            message = "Не удалось импортировать файл: \(error.localizedDescription)"
        }
    }

    /// Imports and analyzes many files one by one. A failed file cannot stop the rest.
    /// Only one analysis runs at a time to avoid microphone/speech-recognizer conflicts.
    func importBatch(_ urls: [URL], allowAppleCloud: Bool) async {
        guard !urls.isEmpty, !isRecording, !isBusy, processingID == nil else { return }
        isBusy = true
        batchActive = true
        batchTotal = urls.count
        batchProcessed = 0
        batchSucceeded = 0
        batchCurrentFile = ""
        batchSummary = ""
        message = nil
        var failures: [String] = []
        defer {
            batchActive = false
            isBusy = false
            batchCurrentFile = ""
        }

        for url in urls {
            let name = url.lastPathComponent
            batchCurrentFile = name
            do {
                let id = try await importSingle(url)
                await analyze(id, allowAppleCloud: allowAppleCloud)
                if sessions.first(where: { $0.id == id })?.report != nil {
                    batchSucceeded += 1
                } else {
                    failures.append("\(name): ошибка анализа")
                }
            } catch {
                failures.append("\(name): \(error.localizedDescription)")
            }
            batchProcessed += 1
        }
        let errors = failures.count
        batchSummary = "Обработано: \(batchSucceeded) из \(batchTotal). Ошибок: \(errors)."
        if !failures.isEmpty {
            batchSummary += " Проблемные файлы: " + failures.prefix(3).joined(separator: "; ")
            if failures.count > 3 { batchSummary += " и ещё \(failures.count - 3)." }
        }
    }

    /// Independent analysis stages: failure in the acoustic engine must not
    /// discard a valid transcription. This also identifies the failing stage.
    func analyze(_ id: UUID, allowAppleCloud: Bool) async {
        guard !isRecording, processingID == nil,
              let session = sessions.first(where: { $0.id == id }) else { return }
        processingID = id
        defer { processingID = nil }

        let original = store.audioURL(session)
        AnalysisDiagnostics.event(sessionID: id, stage: "started", info: "ext=\(original.pathExtension.lowercased())")
        var prepared: URL?
        var acoustic: AcousticValues?
        var speech: TranscriptOutput?
        var warnings: [String] = []
        var failures: [String] = []

        do {
            prepared = try await AudioPreparation.makeAnalysisCopy(from: original)
            AnalysisDiagnostics.event(sessionID: id, stage: "decode", info: "ok")
        } catch {
            failures.append("преобразование аудио")
            AnalysisDiagnostics.error(sessionID: id, stage: "decode", error: error)
            warnings.append("Не удалось преобразовать аудио; пробуем распознать оригинал.")
        }

        // Acoustic calculations are optional; they cannot prevent transcription.
        let acousticURL = prepared ?? original
        do {
            acoustic = try await Task.detached(priority: .userInitiated) {
                try AudioAnalyzer.inspect(acousticURL)
            }.value
            AnalysisDiagnostics.event(sessionID: id, stage: "acoustics", info: "ok")
        } catch {
            failures.append("измерение голоса")
            AnalysisDiagnostics.error(sessionID: id, stage: "acoustics", error: error)
            warnings.append("Акустические показатели недоступны: \(AnalysisDiagnostics.short(error)).")
        }

        // Speech recognition may work with the original M4A even when decoding
        // into CAF fails, so it is attempted independently.
        do {
            speech = try await SpeechToText.recognize(
                url: prepared ?? original,
                allowAppleCloud: allowAppleCloud
            )
            AnalysisDiagnostics.event(sessionID: id, stage: "recognition", info: "ok")
        } catch {
            failures.append("распознавание речи")
            AnalysisDiagnostics.error(sessionID: id, stage: "recognition", error: error)
            warnings.append("Не удалось распознать речь: \(AnalysisDiagnostics.short(error)).")
            if prepared != nil {
                // Second chance on the original recording, not another import.
                do {
                    speech = try await SpeechToText.recognize(
                        url: original, allowAppleCloud: allowAppleCloud
                    )
                    AnalysisDiagnostics.event(sessionID: id, stage: "recognition-original", info: "ok")
                    warnings.removeLast()
                } catch {
                    AnalysisDiagnostics.error(sessionID: id, stage: "recognition-original", error: error)
                }
            }
        }

        if let prepared { try? FileManager.default.removeItem(at: prepared) }

        guard acoustic != nil || speech != nil else {
            let detail = failures.joined(separator: ", ")
            AnalysisDiagnostics.event(sessionID: id, stage: "result", info: "failed (\(detail))")
            if !batchActive {
                message = "Не удалось обработать запись (этапы: \(detail)). Открой «Настройки → Журнал ошибок» — там есть точные коды. Исходный файл сохранён."
            }
            return
        }

        var report = Scoring.makeReport(
            text: speech?.text ?? "",
            segments: speech?.segments ?? [],
            duration: session.duration,
            acoustic: acoustic ?? AcousticValues()
        )
        if acoustic == nil {
            report.caveats.insert("Акустические метрики и оценка интонации недоступны. Их нулевые значения не являются измерениями.", at: 0)
        }
        if speech == nil {
            report.caveats.insert("Текстовые показатели не рассчитаны: распознавание речи не удалось.", at: 0)
        }
        report.caveats.insert(contentsOf: warnings, at: 0)

        do {
            let index = sessions.firstIndex(where: { $0.id == id })
            guard let index else { return }
            // Save first and then update state to prevent phantom reports.
            var updated = sessions
            updated[index].report = report
            try store.save(updated)
            sessions = updated
            AnalysisDiagnostics.event(sessionID: id, stage: "storage", info: "ok")
            if !warnings.isEmpty && !batchActive {
                message = "Анализ частично выполнен. \(warnings.joined(separator: " ")) Подробнее: «Настройки → Журнал ошибок»."
            }
        } catch {
            AnalysisDiagnostics.error(sessionID: id, stage: "storage", error: error)
            if !batchActive {
                message = "Анализ выполнен, но отчёт не сохранён. Код ошибки доступен в «Настройки → Журнал ошибок»."
            }
        }
    }

    func saveAI(_ id: UUID, value: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == id }), var report = sessions[idx].report else { return }
        report.aiComment = value
        sessions[idx].report = report
        do { try store.save(sessions) }
        catch { message = "Не удалось сохранить отзыв ИИ: \(error.localizedDescription)" }
    }

    func delete(_ id: UUID) {
        guard !isRecording && processingID == nil,
              let session = sessions.first(where: { $0.id == id }) else { return }
        do {
            // First remove metadata; keep it intact when persistence fails.
            let rest = sessions.filter { $0.id != id }
            try store.save(rest)
            sessions = rest
            if selectedID == id { selectedID = sessions.first?.id }
            try store.delete(session)
        } catch { message = "Не удалось удалить запись: \(error.localizedDescription)" }
    }

    func play(_ id: UUID) {
        guard let item = sessions.first(where: { $0.id == id }) else { return }
        NSWorkspace.shared.open(store.audioURL(item))
    }
    func reveal(_ id: UUID) {
        guard let item = sessions.first(where: { $0.id == id }) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([store.audioURL(item)])
    }
    func showFolder() { NSWorkspace.shared.open(store.root) }
    func showDiagnostics() { NSWorkspace.shared.activateFileViewerSelecting([AnalysisDiagnostics.logURL]) }
}
