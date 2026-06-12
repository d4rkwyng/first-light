import Foundation

/// Bundled ROM images. Woz Monitor, Integer BASIC and the ACI ROM remain
/// Apple copyrights; they have circulated freely in the Apple-1 community
/// for decades and are included here, as in most open-source Apple-1
/// emulators, for preservation and education.
public enum ROM {
    public enum Error: Swift.Error {
        case missing(String)
    }

    public static func wozmon() throws -> [UInt8] {
        try load("wozmon")
    }

    /// Apple Integer BASIC ("Apple 1 BASIC"), 4 KB, loads at $E000;
    /// start with E000R, warm-restart at E2B3R.
    ///
    /// Note: a widely-circulated dump of this ROM has 2 corrupted bytes
    /// ($F2 for $12) that silently break the input loop. This is the
    /// good dump — it echoes, prompts with ">", and runs programs.
    public static func integerBASIC() throws -> [UInt8] {
        try load("apple1basic")
    }

    /// Signetics 2513 character generator contents (P-LAB dump, CC BY 4.0):
    /// 8 bytes per character indexed by ASCII code, low 5 bits per row,
    /// bit 4 = leftmost pixel. Glyphs exist for $20-$5F only.
    public static func characterROM() throws -> [UInt8] {
        try load("charrom2513")
    }

    private static func load(_ name: String) throws -> [UInt8] {
        guard let url = Bundle.module.url(
            forResource: name, withExtension: "bin", subdirectory: "ROMs")
        else { throw Error.missing(name) }
        return [UInt8](try Data(contentsOf: url))
    }
}
