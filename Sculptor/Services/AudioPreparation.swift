import Foundation
import AVFoundation
import CoreMedia
import AudioToolbox

/// Decodes any supported input audio into a predictable mono 16 kHz PCM CAF.
/// Originals are never modified; converted files are temporary and cleaned up.
enum AudioPreparation {
    enum Failure: LocalizedError {
        case missingFile, emptyFile, missingTrack, readerUnavailable, noSamples, pcmCopyFailed(Int32), readFailed(String)
        var errorDescription: String? {
            switch self {
            case .missingFile: return "Исходный аудиофайл не найден. Проверь его в истории записей."
            case .emptyFile: return "Аудиофайл пуст. Попробуй импортировать другую копию."
            case .missingTrack: return "В файле не обнаружена аудиодорожка."
            case .readerUnavailable: return "Не удалось открыть аудиодорожку для преобразования."
            case .noSamples: return "Файл открылся, но в нём нет декодируемых звуковых данных."
            case .pcmCopyFailed(let code): return "Не удалось преобразовать звуковые данные (код \(code))."
            case .readFailed(let reason): return "Ошибка декодирования аудио: \(reason)"
            }
        }
    }

    static func makeAnalysisCopy(from source: URL) async throws -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path) else { throw Failure.missingFile }
        let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0 else { throw Failure.emptyFile }

        let asset = AVURLAsset(url: source)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw Failure.missingTrack
        }
        let target = fm.temporaryDirectory.appendingPathComponent("SpeechSculptor-\(UUID().uuidString).caf")
        do {
            try await Task.detached(priority: .userInitiated) {
                try decode(asset: asset, track: track, target: target)
            }.value
            // A complete and readable file is required before analysis starts.
            let check = try AVAudioFile(forReading: target, commonFormat: .pcmFormatFloat32, interleaved: false)
            guard check.length > 0 else { throw Failure.noSamples }
            return target
        } catch {
            try? fm.removeItem(at: target)
            throw error
        }
    }

    private static func decode(asset: AVURLAsset, track: AVAssetTrack, target: URL) throws {
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                         sampleRate: 16_000, channels: 1, interleaved: true)!
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        guard reader.canAdd(output) else { throw Failure.readerUnavailable }
        reader.add(output)
        guard reader.startReading() else {
            throw Failure.readFailed(reader.error?.localizedDescription ?? "AVAssetReader не запустился.")
        }
        var framesWritten = 0
        do {
            let file = try AVAudioFile(forWriting: target,
                                       settings: outputFormat.settings,
                                       commonFormat: .pcmFormatInt16,
                                       interleaved: true)
            while let sample = output.copyNextSampleBuffer() {
                let count = CMSampleBufferGetNumSamples(sample)
                guard count > 0 else { continue }
                guard let pcm = AVAudioPCMBuffer(
                    pcmFormat: outputFormat,
                    frameCapacity: AVAudioFrameCount(count)
                ) else { throw Failure.readerUnavailable }
                pcm.frameLength = AVAudioFrameCount(count)
                let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
                    sample, at: 0, frameCount: Int32(count),
                    into: pcm.mutableAudioBufferList
                )
                guard status == noErr else { throw Failure.pcmCopyFailed(status) }
                try file.write(from: pcm)
                framesWritten += count
            }
        } catch {
            reader.cancelReading()
            throw error
        }
        guard reader.status == .completed else {
            throw Failure.readFailed(reader.error?.localizedDescription ?? "Декодирование не завершено.")
        }
        guard framesWritten > 0 else { throw Failure.noSamples }
    }
}
