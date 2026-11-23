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

    static let bundle: Bundle = {
        let finder = Bundle(for: FirstLightBundleFinder.self)
        return ResourceBundleLocator.locate(
            bundleName,
            extra: [finder.resourceURL, finder.bundleURL.deletingLastPathComponent()])
            // swift test / swift run only (bundle in .build). Never reached in
            // a packaged app whose bundle is in Contents/Resources.
            ?? Bundle.module
    }()
}
