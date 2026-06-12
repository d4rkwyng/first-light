import SwiftUI
import Apple1Core


struct ChipView: View {
    let chip: Chip
    let controller: MachineController
    var present = true

    private var glow: Double {
        guard controller.lightingEffects, let region = chip.region
        else { return 0 }
        return controller.glow[region] ?? 0
    }
    private var powered: Bool { controller.powered }

    var body: some View {
        let lit = powered ? glow : 0
        if !present {
            let vertical = chip.frame.height > chip.frame.width
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(white: 0.14))
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(Color(white: 0.32), lineWidth: 1)
                let length = vertical ? chip.frame.height : chip.frame.width
                let pins = pinsPerSide(length)
                let gap = (length - 10 - CGFloat(pins) * 3.0)
                    / CGFloat(max(1, pins - 1))
                let hole = { (i: Int) in
                    Circle().fill(Color.black.opacity(0.85))
                        .frame(width: 3.0, height: 3.0)
                        .overlay(Circle()
                            .fill(PCB.gold.opacity(0.9))
                            .frame(width: 1.4, height: 1.4))
                }
                if vertical {
                    HStack {
                        VStack(spacing: gap) { ForEach(0..<pins, id: \.self, content: hole) }
                        Spacer()
                        VStack(spacing: gap) { ForEach(0..<pins, id: \.self, content: hole) }
                    }
                    .padding(.horizontal, 3)
                } else {
                    VStack {
                        HStack(spacing: gap) { ForEach(0..<pins, id: \.self, content: hole) }
                        Spacer()
                        HStack(spacing: gap) { ForEach(0..<pins, id: \.self, content: hole) }
                    }
                    .padding(.vertical, 3)
                }
            }
        } else {
            switch chip.style {
            case .heatsink:
                // The Copson configuration: black radial-fin heatsink
                // mounted directly on the PCB — no plate. (Woz's own
                // unit used a flat plate INSTEAD of fins; boards had
                // one or the other, never both.)
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.10))
                        .frame(width: chip.frame.width * 0.62,
                               height: chip.frame.height * 0.62)
                    ForEach(0..<8, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color(white: i % 2 == 0 ? 0.16 : 0.09))
                            .frame(width: 15, height: 30)
                            .offset(y: -chip.frame.height * 0.36)
                            .rotationEffect(.degrees(Double(i) * 45))
                    }
                    ForEach(0..<8, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color(white: i % 2 == 0 ? 0.13 : 0.19))
                            .frame(width: 13, height: 24)
                            .offset(y: -chip.frame.height * 0.33)
                            .rotationEffect(.degrees(Double(i) * 45 + 22.5))
                    }
                }
                .shadow(color: .black.opacity(0.45), radius: 3, x: 2, y: 3)
            case .to3can:
                // The brass mounting flange (diagonal screws) on the
                // fins, with the steel LM323K can on top
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(LinearGradient(colors: [
                            Color(red: 0.80, green: 0.66, blue: 0.34),
                            Color(red: 0.62, green: 0.48, blue: 0.22)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 58, height: 58)
                    ForEach([CGFloat(-20), CGFloat(20)], id: \.self) { d in
                        ZStack {
                            Circle().fill(Color(white: 0.70))
                                .frame(width: 8, height: 8)
                            Rectangle().fill(Color(white: 0.35))
                                .frame(width: 7, height: 1.4)
                                .rotationEffect(.degrees(d < 0 ? 30 : 100))
                        }
                        .offset(x: d, y: d)
                    }
                    Circle()
                        .fill(LinearGradient(colors: [
                            Color(white: 0.88), Color(white: 0.58)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44)
                    Circle()
                        .strokeBorder(Color(white: 0.45), lineWidth: 1)
                        .frame(width: 44)
                    Text("LM323K")
                        .font(.system(size: 6, weight: .medium, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.4))
                        .rotationEffect(.degrees(-18))
                }
                .shadow(color: .black.opacity(0.35), radius: 2.5, x: 2, y: 2)
            case .regulator:
                // TO-220: black body, silver tab (silk labels it)
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(white: 0.10))
                    Rectangle()
                        .fill(Color(white: 0.62))
                        .frame(height: chip.frame.height * 0.32)
                }
                .shadow(color: .black.opacity(0.3), radius: 1.5, x: 1, y: 1)
            case .crystal:
                ZStack {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(white: 0.82), Color(white: 0.55),
                                     Color(white: 0.75)],
                            startPoint: .top, endPoint: .bottom))
                        .shadow(color: .black.opacity(0.35), radius: 1.5, x: 1, y: 1.5)
                    Text("14.318")
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.45))
                }
            case .ceramicRam:
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: [
                            Color(red: 0.30, green: 0.27, blue: 0.24),
                            Color(red: 0.20, green: 0.18, blue: 0.16)],
                            startPoint: .leading, endPoint: .trailing))
                        .overlay(RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 1.0, green: 0.55, blue: 0.1).opacity(lit * 0.55)))
                        .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.1).opacity(lit * 0.9),
                                radius: lit * 10)
                    VStack {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(LinearGradient(colors: [Color(white: 0.75), Color(white: 0.5)],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(height: 5)
                        Spacer()
                        RoundedRectangle(cornerRadius: 1)
                            .fill(LinearGradient(colors: [Color(white: 0.7), Color(white: 0.45)],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(height: 5)
                    }
                    .padding(2)
                }
                .overlay(PinTicks(dark: false, vertical: chip.frame.height > chip.frame.width))
            case .smallCan:
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(colors: [Color(white: 0.16), Color(white: 0.06)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 3)
                        .fill(Color(red: 1.0, green: 0.55, blue: 0.1)
                            .opacity((powered ? glow : 0) * 0.5)))
                    .overlay(Circle().fill(Color(white: 0.3)).frame(width: 3)
                        .offset(x: -5, y: -5))
            case .cap:
                let horizontal = chip.frame.width > chip.frame.height
                ZStack(alignment: horizontal ? .leading : .top) {
                    RoundedRectangle(cornerRadius: chip.frame.height * (horizontal ? 0.45 : 0.2))
                        .fill(LinearGradient(
                            colors: [Color(red: 0.13, green: 0.24, blue: 0.48),
                                     Color(red: 0.30, green: 0.48, blue: 0.75),
                                     Color(red: 0.13, green: 0.24, blue: 0.48)],
                            startPoint: horizontal ? .top : .leading,
                            endPoint: horizontal ? .bottom : .trailing))
                    Ellipse()
                        .fill(Color(red: 0.58, green: 0.66, blue: 0.78))
                        .frame(width: horizontal ? chip.frame.height * 0.45 : nil,
                               height: horizontal ? nil : chip.frame.width * 0.45)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("SPRAGUE")
                            .font(.system(size: 8, weight: .semibold))
                            .kerning(1.2)
                        Text("39D")
                            .font(.system(size: 6))
                        Text(chip.id == "bigcap" ? "5300UF-15VDC"
                                                 : "2400UF-25VDC")
                            .font(.system(size: 6))
                        Text("7613L")
                            .font(.system(size: 5.5))
                            .opacity(0.75)
                    }
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .shadow(color: .black.opacity(0.35), radius: 2, x: 1, y: 2)
            case .whiteCeramic:
                let m6800 = chip.group == .cpu
                    && controller.cpuVariant == .m6800
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(m6800 ? Color(white: 0.16)
                              : Color(red: 0.89, green: 0.87, blue: 0.81))
                        .overlay(RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 1.0, green: 0.55, blue: 0.1).opacity(lit * 0.55)))
                        .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.1).opacity(lit * 0.9),
                                radius: lit * 10)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(PCB.gold.opacity(0.9))
                        .frame(width: chip.frame.width * 0.30,
                               height: chip.frame.height * 0.62)
                    Text(m6800 ? "MC6800" : chip.label)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.25, green: 0.18, blue: 0.05))
                }
                .overlay(PinTicks(dark: true, vertical: false))
            case .lightDip:
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(red: 0.78, green: 0.77, blue: 0.72))
                        .overlay(RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 1.0, green: 0.55, blue: 0.1).opacity(lit * 0.45)))
                        .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.1).opacity(lit * 0.9),
                                radius: lit * 10)
                }
                .overlay(PinTicks(dark: true, vertical: chip.frame.height > chip.frame.width))
            case .dip:
                let vertical = chip.frame.height > chip.frame.width
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(
                            colors: [Color(white: 0.13), Color(white: 0.05)],
                            startPoint: vertical ? .leading : .top,
                            endPoint: vertical ? .trailing : .bottom))
                        .overlay(RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 1.0, green: 0.55, blue: 0.1).opacity(lit * 0.55)))
                        .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.1).opacity(lit * 0.9),
                                radius: lit * 10)
                    if chip.big {
                        Text(chip.label)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .overlay(PinTicks(dark: false, vertical: vertical))
            }
        }
    }
}

