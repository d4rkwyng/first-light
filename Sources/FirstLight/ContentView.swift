import SwiftUI

/// The whole bench: peripheral shelf on the left, the board center,
/// the CRT next to it — the user's 1976 workbench.
struct ContentView: View {
    let controller: MachineController
    @AppStorage("tourOffered") private var tourOffered = false
    @State private var showWelcome = false
    // Panel layout persists across launches (N6)
    @AppStorage("infoCollapsed") private var infoCollapsed = false
    @AppStorage("shelfCollapsed") private var shelfCollapsed = false
    @AppStorage("boardCollapsed") private var boardCollapsed = false
    @AppStorage("crtCollapsed") private var crtCollapsed = false
    @AppStorage("keyboardCollapsed") private var keyboardCollapsed = false
    @AppStorage("deckCollapsed") private var deckCollapsed = false
    @AppStorage("powerOnAtLaunch") private var powerOnAtLaunch = true
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if shelfCollapsed {
                    CompactShelf(controller: controller,
                                 expand: { shelfCollapsed = false })
                } else {
                    ShelfView(controller: controller,
                              collapse: { shelfCollapsed = true })
                        .frame(width: 190)
                }
            }
            .zIndex(3) // hover bubbles float over the board

            if boardCollapsed {
                VStack {
                    Spacer()
                    IconPill(symbol: "memorychip", help: "Show the board") {
                        boardCollapsed = false
                    }
                    Spacer()
                }
                .frame(width: 26)
            } else {
                VStack(spacing: 10) {
                    FittedBoard(controller: controller)
                        .overlay(alignment: .topTrailing) {
                            CollapseButton(symbol: "chevron.left.2",
                                           help: "Hide the board — big screen mode") {
                                boardCollapsed = true; if crtCollapsed { crtCollapsed = false }
                            }
                        }
                    keyboardSection
                    bottomPanel
                }
                .frame(minWidth: 540)
                .zIndex(1) // ACI card overhangs the board edge
            }

            if boardCollapsed && crtCollapsed {
                // Both panels hidden: keep the guidance visible
                VStack {
                    Spacer()
                    bottomPanel
                }
                .frame(maxWidth: .infinity)
            }

            if controller.screenDetached {
                if boardCollapsed {
                    // monitor floating, board tucked away: the main
                    // window becomes the input station
                    VStack(spacing: 14) {
                        Spacer()
                        TapeLoadingToast(controller: controller)
                        keyboardSection
                        deckSection
                        Spacer()
                        IconPill(symbol: "arrow.down.backward.square",
                                 help: "Reattach the monitor") {
                            controller.screenDetached = false
                            dismissWindow(id: "screen")
                        }
                        .padding(.bottom, 6)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    VStack {
                        Spacer()
                        IconPill(symbol: "arrow.down.backward.square",
                                 help: "Reattach the monitor") {
                            controller.screenDetached = false
                            dismissWindow(id: "screen")
                        }
                        Spacer()
                    }
                    .frame(width: 26)
                }
            } else if crtCollapsed {
                VStack(spacing: 6) {
                    IconPill(symbol: "tv", help: "Show the monitor") {
                        crtCollapsed = false
                    }
                    IconPill(symbol: "arrow.up.forward.square",
                             help: "Pop the monitor out") {
                        controller.screenDetached = true
                        openWindow(id: "screen")
                    }
                    Spacer()
                }
                .frame(width: 26)
            } else {
                VStack(spacing: 10) {
                    VStack(spacing: 10) {
                        MonitorView(controller: controller)
                            .aspectRatio(1.30, contentMode: .fit)
                            .frame(maxWidth: 760)
                        if !controller.screenDetached {
                            if boardCollapsed {
                                // big-screen mode: keyboard with the
                                // deck at its side
                                HStack(alignment: .top, spacing: 12) {
                                    keyboardSection
                                    deckSection
                                }
                            } else {
                                deckSection
                            }
                        } else {
                            TapeLoadingToast(controller: controller)
                            if boardCollapsed {
                                keyboardSection
                            }
                        }
                    }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(alignment: .topTrailing) {
                            VStack(spacing: 6) {
                                IconPill(symbol: "chevron.right.2",
                                         help: "Hide the screen — big board mode") {
                                    crtCollapsed = true; if boardCollapsed { boardCollapsed = false }
                                }
                                IconPill(symbol: "arrow.up.forward.square",
                                         help: "Detach into a monitor window") {
                                    controller.screenDetached = true
                                    openWindow(id: "screen")
                                }
                            }
                        }
                    if boardCollapsed { bottomPanel }
                }
                .frame(minWidth: 380)
            }
        }
        .padding(16)
        .onChange(of: controller.screenDetached) { _, detached in
            if detached && boardCollapsed { boardCollapsed = false }
        }

        .fileImporter(isPresented: Binding(get: { controller.customTapeRequested },
                                           set: { controller.customTapeRequested = $0 }),
                      allowedContentTypes: [.plainText, .data, .audio]) { result in
            if case .success(let url) = result {
                let accessing = url.startAccessingSecurityScopedResource()
                controller.insertCustom(url: url)
                if accessing { url.stopAccessingSecurityScopedResource() }
            }
        }
        .sheet(isPresented: Binding(get: { controller.aciInspectRequested },
                                    set: { controller.aciInspectRequested = $0 })) {
            ACIInspectView { controller.aciInspectRequested = false }
        }
        .sheet(isPresented: Binding(get: { controller.recordRequested },
                                    set: { controller.recordRequested = $0 })) {
            RecordTapeView(controller: controller) {
                controller.recordRequested = false
            }
        }
        .sheet(isPresented: Binding(get: { controller.paletteRequested },
                                    set: { controller.paletteRequested = $0 })) {
            CommandPaletteView(controller: controller) {
                controller.paletteRequested = false
            }
        }
        .sheet(isPresented: Binding(get: { controller.referenceRequested },
                                    set: { controller.referenceRequested = $0 })) {
            ReferenceView { controller.referenceRequested = false }
        }
        .sheet(isPresented: Binding(get: { controller.galleryRequested },
                                    set: { controller.galleryRequested = $0 })) {
            GalleryView()
        }
        .background(WorkbenchBackground())
        .overlay(alignment: .bottom) {
            // typing at a deaf machine: visible no matter which panels
            // are collapsed
            if controller.typingHintActive {
                HStack(spacing: 8) {
                    Image(systemName: "keyboard.badge.exclamationmark")
                    Text(controller.connected.contains(.keyboard)
                         ? "No power — connect the power supply first."
                         : "No keyboard connected — double-click its shelf icon, "
                         + "click any on-screen key, or drag it to its socket.")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.orange.opacity(0.95)))
                .padding(.bottom, 60)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8),
                   value: controller.typingHintActive)
        .overlay {
            if controller.fullScreenDisplay {
                ZStack(alignment: .bottom) {
                    Color.black.ignoresSafeArea()
                    TerminalView(controller: controller)
                        .padding(36)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Text("double-click, ESC ESC, or ⌘F to return to the bench")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.22))
                        .padding(.bottom, 10)
                }
                .onTapGesture(count: 2) {
                    controller.fullScreenDisplay = false
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25),
                   value: controller.fullScreenDisplay)
        .overlay {
            if showWelcome || controller.welcomeRequested {
                WelcomeCard(
                    takeTour: {
                        showWelcome = false
                        controller.welcomeRequested = false
                        controller.startTutorial()
                    },
                    explore: {
                        showWelcome = false
                        controller.welcomeRequested = false
                    },
                    showGallery: {
                        showWelcome = false
                        controller.welcomeRequested = false
                        controller.galleryRequested = true
                    },
                    powerUp: {
                        showWelcome = false
                        controller.welcomeRequested = false
                        controller.connectEverything()
                    })
            }
        }
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate()
            controller.start()
            if tourOffered && powerOnAtLaunch {
                // returning user: the bench comes up ready, no ritual
                controller.connectAll()
            }
            if !tourOffered {
                tourOffered = true
                showWelcome = true
            }
        }
    }

    @ViewBuilder private var deckSection: some View {
        if deckCollapsed {
            IconPill(symbol: "recordingtape", help: "Show the tape deck") {
                deckCollapsed = false
            }
            if controller.nowLoading != nil {
                TapeLoadingToast(controller: controller)
            }
        } else {
            HStack(alignment: .top, spacing: 6) {
                TapeDeckBar(controller: controller)
                IconPill(symbol: "chevron.down.2", help: "Tuck the deck away") {
                    deckCollapsed = true
                }
            }
        }
    }

    @ViewBuilder private var keyboardSection: some View {
        if controller.keyboardDetached {
            IconPill(symbol: "keyboard.badge.ellipsis",
                     help: "Reattach the keyboard") {
                controller.keyboardDetached = false
                dismissWindow(id: "keyboard")
            }
        } else if keyboardCollapsed {
            HStack(spacing: 6) {
                IconPill(symbol: "keyboard", help: "Show the keyboard") {
                    keyboardCollapsed = false
                }
                IconPill(symbol: "arrow.up.forward.square",
                         help: "Pop the keyboard out") {
                    controller.keyboardDetached = true
                    openWindow(id: "keyboard")
                }
            }
        } else {
            HStack(alignment: .top, spacing: 8) {
                KeyboardView(controller: controller)
                VStack(spacing: 6) {
                    IconPill(symbol: "chevron.down.2",
                             help: "Tuck the keyboard away") {
                        keyboardCollapsed = true
                    }
                    IconPill(symbol: "arrow.up.forward.square",
                             help: "Pop the keyboard out") {
                        controller.keyboardDetached = true
                        openWindow(id: "keyboard")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var bottomPanel: some View {
        if controller.tutorialStep != nil {
            TutorialPanel(controller: controller)
        } else if infoCollapsed {
            Button {
                infoCollapsed = false
            } label: {
                Image(systemName: "chevron.up")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.4))
        } else {
            HStack(spacing: 8) {
                InfoBar(controller: controller)
                Button {
                    infoCollapsed = true
                } label: {
                    Image(systemName: "chevron.down")
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.4))
                .help("Hide this panel")
            }
            .frame(minHeight: 58) // grows to fit long hover text (don't clip it)
        }
    }
}

/// Small chevron control used to collapse panels.
struct CollapseButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .padding(8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.45))
        .help(help)
    }
}

