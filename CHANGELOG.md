# Changelog

User-facing changes to First Light. The release workflow copies the
matching `## [X.Y.Z]` section into the draft release notes.

## [1.0.2] - 2026-11-23

### Fixed

- First Light 1.0.0 and 1.0.1 crashed at launch on every Mac except the one that built them. The app now loads its ROMs, tapes, board art, and CRT shader from inside the app (`Contents/Resources`), so it starts on any Mac.

### For packagers and builders

- Before uploading, the release workflow now launches the notarized app and checks that both of its resource bundles load, with the build machine's copies of those bundles hidden. A build that would crash like 1.0.0 and 1.0.1 fails the release instead of shipping. See [RELEASING.md](RELEASING.md).

## [1.0.1] - 2026-11-23

### Changed

- New app icon: the Woz Monitor's `\` prompt and the Apple-1's `@` cursor in Signetics 2513 ROM glyphs, on a dark CRT in a PCB-green squircle.
- Smaller download: the notarized zip is about 4.9 MB, down from about 6.9 MB for 1.0.0, mostly because the new icon is smaller and a release build no longer has a Finder icon stamped on it after signing.
- The quick reference no longer says nothing can hurry the 60-characters-a-second display. At the authentic clock it holds at 60; only the Turbo speeds in the Machine menu hurry it.

### Fixed

- Decimal-mode ADC and SBC store a real BCD result. Lunar Lander no longer prints heights like `05B0`. On the NMOS 6502 those instructions take the same number of cycles as in binary mode.
- RESET sets the interrupt-disable flag and clears decimal mode, so `SED` does not stay in effect across a reset.
- The Woz Monitor ROM stays intact. Tape loads, deposits, and snapshot restores no longer overwrite `$FF00`–`$FFFF`, and a deposit that runs past the top of memory is dropped instead of crashing the app.
- With the PIA pulled, writes to its registers do nothing, so a reset no longer prints the monitor prompt on a blind board. The Scope's bus peek matches what the CPU reads when the data-direction register is selected.
- The info bar's previous-fact arrow wraps. Clicking it in the first 15 seconds no longer crashes the app.
- Keys typed into a text field (the Scope address field, the command palette, the Record sheet) or a modal dialog stay there instead of going to the Apple-1, and held keys repeat. Keys that go to the Apple-1 still do not auto-repeat, like the Datanetics keyboard.
- A custom tape that can't be loaded shows a **Can't load that tape** alert naming the file, instead of doing nothing: a file that couldn't be read, a recording with no Apple-1 tape data in it ("No Apple-1 tape data was found"), a recording longer than 10 minutes, or a tape over 64 KB (the alert gives its size). A `.txt` that isn't UTF-8 text is still ignored without an alert.
- Stereo recordings decode: the decoder reads channel 0 of the file's own format. Decoding and cassette audio run off the main thread. Load Custom Cassette… decodes `.wav`, `.aif`, `.aiff`, `.mp3`, and `.m4a` recordings, as in 1.0.0, and still takes a `.bin`, a wozmon-format `.txt`, or a BASIC-source `.txt`.
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
- 1.0.1 is the first release built, signed, and notarized by GitHub Actions; 1.0.0 predates the workflow. See [RELEASING.md](RELEASING.md).
- `Scripts/build-app.sh --release` no longer stamps a Finder icon on the bundle after signing, so the signed app passes `codesign --verify --strict`. Dev builds still get the stamp; the release app's icon comes from `CFBundleIconFile`.

## [1.0.0] - 2026-07-06

Initial notarized release for Apple silicon, macOS 15 and later.
