import AppKit
import Apple1Core

/// A set of chips that can be seated on the bare board. The Byte Shop's
/// $666.66 Apple-1s came fully assembled, but Apple sold bare boards to
/// hobbyists too — the tour starts you from one.
enum ChipGroup: String, CaseIterable, Identifiable {
    case cpu, pia, ramW, ramX, proms, video

    var id: String { rawValue }
    var payload: String { "chip.\(rawValue)" }

    /// Bank X is the period RAM upgrade — everything else is required.
    var essential: Bool { self != .ramX }

    var name: String {
        switch self {
        case .cpu: "MOS 6502 CPU"
        case .pia: "6820 PIA"
        case .ramW: "4 KB RAM — bank W"
        case .ramX: "4 KB RAM — bank X"
        case .proms: "Woz Monitor PROMs"
        case .video: "Terminal chip set"
        }
    }

    var symbol: String {
        switch self {
        case .cpu: "cpu"
        case .pia: "arrow.left.arrow.right"
        case .ramW: "memorychip.fill"
        case .ramX: "memorychip"
        case .proms: "text.book.closed"
        case .video: "tv.and.mediabox"
        }
    }

    var blurb: String {
        switch self {
        case .cpu:
            "The $25 processor, in white ceramic with a gold lid. Pull it "
            + "(double-click) and the machine is a very flat doorstop."
        case .pia:
            "The machine's only I/O chip — keyboard in, display out. It "
            + "sits beside the 6502."
        case .ramW:
            "Eight MK4096 DRAMs — the base 4 KB at $0000 the machine "
            + "needs to think at all."
        case .ramX:
            "The upgrade: 4 KB more at $E000. This is where Integer "
            + "BASIC loads — no bank X, no BASIC."
        case .proms:
            "Two little PROMs holding all 256 bytes of the Woz Monitor. "
            + "No PROMs, no prompt."
        case .video:
            "Woz's TV terminal: shift registers, the 2513 character "
            + "generator, sync logic and the crystal. The top of the board."
        }
    }
}

/// A peripheral that can be dragged from the shelf onto the board.
enum Peripheral: String, CaseIterable, Identifiable {
    case power, keyboard, display, aciCard

    var id: String { rawValue }

    var name: String {
        switch self {
        case .power: "Power Supply"
        case .keyboard: "ASCII Keyboard"
        case .display: "Video Monitor"
        case .aciCard: "Cassette Interface"
        }
    }

    var symbol: String {
        switch self {
        case .power: "bolt.fill"
        case .keyboard: "keyboard"
        case .display: "tv"
        case .aciCard: "memorychip"
        }
    }

    var blurb: String {
        switch self {
        case .power:
            "Two transformers — the Apple-1 shipped without them. You bought "
            + "your own, like everything else but the board."
        case .keyboard:
            "A parallel ASCII keyboard (most used the Datanetics). Uppercase "
            + "only — there is no lowercase anywhere in this machine."
        case .display:
            "Any cheap TV or composite monitor. Woz putting the terminal ON "
            + "the board is what made the Apple-1 revolutionary."
        case .aciCard:
            "The Apple Cassette Interface ($75) plugs into the expansion "
            + "slot. It is only needed WHILE loading - once a tape is in "
            + "RAM you can pull the card and the program keeps running. "
            + "Only power loss erases RAM."
        }
    }
}

/// Owns the emulated Apple-1, what's plugged into it, and the per-chip
/// activity glow. Clocks the machine at 60 fps × 17,045 cycles — real time
/// for a 1.023 MHz 6502 — but only once power is connected.
@MainActor
@Observable
final class MachineController {
    /// Board regions that light up with bus activity.
    enum Region: Hashable {
        case cpu, ramW, ramX, rom, pia, video
    }

    let machine: Apple1
    let sound = SoundEngine()
    private(set) var frame = 0
    private(set) var connected: Set<Peripheral> = []
    private(set) var placed: Set<ChipGroup> = Set(ChipGroup.allCases)
    private(set) var glow: [Region: Double] = [:]
    var hoverInfo: String?
    /// Set while a shelf row is hovered — the board highlights the match.
    var highlightedGroup: ChipGroup?
    var highlightedPeripheral: Peripheral?
    var welcomeRequested = false
    /// Debug: overlays extracted footprints (red) vs drawn parts (green).
    var showAudit = false
    var galleryRequested = false
    var customTapeRequested = false
    var referenceRequested = false
    var paletteRequested = false

    /// True while any sheet/dialog is up — the machine must stop
    /// swallowing keystrokes so the UI can have them.
    var uiHasKeyboard: Bool {
        paletteRequested || referenceRequested || galleryRequested
            || customTapeRequested || welcomeRequested || recordRequested
            || aciInspectRequested
    }

