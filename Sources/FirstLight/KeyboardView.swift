import SwiftUI

/// The Datanetics-style ASCII keyboard: cream sculpted caps, black
/// legends (dual on the number row), on a dark plate. SHIFT works —
/// uppercase-only, like the hardware. RESET and CLR are real.
struct KeyboardView: View {
    let controller: MachineController
    @State private var shifted = false

    // (base legend, shift legend, base ascii, shifted ascii)
    private let numberRow: [(String, String, UInt8, UInt8)] = [
        ("1", "!", 0x31, 0x21), ("2", "\"", 0x32, 0x22), ("3", "#", 0x33, 0x23),
        ("4", "$", 0x34, 0x24), ("5", "%", 0x35, 0x25), ("6", "&", 0x36, 0x26),
        ("7", "'", 0x37, 0x27), ("8", "(", 0x38, 0x28), ("9", ")", 0x39, 0x29),
        ("0", "0", 0x30, 0x30), (":", "*", 0x3A, 0x2A), ("-", "=", 0x2D, 0x3D),
    ]
    private let rowQ: [(String, UInt8)] = [
        ("Q", 0x51), ("W", 0x57), ("E", 0x45), ("R", 0x52), ("T", 0x54),
        ("Y", 0x59), ("U", 0x55), ("I", 0x49), ("O", 0x4F), ("P", 0x50)]
    private let rowA: [(String, UInt8)] = [
        ("A", 0x41), ("S", 0x53), ("D", 0x44), ("F", 0x46), ("G", 0x47),
        ("H", 0x48), ("J", 0x4A), ("K", 0x4B), ("L", 0x4C)]
    private let rowZ: [(String, UInt8)] = [
        ("Z", 0x5A), ("X", 0x58), ("C", 0x43), ("V", 0x56), ("B", 0x42),
        ("N", 0x4E), ("M", 0x4D)]

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                ForEach(0..<numberRow.count, id: \.self) { i in
                    let key = numberRow[i]
                    dualCap(key.0, key.1, code: key.2, shiftCode: key.3) {
                        controller.typeKey(shifted ? key.3 : key.2)
                        shifted = false
                    }
                }
                cap("RESET", width: 56, legend: .red) { controller.reset() }
            }
            HStack(spacing: 5) {
                cap("ESC", width: 44, code: 0x1B) { controller.typeKey(0x1B) }
                ForEach(0..<rowQ.count, id: \.self) { i in
                    cap(rowQ[i].0, code: rowQ[i].1) { controller.typeKey(rowQ[i].1) }
                }
                dualCap("@", "`", code: 0x40) { controller.typeKey(0x40); shifted = false }
                cap("CLR", width: 44, legend: .red) { controller.clearScreen() }
            }
            HStack(spacing: 5) {
                cap("CTRL", width: 52, dim: true) {}
                ForEach(0..<rowA.count, id: \.self) { i in
                    cap(rowA[i].0, code: rowA[i].1) { controller.typeKey(rowA[i].1) }
                }
                dualCap(";", "+", code: 0x3B, shiftCode: 0x2B) {
                    controller.typeKey(shifted ? 0x2B : 0x3B); shifted = false
                }
                cap("RETURN", width: 68, code: 0x0D) { controller.typeKey(0x0D) }
            }
            HStack(spacing: 5) {
                cap("SHIFT", width: 66, pressed: shifted) { shifted.toggle() }
                ForEach(0..<rowZ.count, id: \.self) { i in
                    cap(rowZ[i].0, code: rowZ[i].1) { controller.typeKey(rowZ[i].1) }
                }
                dualCap(",", "<", code: 0x2C, shiftCode: 0x3C) {
                    controller.typeKey(shifted ? 0x3C : 0x2C); shifted = false
                }
                dualCap(".", ">", code: 0x2E, shiftCode: 0x3E) {
                    controller.typeKey(shifted ? 0x3E : 0x2E); shifted = false
                }
                dualCap("/", "?", code: 0x2F, shiftCode: 0x3F) {
                    controller.typeKey(shifted ? 0x3F : 0x2F); shifted = false
                }
                cap("SHIFT", width: 66, pressed: shifted) { shifted.toggle() }
            }
            HStack(spacing: 5) {
                cap("", width: 320, code: 0x20) { controller.typeKey(0x20) } // space
                cap("←", width: 44, code: 0x5F) { controller.typeKey(0x5F) } // rubout
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(KeyboardPCB())
        .opacity(controller.connected.contains(.keyboard) ? 1 : 0.8)
    }

    private enum LegendColor { case black, red }

    private func flashing(_ code: UInt8?) -> Bool {
        guard let code, let flash = controller.keyFlash else { return false }
        return flash.ascii == code && controller.pulseFrame - flash.frame < 9
    }

    private func cap(_ label: String, width: CGFloat = 32,
                     legend: LegendColor = .black, dim: Bool = false,
                     pressed: Bool = false, code: UInt8? = nil,
                     action: @escaping () -> Void) -> some View {
        let lit = pressed || flashing(code)
        return Button(action: action) {
            Text(label)
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(legend == .red
                    ? Color(red: 0.72, green: 0.18, blue: 0.12)
                    : Color.black.opacity(dim ? 0.4 : 0.8))
                .frame(width: width, height: 28)
                .background(capBody(pressed: lit))
                .offset(y: lit ? 1.2 : 0)
        }
        .buttonStyle(KeycapStyle())
    }

    private func dualCap(_ base: String, _ shift: String,
                         code: UInt8? = nil, shiftCode: UInt8? = nil,
                         action: @escaping () -> Void) -> some View {
        let lit = flashing(code) || flashing(shiftCode)
        return Button(action: action) {
            VStack(spacing: 0) {
                Text(shift).font(.system(size: 7, design: .monospaced))
                Text(base).font(.system(size: 9.5, weight: .medium,
                                        design: .monospaced))
            }
            .foregroundStyle(Color.black.opacity(0.8))
            .frame(width: 32, height: 28)
            .background(capBody(pressed: lit))
            .offset(y: lit ? 1.2 : 0)
        }
        .buttonStyle(KeycapStyle())
    }

    private func capBody(pressed: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4.5)
            .fill(LinearGradient(colors: pressed
                ? [Color(red: 0.78, green: 0.76, blue: 0.70),
                   Color(red: 0.84, green: 0.82, blue: 0.76)]
                : [Color(red: 0.93, green: 0.91, blue: 0.86),
                   Color(red: 0.82, green: 0.80, blue: 0.74)],
                startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: 4.5)
                .strokeBorder(Color.black.opacity(0.25), lineWidth: 0.8))
            .shadow(color: .black.opacity(0.45), radius: 1, y: 1.6)
    }
}

