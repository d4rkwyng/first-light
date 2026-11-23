# Changelog

User-facing changes to First Light. The release workflow copies the
matching `## [X.Y.Z]` section into the draft release notes.

## [1.0.1] - 2026-11-23

### Changed

- New app icon: the Woz Monitor's `\` prompt and the Apple-1's `@` cursor in Signetics 2513 ROM glyphs, on a dark CRT in a PCB-green squircle.

### Fixed

- Decimal-mode ADC and SBC store a real BCD result. Lunar Lander no longer prints heights like `05B0`. On the NMOS 6502 those instructions take the same number of cycles as in binary mode.
- RESET sets the interrupt-disable flag and clears decimal mode, so `SED` does not stay in effect across a reset.
- The Woz Monitor ROM stays intact. Tape loads, deposits, and snapshot restores no longer overwrite `$FF00`–`$FFFF`, and a deposit that runs past the top of memory is dropped instead of crashing the app.
- With the PIA pulled, writes to its registers do nothing, so a reset no longer prints the monitor prompt on a blind board. The Scope's bus peek matches what the CPU reads when the data-direction register is selected.
- The info bar's previous-fact arrow wraps. Clicking it in the first 15 seconds no longer crashes the app.
- Keys typed into a text field (the Scope address field, the command palette, the Record sheet) or a modal dialog stay there instead of going to the Apple-1, and held keys repeat. Keys that go to the Apple-1 still do not auto-repeat, like the Datanetics keyboard.
- Custom tapes are capped at 64 KB, with an alert that names the file and its size, and an unreadable file now says so instead of doing nothing. Recordings longer than 10 minutes are rejected, stereo recordings decode, and decoding and cassette audio run off the main thread.
- STOP, EJECT, Reset, snapshot restore, power-off, inserting another tape, an authentic ACI load, and ⌘B cancel a recording that is still decoding, and the cancelled decode and audio render actually stop. The deck's STOP button is live during that decode.
- Saving a recording reports a failed write instead of acting as if it worked. The BASIC preset no longer promises a `.wav` it does not write.
- A custom tape is deposited at `$0300` unless the filename contains `@ADDR`. `2048.bin` is no longer loaded at `$2048`.
- The machine, the cursor, and the deck counter keep running while a menu is open or a window or knob is dragged, so tape audio stays in step with the load.
- Restoring a snapshot cancels a tape that was loading, instead of letting that load overwrite the restored machine.
- An authentic tape load is no longer reported as "the 6502 wandered into empty memory and crashed."
- If the audio engine cannot start, the app no longer calls `play()` on it. That exception used to quit First Light on the first key click.
- VoiceOver can read the Apple-1 screen: the visible text and the cursor position.
- The About panel shows credits and a clickable link to the repository, with the version number only (no repeated build number). The Help menu adds **First Light on GitHub** and **Report an Issue…**.
- Four tapes that shipped broken in 1.0.0 run again: Hamurabi and Mini-Startrek (restored code that had been stripped from the listings), APPLE 50TH (no more `SYNTAX ERR` in the picture), and Life (now the tape that came with the Apple-1, loaded at `$0280`).

### For packagers and builders

- `Scripts/build-app.sh` and `Scripts/test.sh` work again with Command Line Tools only, no Xcode, on the Swift 6.4 / macOS 27 SDK toolchain.
- `Scripts/build-app.sh --release` verifies the signature and exits with an error if Gatekeeper rejects the bundle.
- Notarized releases are built by a GitHub Actions workflow; see [RELEASING.md](RELEASING.md).

## [1.0.0]

Initial notarized release for Apple silicon, macOS 15 and later.