    /// Authentic load speed: real ACI rate (~1500 bps + leader) instead
    /// of the ~3-second showcase load. Toggle in the Cassettes menu.
    var authenticLoads = false

    /// Cassette loading theater: name of the tape in the deck, or nil.
    private(set) var nowLoading: String?
    private var loadStartFrame = 0
    /// Whatever cassette currently sits in the deck (after loading too).
    private(set) var insertedTapeName: String?

    func ejectTape() {
        insertedTapeName = nil
        lastTape = nil
        lastCustomLoad = nil
        afterTapeCommand = nil
        sound.chipEject()
    }

    // Manual transport (the deck's keys are real)
    private var lastTape: Tape?
    private var lastCustomLoad: (name: String, data: Data, isBin: Bool)?

    /// PLAY: run the inserted cassette again, tape sound and all.
    func playInsertedTape() {
        ensure6502()
        if let tape = lastTape {
            insert(tape)
        } else if let custom = lastCustomLoad {
            stageLoad(name: custom.name, bytes: [UInt8](custom.data)) { [weak self] in
                self?.performCustom(name: custom.name, data: custom.data,
                                    isBin: custom.isBin)
            }
        }
    }

    /// STOP: kill a load mid-transfer — the bytes never arrive,
    /// exactly like stopping a real tape too early.
    func stopTape() {
        guard nowLoading != nil else { return }
        cancelInFlightLoad() // also flushes the queued run command (L3)
        sound.chipEject()
    }

    /// REW: counter back to 000 with a transport whirr.
    func rewindTape() {
        tapeCounter = 0
        sound.transportWhirr()
    }

    /// F.F: spin the counter forward a bit.
    func fastForwardTape() {
        tapeCounter += 47
        sound.transportWhirr()
    }
    private var loadFinishFrame = 0
    private var pendingLoad: (() -> Void)?
    var loadProgress: Double {
        guard nowLoading != nil else { return 0 }
        let span = max(1, loadFinishFrame - loadStartFrame)
        return max(0, min(1, Double(pulseFrame - loadStartFrame) / Double(span)))
    }

    /// Stage a cassette: machine assembles, the deck spins for ~3 s with
    /// the FSK warble, then `action` performs the actual load.
    /// Authentic ACI load: arm the tape on the bus, drive the real
    /// ROM with typed commands, and run the program when the tape ends.
    private func stageAuthenticACILoad(name: String, bytes: [UInt8],
                                       load: Int, run: String) {
        placeAll()
        connect(.power); connect(.display); connect(.keyboard)
        connect(.aciCard)
        nowLoading = name
        loadStartFrame = frame
        tapeCounter = 0
        insertedTapeName = name
        machine.armTape(bytes: bytes, leaderSeconds: 2.5)
        let duration = sound.tapePlay(bytes: bytes, authentic: true)
        loadFinishFrame = frame + Int(duration * 60)
        pendingLoad = nil
        afterTapeCommand = run
        autoType(String(format: "C100R\n%X.%XR\n",
                        load, load + bytes.count - 1))
    }

    @ObservationIgnored private var afterTapeCommand: String?

    private func stageLoad(name: String, bytes: [UInt8],
                           _ action: @escaping () -> Void) {
        placeAll()
        connect(.power); connect(.display); connect(.keyboard)
        connect(.aciCard)
        nowLoading = name
        loadStartFrame = frame
        tapeCounter = 0
        insertedTapeName = name
        // T1: the deck plays the tape's REAL waveform — the duration is
        // however long those bytes take at the ACI's actual bit rate
        let duration = sound.tapePlay(bytes: bytes, authentic: authenticLoads)
        loadFinishFrame = frame + (authenticLoads
            ? Int(duration * 60)
            : 170)
        pendingLoad = action
    }
    /// True while the screen lives in its own (monitor-styled) window.
    var screenDetached = false

    /// True while the keyboard floats in its own window.
    var keyboardDetached = false

    /// Full-screen display mode: just the Apple-1's picture.
    /// In: ⌘F or double-click the tube. Out: same, or ESC twice.
    var fullScreenDisplay = false
    private var lastEscFrame = -100

    /// 20 Hz heartbeat for ambient animation (reel spin, glow pulse,
    /// key flash). Views observe THIS, not `frame`, so the 60 Hz tick
    /// doesn't re-render the world three times more than needed.
    private(set) var pulseFrame = 0

    /// Frame at which mains power last came on (drives CRT warm-up).
    private(set) var poweredFrame: Int?

    /// 0...1 — how warmed-up the tube's phosphor is. Both the machine
    /// powering up and the monitor's own switch restart the warm-up.
    private(set) var crtWarmth: Double = 0