/// Icon-only shelf: still draggable, one click to expand.
/// Small left-pointing arrow for the removal callout.
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct CompactShelf: View {
    let controller: MachineController
    let expand: () -> Void
    @State private var hoverBubble: String?
    @State private var hoverID: String?

    private func bubble(_ id: String, _ text: String) -> some View {
        HStack(spacing: 0) {
            Triangle()
                .fill(Color(white: 0.16))
                .frame(width: 8, height: 10)
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6)
                    .fill(Color(white: 0.16))
                    .shadow(color: .black.opacity(0.5), radius: 4))
                .fixedSize()
        }
        .opacity(hoverID == id ? 1 : 0)
        .offset(x: 34)
        .allowsHitTesting(false)
        .zIndex(20)
    }

    var body: some View {
        VStack(spacing: 12) {
            Button(action: expand) {
                Image(systemName: "chevron.right.2")
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.5))
            .help("Open the parts shelf")
            ForEach(Peripheral.allCases) { peripheral in
                Image(systemName: peripheral.symbol)
                    .font(.system(size: 16))
                    .foregroundStyle(controller.connected.contains(peripheral)
                                     ? Color.green.opacity(0.7) : .white.opacity(0.9))
                    .frame(width: 30, height: 26)
                    .contentShape(Rectangle())
                    .draggable(peripheral.rawValue)
                    .onTapGesture(count: 2) { controller.toggle(peripheral) }
                    .onHover { inside in
                        hoverID = inside ? peripheral.rawValue
                            : (hoverID == peripheral.rawValue ? nil : hoverID)
                    }
                    .overlay(alignment: .leading) {
                        bubble(peripheral.rawValue,
                               "\(peripheral.name) — "
                               + (controller.connected.contains(peripheral)
                                  ? "connected" : "not connected"))
                    }
            }
            Divider().frame(width: 22)
            // chips: anything pulled glows amber here — double-click
            // reseats it without expanding the shelf
            ForEach(ChipGroup.allCases) { group in
                let calloutAge = controller.pulseFrame
                    - (controller.recentlyRemoved[group] ?? -1000)
                let calloutVisible = calloutAge < 180
                let calloutFade = calloutAge < 120 ? 1.0
                    : max(0, 1.0 - Double(calloutAge - 120) / 60)
                Image(systemName: group.symbol)
                    .font(.system(size: 14))
                    .foregroundStyle(controller.placed.contains(group)
                                     ? Color.green.opacity(0.55)
                                     : Color.orange)
                    .symbolEffect(.pulse,
                                  isActive: !controller.placed.contains(group))
                    .frame(width: 30, height: 24)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        if controller.placed.contains(group) {
                            controller.unplace(group)
                        } else {
                            controller.place(group)
                        }
                    }
                    .onHover { inside in
                        hoverID = inside ? group.rawValue
                            : (hoverID == group.rawValue ? nil : hoverID)
                    }
                    .overlay(alignment: .leading) {
                        bubble(group.rawValue,
                               controller.placed.contains(group)
                               ? "\(group.name) — seated"
                               : "\(group.name) — MISSING")
                    }
                    .overlay(alignment: .leading) {
                        if calloutVisible {
                            HStack(spacing: 0) {
                                Triangle()
                                    .fill(Color.orange.opacity(0.92))
                                    .frame(width: 16, height: 12)
                                Text("\(group.name) removed — double-click to reseat")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.orange.opacity(0.92)))
                                    .fixedSize()
                            }
                            .offset(x: 32)
                            .opacity(calloutFade)
                            .allowsHitTesting(false)
                            .zIndex(10)
                        }
                    }
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .frame(width: 40)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
    }
}

