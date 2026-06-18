import SwiftUI

/// Shared PCB palette — matched against the CHM photos of Woz's board.
enum PCB {
    static let substrate = Color(red: 0.180, green: 0.286, blue: 0.204) // #2E4934, picked from the Woz photo
    static let border = Color(red: 0.23, green: 0.34, blue: 0.25)
    static let trace = Color(red: 0.40, green: 0.60, blue: 0.40)
    static let pad = Color(white: 0.78)
    static let gold = Color(red: 0.78, green: 0.62, blue: 0.25)
    static let silk = Color.white.opacity(0.78)
}

/// One drawn component on the board.
struct Chip: Identifiable {
    enum Style {
        case dip          // black plastic DIP (vertical if taller than wide)
        case whiteCeramic // early MOS 6502: white ceramic, gold lid
        case lightDip     // pale ceramic package (the PROMs)
        case smallCan     // 2504/DS0025: little 8-pin packages
        case ceramicRam   // MK4096: ceramic body, metal seal strips
        case crystal      // silver metal-can crystal
        case cap          // blue electrolytic can (orientation from frame)
        case regulator    // small brown regulator brick
        case heatsink     // finned heatsink + mounting plate (bolted)
        case to3can       // the LM323K TO-3 can (bolts onto the heatsink)
    }

    let id: String
    let label: String          // identity, shown in hover info
    let frame: CGRect
    var region: MachineController.Region?
    let info: String
    var big = false
    var style = Style.dip
    var silk: String?          // white designator near the part (nil = none)
    var silkY: Double?         // per-row baseline override so silks align

    /// Which placeable chip set this component belongs to (nil = soldered).
    var group: ChipGroup? {
        switch true {
        case id == "6502": .cpu
        case id == "pia": .pia
        case id.hasPrefix("prom"): .proms
        case id.hasPrefix("ramW"): .ramW
        case id.hasPrefix("ramX"): .ramX
        case id.hasPrefix("ttl") || id.hasPrefix("2504") || id == "2519"
             || id == "2513" || id.hasPrefix("sr257") || id == "74154": .video
        default: nil
        }
    }
}

/// A connector that accepts a dragged peripheral.
struct Port: Identifiable {
    let id: Peripheral
    let label: String
    let frame: CGRect
}

/// The Apple-1 board, rebuilt from the XS-Labs component-placement
/// diagram of the original (18 columns × rows D/C/B/A) plus CHM photos:
/// PROMs at row A's left edge, 6820 at cols 3-5, 6502 at cols 6-8, RAM
/// banks at cols 11-18 of rows B and A, keyboard socket IN row B col 4,
/// 2513 in row D, power corner with regulator bricks + LM323K plate.
struct BoardView: View {
    let controller: MachineController

    static let designSize = CGSize(width: 1000, height: 582)

    /// Center x of diagram column n (1...18). `nonisolated`: pure functions
    /// over immutable constants, read by the nonisolated `chips`/`ports`
    /// static initializers below.
    nonisolated static func col(_ n: Double) -> Double { 51 * n - 18 }
    /// Row center y for D/C/B/A.
    nonisolated static let rowCenters: [(String, Double)] =
        [("D", 116), ("C", 236), ("B", 362), ("A", 495)]
    nonisolated static func rowY(_ row: String) -> Double {
        rowCenters.first { $0.0 == row }!.1
    }

    nonisolated static let vSize = CGSize(width: 26, height: 58)

    // MARK: Layout (from the placement diagram)

