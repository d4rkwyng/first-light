import Foundation
import Apple1Core

/// Probe: which zero-page bytes hold Integer BASIC's program pointers,
/// so we can synthesize the unpublished ZP block for Blackjack.
@MainActor
enum ZPExperiment {
    static func run() -> Never {
        func machineWith(program lines: [String]) -> Apple1 {
            let m = try! Apple1()
            m.displayCyclesPerChar = 0
            m.load(try! ROM.integerBASIC(), at: 0xE000)
            m.type("E000R\n")
            m.run(cycles: 3_000_000)
            for line in lines {
                m.type(line + "\n")
                m.run(cycles: 3_000_000)
            }
            return m
        }
        let small = machineWith(program: ["10 PRINT 1"])
        let big = machineWith(program: ["10 PRINT 1", "20 PRINT 2",
                                        "30 PRINT 345678"])
        let zpS = small.read(from: 0x4A, to: 0xFF)
        let zpB = big.read(from: 0x4A, to: 0xFF)
        print("bytes differing between small and big program:")
        for i in 0..<zpS.count where zpS[i] != zpB[i] {
            print(String(format: "  $%02X: %02X -> %02X",
                         0x4A + i, zpS[i], zpB[i]))
        }
        // also show stable bytes that look like HIMEM/LOMEM ($1000, $0800)
        print("\nfull ZP $4A-$FF (small program):")
        for row in stride(from: 0, to: zpS.count, by: 16) {
            let slice = zpS[row..<min(row + 16, zpS.count)]
            print(String(format: "%02X: ", 0x4A + row)
                  + slice.map { String(format: "%02X", $0) }.joined(separator: " "))
        }
        exit(0)
    }
}
