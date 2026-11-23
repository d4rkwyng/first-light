import Testing
import Foundation
@testable import FirstLight
import Apple1Core

/// Controller-level tests for the 6800 processor-swap and the snapshot
/// round-trip — the two newest features, and the ones the 2026-06 review
/// found bugs in. These never call `start()`, so no Timer, NSEvent monitor,
/// or window is created. Sound is disabled so nothing plays (the
/// SoundEngine still creates and starts its AVAudioEngine in init).
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

    // MARK: Cassette speed applies to the load that's already running

    @Test func loadSpeedTracksCpuSpeedAndRealtimeToggle() {
        let c = makeController()
        c.connectEverything()
        // Stage an AUTHENTIC load, then play with the dials mid-flight.
        c.authenticLoads = true; c.turboFactor = 1
        c.insert(TapeLibrary.tapes[0]) // Integer BASIC — a raw-bytes tape
        #expect(c.nowLoading != nil)
        #expect(c.loadSpeed == 1)          // real-time
        c.turboFactor = 100
        #expect(c.loadSpeed == 100)        // crank CPU Speed → load speeds up
        c.turboFactor = 1; c.authenticLoads = false
        #expect(c.loadSpeed >= 12)         // drop real-time mid-load → fast-forward
        c.stopTape()
        // A QUICK-staged load keeps its short theater at 1× — running it at
        // 12× chopped the deck whirr after a fraction of a second.
        c.insert(TapeLibrary.tapes[0])
        #expect(c.nowLoading != nil)
        #expect(c.loadSpeed == 1)
    }

    // MARK: Drop zones don't cover each other

    @Test func videoDropZoneClearsTheRAMChips() {
        // The terminal-section chips scatter into row B, level with RAM-X, so
        // a full bounding box would put the video drop zone on top of the
        // RAM-X chips and steal their clicks/drops. The zone is bounded to the
        // top rows; assert it sits entirely above the RAM-X and RAM-W zones.
        let video = BoardView.zone(for: .video)
        #expect(video.maxY <= BoardView.zone(for: .ramX).minY)
        #expect(video.maxY <= BoardView.zone(for: .ramW).minY)
        #expect(video.width > 0 && video.height > 0) // still a real target
    }

    @Test func crankingCpuSpeedMidLoadFinishesItSooner() {
        let c = makeController()
        c.connectEverything()
        c.authenticLoads = true
        let basic = TapeLibrary.tapes.first {
            if case .integerBASIC = $0.kind { return true }; return false
        }!
        // real-time (1×): how many frames the authentic load spans
        c.turboFactor = 1
        c.insert(basic)
        #expect(c.nowLoading != nil)
        var slow = 0
        while c.nowLoading != nil && slow < 200_000 { c.advanceLoad(); slow += 1 }
        #expect(slow > 100, "an authentic real-time load should span many frames")
        // ×100: the SAME tape finishes in far fewer frames
        c.turboFactor = 100
        c.insert(basic)
        #expect(c.nowLoading != nil)
        var fast = 0
        while c.nowLoading != nil && fast < 200_000 { c.advanceLoad(); fast += 1 }
        #expect(fast * 10 < slow,
                "×100 should finish the load far sooner (\(fast) vs \(slow))")
    }

    // MARK: Info-bar facts

    @Test func previousFactNeverIndexesNegative() {
        // The bug: one click on the "previous fact" arrow in the first 15 s
        // gave (0 + -1) % count == -1 and trapped on the array subscript.
        let c = makeController()
        c.previousFact()
        #expect(c.factOffset == -1)
        let count = 7
        #expect(MachineController.factIndex(frame: 0, offset: c.factOffset,
                                            count: count) == count - 1)
        for offset in -50...50 {
            for frame in [0, 899, 900, 54_000] {
                let i = MachineController.factIndex(frame: frame, offset: offset,
                                                    count: count)
                #expect((0..<count).contains(i), "frame \(frame) offset \(offset) → \(i)")
            }
        }
        // Forward rotation is unchanged.
        #expect(MachineController.factIndex(frame: 900 * 3, offset: 1, count: count) == 4)
    }

    // MARK: Keyboard routing

    @Test func textFieldsAndModalsKeepTheirKeys() {
        // The bug: the app-wide monitor fed hex typed into the Scope's
        // address field to the Apple-1 (only a fixed list of sheets was
        // exempt), and a save panel's name field would have lost keys too.
        #expect(MachineController.apple1MayTakeKeys(
            uiHasKeyboard: false, modalUp: false, textInputFocused: false))
        #expect(!MachineController.apple1MayTakeKeys(
            uiHasKeyboard: false, modalUp: false, textInputFocused: true))
        #expect(!MachineController.apple1MayTakeKeys(
            uiHasKeyboard: false, modalUp: true, textInputFocused: false))
        #expect(!MachineController.apple1MayTakeKeys(
            uiHasKeyboard: true, modalUp: false, textInputFocused: false))
    }

    @Test func onlyTheApple1KeyboardRefusesToRepeat() {
        let c = makeController()
        c.connectEverything()
        #expect(c.powered && c.connected.contains(.keyboard))
        let kbdcr: UInt16 = 0xD011
        // Let wozmon set up the PIA so a waiting key shows in KBDCR bit 7.
        c.machine.run(cycles: 200_000)
        #expect(c.machine.busPeek(kbdcr) & 0x80 == 0)
        // A held key's repeats are swallowed and never reach the machine...
        #expect(c.handle(keyCode: 0, characters: "a", command: false, isRepeat: true))
        #expect(c.machine.busPeek(kbdcr) & 0x80 == 0, "a repeat must not press")
        // ...the first press does...
        #expect(c.handle(keyCode: 0, characters: "a", command: false))
        #expect(c.machine.busPeek(kbdcr) & 0x80 != 0)
        // ...and keys the Apple-1 has no use for (arrows) repeat normally,
        // as do ⌘-shortcuts.
        #expect(!c.handle(keyCode: 123, characters: "\u{F702}", command: false, isRepeat: true))
        #expect(!c.handle(keyCode: 6, characters: "z", command: true, isRepeat: true))
    }

    // MARK: Custom tape limits

    private func tempURL(_ name: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fl-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(name)
    }

    @Test func oversizedCustomTapeIsRefusedWithAMessage() throws {
        // The bug: any file of any size was read and its FSK audio
        // synthesized on the main thread (~265 samples per byte).
        let c = makeController()
        c.connectEverything()
        let big = tempURL("huge.bin")
        try Data(count: MachineController.maxCustomTapeBytes + 1).write(to: big)
        c.insertCustom(url: big)
        #expect(c.nowLoading == nil, "an oversized tape must not start loading")
        let message = try #require(c.customTapeError)
        #expect(message.contains("huge.bin") && message.contains("64 KB"))

        // A tape at the limit still loads, and clears the old error.
        let ok = tempURL("fits.bin")
        try Data(repeating: 0xEA, count: MachineController.maxCustomTapeBytes).write(to: ok)
        c.insertCustom(url: ok)
        #expect(c.customTapeError == nil)
        #expect(c.nowLoading == "fits")
    }

    @Test func tapeDecoderCapsDurationAndSizeAndStillRoundTrips() throws {
        let c = makeController()
        let wav = tempURL("t.wav")
        let bytes: [UInt8] = [0xA9, 0x0D, 0x20, 0xEF, 0xFF]
        try c.sound.writeTapeWAV(bytes: bytes, to: wav) // 10 s leader
        #expect(try TapeDecoder.decode(url: wav) == bytes, "chunked decode round-trips")
        #expect(throws: TapeDecoder.DecodeError.self) {
            try TapeDecoder.decode(url: wav, maxSeconds: 5)
        }
        #expect(throws: TapeDecoder.DecodeError.tooLarge(bytes: 5)) {
            try TapeDecoder.decode(url: wav, maxBytes: 4)
        }
    }

    @Test func tapeDurationMatchesRenderedAudio() {
        // tapePlay reports duration without rendering; it must agree with
        // what rendering would produce (authentic loads time off it).
        let phases = TapeEncoding.phases(bytes: [0x00, 0xFF, 0x5A], leaderSeconds: 0.6)
        let rendered = Double(SoundEngine.tapeSamples(phases: phases).count) / SoundEngine.tapeRate
        #expect(SoundEngine.tapeDuration(phases: phases) == rendered)
    }

    // MARK: Accessibility

    @Test func screenTextIsExposedToVoiceOver() {
        // The bug: the 40×24 display was a bare Canvas with no text at all.
        let c = makeController()
        c.connectEverything()
        c.machine.run(cycles: 200_000) // wozmon prints its "\\" prompt
        c.machine.type("FF00\n")
        c.machine.displayCyclesPerChar = 0
        c.machine.run(cycles: 2_000_000)
        let text = TerminalView.accessibleText(c.machine.terminal)
        #expect(text.contains("FF00: D8"), "screen text: \(text)")
        #expect(text.contains("Cursor on line"))
        #expect(!text.contains("  \n"), "trailing blanks are trimmed")
    }

    @Test func hexLookingTapeNameStillLoadsAt0300() throws {
        // The bug: "2048.bin" (no "@") parsed as load address $2048, where
        // there is no RAM. Only "name@ADDR.bin" names an address.
        func load(_ file: String) throws -> MachineController {
            let c = makeController()
            c.connectEverything()
            let url = tempURL(file)
            try Data([0xA9, 0x42, 0x60]).write(to: url)
            c.insertCustom(url: url)
            var spins = 0
            while c.nowLoading != nil && spins < 10_000 { c.advanceLoad(); spins += 1 }
            return c
        }
        let plain = try load("2048.bin")
        #expect(plain.machine.peek(0x0300) == 0xA9)
        let addressed = try load("demo@0280.bin")
        #expect(addressed.machine.peek(0x0280) == 0xA9)
    }

    @Test func restoringASnapshotCancelsAnInFlightLoad() throws {
        let c = makeController()
        c.connectEverything()
        c.machine.load([0x11, 0x22], at: 0x0300)
        let saved = try #require(c.encodeBenchState())
        let tape = try #require(TapeLibrary.tapes.first)
        c.insert(tape)
        #expect(c.nowLoading != nil)
        #expect(c.applyBenchState(saved))
        #expect(c.nowLoading == nil, "the old session's load must not survive")
        for _ in 0..<400 { c.advanceLoad(); c.pumpAutoTypeForTesting() }
        #expect(c.machine.peek(0x0300) == 0x11 && c.machine.peek(0x0301) == 0x22,
                "restored RAM must not be overwritten by the cancelled tape")
    }

    @Test func aLateAudioDecodeNeverStagesAfterStopResetRestoreOrAnotherLoad() async throws {
        // Codex review: the off-main decode wasn't tracked, so STOP, a
        // snapshot restore or another tape during the decode was undone
        // when the old decode finished and staged its tape anyway.
        let c = makeController()
        c.connectEverything()
        let wav = tempURL("late.wav")
        try c.sound.writeTapeWAV(bytes: [0xA9, 0x01, 0x60], to: wav)

        c.insertCustom(url: wav)
        let stopped = try #require(c.customDecode)
        c.stopTape()
        await stopped.value
        #expect(c.nowLoading == nil, "STOP during decode must stick")
        #expect(c.customTapeError == nil)

        let saved = try #require(c.encodeBenchState())
        c.insertCustom(url: wav)
        let restored = try #require(c.customDecode)
        #expect(c.applyBenchState(saved))
        await restored.value
        #expect(c.nowLoading == nil, "a restore during decode must stick")

        c.insertCustom(url: wav)
        let reset = try #require(c.customDecode)
        c.reset()
        await reset.value
        #expect(c.nowLoading == nil, "RESET during decode must stick")

        // Another tape inserted during the decode wins — on the authentic
        // ACI path (which doesn't go through stageLoad) as well as showcase.
        for authentic in [true, false] {
            c.authenticLoads = authentic
            c.insertCustom(url: wav)
            let superseded = try #require(c.customDecode)
            let tape = try #require(TapeLibrary.tapes.first {
                if case .integerBASIC = $0.kind { return true } else { return false }
            })
            c.insert(tape)
            #expect(c.nowLoading == tape.name)
            await superseded.value
            #expect(c.nowLoading == tape.name,
                    "authentic=\(authentic): the late decode must not replace the new load")
            c.stopTape()
        }
        c.authenticLoads = false

        // Left alone, the same recording does load.
        c.insertCustom(url: wav)
        await c.customDecode?.value
        #expect(c.nowLoading == "late")
        #expect(c.customDecode == nil)
    }

    @Test func tutorialAndStripDropAPendingDecodeOnAnUnpoweredBench() async throws {
        // Codex round 4 suspected these leaked a pending decode when the
        // bench was already unpowered. They don't: disconnect(.power) cancels
        // unconditionally. This pins that down, plus STOP's availability.
        let wav = tempURL("pending.wav")
        try makeController().sound.writeTapeWAV(bytes: [0xEA], to: wav)
        for action in ["tutorial", "strip"] {
            let c = makeController()
            #expect(!c.powered)
            c.insertCustom(url: wav)
            let pending = try #require(c.customDecode)
            #expect(c.tapeBusy, "STOP must be available while decoding")
            if action == "tutorial" { c.startTutorial() } else { c.stripBoard() }
            await pending.value
            #expect(c.nowLoading == nil, "\(action) during decode must stick")
            #expect(!c.tapeBusy)
        }
    }

    @Test func cancelledDecodeAndRenderStopWorking() async throws {
        // Codex round 5: cancelling only suppressed the result; the detached
        // decode/render ran to completion. Both now stop when cancelled.
        let wav = tempURL("cancel.wav")
        try makeController().sound.writeTapeWAV(bytes: [0xEA, 0xEA], to: wav)
        let decode = Task.detached { () throws -> [UInt8] in
            withUnsafeCurrentTask { $0?.cancel() }
            return try TapeDecoder.decode(url: wav)
        }
        await #expect(throws: CancellationError.self) { try await decode.value }

        let phases = TapeEncoding.phases(bytes: [UInt8](repeating: 0x55, count: 4096),
                                         leaderSeconds: 6)
        let render = Task.detached { () -> Int in
            withUnsafeCurrentTask { $0?.cancel() }
            return SoundEngine.tapeSamples(phases: phases).count
        }
        #expect(await render.value == 0)
        #expect(!SoundEngine.tapeSamples(phases: phases).isEmpty, "uncancelled renders fully")
    }
}
