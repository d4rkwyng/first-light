import SwiftUI
import Apple1Core


/// Connectors drawn like the real hardware.
struct PortView: View {
    let port: Port
    let connected: Bool
    let targeted: Bool
    var pull: CGSize = .zero

    var body: some View {
        ZStack {
            switch port.id {
            case .display: molex(pins: 4)
            case .power: molex(pins: 6)
            case .keyboard: blueSocket
            case .aciCard: edgeSlot
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(style: StrokeStyle(lineWidth: targeted ? 3 : 1.2,
                                                 dash: connected ? [] : [4, 3]))
                .foregroundStyle(targeted ? Color.yellow
                                 : connected ? Color.clear : Color.white.opacity(0.55))
                .padding(-3)
        )
        .help(connected ? "Double-click to disconnect"
                        : "Drop the \(port.id.name) here")
    }

    private func molex(pins: Int) -> some View {
        let vertical = port.frame.height > port.frame.width
        let colors: [Color] = port.id == .power
            ? [.red, .black, .orange, .black, .blue, .black]
            : [.yellow, .black, Color(white: 0.55), .black]
        return ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [Color(red: 0.93, green: 0.92, blue: 0.87),
                                              Color(red: 0.78, green: 0.77, blue: 0.71)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: port.frame.width, height: port.frame.height)
                .shadow(color: .black.opacity(0.3), radius: 1.5, x: 1, y: 1)
                .overlay {
                    // pin slots live on the base; the seated plug hides
                    // them until it's pulled away
                    let slots = ForEach(0..<pins, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.black.opacity(0.55))
                            .frame(width: vertical ? 9 : 4, height: vertical ? 4 : 9)
                    }
                    if vertical { VStack(spacing: 5) { slots } }
                    else { HStack(spacing: 5) { slots } }
                }
            if connected {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(LinearGradient(colors: [Color(red: 0.97, green: 0.96, blue: 0.92),
                                                  Color(red: 0.84, green: 0.83, blue: 0.78)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: port.frame.width + 1,
                           height: port.frame.height + 1)
                    .shadow(color: .black.opacity(0.35), radius: 2, x: 1, y: 1)
                    .overlay {
                        // wires hang from an overlay so they can't
                        // inflate the connector's layout
                        if vertical {
                            VStack(spacing: 3.6) {
                                ForEach(0..<pins, id: \.self) { i in
                                    Rectangle()
                                        .fill(colors[i % colors.count].opacity(0.9))
                                        .frame(width: 30, height: 1.8)
                                }
                            }
                            .mask(LinearGradient(colors: [.black, .clear],
                                                 startPoint: .leading, endPoint: .trailing))
                            .offset(x: 27)
                            .allowsHitTesting(false)
                        } else {
                            HStack(spacing: 3.6) {
                                ForEach(0..<pins, id: \.self) { i in
                                    Rectangle()
                                        .fill(colors[i % colors.count].opacity(0.9))
                                        .frame(width: 1.8, height: 62)
                                }
                            }
                            .mask(LinearGradient(colors: [.clear, .black, .black, .black],
                                                 startPoint: .top, endPoint: .bottom))
                            .offset(y: -41)
                            .allowsHitTesting(false)
                        }
                    }
                    .offset(pull)
            } else {
                let pinViews = ForEach(0..<pins, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.black.opacity(0.55))
                        .frame(width: vertical ? 9 : 4, height: vertical ? 4 : 9)
                }
                if vertical { VStack(spacing: 5) { pinViews } }
                else { HStack(spacing: 5) { pinViews } }
            }
        }
    }

