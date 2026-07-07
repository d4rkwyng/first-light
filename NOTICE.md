# Notices — bundled third-party and historical material

First Light's original code is MIT-licensed (see [LICENSE](LICENSE)). The app
also bundles historical software and preservation material that is **not**
covered by that license. This file records what it is, where it came from,
and on what basis it ships. First Light is an unofficial tribute and is not
affiliated with, endorsed by, or sponsored by Apple Inc.

## Apple-1 ROMs (© Apple)

`Sources/Apple1Core/Resources/ROMs/`

| File | What it is |
|---|---|
| `wozmon.bin` (256 B) | The Woz Monitor — the Apple-1's resident firmware (Steve Wozniak, 1976) |
| `wozaci.bin` (256 B) | The Apple Cassette Interface ROM at $C100 (Wozniak, 1976) |
| `apple1basic.bin` (4 KB) | Apple Integer BASIC — hand-assembled by Wozniak (1976) |

These remain Apple copyrights. They have circulated freely in the Apple-1
preservation community for decades and are bundled here — as in essentially
every open-source Apple-1 emulator — solely for education and preservation.
No ownership is claimed. If Apple Inc. objects to their inclusion, they will
be removed promptly on request.

The Integer BASIC image is the verified-good dump (the widely circulated copy
with two corrupted bytes at $F2/$12 breaks input; ours is cross-checked
against the napple1 project's).

## Character generator

`charrom2513.bin` (2 KB) — the Signetics 2513 character ROM, from the
[P-LAB](https://www.p-l4b.com) dump, CC BY 4.0.

## Cassette software library

`Sources/FirstLight/Resources/Tapes/` — the 1976–77 Apple-1 cassette catalog
plus modern homebrew, collected from the Apple-1 preservation community:
the [Apple-1 Software Library](https://apple1software.com) preservation
project, [Mike Willegal](https://willegal.net), and
[Applefritter](https://applefritter.com).

- **Era software** (Hamurabi, Mini-Startrek, Lunar Lander, Mastermind,
  Dis-Assembler, Extended Monitor, Blackjack, Conway's Life): distributed on
  Apple's $5 cassettes or in period newsletters; preserved and shared by the
  community for education.
- **Microchess** — © 1976 Peter Jennings, the first commercial game software
  for a personal computer. Included as preserved by the community;
  removed on request.
- **Modern homebrew** (written for real Apple-1s, this century):
  15 Puzzle (Jeff Jetton, 2020), 2048, APPLE 30TH (Dave Schmenk),
  Mandelbrot 65. Credit belongs to their authors.
- **APPLE 50TH** is original to this project (MIT, like the rest of our code).

## Emulation core

`Sources/CFake6502/` — **fake6502** v1.1 © 2011 Mike Chambers, released into
the public domain ("but if you use it please do give credit" — credit given,
gladly). Unmodified except for disabling the NES quirk flag.

## Board fabrication data

The rendered PCB (`board-copper.png`, `board-silk.png`, `board-power.png`)
derives from the Apple-1 gerbers recreated by the Applefritter **A1replica**
project; the ACI card (`aci-copper.png`) from
[kalinchuk/apple_1](https://github.com/kalinchuk/apple_1). Component
placement follows the XS-Labs layout diagram and Computer History Museum
photographs.

## Photographs

`Resources/Gallery/` — all CC BY-SA, Wikimedia Commons:

- Arnold Reinhold — Woz's Apple-1 at the Computer History Museum (CC BY-SA 4.0)
- Ed Uthman — the Smithsonian's Apple-1 (CC BY-SA 2.0)
- Jordiipa — Apple-1 in its wooden tray, CHM (CC BY-SA 3.0)
- Sergei Magel / Heinz Nixdorf MuseumsForum — complete 1976 setup (CC BY-SA 4.0)

## Trademarks

"Apple" and "Apple-1" are used nominatively to describe the historical
machine this project emulates. This project is not affiliated with Apple Inc.