    static let chips: [Chip] = {
        var c: [Chip] = []
        let ttlInfo = "7400-series TTL logic — sync, timing and addressing "
            + "for Woz's TV terminal. He built a complete video terminal "
            + "from parts like these so you didn't have to buy a Teletype."
        let srInfo = "Signetics 2504 — a 1024-bit shift register in a tiny "
            + "package. Six of these ARE the video memory: 960 characters "
            + "forever circulating, redrawn every frame."

        let partInfo: [String: String] = [
            "7400": "Quad NAND gates — general-purpose logic glue.",
            "7402": "Quad NOR gates — logic glue for the terminal.",
            "7404": "Hex inverters.",
            "7408": "Quad AND gates.",
            "7410": "Triple 3-input NAND gates.",
            "7427": "Triple 3-input NOR gates.",
            "7432": "Quad OR gates.",
            "7450": "AND-OR-invert logic — combines video timing signals.",
            "74123": "Dual one-shots — timing pulses for the keyboard strobe.",
            "74154": "4-to-16 line decoder — picks which device answers each address.",
            "74157": "Quad 2-to-1 multiplexers — switch the display memory between CPU and video timing.",
            "74160": "Synchronous decade counter — part of the video timing chain.",
            "74161": "4-bit binary counter — divides the 14.318 MHz crystal down to character and line rates.",
            "74166": "Parallel-load shift register — turns each character's dot row into serial video.",
            "74174": "Hex D flip-flops — latch the character on its way to the screen.",
            "74175": "Quad D flip-flops — pipeline registers for the terminal.",
            "74S257": "Fast 2-to-1 multiplexers — fold the DRAM's row/column address onto its pins.",
            "8T97": "Hex bus drivers — buffer the 6502's address lines to the rest of the board.",
            "9316": "4-bit counters — more of the video timing chain.",
            "555": "The 555 timer — it blinks the @ cursor.",
        ]
        func v(_ id: String, _ name: String, _ colN: Double, _ row: String,
               region: MachineController.Region? = .video,
               info: String? = nil, style: Chip.Style = .dip) -> Chip {
            Chip(id: id, label: name,
                 frame: CGRect(x: col(colN) - vSize.width / 2,
                               y: rowY(row) - vSize.height / 2,
                               width: vSize.width, height: vSize.height),
                 region: region, info: info ?? partInfo[name] ?? ttlInfo,
                 style: style, silk: name)
        }
        func canPair(_ id: String, _ colN: Double, _ row: String) -> [Chip] {
            let y = rowY(row)
            return [
                Chip(id: "\(id)a", label: "2504",
                     frame: CGRect(x: col(colN) - 10, y: y - 26, width: 20, height: 20),
                     region: .video, info: srInfo, style: .smallCan),
                Chip(id: "\(id)b", label: "2504",
                     frame: CGRect(x: col(colN) - 10, y: y + 4, width: 20, height: 20),
                     region: .video, info: srInfo, style: .smallCan, silk: "2504"),
            ]
        }

        // ---- Row D: 2504 pair, the 2513, counters and gates ----
        c.append(v("ttlD1", "74166", 1, "D"))
        c.append(Chip(id: "2513", label: "2513",
                      frame: CGRect(x: 75, y: 112, width: 80, height: 32),
                      region: .video,
                      info: "Signetics 2513 character generator — 64 uppercase "
                      + "glyphs, 5×7 dots, straight out of 1970s video "
                      + "terminals. It is why the Apple-1 can't show "
                      + "lowercase — and this app draws with its actual dots.",
                      silk: "2513"))
        for (n, name) in [(6.0, "74160"), (7.0, "74161"), (8.0, "74161"),
                          (9.0, "74161"), (10.0, "7400"), (11.0, "74161"),
                          (12.0, "7404"), (15.0, "74123")] {
            c.append(v("ttlD\(Int(n))", name, n, "D"))
        }
        c += canPair("2504-2", 4, "D")
        c += canPair("2504-3", 5, "D")
        c += canPair("2504-4", 14, "D")
        c.append(Chip(id: "ttlD13", label: "555",
                      frame: CGRect(x: 637, y: 108, width: 35, height: 13),
                      region: .video, info: ttlInfo))
        // ---- Row C (labels verified against the silkscreen) ----
        c.append(Chip(id: "clock6800", label: "7404",
                      frame: CGRect(x: col(1) - 7, y: rowY("C") - 21,
                                    width: 14, height: 42),
                      region: nil,
                      info: "The 6800's clock driver — silk says (6800 "
                      + "ONLY). As supplied this socket is EMPTY: the "
                      + "6502 makes its own clock. Machine ▸ Processor "
                      + "shows the configuration that never shipped.",
                      style: .dip))
        for (n, name) in [(4.0, "74157"), (5.0, "7427"),
                          (6.0, "7410"), (7.0, "74174"), (8.0, "7450"),
                          (9.0, "7432"), (10.0, "7402"), (12.0, "7408"),
                          (13.0, "74175"), (14.0, "74157"), (15.0, "7400")] {
            c.append(v("ttlC\(Int(n))", name, n, "C"))
        }
        c.append(v("2519", "2519", 3, "C",
                   info: "Signetics 2519 — the 40-bit shift register that "
                   + "recirculates the cursor. The seventh register of "
                   + "Woz's terminal."))
        c += [Chip(id: "ttlC11a", label: "DS0025",
                   frame: CGRect(x: col(11) - 7, y: 222, width: 14, height: 16),
                   region: .video, info: ttlInfo, style: .smallCan),
              Chip(id: "ttlC11b", label: "2504",
                   frame: CGRect(x: col(11) - 7, y: 248, width: 14, height: 16),
                   region: .video,
                   info: "The seventh 2504 shift register — silk puts it "
                   + "under the DS0025 pair.", style: .smallCan)]
        // ---- Row B: gates, KEYBOARD col 4 (port), 74S257s, 74154, RAM W ----
        for (n, name) in [(1.0, "7400"), (2.0, "7410"), (3.0, "74123"),
                          (5.0, "74S257"), (6.0, "74S257"), (7.0, "74S257"),
                          (8.0, "74S257")] {
            c.append(v(name == "74S257" ? "sr257-\(Int(n))" : "ttlB\(Int(n))",
                       name, n, "B"))
        }
        c.append(Chip(id: "74154", label: "74154",
                      frame: CGRect(x: col(9.5) - 44, y: rowY("B") - 20,
                                    width: 88, height: 40),
                      region: .video, info: "74154 — the 4-to-16 address "
                      + "decoder, one of the widest chips on the board.",
                      silk: "74154", silkY: 409))
        let bankWInfo = "4 KB of MK4096 dynamic RAM — bank W, $0000-$0FFF. "
            + "Using brand-new 4K DRAMs instead of static RAM was a Woz "
            + "masterstroke: half the chips of the Altair's approach."
        let bankXInfo = "Bank X, $E000-$EFFF — the optional second 4 KB. "
            + "This is where Integer BASIC lives once you load it from "
            + "cassette. No bank X, no BASIC."
        for i in 0..<8 {
            var ram = v("ramX\(i)", "MK4096", Double(11 + i), "B",
                        region: .ramX, info: bankXInfo, style: .ceramicRam)
            ram.silk = "X\(7 - i)"
            c.append(ram)
        }
        // ---- Row A: PROMs at the LEFT EDGE, 6820, 6502, 8T97s, RAM X ----
        let promInfo = "Two 3601 PROMs holding the Woz Monitor — all 256 "
            + "bytes of it, at the board's left edge. Examine memory, "
            + "deposit bytes, run. The whole OS fits in a tweet."
        c.append(v("promA1", "3601", 1, "A", region: .rom,
                   info: promInfo, style: .lightDip))
        c.append(v("promA2", "3601", 2, "A", region: .rom,
                   info: promInfo, style: .lightDip))
        c.append(Chip(id: "pia", label: "6820 PIA",
                      frame: CGRect(x: col(4) - 72, y: rowY("A") - 22,
                                    width: 144, height: 44),
                      region: .pia,
                      info: "Motorola 6820 Peripheral Interface Adapter — the "
                      + "machine's only I/O: port A reads the keyboard, port "
                      + "B's handshake feeds the terminal one character per "
                      + "video frame (~60 per second).", big: true,
                      silk: "6820 (PIA)", silkY: 504))
        c.append(Chip(id: "6502", label: "MOS 6502",
                      frame: CGRect(x: col(7) - 72, y: rowY("A") - 22,
                                    width: 144, height: 44),
                      region: .cpu,
                      info: "The MOS Technology 6502, 1.023 MHz, in the early "
                      + "white-ceramic gold-lid package. $25 when an Intel "
                      + "8080 cost $179 — the price that made the Apple-1 "
                      + "possible. The same family later ran the Apple II, "
                      + "C64, and NES.", big: true, style: .whiteCeramic,
                      silk: "6502 (MICRO PROCESSOR)", silkY: 504))
        for n in [9.0, 10.0] {
            c.append(v("buf\(Int(n))", "8T97", n, "A", region: nil,
                       info: "8T97 hex buffers driving the address bus."))
        }
        for i in 0..<8 {
            var ram = v("ramW\(i)", "MK4096", Double(11 + i), "A",
                        region: .ramW, info: bankWInfo, style: .ceramicRam)
            ram.silk = "W\(7 - i)"
            c.append(ram)
        }
        // ---- Power section (top, from the diagram) ----
        c.append(Chip(id: "bigcap", label: "Sprague 5300 µF",
                      frame: CGRect(x: 630, y: 14, width: 168, height: 60),
                      region: nil,
                      info: "The biggest can on the board: 5,300 µF of raw "
                      + "smoothing for the +5 V rail.", style: .cap))
        c.append(Chip(id: "xtal", label: "14.318 MHz",
                      frame: CGRect(x: 700, y: 74, width: 32, height: 16),
                      region: nil,
                      info: "The master crystal. Every clock in the machine — "
                      + "video timing and the CPU's 1.023 MHz — divides down "
                      + "from this one can.", style: .crystal, silk: "XTAL"))
        let regInfo = "Linear regulators — the Apple-1's infamous achilles "
            + "heel. Original boards are often found with them replaced."
        for (i, name) in ["LM320 MP-5", "LM320 MP-12", "LM340 12"].enumerated() {
            c.append(Chip(id: "reg\(i)", label: name,
                          frame: CGRect(x: 822, y: [52.0, 90.0, 124.0][i], width: 20, height: 11),
                          region: nil, info: regInfo, style: .regulator))
        }
        c.append(Chip(id: "heatsink", label: "heatsink",
                      frame: CGRect(x: 893, y: 19, width: 96, height: 96),
                      region: nil,
                      info: "The finned heatsink and its mounting plate — "
                      + "bolted to the board, doing its best against the "
                      + "LM323K's heat.", style: .heatsink))
        c.append(Chip(id: "lm323k", label: "LM323K",
                      frame: CGRect(x: 905, y: 35, width: 72, height: 64),
                      region: nil,
                      info: "The LM323K 5-volt regulator in its steel-and-"
                      + "brass TO-3 can — the Apple-1's infamous hot spot. "
                      + "It bolts onto the heatsink below.", style: .to3can))
        let capInfo = "Sprague 2,400 µF electrolytics — the landmark blue "
            + "cans of every Apple-1 photo."
        c.append(Chip(id: "cap2", label: "Sprague 2400 µF",
                      frame: CGRect(x: 814, y: 205.6, width: 128, height: 56),
                      region: nil, info: capInfo, style: .cap))
        c.append(Chip(id: "cap3", label: "Sprague 2400 µF",
                      frame: CGRect(x: 811, y: 269.6, width: 128, height: 56),
                      region: nil, info: capInfo, style: .cap))

        // F1: snap each part to the nearest real footprint extracted
        // from the silkscreen gerber — exact position AND package size.
        var available = BoardFootprints.rects
        c = c.map { chip in
            if chip.style == .cap || chip.style == .regulator
                || chip.style == .heatsink {
                return chip
            }
            let cx = chip.frame.midX
            let cy = chip.frame.midY
            var best: (index: Int, distance: CGFloat)?
            for (i, r) in available.enumerated() {
                let d = hypot(r.midX - cx, r.midY - cy)
                if d < 36, best == nil || d < best!.distance {
                    best = (i, d)
                }
            }
            guard let hit = best else { return chip }
            let rect = available.remove(at: hit.index)
            return Chip(id: chip.id, label: chip.label, frame: rect,
                        region: chip.region, info: chip.info, big: chip.big,
                        style: chip.style, silk: chip.silk, silkY: chip.silkY)
        }
        #if DEBUG
        // F8 audit hook: dump final (post-snap) frames for Tools/audit.py
        let dump = c.map {
            "\($0.id),\($0.frame.origin.x),\($0.frame.origin.y)," +
            "\($0.frame.width),\($0.frame.height)"
        }.joined(separator: "\n")
        try? dump.write(toFile: "/tmp/firstlight_chips.csv",
                        atomically: true, encoding: .utf8)
        #endif
        return c
    }()

