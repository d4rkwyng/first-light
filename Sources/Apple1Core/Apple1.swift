import CFake6502
import Foundation

/// A complete Apple-1: 6502 CPU, RAM, Woz Monitor ROM, PIA 6820, and the
/// terminal section. fake6502 keeps its CPU state in C globals, so exactly
/// one machine can exist at a time; the most recently created instance owns
/// the CPU.
public final class Apple1 {
    // MARK: Memory map
    // $0000-$0FFF  4 KB RAM (on-board, bank "W")
    // $D010-$D013  PIA 6820: KBD, KBDCR, DSP, DSPCR
    // $E000-$EFFF  4 KB RAM (second bank "X" — Integer BASIC loads here)
    // $FF00-$FFFF  Woz Monitor ROM (256 bytes)

    static let kbd: UInt16 = 0xD010
    static let kbdcr: UInt16 = 0xD011
    static let dsp: UInt16 = 0xD012
    static let dspcr: UInt16 = 0xD013

    /// One video frame of CPU cycles. The Apple-1 clock is derived from
    /// the NTSC colorburst: 14.31818 MHz ÷ 14 = 1.0227 MHz; ÷ 60 Hz =
    /// 17,045 cycles. The display accepts at most one character per
    /// frame — the famous ~60 chars/sec crawl.
    public static let cyclesPerFrame = 17045

    nonisolated(unsafe) static var current: Apple1?

    var mem = [UInt8](repeating: 0, count: 0x10000)
    public private(set) var terminal = Terminal()

    /// Cycles the display takes to accept a character. 0 = instant
    /// (for tests and turbo demos); `Apple1.cyclesPerFrame` = authentic.
    public var displayCyclesPerChar = 0

    /// Whether the second 4 KB bank ($E000, "bank X") is populated. The
    /// base machine shipped with 4 KB; the second bank was the upgrade
    /// that made room for BASIC.
    public var ramXInstalled = true

    /// Socket flags for the other pullable parts. Each absence fails the
    /// way the real hardware does: no PROMs → the reset vector floats and
    /// the CPU leaps into garbage; no bank W → zero page and stack are
    /// gone, the first subroutine call crashes; no PIA → blind and deaf;
    /// no terminal section → the display handshake never answers and the
    /// CPU hangs waiting for it.
    public var ramWInstalled = true
    public var romInstalled = true
    public var piaInstalled = true
    public var videoInstalled = true

    /// The Apple Cassette Interface: its 256-byte ROM at $C100, with
    /// the famous input trick at $C0xx — the tape signal drives address
    /// bit 0, so reads return ROM bytes selected by the input level.
    public var aciInstalled = false
    private var aciROM: [UInt8] = []

    public func installACI(rom: [UInt8]) {
        precondition(rom.count == 256, "ACI ROM must be 256 bytes")
        aciROM = rom
        aciInstalled = true
    }

    // Cycle-timed tape playback for authentic ACI loads
    private var tapeTransitions: [UInt64] = []
    private var tapeStart: UInt64?
    private var tapeIndex = 0

    /// Queue a tape; the signal clock anchors to the FIRST $C0xx poll,
    /// so the ROM always hears the leader from its beginning.
    public func armTape(bytes: [UInt8], leaderSeconds: Double = 6.0,
                        speed: Double = 1.0, byteGapUs: Double = 0) {
        tapeTransitions = TapeEncoding.transitions(bytes: bytes,
                                                   leaderSeconds: leaderSeconds,
                                                   speed: speed,
                                                   byteGapUs: byteGapUs)
        tapeStart = nil
        tapeIndex = 0
    }

    /// Debug probe: current level + internals.
    public func tapeProbe() -> (level: Int, index: Int, anchored: Bool, total: Int) {
        (tapeLevel(), tapeIndex, tapeStart != nil, tapeTransitions.count)
    }

    public var tapePlaying: Bool {
        !tapeTransitions.isEmpty
            && (tapeStart == nil
                || tapeIndex < tapeTransitions.count)
    }

