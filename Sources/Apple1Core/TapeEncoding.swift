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
        // the start bit: one full SHORT cycle (~385 µs total) — wozaci
        // detects it with a ~364 µs phase window (LDY #31)
        out.append(192.5)
        out.append(192.5)
        // Bit polarity per the ROM's own reader (CPY #128 carry → ROL):
        // a LONG cycle (1 kHz) is a 1, a SHORT cycle (2 kHz) is a 0.
        // (The summary tables that say "1 = 2 kHz" disagree with the
        // code; the code wins.)
        for byte in bytes {
            for bit in (0..<8).reversed() {
                let half = (byte >> bit) & 1 == 1 ? 500.0 : 250.0
                out.append(half)
                out.append(half)
            }
        }
        _ = byteGapUs // reader self-compensates (thresholds 58/57/53)
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
