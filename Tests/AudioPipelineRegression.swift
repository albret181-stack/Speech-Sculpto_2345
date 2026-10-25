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
            print("TEST SOURCE \(source.lastPathComponent)")
            fflush(stdout)
            let before = SHA256.hash(data: try Data(contentsOf: source))
            let prepared: URL
            do { prepared = try await AudioPreparation.makeAnalysisCopy(from: source) }
            catch { print("FAILED PREPARE \(source.lastPathComponent): \(error)"); throw error }
            print("PREPARED \(source.lastPathComponent)")
            fflush(stdout)
            defer { try? FileManager.default.removeItem(at: prepared) }

            print("OPEN PREPARED \(prepared.path)")
            fflush(stdout)
            let audio: AVAudioFile
            do { audio = try AVAudioFile(forReading: prepared) }
            catch { print("FAILED OPEN CAF \(source.lastPathComponent): \(error)"); fflush(stdout); throw error }
            guard audio.length > 0 else { fatalError("Decoded file empty: \(path)") }
            guard abs(audio.processingFormat.sampleRate - 16000) < 1 else {
                fatalError("Sample rate not normalized: \(path)")
            }
            guard audio.processingFormat.channelCount == 1 else {
                fatalError("Not mono: \(path)")
            }
            print("OPEN OK format \(audio.processingFormat)")
            fflush(stdout)
            let buffer = AVAudioPCMBuffer(pcmFormat: audio.processingFormat, frameCapacity: 4096)!
            do { try audio.read(into: buffer) }
            catch { print("FAILED PCM READ \(source.lastPathComponent): \(error)"); fflush(stdout); throw error }
            print("PCM READ OK")
            fflush(stdout)
            guard buffer.frameLength > 0, buffer.floatChannelData != nil else {
                fatalError("Cannot read float samples: \(path)")
            }
            // Also exercise the exact acoustic analyzer used in the app.
            let result: AcousticValues
            do { result = try AudioAnalyzer.inspect(prepared) }
            catch { print("FAILED ACOUSTICS \(source.lastPathComponent): \(error)"); throw error }
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
