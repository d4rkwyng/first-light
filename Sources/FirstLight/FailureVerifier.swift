import Foundation
import Apple1Core

/// Verifies the board fails the way a real Apple-1 failed when parts
/// are pulled. `FirstLight --verify-failures`. Each scenario builds a
/// fresh machine, removes one thing, and asserts the observable 1976
/// consequence.
@MainActor
enum FailureVerifier {
    static func run() -> Never {
        var failures = 0
        func check(_ name: String, _ body: () -> (Bool, String)) {
            let (ok, note) = body()
            print(ok ? "PASS  \(name)" : "FAIL  \(name) — \(note)")
            if !ok { failures += 1 }
        }

        check("baseline: assembled machine prints the wozmon prompt") {
            let m = fresh()
            m.run(cycles: 1_000_000)
            return (m.terminal.transcript.contains("\\"),
                    "no prompt: \(m.terminal.transcript)")
        }

        check("PROMs pulled: reset vector floats, no prompt ever") {
            let m = fresh()
            m.romInstalled = false
            m.reset()
            m.run(cycles: 2_000_000)
            return (!m.terminal.transcript.contains("\\"),
                    "prompt appeared without ROM?!")
        }

        check("RAM W pulled: stack gone — wozmon dies, can't echo typing") {
            let m = fresh()
            m.ramWInstalled = false
            m.reset()
            m.run(cycles: 1_000_000)
            let before = m.terminal.transcript
            m.type("FF00\n")
            m.run(cycles: 2_000_000)
            let new = String(m.terminal.transcript.dropFirst(before.count))
            return (!new.contains("FF00: D8"),
                    "examine WORKED with no stack: \(new)")
        }

        check("PIA pulled: machine alive in ROM, deaf to keys") {
            let m = fresh()
            m.piaInstalled = false
            m.reset()
            m.run(cycles: 1_000_000)
            let before = m.terminal.transcript
            m.type("FF00\n")
            m.run(cycles: 2_000_000)
            let new = String(m.terminal.transcript.dropFirst(before.count))
            let aliveInROM = m.pc >= 0xFF00
            return (aliveInROM && new.isEmpty,
                    "pc=\(String(m.pc, radix: 16)) new='\(new)'")
        }

        check("terminal section pulled: CPU hangs awaiting display") {
            let m = fresh()
            m.videoInstalled = false
            m.reset()
            m.run(cycles: 2_000_000)
            // banner char never accepted; wozmon stuck in ROM wait loop
            return (m.terminal.transcript.isEmpty && m.pc >= 0xFF00,
                    "transcript='\(m.terminal.transcript)' pc=\(String(m.pc, radix: 16))")
        }

        check("RAM X pulled: wozmon fine, BASIC can't start") {
            let m = fresh()
            m.ramXInstalled = false
            m.run(cycles: 1_000_000)
            let promptOK = m.terminal.transcript.contains("\\")
            let before = m.terminal.transcript
            m.type("E000R\n")
            m.run(cycles: 4_000_000)
            let new = String(m.terminal.transcript.dropFirst(before.count))
            return (promptOK && !new.contains(">"),
                    "prompt=\(promptOK) basicStarted=\(new.contains(">"))")
        }

        check("recovery: PROMs reseated + reset → prompt returns") {
            let m = fresh()
            m.romInstalled = false
            m.reset()
            m.run(cycles: 500_000)
            m.romInstalled = true
            m.reset()
            m.run(cycles: 1_000_000)
            return (m.terminal.transcript.contains("\\"),
                    "no prompt after reseat")
        }

        check("recovery: BASIC survives a CPU-style reset (E2B3R warm)") {
            let m = fresh()
            guard let basic = try? ROM.integerBASIC() else { return (false, "no ROM") }
            m.load(basic, at: 0xE000)
            m.type("E000R\n")
            m.run(cycles: 4_000_000)
            m.type("10 PRINT 1\n")
            m.run(cycles: 4_000_000)
            m.reset() // the hot-reseat consequence
            m.run(cycles: 500_000)
            let before = m.terminal.transcript
            m.type("E2B3R\nLIST\n")
            m.run(cycles: 6_000_000)
            let new = String(m.terminal.transcript.dropFirst(before.count))
            return (new.contains("10 PRINT 1"),
                    "program lost after warm re-entry: \(new.suffix(60))")
        }

        check("tape round-trip: encode→wav→decode gives identical bytes") {
            let original: [UInt8] = (0..<512).map { _ in UInt8.random(in: 0...255) }
            let engine = SoundEngine()
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("roundtrip-test.wav")
            do {
                try engine.writeTapeWAV(bytes: original, to: url)
                let decoded = try TapeDecoder.decode(url: url)
                let mismatch = zip(decoded, original).enumerated()
                    .first { $0.element.0 != $0.element.1 }?.offset ?? -1
                return (decoded == original,
                        "got \(decoded.count) bytes, want \(original.count); "
                        + "first mismatch at \(mismatch)")
            } catch {
                return (false, "\(error)")
            }
        }

        check("record format: encode→parse returns identical bytes+address") {
            let bytes: [UInt8] = (0..<300).map { _ in UInt8.random(in: 0...255) }
            let text = TapeText.encode(bytes: bytes, from: 0x0280)
            let parsed = TapeText.parse(text)
            let flat = parsed.flatMap(\.bytes)
            return (parsed.first?.address == 0x0280 && flat == bytes,
                    "addr=\(parsed.first?.address ?? 0) count=\(flat.count)")
        }

        check("full circle: record program tape, power-cycle, reload, LIST works") {
            // machine A: BASIC + a program, recorded as a bank X image
            let a = fresh()
            guard let basic = try? ROM.integerBASIC() else { return (false, "no ROM") }
            a.load(basic, at: 0xE000)
            a.type("E000R\n")
            a.run(cycles: 4_000_000)
            a.type("10 PRINT \"SAVED IN 76\"\n")
            a.run(cycles: 4_000_000)
            // the REAL tape: zero-page pointers + the program, which
            // Apple-1 BASIC keeps in BANK W (like Hamurabi's $300-$FFF)
            let zp = a.read(from: 0x004A, to: 0x00FF)
            let program = a.read(from: 0x0300, to: 0x0FFF)
            // machine B: fresh RAM noise — interpreter + both ranges
            let b = fresh()
            b.powerUp()
            b.run(cycles: 200_000)
            b.load(basic, at: 0xE000)
            b.load(zp, at: 0x004A)
            b.load(program, at: 0x0300)
            let before = b.terminal.transcript
            b.type("E2B3R\nLIST\n")
            b.run(cycles: 6_000_000)
            let out = String(b.terminal.transcript.dropFirst(before.count))
            return (out.contains("10 PRINT \"SAVED IN 76\"")
                    || out.contains("SAVED IN 76"),
                    "LIST after restore: \(out.suffix(80))")
        }

        exit(failures == 0 ? 0 : 1)
    }

    private static func fresh() -> Apple1 {
        let m = try! Apple1()
        m.displayCyclesPerChar = 0
        return m
    }
}
