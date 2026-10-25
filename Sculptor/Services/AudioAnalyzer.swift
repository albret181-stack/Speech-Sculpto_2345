import Foundation
import AVFoundation

/// Acoustic heuristics only. These values are not a clinical voice assessment.
enum AudioAnalyzer {
    enum AudioError: LocalizedError {
        case unreadableAudio
        var errorDescription: String? { "Не удалось декодировать аудио для акустического анализа." }
    }

    static func inspect(_ url: URL) throws -> AcousticValues {
        let file = try AVAudioFile(forReading: url)
        let fmt = file.processingFormat
        guard fmt.sampleRate > 0 else { throw AudioError.unreadableAudio }
        let step = max(1, Int((fmt.sampleRate / 8000).rounded()))
        let rate = fmt.sampleRate / Double(step)
        let chunkSize: AVAudioFrameCount = 8192
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: chunkSize) else { throw AudioError.unreadableAudio }
        var reduced: [Float] = []
        reduced.reserveCapacity(Int(Double(file.length) / Double(step)) + 1)
        var offset = 0
        while file.framePosition < file.length {
            let remaining = file.length - file.framePosition
            let requested = AVAudioFrameCount(min(AVAudioFramePosition(chunkSize), remaining))
            guard requested > 0 else { break }
            do {
                try file.read(into: buf, frameCount: requested)
            } catch {
                throw AudioError.unreadableAudio
            }
            let count = Int(buf.frameLength)
            guard count > 0 else { break }
            guard let data = buf.floatChannelData else { throw AudioError.unreadableAudio }
            for idx in 0..<count where (offset + idx) % step == 0 {
                var mix: Float = 0
                for channel in 0..<Int(fmt.channelCount) { mix += data[channel][idx] }
                reduced.append(mix / Float(fmt.channelCount))
            }
            offset += count
        }
        guard !reduced.isEmpty else { return AcousticValues() }
        let frame = max(1, Int(rate * 0.10))
        var rms: [Double] = []
        rms.reserveCapacity(reduced.count / frame + 1)
        for start in stride(from: 0, to: reduced.count, by: frame) {
            let end = min(reduced.count, start + frame)
            var power = 0.0
            for i in start..<end { power += Double(reduced[i]) * Double(reduced[i]) }
            rms.append(sqrt(power / Double(end - start)))
        }
        let dbs = rms.map { 20 * log10(max($0, 0.0000001)) }
        let sorted = dbs.sorted()
        let floorDB = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.20))]
        let threshold = max(-42.0, floorDB + 9)
        let voiced = dbs.map { $0 > threshold }
        var speechBlocks = 0
        var pauseBlocks = 0
        var pauses = 0
        var hasSpoken = false
        for active in voiced {
            if active {
                if hasSpoken && pauseBlocks >= 3 { pauses += 1 }
                pauseBlocks = 0
                speechBlocks += 1
                hasSpoken = true
            } else if hasSpoken { pauseBlocks += 1 }
        }
        // End silence is not a conversational pause.
        var pitches: [Double] = []
        let spacing = max(1, Int(rate * 0.50))
        let window = max(300, Int(rate * 0.065))
        if reduced.count > window {
            for start in stride(from: 0, through: reduced.count - window, by: spacing) {
                let frameNo = min(voiced.count - 1, Int(Double(start) / rate / 0.10))
                if !voiced[frameNo] { continue }
                if let hz = estimatePitch(samples: reduced, start: start, size: window, sampleRate: rate), hz > 70, hz < 400 {
                    pitches.append(hz)
                }
            }
        }
        var pitchRange: Double?
        if pitches.count >= 15 {
            let st = pitches.map { 12 * log2($0 / 100.0) }.sorted()
            pitchRange = st[Int(Double(st.count - 1) * 0.90)] - st[Int(Double(st.count - 1) * 0.10)]
        }
        return AcousticValues(speechSeconds: Double(speechBlocks) * 0.1, pauses: pauses,
                              pitchRange: pitchRange, pitchSamples: pitches.count)
    }

    private static func estimatePitch(samples: [Float], start: Int, size: Int, sampleRate: Double) -> Double? {
        // Simple normalized autocorrelation. Rejects noisy and weakly periodic windows.
        let minLag = max(1, Int(sampleRate / 400))
        let maxLag = min(size / 2, Int(sampleRate / 75))
        guard minLag < maxLag else { return nil }
        var best = 0.0
        var bestLag = 0
        for lag in minLag...maxLag {
            var numerator = 0.0
            var aa = 0.0
            var bb = 0.0
            for i in 0..<(size - lag) {
                let a = Double(samples[start + i])
                let b = Double(samples[start + i + lag])
                numerator += a * b
                aa += a * a
                bb += b * b
            }
            let correlation = numerator / sqrt(max(aa * bb, 1e-12))
            if correlation > best { best = correlation; bestLag = lag }
        }
        return best > 0.74 && bestLag > 0 ? sampleRate / Double(bestLag) : nil
    }
}
