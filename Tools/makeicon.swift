// Renders the app icon: PCB-green squircle, faint traces, gold edge
// fingers, and the 1977 six-stripe apple. Emits an .iconset + .icns.
import AppKit

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let out = "dist/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func draw(_ px: Int) -> NSImage {
    let size = CGFloat(px)
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext

    // macOS icon grid: content inset ~10%
    let inset = size * 0.09
    let rect = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let squircle = NSBezierPath(roundedRect: rect, xRadius: size * 0.2, yRadius: size * 0.2)
    squircle.addClip()

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

    // six-stripe apple
    if let symbol = NSImage(systemSymbolName: "applelogo", accessibilityDescription: nil) {
        let config = NSImage.SymbolConfiguration(pointSize: size * 0.5, weight: .regular)
        let glyph = symbol.withSymbolConfiguration(config)!
        let gsize = glyph.size
        let scale = (rect.height * 0.58) / gsize.height
        let w = gsize.width * scale, h = gsize.height * scale
        let gx = rect.midX - w / 2, gy = rect.midY - h / 2 + rect.height * 0.02
        let stripes: [NSColor] = [
            NSColor(red: 0.00, green: 0.56, blue: 0.84, alpha: 1),
            NSColor(red: 0.58, green: 0.22, blue: 0.56, alpha: 1),
            NSColor(red: 0.89, green: 0.16, blue: 0.12, alpha: 1),
            NSColor(red: 0.96, green: 0.51, blue: 0.12, alpha: 1),
            NSColor(red: 0.99, green: 0.78, blue: 0.05, alpha: 1),
            NSColor(red: 0.38, green: 0.73, blue: 0.27, alpha: 1),
        ] // bottom→top
        ctx.saveGState()
        let glyphRect = CGRect(x: gx, y: gy, width: w, height: h)
        ctx.clip(to: glyphRect, mask: glyph.cgImage(forProposedRect: nil, context: nil, hints: nil)!)
        let band = h / 6
        for (i, color) in stripes.enumerated() {
            ctx.setFillColor(color.cgColor)
            ctx.fill(CGRect(x: gx, y: gy + CGFloat(i) * band, width: w, height: band))
        }
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
