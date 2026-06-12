import SwiftUI

@main
struct FirstLightApp: App {
    init() {
        if CommandLine.arguments.contains("--verify-tapes") {
            TapeVerifier.run()
        }
        // Dock icon, set directly at runtime — immune to LaunchServices
        // cache moods.
        if let url = Bundle.main.url(forResource: "AppIcon",
                                     withExtension: "icns")
            ?? Bundle.module.url(forResource: "AppIcon",
                                 withExtension: "icns",
                                 subdirectory: "Resources"),
           let image = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = image
        }
        if CommandLine.arguments.contains("--verify-failures") {
            FailureVerifier.run()
        }
        if CommandLine.arguments.contains("--zp-experiment") {
            ZPExperiment.run()
        }
    }

    @State private var controller = MachineController()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("First Light — Apple-1", id: "main") {
            ContentView(controller: controller)
                .frame(minWidth: 1280, minHeight: 640)
        }
        .commands {
            CommandMenu("Machine") {
                Button("Reset") { controller.reset() }
                    .keyboardShortcut("r")
                Button("Paste into Apple-1") { controller.paste() }
                    .keyboardShortcut("v")
                Divider()
                Button("Connect Everything") { controller.connectAll() }
                    .keyboardShortcut("k", modifiers: [.command, .shift])
                Button("Strip to Bare Board") { controller.stripBoard() }
                Divider()
                Picker("CPU Speed", selection: Binding(
                    get: { controller.turboFactor },
                    set: { controller.turboFactor = $0 })) {
                    Text("Authentic — 1.023 MHz").tag(1)
                    Text("Turbo ×10").tag(10)
                    Text("Turbo ×100").tag(100)
                }
                Divider()
                Menu("Sound") {
                    Toggle("Sound", isOn: Binding(
                        get: { controller.sound.enabled },
                        set: { controller.sound.enabled = $0 }))
                        .keyboardShortcut("m", modifiers: [.command, .shift])
                    Divider()
                    Toggle("Key Clicks", isOn: Binding(
                        get: { controller.sound.keyClicksEnabled },
                        set: { controller.sound.keyClicksEnabled = $0 }))
                    Toggle("Persistent Power Hum", isOn: Binding(
                        get: { controller.sound.persistentHum },
                        set: { controller.sound.persistentHum = $0 }))
                    Toggle("CRT Flyback Whine (15.7 kHz)", isOn: Binding(
                        get: { controller.flybackWhine },
                        set: { controller.flybackWhine = $0 }))
                }
                Toggle("Power On at Launch", isOn: Binding(
                    get: { UserDefaults.standard.object(forKey: "powerOnAtLaunch") as? Bool ?? true },
                    set: { UserDefaults.standard.set($0, forKey: "powerOnAtLaunch") }))
                Divider()
                Button("Save Machine State…") { controller.saveSnapshot() }
                    .keyboardShortcut("s")
                Button("Restore Machine State…") { controller.restoreSnapshot() }
                    .keyboardShortcut("o", modifiers: [.command, .option])
            }
            CommandGroup(after: .toolbar) {
                Divider()
                Button("Full-Screen Display") {
                    controller.fullScreenDisplay.toggle()
                }
                .keyboardShortcut("f")
                Button("Detach Screen into Monitor Window") {
                    controller.screenDetached = true
                    openWindow(id: "screen")
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Photograph the Bench…") {
                    BenchPhotographer.save(controller)
                }
                Button("Inspect the Cassette Interface Card…") {
                    controller.aciInspectRequested = true
                }
                Button("Open the Scope (CPU Inspector)") {
                    openWindow(id: "scope")
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                Divider()
                Toggle("Lighting Effects", isOn: Binding(
                    get: { controller.lightingEffects },
                    set: { controller.lightingEffects = $0 }))
                Toggle("Footprint Audit Overlay", isOn: Binding(
                    get: { controller.showAudit },
                    set: { controller.showAudit = $0 }))
                    .keyboardShortcut("a", modifiers: [.command, .option])
            }
            CommandGroup(replacing: .help) {
                Menu("Tutorials") {
                    Button("Operate It") { controller.startTutorial(track: 0) }
                        .keyboardShortcut("t")
                    Button("Under the Hood") { controller.startTutorial(track: 1) }
                    Button("The Software Story") { controller.startTutorial(track: 2) }
                }
                Divider()
                Button("Command Palette…") { controller.paletteRequested = true }
                    .keyboardShortcut("k")
                Button("Quick Reference") { controller.referenceRequested = true }
                    .keyboardShortcut("/")
                Divider()
                Button("Welcome…") { controller.welcomeRequested = true }
                Button("Real Apple-1 Photos…") { controller.galleryRequested = true }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                Divider()
                Link("Original Operation Manual (archive.org)",
                     destination: URL(string:
                        "https://archive.org/details/Apple-1_Operation_Manual_1976_Apple")!)
            }
            CommandMenu("Cassettes") {
                ForEach(TapeLibrary.tapes.filter { !$0.homebrew }) { tape in
                    if tape.name == "Integer BASIC" {
                        Button(tape.name) { controller.insert(tape) }
                            .keyboardShortcut("b")
                    } else {
                        Button(tape.name) { controller.insert(tape) }
                    }
                }
                Divider()
                Text("Homebrew")
                ForEach(TapeLibrary.tapes.filter(\.homebrew)) { tape in
                    Button(tape.name) { controller.insert(tape) }
                }
                Divider()
                Button("Load Custom Cassette…") {
                    controller.customTapeRequested = true
                }
                .keyboardShortcut("o")
                Button("Record to Cassette…") {
                    controller.recordRequested = true
                }
                Divider()
                Toggle("Authentic Load Speed", isOn: Binding(
                    get: { controller.authenticLoads },
                    set: { controller.authenticLoads = $0 }))
                Divider()
                Menu("Type-In Programs") {
                    ForEach(Programs.all) { program in
                        Button(program.name) { controller.run(program) }
                    }
                }
            }
        }
        Window("Scope — Apple-1", id: "scope") {
            ScopeView(controller: controller)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .windowLevel(.floating)

        Window("Keyboard — Apple-1", id: "keyboard") {
            KeyboardView(controller: controller)
                .padding(10)
                .background(Color(red: 0.13, green: 0.11, blue: 0.09))
                .onAppear { controller.keyboardDetached = true }
                .onDisappear { controller.keyboardDetached = false }
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .windowLevel(.floating)

        Window("Monitor — Apple-1", id: "screen") {
            MonitorView(controller: controller)
                .padding(8)
                .background(Color.black)
                .frame(minWidth: 540, minHeight: 430)
                .overlay(alignment: .bottom) {
                    TapeLoadingToast(controller: controller)
                        .padding(.bottom, 18)
                }
                .onAppear { controller.screenDetached = true }
                .onDisappear { controller.screenDetached = false }
        }
        .defaultSize(width: 600, height: 470)
        .defaultLaunchBehavior(.suppressed)   // never opens at launch
        .restorationBehavior(.disabled)       // no state-restoration ghost
        .windowLevel(.floating)               // stays above the bench
    }
}
