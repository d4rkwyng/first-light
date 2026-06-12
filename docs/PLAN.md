# First Light — an Apple-1 for Apple's 50th

A native Mac app (Swift/SwiftUI, Metal later) that shows a living Apple-1:
the board with every chip visible and explained, a CRT next to it, peripherals
you drag onto the machine, and guided demos of what $666.66 bought in 1976.
Fully functional emulation underneath. Planned to reach iPad and visionOS.

## Why this project (research summary, June 2026)

Nobody has combined these; each piece exists separately:
- Visible-chips board diagram: apple1registry.com/interactive (static, no emulation)
- Drag-drop peripherals onto live emulation: OpenEmulator (list UI, no board art)
- 3D showcase + real emulator: Virtual Beeb (BBC Micro), Breadbox (Commodore)
- One-click era demos: apple1software.com

Nothing like this shipped for the 50th anniversary (April 1, 2026). CHM's
"Apple at 50" exhibit runs through Sept 7, 2026.

## Architecture

- `CFake6502` — Mike Chambers' fake6502 v1.1 (public domain), BCD enabled.
  Global CPU state → exactly one machine instance at a time.
- `Apple1Core` — pure model, no UI: memory map, PIA 6820 (with DDR/port
  select on CR bit 2), Terminal (40×24, 6-bit glyph truncation, 60 cps
  governor at 17,050 cycles/frame), bundled ROMs. Portable to iPad/visionOS.
- `FirstLight` — SwiftUI app. 60 Hz timer drives the machine in real time.

## Milestones

1. **DONE — Working core.** Wozmon boots, examine/deposit/run work, Integer
   BASIC runs programs, display governor verified. 7 tests green.
2. **DONE (minimal) — Terminal app.** Green-phosphor 40×24 CRT view, blinking
   @ cursor, live keyboard, Machine menu (Reset ⌘R, Load BASIC ⌘B).
3. **DONE — The living board.** Stylized vector board (not photoreal, per
   owner): chips drawn/labeled, copper traces + vias + gold edge fingers,
   white silkscreen section boxes, APPLE COMPUTER 1 serif silkscreen.
   Hover → plain-English info bar (collapsible chevron when idle). Chips
   glow with real bus activity (Activity counters in Apple1Core; PIA
   counts real I/O events, not idle polling).
   References for accuracy passes: apple1registry.com photos, Wikimedia
   Commons hi-res shots (CC), archive.org/details/Apple1Schematic1976,
   XS-Computer-One layout diagram, Mimeo-1 docs (willegal.net).
4. **DONE — Drag-drop assembly.** Shelf: power, keyboard, monitor, ACI
   card. Drag to POWER/KEYBOARD/VIDEO/EXPANSION ports; machine only runs
   with power, CRT dark without monitor, keys ignored without keyboard,
   ⌘B (BASIC) needs the ACI. Double-click a port to disconnect. ⌘K
   connects everything. GOTCHA: interaction modifiers must be applied
   BEFORE .position() — after, each port is a board-sized layer and the
   topmost swallows all drags/clicks (this bug shipped once).
5. **DONE (v1: tutorial) — Guided experience.** 9-step tour (Tutorial.swift):
   1976 intro → power → monitor → keyboard → hex examine → machine-code
   program → ACI/BASIC load → 10 PRINT/GOTO → outro. First-launch welcome
   (AppStorage "tourOffered"), ⌘T restarts, per-step "Show me" auto-types
   at 20 cps (user keys swallowed while auto-typing), completion checked
   against transcript-since-step-start. Still to add: era software demos
   (Lunar Lander etc.) with real FSK cassette audio, original "APPLE 50TH"
   ASCII demo in the spirit of APPLE 30TH (Software/apple30.bin).
UX learned from live testing (2026-06-09): green PCB per owner; shelf,
board and info bar all collapsible (board collapsed = big-screen terminal
mode); crash detector (pc < $E000 + no video output for 2s → info-bar hint
explaining ⌘R; typing RUN at wozmon jumps into garbage = authentic crash);
Delete = "_" rubout, taught in tutorial step 4; user keys swallowed during
tutorial auto-typing; double-click (not click) disconnects a port.

