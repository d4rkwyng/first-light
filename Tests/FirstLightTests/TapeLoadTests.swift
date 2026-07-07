import Testing
import Foundation
@testable import FirstLight
import Apple1Core

/// End-to-end cassette loads through the REAL controller path — insert,
/// spin the deck, and check the program actually runs. These caught two
/// released-quality bugs: a HIMEM poke into open bus ($1000-$1FFF has no
/// RAM — writes vanished and BASIC hung after one line), and Blackjack's
/// dump carrying 518 bytes of tape-recovery slack before the program.
@MainActor
@Suite(.serialized)
struct TapeLoadTests {

    private func loadAndRun(_ name: String, frames: Int = 20_000) -> String {
        let c = MachineController()
        c.sound.enabled = false
        c.connectEverything()
        let tape = TapeLibrary.tapes.first { $0.name == name }!
        c.insert(tape)
        var spins = 0
        while c.nowLoading != nil && spins < 100_000 { c.advanceLoad(); spins += 1 }
        // performInsert has run; drain the autotyped RUN like tick() does.
        for _ in 0..<frames {
            c.pumpAutoTypeForTesting()
            c.machine.run(cycles: Apple1.cyclesPerFrame)
        }
        return c.machine.terminal.transcript
    }

    @Test func apple50thTypesAndRuns() {
        let t = loadAndRun("APPLE 50TH")
        #expect(!t.contains("MEM FULL"), "LOMEM poke should make the listing fit")
        #expect(t.contains("960 END"), "the whole listing should TurboType in")
        #expect(t.contains("APPLE"), "the demo should run and print")
    }

    @Test func blackjackDealsAHand() {
        let t = loadAndRun("Blackjack")
        #expect(!t.contains("MEM FULL"))
        #expect(t.contains("WELCOME TO 21"),
                "the 1976 tape's opening line (per the 1977 Kilobaud review)")
    }
}
