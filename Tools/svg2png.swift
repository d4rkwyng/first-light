import AppKit
let args = CommandLine.arguments
guard args.count == 4, let width = Int(args[3]) else {
    print("usage: svg2png <in.svg> <out.png> <width>"); exit(1)
}
guard let image = NSImage(contentsOfFile: args[1]) else {
    print("cannot load \(args[1])"); exit(1)
}
let aspect = image.size.height / image.size.width
let size = NSSize(width: CGFloat(width), height: CGFloat(width) * aspect)
guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width),
    pixelsHigh: Int(size.height), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
    print("rep fail"); exit(1)
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
image.draw(in: NSRect(origin: .zero, size: size))
NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: args[2]))
print("wrote \(args[2]) \(Int(size.width))x\(Int(size.height))")