/// A small icon-only round button (board / deck / keyboard chrome).
struct IconPill: View {
    let symbol: String
    var help: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 24, height: 24) // uniform circles, aligned
                .background(Circle().fill(Color(white: 0.14)))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// The tube: keeps identical layout in every state — the picture, the
/// off-glass, and state messages are all overlays on one fixed frame.
struct TubeView: View {
    let controller: MachineController

    var body: some View {
        let message: String? = {
            if !controller.monitorOn { return "" }
            if !controller.connected.contains(.display) { return "NO MONITOR CONNECTED" }
            if !controller.powered { return "NO POWER" }
            if !controller.placed.contains(.video) { return "NO VIDEO SIGNAL" }
            return nil
        }()
        TerminalView(controller: controller)
            .opacity(message == nil ? 1 : 0)
            .overlay {
                if let message {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(red: 0.04, green: 0.05, blue: 0.04))
                        Text(message)
                            .font(.system(size: 11, weight: .semibold,
                                          design: .monospaced))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                    .padding(8)
                }
            }
            .overlay { CollapseFlash(controller: controller) }
            .overlay(alignment: .topLeading) {
                if controller.turboFactor > 1 {
                    Text("TURBO ×\(controller.turboFactor)")
                        .font(.system(size: 8, weight: .heavy,
                                      design: .monospaced))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.black.opacity(0.6)))
                        .padding(10)
                }
            }
            .onTapGesture(count: 2) {
                controller.fullScreenDisplay.toggle()
            }
    }
}

