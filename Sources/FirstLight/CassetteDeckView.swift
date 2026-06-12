import SwiftUI

/// The tape player under the screen: cassette door up top, a row of
/// mechanical piano keys below. PLAY sits depressed while a tape loads.
struct TapeDeckBar: View {
    let controller: MachineController
    @State private var showChooser = false

    var body: some View {
        let loading = controller.nowLoading != nil
        let progress = loading ? controller.loadProgress : 1
        let spin = loading ? Double(controller.frame) * 6 : 0
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                // cassette door
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.black.opacity(0.6))
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(Color(white: 0.38), lineWidth: 1)
                    if let name = controller.insertedTapeName {
                        cassette(name: name, progress: progress, spin: spin)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Text("NO CASSETTE")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                    LinearGradient(colors: [.white.opacity(0.07), .clear],
                                   startPoint: .topLeading, endPoint: .center)
                        .allowsHitTesting(false)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .frame(height: 148)
                // side column: counter, lamp, badge
                VStack(spacing: 8) {
                    HStack(spacing: 1) {
                        let digits = String(format: "%03d", controller.tapeCounter % 1000)
                        ForEach(Array(digits.enumerated()), id: \.offset) { _, d in
                            Text(String(d))
                                .font(.system(size: 11, weight: .bold,
                                              design: .monospaced))
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(width: 12, height: 17)
                                .background(Rectangle().fill(Color.black))
                        }
                    }
                    .overlay(Rectangle().strokeBorder(Color(white: 0.4),
                                                      lineWidth: 1))
                    Circle()
                        .fill(loading ? Color.orange : Color(white: 0.25))
                        .frame(width: 7, height: 7)
                        .shadow(color: .orange.opacity(loading ? 0.8 : 0), radius: 3)
                    if loading {
                        Text("\(Int(controller.loadProgress * 100))%")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(.orange.opacity(0.85))
                    }
                    Spacer()
                    VStack(spacing: 2.5) { // speaker grille
                        ForEach(0..<6, id: \.self) { _ in
                            Capsule().fill(Color.black.opacity(0.7))
                                .frame(height: 2.5)
                                .overlay(Capsule()
                                    .strokeBorder(Color(white: 0.4).opacity(0.5),
                                                  lineWidth: 0.4))
                        }
                    }
                    .frame(width: 34)
                    Text("SOLID STATE")
                        .font(.system(size: 5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(width: 44, height: 148)
            }
            // piano keys: equal flexible widths — they always fit
            HStack(spacing: 2.5) {
                key("REW", enabled: !loading) { controller.rewindTape() }
                key("PLAY", pressed: loading,
                    enabled: controller.insertedTapeName != nil && !loading) {
                    controller.playInsertedTape()
                }
                key("F.F", enabled: !loading) { controller.fastForwardTape() }
                key("STOP", enabled: loading) { controller.stopTape() }
                key("EJECT", enabled: controller.insertedTapeName != nil && !loading) {
                    controller.ejectTape()
                }
                key("REC", enabled: controller.powered && !loading) {
                    controller.recordRequested = true
                }
            }
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 9)
            .fill(LinearGradient(colors: [Color(white: 0.20), Color(white: 0.09)],
                                 startPoint: .top, endPoint: .bottom)))
        .overlay(RoundedRectangle(cornerRadius: 9)
            .strokeBorder(LinearGradient(colors: [Color(white: 0.95),
                                                  Color(white: 0.45)],
                                         startPoint: .top, endPoint: .bottom),
                          lineWidth: 1.5))
        .frame(minWidth: 330, maxWidth: 470)
        .animation(.spring(response: 0.4, dampingFraction: 0.8),
                   value: controller.insertedTapeName != nil)
        .onTapGesture(count: 2) { showChooser = true }
        .contextMenu {
            ForEach(TapeLibrary.tapes) { tape in
                Button(tape.name) { controller.insert(tape) }
            }
            Divider()
            Button("Load Custom Cassette…") {
                controller.customTapeRequested = true
            }
        }
        .popover(isPresented: $showChooser, arrowEdge: .top) {
            TapeChooser(controller: controller, dismiss: { showChooser = false })
        }
        .help("Double-click to pick a cassette")
    }

    @ViewBuilder
    private func cassette(name: String, progress: Double, spin: Double) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(LinearGradient(colors: [Color(white: 0.20),
                                              Color(white: 0.11)],
                                     startPoint: .top, endPoint: .bottom))
            VStack(spacing: 3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(red: 0.91, green: 0.88, blue: 0.80))
                    Text(name.uppercased())
                        .font(.system(size: 12, weight: .bold,
                                      design: .monospaced))
                        .foregroundStyle(.black.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 6)
                }
                .frame(height: 26)
                .padding(.horizontal, 10)
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.black.opacity(0.55))
                        .frame(width: 142, height: 52)
                    HStack(spacing: 36) {
                        reel(packRadius: 22 - 10 * progress, spin: spin)
                        reel(packRadius: 12 + 10 * progress, spin: spin)
                    }
                    Rectangle()
                        .fill(Color(red: 0.45, green: 0.30, blue: 0.16))
                        .frame(width: 26, height: 2.4)
                }
            }
            .padding(.vertical, 7)
        }
        .frame(width: 205, height: 128)
        .overlay {
            ForEach(0..<4, id: \.self) { i in
                Circle().fill(Color(white: 0.33))
                    .frame(width: 4, height: 4)
                    .offset(x: i % 2 == 0 ? -91 : 91,
                            y: i < 2 ? -52 : 52)
            }
        }
    }

    private func key(_ label: String, pressed: Bool = false,
                     enabled: Bool = true,
                     action: @escaping () -> Void = {}) -> some View {
        Button(action: action) {
            VStack(spacing: 1.5) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(white: pressed ? 0.30 : 0.45))
                    .frame(height: 2)
                Text(label)
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(.vertical, pressed ? 8 : 6)
            .frame(maxWidth: .infinity) // share the row, never overflow
            .background(RoundedRectangle(cornerRadius: 2.5)
                .fill(LinearGradient(colors: pressed
                    ? [Color(white: 0.12), Color(white: 0.18)]
                    : [Color(white: 0.30), Color(white: 0.16)],
                    startPoint: .top, endPoint: .bottom)))
            .offset(y: pressed ? 1.5 : 0)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled || pressed ? 1 : 0.75)
        .accessibilityLabel("\(label) tape deck key")
    }

    private func reel(packRadius: CGFloat, spin: Double) -> some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.35, green: 0.23, blue: 0.12))
                .frame(width: packRadius * 2, height: packRadius * 2)
            Circle()
                .fill(Color(white: 0.85))
                .frame(width: 12, height: 12)
            ForEach(0..<6, id: \.self) { i in
                Rectangle()
                    .fill(Color(white: 0.4))
                    .frame(width: 1.6, height: 5)
                    .offset(y: -5.2)
                    .rotationEffect(.degrees(Double(i) * 60 + spin))
            }
        }
        .frame(width: 40, height: 40)
    }
}


