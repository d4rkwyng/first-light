import Foundation
import Apple1Core

/// T2: headless verification that every cassette in the library loads and
/// runs. Invoked with `FirstLight --verify-tapes` (add `--verbose` to dump
/// each tape's transcript); exits non-zero on any failure. Wired into
/// Scripts/verify-tapes.sh.
///
/// Every tape goes through the SAME path the app uses — `MachineController`
/// insert, the deck's load, `performInsert`, the autotyped run command — not
/// a hand-rolled copy of it. (The old verifier rebuilt each load itself and
/// drifted from the app: no LOMEM poke, so APPLE 50TH hit MEM FULL in the
/// check while the app was fine, and vice versa it could never catch a bug
/// in the app's own load path.)
///
/// What counts as a pass is strict on purpose. 1.0.0 shipped four broken
/// tapes while this check reported 15/15, because "any output longer than 10
/// characters" passed: a bare `0400: 8D` echo, a `*** MEM FULL ERR`, and
/// listings with half their lines missing all qualified. Now:
///   - every tape names text its program must print (no empty needles);
///   - interactive tapes are driven a few moves in and must answer the way
///     the real program does — a damaged listing goes off the rails here;
///   - any Integer BASIC error (`*** … ERR`) anywhere fails the tape;
///   - BASIC listings must type in completely: every numbered source line
///     has to be echoed back in full (Apple-1 input treats `_` as rubout,
///     so a line containing one is silently mangled — that check catches it).
@MainActor
enum TapeVerifier {
    /// One scripted exchange: type `send` (if any), then `expect` must appear
    /// in the output that follows, within `frames` frames of emulation.
    struct Step {
        var send: String?
        var expect: String
        var frames = 60 * 120
    }

    /// Per tape: the first step's `expect` is what the program prints after
    /// the run command; later steps play a few moves.
    static let scripts: [String: [Step]] = [
        "Integer BASIC": [
            Step(expect: ">"),
            Step(send: "PRINT 6*7\n", expect: "42"),
            Step(send: "PRINT 3<5, 3>5\n", expect: "1"),
        ],
        "Hamurabi": [
            Step(expect: "HOW MANY ACRES DO YOU WISH TO BUY"),
            Step(send: "0\n", expect: "HOW MANY ACRES DO YOU WISH TO SELL"),
            Step(send: "0\n", expect: "HOW MANY BUSHELS DO YOU WISH TO FEED"),
            Step(send: "2000\n", expect: "HOW MANY ACRES DO YOU WISH TO PLANT"),
            Step(send: "100\n", expect: "IN YEAR 2,"),
        ],
        "Mini-Startrek": [
            Step(expect: "TYPE A NUMBER"),
            Step(send: "5\n", expect: "COMMAND"),
            // short-range scan draws the quadrant; the Enterprise is <*>
            Step(send: "1\n", expect: "SHORT RANGE SENSOR SCAN"),
            Step(expect: "<*>"),
            // wait for the prompt: a key typed while BASIC runs stops it
            Step(expect: "COMMAND ?"),
            Step(send: "7\n", expect: "COMMAND ?"), // out of range: re-prompt
        ],
        "Lunar Lander": [
            Step(expect: "BEGIN LANDING PROCEDURE"),
            Step(send: "5\n", expect: "0450"), // BCD: 500 ft less 50 ft/s
        ],
        "Mastermind": [Step(expect: "READY?")],
        "Blackjack": [Step(expect: "WELCOME TO 21.  YOUR NAME?")],
        "Dis-Assembler": [Step(expect: "BRK")],
        "Extended Monitor": [Step(expect: "\n%")],
        "Microchess": [Step(expect: "MICROCHESS(C)")],
        "Life": [
            Step(expect: "#"),
            Step(send: "\n", expect: "?"),
            // seed a blinker; generation 1 is horizontal…
            Step(send: "***D", expect: "...............***......................"),
            // …and the next generation must turn it vertical
            Step(expect: String(repeating: "................*"
                                + String(repeating: ".", count: 23) + "\n",
                                count: 3)),
        ],
        "15 Puzzle": [
            Step(expect: "15 PUZZLE - BY JEFF JETTON"),
            Step(send: "N", expect: "DIFFICULTY LEVEL"),
        ],
        "2048": [Step(expect: "PRESS ANY KEY")],
        "APPLE 30TH": [Step(expect: "@@@@@@@@")],
        "APPLE 50TH": [
            Step(expect: "FIFTY YEARS OF APPLE"),
            Step(expect: ".---------------."),       // the Apple-1 board art
            Step(expect: "HAPPY 50TH, APPLE.      FIRST LIGHT",
                 frames: 60 * 900),                  // runs to the end
        ],
        "Mandelbrot 65": [Step(expect: "(PRESS ANY KEY TO START)")],
    ]