    private var blueSocket: some View {
        // A black 16-pin DIP socket, same scale as the chip sockets.
        // When the keyboard is attached, its plug seats here and the
        // rainbow ribbon curves down toward the front of the bench.
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(white: 0.10))
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(Color(white: 0.22), lineWidth: 1)
            HStack(spacing: 3.4) {
                ForEach(0..<2, id: \.self) { _ in
                    VStack(spacing: 2.8) {
                        ForEach(0..<8, id: \.self) { _ in
                            Circle().fill(Color.black.opacity(0.85))
                                .frame(width: 2.2, height: 2.2)
                                .overlay(Circle()
                                    .fill(PCB.gold.opacity(0.9))
                                    .frame(width: 1.1, height: 1.1))
                        }
                    }
                }
            }
            if connected {
                // Header plug; the ribbon hangs from an overlay so it
                // can't inflate the socket's layout
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(LinearGradient(colors: [Color(white: 0.20),
                                                  Color(white: 0.07)],
                                         startPoint: .leading,
                                         endPoint: .trailing))
                    .frame(width: 12, height: 41)
                    .overlay(
                        VStack(spacing: 3.6) {
                            ForEach(0..<8, id: \.self) { _ in
                                Circle().fill(Color(white: 0.45))
                                    .frame(width: 1.8, height: 1.8)
                            }
                        }
                    )
                    .overlay(alignment: .bottom) {
                        Canvas { ctx, size in
                            // 16-way ribbon: as wide as the plug is long,
                            // one bend, one gentle wave to the front edge
                            func cable(_ dx: CGFloat) -> Path {
                                var p = Path()
                                // full conductor pitch at the plug…
                                p.move(to: CGPoint(x: size.width - 2, y: 26 + dx))
                                // …rotating through the bend…
                                p.addCurve(to: CGPoint(x: 32 + dx, y: 56),
                                           control1: CGPoint(x: 50 + dx * 0.7, y: 26 + dx),
                                           control2: CGPoint(x: 32 + dx, y: 34 + dx * 0.5))
                                // …then side-by-side down the descent
                                p.addCurve(to: CGPoint(x: 27 + dx, y: size.height - 6),
                                           control1: CGPoint(x: 32 + dx, y: 110),
                                           control2: CGPoint(x: 22 + dx, y: 150))
                                return p
                            }
                            let rainbow: [Color] = [
                                Color(red: 0.55, green: 0.27, blue: 0.16), // brown
                                .red, .orange, .yellow, .green, .blue,
                                Color(red: 0.45, green: 0.25, blue: 0.65), // violet
                                Color(white: 0.55)]                        // gray
                            for k in 0..<8 {
                                ctx.stroke(cable(CGFloat(k) * 4.6 - 16.1),
                                           with: .color(rainbow[k].opacity(0.88)),
                                           lineWidth: 4.6)
                            }
                        }
                        .frame(width: 96, height: 300)
                        .mask(LinearGradient(stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.66),
                            .init(color: .black.opacity(0.55), location: 0.82),
                            .init(color: .black.opacity(0.2), location: 0.93),
                            .init(color: .clear, location: 1),
                        ], startPoint: .top, endPoint: .bottom))
                        .offset(x: -50, y: 254)
                        .allowsHitTesting(false)
                    }
                    .offset(pull)
            } else {
                HStack(spacing: 3.4) {
                    ForEach(0..<2, id: \.self) { _ in
                        VStack(spacing: 2.8) {
                            ForEach(0..<8, id: \.self) { _ in
                                Circle().fill(Color.black.opacity(0.85))
                                    .frame(width: 2.2, height: 2.2)
                                    .overlay(Circle()
                                        .fill(PCB.gold.opacity(0.9))
                                        .frame(width: 1.1, height: 1.1))
                            }
                        }
                    }
                }
            }
        }
    }

    private var edgeSlot: some View {
        // The 44-pin female edge connector: dark body, center groove,
        // and — when empty — 22 visible contact pairs, one each side
        // of the groove.
        ZStack {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(red: 0.07, green: 0.12, blue: 0.10))
            RoundedRectangle(cornerRadius: 2.5)
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
            // the groove
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.black.opacity(0.85))
                .frame(width: 5)
            if !connected {
                // 22 contact pairs flanking the groove
                VStack(spacing: 7.1) {
                    ForEach(0..<22, id: \.self) { _ in
                        HStack(spacing: 5) {
                            Rectangle()
                                .fill(PCB.gold.opacity(0.9))
                                .frame(width: 3.2, height: 2.6)
                            Rectangle()
                                .fill(PCB.gold.opacity(0.9))
                                .frame(width: 3.2, height: 2.6)
                        }
                    }
                }
                .padding(.vertical, 5)
            }
        }
    }
}

/// One rendered gerber layer (real copper or silkscreen), stretched
/// over the board.
/// The board's true outline (.gm1 gerber): a rounded rect with the
/// right-edge notch and the stepped bottom-right corner cut out —
/// real transparent cutouts, whatever the bench looks like.
