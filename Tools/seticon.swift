// Stamps the Finder icon directly onto the app bundle (resource-fork
// custom icon) — bypasses the LaunchServices icns pipeline entirely.
import AppKit
let args = CommandLine.arguments
guard args.count == 3,
      let image = NSImage(contentsOfFile: args[1]) else {
    print("usage: seticon <image> <target>")
    exit(1)
}
let ok = NSWorkspace.shared.setIcon(image, forFile: args[2])
print(ok ? "icon stamped on \(args[2])" : "FAILED")
exit(ok ? 0 : 1)
