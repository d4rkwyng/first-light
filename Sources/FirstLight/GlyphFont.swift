import CoreGraphics
import Apple1Core

/// Renders the Signetics 2513's actual 5×7 dot-matrix glyphs (from the
/// character ROM dump) as tiny CGImages, drawn scaled-up with no
/// interpolation for honest chunky pixels.
@MainActor
final class GlyphFont {
    static let shared = GlyphFont()

    private var images: [UInt8: CGImage] = [:]

    private init() {
        guard let rom = try? ROM.characterROM() else { return }
        // Phosphor green, premultiplied RGBA
        let on: [UInt8] = [102, 255, 115, 255]
        for code in 0x20...0x5F {
            var pixels = [UInt8](repeating: 0, count: 5 * 8 * 4)
            for row in 0..<8 {
                let bits = rom[code * 8 + row]
                for col in 0..<5 where bits & (1 << (4 - col)) != 0 {
                    let offset = (row * 5 + col) * 4
                    pixels.replaceSubrange(offset..<offset + 4, with: on)
                }
            }
            let data = CFDataCreate(nil, pixels, pixels.count)!
            if let provider = CGDataProvider(data: data),
               let image = CGImage(
                   width: 5, height: 8, bitsPerComponent: 8, bitsPerPixel: 32,
                   bytesPerRow: 20, space: CGColorSpaceCreateDeviceRGB(),
                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                   provider: provider, decode: nil, shouldInterpolate: false,
                   intent: .defaultIntent) {
                images[UInt8(code)] = image
            }
        }
    }

    var isAvailable: Bool { !images.isEmpty }

    func image(for ascii: UInt8) -> CGImage? { images[ascii] }
}
