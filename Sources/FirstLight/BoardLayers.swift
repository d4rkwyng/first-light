import SwiftUI
import Apple1Core


/// One rendered gerber layer (real copper or silkscreen), stretched
/// over the board.
/// The board's true outline (.gm1 gerber): a rounded rect with the
/// right-edge notch and the stepped bottom-right corner cut out —
/// real transparent cutouts, whatever the bench looks like.
struct BoardOutline: Shape {
    func path(in rect: CGRect) -> Path {
        // TRUE outline coordinates from the .gm1 gerber — the physical
        // board spans (3.5, 3.2)-(995.5, 579.3) in design space, NOT
        // the full 1000x582 frame. The copper comb ends exactly at
        // 995.5; now so does the board.
        let left: CGFloat = 3.5, right: CGFloat = 995.5
        let top: CGFloat = 3.2, bottom: CGFloat = 579.3
        let r: CGFloat = 10
        var p = Path()
        p.move(to: CGPoint(x: left + r, y: top))
        p.addLine(to: CGPoint(x: right - r, y: top))
        p.addQuadCurve(to: CGPoint(x: right, y: top + r),
                       control: CGPoint(x: right, y: top))
        p.addLine(to: CGPoint(x: right, y: 259.2))
        p.addLine(to: CGPoint(x: 974.7, y: 259.2))
        p.addLine(to: CGPoint(x: 974.7, y: 310.4))
        p.addLine(to: CGPoint(x: right, y: 310.4))
        p.addLine(to: CGPoint(x: right, y: 539.3))
        p.addLine(to: CGPoint(x: 974.7, y: 539.3))
        p.addLine(to: CGPoint(x: 974.7, y: bottom))
        p.addLine(to: CGPoint(x: left + r, y: bottom))
        p.addQuadCurve(to: CGPoint(x: left, y: bottom - r),
                       control: CGPoint(x: left, y: bottom))
        p.addLine(to: CGPoint(x: left, y: top + r))
        p.addQuadCurve(to: CGPoint(x: left + r, y: top),
                       control: CGPoint(x: left, y: top))
        p.closeSubpath()
        return p
    }
}

/// The power-corner plate: notched along its left edge where the
/// three TO-220 regulators sit (per the Copson close-up).
struct PlateShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRoundedRect(in: rect, cornerSize: CGSize(width: 2, height: 2))
        // notches at the regulator rows (board y 52/90/124 → local)
        for centerY in [47.5, 85.5, 119.5] {
            p.addRect(CGRect(x: rect.minX - 1, y: rect.minY + centerY - 10,
                             width: 16, height: 20))
        }
        return p
    }
}

struct GerberLayer: View {
    let name: String
    var opacity: Double = 1.0

    var body: some View {
        if let url = Bundle.module.url(forResource: name, withExtension: "png",
                                       subdirectory: "Resources"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .opacity(opacity)
                .allowsHitTesting(false)
        }
    }
}