    private func tapeLevel() -> Int {
        guard !tapeTransitions.isEmpty else { return 0 }
        if tapeStart == nil { tapeStart = totalCycles }
        let elapsed = totalCycles - tapeStart!
        while tapeIndex < tapeTransitions.count,
              tapeTransitions[tapeIndex] <= elapsed {
            tapeIndex += 1
        }
        if tapeIndex >= tapeTransitions.count {
            tapeTransitions = [] // tape ran out
            return 0
        }
        return tapeIndex % 2 == 0 ? 1 : 0
    }

    public private(set) var totalCycles: UInt64 = 0

    /// Current program counter (for debugging and the future board view).
    public var pc: UInt16 { fake6502_pc() }

    /// Full register file (the Scope inspector reads these).
    public var registers: (a: UInt8, x: UInt8, y: UInt8, sp: UInt8, status: UInt8, pc: UInt16) {
        (fake6502_a(), fake6502_x(), fake6502_y(),
         fake6502_sp(), fake6502_status(), fake6502_pc())
    }

    // PIA state. Control-register bit 2 selects whether the port address
    // reaches the data register (1) or the data-direction register (0) —
    // wozmon's first `STY DSP` is a DDR setup write, not a character.
    private var keyQueue: [UInt8] = []
    private var lastKey: UInt8 = 0
    private var kbdCR: UInt8 = 0
    private var dspCR: UInt8 = 0
    private var dspChar: UInt8 = 0
    private var dspBusyUntil: UInt64 = 0
    private var dspPending = false

    /// Called whenever the terminal accepts a character (UI refresh hook).
    public var onDisplay: ((UInt8) -> Void)?

    /// Bus-access counts since the last `takeActivity()` — drives the
    /// board view's chip-activity glow. `pia` counts real I/O events
    /// (keys consumed, characters written), not idle polling.
    public struct Activity {
        public var ramW = 0   // $0000-$0FFF
        public var ramX = 0   // $E000-$EFFF
        public var rom = 0    // $FF00-$FFFF (wozmon PROMs)
        public var pia = 0
    }
    private var activity = Activity()

    public func takeActivity() -> Activity {
        defer { activity = Activity() }
        return activity
    }

    public init(wozmon: [UInt8]) {
        precondition(wozmon.count == 256, "Woz Monitor ROM must be 256 bytes")
        mem.replaceSubrange(0xFF00...0xFFFF, with: wozmon)
        Apple1.current = self
        reset()
    }

    public convenience init() throws {
        self.init(wozmon: try ROM.wozmon())
    }

    // MARK: Control

    /// Mains power removed: the display loses its loop and pending I/O dies.
    public func powerDown() {
        terminal.clear()
        keyQueue.removeAll()
        dspPending = false
    }

    /// Mains power restored: DRAM wakes up full of noise (it held its
    /// contents only while refreshed), then the 6502 takes the reset
    /// vector. Anything you had in RAM — including BASIC — is gone.
    public func powerUp() {
        var state = UInt32(truncatingIfNeeded: totalCycles) | 1
        for range in [0x0000...0x0FFF, 0xE000...0xEFFF] {
            for address in range {
                state = state &* 1664525 &+ 1013904223 // LCG noise
                mem[address] = UInt8(truncatingIfNeeded: state >> 16)
            }
        }
        reset()
    }

    // MARK: Snapshots (T6)

    public struct Snapshot: Codable {
        public var mem: Data
        public var a, x, y, sp, status: UInt8
        public var pc: UInt16
        public var totalCycles: UInt64
        public var kbdCR, dspCR, dspChar: UInt8
        public var dspBusyUntil: UInt64
        public var dspPending: Bool
        public var keyQueue: [UInt8]
        public var lastKey: UInt8
        public var ramX, ramW, rom, pia, video: Bool
        public var screen: Data
        public var cursorX, cursorY: Int
        public var transcript: String
    }