Also shipped same day, from owner feedback:
- CRT text rendered from the REAL 2513 character ROM (P-LAB dump, CC BY 4.0,
  charrom2513.bin: 8 bytes/char ASCII-indexed, low 5 bits, bit4=left);
  redraws gated on Terminal.revision so the canvas isn't repainted at 60 Hz.
- Chips are pullable/seatable: ChipGroup (cpu/pia/ramW/ramX/proms/video),
  double-click pulls, drag or double-click from shelf reseats; machine
  needs all essentials; bank X ($E000) is the optional period RAM upgrade
  (Apple1.ramXInstalled gates the bus; BASIC needs it). Default = fully
  assembled, as Byte Shop units were sold (Terrell refused kits).
- Board redrawn against real photos (CHM/Wikimedia): white-ceramic gold-lid
  6502, cylinder electrolytics, right-edge expansion slot + gold fingers,
  small left-edge silkscreen, grid letters/numbers, support-TTL rows,
  channel-routed traces with vias and sprinkled ceramic caps.
- Realism iteration loop (screenshot → compare to photo → adjust, 2026-06):
  brighter photo-matched palette, wavy sine-meander trace layer (the real
  board's dominant texture), pin-leg ticks on every DIP, WHITE ceramic
  DRAMs/PROMs (unmistakable in the photo), tan resistors, finned heatsink,
  horizontal Sprague caps, rows trimmed so the power corner stays clear.
- Second photo-matching pass against "Apple 1 Woz 1976 at CHM.agr cropped"
  (straight-on, Woz's unit): TRUE row structure — four full-width rows
  D/C/B/A top-to-bottom, PIA + white 6502 + PROMs bottom-LEFT, sixteen
  DRAMs in two rows bottom-RIGHT, regulator heatsink plate + two
  HORIZONTAL Sprague caps top-right + two at right edge, silkscreen
  between rows C and B, numbers 1-18, keyboard header bottom-left,
  1000×600 design (1.67 aspect), solder-pad dot rows under every chip
  row, no section boxes (real board has none — zones dash only when a
  chip set is missing).
- Programs menu (Programs.swift): period-faithful demos that auto-type
  (charset machine code, squares, star triangle, guess-a-number w/ INPUT,
  F→C table). ⌘V pastes clipboard as keystrokes.
- Rotating "1976 FACT" lore in the idle info bar; welcome card with the
  CC-BY-SA Smithsonian photo (Ed Uthman), reachable via Machine▸Welcome….
- Tour: starts assembled, "Meet the hardware" step teaches hover/pull;
  every "Show me" is self-sufficient (placeAll + connects); generous step
  completions so early ⌘R can't strand the user.

## Fidelity & Delight plan (2026-06-10, owner direction)

The board is now rendered from the REAL fabrication files (gerber copper +
silkscreen + ACI card copper). Next wave, in priority order:

F1. **Footprint-exact components.** Extend the gerber toolchain
    (/tmp/gerb2svg.py, copy into Tools/) to extract component outlines
    from the silk layer (cluster the outline segments into rects), emit
    `BoardFootprints.swift`: designator → frame in design coords. Chips
    then take exact position AND size from the real footprints (DIP-14
    vs -16 vs -40 become real sizes; PinTicks count from footprint length).
    Passives (ceramics, resistors, diodes) move from procedural scatter
    to their true silk locations. Acceptance: overlay screenshot where
    every drawn part covers its silk outline exactly.

F2. **Authentic copper colors.** Original boards were solder-coated
    (HASL): traces read pale silvery-green under the mask, pads bright
    tin. Two-tone re-emit: segments #8FAE92, flashes/pads #C9CFC4.
    (DONE same day — see below.)

F3. **Signal-transit highlighting (showcase feature).** We know every
    segment's WIDTH from the gerbers: the wide apertures are the power
    distribution — extract "power net" into its own layer and light it
    when the power supply connects. Approximate the data/address bus as
    the corridor of thin traces between 6502/PIA/PROM/RAM footprints;
    pulse that layer with the existing Activity counters (the same data
    driving chip glow). Render = extra tinted PNGs overlaid with
    animated opacity; "flow" effect via an animated gradient mask.

F4. **Animations.**
    - Power-on theater: board layers fade up, caps/regulator warm,
      CRT does a phosphor warm-up bloom before the prompt appears.
    - Chip seating: drop-in with a small settle bounce (+ click sound).
    - Trace flow shimmer on the F3 layers (gradient mask sweep).
    - CRT: subtle scanline sweep + phosphor persistence on new chars.
    - Drop-zone breathing while dragging.
    Constraint: keep 60 fps budget; prefer opacity/mask animation over
    per-frame Canvas redraws.

F5. **Sound.** Power hum, keyboard click, ACI FSK tones during ⌘B load
    (ties into the existing cassette-audio roadmap item).

F6. **Board zoom & pan.** Scroll/pinch-to-zoom with drag-pan on the
    board — the gerber layers are rendered at 2400px so real silk
    designators and copper detail are crisp under magnification.
    Double-tap to reset.

F7. **Detachable screen window.** A second SwiftUI Window scene showing
    just CRTView, openable from the Machine menu — big terminal on a
    second display while the board stays interactive in the main window.

F8. **Automated placement audit.** Finish Tools/audit (replicate the
    runtime snap over ALL seeds incl. loop-generated rows) so every
    chip↔footprint pairing is machine-verified per build, not spot-
    checked via the ⌥⌘A overlay.

6. **Polish.** Metal CRT shader (phosphor glow, scanlines, curvature),
   idle-CPU reduction (60 Hz full redraw of board+CRT costs ~45% of a core
   — throttle board redraw / draw only on change),
   2513 character ROM font (render glyphs from the Signetics datasheet),
   cassette audio (AVFoundation; stretch: load from the mic like a real ACI),
   1976 story layer, free-play mode.
7. **Later.** iPad target (needs Xcode), visionOS life-size board.

## Software/ binaries (from alexander-akhmetov/apple1 repo)

apple30.bin, lunar.bin, life.bin, ASMmchess.bin — load addresses TBD
(check that repo's loader). Not yet bundled.

## Legal notes

- fake6502: public domain (credit Mike Chambers).
- Woz Monitor + Integer BASIC: still Apple copyrights; tolerated and bundled
  by virtually all open-source Apple-1 emulators for decades. Bundled here
  too; revisit before any public release.
- The corrupted circulating BASIC dump ($F2/$12 at two bytes) breaks input —
  we ship the verified-good dump (cross-checked against napple1).
- 2513 font: render from datasheet bitmaps (not copyrightable glyph data).

## Build / test (CLT-only Mac, no Xcode)

- Tests: `./Scripts/test.sh` (adds Testing.framework paths for CLT)
- App: `./Scripts/build-app.sh [--install]` → `dist/First Light.app`
- DO NOT create a GitHub repo / push until mostly done (owner's request).

## Next 10 (planned 2026-06-10, post F1-F8)

N1. **Cassette deck & loading theater.** A skeuomorphic cassette (CassoFlow-
    style): labeled tape art per title, reels that actually spin during the
    load, tape winding left→right as progress, FSK audio synced. Cassettes
    menu becomes a shoebox of labeled tapes. Optional "authentic load"
    toggle (full ~45 s, like 1976).

N2. **First-launch cold open.** Replace the welcome sheet with a moment:
    dim bench → light comes up → "It's 1976. This is the computer that
    started it." → first power-on plays the full theater (surge, hum, CRT
    warm-up, prompt) → then offer the tutorial.

N3. **Tutorial v2 — three tracks.** Split the 9 linear steps into Operate
    (type, run, cassettes), Under the Hood (pull chips, failure modes,
    power net), and Software (BASIC, wozmon, demos). Each ~4 steps. End
    with BASIC printing CONGRATULATIONS at 60 cps.

N4. **Rainbow Apple moment.** The six-color logo (1977) rendered in SwiftUI
    in the About panel and welcome card; rainbow stripe accent on the
    fact bar's anniversary facts; APPLE 50TH demo gallery card.

N5. **App icon.** The board's silhouette (green PCB, gold edge fingers)
    with the rainbow-striped apple over it. Needed before anything ships.

N6. **Layout polish.** Panel-state + window-frame persistence, mini-CRT
    picture-in-picture when the screen panel is collapsed but powered,
    smarter responsive breakpoints for small windows.

N7. **Metal CRT shader.** Curvature, scanlines, phosphor persistence
    (ghost trails), bloom — and kills the idle Canvas redraw cost.

N8. **Workbench ambiance.** Wood-grain bench under the board, soft lamp
    vignette, subtle paper "Operation Manual" prop that opens the real
    PDF's pages.

N9. **Software shelf expansion.** Homebrew section (15 Puzzle, 2048,
    Mandelbrot-65), Bob Bishop's Star Trek, Blackjack ZP block, and a
    "type-in magazine" view that shows each BASIC listing as a 1976
    magazine page you can read then load.

N10. **Photograph the bench.** Export a high-res PNG of the current board
    state (and screen text) — share the machine you built. Groundwork
    for the eventual public release.


## Top 10 — Round 3 (researched & voted 2026-06-11)

Candidates were generated from three angles (authenticity, verification,
modern-twist), scored on authenticity x user value x effort. POM1 (the
cycle-accurate 50th-anniversary emulator) and the SB-Projects ACI format
doc were the key external references.

T1. **Bit-true tape audio.** Synthesize each cassette's FSK from its
    ACTUAL BYTES per the ACI spec (1kHz=0, 2kHz=1, asymmetric-cycle
    leader). The sound coming from the deck IS the program — in
    principle recordable to a real cassette and loadable on a real
    Apple-1. Replaces the generic pseudo-random warble.

T2. **Automated cassette verification suite.** Headless test that runs
    EVERY tape (incl. Extended Monitor E003R, Lunar, 2048, Mandelbrot —
    currently unverified) and asserts expected screen output. Catches
    data bugs like the lunar/15-Puzzle slug mixup permanently.

T3. **Operation Manual + quick reference.** In-app wozmon & BASIC
    command card (examine, deposit, run, ranges; BASIC keywords) — the
    missing instructions layer. Period typography.

T4. **Command palette (modern twist).** A small assistant that builds
    correct wozmon/BASIC commands ("show me memory at..." → types
    FF00.FFFF) — bridging the 2026 user to 1976 syntax without faking
    the machine.

T5. **Turbo mode.** CPU at 10x/100x with authentic speed as default and
    a visible "TURBO" indicator — for long BASIC programs/Mandelbrot.
    The period machine, with the modern impatience valve.

T6. **Machine state snapshots.** Save/restore the whole machine (RAM,
    CPU regs, screen) — freeze a Microchess game, resume tomorrow.

T7. **Metal CRT shader.** BLOCKED on CLT-only setup (no `metal`
    compiler without full Xcode). Shipped the Canvas edition: scanlines,
    vignette, tube-glass corner rounding. True curvature + persistence
    when Xcode lands (also prerequisite for iPad/visionOS).

T8. **Known-bug sweep.** Keyboard auto-repeat behavior research (real
    Datanetics had none), CTRL key function, fullscreen edge cases,
    deck % display on long authentic loads, tutorial completion races.

T9. **Period AV details bundle.** Mechanical 3-digit tape counter on
    the deck, CRT flyback whine (15.7kHz, optional!), monitor-side 60Hz
    hum distinct from PSU hum.

T10. **Release readiness.** Fact-check every in-app date/claim, credits
    & licenses README, screenshots, and the FIRST GIT COMMIT gate.

Voted order rationale: T1+T2 first (authenticity flagship + the safety
net), then instructions (T3/T4), speed (T5/T6), visuals (T7), polish
(T8-T10).