/// Pin-leg ticks along a DIP's long edges.
/// Pins per side from real DIP body lengths (design px @ 64/in):
/// DIP-8 <30, DIP-14/16 ~42-50 → 8, DIP-18 ~58 → 9, DIP-24 ~80 → 12,
/// DIP-40 ~131 → 20.

/// Pin-leg ticks along a DIP's long edges.
/// Pins per side from real DIP body lengths (design px @ 64/in):
/// DIP-8 <30, DIP-14/16 ~42-50 → 8, DIP-18 ~58 → 9, DIP-24 ~80 → 12,
/// DIP-40 ~131 → 20.
func pinsPerSide(_ length: CGFloat) -> Int {
    length > 100 ? 20 : length > 70 ? 12 : length > 52 ? 9
        : length > 30 ? 8 : 4
}

struct PinTicks: View {
    let dark: Bool
    var vertical = false

    var body: some View {
        Canvas { ctx, size in
            let color = dark ? Color.black.opacity(0.30) : Color.white.opacity(0.25)
            if vertical {
                let count = pinsPerSide(size.height)
                let step = size.height / CGFloat(count)
                for i in 0..<count {
                    let y = step * (CGFloat(i) + 0.5) - 0.8
                    ctx.fill(Path(CGRect(x: 0, y: y, width: 2.5, height: 1.6)),
                             with: .color(color))
                    ctx.fill(Path(CGRect(x: size.width - 2.5, y: y, width: 2.5, height: 1.6)),
                             with: .color(color))
                }
            } else {
                let count = pinsPerSide(size.width)
                let step = size.width / CGFloat(count)
                for i in 0..<count {
                    let x = step * (CGFloat(i) + 0.5) - 0.8
                    ctx.fill(Path(CGRect(x: x, y: 0, width: 1.6, height: 2.5)),
                             with: .color(color))
                    ctx.fill(Path(CGRect(x: x, y: size.height - 2.5, width: 1.6, height: 2.5)),
                             with: .color(color))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Connectors drawn like the real hardware.