    static let ports: [Port] = [
        // 4-pin video, top-left corner — a white Molex block
        Port(id: .display, label: "VIDEO",
             frame: CGRect(x: 44, y: 28, width: 46, height: 18)),
        // 6-pin power on the RIGHT EDGE, below the heatsink
        Port(id: .power, label: "POWER",
             frame: CGRect(x: 974, y: 180, width: 22, height: 64)),
        // The keyboard socket sits IN row B, column 4
        Port(id: .keyboard, label: "KBD",
             frame: CGRect(x: 184, y: 341.5, width: 16.5, height: 46.5)),
        // 44-pin expansion edge, right edge at rows B/A
        Port(id: .aciCard, label: "EXPANSION",
             frame: CGRect(x: 946, y: 314, width: 20, height: 222)),
    ]

    @State private var targetedPort: Peripheral?
    @State private var aciSeated = false
    @State private var pulledPort: Peripheral?
    @State private var pullOffset: CGSize = .zero
    @State private var liftedChip: String?
    @State private var hoveredChip: String?
    @State private var hoveredPort: Peripheral?
    @State private var liftOffset: CGSize = .zero
    @State private var aciX: CGFloat = 720
    @State private var aciY: CGFloat = 426
    @State private var targetedZone: ChipGroup?

    /// Where each chip set seats on the board.
    static func passiveBlurb(_ kind: Int) -> String {
        switch kind {
        case 1: "Carbon resistor — sets currents and pull-ups. The "
            + "color bands spell its value (the 3K trio by the 6502 "
            + "read orange-black-red)."
        case 2: "Ceramic capacitor — the little amber drop. One sits "
            + "near every few chips, smoothing the 5V rail against "
            + "switching spikes. Cheap insurance, 1976 style."
        case 3: "Power diode — turns the transformer's AC into the DC "
            + "the regulators clean up. The silver band marks cathode."
        case 4: "Small electrolytic capacitor — bulk smoothing for a "
            + "local power rail."
        default: "Passive component."
        }
    }

