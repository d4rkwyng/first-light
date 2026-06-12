import Foundation
import Apple1Core

/// T2: headless verification that every cassette in the library loads
/// and runs. Invoked with `FirstLight --verify-tapes`; exits non-zero
/// on any failure. Wired into Scripts/verify-tapes.sh.
@MainActor
enum TapeVerifier {
    /// Expected output fragment per tape, AFTER the run command.
    static let needles: [String: String] = [
        "Integer BASIC": ">",
        "Hamurabi": "SUMERIA",
        "Mini-Startrek": "TYPE A NUMBER",
        "Lunar Lander": "LUNAR",
        "Mastermind": "READY",
        "Dis-Assembler": "",          // disassembler waits for input
        "Extended Monitor": "",        // banner varies; crash check only
        "Microchess": "MICROCHESS",
        "Blackjack": "",
        "Life": "",
        "15 Puzzle": "",
        "2048": "",
        "Mandelbrot 65": "",
        "APPLE 30TH": "",
    ]

    static func run() -> Never {
        var failures = 0
        for tape in TapeLibrary.tapes {
            let result = verify(tape)
            print(result.ok ? "PASS  \(tape.name)" : "FAIL  \(tape.name) — \(result.note)")
            if !result.ok { failures += 1 }
        }
        exit(failures == 0 ? 0 : 1)
    }

    private static func verify(_ tape: Tape) -> (ok: Bool, note: String) {
        guard let machine = try? Apple1() else { return (false, "no machine") }
        machine.displayCyclesPerChar = 0

        let before: String
        switch tape.kind {
        case .integerBASIC:
            guard let basic = try? ROM.integerBASIC() else { return (false, "no BASIC ROM") }
            machine.load(basic, at: 0xE000)
            machine.type("E000R\n")
            before = machine.terminal.transcript
        case .basicSource(let file):
            guard let basic = try? ROM.integerBASIC(),
                  let source = TapeLibrary.basicSource(file)
            else { return (false, "missing resources") }
            machine.load(basic, at: 0xE000)
            machine.type("E000R\n")
            machine.type(source + "\n")
            machine.run(cycles: 250_000_000)
            before = machine.terminal.transcript
            machine.type("RUN\n")
        case .binary(let file, let load, let runCmd):
            guard let bytes = TapeLibrary.binary(file) else { return (false, "missing bin") }
            machine.load(bytes, at: load)
            before = machine.terminal.transcript
            machine.type(runCmd + "\n")
        case .basicImage(let file, let load):
            guard let basic = try? ROM.integerBASIC(),
                  let image = TapeLibrary.binary(file)
            else { return (false, "missing resources") }
            machine.load(basic, at: 0xE000)
            machine.type("E000R\n")
            machine.run(cycles: 4_000_000)
            machine.load(image, at: load)
            let pointer = [UInt8(load & 0xFF), UInt8(load >> 8)]
            machine.load(pointer, at: 0x00CA)
            machine.load(pointer, at: 0x00E4)
            machine.load(pointer, at: 0x00E6)
            before = machine.terminal.transcript
            machine.type("E2B3R\nRUN\n")
        }
        machine.run(cycles: 80_000_000)
        var output = String(machine.terminal.transcript.dropFirst(before.count))

        // a program may sit waiting for input — poke it once
        if output.count < 30 {
            machine.type("\n")
            machine.run(cycles: 40_000_000)
            output = String(machine.terminal.transcript.dropFirst(before.count))
        }

        if let needle = needles[tape.name], !needle.isEmpty {
            // a specific banner is the contract
            guard output.contains(needle) else {
                return (false, "missing '\(needle)' in: \(output.suffix(90))")
            }
            return (true, "")
        }
        // otherwise: any life beyond the command's own echo counts
        guard output.count > 10 else {
            return (false, "no output: \(output)")
        }
        return (true, "")
    }
}
