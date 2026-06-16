import SwiftUI

/// T4: the modern bridge to 1976 syntax. ⌘K opens a palette of plain-
/// English intents; choosing one types the correct wozmon/BASIC
/// commands into the machine — visibly, so you learn them.
struct PaletteAction: Identifiable {
    let title: String
    let detail: String
    let perform: @MainActor (MachineController) -> Void
    var id: String { title }
}

@MainActor
enum Palette {
    static let actions: [PaletteAction] = [
        PaletteAction(title: "Show the Woz Monitor's own code",
                      detail: "FF00.FFFF — the whole 256-byte OS, in hex") {
            $0.connectEverything(); $0.autoType("FF00.FFFF\n")
        },
        PaletteAction(title: "Show zero page",
                      detail: "0.FF — the 6502's favorite 256 bytes") {
            $0.connectEverything(); $0.autoType("0.FF\n")
        },
        PaletteAction(title: "Read the reset vector",
                      detail: "FFFC.FFFD — where the CPU looks first") {
            $0.connectEverything(); $0.autoType("FFFC.FFFD\n")
        },
        PaletteAction(title: "Print the character set forever",
                      detail: "deposit a tiny machine-code loop, then run it") {
            $0.connectEverything()
            $0.autoType("0:A9 0 AA 20 EF FF E8 8A 4C 2 0\n0R\n")
        },
        PaletteAction(title: "Cold-start BASIC",
                      detail: "load the BASIC tape and jump to $E000") {
            $0.connectEverything(); $0.loadBASIC()
        },
        PaletteAction(title: "Re-enter BASIC without losing the program",
                      detail: "E2B3R — the warm entry point") {
            $0.connectEverything(); $0.autoType("E2B3R\n")
        },
        PaletteAction(title: "Type the classic two-liner",
                      detail: "10 PRINT … 20 GOTO 10 … RUN") {
            $0.connectEverything()
            $0.autoType("10 PRINT \"HELLO FROM 1976\"\n20 GOTO 10\nRUN\n")
        },
        PaletteAction(title: "List the BASIC program",
                      detail: "LIST at the > prompt") {
            $0.autoType("LIST\n")
        },
        PaletteAction(title: "Reset the machine",
                      detail: "the panic button (⌘R)") {
            $0.reset()
        },
    ]
}

struct CommandPaletteView: View {
    let controller: MachineController
    let dismiss: () -> Void
    @State private var query = ""

    private var filtered: [PaletteAction] {
        guard !query.isEmpty else { return Palette.actions }
        return Palette.actions.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.detail.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("What do you want the Apple-1 to do?", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                Button(action: dismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction) // ESC closes
            }
            .padding(12)
            Divider()
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(filtered) { action in
                        PaletteRow(action: action) {
                            dismiss()
                            controller.ensure6502() // palette commands are 6502 syntax
                            action.perform(controller)
                        }
                    }
                }
                .padding(6)
            }
            .frame(maxHeight: 320)
        }
        .frame(width: 470)
        .background(.regularMaterial)
        .onExitCommand(perform: dismiss)
    }
}

private struct PaletteRow: View {
    let action: PaletteAction
    let select: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 1) {
                Text(action.title).font(.system(size: 12, weight: .medium))
                Text(action.detail)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .padding(.horizontal, 9)
            .background(RoundedRectangle(cornerRadius: 6)
                .fill(hovered ? Color.accentColor.opacity(0.25) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}