    static func zone(for group: ChipGroup) -> CGRect {
        switch group {
        case .video: CGRect(x: 36, y: 146, width: 900, height: 262)
        case .proms: CGRect(x: col(1) - 22, y: 468, width: 96, height: 62)
        case .pia: CGRect(x: col(4) - 80, y: 470, width: 160, height: 60)
        case .cpu: CGRect(x: col(7) - 80, y: 470, width: 160, height: 60)
        case .ramX: CGRect(x: col(11) - 26, y: 330, width: 420, height: 66)
        case .ramW: CGRect(x: col(11) - 26, y: 462, width: 420, height: 68)
        }
    }

    var body: some View {
        ZStack {
            BoardOutline()
                .fill(PCB.substrate)
            BoardOutline()
                .stroke(PCB.border, lineWidth: 2)

            GerberLayer(name: "board-copper")
            PowerNetLayer(controller: controller)
            GerberLayer(name: "board-silk", opacity: 1.0)
            TracesView()

            // The power-corner aluminum plate (Copson board)
            ZStack {
                PlateShape()
                    .fill(LinearGradient(colors: [Color(white: 0.78),
                                                  Color(white: 0.62)],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing),
                          style: FillStyle(eoFill: true))
                PlateShape()
                    .stroke(Color(white: 0.45), lineWidth: 1)
                Circle().fill(Color(white: 0.30))
                    .frame(width: 6, height: 6)
                    .position(x: 861 - 815, y: 29 - 10)
            }
            .frame(width: 177, height: 128)
            .position(x: 815 + 88.5, y: 10 + 64)
            .allowsHitTesting(false)

            // The (6800 ONLY) option field: the dual-CPU provision.
            // Populated only via the what-if toggle.
            if controller.populate6800 {
                // Component outlines extracted from the silkscreen:
                // Q transistors (TO-92), R resistors, thin diodes, and
                // the two capacitor positions — the 6800's clock parts.
                Canvas { ctx, _ in
                    func leads(_ r: CGRect, vertical: Bool = false) {
                        var p = Path()
                        if vertical {
                            p.move(to: CGPoint(x: r.midX, y: r.minY - 3))
                            p.addLine(to: CGPoint(x: r.midX, y: r.maxY + 3))
                        } else {
                            p.move(to: CGPoint(x: r.minX - 3, y: r.midY))
                            p.addLine(to: CGPoint(x: r.maxX + 3, y: r.midY))
                        }
                        ctx.stroke(p, with: .color(Color(white: 0.7)),
                                   lineWidth: 1.3)
                    }
                    // resistors (silk: 22.4 x 11.5 outlines)
                    for (x, y) in [(104.3, 31.0), (206.7, 31.0),
                                   (129.9, 55.4), (181.1, 55.7),
                                   (232.3, 55.7)] {
                        let r = CGRect(x: x + 4, y: y + 2.7,
                                       width: 14.4, height: 6.1)
                        leads(CGRect(x: x, y: y, width: 22.4, height: 11.5))
                        ctx.fill(Path(roundedRect: r, cornerRadius: 3),
                                 with: .color(Color(red: 0.76, green: 0.63,
                                                    blue: 0.40)))
                    }
                    // thin diodes (18.9 x 5.5)
                    for (x, y) in [(131.7, 48.4), (182.9, 48.4),
                                   (234.1, 48.4)] {
                        let r = CGRect(x: x + 3.5, y: y + 0.7,
                                       width: 11.9, height: 4.1)
                        leads(CGRect(x: x, y: y, width: 18.9, height: 5.5))
                        ctx.fill(Path(roundedRect: r, cornerRadius: 2),
                                 with: .color(Color(red: 0.30, green: 0.16,
                                                    blue: 0.10)))
                        ctx.fill(Path(CGRect(x: r.maxX - 2.4, y: r.minY,
                                             width: 1.8, height: r.height)),
                                 with: .color(Color(white: 0.75)))
                    }
                    // Q transistors: TO-92 half-moons (12 x 10 circles)
                    for (x, y) in [(135.1, 33.3), (186.3, 33.3),
                                   (237.5, 33.3)] {
                        let r = CGRect(x: x, y: y, width: 12.1, height: 10.0)
                        var halfMoon = Path()
                        halfMoon.addArc(center: CGPoint(x: r.midX, y: r.midY),
                                        radius: r.width / 2,
                                        startAngle: .degrees(-50),
                                        endAngle: .degrees(230),
                                        clockwise: false)
                        halfMoon.closeSubpath()
                        ctx.fill(halfMoon, with: .color(Color(white: 0.10)))
                        ctx.stroke(halfMoon,
                                   with: .color(Color(white: 0.35)),
                                   lineWidth: 0.8)
                    }
                    // the two capacitors (symbol marks at the silk)
                    for (x, y) in [(149.0, 69.8), (183.6, 69.8)] {
                        let r = CGRect(x: x - 4, y: y - 2, width: 9, height: 9)
                        leads(CGRect(x: x - 5, y: y, width: 11, height: 5))
                        ctx.fill(Path(ellipseIn: r),
                                 with: .color(Color(red: 0.86, green: 0.52,
                                                    blue: 0.16)))
                    }
                }
                .allowsHitTesting(false)
            }
            Color.clear
                .frame(width: 262, height: 50)
                .contentShape(Rectangle())
                .onHover { inside in
                    // Schematic note 7, verified: "UNIT, AS SUPPLIED,
                    // INCLUDES A 6502... AND HAS OMITTED ALL COMPONENTS
                    // SHOWN WITHIN THE DOTTED BOX. IF A 6800 IS
                    // SUBSTITUTED... INSTALL ALL COMPONENTS SHOWN, AND
                    // BREAK BOTH SOLDER BRIDGES NOTED '6502'."
                    controller.hoverInfo = inside
                        ? "The dotted box: the board takes EITHER CPU. "
                        + "As supplied — 6502, this box EMPTY, and two "
                        + "solder bridges made at the points marked "
                        + "6502. For a Motorola 6800: install Q1-Q3, "
                        + "the 22-ohm and 1K resistors, four caps — and "
                        + "break both bridges. None ever shipped that "
                        + "way. "
                        + (controller.populate6800
                           ? "(Showing the 6800 what-if.)"
                           : "(Machine ▸ Processor swaps the what-if in.)")
                        : nil
                }
                .position(x: 116 + 131, y: 42 + 25)

            // The chip-select jumper wires above the 74154 (Copson
            // photo): purple Y→WX arc and two pale wires into the
            // numbered holes. Schematic note 8: these select which 4K
            // blocks the RAM banks answer — the memory map, as wires.
            Canvas { ctx, _ in
                func wire(_ pts: [(CGFloat, CGFloat)], _ color: Color,
                          width: CGFloat) {
                    var path = Path()
                    path.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
                    for i in 1..<pts.count where i + 1 < pts.count {
                        // smooth through control points
                        path.addQuadCurve(
                            to: CGPoint(x: (pts[i].0 + pts[i + 1].0) / 2,
                                        y: (pts[i].1 + pts[i + 1].1) / 2),
                            control: CGPoint(x: pts[i].0, y: pts[i].1))
                    }
                    path.addLine(to: CGPoint(x: pts.last!.0, y: pts.last!.1))
                    ctx.stroke(path, with: .color(color),
                               lineWidth: width)
                    for end in [pts.first!, pts.last!] {
                        ctx.fill(Path(ellipseIn: CGRect(x: end.0 - 1.8,
                                                        y: end.1 - 1.8,
                                                        width: 3.6, height: 3.6)),
                                 with: .color(Color(white: 0.6)))
                    }
                }
                // purple: long arc from the Y/Z posts over to W/X
                wire([(424, 312), (438, 290), (475, 282), (505, 296),
                      (511, 313)],
                     Color(red: 0.55, green: 0.44, blue: 0.76), width: 2.6)
                // white: R/S/T post curving down into the hole row
                wire([(497, 303), (478, 316), (458, 330), (443, 328)],
                     Color(white: 0.85), width: 2.4)
                // pale grey: short hop from Z down to its hole
                wire([(431, 313), (438, 322), (446, 329)],
                     Color(white: 0.72), width: 2.2)
            }
            .allowsHitTesting(false)
            Color.clear
                .frame(width: 110, height: 40)
                .contentShape(Rectangle())
                .onHover { inside in
                    controller.hoverInfo = inside
                        ? "Chip-select jumper wires (note 8): they wire "
                        + "each RAM bank to a 4K address block — bank W "
                        + "to $0000, bank X to $E000, where BASIC lives. "
                        + "The memory map isn't in silicon; it's these "
                        + "three wires. Rewire them and the machine "
                        + "rearranges. (Needed whichever processor is "
                        + "fitted — the CPU choice is the solder "
                        + "bridges, not these.)"
                        : nil
                }
                .position(x: 468, y: 308)

            // Every passive explains itself on hover
            ForEach(Array(BoardPassives.items.enumerated()),
                    id: \.offset) { _, item in
                Color.clear
                    .frame(width: max(item.rect.width, 10),
                           height: max(item.rect.height, 10))
                    .contentShape(Rectangle())
                    .onHover { inside in
                        controller.hoverInfo = inside
                            ? Self.passiveBlurb(item.kind) : nil
                    }
                    .position(x: item.rect.midX, y: item.rect.midY)
            }

            // Axial leads from the big Spragues to their drilled holes
            Canvas { ctx, _ in
                let lead = Color(white: 0.72)
                func stub(from: CGPoint, to: CGPoint) {
                    var p = Path()
                    p.move(to: from)
                    p.addLine(to: to)
                    ctx.stroke(p, with: .color(lead),
                               lineWidth: 2.2)
                    ctx.fill(Path(ellipseIn: CGRect(x: to.x - 2.4,
                                                    y: to.y - 2.4,
                                                    width: 4.8, height: 4.8)),
                             with: .color(Color(white: 0.55)))
                }
                stub(from: CGPoint(x: 642, y: 48), to: CGPoint(x: 627.5, y: 48))
                stub(from: CGPoint(x: 786, y: 48), to: CGPoint(x: 800.3, y: 48))
                stub(from: CGPoint(x: 814, y: 233.6), to: CGPoint(x: 806.7, y: 233.6))
                stub(from: CGPoint(x: 942, y: 233.6), to: CGPoint(x: 947.5, y: 233.6))
                stub(from: CGPoint(x: 811, y: 297.6), to: CGPoint(x: 803.5, y: 297.6))
                stub(from: CGPoint(x: 939, y: 297.6), to: CGPoint(x: 944.3, y: 297.6))
            }
            .allowsHitTesting(false)

            // Sockets: fixed to the board (they don't move when a chip
            // is lifted out — the Apple-1 was fully socketed)
            ForEach(Self.chips.filter {
                $0.id != "clock6800" || controller.populate6800
            }) { chip in
                if chip.style == .dip || chip.style == .lightDip
                    || chip.style == .ceramicRam || chip.style == .smallCan
                    || chip.style == .whiteCeramic {
                    let vertical = chip.frame.height > chip.frame.width
                    ZStack {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(white: 0.05).opacity(0.92))
                        // contact holes — one per pin, spread the
                        // full socket length (DIP pitch)
                        let length = vertical ? chip.frame.height : chip.frame.width
                        let pins = pinsPerSide(length)
                        let gap = (length - 8 - CGFloat(pins) * 2.6)
                            / CGFloat(max(1, pins - 1))
                        let holes = ForEach(0..<pins, id: \.self) { _ in
                            Circle().fill(Color.black.opacity(0.9))
                                .frame(width: 2.6, height: 2.6)
                                .overlay(Circle()
                                    .fill(PCB.gold.opacity(0.85))
                                    .frame(width: 1.3, height: 1.3))
                        }
                        if vertical {
                            HStack {
                                VStack(spacing: gap) { holes }
                                Spacer()
                                VStack(spacing: gap) { holes }
                            }
                            .padding(.horizontal, 2.5)
                            .padding(.vertical, 4)
                        } else {
                            VStack {
                                HStack(spacing: gap) { holes }
                                Spacer()
                                HStack(spacing: gap) { holes }
                            }
                            .padding(.vertical, 2.5)
                            .padding(.horizontal, 4)
                        }
                    }
                    .frame(width: chip.frame.width + 7.2,
                           height: chip.frame.height + 7.2)
                    .position(x: chip.frame.midX, y: chip.frame.midY)
                    .allowsHitTesting(false)
                }
            }

            // NOTE: interaction modifiers must come BEFORE .position —
            // applied after, the view is board-sized and the topmost one
            // swallows every drag/hover/click on the whole board.
            ForEach(Self.chips.filter {
                $0.id != "clock6800" || controller.populate6800
            }) { chip in
                let present = chip.group.map { controller.placed.contains($0) } ?? true
                ChipView(chip: chip,
                         controller: controller,
                         present: present)
                    .frame(width: chip.frame.width, height: chip.frame.height)
                    .scaleEffect(present ? 1 : 0.85) // seat with a bounce
                    .animation(.spring(response: 0.32, dampingFraction: 0.5),
                               value: present)
                    .onHover { inside in
                        // The CPU chip face flips to MC6800 in the what-if —
                        // its tooltip must follow, not keep describing the 6502.
                        let m6800CPU = chip.group == .cpu
                            && controller.cpuVariant == .m6800
                        let label = m6800CPU ? "MC6800" : chip.label
                        let info = m6800CPU
                            ? "The Motorola 6800 — the OTHER processor this board "
                              + "could take. Same job as the 6502 but a different "
                              + "instruction set, so it needs its own firmware: the "
                              + "Woz Monitor PROMs hold 6502 code, and no 6800 "
                              + "monitor was ever written for the Apple-1. It sits "
                              + "powered but silent."
                            : chip.info
                        controller.hoverInfo = inside
                            ? (present ? "\(label) — \(info)"
                               : "Empty \(label) socket — "
                                 + (chip.group?.blurb ?? ""))
                            : nil
                        if inside {
                            hoveredChip = chip.id
                        } else if hoveredChip == chip.id {
                            hoveredChip = nil
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 3.5)
                            .strokeBorder(Color.white.opacity(
                                (hoveredChip == chip.id
                                 || (chip.group != nil
                                     && chip.group == controller.highlightedGroup))
                                ? 0.9 : 0), lineWidth: 1.4)
                            .padding(-4.8) // ring the SOCKET, not just the chip
                    )
                    .shadow(color: .white.opacity(
                        (hoveredChip == chip.id
                         || (chip.group != nil
                             && chip.group == controller.highlightedGroup))
                        ? 0.5 : 0), radius: 6)
                    .brightness(
                        (hoveredChip == chip.id
                         || (chip.group != nil
                             && chip.group == controller.highlightedGroup))
                        ? 0.06 : 0)
                    .onTapGesture(count: 2) {
                        guard let group = chip.group else { return }
                        if present {
                            controller.unplace(group)
                        } else {
                            controller.place(group) // empty socket: reseat
                        }
                    }
                    .offset(liftedChip == chip.id ? liftOffset : .zero)
                    .scaleEffect(liftedChip == chip.id ? 1.12 : 1.0)
                    .shadow(color: .black.opacity(liftedChip == chip.id ? 0.5 : 0),
                            radius: 6, x: 3, y: 5)
                    .zIndex(liftedChip == chip.id ? 10 : 0)
                    .gesture(
                        DragGesture(minimumDistance: 4)
                            .onChanged { value in
                                // only seated, PULLABLE chips lift — soldered
                                // parts (group == nil) and the heatsink don't
                                guard present, chip.group != nil,
                                      chip.style != .heatsink else { return }
                                if liftedChip != chip.id {
                                    controller.sound.chipPick()
                                }
                                liftedChip = chip.id
                                liftOffset = value.translation
                            }
                            .onEnded { value in
                                let dist = hypot(value.translation.width,
                                                 value.translation.height)
                                if dist > 60, let group = chip.group {
                                    controller.unplace(group)
                                    liftedChip = nil
                                    liftOffset = .zero
                                } else {
                                    withAnimation(.spring(response: 0.4,
                                                          dampingFraction: 0.5)) {
                                        liftOffset = .zero
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                        if liftOffset == .zero { liftedChip = nil }
                                    }
                                }
                            }
                    )
                    .position(x: chip.frame.midX, y: chip.frame.midY)
            }

            // Drop zones for seating chip sets (only while missing)
            ForEach(ChipGroup.allCases) { group in
                if !controller.placed.contains(group) {
                    let rect = Self.zone(for: group)
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(style: StrokeStyle(lineWidth: targetedZone == group ? 3 : 1.5,
                                                         dash: [6, 4]))
                        .foregroundStyle(targetedZone == group ? Color.yellow
                                         : Color.white.opacity(0.35))
                        .frame(width: rect.width, height: rect.height)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            controller.place(group) // empty spot: reseat
                        }
                        .dropDestination(for: String.self) { items, _ in
                            guard items.first == group.payload else { return false }
                            controller.place(group)
                            return true
                        } isTargeted: { over in
                            targetedZone = over ? group : (targetedZone == group ? nil : targetedZone)
                        }
                        .position(x: rect.midX, y: rect.midY)
                }
            }

