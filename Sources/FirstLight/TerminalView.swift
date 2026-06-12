import SwiftUI
import Apple1Core

/// The compiled CRT shader, if its metallib shipped (it's built by
/// `xcrun metal` — see Shaders/CRT.metal). Nil on a CLT-only machine,
/// where the Canvas fallback below takes over.
@MainActor let crtShaderLibrary: ShaderLibrary? = {
    guard let url = Bundle.module.url(forResource: "CRT",
                                      withExtension: "metallib",
                                      subdirectory: "Resources")
    else { return nil }
    return ShaderLibrary(url: url)
}()

/// The Apple-1's TV display: 40×24 characters rendered from the actual
/// Signetics 2513 character ROM — the same dots a 1976 TV drew. Blinking
/// @ cursor, phosphor green. Redraws only when the display changes.
struct TerminalView: View {
    let controller: MachineController

    var body: some View {
        let _ = controller.displayRevision // sole redraw trigger
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(Color(red: 0.02, green: 0.05, blue: 0.02)))

            let terminal = controller.machine.terminal
            let cell = CGSize(width: size.width / CGFloat(Terminal.columns),
                              height: size.height / CGFloat(Terminal.rows))
            let font = GlyphFont.shared
            // V-HOLD: off-center displaces the picture; far off, it rolls
            let hold = controller.vHold
            var shift = CGFloat(hold) * size.height * 0.4
            if abs(hold) > 0.55 {
                shift += CGFloat(controller.frame % 60) / 60 * size.height
                    * (hold > 0 ? 1 : -1)
            }

            context.withCGContext { cg in
                cg.interpolationQuality = .none
                for row in 0..<Terminal.rows {
                    for col in 0..<Terminal.columns {
                        var ascii = terminal.screen[row * Terminal.columns + col]
                        if row == terminal.cursorY && col == terminal.cursorX {
                            ascii = controller.cursorVisible ? 0x40 : 0x20 // @
                        }
                        guard ascii != 0x20, let glyph = font.image(for: ascii)
                        else { continue }
                        // 5 dots + 2 blank columns per character cell
                        let rawY = CGFloat(row) * cell.height + cell.height * 0.06 + shift
                        let wrappedY = rawY.truncatingRemainder(dividingBy: size.height)
                        let rect = CGRect(
                            x: CGFloat(col) * cell.width + cell.width / 7,
                            y: wrappedY < 0 ? wrappedY + size.height : wrappedY,
                            width: cell.width * 5 / 7,
                            height: cell.height * 0.88)
                        cg.saveGState()
                        // CGContext draws images bottom-up; flip per glyph
                        cg.translateBy(x: rect.minX, y: rect.maxY)
                        cg.scaleBy(x: 1, y: -1)
                        cg.draw(glyph, in: CGRect(origin: .zero, size: rect.size))
                        cg.restoreGState()
                    }
                }
            }
        }
        // T7: the real tube — Metal barrel curvature, raster-locked
        // scanlines, bloom and vignette in one pass. Canvas fallback
        // when the metallib isn't available.
        .modifier(CRTGlassModifier())
        .clipShape(RoundedRectangle(cornerRadius: 14)) // tube-glass corners
        .overlay {
            LinearGradient(colors: [.white.opacity(0.045), .clear, .clear],
                           startPoint: .topLeading, endPoint: .center)
                .allowsHitTesting(false)
        }
        // Phosphor warm-up: dim and slightly bloomy until the tube heats
        .opacity(0.25 + 0.75 * controller.crtWarmth)
        .brightness(controller.crtBrightness * 0.25
                    - (1 - controller.crtWarmth) * 0.18)
        .blur(radius: (1 - controller.crtWarmth) * 1.6)
        .contrast(1 + controller.crtContrast * 0.5)
        .aspectRatio(40.0 * 7.0 / (24.0 * 9.0), contentMode: .fit)
        .padding(8)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}


/// Applies the Metal CRT pass when available, else the Canvas look.
struct CRTGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        if let library = crtShaderLibrary {
            content.visualEffect { view, proxy in
                view.layerEffect(
                    library.crt(.float2(proxy.size),
                                .float(0.12),
                                .float(0.22)),
                    maxSampleOffset: CGSize(width: 60, height: 60))
            }
        } else {
            content
                .overlay {
                    Canvas { ctx, size in
                        var y: CGFloat = 0
                        while y < size.height {
                            ctx.fill(Path(CGRect(x: 0, y: y,
                                                 width: size.width, height: 1)),
                                     with: .color(.black.opacity(0.15)))
                            y += 3
                        }
                    }
                    .allowsHitTesting(false)
                }
                .overlay {
                    RadialGradient(colors: [.clear, .clear, .black.opacity(0.34)],
                                   center: .center, startRadius: 0, endRadius: 420)
                        .allowsHitTesting(false)
                }
        }
    }
}