/// The CRT switch-off: picture collapses to a bright line, then a dot.
struct CollapseFlash: View {
    let controller: MachineController

    var body: some View {
        if let off = controller.monitorOffFrame,
           controller.frame - off < 28 {
            let t = Double(controller.frame - off) / 28
            Canvas { ctx, size in
                let width = size.width * (1 - t * 0.92)
                let line = CGRect(x: (size.width - width) / 2,
                                  y: size.height / 2 - 1.2,
                                  width: width, height: 2.4)
                ctx.fill(Path(roundedRect: line, cornerRadius: 1.2),
                         with: .color(.white.opacity(0.95 * (1 - t * 0.6))))
                if t > 0.7 {
                    let r = 3.0 * (1 - t)
                    ctx.fill(Path(ellipseIn: CGRect(x: size.width/2 - r,
                                                    y: size.height/2 - r,
                                                    width: r*2, height: r*2)),
                             with: .color(.white.opacity(1 - t)))
                }
            }
            .allowsHitTesting(false)
        }
    }
}

/// N10: render the live board to a high-res PNG and save it.
@MainActor
enum BenchPhotographer {
    static func save(_ controller: MachineController) {
        let renderer = ImageRenderer(
            content: BoardView(controller: controller)
                .frame(width: BoardView.designSize.width,
                       height: BoardView.designSize.height)
                .background(Color(red: 0.13, green: 0.11, blue: 0.09)))
        renderer.scale = 2.4
        guard let image = renderer.nsImage else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "First Light — Apple-1 Bench.png"
        panel.allowedContentTypes = [.png]
        guard panel.runModal() == .OK, let url = panel.url,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { return }
        try? png.write(to: url)
    }
}

/// The garage workbench: worn wood under a desk lamp. All static —
/// drawn once, no animation cost.
struct WorkbenchBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.16, green: 0.12, blue: 0.085),
                                    Color(red: 0.11, green: 0.08, blue: 0.055)],
                           startPoint: .top, endPoint: .bottom)
            // wood grain: long uneven streaks
            Canvas { ctx, size in
                var seed: UInt64 = 0x1976
                func rnd() -> CGFloat {
                    seed = seed &* 6364136223846793005 &+ 1442695040888963407
                    return CGFloat(seed >> 33) / CGFloat(UInt32.max)
                }
                for _ in 0..<70 {
                    let y = rnd() * size.height
                    let x0 = rnd() * size.width * 0.3
                    let len = size.width * (0.3 + rnd() * 0.7)
                    var path = Path()
                    path.move(to: CGPoint(x: x0, y: y))
                    path.addCurve(to: CGPoint(x: x0 + len, y: y + (rnd() - 0.5) * 6),
                                  control1: CGPoint(x: x0 + len * 0.3, y: y + (rnd() - 0.5) * 4),
                                  control2: CGPoint(x: x0 + len * 0.7, y: y + (rnd() - 0.5) * 4))
                    ctx.stroke(path,
                               with: .color(.black.opacity(0.05 + 0.08 * Double(rnd()))),
                               lineWidth: 0.8 + rnd() * 1.2)
                }
            }
            // the lamp's pool of light, slightly left of center
            RadialGradient(colors: [Color(red: 0.32, green: 0.26, blue: 0.16).opacity(0.55),
                                    .clear],
                           center: UnitPoint(x: 0.42, y: 0.32),
                           startRadius: 0, endRadius: 700)
            // room vignette
            RadialGradient(colors: [.clear, .clear, .black.opacity(0.45)],
                           center: .center, startRadius: 0, endRadius: 1100)
        }
        .ignoresSafeArea()
    }
}

/// The 1977 six-stripe apple, drawn in SwiftUI.
struct RainbowApple: View {
    static let stripes: [Color] = [
        Color(red: 0.38, green: 0.73, blue: 0.27),  // green
        Color(red: 0.99, green: 0.78, blue: 0.05),  // yellow
        Color(red: 0.96, green: 0.51, blue: 0.12),  // orange
        Color(red: 0.89, green: 0.16, blue: 0.12),  // red
        Color(red: 0.58, green: 0.22, blue: 0.56),  // purple
        Color(red: 0.00, green: 0.56, blue: 0.84),  // blue
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { i in
                Rectangle().fill(Self.stripes[i])
            }
        }
        .mask(
            Image(systemName: "applelogo")
                .resizable()
                .scaledToFit()
        )
    }
}

