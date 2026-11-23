import Testing
import Foundation
@testable import Apple1Core

/// The packaged app must find its resource bundles in Contents/Resources.
/// SwiftPM's generated `Bundle.module` does not look there (1.0.0 / 1.0.1
/// crashed at launch on every Mac but the build machine), so these tests
/// pin `ResourceBundleLocator` against a fake .app laid out the way
/// Scripts/build-app.sh lays out First Light.app.
struct ResourceBundleTests {

    /// Builds `<tmp>/Fake.app` with Info.plist, an executable, and
    /// `Contents/Resources/<name>.bundle/ROMs/wozmon.bin`. Returns the app URL.
    private func makeFakeApp(in root: URL, bundleName: String) throws -> URL {
        let fm = FileManager.default
        let app = root.appendingPathComponent("Fake.app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        let macos = contents.appendingPathComponent("MacOS", isDirectory: true)
        let roms = contents.appendingPathComponent(
            "Resources/\(bundleName).bundle/ROMs", isDirectory: true)
        try fm.createDirectory(at: macos, withIntermediateDirectories: true)
        try fm.createDirectory(at: roms, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "CFBundleExecutable": "Fake",
            "CFBundleIdentifier": "test.fake.\(UUID().uuidString)",
            "CFBundlePackageType": "APPL",
        ]
        try PropertyListSerialization
            .data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        try Data([0x60]).write(to: macos.appendingPathComponent("Fake"))
        try fm.setAttributes([.posixPermissions: 0o755],
                             ofItemAtPath: macos.appendingPathComponent("Fake").path)
        try Data([0xD8, 0x58]).write(to: roms.appendingPathComponent("wozmon.bin"))
        return app
    }

    private func withTempDir<T>(_ body: (URL) throws -> T) throws -> T {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fl-bundle-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        return try body(dir.resolvingSymlinksInPath())
    }

    private func path(_ url: URL?) -> String? {
        url?.resolvingSymlinksInPath().standardizedFileURL.path
    }

    @Test func candidatesForAnAppStartWithContentsResources() throws {
        try withTempDir { root in
            let app = try makeFakeApp(in: root, bundleName: "x_Y")
            let main = try #require(Bundle(url: app))
            let dirs = ResourceBundleLocator.candidateDirectories(main: main)
            #expect(dirs.map { path($0) } == [
                path(app.appendingPathComponent("Contents/Resources")),
                path(app),
                path(app.appendingPathComponent("Contents/MacOS")),
            ])
        }
    }

    @Test func resolvesTheBundleInContentsResources() throws {
        try withTempDir { root in
            let name = Apple1CoreResources.bundleName
            let app = try makeFakeApp(in: root, bundleName: name)
            let main = try #require(Bundle(url: app))
            let found = try #require(ResourceBundleLocator.locate(name, main: main))
            #expect(path(found.bundleURL) == path(
                app.appendingPathComponent("Contents/Resources/\(name).bundle")))
            let rom = try #require(found.url(forResource: "wozmon", withExtension: "bin",
                                             subdirectory: "ROMs"))
            #expect(try Data(contentsOf: rom) == Data([0xD8, 0x58]))
        }
    }

    @Test func contentsResourcesWinsOverTheAppRoot() throws {
        try withTempDir { root in
            let app = try makeFakeApp(in: root, bundleName: "x_Y")
            try FileManager.default.createDirectory(
                at: app.appendingPathComponent("x_Y.bundle"),
                withIntermediateDirectories: true)
            let main = try #require(Bundle(url: app))
            let found = try #require(ResourceBundleLocator.locate("x_Y", main: main))
            #expect(path(found.bundleURL) == path(
                app.appendingPathComponent("Contents/Resources/x_Y.bundle")))
        }
    }

    @Test func extraDirectoriesAreSearchedLast() throws {
        try withTempDir { root in
            let app = try makeFakeApp(in: root, bundleName: "other_Bundle")
            let side = root.appendingPathComponent("side", isDirectory: true)
            try FileManager.default.createDirectory(
                at: side.appendingPathComponent("x_Y.bundle"),
                withIntermediateDirectories: true)
            let main = try #require(Bundle(url: app))
            let found = try #require(
                ResourceBundleLocator.locate("x_Y", main: main, extra: [nil, side]))
            #expect(path(found.bundleURL) == path(side.appendingPathComponent("x_Y.bundle")))
        }
    }

    /// No candidate holds the bundle: nil, not a trap.
    @Test func missingBundleIsNilNotACrash() throws {
        try withTempDir { root in
            let app = try makeFakeApp(in: root, bundleName: "other_Bundle")
            let main = try #require(Bundle(url: app))
            #expect(ResourceBundleLocator.locate("x_Y", main: main) == nil)
            // A regular file with the bundle's name is not a bundle.
            try Data().write(to: root.appendingPathComponent("x_Y.bundle"))
            #expect(ResourceBundleLocator.locate("x_Y", in: [root]) == nil)
        }
    }

    /// Under `swift test` the bundle is in .build; whichever path finds it,
    /// it must be the real Apple1Core bundle (catches a renamed package or
    /// target, which would change SwiftPM's `<package>_<target>` name).
    @Test func liveAccessorFindsTheRealBundle() throws {
        #expect(Apple1CoreResources.bundle.bundleURL.lastPathComponent
                == Apple1CoreResources.bundleName + ".bundle")
        #expect(Apple1CoreResources.bundle.url(forResource: "wozmon", withExtension: "bin",
                                               subdirectory: "ROMs") != nil)
    }
}