private struct KeycapStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 1.4 : 0)
            .brightness(configuration.isPressed ? -0.05 : 0)
    }
}


/// The bare keyboard PCB the caps mount to — no enclosure, like the
/// Datanetics assemblies shipped: phenolic board, traces, mounting
/// holes, and the solder side of the switch matrix peeking through.
private struct KeyboardPCB: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [
                    Color(red: 0.45, green: 0.33, blue: 0.16),
                    Color(red: 0.36, green: 0.26, blue: 0.12)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            // switch-matrix traces running between key rows
            Canvas { ctx, size in
                let trace = Color(red: 0.62, green: 0.50, blue: 0.28).opacity(0.55)
                for i in 0..<6 {
                    let y = size.height * (0.08 + 0.165 * CGFloat(i))
                    var p = Path()
                    p.move(to: CGPoint(x: 8, y: y))
                    p.addLine(to: CGPoint(x: size.width - 8, y: y))
                    ctx.stroke(p, with: .color(trace), lineWidth: 1)
                }
                for i in 0..<16 {
                    let x = size.width * (0.05 + 0.06 * CGFloat(i))
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: 6))
                    p.addLine(to: CGPoint(x: x, y: size.height - 6))
                    ctx.stroke(p, with: .color(trace.opacity(0.4)), lineWidth: 0.7)
                }
                // solder pads scattered along rows
                for i in 0..<40 {
                    let x = size.width * (0.04 + 0.024 * CGFloat(i))
                    for j in 0..<5 {
                        let y = size.height * (0.16 + 0.165 * CGFloat(j))
                        ctx.fill(Path(ellipseIn: CGRect(x: x - 1.2, y: y - 1.2,
                                                        width: 2.4, height: 2.4)),
                                 with: .color(Color(red: 0.78, green: 0.66,
                                                    blue: 0.38).opacity(0.5)))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Color(red: 0.28, green: 0.20, blue: 0.09),
                              lineWidth: 1.5)
        }
        .overlay {
            // corner mounting holes with gold annular rings
            ForEach(0..<4, id: \.self) { i in
                ZStack {
                    Circle().fill(Color(red: 0.78, green: 0.66, blue: 0.38))
                        .frame(width: 9, height: 9)
                    Circle().fill(Color(red: 0.10, green: 0.085, blue: 0.06))
                        .frame(width: 5.5, height: 5.5)
                }
                .position(x: i % 2 == 0 ? 10 : nil ?? 10, y: 10)
                .opacity(0)
            }
            GeometryReader { geo in
                ForEach(0..<4, id: \.self) { i in
                    ZStack {
                        Circle().fill(Color(red: 0.78, green: 0.66, blue: 0.38))
                            .frame(width: 9, height: 9)
                        Circle().fill(Color(red: 0.10, green: 0.085, blue: 0.06))
                            .frame(width: 5, height: 5)
                    }
                    .position(x: i % 2 == 0 ? 11 : geo.size.width - 11,
                              y: i < 2 ? 11 : geo.size.height - 11)
                }
                // ribbon header stub on the left edge, where the rainbow
                // cable runs to the board
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(white: 0.12))
                    .frame(width: 7, height: 44)
                    .position(x: 5, y: geo.size.height * 0.5)
            }
        }
    }
}
