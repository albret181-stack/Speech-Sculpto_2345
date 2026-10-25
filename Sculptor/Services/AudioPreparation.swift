import Foundation
import AVFoundation
import AudioToolbox

/// Safely converts imported or microphone audio to mono 16 kHz float PCM in CAF.
/// The original file is never overwritten.
/// ExtAudioFile decodes compressed AAC/MP3 and PCM and does the sample-rate/channel conversion.
enum AudioPreparation {
    enum Failure: LocalizedError {
        case missingFile
        case emptyFile
        case emptyDecodedFile
        case audioToolbox(String, OSStatus)
        case fileSystem(String)

        var errorDescription: String? {
            switch self {
            case .missingFile:
                return "Исходная запись не найдена. Открой её расположение через Историю."
            case .emptyFile:
                return "Аудиофайл пуст. Проверь, завершилась ли запись."
            case .emptyDecodedFile:
                return "Декодирование завершено, но в аудио нет звуковых сэмплов."
            case .audioToolbox(let stage, let code):
                return "Ошибка обработки звука на этапе «\(stage)» (OSStatus \(code))."
            case .fileSystem(let stage):
                return "Не удалось подготовить аудиофайл: \(stage)."
            }
        }
    }

    private static func checked(_ code: OSStatus, _ stage: String) throws {
        guard code == noErr else { throw Failure.audioToolbox(stage, code) }
    }

    static func makeAnalysisCopy(from source: URL) async throws -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path) else { throw Failure.missingFile }
        guard (try source.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0 > 0
        else { throw Failure.emptyFile }

        let target = fm.temporaryDirectory.appendingPathComponent(
            "SpeechSculptor-\(UUID().uuidString).caf"
        )
        do {
            try await Task.detached(priority: .userInitiated) {
                try decode(source: source, target: target)
            }.value
            return target
        } catch {
            try? fm.removeItem(at: target)
            throw error
        }
    }

    private static func decode(source: URL, target: URL) throws {
        var input: ExtAudioFileRef?
        try checked(ExtAudioFileOpenURL(source as CFURL, &input), "открытие аудио")
        guard let input else { throw Failure.fileSystem("не создан объект чтения") }
        defer { ExtAudioFileDispose(input) }

        // Decode with ExtAudioFile and write float32 PCM using AVAudioFile to guarantee readable file structure.
        var pcm = AudioStreamBasicDescription(
            mSampleRate: 16_000,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked |
                          kAudioFormatFlagsNativeEndian,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        try checked(
            ExtAudioFileSetProperty(
                input, kExtAudioFileProperty_ClientDataFormat,
                UInt32(MemoryLayout<AudioStreamBasicDescription>.size), &pcm
            ),
            "настройка декодера и преобразования в моно 16 кГц"
        )

        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                   sampleRate: 16_000, channels: 1, interleaved: false)!
        let writer = try AVAudioFile(forWriting: target, settings: format.settings,
                                     commonFormat: .pcmFormatFloat32, interleaved: false)

        let frameCount = 8192
        var samples = [Float](repeating: 0, count: frameCount)
        var totalFrames: Int64 = 0
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)),
              let floatData = buffer.floatChannelData else {
            throw Failure.fileSystem("не удалось создать буфер звука")
        }
        while true {
            var frames = UInt32(frameCount)
            try samples.withUnsafeMutableBufferPointer { values in
                var list = AudioBufferList(
                    mNumberBuffers: 1,
                    mBuffers: AudioBuffer(
                        mNumberChannels: 1,
                        mDataByteSize: UInt32(frameCount * MemoryLayout<Float>.size),
                        mData: values.baseAddress
                    )
                )
                try checked(ExtAudioFileRead(input, &frames, &list), "чтение звуковых сэмплов")
            }
            if frames == 0 { break }
            buffer.frameLength = AVAudioFrameCount(frames)
            samples.withUnsafeBufferPointer { data in
                if let pointer = data.baseAddress {
                    floatData[0].update(from: pointer, count: Int(frames))
                }
            }
            try writer.write(from: buffer)
            totalFrames += Int64(frames)
        }
        guard totalFrames > 0 else { throw Failure.emptyDecodedFile }
    }
}
