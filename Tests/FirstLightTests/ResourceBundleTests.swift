import Testing
import Foundation
@testable import FirstLight
import Apple1Core

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

/// `--resource-check` must find both bundles through the locator alone
/// (no `Bundle.module`) and load its known file from each.
struct ResourceCheckTests {
    @Test func bothBundlesPassThroughTheLocator() {
        #expect(Apple1CoreResources.located != nil)
        #expect(FirstLightResources.located != nil)
        let results = ResourceCheck.results()
        #expect(results.count == 2)
        for r in results { #expect(r.ok, "\(r.line)") }
    }

    @Test func aLocatorMissIsAFailureNotAFallback() {
        let r = ResourceCheck.check(label: "X", name: "x_Y", bundle: nil, file: "f",
                                    ext: "bin", subdirectory: "ROMs", size: 1)
        #expect(!r.ok)
        #expect(r.line.hasPrefix("resource-check FAIL X: x_Y.bundle not found"))
    }

    @Test func aWrongSizeFails() throws {
        let bundle = try #require(Apple1CoreResources.located)
        let r = ResourceCheck.check(label: "Apple1Core", name: "n", bundle: bundle,
                                    file: "wozmon", ext: "bin", subdirectory: "ROMs", size: 255)
        #expect(!r.ok)
        #expect(r.line.contains("is 256 bytes, expected 255"))
    }
}