            ForEach(Self.ports) { port in
                PortView(port: port,
                         connected: controller.connected.contains(port.id),
                         targeted: targetedPort == port.id
                             || controller.highlightedPeripheral == port.id,
                         pull: pulledPort == port.id ? pullOffset : .zero)
                    .frame(width: port.frame.width, height: port.frame.height)
                    .contentShape(Rectangle())
                    .contextMenu {
                        if port.id == .aciCard {
                            Button("Inspect the Card Up Close…") {
                                controller.aciInspectRequested = true
                            }
                            if controller.connected.contains(.aciCard) {
                                Button("Pull the Card") {
                                    controller.disconnect(.aciCard)
                                }
                            }
                        }
                    }
                    .onHover { inside in
                        controller.hoverInfo = inside ? port.id.blurb : nil
                        if inside {
                            hoveredPort = port.id
                        } else if hoveredPort == port.id {
                            hoveredPort = nil
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.white.opacity(
                                hoveredPort == port.id ? 0.9 : 0), lineWidth: 1.4)
                            .padding(-4)
                    )
                    .shadow(color: .white.opacity(hoveredPort == port.id ? 0.45 : 0),
                            radius: 6)
                    .brightness(hoveredPort == port.id ? 0.06 : 0)
                    .dropDestination(for: String.self) { items, _ in
                        guard items.first == port.id.rawValue else { return false }
                        controller.connect(port.id)
                        return true
                    } isTargeted: { over in
                        targetedPort = over ? port.id : (targetedPort == port.id ? nil : targetedPort)
                    }
                    .onTapGesture(count: 2) {
                        controller.toggle(port.id)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { value in
                                guard controller.connected.contains(port.id) else { return }
                                if port.id == .aciCard {
                                    // Pulling the ACI: the full card
                                    // re-emerges and follows the drag
                                    aciSeated = false
                                    aciX = 903 + min(0, value.translation.width)
                                } else {
                                    // The plug visibly pulls away from
                                    // the connector before it lets go
                                    pulledPort = port.id
                                    let t = value.translation
                                    pullOffset = CGSize(
                                        width: max(-70, min(70, t.width)),
                                        height: max(-70, min(70, t.height)))
                                }
                            }
                            .onEnded { value in
                                if port.id == .aciCard,
                                   controller.connected.contains(.aciCard) {
                                    if value.translation.width < -70 {
                                        // slide out leftward, back to
                                        // the shelf
                                        withAnimation(.easeIn(duration: 0.35)) {
                                            aciX = 620
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                            controller.disconnect(.aciCard)
                                        }
                                    } else {
                                        withAnimation(.easeOut(duration: 0.35)) {
                                            aciX = 903
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                            withAnimation(.easeOut(duration: 0.25)) {
                                                aciSeated = true
                                            }
                                        }
                                    }
                                } else if controller.connected.contains(port.id) {
                                    if hypot(value.translation.width,
                                             value.translation.height) > 50 {
                                        controller.disconnect(port.id)
                                        pulledPort = nil
                                        pullOffset = .zero
                                    } else {
                                        withAnimation(.spring(response: 0.35,
                                                              dampingFraction: 0.6)) {
                                            pullOffset = .zero
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                            pulledPort = nil
                                        }
                                    }
                                }
                            }
                    )
                    .position(x: port.frame.midX, y: port.frame.midY)
            }

