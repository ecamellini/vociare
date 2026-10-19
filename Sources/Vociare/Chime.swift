import AppKit

/// Soft two-note chimes: rising when recording starts, falling when it stops. Synthesized so no sound files ship.
@MainActor
enum Chime {
    private static let low = 659.25  // E5
    private static let high = 987.77  // B5
    static let start = make([low, high])
    static let stop = make([high, low])

    private static func make(_ frequencies: [Double]) -> NSSound? {
        let sampleRate = 44_100.0
        let noteSpacing = 0.075
        let length = noteSpacing * Double(frequencies.count) + 0.25
        let samples = (0..<Int(sampleRate * length)).map { index -> Int16 in
            let time = Double(index) / sampleRate
            let value = frequencies.enumerated().reduce(0.0) { sum, note in
                let noteTime = time - Double(note.offset) * noteSpacing
                guard noteTime >= 0 else { return sum }
                // Fast attack and exponential decay, with a quiet octave overtone, sound like a soft bell.
                let envelope = min(noteTime / 0.004, 1) * exp(-noteTime * 22)
                let tone = sin(2 * .pi * note.element * noteTime) + 0.25 * sin(4 * .pi * note.element * noteTime)
                return sum + tone * envelope
            }
            return Int16(max(-1, min(1, value * 0.18)) * Double(Int16.max))
        }
        return NSSound(data: wav(samples, sampleRate: Int(sampleRate)))
    }

    private static func wav(_ samples: [Int16], sampleRate: Int) -> Data {
        func bytes<T: FixedWidthInteger>(_ value: T) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
        let dataSize = UInt32(samples.count * MemoryLayout<Int16>.size)
        let header: [Data] = [
            Data("RIFF".utf8), bytes(36 + dataSize), Data("WAVEfmt ".utf8),
            bytes(UInt32(16)), bytes(UInt16(1)), bytes(UInt16(1)),  // PCM, mono
            bytes(UInt32(sampleRate)), bytes(UInt32(sampleRate * 2)), bytes(UInt16(2)), bytes(UInt16(16)),
            Data("data".utf8), bytes(dataSize),
        ]
        return header.reduce(Data(), +) + samples.withUnsafeBytes { Data($0) }
    }
}