/// First launch: a cold open. Dark bench, one line, and a power switch.
struct WelcomeCard: View {
    let takeTour: () -> Void
    let explore: () -> Void
    var showGallery: () -> Void = {}
    var powerUp: () -> Void = {}

    var body: some View {
        ZStack {
            // a dark room, the bench barely visible beneath
            Color.black.opacity(0.88)
            VStack(spacing: 18) {
                RainbowApple()
                    .frame(width: 56, height: 64)
                    .padding(.bottom, 2)
                Text("It's 1976.")
                    .font(.system(size: 40, weight: .bold, design: .serif))
                Text("A computer is something you build.")
                    .font(.system(size: 17, design: .serif))
                    .italic()
                    .foregroundStyle(.white.opacity(0.75))
                Text("On the bench in front of you is an Apple-1 — the "
                     + "circuit board that started Apple, fifty years ago. "
                     + "No case, no keyboard, no screen. Every chip is real, "
                     + "every trace is from the original fabrication files, "
                     + "and it runs the software it ran then.")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 6)
                Button(action: powerUp) {
                    HStack(spacing: 8) {
                        Image(systemName: "power")
                        Text("Switch it on")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 4)
                }
                .keyboardShortcut(.defaultAction)
                .padding(.top, 8)
                HStack(spacing: 16) {
                    Button("Take the tour", action: takeTour)
                    Button("Just explore", action: explore)
                    Button("Real photos", action: showGallery)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
            }
            .padding(44)
            .foregroundStyle(.white)
        }
    }
}

/// The guided-tour card: replaces the info bar while a tour is running.
struct TutorialPanel: View {
    let controller: MachineController

    var body: some View {
        let _ = controller.pulseFrame
        if let index = controller.tutorialStep {
            let step = controller.tutorialSteps[index]
            let last = index == controller.tutorialSteps.count - 1
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(step.title)
                            .font(.system(size: 14, weight: .bold))
                        if controller.stepComplete && !last {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    Text(step.body)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Text("\(index + 1) of \(controller.tutorialSteps.count)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        if step.action != nil && !controller.stepComplete {
                            Button("Show me") { controller.runStepAction() }
                        }
                        Button(last ? "Done" : "Next") {
                            controller.advanceTutorial()
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(!controller.stepComplete)
                    }
                    Button("End tour") { controller.endTutorial() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.10, green: 0.16, blue: 0.22)))
            .foregroundStyle(.white)
        }
    }
}

/// Scales the fixed-coordinate board to the available space.
struct FittedBoard: View {
    let controller: MachineController
    @State private var zoom: CGFloat = 1
    @State private var zoomBase: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var panBase: CGSize = .zero

    private func resetZoom() {
        withAnimation(.easeOut(duration: 0.25)) {
            zoom = 1; zoomBase = 1; pan = .zero; panBase = .zero
        }
        controller.boardZoomed = false
    }

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / BoardView.designSize.width,
                            geo.size.height / BoardView.designSize.height)
            let board = BoardView(controller: controller)
                .scaleEffect(scale * zoom)
                .offset(pan)
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            zoom = min(5, max(1, zoomBase * value))
                            controller.boardZoomed = zoom > 1.02
                            if zoom == 1 { pan = .zero; panBase = .zero }
                        }
                        .onEnded { _ in
                            zoomBase = zoom
                            controller.boardZoomed = zoom > 1.02
                        }
                )
                .gesture(
                    DragGesture(minimumDistance: 14)
                        .onChanged { value in
                            guard zoom > 1 else { return }
                            pan = CGSize(width: panBase.width + value.translation.width,
                                         height: panBase.height + value.translation.height)
                        }
                        .onEnded { _ in panBase = pan }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        zoom = 1; zoomBase = 1; pan = .zero; panBase = .zero
                    }
                    controller.boardZoomed = false
                }
            ZStack(alignment: .bottomTrailing) {
                if zoom > 1 {
                    board.clipped()
                } else {
                    board
                }
                if zoom > 1.02 {
                    HStack(spacing: 6) {
                        IconPill(symbol: "minus.magnifyingglass",
                                 help: "Zoom out") {
                            zoom = max(1, zoom / 1.4)
                            zoomBase = zoom
                            if zoom <= 1.02 { resetZoom() }
                        }
                        Text("\(Int(zoom * 100))%")
                            .font(.system(size: 9, weight: .semibold,
                                          design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                        IconPill(symbol: "plus.magnifyingglass",
                                 help: "Zoom in") {
                            zoom = min(5, zoom * 1.4)
                            zoomBase = zoom
                        }
                        IconPill(symbol: "arrow.counterclockwise",
                                 help: "Reset zoom (or double-click the board)") {
                            resetZoom()
                        }
                    }
                    .padding(8)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .padding(10)
                }
            }
        }
    }
}

