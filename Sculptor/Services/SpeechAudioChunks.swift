import Foundation
import AVFoundation

/// PCM chunks for Apple's short Speech tasks. The returned CAF is fully closed
/// and validated before Speech is allowed to open it.
enum SpeechAudioChunks {
    enum ChunkError: LocalizedError {
        case invalidRange, emptyChunk, incompleteChunk
        var errorDescription: String? {
            switch self {
            case .invalidRange: return "Неверный диапазон аудиофрагмента."
            case .emptyChunk: return "Аудиофрагмент оказался пустым."
            case .incompleteChunk: return "Аудиофрагмент не удалось записать полностью."
            }
        }
    }

    static func makeChunk(from source: AVAudioFile,
                          at startFrame: AVAudioFramePosition,
                          frameCount: AVAudioFramePosition) throws -> URL {
        guard startFrame >= 0, frameCount > 0, startFrame < source.length,
              frameCount <= source.length - startFrame else { throw ChunkError.invalidRange }

        let target = FileManager.default.temporaryDirectory
            .appendingPathComponent("speechsculptor-chunk-\(UUID().uuidString).caf")
        do {
            // The writer must be released before we reopen its header.
            // In the previous code it was still alive when recognition started.
            try writeAndClose(source: source, at: startFrame,
                              frameCount: frameCount, destination: target)
            let check = try AVAudioFile(forReading: target)
            guard check.length > 0 else { throw ChunkError.emptyChunk }
            guard check.length == frameCount else { throw ChunkError.incompleteChunk }
            let requested = AVAudioFrameCount(min(check.length, 2048))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: check.processingFormat, frameCapacity: requested) else {
                throw ChunkError.emptyChunk
            }
            try check.read(into: buffer, frameCount: requested)
            guard buffer.frameLength > 0 else { throw ChunkError.emptyChunk }
            return target
        } catch {
            try? FileManager.default.removeItem(at: target)
            throw error
        }
    }

    private static func writeAndClose(source: AVAudioFile,
                                      at startFrame: AVAudioFramePosition,
                                      frameCount: AVAudioFramePosition,
                                      destination: URL) throws {
        let format = source.processingFormat
        let writer = try AVAudioFile(forWriting: destination,
                                     settings: format.settings,
                                     commonFormat: format.commonFormat,
                                     interleaved: format.isInterleaved)
        source.framePosition = startFrame
        var remaining = frameCount
        while remaining > 0 {
            let amount = AVAudioFrameCount(min(AVAudioFramePosition(8192), remaining))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: amount) else {
                throw ChunkError.emptyChunk
            }
            try source.read(into: buffer, frameCount: amount)
            guard buffer.frameLength > 0 else { throw ChunkError.incompleteChunk }
            try writer.write(from: buffer)
            remaining -= AVAudioFramePosition(buffer.frameLength)
        }
    }
}
