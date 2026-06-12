import SwiftUI
import Apple1Core

/// P3: the Scope — live registers, disassembly around the PC, and a
/// memory dump. The modern window into the 1976 machine.
struct ScopeView: View {
    let controller: MachineController
    @State private var dumpAddress = "FF00"

    var body: some View {
        // refresh ~10×/sec, not every frame
        let _ = controller.frame / 6
        let regs = controller.machine.registers
        VStack(alignment: .leading, spacing: 10) {
            // registers
            HStack(spacing: 14) {
                reg("A", regs.a); reg("X", regs.x); reg("Y", regs.y)
                reg("SP", regs.sp)
                Text(String(format: "PC %04X", regs.pc))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
                flags(regs.status)
            }
            Divider()
            HStack(alignment: .top, spacing: 16) {
                // disassembly from PC
                VStack(alignment: .leading, spacing: 1) {
                    Text("DISASSEMBLY").font(.system(size: 8, weight: .bold,
                                                    design: .monospaced))
                        .foregroundStyle(.secondary)
                    let lines = disassemble(from: Int(regs.pc), count: 14)
                    ForEach(0..<lines.count, id: \.self) { i in
                        Text(lines[i])
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(i == 0 ? .green : .primary)
                    }
                }
                Divider()
                // memory dump
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("MEMORY").font(.system(size: 8, weight: .bold,
                                                    design: .monospaced))
                            .foregroundStyle(.secondary)
                        TextField("hex", text: $dumpAddress)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 10, design: .monospaced))
                            .frame(width: 56)
                    }
                    let base = (Int(dumpAddress, radix: 16) ?? 0xFF00) & 0xFFF0
                    ForEach(0..<8, id: \.self) { row in
                        let addr = (base + row * 16) & 0xFFFF
                        let bytes = controller.machine.read(from: addr,
                                                            to: addr + 15)
                        Text(String(format: "%04X  ", addr)
                             + bytes.map { String(format: "%02X", $0) }
                                 .joined(separator: " "))
                            .font(.system(size: 10, design: .monospaced))
                    }
                }
            }
        }
        .padding(14)
        .frame(minWidth: 660, minHeight: 300)
        .background(Color(red: 0.09, green: 0.10, blue: 0.09))
        .foregroundStyle(.white.opacity(0.9))
    }

    private func reg(_ name: String, _ value: UInt8) -> some View {
        Text(String(format: "%@ %02X", name, value))
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
    }

    private func flags(_ status: UInt8) -> some View {
        HStack(spacing: 3) {
            ForEach(Array("NV-BDIZC".enumerated()), id: \.offset) { i, ch in
                Text(String(ch))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(status & (0x80 >> i) != 0
                                     ? Color.green : .white.opacity(0.25))
            }
        }
    }

    private func disassemble(from pc: Int, count: Int) -> [String] {
        var lines: [String] = []
        var address = pc
        for _ in 0..<count {
            let bytes = controller.machine.read(from: address,
                                                to: min(address + 2, 0xFFFF))
            let (text, length) = Disassembler.line(at: address, bytes: bytes)
            lines.append(text)
            address = (address + length) & 0xFFFF
            if address < pc && lines.count > 1 { break } // wrapped
        }
        return lines
    }
}
