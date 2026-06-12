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

        // skip the leader, find the sync phase (~385 µs)
        var i = 0
        while i < halves.count, !(330...430).contains(halves[i]) { i += 1 }
        guard i < halves.count else { throw DecodeError.noData }
        i += 1 // past sync
        // read bit halves in pairs; the postamble's long leader-like
        // phases produce <8 stray bits that the %8 trim discards
        var bits: [Bool] = []
        while i + 1 < halves.count {
            let a = halves[i]
            guard a < 620 else { break } // postamble reached
            bits.append(a < 330)
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