    public func takeSnapshot() -> Snapshot {
        Snapshot(mem: Data(mem),
                 a: fake6502_a(), x: fake6502_x(), y: fake6502_y(),
                 sp: fake6502_sp(), status: fake6502_status(),
                 pc: fake6502_pc(), totalCycles: totalCycles,
                 kbdCR: kbdCR, dspCR: dspCR, dspChar: dspChar,
                 dspBusyUntil: dspBusyUntil, dspPending: dspPending,
                 keyQueue: keyQueue, lastKey: lastKey,
                 ramX: ramXInstalled, ramW: ramWInstalled,
                 rom: romInstalled, pia: piaInstalled,
                 video: videoInstalled,
                 screen: Data(terminal.screen),
                 cursorX: terminal.cursorX, cursorY: terminal.cursorY,
                 transcript: terminal.transcript)
    }

    public func restore(_ snap: Snapshot) {
        guard snap.mem.count == 0x10000 else { return } // reject a corrupt image
        mem = [UInt8](snap.mem)
        fake6502_restore(snap.a, snap.x, snap.y, snap.sp, snap.status, snap.pc)
        totalCycles = snap.totalCycles
        kbdCR = snap.kbdCR
        dspCR = snap.dspCR
        dspChar = snap.dspChar
        dspBusyUntil = snap.dspBusyUntil
        dspPending = snap.dspPending
        keyQueue = snap.keyQueue
        lastKey = snap.lastKey
        ramXInstalled = snap.ramX
        ramWInstalled = snap.ramW
        romInstalled = snap.rom
        piaInstalled = snap.pia
        videoInstalled = snap.video
        terminal.restore(screen: [UInt8](snap.screen),
                         cursorX: snap.cursorX, cursorY: snap.cursorY,
                         transcript: snap.transcript)
    }

    /// The keyboard's CLR SCR key: clears the terminal hardware.
    public func clearTerminal() {
        terminal.clear()
    }

    public func reset() {
        keyQueue.removeAll()
        kbdCR = 0
        dspCR = 0
        dspPending = false
        dspBusyUntil = 0
        reset6502()
    }

    /// Run the CPU for at least `cycles` clock ticks.
    public func run(cycles: Int) {
        let start = fake6502_clockticks()
        while Int(fake6502_clockticks() &- start) < cycles {
            let before = fake6502_clockticks()
            step6502()
            totalCycles &+= UInt64(fake6502_clockticks() &- before)
            serviceDisplay()
        }
    }

    private func serviceDisplay() {
        // No terminal section → the CB1 "frame done" pulse never comes;
        // the display stays busy forever and the CPU waits on it.
        guard videoInstalled else { return }
        if dspPending && totalCycles >= dspBusyUntil {
            dspPending = false
            terminal.put(dspChar)
            onDisplay?(dspChar)
        }
    }

    // MARK: Keyboard

    /// Queue one ASCII key press (the PIA sets bit 7 on read, as the
    /// keyboard hardware did).
    public func press(_ ascii: UInt8) {
        keyQueue.append(ascii)
    }

    /// Type a whole string: uppercased, "\n" becomes CR.
    public func type(_ text: String) {
        for ch in text.uppercased().unicodeScalars {
            if ch == "\n" {
                press(0x0D)
            } else if ch.isASCII {
                press(UInt8(ch.value))
            }
        }
    }

    /// Deposit a binary image into RAM (e.g. Integer BASIC at 0xE000).
    public func load(_ bytes: [UInt8], at address: UInt16) {
        let start = Int(address)
        mem.replaceSubrange(start ..< start + bytes.count, with: bytes)
    }

    public func peek(_ address: UInt16) -> UInt8 { mem[Int(address)] }

    /// A copy of a memory range (for tape recording).
    public func read(from: Int, to: Int) -> [UInt8] {
        let lo = max(0, min(from, 0xFFFF))
        let hi = max(lo, min(to, 0xFFFF))
        return Array(mem[lo...hi])
    }

