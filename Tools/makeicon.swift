// Renders the First Light app icon (V2, picked 2026-11-22): PCB-green
// continuous-corner squircle with faint traces and gold edge fingers, a dark
// CRT inset, and "\@" (the Woz Monitor prompt + the Apple-1's "@" cursor)
// drawn from the real Signetics 2513 5×7 bitmaps in charrom2513.bin as
// integer-pixel squares, antialiasing off, in six hard 1977 stripes with no
// bloom or glow. Everything outside the squircle is transparent. The palette
// evokes the era without using Apple's marks.
//
// Every size is rendered natively at its own pixel size (never downscaled:
// nearest-neighbour downscales drop or duplicate dot rows and alias the
// stripes). Run from the repo root:
//
//   swift Tools/makeicon.swift [path/to/charrom2513.bin]
//
// Writes dist/AppIcon.iconset (build-app.sh stamps its 1024 on dev builds),
// docs/icon.png (512), and Sources/FirstLight/Resources/AppIcon.icns via
// iconutil. The renderer below is the round-13 makeicon13.swift renderer,
// unchanged apart from this header, the default ROM path and the variant list.
import AppKit
import ImageIO
import UniformTypeIdentifiers

let romPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1]
    : "Sources/Apple1Core/Resources/ROMs/charrom2513.bin"
let rom = [UInt8](try! Data(contentsOf: URL(fileURLWithPath: romPath)))
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

// 1977 palette, top→bottom — identical values to RainbowPrompt.
let stripes: [(CGFloat, CGFloat, CGFloat)] = [
    (0.38, 0.73, 0.27), // green
    (0.99, 0.78, 0.05), // yellow
    (0.96, 0.51, 0.12), // orange
    (0.89, 0.16, 0.12), // red
    (0.58, 0.22, 0.56), // purple
    (0.00, 0.56, 0.84), // blue
]
func rgb(_ c: (CGFloat, CGFloat, CGFloat), _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: srgb, components: [c.0, c.1, c.2, a])!
}

// --- 2513 glyphs ---------------------------------------------------------
// ROM is 8 bytes per char, bit 4 = leftmost of 5 columns. "\@" sits in two
// 6-dot character cells (5 dots + 1 gap), so the mark is 11×7 dots using
// ROM rows 1…7 (row 0 is blank for every printable glyph).
func glyph(_ ascii: UInt8) -> [[Bool]] {
    (1...7).map { row in
        let bits = rom[Int(ascii) * 8 + row]
        return (0..<5).map { bits & (1 << (4 - $0)) != 0 }
    }
}
let mark: [[Bool]] = zip(glyph(0x5C), glyph(0x40)).map { $0 + [false] + $1 }
let markCols = 11, markRows = 7

// --- continuous-corner rounded rect (Apple "squircle") -------------------
// The published reverse-engineering of UIBezierPath's continuous corners:
// each corner starts 1.52866·r from the vertex and is three cubics.
func continuousRect(_ rc: CGRect, _ r0: CGFloat) -> CGPath {
    let r = min(r0, min(rc.width, rc.height) / 2 / 1.52866483)
    let p = CGMutablePath()
    let (x0, y0, x1, y1) = (rc.minX, rc.minY, rc.maxX, rc.maxY)
    // corner helper: v = vertex, u = unit toward the start edge, w = unit toward the end edge
    func corner(_ vx: CGFloat, _ vy: CGFloat, _ ux: CGFloat, _ uy: CGFloat, _ wx: CGFloat, _ wy: CGFloat) {
        func pt(_ a: CGFloat, _ b: CGFloat) -> CGPoint { // a along u, b along w (from vertex)
            CGPoint(x: vx + ux * a * r + wx * b * r, y: vy + uy * a * r + wy * b * r)
        }
        p.addLine(to: pt(1.52866483, 0))
        p.addCurve(to: pt(0.63149399, 0.07491100), control1: pt(1.08849323, 0), control2: pt(0.86840689, 0))
        p.addCurve(to: pt(0.07491100, 0.63149399), control1: pt(0.37282392, 0.16905899), control2: pt(0.16905899, 0.37282392))
        p.addCurve(to: pt(0, 1.52866483), control1: pt(0, 0.86840689), control2: pt(0, 1.08849323))
    }
    p.move(to: CGPoint(x: x0 + 1.52866483 * r, y: y0))
    corner(x1, y0, -1, 0, 0, 1)   // bottom-right (y-up)
    corner(x1, y1, 0, -1, -1, 0)  // top-right
    corner(x0, y1, 1, 0, 0, -1)   // top-left
    corner(x0, y0, 0, 1, 1, 0)    // bottom-left
    p.closeSubpath()
    return p
}