    private func updateWarmth() {
        var warmth: Double = 0
        if powered, let on = poweredFrame {
            warmth = min(1, Double(frame - on) / 110)
            if let monitorOn = monitorOnFrame {
                warmth = min(warmth, min(1, Double(frame - monitorOn) / 110))
            }
            warmth = max(0, warmth)
        }
        if abs(warmth - crtWarmth) > 0.02 || (warmth == 0) != (crtWarmth == 0)
            || (warmth == 1) != (crtWarmth == 1) {
            crtWarmth = warmth
        }
    }

    /// All board lighting theater — power-net surge/pulse and the
    /// chip activity glow — behind one switch.
    var lightingEffects = true

    /// CRT effects (curvature, scanlines, bloom, warm-up). Off = a
    /// clean, crisp display: the showcase becomes a plain emulator.
    var crtEffects = true

    enum CPUVariant: String { case mos6502, m6800 }

    /// The processor in the socket. Swapping to the 6800 populates the
    /// dotted-box parts and the (6800 ONLY) 7404 — and the machine
    /// goes silent, authentically: no 6800 firmware was ever written.
    var cpuVariant: CPUVariant = .mos6502 {
        didSet {
            guard cpuVariant != oldValue else { return }
            cancelInFlightLoad() // a swap aborts any load in progress
            clearCrashState()
            machine.clearTerminal()
            machine.reset()
            displayRevision += 1
        }
    }

    var populate6800: Bool { cpuVariant == .m6800 }

    /// Put the 6502 back in the socket. A no-op when it's already there;
    /// from the 6800 what-if, the didSet flushes load/crash state and resets.
    /// Called by every user action that means "run 6502 software" so the
    /// what-if can never strand a load or swallow keystrokes.
    func ensure6502() { cpuVariant = .mos6502 }

    /// Abort any cassette load in progress and flush the autotype queue —
    /// the shared cleanup behind reset/power-off/STOP/processor-swap.
    private func cancelInFlightLoad() {
        autoTypeQueue.removeAll()
        if nowLoading != nil { sound.tapeStop() }
        nowLoading = nil
        pendingLoad = nil
        afterTapeCommand = nil
    }

    /// Clear the "ran into garbage" crash heuristic.
    private func clearCrashState() {
        silentLowFrames = 0
        if looksCrashed { looksCrashed = false }
    }

    /// T5: CPU speed multiplier. 1 = the authentic 1.023 MHz (default);
    /// 10/100 = the modern impatience valve. The display governor is
    /// measured in CPU cycles, so under turbo the on-screen crawl speeds
    /// up too — which is the whole point for print-heavy programs. (Real
    /// hardware held 60 cps via the 60 Hz video field regardless of clock;
    /// turbo is an intentional anachronism, like the 100× clock itself.)
    var turboFactor = 1

    /// T9: the CRT's 15.7 kHz whine — authentic, optional, default off
    /// (it is genuinely irritating, which is the point).
    var flybackWhine = false

    /// T9: the deck's mechanical 3-digit counter.
    private(set) var tapeCounter = 0

    /// The monitor's own power switch (independent of machine power).
    /// Switching it on re-warms the tube, like any real CRT.
    var monitorOn = true {
        didSet {
            if monitorOn && !oldValue { monitorOnFrame = frame }
            if !monitorOn && oldValue { monitorOffFrame = frame }
        }
    }
    private var monitorOnFrame: Int?
    private(set) var monitorOffFrame: Int?

    /// Monitor front-panel controls (the knobs actually work).
    var crtBrightness: Double = 0   // -1...1
    var crtContrast: Double = 0    // -1...1
    var vHold: Double = 0          // off-center = the picture rolls

    /// Clicking the fact bar skips ahead in the rotation.
    private(set) var factOffset = 0
    func previousFact() {
        factOffset -= 1
    }

    func nextFact() { factOffset += 1 }

    /// Bumped only when the CRT content (or cursor blink) changes, so the
    /// terminal canvas doesn't redraw 60 times a second for nothing.
    private(set) var displayRevision = 0
    private(set) var cursorVisible = true
    private var lastTerminalRevision = -1

    // Tutorial state
    private(set) var tutorialStep: Int?
    private(set) var tutorialTrack = 0
    var tutorialSteps: [TutorialStep] { Tutorial.tracks[tutorialTrack].steps }
    private(set) var stepComplete = false
    private var transcriptMark = 0

    private var timer: Timer?
    private var keyMonitor: Any?
    private var videoChars = 0
    private var autoTypeQueue: [UInt8] = []
    @ObservationIgnored private var silentLowFrames = 0

