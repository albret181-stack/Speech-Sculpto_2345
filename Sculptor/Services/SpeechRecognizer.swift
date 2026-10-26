import Foundation
import AVFoundation
import Speech

struct TranscriptOutput {
    let text: String
    let segments: [SpeechSegment]
}

enum SpeechToText {
    enum TranscriptError: LocalizedError {
        case missingPermission, languageUnavailable, offlineUnavailable, emptyTranscript
        var errorDescription: String? {
            switch self {
            case .missingPermission: return "Разреши распознавание речи в Системных настройках → Конфиденциальность → Распознавание речи."
            case .languageUnavailable: return "Русское распознавание Apple сейчас недоступно на этом Mac."
            case .offlineUnavailable: return "Локальное распознавание русского языка недоступно на этом Mac. В настройках можно разрешить распознавание Apple через интернет."
            case .emptyTranscript: return "Речь не распознана. Проверь, что запись содержит понятную речь."
            }
        }
    }

    static func recognize(url: URL, allowAppleCloud: Bool) async throws -> TranscriptOutput {
        let permission = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard permission == .authorized else { throw TranscriptError.missingPermission }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ru-RU")), recognizer.isAvailable else {
            throw TranscriptError.languageUnavailable
        }
        guard recognizer.supportsOnDeviceRecognition || allowAppleCloud else { throw TranscriptError.offlineUnavailable }

        // Apple's recognizer can impose short-task limits. Slice long audio into
        // approximately 45-second PCM chunks, but retain timestamps in the original file.
        let audio = try AVAudioFile(forReading: url)
        let chunkFrames = max(1, AVAudioFramePosition(audio.processingFormat.sampleRate * 30))
        if audio.length <= chunkFrames { return try await recognizeSingle(url: url, using: recognizer) }
        var fullText: [String] = []
        var words: [SpeechSegment] = []
        var position: AVAudioFramePosition = 0
        while position < audio.length {
            let count = min(chunkFrames, audio.length - position)
            let destination = try SpeechAudioChunks.makeChunk(from: audio, at: position, frameCount: count)
            let chunk: TranscriptOutput
            do {
                chunk = try await recognizeSingle(url: destination, using: recognizer)
            } catch {
                try? FileManager.default.removeItem(at: destination)
                throw error
            }
            try? FileManager.default.removeItem(at: destination)
            fullText.append(chunk.text)
            let offset = Double(position) / audio.processingFormat.sampleRate
            words.append(contentsOf: chunk.segments.map { SpeechSegment(word: $0.word, start: $0.start + offset, duration: $0.duration) })
            position += count
        }
        return TranscriptOutput(text: fullText.joined(separator: " "), segments: words)
    }

    private static func recognizeSingle(url: URL, using recognizer: SFSpeechRecognizer) async throws -> TranscriptOutput {
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.taskHint = .dictation
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TranscriptOutput, Error>) in
            var finished = false
            var task: SFSpeechRecognitionTask?
            task = recognizer.recognitionTask(with: request) { result, error in
                if finished { return }
                if let error {
                    finished = true
                    continuation.resume(throwing: error)
                    task?.cancel()
                    return
                }
                guard let result, result.isFinal else { return }
                finished = true
                let segments = result.bestTranscription.segments.map {
                    SpeechSegment(word: $0.substring, start: $0.timestamp, duration: $0.duration)
                }
                let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty { continuation.resume(throwing: TranscriptError.emptyTranscript) }
                else { continuation.resume(returning: TranscriptOutput(text: text, segments: segments)) }
                task?.cancel()
            }
            _ = task
        }
    }
}