struct ShelfView: View {
    let controller: MachineController
    var collapse: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PERIPHERALS")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                CollapseButton(symbol: "chevron.left.2",
                               help: "Collapse the shelf", action: collapse)
            }
            ForEach(Peripheral.allCases) { peripheral in
                ShelfItem(peripheral: peripheral,
                          connected: controller.connected.contains(peripheral),
                          toggle: { controller.toggle(peripheral) })
                    .onHover { inside in
                        controller.hoverInfo = inside ? peripheral.blurb : nil
                        controller.highlightedPeripheral = inside ? peripheral : nil
                    }
            }
            Text("CHIPS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 6)
            ForEach(ChipGroup.allCases) { group in
                ChipShelfItem(group: group,
                              placed: controller.placed.contains(group),
                              toggle: {
                                  if controller.placed.contains(group) {
                                      controller.unplace(group)
                                  } else {
                                      controller.place(group)
                                  }
                              })
                    .onHover { inside in
                        controller.hoverInfo = inside ? group.blurb : nil
                        controller.highlightedGroup = inside ? group : nil
                    }
            }
            Spacer()
            Text("Drag each part onto its connector — or double-click it. Nothing happens until you build the machine; 1976 was like that.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.vertical, 8)
    }
}

struct ShelfItem: View {
    let peripheral: Peripheral
    let connected: Bool
    var toggle: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: peripheral.symbol)
                .font(.system(size: 20))
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(peripheral.name)
                    .font(.system(size: 12, weight: .semibold))
                Text(connected ? "Connected" : "On the shelf")
                    .font(.system(size: 10))
                    .foregroundStyle(connected ? Color.green : .secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(connected ? 0.04 : 0.10)))
        .foregroundStyle(.white.opacity(connected ? 0.45 : 0.95))
        .contentShape(Rectangle())
        .draggable(peripheral.rawValue)
        .onTapGesture(count: 2, perform: toggle)
        .opacity(connected ? 0.55 : 1)
        .help(connected ? "Double-click to disconnect" : "Drag to the board, or double-click to connect")
    }
}

/// A chip set waiting to be seated on the bare board.
struct ChipShelfItem: View {
    let group: ChipGroup
    let placed: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: group.symbol)
                .font(.system(size: 16))
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.system(size: 12, weight: .semibold))
                Text(placed ? "Seated" : "On the shelf")
                    .font(.system(size: 10))
                    .foregroundStyle(placed ? Color.green : .secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(placed ? 0.04 : 0.10)))
        .foregroundStyle(.white.opacity(placed ? 0.45 : 0.95))
        .contentShape(Rectangle())
        .draggable(group.payload)
        .onTapGesture(count: 2, perform: toggle)
        .opacity(placed ? 0.6 : 1)
        .help(placed ? "Double-click to pull it from the board"
                     : "Drag to its outline on the board, or double-click to seat it")
    }
}

/// Bottom strip: explains whatever the mouse is over, the next assembly
/// step — or, once the machine is built, rotating Apple-1 lore.
struct InfoBar: View {
    let controller: MachineController

    private static let facts: [(String, String)] = [
        ("1976", "The $666.66 price wasn't a statement — Woz just liked repeating digits. Apple got complaint letters anyway."),
        ("1976", "Paul Terrell's Byte Shop ordered 50 units — but only fully assembled. That order turned two guys in a garage into a computer company."),
        ("1976", "Jobs sold his VW Microbus and Woz his HP-65 calculator to pay for the first circuit-board run."),
        ("1976", "Apple incorporated on April 1, 1976. Third founder Ron Wayne sold his 10% back for $800 twelve days later."),
        ("1976", "Woz wrote Integer BASIC by hand on paper — he couldn't afford computer time on an assembler."),
        ("1976", "The Apple-1 debuted at the Homebrew Computer Club, and Woz handed out the schematics to anyone who asked."),
        ("1976", "A Teletype terminal cost over $1,000. Woz building a 60-character-a-second TV terminal onto the board WAS the product."),
        ("1976", "There's no power switch. Plug it in and it's on. Keyboard, TV, transformers and case were all bring-your-own."),
        ("1976", "Owners built their boards into briefcases, drawers and hand-cut wood cases — the Smithsonian's wears one."),
        ("1975", "The 6502 cost $25 when Intel's 8080 cost $179. That price difference is why hobby computers happened at all."),
        ("1976", "The board takes TWO brains: as shipped, a 6502 with the dotted box empty and two solder bridges made. A 6800 needed the box filled and the bridges broken. None ever shipped."),
        ("1976", "The Woz Monitor in the PROMs is 256 bytes — still studied as a masterpiece of tiny programming."),
        ("1976", "No lowercase: the 2513 character chip holds exactly 64 glyphs. This app renders its actual dot patterns."),
        ("1977", "Apple offered Apple-1 owners trade-in credit toward an Apple II — then scrapped the returns. A big reason only ~80 boards survive."),
        ("1980", "Four years after this board, Apple's IPO minted more instant millionaires than any company before it."),
        ("1984", "Eight years from garage board to Macintosh — same idea both times: a computer for a person, not an institution."),
        ("2014", "A working Apple-1 sold at Bonhams for $905,000. The Henry Ford Museum was the buyer."),
        ("2023", "Steve Jobs' handwritten draft of an Apple-1 ad sold at auction for $175,759 — the ad, not the computer."),
        ("2026", "Apple turned 50 on April 1, 2026. About 200 of these boards started all of it."),
    ]