    /// True when the CPU has been executing low memory with no output for
    /// a couple of seconds — the classic "ran garbage, hit BRK, looping
    /// through the zero vector" crash. Real Apple-1s did exactly this.
    private(set) var looksCrashed = false

    var allPlaced: Bool { placed.count == ChipGroup.allCases.count }
    var essentialsPlaced: Bool {
        ChipGroup.allCases.filter(\.essential).allSatisfy(placed.contains)
    }
    /// Mains makes the board live; what happens next depends on which
    /// chips are seated — each absence fails like the real hardware.
    var powered: Bool { connected.contains(.power) }
    var running: Bool { powered && placed.contains(.cpu) }

    init() {
        machine = try! Apple1()
        machine.displayCyclesPerChar = Apple1.cyclesPerFrame
        machine.onDisplay = { [weak self] _ in
            MainActor.assumeIsolated { self?.videoChars += 1 }
        }
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            MainActor.assumeIsolated { self.tick() }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // NSEvent is not Sendable; lift out the plain values first.
            // Held keys do NOT repeat — the Datanetics keyboard had no
            // auto-repeat, so neither do we.
            if event.isARepeat { return nil }
            let keyCode = event.keyCode
            let characters = event.characters
            let command = event.modifierFlags.contains(.command)
            let consumed = MainActor.assumeIsolated { () -> Bool in
                guard let self, !self.uiHasKeyboard else { return false }
                return self.handle(keyCode: keyCode, characters: characters,
                                   command: command)
            }
            return consumed ? nil : event
        }
    }

    private func tick() {
        if running && cpuVariant == .mos6502 {
            // The app "typing" for the tutorial, at a human ~20 cps.
            if !autoTypeQueue.isEmpty, frame % 3 == 0 {
                machine.press(autoTypeQueue.removeFirst())
            }
            machine.run(cycles: Apple1.cyclesPerFrame * turboFactor)
            let activity = machine.takeActivity()
            // The CPU is always fetching; everything else fades unless the
            // bus actually touched it this frame.
            update(.cpu, 1.0)
            update(.ramW, Double(activity.ramW) / 2000)
            update(.ramX, Double(activity.ramX) / 2000)
            update(.rom, Double(activity.rom) / 2000)
            update(.pia, Double(activity.pia) / 60)
            update(.video, Double(videoChars))
            // Crash heuristic: ROM/BASIC live at $E000+, so a quiet CPU
            // below that is running garbage, not waiting for input.
            if machine.pc < 0xE000 && videoChars == 0 {
                silentLowFrames += 1
                if silentLowFrames == 121 { looksCrashed = true }
            } else {
                silentLowFrames = 0
        if looksCrashed { looksCrashed = false }
            }
            videoChars = 0
        } else {
            for key in glow.keys { glow[key] = max(0, (glow[key] ?? 0) - 0.1) }
        }
        // The cursor blink comes from the terminal hardware — it keeps
        // blinking even with the CPU pulled, and dies with the video set.
        if nowLoading != nil, frame % 6 == 0 { tapeCounter += 1 }
        sound.flybackSet(flybackWhine && powered && monitorOn
                         && connected.contains(.display))
        if nowLoading != nil, frame >= loadFinishFrame {
            nowLoading = nil
            sound.tapeStop()
            let action = pendingLoad
            pendingLoad = nil
            action?()
            if let run = afterTapeCommand {
                afterTapeCommand = nil
                autoType(run + "\n")
            }
        }

        // A detuned V-HOLD or a warming tube needs continuous redraws
        if abs(vHold) > 0.08 || (powered && crtWarmth < 1) {
            displayRevision += 1
        }
        if frame % 3 == 0 { pulseFrame = frame }
        updateWarmth()
        let blink = powered && placed.contains(.video) && (frame / 15) % 2 == 0
        if machine.terminal.revision != lastTerminalRevision || blink != cursorVisible {
            lastTerminalRevision = machine.terminal.revision
            if cursorVisible != blink { cursorVisible = blink }
            displayRevision += 1
        }
        if let step = tutorialStep, !stepComplete {
            let new = String(machine.terminal.transcript.dropFirst(transcriptMark))
            if tutorialSteps[step].isComplete(self, new) { stepComplete = true }
        }
        frame += 1 // invalidates observers → redraw
    }

    // MARK: Tutorial

    func startTutorial(track: Int) {
        tutorialTrack = track
        startTutorial()
        runAutoAction()
    }

    private func runAutoAction() {
        guard let step = tutorialStep else { return }
        let s = tutorialSteps[step]
        if s.autoAction { s.action?(self) }
    }

    func startTutorial() {
        // You brought home an assembled board (the Byte Shop insisted) —
        // but power, keyboard, monitor and case were your problem.
        ensure6502() // the tour is a 6502 experience start to finish
        placeAll()
        for p in Peripheral.allCases { disconnect(p) }
        tutorialStep = 0
        beginStep()
    }

    func advanceTutorial() {
        guard let step = tutorialStep else { return }
        if step + 1 < tutorialSteps.count {
            tutorialStep = step + 1
            runAutoAction()
            beginStep()
        } else {
            endTutorial()
        }
    }

    func endTutorial() {
        tutorialStep = nil
        autoTypeQueue.removeAll()
    }

    func runStepAction() {
        guard let step = tutorialStep else { return }
        ensure6502() // a mid-tour processor swap shouldn't strand "Show me"
        tutorialSteps[step].action?(self)
    }

    private func beginStep() {
        transcriptMark = machine.terminal.transcript.count
        stepComplete = false
        autoTypeQueue.removeAll()
    }

    /// Feed keystrokes as if a patient demonstrator were typing them.
    func autoType(_ text: String) {
        for ch in text.uppercased().unicodeScalars where ch.isASCII {
            autoTypeQueue.append(ch == "\n" ? 0x0D : UInt8(ch.value))
        }
    }

    @ObservationIgnored private var rawGlow: [Region: Double] = [:]

    private func update(_ region: Region, _ intensity: Double) {
        // raw value evolves every tick; the OBSERVED value is quantized
        // to 1/12 steps so chip views only re-render on visible change
        let next = max((rawGlow[region] ?? 0) * 0.80, min(1.0, intensity))
        rawGlow[region] = next
        let quantized = (next * 12).rounded() / 12
        if glow[region] != quantized {
            glow[region] = quantized
        }
    }

    // MARK: Peripherals

    func connect(_ peripheral: Peripheral) {
        guard !connected.contains(peripheral) else { return }
        connected.insert(peripheral)
        // The ACI seats into the edge connector; plugs snap home
        if peripheral == .aciCard {
            sound.chipSeat()
            if let rom = try? ROM.wozaci() {
                machine.installACI(rom: rom)
            }
        } else {
            sound.connectorSnap()
        }
        if peripheral == .power {
            machine.powerUp() // DRAM wakes as noise; RAM contents are gone
            sound.powerOn()
            poweredFrame = frame
        }
    }

    func disconnect(_ peripheral: Peripheral) {
        if connected.remove(peripheral) != nil {
            sound.connectorPull()
        }
        if peripheral == .aciCard {
            machine.aciInstalled = false
        }
        if peripheral == .power {
            machine.powerDown()
            sound.powerOff()
            poweredFrame = nil
            cancelInFlightLoad()
            clearCrashState()
        }
    }

    func connectEverything() {
        placeAll()
        for p in Peripheral.allCases { connect(p) }
    }

    func toggle(_ peripheral: Peripheral) {
        if connected.contains(peripheral) {
            disconnect(peripheral)
        } else {
            connect(peripheral)
        }
    }

    func connectAll() {
        for g in ChipGroup.allCases { place(g) }
        for p in Peripheral.allCases { connect(p) }
    }

    // MARK: Chips

    func placeAll() {
        for g in ChipGroup.allCases { place(g) }
    }

    /// Set after a hot-reseat reset: RAM (and any loaded BASIC)
    /// survived — the info bar explains how to get back.
    private(set) var reseatHintUntil = 0
    var reseatHintActive: Bool { pulseFrame < reseatHintUntil }

    func place(_ group: ChipGroup) {
        placed.insert(group)
        sound.chipSeat()
        syncSockets()
        // Hot-seating the brain or its ROM restarts execution cleanly
        if powered, group == .cpu || group == .proms {
            machine.reset()
            reseatHintUntil = frame + 700
        }
    }

    /// Pull a chip set out of its sockets. Each absence fails the way
    /// the real hardware does (see Apple1's socket flags).
    func unplace(_ group: ChipGroup) {
        placed.remove(group)
        sound.chipEject()
        syncSockets()
        if group == .cpu { clearCrashState() } // a pulled CPU isn't "crashed"
        recentlyRemoved[group] = frame
    }

    /// Per-group removal timestamps — every pulled chip gets its own
    /// transient callout in the shelf rail.
    private(set) var recentlyRemoved: [ChipGroup: Int] = [:]

    private func syncSockets() {
        machine.ramXInstalled = placed.contains(.ramX)
        machine.ramWInstalled = placed.contains(.ramW)
        machine.romInstalled = placed.contains(.proms)
        machine.piaInstalled = placed.contains(.pia)
        machine.videoInstalled = placed.contains(.video)
    }

    /// Pull every socketed chip — the bare board a hobbyist started from.
    func stripBoard() {
        placed.removeAll()
        syncSockets()
        for p in Peripheral.allCases { disconnect(p) }
    }

    /// Set up whatever the program needs, then type it in on-screen.
    func run(_ program: DemoProgram) {
        ensure6502() // running software means the 6502 goes back in
        placeAll()
        connect(.power); connect(.display); connect(.keyboard)
        if program.needsBASIC {
            connect(.aciCard)
            loadBASIC()
        } else {
            reset()
        }
        autoType(program.text)
    }

    /// Insert a cassette: sets the machine up, loads the tape the way
    /// 1976 did (binaries at their address, BASIC games typed in fast),
    /// and runs it.
    func insert(_ tape: Tape) {
        ensure6502()
        lastTape = tape
        lastCustomLoad = nil
        if authenticLoads {
            // kinds with raw bytes go through the REAL ACI ROM
            switch tape.kind {
            case .integerBASIC:
                if let basic = try? ROM.integerBASIC() {
                    stageAuthenticACILoad(name: tape.name, bytes: basic,
                                          load: 0xE000, run: "E000R")
                    return
                }
            case .binary(let file, let load, let run):
                if let bytes = TapeLibrary.binary(file) {
                    stageAuthenticACILoad(name: tape.name, bytes: bytes,
                                          load: Int(load), run: run)
                    return
                }
            default:
                break // source/image tapes use the deposit path
            }
        }
        let bytes: [UInt8]
        switch tape.kind {
        case .integerBASIC:
            bytes = (try? ROM.integerBASIC()) ?? Array(repeating: 0, count: 4096)
        case .basicSource(let file):
            bytes = Array((TapeLibrary.basicSource(file) ?? "").utf8)
        case .binary(let file, _, _):
            bytes = TapeLibrary.binary(file) ?? []
        case .basicImage(let file, _):
            bytes = TapeLibrary.binary(file) ?? []
        }
        stageLoad(name: tape.name, bytes: bytes) { [weak self] in
            self?.performInsert(tape)
        }
    }

    private func performInsert(_ tape: Tape) {
        switch tape.kind {
        case .integerBASIC:
            loadBASIC()
        case .basicSource(let file):
            guard let source = TapeLibrary.basicSource(file) else { return }
            loadBASIC()
            // TurboType: feed and crunch the listing at tape speed
            machine.displayCyclesPerChar = 0
            machine.type(source + "\n")
            machine.run(cycles: 80_000_000)
            machine.displayCyclesPerChar = Apple1.cyclesPerFrame
            autoType("RUN\n")
        case .basicImage(let file, let load):
            guard let image = TapeLibrary.binary(file) else { return }
            loadBASIC() // cold boot gives a sane zero page
            machine.displayCyclesPerChar = 0
            machine.run(cycles: 6_000_000)
            machine.displayCyclesPerChar = Apple1.cyclesPerFrame
            machine.load(image, at: load)
            // point BASIC's program pointers at the image
            let pointer = [UInt8(load & 0xFF), UInt8(load >> 8)]
            machine.load(pointer, at: 0x00CA)
            machine.load(pointer, at: 0x00E4)
            machine.load(pointer, at: 0x00E6)
            autoType("E2B3R\nRUN\n")
        case .binary(let file, let load, let run):
            guard let bytes = TapeLibrary.binary(file) else { return }
            reset()
            machine.load(bytes, at: load)
            autoType("\(run)\n")
        }
    }

    /// Load a user-supplied cassette. Three formats, auto-detected:
    /// wozmon paste text ("0300: A9 0D ..." — addresses are inline),
    /// BASIC source (numbered lines — typed into BASIC and RUN), or a
    /// raw .bin (loads at $0300, or at the address in a "name@0280.bin"
    /// style filename; runs from the load address).
    func insertCustom(url: URL) {
        ensure6502()
        let title = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.lowercased()
        if ["wav", "aif", "aiff", "mp3", "m4a"].contains(ext) {
            // a real tape recording: decode the FSK back into bytes
            guard let bytes = try? TapeDecoder.decode(url: url) else { return }
            lastTape = nil
            lastCustomLoad = (title, Data(bytes), true)
            stageLoad(name: title, bytes: bytes) { [weak self] in
                self?.performCustom(name: title, data: Data(bytes), isBin: true)
            }
            return
        }
        guard let data = try? Data(contentsOf: url) else { return }
        lastTape = nil
        lastCustomLoad = (title, data, ext == "bin")
        stageLoad(name: title, bytes: [UInt8](data)) { [weak self] in
            self?.performCustom(name: title, data: data,
                                isBin: ext == "bin")
        }
    }

    private func performCustom(name: String, data: Data, isBin: Bool) {
        if isBin {
            var load: UInt16 = 0x0300
            if let at = name.split(separator: "@").last,
               let parsed = UInt16(at, radix: 16) {
                load = parsed
            }
            reset()
            machine.load([UInt8](data), at: load)
            autoType(String(format: "%X", load) + "R\n")
            return
        }
        guard let text = String(data: data, encoding: .utf8) else { return }
        let wozLines = TapeText.parse(text)
        if !wozLines.isEmpty {
            reset()
            var first: UInt16?
            for (address, bytes) in wozLines {
                machine.load(bytes, at: address)
                if first == nil { first = address }
            }
            let hasZP = wozLines.contains { $0.address < 0x0100 }
            if hasZP {
                // a real-style BASIC program tape (pointers + program)
                // the interpreter must be present; then warm-enter so
                // it adopts the restored pointers
                if let basic = try? ROM.integerBASIC() {
                    machine.load(basic, at: 0xE000)
                }
                for (address, chunk) in wozLines {
                    machine.load(chunk, at: address)
                }
                autoType("E2B3R\n")
            } else if let start = first {
                autoType(String(format: "%X", start) + "R\n")
            }
        } else {
            // assume BASIC source: TurboType it in and RUN
            loadBASIC()
            machine.displayCyclesPerChar = 0
            machine.type(text + "\n")
            machine.run(cycles: 80_000_000)
            machine.displayCyclesPerChar = Apple1.cyclesPerFrame
            autoType("RUN\n")
        }
    }

    /// Parse wozmon paste format: lines of "XXXX: HH HH HH ...".
    private func wozmonChunks(_ text: String) -> [(UInt16, [UInt8])] {
        var chunks: [(UInt16, [UInt8])] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":")
            guard parts.count == 2,
                  let address = UInt16(parts[0].trimmingCharacters(in: .whitespaces),
                                       radix: 16) else { continue }
            let bytes = parts[1].split(separator: " ").compactMap {
                UInt8($0, radix: 16)
            }
            guard !bytes.isEmpty else { continue }
            chunks.append((address, bytes))
        }
        return chunks
    }

    /// Most recent keypress (from either keyboard) — the on-screen
    /// caps flash to match.
    private(set) var keyFlash: (ascii: UInt8, frame: Int)?

    /// A click on the on-screen keyboard: connects the keyboard if
    /// needed (using it IS plugging it in), then types.
    func typeKey(_ ascii: UInt8) {
        if !connected.contains(.keyboard) { connect(.keyboard) }
        machine.press(ascii)
        keyFlash = (ascii, frame)
        sound.keyClick()
    }

    /// The Datanetics CLR SCR key: hardware-clears the terminal.
    func clearScreen() {
        machine.clearTerminal()
        displayRevision += 1
    }

    // MARK: Tape recording (P1)

    var recordRequested = false
    var aciInspectRequested = false
    /// FittedBoard sets this while pinch-zoomed; overhanging visuals
    /// (the seated ACI's protruding edge) hide to avoid odd pop-out.
    var boardZoomed = false

    /// Save a memory range as a cassette: a wozmon-format .txt (loads
    /// straight back via Load Custom Cassette) and a bit-true .wav —
    /// the same audio a real ACI would have put on tape.
    func recordTape(name: String, from: Int, to: Int) {
        recordTape(name: name, ranges: [(from, to)])
    }

    /// Real BASIC tapes carried TWO ranges — the zero-page pointer
    /// block and the program bank. This writes any number of ranges
    /// into one wozmon text (the .wav holds the concatenated bytes).
    func recordTape(name: String, ranges: [(from: Int, to: Int)]) {
        var sections: [String] = []
        var allBytes: [UInt8] = []
        for range in ranges {
            let bytes = machine.read(from: range.from, to: range.to)
            sections.append(TapeText.encode(bytes: bytes, from: range.from))
            allBytes += bytes
        }
        let text = sections.joined(separator: "\n")
        let bytes = allBytes
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(name).woz.txt"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? text.write(to: url, atomically: true, encoding: .utf8)
        // Only a single contiguous range round-trips faithfully as one .wav
        // (a flat stream has no addresses; no real tape concatenated two
        // non-contiguous ranges). Multi-range tapes keep just the .woz.txt,
        // which preserves each range and warm-restarts BASIC correctly.
        if ranges.count == 1 {
            let wavURL = url.deletingPathExtension().deletingPathExtension()
                .appendingPathExtension("wav")
            try? sound.writeTapeWAV(bytes: bytes, to: wavURL)
        }
        sound.tapeLoad() // a little record-head chirp for the moment
        insertedTapeName = name.uppercased()
    }

    // MARK: Snapshots (T6)

    private struct BenchState: Codable {
        var machine: Apple1.Snapshot
        var placed: [String]
        var connected: [String]
        var cpuVariant: String? // optional: snapshots predating the 6800 swap
    }

    func saveSnapshot() {
        let state = BenchState(
            machine: machine.takeSnapshot(),
            placed: placed.map(\.rawValue),
            connected: connected.map(\.rawValue),
            cpuVariant: cpuVariant.rawValue)
        guard let data = try? JSONEncoder().encode(state) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Apple-1 Session.a1state"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? data.write(to: url)
    }

    func restoreSnapshot() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(BenchState.self, from: data),
              state.machine.mem.count == 0x10000,
              state.machine.screen.count == Terminal.columns * Terminal.rows
        else { return } // reject a corrupt/foreign file before touching live state
        placed = Set(state.placed.compactMap(ChipGroup.init(rawValue:)))
        connected = Set(state.connected.compactMap(Peripheral.init(rawValue:)))
        // Set the variant BEFORE restoring: the didSet resets/clears, then
        // machine.restore overwrites with the saved mem/regs/screen.
        cpuVariant = CPUVariant(rawValue: state.cpuVariant ?? "") ?? .mos6502
        syncSockets()
        // Re-derive ACI from `connected` the way syncSockets does for the
        // other sockets — otherwise the card's bus behavior desyncs.
        if connected.contains(.aciCard), let rom = try? ROM.wozaci() {
            machine.installACI(rom: rom)
        } else {
            machine.aciInstalled = false
        }
        machine.restore(state.machine)
        // Anchor the warm-up clocks so a restored-powered tube actually
        // warms (instead of pinning cold and forcing a redraw every frame).
        if connected.contains(.power) {
            poweredFrame = frame
            if monitorOn { monitorOnFrame = frame }
        }
        displayRevision += 1
    }

    /// ⌘V: type the clipboard into the machine, 1976-style.
    func paste() {
        ensure6502()
        guard powered, connected.contains(.keyboard),
              let text = NSPasteboard.general.string(forType: .string) else { return }
        autoType(String(text.prefix(2000)))
    }

    // MARK: Input

    /// Set while the user types at a machine that can't hear them.
    private(set) var typingHintUntil = 0
    private var strayKeys = 0
    private var lastStrayFrame = -1000

    var typingHintActive: Bool { pulseFrame < typingHintUntil }

    private func handle(keyCode: UInt16, characters: String?, command: Bool) -> Bool {
        if command { return false }
        guard powered, connected.contains(.keyboard) else {
            // typing at a deaf machine: after a few keys, say why
            if frame - lastStrayFrame > 300 { strayKeys = 0 }
            strayKeys += 1
            lastStrayFrame = frame
            if strayKeys >= 3 { typingHintUntil = frame + 480 }
            return false
        }
        // While the tutorial is "typing", swallow the user's keys —
        // interleaving the two garbles the demo input line.
        if !autoTypeQueue.isEmpty { return true }
        if keyCode == 53 { // esc — Woz Monitor line cancel
            if fullScreenDisplay, frame - lastEscFrame < 35 {
                fullScreenDisplay = false // double-ESC exits full screen
                return true
            }
            lastEscFrame = frame
            machine.press(0x1B)
            keyFlash = (0x1B, frame)
            sound.keyClick()
            return true
        }
        guard let scalar = characters?.uppercased().unicodeScalars.first,
              scalar.isASCII else { return false }
        switch scalar.value {
        case 0x0D, 0x03: machine.press(0x0D)
        case 0x7F: machine.press(0x5F) // delete → "_", the Apple-1 rubout
        case 0x20...0x5F: machine.press(UInt8(scalar.value))
        default: return false
        }
        keyFlash = (scalar.value == 0x7F ? 0x5F
                    : scalar.value == 0x03 ? 0x0D
                    : UInt8(truncatingIfNeeded: scalar.value), frame)
        sound.keyClick()
        return true
    }

    func reset() {
        guard powered else { return }
        clearCrashState()
        machine.reset()
    }

    /// Drop Integer BASIC into RAM at $E000 and type E000R — the same
    /// result as loading the cassette, minus the wait. Needs the ACI.
    /// Resets first so it works from any state, including a crashed CPU
    /// or a runaway program.
    func loadBASIC() {
        ensure6502()
        guard powered, connected.contains(.aciCard), placed.contains(.ramX),
              let basic = try? ROM.integerBASIC() else { return }
        reset()
        machine.load(basic, at: 0xE000)
        machine.type("E000R\n")
    }
}
