import Foundation

/// One step of the guided tour. `isComplete` sees only the terminal text
/// produced since the step began, so "wait for FF00:" can't be satisfied
/// by output from an earlier step.
struct TutorialStep {
    let title: String
    let body: String
    var action: (@MainActor (MachineController) -> Void)?
    /// Run `action` automatically when the step appears (for steps that
    /// need the machine in a known state before the user acts).
    var autoAction = false
    var isComplete: @MainActor (MachineController, String) -> Bool = { _, _ in true }
}

/// A themed track of tour steps.
struct TutorialTrack: Identifiable {
    let name: String
    let blurb: String
    let steps: [TutorialStep]
    var id: String { name }
}

/// Three tracks: operate it like 1976, look under the hood, then the
/// software story. Each is self-contained.
enum Tutorial {
    @MainActor static var tracks: [TutorialTrack] {
        [TutorialTrack(name: "Operate It",
                       blurb: "Build it up and boot it, the 1976 way.",
                       steps: steps),
         TutorialTrack(name: "Under the Hood",
                       blurb: "Pull chips and watch real failure modes.",
                       steps: hoodSteps),
         TutorialTrack(name: "The Software Story",
                       blurb: "Hex, BASIC, and the cassette library.",
                       steps: softwareSteps)]
    }

    @MainActor static let steps: [TutorialStep] = [
        TutorialStep(
            title: "It's 1976.",
            body: "You just paid $666.66 at the Byte Shop for an Apple-1 — "
                + "fully assembled and tested, because owner Paul Terrell "
                + "refused to sell kits. What you got is this bare board: "
                + "no case, no keyboard, no screen, no power supply. Two "
                + "guys named Steve built it in a Los Altos garage."),

        TutorialStep(
            title: "Meet the hardware",
            body: "Every chip is real and live — hover over any of them to "
                + "learn its job. Curious what's under a chip? Double-click "
                + "to pull it from its socket (drag it back from the shelf "
                + "later). Pull the 6502 while it's running and you'll see "
                + "exactly how much the machine misses it."),

        TutorialStep(
            title: "Power",
            body: "Drag the power supply to the POWER connector, top right. "
                + "Owners wired up their own transformers — there isn't even "
                + "an on/off switch. The moment power lands, the 6502 starts "
                + "executing. Watch the chips wake up.",
            action: { c in c.placeAll(); c.connect(.power) },
            isComplete: { c, _ in c.connected.contains(.power) }),

        TutorialStep(
            title: "Now... can you hear it?",
            body: "The machine is running — and you have no way to know. "
                + "Connect the monitor to the VIDEO connector. Any 1970s TV "
                + "would do; Woz built the video terminal right onto the "
                + "board, which is THE radical idea here.",
            action: { c in c.placeAll(); c.connect(.power); c.connect(.display) },
            isComplete: { c, _ in c.connected.contains(.display) }),

        TutorialStep(
            title: "That backslash is the whole operating system",
            body: "The \\ is the Woz Monitor saying hello — 256 bytes of "
                + "code, the smallest OS Apple ever shipped. To talk back, "
                + "drag the keyboard to its connector. Uppercase only — "
                + "and for typos, Delete sends _, the Apple-1's rubout: "
                + "the screen can't erase, but the machine forgets the "
                + "character.",
            action: { c in c.placeAll(); c.connect(.keyboard) },
            isComplete: { c, _ in c.connected.contains(.keyboard) }),

        TutorialStep(
            title: "Read the machine's mind",
            body: "Type FF00.FF1F and press Return. That asks the monitor "
                + "to show memory from address $FF00 to $FF1F — in hex. "
                + "You're reading the monitor's own code out of the PROMs. "
                + "Watch the PROM chips glow as it reads them.",
            action: { c in
                c.placeAll()
                c.connect(.power); c.connect(.display); c.connect(.keyboard)
                c.autoType("FF00.FF1F\n")
            },
            isComplete: { _, new in new.contains("FF00: D8") }),

        TutorialStep(
            title: "Your first program — no BASIC, no mercy",
            body: "Programs were typed in as raw hex. This one prints the "
                + "character set forever:\n0:A9 0 AA 20 EF FF E8 8A 4C 2 0\n"
                + "then 0R to run it. When you've seen enough 1976 screen "
                + "saver, ⌘R is the reset switch — the only way to stop it.",
            action: { c in
                c.placeAll()
                c.connect(.power); c.connect(.display); c.connect(.keyboard)
                c.autoType("0:A9 0 AA 20 EF FF E8 8A 4C 2 0\n0R\n")
            },
            // Generous: the first output line satisfies it, so resetting
            // early (as the step itself suggests!) can't strand you.
            isComplete: { _, new in
                new.contains("@ABC") || new.contains("STUV")
                    || new.contains("0000: A9")
            }),

        TutorialStep(
            title: "Loading BASIC (the $75 upgrade)",
            body: "Hit ⌘R to stop that loop. Now drag the cassette "
                + "interface into the EXPANSION slot — in 1976 you'd play a "
                + "cassette of Woz's hand-written BASIC into it for a "
                + "minute and a half. Press ⌘B to load it and jump to "
                + "$E000. Watch RAM bank X fill up.",
            action: { c in
                c.placeAll()
                c.connect(.power); c.connect(.display); c.connect(.keyboard)
                c.connect(.aciCard)
                c.loadBASIC() // resets first, works from any state
            },
            isComplete: { _, new in new.contains(">") }),

        TutorialStep(
            title: "Every kid's first program",
            body: "That > prompt is Integer BASIC. Type:\n"
                + "10 PRINT \"HELLO FROM 1976\"\n20 GOTO 10\nRUN\n"
                + "Fifty years of kids in computer stores started "
                + "exactly here. ⌘R when you're done grinning.",
            action: { c in
                // Self-sufficient: assemble and get to a fresh BASIC
                // prompt no matter what state the machine is in.
                c.placeAll()
                c.connect(.power); c.connect(.display); c.connect(.keyboard)
                c.connect(.aciCard)
                c.loadBASIC()
                c.autoType("10 PRINT \"HELLO FROM 1976\"\n20 GOTO 10\nRUN\n")
            },
            isComplete: { _, new in new.contains("1976\nHELLO FROM 1976") }),

        TutorialStep(
            title: "That's the machine that started Apple",
            body: "One chip doing video, one doing I/O, 8 KB of RAM, and an "
                + "OS smaller than this paragraph. Fifty years later the "
                + "company it launched made the computer you're holding. "
                + "The machine is yours now — hover over any chip to learn "
                + "what it does. Try FF00.FFFF, or write some BASIC."),
    ]

