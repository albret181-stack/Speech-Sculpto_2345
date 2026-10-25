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

    func analyze(_ id: UUID, allowAppleCloud: Bool) async {
        guard !isRecording, processingID == nil,
              let session = sessions.first(where: { $0.id == id }) else { return }
        processingID = id
        defer { processingID = nil }
        let original = store.audioURL(session)
        var prepared: URL?
        do {
            // Normalize even existing recordings so AAC, stereo and non-standard
            // input sample rates do not reach AVAudioFile directly.
            let normalized = try await AudioPreparation.makeAnalysisCopy(from: original)
            prepared = normalized
            defer { try? FileManager.default.removeItem(at: normalized) }
            let acoustic = try await Task.detached(priority: .userInitiated) {
                try AudioAnalyzer.inspect(normalized)
            }.value

            var transcript = ""
            var segments: [SpeechSegment] = []
            var warning: String?
            do {
                let speech = try await SpeechToText.recognize(
                    url: normalized, allowAppleCloud: allowAppleCloud
                )
                transcript = speech.text
                segments = speech.segments
            } catch { warning = error.localizedDescription }

            var report = Scoring.makeReport(
                text: transcript, segments: segments,
                duration: session.duration, acoustic: acoustic
            )
            if let warning {
                report.caveats.insert("Расшифровка недоступна: \(warning). Текстовые метрики не рассчитаны.", at: 0)
            }
            if let idx = sessions.firstIndex(where: { $0.id == id }) {
                sessions[idx].report = report
                try store.save(sessions)
            }
            if let warning, !batchActive { message = warning }
        } catch {
            if !batchActive {
                message = "Не удалось подготовить аудио: \(error.localizedDescription). Исходная запись сохранена."
            }
        }
        if let prepared { try? FileManager.default.removeItem(at: prepared) }
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
}
