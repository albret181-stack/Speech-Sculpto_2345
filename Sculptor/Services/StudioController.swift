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

    func importAudio(_ url: URL) async {
        guard !isRecording && !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.lowercased()
        guard ["m4a", "mp3", "wav", "caf", "aiff", "aif"].contains(ext) else {
            message = "Поддерживаются M4A, MP3, WAV, CAF и AIFF."
            return
        }
        do {
            let id = UUID()
            let destination = try store.newAudioURL(id, ext: ext)
            try FileManager.default.copyItem(at: url, to: destination)
            let asset = AVURLAsset(url: destination)
            let duration = (try? await asset.load(.duration).seconds) ?? 0
            let item = SpeechSession(id: id,
                                     title: url.deletingPathExtension().lastPathComponent,
                                     createdAt: Date(), duration: max(0, duration),
                                     relativeAudioPath: "Recordings/\(id.uuidString)/audio.\(ext)",
                                     isPractice: false, report: nil)
            sessions.insert(item, at: 0)
            selectedID = id
            try store.save(sessions)
            message = "Файл импортирован. Нажми «Анализировать», чтобы получить разбор."
        } catch { message = "Не удалось импортировать файл: \(error.localizedDescription)" }
    }

    func analyze(_ id: UUID, allowAppleCloud: Bool) async {
        guard !isRecording, processingID == nil,
              let session = sessions.first(where: { $0.id == id }) else { return }
        processingID = id
        defer { processingID = nil }
        let url = store.audioURL(session)
        do {
            let acoustic = try await Task.detached(priority: .userInitiated) {
                try AudioAnalyzer.inspect(url)
            }.value
            var text = ""
            var words: [SpeechSegment] = []
            var warning: String?
            do {
                let transcript = try await SpeechToText.recognize(url: url, allowAppleCloud: allowAppleCloud)
                text = transcript.text
                words = transcript.segments
            } catch { warning = error.localizedDescription }
            var report = Scoring.makeReport(text: text, segments: words, duration: session.duration, acoustic: acoustic)
            if let warning {
                report.caveats.insert("Расшифровка недоступна: \(warning). Текстовые метрики не рассчитаны.", at: 0)
            }
            if let idx = sessions.firstIndex(where: { $0.id == id }) {
                sessions[idx].report = report
                try store.save(sessions)
            }
            if let warning { message = warning }
        } catch { message = "Не удалось обработать аудио: \(error.localizedDescription)" }
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
