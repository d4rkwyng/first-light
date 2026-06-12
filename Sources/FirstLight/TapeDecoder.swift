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

        // full-cycle durations in µs via positive-going zero crossings
        var cycles: [Double] = []
        var lastCross = -1
        var prev = data[0]
        for i in 1..<n {
            let cur = data[i]
            if prev <= 0, cur > 0 {
                if lastCross >= 0 {
                    cycles.append(Double(i - lastCross) / rate * 1_000_000)
                }
                lastCross = i
            }
            prev = cur
        }

        // leader: ~1 kHz cycles. Data: "1" ≈ 500 µs, "0" ≈ 1000 µs.
        // The leader/0 ambiguity resolves at the first SHORT cycle —
        // everything after it is data (skip the merged sync cycle).
        guard let firstShort = cycles.firstIndex(where: { $0 < 720 })
        else { throw DecodeError.noData }
        var bits: [Bool] = []
        for cycle in cycles[(firstShort + 1)...] {
            guard cycle < 1500 else { break } // trailing silence/noise
            bits.append(cycle < 720)
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
