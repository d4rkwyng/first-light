import SwiftUI

/// T3: the quick-reference card — wozmon and Integer BASIC on one
/// period-styled sheet. ⌘/ or Machine ▸ Quick Reference.
struct ReferenceView: View {
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("APPLE-1 OPERATION — QUICK REFERENCE")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                Spacer()
                Button("Done", action: dismiss)
                    .keyboardShortcut(.defaultAction)
            }
            HStack(alignment: .top, spacing: 22) {
                section("WOZ MONITOR  (the \\ prompt)", [
                    ("FF00", "show the byte at $FF00"),
                    ("FF00.FF1F", "show a range"),
                    ("0:A9 8D 20", "deposit bytes at $0"),
                    ("300R", "run from $0300"),
                    ("E000R", "cold-start BASIC"),
                    ("E2B3R", "re-enter BASIC (keeps program)"),
                    ("ESC", "cancel the line"),
                    ("⌘R", "reset (the only panic button)"),
                ])
                section("INTEGER BASIC  (the > prompt)", [
                    ("10 PRINT \"HI\"", "numbered lines are stored"),
                    ("LIST", "show the program"),
                    ("RUN", "run it"),
                    ("PRINT 2+2", "immediate mode"),
                    ("INPUT X", "read a number"),
                    ("IF X>5 THEN 99", "branch"),
                    ("FOR I=1 TO 9 … NEXT I", "loop"),
                    ("GOSUB / RETURN", "subroutines"),
                    ("PEEK(0) / POKE 0,255", "touch memory"),
                    ("ABS RND SGN", "the whole math library"),
                ])
            }
            Text("Uppercase only. Delete prints _ (the screen can't erase — "
                 + "the machine forgets the character anyway). The display "
                 + "draws 60 characters a second and nothing can hurry it.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(width: 640)
        .background(Color(red: 0.93, green: 0.90, blue: 0.82))
        .foregroundStyle(Color(red: 0.15, green: 0.13, blue: 0.10))
    }

    private func section(_ title: String,
                         _ rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.bottom, 2)
            ForEach(0..<rows.count, id: \.self) { i in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(rows[i].0)
                        .font(.system(size: 11, weight: .semibold,
                                      design: .monospaced))
                        .frame(width: 150, alignment: .leading)
                    Text(rows[i].1)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
