import Foundation
import AVFoundation
import CryptoKit

@main
struct AudioPipelineRegression {
    static func main() async throws {
        guard CommandLine.arguments.count > 1 else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Pass fixture file paths."])
        }

        for path in CommandLine.arguments.dropFirst() {
            let source = URL(fileURLWithPath: path)
            let before = SHA256.hash(data: try Data(contentsOf: source))
            let prepared = try await AudioPreparation.makeAnalysisCopy(from: source)
            defer { try? FileManager.default.removeItem(at: prepared) }

            let audio = try AVAudioFile(forReading: prepared)
            guard audio.length > 0 else { fatalError("Decoded file empty: \(path)") }
            guard abs(audio.processingFormat.sampleRate - 16000) < 1 else {
                fatalError("Sample rate not normalized: \(path)")
            }
            guard audio.processingFormat.channelCount == 1 else {
                fatalError("Not mono: \(path)")
            }
            let buffer = AVAudioPCMBuffer(pcmFormat: audio.processingFormat, frameCapacity: 4096)!
            try audio.read(into: buffer)
            guard buffer.frameLength > 0, buffer.floatChannelData != nil else {
                fatalError("Cannot read float samples: \(path)")
            }
            // Also exercise the exact acoustic analyzer used in the app.
            let result = try AudioAnalyzer.inspect(prepared)
            guard result.speechSeconds >= 0 else { fatalError("Invalid analyzer output") }
            let after = SHA256.hash(data: try Data(contentsOf: source))
            guard before == after else { fatalError("Source was modified: \(path)") }

            print("PASS: \(source.lastPathComponent) -> mono PCM 16 kHz, \(audio.length) frames")
        }

        let empty = FileManager.default.temporaryDirectory
            .appendingPathComponent("speech-sculptor-zero-\(UUID().uuidString).wav")
        FileManager.default.createFile(atPath: empty.path, contents: Data())
        defer { try? FileManager.default.removeItem(at: empty) }
        do {
            _ = try await AudioPreparation.makeAnalysisCopy(from: empty)
            fatalError("Expected empty-file error")
        } catch AudioPreparation.Failure.emptyFile {
            print("PASS: empty-file diagnostic")
        }
        print("Audio pipeline regression suite passed")
    }
}