    @MainActor static let hoodSteps: [TutorialStep] = [
        TutorialStep(
            title: "Every chip is real",
            body: "The bench just powered itself up so we have a victim. "
                + "Hover over any chip: part number and its job. The board "
                + "under them is built from the original fabrication files — "
                + "copper, silkscreen, even the drill holes are 1976's. "
                + "Let's break it. Click Next.",
            action: { c in c.connectEverything() },
            autoAction: true),
        TutorialStep(
            title: "Pull the CPU",
            body: "Grab the white MOS 6502 (bottom center) and drag it off "
                + "the board. Watch the screen: it does NOT go blank. The "
                + "terminal was its own little machine — it just never "
                + "hears from the brain again.",
            action: { c in c.connectEverything() },
            autoAction: true,
            isComplete: { c, _ in c.powered && !c.placed.contains(.cpu) }),
        TutorialStep(
            title: "Pull the Woz Monitor",
            body: "Seat the CPU again (drag from the shelf), then pull the "
                + "two PROMs at the bottom left. The 6502's reset vector now "
                + "reads from empty sockets — it leaps into noise and "
                + "crashes. 1976 had no error dialogs.",
            isComplete: { c, _ in c.powered && !c.placed.contains(.proms)
                && c.placed.contains(.cpu) }),
        TutorialStep(
            title: "The power arteries",
            body: "Reseat the PROMs. Now yank the power plug (drag it off "
                + "its connector) and push it back in: the wide traces that "
                + "flash gold are the real +5 V distribution net from the "
                + "fab files, feeding every row.",
            isComplete: { c, _ in c.powered && c.essentialsPlaced }),
        TutorialStep(
            title: "It forgives you",
            body: "Everything you just did, real owners did — the Apple-1 "
                + "was fully socketed, which made it a tinkerer's machine. "
                + "Pull anything, watch how it fails, seat it back, ⌘R. "
                + "That's the whole repair manual."),
    ]

    @MainActor static let softwareSteps: [TutorialStep] = [
        TutorialStep(
            title: "Raw hex, no mercy",
            body: "Machine code, typed by hand. This prints the character "
                + "set forever:\n0:A9 0 AA 20 EF FF E8 8A 4C 2 0\nthen 0R. "
                + "⌘R is the only stop button.",
            action: { c in
                c.connectEverything()
                c.autoType("0:A9 0 AA 20 EF FF E8 8A 4C 2 0\n0R\n")
            },
            isComplete: { _, new in
                new.contains("@ABC") || new.contains("STUV")
                    || new.contains("0000: A9")
            }),
        TutorialStep(
            title: "BASIC, from cassette",
            body: "⌘R to stop. BASIC arrived on a $5 tape through the "
                + "cassette interface card. Press ⌘B (or pick Integer BASIC "
                + "from the Cassettes menu) and watch the deck load it.",
            action: { c in c.insert(TapeLibrary.tapes[0]) },
            isComplete: { _, new in new.contains(">") }),
        TutorialStep(
            title: "Every kid's first program",
            body: "At the > prompt:\n10 PRINT \"HELLO FROM 1976\"\n"
                + "20 GOTO 10\nRUN\nFifty years of kids started exactly "
                + "here.",
            isComplete: { _, new in new.contains("HELLO FROM 1976") }),
        TutorialStep(
            title: "The 1976 software library",
            body: "Eight cassettes existed. Open the Cassettes menu and pick "
                + "one — Hamurabi is a kingdom-management game from before "
                + "that genre had a name. The deck spins, the tape squeals, "
                + "the program runs.",
            isComplete: { c, _ in c.nowLoading != nil || c.loadProgress > 0 }),
        TutorialStep(
            title: "Save your work — to tape",
            body: "1976 storage: press the deck's REC key (or Cassettes ▸ "
                + "Record to Cassette…), pick \"RAM bank X\" and record. "
                + "You get a text file that reloads via Load Custom "
                + "Cassette — and a .wav of the actual ACI tones a real "
                + "Apple-1 could load. RAM forgets; tape remembers.",
            action: { c in c.recordRequested = true }),
        TutorialStep(
            title: "Yours to fill",
            body: "Cassettes ▸ Load Custom Cassette… accepts anything the "
                + "Apple-1 community publishes — wozmon dumps, BASIC "
                + "listings, raw binaries. People still write software for "
                + "this machine. Now you can run all of it."),
    ]
}
