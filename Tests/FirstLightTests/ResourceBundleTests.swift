import Testing
import Foundation
@testable import FirstLight

/// The app target's accessor must resolve the real `<package>_<target>`
/// bundle (a renamed package or target changes the name SwiftPM uses, and
/// the hard-coded `bundleName` would then miss in the packaged app).
struct FirstLightResourceBundleTests {
    @Test func liveAccessorFindsTheRealBundle() throws {
        #expect(FirstLightResources.bundle.bundleURL.lastPathComponent
                == FirstLightResources.bundleName + ".bundle")
        #expect(FirstLightResources.bundle.url(forResource: "board-copper",
                                               withExtension: "png",
                                               subdirectory: "Resources") != nil)
    }
}
