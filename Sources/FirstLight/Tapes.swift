import Foundation

/// The official Apple-1 cassette library — the $5 tapes Apple sold in
/// 1976-77. Sourced from the Apple-1 Software Library preservation
/// project (apple1software.com). BASIC games load by typing their
/// listing (TurboType, like a fast tape); machine-language tapes load
/// their binary at the documented address.
struct Tape: Identifiable {
    enum Kind {
        case integerBASIC                      // tape #1: BASIC itself
        case basicSource(file: String)         // type listing into BASIC, RUN
        case binary(file: String, load: UInt16, run: String)
        /// A BASIC memory image without its pointer block — we rebuild
        /// Integer BASIC's real zero-page pointers (LOMEM $4A, HIMEM $4C,
        /// PP $CA, PV $CC) around it before RUN.
        case basicImage(file: String, load: UInt16)
    }

    let name: String
    let kind: Kind
    let blurb: String
    var homebrew = false

    var id: String { name }
}

enum TapeLibrary {
    static let tapes: [Tape] = [
        Tape(name: "Integer BASIC",
             kind: .integerBASIC,
             blurb: "Tape #1: Woz's 4K BASIC interpreter, hand-assembled "
             + "on paper. Loads at $E000."),
        Tape(name: "Hamurabi",
             kind: .basicSource(file: "hamurabi"),
             blurb: "Govern ancient Sumer: buy land, plant grain, survive "
             + "the plague. The classic of early computing."),
        Tape(name: "Mini-Startrek",
             kind: .basicSource(file: "mini-startrek"),
             blurb: "Hunt Klingons across the quadrants in 4 KB of BASIC."),
        Tape(name: "Lunar Lander",
             kind: .binary(file: "lunar-lander", load: 0x0300, run: "0300R"),
             blurb: "Burn just enough fuel to touch down softly — or dig "
             + "a new crater."),
        Tape(name: "Mastermind",
             kind: .binary(file: "mastermind", load: 0x0300, run: "0300R"),
             blurb: "Guess the computer's 5-digit code in the fewest tries."),
        Tape(name: "Dis-Assembler",
             kind: .binary(file: "dis-assembler", load: 0x0800, run: "800R"),
             blurb: "Turn memory back into 6502 assembly — the era's "
             + "debugging power tool."),
        Tape(name: "Extended Monitor",
             kind: .binary(file: "extended-monitor", load: 0xE000, run: "E003R"),
             blurb: "The Woz Monitor's big sibling: search, move, and "
             + "edit memory. Needs RAM bank X."),
        Tape(name: "APPLE 50TH",
             kind: .basicSource(file: "apple50th"),
             blurb: "Our anniversary tape: fifty years of Apple, told by "
             + "the machine that started it — at 60 characters a second."),
        Tape(name: "Microchess",
             kind: .binary(file: "microchess", load: 0x0300, run: "300R"),
             blurb: "Peter Jennings' 1976 chess engine — the first "
             + "commercial game software for a personal computer, $10 "
             + "by mail order."),
        Tape(name: "Life",
             kind: .binary(file: "life", load: 0x0280, run: "400R"),
             blurb: "Conway's Game of Life, breeding on a 1976 screen — "
             + "emergence at 60 characters a second."),
        Tape(name: "Blackjack",
             kind: .basicImage(file: "blackjack", load: 0x0A06),
             blurb: "Hit or stand — recovered from an original 1976 tape "
             + "in 2005. A bare memory image; we rebuild BASIC's "
             + "pointers around it."),

        // — Homebrew: written for real Apple-1s, this century —
        Tape(name: "15 Puzzle",
             kind: .binary(file: "fifteen-puzzle", load: 0x0300, run: "0300R"),
             blurb: "Jeff Jetton's 2020 sliding-tile puzzle — new software "
             + "for a 44-year-old machine.", homebrew: true),
        Tape(name: "2048",
             kind: .binary(file: "2048", load: 0x0280, run: "280R"),
             blurb: "The modern tile-merge classic, squeezed into Apple-1 "
             + "memory.", homebrew: true),
        Tape(name: "APPLE 30TH",
             kind: .binary(file: "apple-30th", load: 0x0280, run: "280R"),
             blurb: "Dave Schmenk's 30th-anniversary graphics demo — an "
             + "undocumented display trick. Squint from across the room.",
             homebrew: true),
        Tape(name: "Mandelbrot 65",
             kind: .binary(file: "mandelbrot-65", load: 0x0280, run: "280R"),
             blurb: "A fractal, rendered in ASCII by a 1 MHz 6502. Give "
             + "it a minute — it's worth it.", homebrew: true),
    ]

    static func basicSource(_ file: String) -> String? {
        guard let url = Bundle.module.url(forResource: file, withExtension: "bas.txt",
                                          subdirectory: "Resources/Tapes") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    static func binary(_ file: String) -> [UInt8]? {
        guard let url = Bundle.module.url(forResource: file, withExtension: "bin",
                                          subdirectory: "Resources/Tapes") else { return nil }
        return (try? Data(contentsOf: url)).map([UInt8].init)
    }
}
