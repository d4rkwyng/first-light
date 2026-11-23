import Foundation
import Apple1Core

private final class FirstLightBundleFinder {}

/// The app target's resources (board art, gallery, tapes, CRT shader).
/// Use this, never `Bundle.module`: SwiftPM's generated accessor does not
/// look in Contents/Resources and traps when the bundle is elsewhere. See
/// `ResourceBundleLocator` in Apple1Core.
enum FirstLightResources {
    /// SwiftPM names a target's resource bundle `<package>_<target>`.
    static let bundleName = "first-light_FirstLight"

    /// The bundle as found by `ResourceBundleLocator`, or nil. Never traps
    /// and never consults `Bundle.module` (see `ResourceCheck`).
    static let located: Bundle? = {
        let finder = Bundle(for: FirstLightBundleFinder.self)
        return ResourceBundleLocator.locate(
            bundleName,
            extra: [finder.resourceURL, finder.bundleURL.deletingLastPathComponent()])
    }()

    static let bundle: Bundle = located
        // swift test / swift run only (bundle in .build). Never reached in
        // a packaged app whose bundle is in Contents/Resources.
        ?? Bundle.module
}

/// `First Light --resource-check`: load one known file from each resource
/// bundle through the locator alone and exit 0 if both load, 1 otherwise.
/// Scripts/smoke-launch.sh runs it on the packaged app with the build-time
/// bundle paths hidden. It never touches `Bundle.module`: a locator miss is
/// a failure here, not a fallback (in the shipped app that fallback is
/// exactly the trap that crashed 1.0.0 and 1.0.1).
enum ResourceCheck {
    struct Result {
        var ok: Bool
        var line: String
    }

    /// One known file per bundle: the Woz Monitor ROM (exactly 256 bytes)
    /// and the copper board image the bench draws at launch.
    static func results() -> [Result] {
        [
            check(label: "Apple1Core", name: Apple1CoreResources.bundleName,
                  bundle: Apple1CoreResources.located,
                  file: "wozmon", ext: "bin", subdirectory: "ROMs", size: 256),
            check(label: "FirstLight", name: FirstLightResources.bundleName,
                  bundle: FirstLightResources.located,
                  file: "board-copper", ext: "png", subdirectory: "Resources", size: nil),
        ]
    }

    /// `size` nil means "any non-empty file".
    static func check(label: String, name: String, bundle: Bundle?, file: String,
                      ext: String, subdirectory: String, size: Int?) -> Result {
        let item = "\(subdirectory)/\(file).\(ext)"
        guard let bundle else {
            return Result(ok: false, line: "resource-check FAIL \(label): \(name).bundle not found by the locator")
        }
        let path = bundle.bundleURL.path
        guard let url = bundle.url(forResource: file, withExtension: ext,
                                   subdirectory: subdirectory) else {
            return Result(ok: false, line: "resource-check FAIL \(label): \(item) missing in \(path)")
        }
        guard let data = try? Data(contentsOf: url) else {
            return Result(ok: false, line: "resource-check FAIL \(label): \(item) unreadable in \(path)")
        }
        if let size, data.count != size {
            return Result(ok: false, line: "resource-check FAIL \(label): \(item) is \(data.count) bytes, expected \(size), in \(path)")
        }
        if data.isEmpty {
            return Result(ok: false, line: "resource-check FAIL \(label): \(item) is empty in \(path)")
        }
        return Result(ok: true, line: "resource-check PASS \(label): \(item) (\(data.count) bytes) from \(path)")
    }

    static func run() -> Never {
        let results = results()
        for r in results { print(r.line) }
        fflush(stdout)
        exit(results.allSatisfy(\.ok) ? 0 : 1)
    }
}