// --- renderer --------------------------------------------------------------
struct Variant { let name: String; let title: String; let dot: CGFloat; let glow: Bool }
// Round 13 tried V1 (dot 36), V2 (dot 42) and V3 (dot 42 + faint halo);
// V2 is the shipped icon. Dot size is in pixels at 1024.
let v2 = Variant(name: "v2-larger-glyph", title: "V2", dot: 42, glow: false)

func ctx(_ w: Int, _ h: Int) -> CGContext {
    let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                      space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.clear(CGRect(x: 0, y: 0, width: w, height: h))
    return c
}

func render(_ v: Variant, _ px: Int) -> CGImage {
    let size = CGFloat(px)
    let c = ctx(px, px)
    // macOS icon grid: 824/1024 body, continuous corner radius 0.225 × body.
    let inset = (size * 100 / 1024).rounded()
    let rect = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let body = continuousRect(rect, rect.width * 0.225)
    c.addPath(body); c.clip()

    // PCB substrate (same gradient as the original: lighter top → darker bottom)
    let grad = CGGradient(colorsSpace: srgb, colors: [rgb((0.21, 0.33, 0.24)), rgb((0.13, 0.23, 0.16))] as CFArray,
                          locations: [0, 1])!
    c.drawLinearGradient(grad, start: CGPoint(x: 0, y: rect.maxY), end: CGPoint(x: 0, y: rect.minY), options: [])

    // faint traces — same geometry, line width and y snapped to whole pixels
    let lw = max(1, (size * 0.008).rounded())
    c.setStrokeColor(rgb((0.34, 0.44, 0.36), 0.8))
    c.setLineWidth(lw)
    c.setLineJoin(.miter)
    let half: CGFloat = Int(lw) % 2 == 1 ? 0.5 : 0
    for i in 0..<7 {
        let y = (rect.minY + rect.height * (0.12 + 0.13 * CGFloat(i))).rounded() + half
        let dy = (rect.height * 0.05).rounded()
        let xk = (rect.minX + rect.width * 0.22).rounded()
        c.move(to: CGPoint(x: rect.minX, y: y))
        c.addLine(to: CGPoint(x: xk, y: y))
        c.addLine(to: CGPoint(x: xk + dy * 1.6, y: y + dy))
        c.addLine(to: CGPoint(x: rect.maxX, y: y + dy))
        c.strokePath()
    }
    // gold edge fingers along the bottom, pixel-snapped
    c.setFillColor(rgb((0.80, 0.65, 0.30)))
    let fw = rect.width / 24
    for i in 0..<12 {
        let x = (rect.minX + rect.width * 0.04 + CGFloat(i) * fw * 1.9).rounded()
        c.fill(CGRect(x: x, y: rect.minY, width: fw.rounded(), height: (rect.height * 0.07).rounded()))
    }

    // dark CRT bezel + glass (continuous corners)
    let glass = rect.insetBy(dx: (rect.width * 0.14).rounded(), dy: (rect.height * 0.17).rounded())
    c.setFillColor(rgb((0.04, 0.04, 0.04)))
    c.addPath(continuousRect(glass.insetBy(dx: -(size * 0.018).rounded(), dy: -(size * 0.018).rounded()), size * 0.08 * 0.8))
    c.fillPath()
    let glassPath = continuousRect(glass, size * 0.07 * 0.8)
    c.setFillColor(rgb((0.02, 0.05, 0.03)))
    c.addPath(glassPath); c.fillPath()

    // scanlines + glare stay on the glass but go *under* the glyph so they
    // can't break up or tint the dots (skipped below 64 px, as before).
    if px >= 64 {
        c.saveGState()
        c.addPath(glassPath); c.clip()
        c.setFillColor(CGColor(gray: 0, alpha: 0.22))
        let period = max(2, (size * 0.016).rounded()), h = max(1, (size * 0.005).rounded())
        var y = glass.minY
        while y < glass.maxY { c.fill(CGRect(x: glass.minX, y: y, width: glass.width, height: h)); y += period }
        let hl = CGGradient(colorsSpace: srgb, colors: [CGColor(gray: 1, alpha: 0.10), CGColor(gray: 1, alpha: 0)] as CFArray,
                            locations: [0, 1])!
        c.drawLinearGradient(hl, start: CGPoint(x: glass.minX, y: glass.maxY),
                             end: CGPoint(x: glass.minX + glass.height * 0.18, y: glass.midY), options: [])
        c.restoreGState()
    }

    // "\@" — integer dot size, integer origin, centred on the glass.
    let dot = max(1, (v.dot * size / 1024).rounded())
    let gw = dot * CGFloat(markCols), gh = dot * CGFloat(markRows)
    let gx = (glass.midX - gw / 2).rounded(), gy = (glass.midY - gh / 2).rounded()
    // Six hard bands over the 7 dot rows. Equal sixths would leave thin
    // slivers on the dots, so bands snap to half-dot rows (14 halves split
    // 3·2·2·2·2·3): green/blue get 1½ rows, each inner row is cut exactly in
    // half, and the shorter "\" (ROM rows 2–6) still shows all six colours.
    let halves = [0, 3, 5, 7, 9, 11, 14]
    let edges = halves.map { (gy + gh - CGFloat($0) * dot / 2).rounded() } // top→bottom, y-up
    func drawDots(_ fill: (Int) -> Void) {
        for b in 0..<6 {
            c.saveGState()
            c.clip(to: CGRect(x: gx, y: edges[b + 1], width: gw, height: edges[b] - edges[b + 1]))
            fill(b)
            for (r, row) in mark.enumerated() {
                for (col, on) in row.enumerated() where on {
                    c.addRect(CGRect(x: gx + CGFloat(col) * dot, y: gy + gh - CGFloat(r + 1) * dot, width: dot, height: dot))
                }
            }
            c.fillPath()
            c.restoreGState()
        }
    }
    if v.glow && px >= 64 {
        // faint phosphor halo in each band's own colour, drawn first; the hard
        // dots are then redrawn on top, so no glyph pixel is ever blurred.
        c.saveGState()
        c.addPath(glassPath); c.clip()
        let blur = size * 0.022
        for b in 0..<6 {
            c.saveGState()
            c.setShadow(offset: .zero, blur: blur, color: rgb(stripes[b], 0.55))
            c.setFillColor(rgb(stripes[b]))
            c.beginTransparencyLayer(auxiliaryInfo: nil)
            c.clip(to: CGRect(x: gx - dot, y: edges[b + 1] - (b == 5 ? dot : 0), width: gw + 2 * dot,
                              height: edges[b] - edges[b + 1] + (b == 0 || b == 5 ? dot : 0)))
            for (r, row) in mark.enumerated() {
                for (col, on) in row.enumerated() where on {
                    c.addRect(CGRect(x: gx + CGFloat(col) * dot, y: gy + gh - CGFloat(r + 1) * dot, width: dot, height: dot))
                }
            }
            c.fillPath()
            c.endTransparencyLayer()
            c.restoreGState()
        }
        c.restoreGState()
    }
    c.setShouldAntialias(false)
    drawDots { c.setFillColor(rgb(stripes[$0])) }
    c.setShouldAntialias(true)
    return c.makeImage()!
}

// --- helpers ---------------------------------------------------------------
func writePNG(_ img: CGImage, _ path: String) {
    let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, img, nil)
    precondition(CGImageDestinationFinalize(d), "write failed \(path)")
}

// --- outputs ---------------------------------------------------------------
let out = "dist/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
for pt in [16, 32, 128, 256, 512] {
    writePNG(render(v2, pt), "\(out)/icon_\(pt)x\(pt).png")
    writePNG(render(v2, pt * 2), "\(out)/icon_\(pt)x\(pt)@2x.png")
}
writePNG(render(v2, 512), "docs/icon.png")
print("wrote \(out) and docs/icon.png")

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", out, "-o", "Sources/FirstLight/Resources/AppIcon.icns"]
try! iconutil.run()
iconutil.waitUntilExit()
precondition(iconutil.terminationStatus == 0, "iconutil failed")
print("wrote Sources/FirstLight/Resources/AppIcon.icns")
