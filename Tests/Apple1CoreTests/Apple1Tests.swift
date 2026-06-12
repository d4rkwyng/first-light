import Testing
@testable import Apple1Core

/// Run until the transcript contains `needle` or the cycle budget runs out.
@discardableResult
func runUntil(_ machine: Apple1, contains needle: String,
              maxCycles: Int = 20_000_000) -> Bool {
    var spent = 0
    while spent < maxCycles {
        machine.run(cycles: 10_000)
        spent += 10_000
        if machine.terminal.transcript.contains(needle) { return true }
    }
    return false
}

@Suite(.serialized) struct Apple1Tests {

    @Test func wozmonBootsAndPrompts() throws {
        let m = try Apple1()
        // On reset the monitor prints "\" then CR and waits for input.
        #expect(runUntil(m, contains: "\\", maxCycles: 1_000_000))
    }

    @Test func wozmonEchoesAndExaminesMemory() throws {
        let m = try Apple1()
        m.type("FF00.FF0F\n")
        // The monitor dumps 8 bytes per line; the ROM starts D8 58 A0 7F.
        #expect(runUntil(m, contains: "FF00: D8 58 A0 7F 8C 12 D0 A9"))
        #expect(m.terminal.transcript.contains("FF08:"))
    }

    @Test func wozmonDepositsBytes() throws {
        let m = try Apple1()
        m.type("300: A9 8D 20 EF FF\n")
        runUntil(m, contains: "0300: A9")
        #expect(m.peek(0x0300) == 0xA9)
        #expect(m.peek(0x0301) == 0x8D)
        #expect(m.peek(0x0304) == 0xFF)
    }

    @Test func runsTheOperationManualSampleProgram() throws {
        // The 1976 Operation Manual's first program: print the character
        // set forever (LDA #0; TAX; loop: JSR ECHO; INX; TXA; JMP loop).
        let m = try Apple1()
        m.type("0:A9 0 AA 20 EF FF E8 8A 4C 2 0\n")
        m.run(cycles: 200_000)
        m.type("0R\n")
        // Each 128-char pass wraps the 40-column screen after CR at $0D:
        // chars $48-$6F land at the start of a line, so H..Z is contiguous.
        #expect(runUntil(m, contains: "HIJKLMNOPQRSTUVWXYZ"))
    }

    @Test func integerBASICBootsAndRunsAProgram() throws {
        let m = try Apple1()
        m.load(try ROM.integerBASIC(), at: 0xE000)
        m.type("E000R\n")
        #expect(runUntil(m, contains: ">"), "BASIC should print its > prompt")
        m.type("10 PRINT \"HELLO FROM 1976\"\n")
        m.type("20 END\n")
        m.type("RUN\n")
        #expect(runUntil(m, contains: "HELLO FROM 1976"))
    }

    @Test func displayGovernorThrottlesTo60cps() throws {
        let m = try Apple1()
        m.displayCyclesPerChar = Apple1.cyclesPerFrame
        m.type("FF00.FFFF\n")
        // One second of CPU time can emit at most ~60 characters.
        m.run(cycles: 1_023_000)
        #expect(m.terminal.transcript.count <= 62)
        #expect(m.terminal.transcript.count > 30)
    }

    @Test func activityCountersTrackBusTraffic() throws {
        let m = try Apple1()
        m.run(cycles: 50_000) // boot: prints "\" and CR through the PIA
        var a = m.takeActivity()
        #expect(a.rom > 0, "wozmon executes from the PROMs")
        m.run(cycles: 100_000) // now idle at the prompt, just polling
        a = m.takeActivity()
        #expect(a.pia == 0, "idle polling is not I/O activity")
        m.type("A\n")
        m.run(cycles: 100_000)
        a = m.takeActivity()
        #expect(a.pia > 0, "consuming keys and echoing counts as PIA activity")
    }

    @Test func powerCycleLosesRAMAndScreen() throws {
        let m = try Apple1()
        m.type("300: A9 5C\n")
        runUntil(m, contains: "0300: A9")
        #expect(m.peek(0x0300) == 0xA9)
        #expect(m.terminal.line(0).contains("\\"))
        m.powerDown()
        #expect(m.terminal.line(0).trimmingCharacters(in: .whitespaces).isEmpty)
        m.powerUp()
        // DRAM woke up as noise; deposited bytes shouldn't have survived
        // as a coherent pair, and the monitor must boot fresh.
        #expect(!(m.peek(0x0300) == 0xA9 && m.peek(0x0301) == 0x5C))
        #expect(runUntil(m, contains: "\\", maxCycles: 1_000_000))
    }

    @Test func terminalRendersLikeTheHardware() throws {
        var t = Terminal()
        for b in Array("HELLO".utf8) { t.put(b) }
        #expect(t.line(0).hasPrefix("HELLO"))
        // The 2513 only has 64 glyphs: lowercase 'h' ($68) renders as the
        // 6-bit-truncated '(' ($28), exactly as on real hardware.
        t.put(0x68)
        #expect(t.line(0).hasPrefix("HELLO("))
        for _ in 0..<30 { t.put(0x0D) }
        #expect(t.cursorY == Terminal.rows - 1)
    }
}