    static func run() -> Never {
        let verbose = CommandLine.arguments.contains("--verbose")
        var failures = 0
        for tape in TapeLibrary.tapes {
            let (problem, transcript) = verify(tape)
            if let problem {
                failures += 1
                print("FAIL  \(tape.name) — \(problem)")
            } else {
                print("PASS  \(tape.name)")
            }
            if verbose || problem != nil {
                let tail = verbose ? transcript : String(transcript.suffix(400))
                print(tail.split(separator: "\n", omittingEmptySubsequences: false)
                    .map { "      | \($0)" }.joined(separator: "\n"))
            }
        }
        print(failures == 0 ? "all \(TapeLibrary.tapes.count) tapes verified"
                            : "\(failures) of \(TapeLibrary.tapes.count) tapes FAILED")
        exit(failures == 0 ? 0 : 1)
    }

    /// nil = pass, else what went wrong; plus the session transcript.
    static func verify(_ tape: Tape) -> (problem: String?, transcript: String) {
        guard let steps = scripts[tape.name], !steps.isEmpty else {
            return ("no script — every tape needs an expected output", "")
        }
        let c = MachineController()
        c.sound.enabled = false
        c.connectEverything()
        let start = c.machine.terminal.transcript.count
        func session() -> String {
            String(c.machine.terminal.transcript.dropFirst(start))
        }

        c.insert(tape)
        var spins = 0
        while c.nowLoading != nil && spins < 100_000 { c.advanceLoad(); spins += 1 }
        guard c.nowLoading == nil else { return ("load never finished", session()) }
        // performInsert has run; from here, emulate full speed and feed the
        // autotyped run command (and our answers) the way tick() does.
        c.machine.displayCyclesPerChar = 0

        var mark = c.machine.terminal.transcript.count
        for (n, step) in steps.enumerated() {
            if let send = step.send {
                mark = c.machine.terminal.transcript.count
                c.autoType(send)
            }
            var seen = false
            for frame in 0..<step.frames {
                c.pumpAutoTypeForTesting()
                c.machine.run(cycles: Apple1.cyclesPerFrame)
                if frame % 20 == 19 || frame == step.frames - 1 {
                    let out = c.machine.terminal.transcript.dropFirst(mark)
                    if let range = out.range(of: step.expect) {
                        // the next step reads on from here
                        mark = c.machine.terminal.transcript.count
                            - out.distance(from: range.upperBound, to: out.endIndex)
                        seen = true
                        break
                    }
                }
            }
            if let error = basicError(in: session()) {
                return ("BASIC error: \(error)", session())
            }
            guard seen else {
                return ("step \(n + 1): never printed '\(step.expect)'", session())
            }
        }

        if case .basicSource(let file) = tape.kind,
           let source = TapeLibrary.basicSource(file),
           let problem = listingProblem(source: source, transcript: session()) {
            return (problem, session())
        }
        if let error = basicError(in: session()) {
            return ("BASIC error: \(error)", session())
        }
        return (nil, session())
    }

    /// The first Integer BASIC error message in the transcript, if any.
    static func basicError(in transcript: String) -> String? {
        for line in transcript.split(separator: "\n")
        where line.contains("*** ") && line.contains("ERR") {
            return String(line)
        }
        return nil
    }

    /// Every numbered line of the listing must have been typed in whole.
    /// The terminal wraps at 40 columns, so compare with newlines removed;
    /// BASIC echoes each typed line after its `>` prompt.
    static func listingProblem(source: String, transcript: String) -> String? {
        let echoed = transcript.replacingOccurrences(of: "\n", with: "")
        for raw in source.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces).uppercased()
            guard let first = line.first, first.isNumber else { continue }
            if line.contains("_") {
                return "line '\(line.prefix(12))…' contains '_', the Apple-1 rubout key"
            }
            if !echoed.contains(">" + line) {
                return "listing line never typed in whole: \(line.prefix(40))"
            }
        }
        return nil
    }
}
