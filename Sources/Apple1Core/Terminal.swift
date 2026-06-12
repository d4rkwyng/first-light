/// The Apple-1 terminal section — the autonomous TV-typewriter half of the
/// board (2504 shift registers + 2513 character generator). The CPU never
/// addresses it directly; it only receives one 7-bit character at a time
/// through the PIA, at most one per video frame (~60 cps).
public struct Terminal {
    public static let columns = 40
    public static let rows = 24

    /// Screen contents as displayable ASCII (0x20...0x5F), row-major.
    public private(set) var screen: [UInt8]
    public private(set) var cursorX = 0
    public private(set) var cursorY = 0

    /// Everything ever shown, as a String — for tests and demo scripting.
    public private(set) var transcript = ""

    /// Bumped on every visible change — lets the UI skip redraws.
    public private(set) var revision = 0

    public init() {
        screen = [UInt8](repeating: 0x20, count: Self.columns * Self.rows)
    }

    /// Power loss: the 2504 shift registers lose their circulating loop.
    /// (The transcript survives — it's the all-time log, not the screen.)
    /// Snapshot restore: install a saved screen wholesale.
    public mutating func restore(screen newScreen: [UInt8],
                                 cursorX cx: Int, cursorY cy: Int,
                                 transcript log: String) {
        guard newScreen.count == screen.count else { return }
        screen = newScreen
        cursorX = cx
        cursorY = cy
        transcript = log
        revision += 1
    }

    public mutating func clear() {
        screen = [UInt8](repeating: 0x20, count: Self.columns * Self.rows)
        cursorX = 0
        cursorY = 0
        revision += 1
    }

    /// Accept one character from the PIA, as the display hardware would.
    public mutating func put(_ raw: UInt8) {
        revision += 1
        let c = raw & 0x7F
        if c == 0x0D {
            transcript.append("\n")
            newline()
            return
        }
        // The 2513 character generator only has 64 glyphs; the hardware
        // addresses it with the low 6 bits, so $60-$7F render as $20-$3F
        // and letters always come out uppercase.
        guard c >= 0x20 else { return }
        let glyph = c & 0x3F
        let shown: UInt8 = glyph < 0x20 ? glyph + 0x40 : glyph
        screen[cursorY * Self.columns + cursorX] = shown
        transcript.append(Character(UnicodeScalar(shown)))
        cursorX += 1
        if cursorX == Self.columns {
            transcript.append("\n")
            newline()
        }
    }

    private mutating func newline() {
        cursorX = 0
        cursorY += 1
        if cursorY == Self.rows {
            cursorY = Self.rows - 1
            // Scroll up one line.
            screen.removeFirst(Self.columns)
            screen.append(contentsOf: [UInt8](repeating: 0x20, count: Self.columns))
        }
    }

    public func line(_ row: Int) -> String {
        let slice = screen[row * Self.columns ..< (row + 1) * Self.columns]
        return String(bytes: slice, encoding: .ascii) ?? ""
    }
}
