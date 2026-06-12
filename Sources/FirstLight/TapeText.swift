import Foundation

/// The wozmon text format — shared by tape recording, the custom-tape
/// loader, and the verifier, so what we write always reloads.
enum TapeText {
    static func encode(bytes: [UInt8], from address: Int) -> String {
        var lines: [String] = []
        var cursor = address
        for chunk in stride(from: 0, to: bytes.count, by: 8) {
            let slice = bytes[chunk..<min(chunk + 8, bytes.count)]
            let hex = slice.map { String(format: "%02X", $0) }
                .joined(separator: " ")
            lines.append(String(format: "%04X: ", cursor) + hex)
            cursor += 8
        }
        return lines.joined(separator: "\n")
    }

    static func parse(_ text: String) -> [(address: UInt16, bytes: [UInt8])] {
        var chunks: [(UInt16, [UInt8])] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":")
            guard parts.count == 2,
                  let address = UInt16(parts[0].trimmingCharacters(in: .whitespaces),
                                       radix: 16) else { continue }
            let bytes = parts[1].split(separator: " ").compactMap {
                UInt8($0, radix: 16)
            }
            guard !bytes.isEmpty else { continue }
            chunks.append((address, bytes))
        }
        return chunks
    }
}
