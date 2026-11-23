import Foundation

/// Finds a SwiftPM resource bundle without relying on `Bundle.module` in the
/// shipped app.
///
/// Why not `Bundle.module`: the accessor SwiftPM generates (command-line
/// `swift build`) only looks for `<name>.bundle` at `Bundle.main.bundleURL`,
/// which for an .app is the bundle ROOT (`First Light.app/`), and then at the
/// absolute build-time path (`…/.build/<triple>/release/<name>.bundle`). If
/// neither exists it calls `fatalError`. Scripts/build-app.sh puts the bundles
/// in `Contents/Resources/` (the only place codesign and notarization accept
/// them), so a packaged app only ever worked on the machine that built it,
/// through the build-path fallback. 1.0.0 and 1.0.1 crashed at launch
/// everywhere else.
///
/// `locate` checks the places an app, a command-line tool, or a test runner
/// keep their resource bundles, in that order, and returns nil rather than
/// trapping. Each target's accessor (`Apple1CoreResources.bundle`, and
/// `FirstLightResources.bundle` in the app) falls back to `Bundle.module`
/// only after every candidate here missed — that path is for `swift test` /
/// `swift run`, where the bundles live in .build next to the binaries.
public enum ResourceBundleLocator {

    /// Directories searched for `<name>.bundle`, most specific first:
    ///  1. `main.resourceURL` — `X.app/Contents/Resources` (where the app ships
    ///     its bundles; for a bare executable this is its own directory);
    ///  2. `main.bundleURL` — the .app root, or a CLI tool's directory (where
    ///     SwiftPM's own accessor looks);
    ///  3. the directory holding `main`'s executable (`swift run`, and a
    ///     binary copied out of .build together with its bundles);
    ///  4. `extra` — e.g. the directory of the code bundle that contains the
    ///     caller (`Bundle(for:)`, the .xctest under `swift test`).
    /// Nils and duplicates are dropped; order is kept.
    public static func candidateDirectories(main: Bundle = .main,
                                            extra: [URL?] = []) -> [URL] {
        let raw: [URL?] = [
            main.resourceURL,
            main.bundleURL,
            main.executableURL?.deletingLastPathComponent(),
        ] + extra
        var seen = Set<String>()
        var out: [URL] = []
        for case let url? in raw {
            let key = url.standardizedFileURL.path
            if seen.insert(key).inserted { out.append(url) }
        }
        return out
    }

    /// The first `<directory>/<name>.bundle` that exists as a directory and
    /// opens as a `Bundle`, or nil. Never traps.
    public static func locate(_ name: String, in directories: [URL]) -> Bundle? {
        for dir in directories {
            let url = dir.appendingPathComponent(name + ".bundle", isDirectory: true)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
                  isDir.boolValue,
                  let bundle = Bundle(url: url) else { continue }
            return bundle
        }
        return nil
    }

    /// `locate(name, in: candidateDirectories(main:extra:))`.
    public static func locate(_ name: String, main: Bundle = .main,
                              extra: [URL?] = []) -> Bundle? {
        locate(name, in: candidateDirectories(main: main, extra: extra))
    }
}

private final class Apple1CoreBundleFinder {}

/// Apple1Core's resources (the ROM images). Use this, never `Bundle.module`.
public enum Apple1CoreResources {
    /// SwiftPM names a target's resource bundle `<package>_<target>`.
    public static let bundleName = "first-light_Apple1Core"

    public static let bundle: Bundle = {
        let finder = Bundle(for: Apple1CoreBundleFinder.self)
        return ResourceBundleLocator.locate(
            bundleName,
            extra: [finder.resourceURL, finder.bundleURL.deletingLastPathComponent()])
            // swift test / swift run only: the bundle is in .build, and the
            // generated accessor knows that absolute path. Never reached in a
            // packaged app whose bundle is in Contents/Resources.
            ?? Bundle.module
    }()
}