    var body: some View {
        let content = content
        HStack(spacing: 10) {
            Text(content.text)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
            if content.isFact {
                Button {
                    controller.previousFact()
                } label: {
                    Image(systemName: "arrow.left.circle")
                        .font(.system(size: 16))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.55))
                .help("Previous fact")
                Button {
                    controller.nextFact()
                } label: {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 16))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.55))
                .help("Next fact")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)))
        .contentShape(Rectangle())
        .onTapGesture { if content.isFact { controller.nextFact() } }
    }

    private var content: (text: String, isFact: Bool) {
        if let hover = controller.hoverInfo { return (hover, false) }
        return nextStep
    }

    private var nextStep: (text: String, isFact: Bool) {
        if controller.looksCrashed {
            return ("The 6502 wandered into empty memory and crashed — "
                + "authentically. ⌘R is the reset switch. (Tip: RUN only "
                + "means something to BASIC; the monitor's run command is "
                + "an address followed by R, like E000R.)", false)
        }
        if controller.powered, controller.cpuVariant == .m6800 {
            return ("The 6800 configuration: clock parts installed, "
                + "bridges broken, terminal blinking — but the PROMs "
                + "hold 6502 code and no 6800 monitor was ever written. "
                + "It waits forever for software that never existed. "
                + "(Machine ▸ Processor swaps back.)", false)
        }
        if controller.reseatHintActive {
            return ("Reseated and reset — but RAM survived. If BASIC was "
                + "loaded, type E2B3R to re-enter it with your program "
                + "intact. (Real Apple-1s worked exactly this way.)", false)
        }
        if controller.typingHintActive {
            if !controller.connected.contains(.keyboard) {
                return ("You're typing, but no keyboard is connected — "
                    + "double-click its shelf icon, click any on-screen "
                    + "key, or drag it to its socket on the board.", false)
            }
            return ("You're typing, but the machine has no power — "
                + "connect the power supply first.", false)
        }
        if controller.powered, !controller.placed.contains(.cpu) {
            return ("No CPU: the board is warm but nothing is thinking. "
                + "Note the screen holds its last image — the terminal "
                + "really was independent of the 6502.", false)
        }
        if controller.powered, !controller.placed.contains(.proms) {
            return ("No PROMs: the reset vector reads as garbage and the "
                + "6502 is executing noise. Seat the Woz Monitor PROMs "
                + "and reset.", false)
        }
        if controller.powered, !controller.placed.contains(.ramW) {
            return ("No bank W RAM: zero page and the stack are gone — "
                + "the first subroutine call sent the CPU into the void.", false)
        }
        if controller.powered, !controller.placed.contains(.pia) {
            return ("No PIA: the machine is running blind and deaf — no "
                + "keys in, characters written into nowhere.", false)
        }
        if controller.powered, !controller.placed.contains(.video) {
            return ("No terminal section: the display never answers the "
                + "handshake, so the CPU is waiting forever. 1976 had no "
                + "timeout errors.", false)
        }
        if !controller.essentialsPlaced {
            return ("Empty sockets: seat the chips from the shelf into "
                + "their outlines — drag them over, or double-click.", false)
        }
        let c = controller.connected
        if controller.powered, !controller.placed.contains(.ramX) {
            return ("Running as a 4 KB machine. Seat RAM bank X (another "
                + "4 KB at $E000) to make room for BASIC — the classic "
                + "Apple-1 upgrade.", false)
        }
        if !c.contains(.power) {
            return ("Connect the power supply to bring the board to life.", false)
        }
        if !c.contains(.display) {
            return ("It's running — but you can't see anything. Connect a monitor.", false)
        }
        if !c.contains(.keyboard) {
            return ("There's the Woz Monitor prompt. Connect a keyboard to talk to it.", false)
        }
        if !c.contains(.aciCard) {
            return ("Try FF00.FFFF to read the ROM. Add the cassette interface to load BASIC (⌘B).", false)
        }
        // Fully assembled: rotate lore every 15 seconds; arrow to skip.
        let index = (controller.pulseFrame / 900 + controller.factOffset) % Self.facts.count
        let (year, fact) = Self.facts[index]
        return ("\(year) — \(fact)", true)
    }
}