/// Passives at their true diagram positions: resistors, ceramic caps,
/// diodes, and small electrolytics — extracted and calibrated from the
/// placement diagram. Everything else comes from the fabrication files.
struct TracesView: View {
    var body: some View {
        Canvas { ctx, _ in
            let leadColor = Color(white: 0.70)

            /// The passive's rect spans its LEAD HOLES; the body sits
            /// centered with silver legs running to solder dots.
            func bodyAndLeads(_ r: CGRect, bodyFraction: CGFloat) -> CGRect {
                let horizontal = r.width >= r.height
                let length = horizontal ? r.width : r.height
                guard length > 18 else { return r }
                let bodyLen = length * bodyFraction
                let inset = (length - bodyLen) / 2
                var leads = Path()
                if horizontal {
                    leads.move(to: CGPoint(x: r.minX, y: r.midY))
                    leads.addLine(to: CGPoint(x: r.maxX, y: r.midY))
                } else {
                    leads.move(to: CGPoint(x: r.midX, y: r.minY))
                    leads.addLine(to: CGPoint(x: r.midX, y: r.maxY))
                }
                ctx.stroke(leads, with: .color(leadColor), lineWidth: 1.5)
                let ends = horizontal
                    ? [CGPoint(x: r.minX, y: r.midY), CGPoint(x: r.maxX, y: r.midY)]
                    : [CGPoint(x: r.midX, y: r.minY), CGPoint(x: r.midX, y: r.maxY)]
                for end in ends {
                    ctx.fill(Path(ellipseIn: CGRect(x: end.x - 1.9, y: end.y - 1.9,
                                                    width: 3.8, height: 3.8)),
                             with: .color(Color(white: 0.55)))
                }
                return horizontal
                    ? CGRect(x: r.minX + inset, y: r.minY,
                             width: bodyLen, height: r.height)
                    : CGRect(x: r.minX, y: r.minY + inset,
                             width: r.width, height: bodyLen)
            }

            for item in BoardPassives.items {
                let r = item.rect
                let horizontal = r.width >= r.height
                switch item.kind {
                case 1:
                    var body = bodyAndLeads(r, bodyFraction: 0.58)
                    // a resistor is ~2.5x longer than thick
                    if horizontal, body.height > body.width * 0.45 {
                        let t = body.width * 0.45
                        body = CGRect(x: body.minX, y: body.midY - t / 2,
                                      width: body.width, height: t)
                    } else if !horizontal, body.width > body.height * 0.45 {
                        let t = body.height * 0.45
                        body = CGRect(x: body.midX - t / 2, y: body.minY,
                                      width: t, height: body.height)
                    }
                    ctx.fill(Path(roundedRect: body,
                                  cornerRadius: min(body.width, body.height) / 2),
                             with: .color(Color(red: 0.76, green: 0.63, blue: 0.40)))
                    let is3K = r.minX > 680 && r.minX < 760
                        && r.minY > 345 && r.minY < 400
                    let bands: [Color] = [
                        is3K ? Color(red: 0.92, green: 0.45, blue: 0.06)
                             : Color(red: 0.42, green: 0.23, blue: 0.10),
                        .black,
                        Color(red: 0.75, green: 0.12, blue: 0.08),
                        Color(red: 0.80, green: 0.65, blue: 0.25),
                    ]
                    for (i, color) in bands.enumerated() {
                        let f = 0.18 + 0.18 * CGFloat(i)
                        let band = horizontal
                            ? CGRect(x: body.minX + body.width * f, y: body.minY,
                                     width: 1.9, height: body.height)
                            : CGRect(x: body.minX, y: body.minY + body.height * f,
                                     width: body.width, height: 1.9)
                        ctx.fill(Path(band), with: .color(color.opacity(0.9)))
                    }
                case 2:
                    let body = bodyAndLeads(r, bodyFraction: 0.5)
                    let d = max(min(body.width, body.height), 9)
                    let drop = horizontal
                        ? CGRect(x: body.midX - d * 0.7, y: body.midY - d * 0.42,
                                 width: d * 1.4, height: d * 0.84)
                        : CGRect(x: body.midX - d * 0.42, y: body.midY - d * 0.7,
                                 width: d * 0.84, height: d * 1.4)
                    ctx.fill(Path(ellipseIn: drop),
                             with: .color(Color(red: 0.86, green: 0.52, blue: 0.16)))
                    ctx.stroke(Path(ellipseIn: drop.insetBy(dx: 1, dy: 1)),
                               with: .color(Color(red: 0.62, green: 0.33, blue: 0.08)),
                               lineWidth: 0.8)
                case 3:
                    var body = bodyAndLeads(r, bodyFraction: 0.55)
                    if horizontal, body.height > body.width * 0.5 {
                        let t = body.width * 0.5
                        body = CGRect(x: body.minX, y: body.midY - t / 2,
                                      width: body.width, height: t)
                    } else if !horizontal, body.width > body.height * 0.5 {
                        let t = body.height * 0.5
                        body = CGRect(x: body.midX - t / 2, y: body.minY,
                                      width: t, height: body.height)
                    }
                    ctx.fill(Path(roundedRect: body,
                                  cornerRadius: min(body.width, body.height) / 2),
                             with: .color(Color(red: 0.30, green: 0.16, blue: 0.10)))
                    let band = horizontal
                        ? CGRect(x: body.minX + body.width * 0.72, y: body.minY,
                                 width: 2.4, height: body.height)
                        : CGRect(x: body.minX, y: body.minY + body.height * 0.72,
                                 width: body.width, height: 2.4)
                    ctx.fill(Path(band), with: .color(Color(white: 0.75)))
                case 4:
                    let body = bodyAndLeads(r, bodyFraction: 0.62)
                    ctx.fill(Path(roundedRect: body,
                                  cornerRadius: min(body.width, body.height) / 2),
                             with: .color(Color(red: 0.22, green: 0.38, blue: 0.70)))
                    ctx.fill(Path(roundedRect: CGRect(x: body.minX, y: body.minY,
                                                      width: body.width,
                                                      height: max(3, body.height * 0.2)),
                                  cornerRadius: 1.5),
                             with: .color(Color(white: 0.78).opacity(0.7)))
                default:
                    break
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// F3's power net as its own observer: the surge-then-breathe pulse
/// re-renders only THIS layer at 20 Hz, not the whole board.
struct PowerNetLayer: View {
    let controller: MachineController
    @State private var poweredAtFrame: Int?

    var body: some View {
        let opacity: Double = {
            guard controller.powered else { return 0 }
            let pulse = controller.lightingEffects
                ? 0.14 + 0.06 * sin(Double(controller.pulseFrame) / 42)
                : 0.0
            if let onFrame = poweredAtFrame {
                let since = Double(controller.pulseFrame - onFrame)
                if since < 90 {
                    return max(pulse, 0.85 * (1 - since / 90))
                }
            }
            return pulse
        }()
        GerberLayer(name: "board-power")
            .opacity(opacity)
            .onChange(of: controller.powered) { _, on in
                poweredAtFrame = on ? controller.pulseFrame : nil
            }
    }
}