    /// What the CPU would READ at `address` right now — floating 0xFF over empty
    /// sockets, the ACI ROM at $C0/$C1xx, the PIA registers. Side-effect-free,
    /// unlike `busRead` (no activity counted, no key consumed, no tape advanced):
    /// the Scope's panes must show exactly what the 6502 sees, not the raw array.
    public func busPeek(_ address: UInt16) -> UInt8 {
        switch address {
        case Apple1.kbd:   return piaInstalled ? (lastKey | 0x80) : 0xFF
        case Apple1.kbdcr: return piaInstalled ? ((keyQueue.isEmpty ? 0x00 : 0x80) | (kbdCR & 0x3F)) : 0x00
        case Apple1.dsp:   return piaInstalled ? (dspPending ? 0x80 : 0x00) : 0x00
        case Apple1.dspcr: return dspCR & 0x3F
        case 0x0000...0x0FFF: return ramWInstalled ? mem[Int(address)] : 0xFF
        case 0xE000...0xEFFF: return ramXInstalled ? mem[Int(address)] : 0x00
        case 0xC000...0xC1FF: return aciInstalled ? aciROM[Int(address) & 0xFF] : 0xFF
        case 0xFF00...0xFFFF: return romInstalled ? mem[Int(address)] : 0xFF
        default: return mem[Int(address)]
        }
    }

    /// Range version of `busPeek`, for the Scope's memory dump.
    public func busPeek(from: Int, to: Int) -> [UInt8] {
        let lo = max(0, min(from, 0xFFFF)), hi = max(lo, min(to, 0xFFFF))
        return (lo...hi).map { busPeek(UInt16($0)) }
    }

    // MARK: Bus (called from the fake6502 trampolines)

    func busRead(_ address: UInt16) -> UInt8 {
        switch address {
        case Apple1.kbd:
            guard piaInstalled else { return 0xFF } // floating bus
            guard kbdCR & 0x04 != 0 else { return 0x00 } // DDR selected
            if !keyQueue.isEmpty {
                lastKey = keyQueue.removeFirst()
                activity.pia += 60 // a key is a big event, not one cycle
            }
            return lastKey | 0x80
        case Apple1.kbdcr:
            guard piaInstalled else { return 0x00 } // no key ever ready
            return (keyQueue.isEmpty ? 0x00 : 0x80) | (kbdCR & 0x3F)
        case Apple1.dsp:
            guard piaInstalled else { return 0x00 } // writes vanish happily
            guard dspCR & 0x04 != 0 else { return 0x00 } // DDR selected
            return dspPending ? 0x80 : 0x00
        case Apple1.dspcr:
            return dspCR & 0x3F
        default:
            switch address {
            case 0x0000...0x0FFF:
                guard ramWInstalled else { return 0xFF } // empty sockets
                activity.ramW += 1
            case 0xE000...0xEFFF:
                guard ramXInstalled else { return 0x00 } // empty sockets
                activity.ramX += 1
            case 0xC000...0xC0FF:
                guard aciInstalled else { return 0xFF }
                // tape input drives A0: ROM byte selected by the signal
                return aciROM[(Int(address) & 0xFE | tapeLevel()) & 0xFF]
            case 0xC100...0xC1FF:
                guard aciInstalled else { return 0xFF }
                return aciROM[Int(address) & 0xFF]
            case 0xFF00...0xFFFF:
                guard romInstalled else { return 0xFF } // floating vector
                activity.rom += 1
            default: break
            }
            return mem[Int(address)]
        }
    }

    func busWrite(_ address: UInt16, _ value: UInt8) {
        switch address {
        case Apple1.dsp:
            guard dspCR & 0x04 != 0 else { break } // DDR setup write
            dspChar = value
            dspPending = true
            dspBusyUntil = totalCycles &+ UInt64(displayCyclesPerChar)
            activity.pia += 60
        case Apple1.kbdcr:
            kbdCR = value
        case Apple1.dspcr:
            dspCR = value
        case Apple1.kbd:
            break // port A is wired as input; DDR write changes nothing
        case 0x0000...0x0FFF:
            guard ramWInstalled else { break }
            activity.ramW += 1
            mem[Int(address)] = value
        case 0xE000...0xEFFF:
            guard ramXInstalled else { break }
            activity.ramX += 1
            mem[Int(address)] = value
        default:
            break // unpopulated address space or ROM: writes float away
        }
    }
}

// fake6502's externally-provided memory bus.
@_cdecl("read6502")
func fl_read6502(_ address: UInt16) -> UInt8 {
    Apple1.current?.busRead(address) ?? 0
}

@_cdecl("write6502")
func fl_write6502(_ address: UInt16, _ value: UInt8) {
    Apple1.current?.busWrite(address, value)
}