/// The detached screen, dressed as the era's monitor of choice — a
/// Sanyo VM-4209: dark steel cabinet, molded face around the tube, and
/// front-panel knobs that actually work.
struct MonitorView: View {
    @Bindable var controller: MachineController

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [Color(red: 0.25, green: 0.25, blue: 0.26),
                                              Color(red: 0.12, green: 0.12, blue: 0.13)],
                                     startPoint: .top, endPoint: .bottom))
            HStack(spacing: 10) {
                // Molded face: recessed panel around the tube
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.07, green: 0.07, blue: 0.08))
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(white: 0.30), lineWidth: 1.5)
                    TubeView(controller: controller)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(14)
                }
                VStack(spacing: 14) {
                    Spacer(minLength: 8)
                    KnobView(label: "BRIGHT", value: $controller.crtBrightness)
                    KnobView(label: "CONTR", value: $controller.crtContrast)
                    KnobView(label: "V-HOLD", value: $controller.vHold)
                    Spacer(minLength: 4)
                    Button {
                        controller.monitorOn.toggle()
                        controller.sound.connectorSnap()
                    } label: {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(white: 0.2))
                            .frame(width: 18, height: 26)
                            .overlay(
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(controller.monitorOn
                                          ? Color(white: 0.65) : Color(white: 0.35))
                                    .frame(width: 12, height: 10)
                                    .offset(y: controller.monitorOn ? -6 : 6)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Monitor power")
                    Circle()
                        .fill(controller.monitorOn && controller.connected.contains(.display)
                              ? Color.red : Color(white: 0.2))
                        .frame(width: 7, height: 7)
                        .shadow(color: .red.opacity(
                            controller.monitorOn && controller.connected.contains(.display)
                            ? 0.8 : 0), radius: 4)
                    Text("SANYO")
                        .font(.system(size: 10, weight: .bold))
                        .kerning(2)
                        .foregroundStyle(.white.opacity(0.5))
                    Text("VM-4209")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.bottom, 10)
                }
                .frame(width: 66)
            }
            .padding(14)
        }
    }
}


/// The monitor's front-panel controls — knobs plus the power switch.
/// Shared by the attached CRT panel (compact) and the Monitor window.
struct MonitorControls: View {
    @Bindable var controller: MachineController
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 16 : 12) {
            KnobView(label: "BRIGHT", value: $controller.crtBrightness)
            KnobView(label: "CONTR", value: $controller.crtContrast)
            KnobView(label: "V-HOLD", value: $controller.vHold)
            VStack(spacing: 4) {
                Button {
                    controller.monitorOn.toggle()
                    controller.sound.connectorSnap()
                } label: {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(white: 0.2))
                        .frame(width: 18, height: 26)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(controller.monitorOn
                                      ? Color(white: 0.65) : Color(white: 0.35))
                                .frame(width: 12, height: 10)
                                .offset(y: controller.monitorOn ? -6 : 6)
                        )
                }
                .buttonStyle(.plain)
                .help("Monitor power")
                Text("POWER")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Circle()
                .fill(monitorLit ? Color.red : Color(white: 0.2))
                .frame(width: 7, height: 7)
                .shadow(color: .red.opacity(monitorLit ? 0.8 : 0), radius: 4)
        }
        .scaleEffect(compact ? 0.85 : 1)
    }

    private var monitorLit: Bool {
        controller.monitorOn && controller.connected.contains(.display)
    }
}

/// A front-panel knob: drag up/down to turn it.
struct KnobView: View {
    let label: String
    @Binding var value: Double
    @State private var dragBase: Double?

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(white: 0.38),
                                                  Color(white: 0.14)],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
                Circle()
                    .strokeBorder(Color(white: 0.45), lineWidth: 1)
                Rectangle()
                    .fill(Color(white: 0.8))
                    .frame(width: 2.4, height: 10)
                    .offset(y: -8)
                    .rotationEffect(.degrees(value * 135))
            }
            .frame(width: 32, height: 32)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { drag in
                        let base = dragBase ?? value
                        dragBase = base
                        value = max(-1, min(1, base - Double(drag.translation.height) / 70))
                    }
                    .onEnded { _ in dragBase = nil }
            )
            .onTapGesture(count: 2) { value = 0 } // snap back to center
            Text(label)
                .font(.system(size: 7, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
        }
        .help("Drag to turn; double-click to center")
        .accessibilityLabel("\(label) monitor knob")
        .accessibilityValue(String(format: "%.0f%%", (value + 1) * 50))
    }
}


/// A close look at the unplugged Apple Cassette Interface.
struct ACIInspectView: View {
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("APPLE CASSETTE INTERFACE — $75 (1976)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [
                        Color(red: 0.21, green: 0.33, blue: 0.24),
                        Color(red: 0.15, green: 0.26, blue: 0.18)],
                        startPoint: .top, endPoint: .bottom))
                if let url = Bundle.module.url(forResource: "aci-copper",
                                               withExtension: "png",
                                               subdirectory: "Resources"),
                   let image = NSImage(contentsOf: url) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                }
            }
            .aspectRatio(1.94, contentMode: .fit)
            .frame(maxWidth: 560)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 8)
            HStack(spacing: 18) {
                Label("gold edge fingers → expansion slot",
                      systemImage: "arrow.down")
                Label("tape jacks wire to EAR/MIC", systemImage: "circle.grid.2x1")
            }
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.secondary)
            Text("Rendered from the card's actual copper artwork — "
                 + "\"APPLE 1 CASSETTE INTERFACE\" is etched in the "
                 + "traces. Two tone frequencies, one earphone jack, one "
                 + "mic jack, and the whole 1976 storage industry.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
            Button("Done", action: dismiss).keyboardShortcut(.defaultAction)
        }
        .padding(22)
    }
}
