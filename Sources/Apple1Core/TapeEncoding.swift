import Foundation

/// The ACI tape format, as one list of phase durations (µs). Strictly
/// alternating polarity — the leader's asymmetric cycles, the short
/// sync phase, then two phases per bit (1 = 2 kHz, 0 = 1 kHz), MSB
/// first. Shared by the audio synthesizer (SoundEngine) and the
/// cycle-timed bus playback (Apple1.armTape) so a tape sounds and
/// LOADS identically.
public enum TapeEncoding {
    /// (durations in µs; polarity alternates starting HIGH)
    public static func phases(bytes: [UInt8],
                              leaderSeconds: Double,
                              speed: Double = 1.0,
                              byteGapUs: Double = 0) -> [Double] {
        var out: [Double] = []
        defer { }
        let leaderCycles = Int(leaderSeconds * 1_000_000 / 1020)
        for _ in 0..<leaderCycles {
            out.append(565)
            out.append(455)
        }
        out.append(385) // the short sync phase
        for byte in bytes {
            var first = true
            for bit in (0..<8).reversed() {
                let half = (byte >> bit) & 1 == 1 ? 250.0 : 500.0
                // the real writer's per-byte overhead stretches each
                // byte's first phase — the reader needs that allowance
                out.append(first ? half + byteGapUs : half)
                first = false
                out.append(half)
            }
        }
        // postamble: the last data phase needs a closing edge
        for _ in 0..<3 {
            out.append(565)
            out.append(455)
        }
        return out.map { $0 / speed }
    }

    /// Phase boundaries as CPU-cycle timestamps (1.0227 MHz).
    public static func transitions(bytes: [UInt8],
                                    leaderSeconds: Double,
                                    speed: Double = 1.0,
                                    byteGapUs: Double = 0) -> [UInt64] {
        var t: Double = 0
        var out: [UInt64] = []
        for phase in phases(bytes: bytes, leaderSeconds: leaderSeconds,
                            speed: speed, byteGapUs: byteGapUs) {
            t += phase * 1.0227
            out.append(UInt64(t))
        }
        return out
    }
}