            if controller.showAudit {
                ForEach(Array(BoardFootprints.rects.enumerated()), id: \.offset) { _, r in
                    Rectangle()
                        .strokeBorder(Color.red.opacity(0.85), lineWidth: 1)
                        .frame(width: r.width, height: r.height)
                        .position(x: r.midX, y: r.midY)
                        .allowsHitTesting(false)
                }
                ForEach(Self.chips) { chip in
                    Rectangle()
                        .strokeBorder(Color.green.opacity(0.9), lineWidth: 1)
                        .frame(width: chip.frame.width, height: chip.frame.height)
                        .position(x: chip.frame.midX, y: chip.frame.midY)
                        .allowsHitTesting(false)
                }
            }

            // The ACI: slides in from the side, then settles into a
            // top-down view (you only see the card's edge from above).
            if controller.connected.contains(.aciCard) {
                if aciSeated {
                    ZStack {
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(LinearGradient(colors: [
                                Color(red: 0.42, green: 0.68, blue: 0.50),
                                Color(red: 0.14, green: 0.30, blue: 0.20)],
                                startPoint: .leading, endPoint: .trailing))
                        RoundedRectangle(cornerRadius: 2.5)
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.8)
                        Rectangle()
                            .fill(PCB.gold.opacity(0.8))
                            .frame(width: 2.2)
                            .offset(x: 4)
                    }
                    .frame(width: 12, height: 218)
                    .shadow(color: .black.opacity(0.6), radius: 5, x: -6, y: 4)
                    .position(x: 956, y: 425)
                    .allowsHitTesting(false)
                } else {
                    ZStack {
                        aciCardFace
                            .position(x: aciX, y: aciY)
                    }
                    .frame(width: Self.designSize.width,
                           height: Self.designSize.height)
                    .clipShape(Rectangle())
                    .allowsHitTesting(false)
                }
            }
        }
        .frame(width: Self.designSize.width, height: Self.designSize.height)
        .onAppear {
            // View state resets when the layout rebuilds — a card that
            // was already seated must come back seated, not floating
            // mid-glide at its initial position.
            if controller.connected.contains(.aciCard) {
                aciSeated = true
                aciX = 903
            }
        }
        .onChange(of: controller.connected.contains(.aciCard)) { _, inserted in
            if inserted {
                aciSeated = false
                aciX = 720 // glides left-to-right across the board
                withAnimation(.easeInOut(duration: 1.3)) { aciX = 903 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeOut(duration: 0.35)) { aciSeated = true }
                }
            } else {
                aciSeated = false
            }
        }
    }

    /// The ACI's face, rendered from its real gerber copper.
    private var aciCardFace: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(PCB.substrate)
                .overlay(RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(PCB.border, lineWidth: 1))
            // just the REAL copper — its pads, traces, and edge
            // fingers align by definition
            GerberLayer(name: "aci-copper")
                .padding(2)
        }
        .frame(width: 257, height: 134)
        .rotationEffect(.degrees(-90))
        .shadow(color: .black.opacity(0.4), radius: 3, x: 2, y: 2)
    }
}
