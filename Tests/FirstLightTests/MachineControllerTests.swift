import Testing
import Foundation
@testable import FirstLight
import Apple1Core

/// Controller-level tests for the 6800 processor-swap and the snapshot
/// round-trip — the two newest features, and the ones the 2026-06 review
/// found bugs in. These never call `start()`, so no Timer, NSEvent monitor,
/// or window is created; sound is disabled so no audio engine spins up.
/// `.serialized` because each controller's Apple1 owns the shared fake6502
/// CPU globals.
@MainActor
@Suite(.serialized)
struct MachineControllerTests {

    private func makeController() -> MachineController {
        let c = MachineController()
        c.sound.enabled = false // no audio engine in tests
        return c
    }

    // MARK: Assembly defaults

    @Test func startsAsAFullyAssembled6502() {
        let c = makeController()
        #expect(c.cpuVariant == .mos6502)
        #expect(c.populate6800 == false)
        #expect(c.essentialsPlaced)
    }

    // MARK: The 6800 what-if

    @Test func processorSwapTogglesPopulate6800() {
        let c = makeController()
        c.cpuVariant = .m6800
        #expect(c.populate6800)
        c.cpuVariant = .mos6502
        #expect(c.populate6800 == false)
    }

    @Test func ensure6502RecoversFromTheWhatIf() {
        let c = makeController()
        c.cpuVariant = .m6800
        c.ensure6502()
        #expect(c.cpuVariant == .mos6502)
    }

    @Test func loadingBASICForcesThe6502Back() {
        // The bug: ⌘B / a tape / a demo in 6800 mode used to strand the load
        // and swallow keystrokes. Now every load entry point flips the 6502
        // back in first (ensure6502).
        let c = makeController()
        c.connectEverything()
        c.cpuVariant = .m6800
        #expect(c.cpuVariant == .m6800)
        c.loadBASIC()
        #expect(c.cpuVariant == .mos6502)
    }

    @Test func insertingATapeForcesThe6502Back() {
        let c = makeController()
        c.connectEverything()
        c.cpuVariant = .m6800
        c.insert(TapeLibrary.tapes[0]) // any tape; insert() calls ensure6502()
        #expect(c.cpuVariant == .mos6502)
    }

    // MARK: Socket failure modes (syncSockets)

    @Test func pullingChipsMatchesTheMachineFlags() {
        let c = makeController()
        c.connect(.power)
        c.unplace(.proms)
        #expect(c.machine.romInstalled == false)   // no PROMs → floating vector
        c.unplace(.ramW)
        #expect(c.machine.ramWInstalled == false)   // no bank W → no zero page
        c.place(.proms)
        c.place(.ramW)
        #expect(c.machine.romInstalled)
        #expect(c.machine.ramWInstalled)
    }

    @Test func stripBoardClearsChipsAndPeripherals() {
        let c = makeController()
        c.connectEverything()
        c.stripBoard()
        #expect(c.placed.isEmpty)
        #expect(c.connected.isEmpty)
    }

    // MARK: Snapshot round-trip (the M1 / cpuVariant / M4 fixes)

    @Test func snapshotPersistsCpuVariant() {
        let c = makeController()
        c.connectEverything()
        c.cpuVariant = .m6800
        let data = c.encodeBenchState()
        #expect(data != nil)
        c.cpuVariant = .mos6502 // diverge from the snapshot
        #expect(c.applyBenchState(data!))
        #expect(c.cpuVariant == .m6800) // saved in 6800 → restored as 6800
    }

    @Test func snapshotReconcilesTheACIBus() {
        let c = makeController()
        c.connectEverything() // seats and installs the ACI card
        #expect(c.machine.aciInstalled)
        let data = c.encodeBenchState()!
        c.disconnect(.aciCard) // pull the card out from under the machine
        #expect(c.machine.aciInstalled == false)
        #expect(c.applyBenchState(data))
        #expect(c.machine.aciInstalled) // bus state re-derived from `connected`
    }

    @Test func corruptSnapshotIsRejectedWithoutTouchingState() {
        let c = makeController()
        c.connect(.power)
        c.cpuVariant = .m6800
        // Not JSON at all:
        #expect(c.applyBenchState(Data("not a bench".utf8)) == false)
        // Valid JSON, wrong shape:
        #expect(c.applyBenchState(Data(#"{"foo":1}"#.utf8)) == false)
        // Live state is untouched by a rejected restore:
        #expect(c.cpuVariant == .m6800)
        #expect(c.powered)
    }

    // MARK: Missing-part warning

    @Test func missingPartsForLoadReflectsPulledChips() {
        let c = makeController() // starts fully assembled
        let binary = TapeLibrary.tapes.first { if case .binary = $0.kind { return true }; return false }!
        let basic = TapeLibrary.tapes.first { if case .integerBASIC = $0.kind { return true }; return false }!
        #expect(c.missingParts(for: binary).isEmpty)
        c.unplace(.proms)
        #expect(c.missingParts(for: binary).contains(.proms)) // can't run without the PROMs
        c.unplace(.ramX) // bank X is the BASIC upgrade
        #expect(!c.missingParts(for: binary).contains(.ramX)) // a binary doesn't need it
        #expect(c.missingParts(for: basic).contains(.ramX))   // BASIC does
    }
}
