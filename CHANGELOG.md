# Changelog

User-facing changes to First Light. The release workflow copies the
matching `## [X.Y.Z]` section into the draft release notes.

## [1.0.1] — Unreleased

### Changed

- New app icon: the Apple-1's `@` prompt in Signetics 2513 ROM glyphs, on a dark CRT in a PCB-green squircle.

### Fixed

- Decimal-mode ADC and SBC store a real BCD result. Lunar Lander no longer prints heights like `05B0`. On the NMOS 6502 those instructions take the same number of cycles as in binary mode.
- RESET sets the interrupt-disable flag and clears decimal mode, so `SED` does not stay in effect across a reset.
- The Woz Monitor ROM is write-protected. Loads, deposits, and snapshot restores no longer overwrite `$FF00`–`$FFFF`, and a deposit that runs past `$FFFF` is dropped instead of crashing the app.
- With the PIA pulled, writes to its registers do nothing, so a reset no longer prints the monitor prompt on a blind board. The Scope's bus peek matches what the CPU reads when the data-direction register is selected.
- The info bar's previous-fact arrow wraps. Clicking it in the first 15 seconds no longer traps on a negative index.
- Typing in a text field (the Scope address field) or an AppKit modal stays there, and those keys repeat. The on-screen Datanetics keyboard still does not auto-repeat.
- Custom tapes are capped at 64 KB, with an alert that names the file. Decoding and cassette audio are built off the main thread, and recordings longer than 10 minutes are rejected.
- STOP, Reset, snapshot restore, power-off, an authentic ACI load, and ⌘B cancel a recording that is still decoding, and the cancelled decode and audio render actually stop. The deck's STOP button is live during that decode.
- Saving a recording reports a failed write instead of acting as if it worked. The BASIC preset no longer promises a `.wav` it does not write.
- A custom tape is deposited at `$0300` unless the filename contains `@ADDR`. `2048.bin` is no longer loaded at `$2048`.
- The machine, the cursor, and the deck counter keep running while a menu is open or a window is dragged, so tape audio stays in step with the load.
- Restoring a snapshot cancels a tape that was loading, instead of letting that load overwrite the restored machine.
- An authentic tape load is no longer reported as "the 6502 wandered into empty memory and crashed."
- If the audio engine cannot start, the app no longer calls `play()` on it. That exception used to quit First Light on the first key click.
- VoiceOver can read the Apple-1 screen: the visible text and the cursor position.
- The About panel shows credits and a link to the repository, on the main thread, with the marketing version only. The Help menu links to the repository and to a new issue.
- Four tapes that shipped broken in 1.0.0 run again: Hamurabi, Mini-Startrek, APPLE 50TH, and Life (the Apple-1 Life recording, loaded at `$0280`).

## [1.0.0]

Initial notarized release for Apple silicon, macOS 15 and later.
