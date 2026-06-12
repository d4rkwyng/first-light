import AVFoundation

/// P2: decode a real ACI tape recording (.wav/.aiff/.mp3) back into
/// bytes — cycle-length FSK detection, the way the ACI hardware did it.
enum TapeDecoder {
    enum DecodeError: Error { case unreadable, noData }

    static func decode(url: URL) throws -> [UInt8] {
        let file = try AVAudioFile(forReading: url)
        guard let format = AVAudioFormat(standardFormatWithSampleRate:
                file.processingFormat.sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format,
                frameCapacity: AVAudioFrameCount(file.length))
        else { throw DecodeError.unreadable }
        try file.read(into: buffer)
        guard let data = buffer.floatChannelData?[0],
              buffer.frameLength > 1000 else { throw DecodeError.noData }
        let rate = file.processingFormat.sampleRate
        let n = Int(buffer.frameLength)

        // HALF-period durations via every zero crossing — matching the
        // strict-alternation encoding (leader 565/455, sync 385, bit
        // halves 250 ("1") / 500 ("0")).
        var halves: [Double] = []
        var lastCross = -1
        var prev = data[0]
        for i in 1..<n {
            let cur = data[i]
            if (prev <= 0) != (cur <= 0) {
                if lastCross >= 0 {
                    halves.append(Double(i - lastCross) / rate * 1_000_000)
                }
                lastCross = i
            }
            prev = cur
        }

        // skip the leader (455/565 µs phases); the start bit is the
        // first SHORT phase (~192 µs), two phases long
        var i = 0
        while i < halves.count, halves[i] > 360 { i += 1 }
        guard i + 1 < halves.count else { throw DecodeError.noData }
        i += 2 // past both start-bit phases
        // bit halves: ~500 µs = 1, ~250 µs = 0 (the ROM's polarity)
        var bits: [Bool] = []
        while i + 1 < halves.count {
            let a = halves[i]
            guard a < 540 else { break } // postamble reached
            bits.append(a >= 360)
            i += 2
        }
        var bytes: [UInt8] = []
        for chunk in stride(from: 0, to: bits.count - bits.count % 8, by: 8) {
            var byte: UInt8 = 0
            for bit in 0..<8 where bits[chunk + bit] {
                byte |= 1 << (7 - bit)
            }
            bytes.append(byte)
        }
        guard !bytes.isEmpty else { throw DecodeError.noData }
        return bytes
    }
}
