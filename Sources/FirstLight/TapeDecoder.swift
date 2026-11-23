import AVFoundation

/// P2: decode a real ACI tape recording (.wav/.aiff/.mp3) back into
/// bytes — cycle-length FSK detection, the way the ACI hardware did it.
enum TapeDecoder {
    enum DecodeError: Error, Equatable {
        case unreadable, noData
        /// Longer than `maxSeconds`: a 64 KB tape is under seven minutes.
        case tooLong(seconds: Int)
        /// Decoded to more bytes than the Apple-1 can address.
        case tooLarge(bytes: Int)
    }

    /// A full 64 KB image takes ~6.6 minutes at the ACI's bit rate (plus
    /// leader); anything much longer isn't an Apple-1 tape.
    static let maxSeconds: Double = 10 * 60

    /// Frames read per chunk — memory stays bounded however long the file.
    private static let chunkFrames: AVAudioFrameCount = 1 << 16

    static func decode(url: URL, maxSeconds: Double = maxSeconds,
                       maxBytes: Int = 0x10000) throws -> [UInt8] {
        let file = try AVAudioFile(forReading: url)
        // processingFormat is deinterleaved Float32 at the file's own rate
        // and channel count, so stereo captures read fine; channel 0 is used.
        let format = file.processingFormat
        let rate = format.sampleRate
        guard rate > 0 else { throw DecodeError.unreadable }
        let seconds = Double(file.length) / rate
        guard seconds <= maxSeconds else {
            throw DecodeError.tooLong(seconds: Int(seconds))
        }
        guard file.length > 1000 else { throw DecodeError.noData }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: chunkFrames)
        else { throw DecodeError.unreadable }

        // HALF-period durations via every zero crossing — matching the
        // strict-alternation encoding (leader 565/455, sync 385, bit
        // halves 250 ("0") / 500 ("1")).
        var halves: [Double] = []
        var lastCross = -1
        var prev: Float?
        var base = 0 // absolute frame index of the chunk's first sample
        while file.framePosition < file.length {
            try Task.checkCancellation() // STOP/RESET/another tape: quit early
            try file.read(into: buffer, frameCount: chunkFrames)
            let n = Int(buffer.frameLength)
            guard n > 0, let data = buffer.floatChannelData?[0] else { break }
            for j in 0..<n {
                let cur = data[j]
                if let p = prev, (p <= 0) != (cur <= 0) {
                    let i = base + j
                    if lastCross >= 0 {
                        halves.append(Double(i - lastCross) / rate * 1_000_000)
                    }
                    lastCross = i
                }
                prev = cur
            }
            base += n
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
        let byteCount = bits.count / 8
        guard byteCount <= maxBytes else {
            throw DecodeError.tooLarge(bytes: byteCount)
        }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(byteCount)
        for chunk in stride(from: 0, to: byteCount * 8, by: 8) {
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