/// Transient load indicator for when the deck isn't on screen (e.g. the
/// monitor is detached): appears during a load, then vanishes.
struct TapeLoadingToast: View {
    let controller: MachineController

    var body: some View {
        if let name = controller.nowLoading {
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.35, green: 0.23, blue: 0.12))
                        .frame(width: 16, height: 16)
                    ForEach(0..<3, id: \.self) { i in
                        Rectangle()
                            .fill(Color(white: 0.8))
                            .frame(width: 1.4, height: 5)
                            .offset(y: -3)
                            .rotationEffect(.degrees(Double(i) * 120
                                + Double(controller.frame) * 6))
                    }
                }
                Text("LOADING \(name.uppercased())  \(Int(controller.loadProgress * 100))%")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.black.opacity(0.75)))
            .overlay(Capsule().strokeBorder(Color(white: 0.35), lineWidth: 1))
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.35, dampingFraction: 0.8),
                       value: controller.nowLoading != nil)
        }
    }
}


/// The shoebox of tapes: double-clicking the deck opens this.
struct TapeChooser: View {
    let controller: MachineController
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CASSETTE LIBRARY")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                    ForEach(TapeLibrary.tapes.filter { !$0.homebrew }) { tape in
                        TapeRow(tape: tape) {
                            dismiss()
                            controller.insert(tape)
                        }
                    }
                    Divider().padding(.vertical, 4)
                    Text("HOMEBREW")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                    ForEach(TapeLibrary.tapes.filter(\.homebrew)) { tape in
                        TapeRow(tape: tape) {
                            dismiss()
                            controller.insert(tape)
                        }
                    }
                }
            }
            .frame(maxHeight: 400) // scrolls on small screens
            Divider().padding(.vertical, 4)
            Button {
                dismiss()
                controller.customTapeRequested = true
            } label: {
                Label("Load Custom Cassette…", systemImage: "folder")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .padding(.vertical, 3)
        }
        .padding(14)
        .frame(width: 290)
    }
}

/// One tape in the chooser — highlights under the mouse.
private struct TapeRow: View {
    let tape: Tape
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 1) {
                Text(tape.name)
                    .font(.system(size: 11, weight: .semibold))
                Text(tape.blurb)
                    .font(.system(size: 9))
                    .foregroundStyle(hovered ? .primary : .secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(RoundedRectangle(cornerRadius: 5)
                .fill(hovered ? Color.accentColor.opacity(0.22) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

/// P1: the record dialog — pick a range, get a cassette.
struct RecordTapeView: View {
    let controller: MachineController
    let dismiss: () -> Void
    @State private var name = "MY TAPE"
    @State private var preset = 0
    @State private var fromHex = "0000"
    @State private var toHex = "0FFF"

    private static let presets: [(String, Int, Int)] = [
        ("RAM bank W — your wozmon work ($0000-$0FFF)", 0x0000, 0x0FFF),
        ("Your BASIC program — the real two-range tape ($4A-$FF + $300-$FFF)",
         -1, -1),
        ("Custom range", 0, 0),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("RECORD TO CASSETTE")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
            TextField("Tape label", text: $name)
                .textFieldStyle(.roundedBorder)
            Picker("Range", selection: $preset) {
                ForEach(0..<Self.presets.count, id: \.self) { i in
                    Text(Self.presets[i].0).tag(i)
                }
            }
            .pickerStyle(.radioGroup)
            if preset == 2 {
                HStack {
                    TextField("From (hex)", text: $fromHex)
                    TextField("To (hex)", text: $toHex)
                }
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            }
            Text("Saves a wozmon-format .txt (reloads via Load Custom "
                 + "Cassette) and a bit-true .wav — the actual ACI tones, "
                 + "playable to a real Apple-1.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel", action: dismiss)
                    .keyboardShortcut(.cancelAction)
                Button("Record") {
                    dismiss()
                    if preset == 1 {
                        // authentic BASIC tape: zero-page pointers plus
                        // the program, which lives in BANK W ($300+)
                        controller.recordTape(name: name, ranges:
                            [(0x004A, 0x00FF), (0x0300, 0x0FFF)])
                    } else if preset == 2 {
                        controller.recordTape(name: name,
                            from: Int(fromHex, radix: 16) ?? 0,
                            to: Int(toHex, radix: 16) ?? 0xFFF)
                    } else {
                        controller.recordTape(name: name,
                            from: Self.presets[preset].1,
                            to: Self.presets[preset].2)
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
