// Renders the app icon: PCB-green squircle with faint traces and gold edge
// fingers, a dark CRT inset, and the Woz Monitor's boot prompt (backslash +
// block cursor) filled with the 1977 six-stripe palette. The prompt glyph is
// original artwork — the palette evokes the era without using Apple's marks.
// Emits an .iconset + the PNGs build-app.sh stamps on the bundle.
import AppKit

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let out = "dist/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

// The 1977 palette, top→bottom: green, yellow, orange, red, purple, blue
let stripes: [NSColor] = [
    NSColor(red: 0.38, green: 0.73, blue: 0.27, alpha: 1),
    NSColor(red: 0.99, green: 0.78, blue: 0.05, alpha: 1),
    NSColor(red: 0.96, green: 0.51, blue: 0.12, alpha: 1),
    NSColor(red: 0.89, green: 0.16, blue: 0.12, alpha: 1),
    NSColor(red: 0.58, green: 0.22, blue: 0.56, alpha: 1),
    NSColor(red: 0.00, green: 0.56, blue: 0.84, alpha: 1),
]

func draw(_ px: Int) -> NSImage {
    let size = CGFloat(px)
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext

    // macOS icon grid: content inset ~10%
    let inset = size * 0.09
    let rect = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    NSBezierPath(roundedRect: rect, xRadius: size * 0.2, yRadius: size * 0.2).addClip()

    // PCB substrate
    let grad = NSGradient(colors: [NSColor(red: 0.21, green: 0.33, blue: 0.24, alpha: 1),
                                   NSColor(red: 0.13, green: 0.23, blue: 0.16, alpha: 1)])!
    grad.draw(in: rect, angle: -90)

    // faint traces
    ctx.setStrokeColor(NSColor(red: 0.34, green: 0.44, blue: 0.36, alpha: 0.8).cgColor)
    ctx.setLineWidth(max(1, size * 0.008))
    for i in 0..<7 {
        let y = rect.minY + rect.height * (0.12 + 0.13 * CGFloat(i))
        ctx.move(to: CGPoint(x: rect.minX, y: y))
        ctx.addLine(to: CGPoint(x: rect.minX + rect.width * 0.22, y: y))
        ctx.addLine(to: CGPoint(x: rect.minX + rect.width * 0.30, y: y + rect.height * 0.05))
        ctx.addLine(to: CGPoint(x: rect.maxX, y: y + rect.height * 0.05))
        ctx.strokePath()
    }
    // gold edge fingers along the bottom
    ctx.setFillColor(NSColor(red: 0.80, green: 0.65, blue: 0.30, alpha: 1).cgColor)
    let fw = rect.width / 24
    for i in 0..<12 {
        let x = rect.minX + rect.width * 0.04 + CGFloat(i) * fw * 1.9
        ctx.fill(CGRect(x: x, y: rect.minY, width: fw, height: rect.height * 0.07))
    }

    // dark CRT glass inset
    let glass = rect.insetBy(dx: rect.width * 0.14, dy: rect.height * 0.17)
    ctx.setFillColor(NSColor(white: 0.04, alpha: 1).cgColor)
    NSBezierPath(roundedRect: glass.insetBy(dx: -size * 0.018, dy: -size * 0.018),
                 xRadius: size * 0.08, yRadius: size * 0.08).fill()
    NSColor(red: 0.02, green: 0.05, blue: 0.03, alpha: 1).setFill()
    NSBezierPath(roundedRect: glass, xRadius: size * 0.07, yRadius: size * 0.07).fill()

    // The boot prompt + cursor, striped. The cursor is the Apple-1's
    // blinking "@" (the 2513 had no inverse video) — a solid block would
    // be the Apple II's cursor, the wrong machine.
    let font = NSFont.monospacedSystemFont(ofSize: size * 0.36, weight: .bold)
    let s = NSAttributedString(string: "\\@",
                               attributes: [.font: font, .foregroundColor: NSColor.white])
    let ts = s.size()
    let at = CGPoint(x: glass.midX - ts.width / 2, y: glass.midY - ts.height / 2)
    let glyphImg = NSImage(size: NSSize(width: ts.width + 2, height: ts.height + 2))
    glyphImg.lockFocus()
    s.draw(at: CGPoint(x: 1, y: 1))
    glyphImg.unlockFocus()
    let mask = glyphImg.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    let glyphRect = CGRect(x: at.x - 1, y: at.y - 1, width: ts.width + 2, height: ts.height + 2)
    // soft phosphor bloom behind the glyph
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: size * 0.05,
                  color: NSColor(white: 1, alpha: 0.55).cgColor)
    ctx.draw(mask, in: glyphRect)
    ctx.restoreGState()
    // six stripes through the glyph (CG is y-up, so reversed keeps green on top)
    ctx.saveGState()
    ctx.clip(to: glyphRect, mask: mask)
    let band = glyphRect.height / 6
    for (i, color) in stripes.reversed().enumerated() {
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(x: glyphRect.minX, y: glyphRect.minY + CGFloat(i) * band,
                        width: glyphRect.width, height: band))
    }
    ctx.restoreGState()

    // scanlines + glass glare over everything on the tube (skip at tiny sizes)
    if px >= 64 {
        ctx.saveGState()
        NSBezierPath(roundedRect: glass, xRadius: size * 0.07, yRadius: size * 0.07).addClip()
        ctx.setFillColor(NSColor(white: 0, alpha: 0.22).cgColor)
        var y = glass.minY
        while y < glass.maxY {
            ctx.fill(CGRect(x: glass.minX, y: y, width: glass.width, height: size * 0.005))
            y += size * 0.016
        }
        let hl = NSGradient(colors: [NSColor(white: 1, alpha: 0.10),
                                     NSColor(white: 1, alpha: 0)])!
        hl.draw(in: CGRect(x: glass.minX, y: glass.midY,
                           width: glass.width, height: glass.height / 2), angle: -70)
        ctx.restoreGState()
    }
    image.unlockFocus()
    return image
}

for px in sizes {
    let img = draw(px)
    let rep = NSBitmapImageRep(cgImage: img.cgImage(forProposedRect: nil, context: nil, hints: nil)!)
    rep.size = NSSize(width: px, height: px)
    let data = rep.representation(using: .png, properties: [:])!
    let names: [String]
    switch px {
    case 16: names = ["icon_16x16.png"]
    case 32: names = ["icon_16x16@2x.png", "icon_32x32.png"]
    case 64: names = ["icon_32x32@2x.png"]
    case 128: names = ["icon_128x128.png"]
    case 256: names = ["icon_128x128@2x.png", "icon_256x256.png"]
    case 512: names = ["icon_256x256@2x.png", "icon_512x512.png"]
    default: names = ["icon_512x512@2x.png"]
    }
    for n in names { try! data.write(to: URL(fileURLWithPath: "\(out)/\(n)")) }
}
print("iconset written")
