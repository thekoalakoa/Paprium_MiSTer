# Paprium_MiSTer

A standalone **MiSTer FPGA** core for **Paprium** (WaterMelon, Mega Drive / Genesis). It is a port of the [Analogue Pocket Paprium core](https://github.com/thekoalakoa/paprium-pocket).

This is a Mega Drive core with Paprium's own cartridge hardware added: the processor that stands in for the cart's chip and runs our firmware, Little-Man Firmware; a sprite decoder and a sound chip we rebuilt to work the way the cart's do.

> **You need your own copy of the game.** This project doesn't include one and won't link one. WaterMelon have stopped trading and the game isn't sold anymore, but that doesn't make it public domain. It's still their work, and this project treats it that way.
>
> You don't need a soundtrack file anymore. From 0.3.0 on, the core makes the game's music from your own copy of the game, the same way the cart does.

## Current release

**0.3.0**, from the [latest release](https://github.com/thekoalakoa/Paprium_MiSTer/releases/latest): `Paprium_MiSTer_0.3.0.zip`. It puts `Paprium.rbf` and `Paprium.mgl` in `_Console`, and Little-Man Firmware 1.0 in `games/Paprium/little_man_firmware.bin`.

**Installation: [docs/INSTALL.md](docs/INSTALL.md)**

This release mirrors [Paprium for Analogue Pocket 0.3.0](https://github.com/thekoalakoa/paprium-pocket/releases/tag/v0.3.0), adapted for MiSTer.

## What 0.3.0 is

With 0.3.0 the core acts like the original cart. Two things changed the most.

- **The game's own music, made the way the cart makes it.** We rebuilt the cart's sound chip in the core's logic, and our music player runs in the firmware, working like the cart's does. The music and sound effects are made from your own copy of the game the same way the cart makes them, so the music reacts to what's happening in the game just like on a real cart. Both of the game's sound options work, YM and Datenmeister. No more soundtrack file.
- **Our own firmware for the cart's chip.** The cart has its own processor. It unpacks the game's graphics, drives the sprites, keeps the saves and plays the sound. In this core that processor runs **Little-Man Firmware**, which our team wrote from our own study of how the cart behaves. On MiSTer it is its own file, `games/Paprium/little_man_firmware.bin`, version 1.0 — the same Little-Man Firmware 1.0 the Pocket core uses. Paprium.mgl loads it when you launch the core; it is not auto-loaded by MiSTer by filename. It's free software under the GPL (version 3 or later). The source is in the Pocket repo's [`firmware/`](https://github.com/thekoalakoa/paprium-pocket/tree/v0.3.0/firmware) folder.

Anything a player might notice that's different from the original cart is listed under [Known differences from the original cartridge](#known-differences-from-the-original-cartridge).

## What you need

- A MiSTer (DE10-Nano) with an up-to-date MiSTer main binary. This release only adds Paprium files. It does not replace MiSTer Main, Linux, or other system files.
- Your own copy of the game, named `Paprium.md`.
- The 0.3.0 release zip, `Paprium_MiSTer_0.3.0.zip`.

You can forget the soundtrack file (`paprium.pcm`), and the `paprium.cue` next to it. 0.3.0 doesn't read either. If you might go back to 0.2.6, keep them, because 0.2.6 needs the soundtrack for music.

## What changed since 0.2.6

**Sound**
- The music comes from our music player in the firmware plus our rebuild of the cart's sound chip, which work the way the cart's do, in both of the game's sound options (YM and Datenmeister). It follows the game like the cart does: the low-health music, the sax man's cues, the Boom Box's X, Y and Z effects and the fades.
- Sound effects play on our rebuild of the cart's synthesiser, filter and echo included.
- The audio option in the game's own options menu works like it does on the cart.
- Each start takes longer than you're used to. The screen stays black, with no progress bar, while the core unpacks the game's sounds from your copy of the game. MiSTer does not keep a sound-cache file, so this happens every time you launch the core.
- The OSD rows for loading or mounting a soundtrack file are gone.
- The old diagnostic rows, and the separate Console Reset, are gone. The regular Reset does a full reset, and so does the USER button on the MiSTer.

**How the cart behaves**
- The sprites, the zooms, unpacking the game's data, the saves, the start-up and the cart's watchdog all work the way the cart does them.
- Sprites get the cart's colours. Dice's afterimage outline is green like on the cart (0.2.x drew it blue), and the first level's doorway gets its colours from the cart's own rule.
- Saves use the cart's own format, 8 KB, the size of the cart's save chip. A 0.2.x save gets converted once, the first time 0.3.0 starts. Make a copy of your save before you install (see [docs/INSTALL.md](docs/INSTALL.md)).
- The cart's watchdog is back. With the OSD closed, if the game stops sending its once-a-frame signal for about 4 seconds, the cart's chip halts, just like a real cart.

**The OSD**
- **Arcade Mode** is now a virtual Grand Stick III, with Off, On, Multiplayer and Stick Only. On and Multiplayer flip the stick's ARCADE switch, so the game turns on its own arcade mode with no change to the ROM. Mode drops a coin, and like a real stick, the first coin after power-on or a reset doesn't give a credit. Stick Only is the stick with every switch off: the normal game, with Mode as the stick's Mode button. Also new: **Arcade Coins** and **Attract Only**.
- **3-Player Mode** (Off by default): an EA 4-Way Play, for the game's three-player modes with three controllers.
- **TeraDrive** joins the Console list (it's a Japanese console, so the region is Japan).
- **Load Little-Man Firmware** can load a different firmware file by hand, for testing. For normal play, leave `games/Paprium/little_man_firmware.bin` where the zip put it, and launch Paprium.mgl, which loads it.
- **MegaWire4.0** is still in the OSD.

**Fixed**
- Hall of Fame name entry: the highlight bar is clean with Arcade Stage or 6-Button Mode on (a 0.2.6 known issue, verified on the pass 10 hardware run).
- The Arcade coin plays the game's coin sound on every press.
- TMSS, the licence check later consoles run at power-on, works on every all-in-one Mega CD unit (Wondermega, Wondermega M2 / X'Eye, LaserActive, Aiwa CSD-GM1, CDX).

## Installing

The short version: unzip the release onto the SD card, keep your `Paprium.md` where it is, back up your save first, and launch `Paprium.mgl`. Paprium.mgl loads `games/Paprium/little_man_firmware.bin` first, then `games/Paprium/Paprium/Paprium.md`. The full steps, the exact mgl, the red-screen note, and how to go back to 0.2.6 are in [docs/INSTALL.md](docs/INSTALL.md).

```
_Console/Paprium.rbf
_Console/Paprium.mgl
games/Paprium/little_man_firmware.bin                Little-Man Firmware 1.0
games/Paprium/Paprium/Paprium.md           your own copy of the game
saves/Paprium/Paprium.sav                  your save (back this up first)
```

## OSD guide

- **Load \*.BINGENMD**: load a ROM by hand.
- **Load Little-Man Firmware**: load a firmware file by hand, for testing.
- **TMSS**: Disabled / Enabled.
- **SCUM! (Needs Reset)** page (change, then Reset):
  - **Grand Stick Options** page: 6-Button Mode, Swap Joysticks, Arcade Mode (Off, On, Multiplayer, Stick Only), Arcade Coins, Attract Only, 3-Player Mode, Arcade Stage.
  - **Console**: Mega Drive, Genesis, Mega Drive 2, Genesis Model 2, Genesis 3, Nomad, Mega Jet, Unknown, TeraDrive. Sets the region and the console picture in the Boom Box. The TMSS models boot with no licence screen. TeraDrive is detection only: the core answers the game's video RAM test, so the Boom Box shows the TeraDrive.
  - **CD Model**: None, Mega-CD / Sega CD, Mega-CD 2 / Sega CD 2, Wondermega, Wondermega M2 / X'Eye, LaserActive, Aiwa CSD-GM1, CDX, Unknown CD. A real unit (anything except None or Unknown CD) turns on the CPU MATE partner.
  - **32X Mode**: Off / On. The game believes a 32X is attached; some throwables become 32X boxes.
  - **MegaWire4.0**: Off / On.
  - **Little-Man** page: Infinite Life, Infinite Pills, Infinite Lives. These are the cheats. They have nothing to do with the firmware file.
- **Audio & Video** page: Aspect Ratio, Scandoubler Fx, Vertical Crop, Crop Offset, Scale, 320x224 Aspect, Border, Composite Blend, CRAM Dots, Audio Filter, FM Chip, Stereo Mix.
- **Pause When OSD is Open**: No / Yes.
- **Reset**: resets the core, cart included. The **USER** button on the MiSTer does the same full reset.

The game reads Console, CD Model, 32X Mode, Arcade Mode and 3-Player Mode at boot, so change the setting first, then hit Reset.

None of the Scum! switches touches your ROM file. Little-Man and the Arcade stage pick work like a Game Genie: while one is on, the cart hands the console a few replacement words instead of the game's own. Arcade Mode, 6-Button Mode and 3-Player Mode don't change a word of the game. They change what the game finds on its controller ports.

**CPU MATE.** In the OSD, pick a CD Model other than None or Unknown, then Reset. In the game's Options, switch CPU MATE on. At character select, bring the partner in:

- **With one controller:** turn **6-Button Mode** on (SCUM! (Needs Reset) > Grand Stick Options). Hold Mode to add the partner; still holding it, move the partner's cursor with the D-pad and press Start to pick its character. Release Mode to pick your own. It is the game's own six-button control with a Mega CD ([Paprium FAQ](https://www.wafflenet.com/paprium.html#questions)).
- **With a second controller:** press Start on controller 2, and again to pick its character.

The partner's brain ships inside the firmware file. It's a reverse-engineered emulation of the game's CPU partner. Its files aren't part of this repository's source. A firmware file built without it still runs the game, but the partner just stands there.

Progress saves automatically when the OSD is opened. There is no Hard Reset, Load/Save Backup RAM or Autosave item.

## Known differences from the original cartridge

These are the differences a player can notice. Each one is there on purpose.

- **Starting takes longer than on the cart.** Before the game starts, the core checks the firmware file and holds the game until the cart's chip is ready, and it unpacks the game's sounds from your own copy of the game. There is no progress bar, and no sound-cache file is kept, so the unpack happens every time you launch the core.
- **The OSD.** The cart doesn't have a menu. While the OSD is open, the cart's watchdog stops counting. If you turn on **Pause When OSD is Open**, the game pauses and the cart's sound effects are held with it while the menu is open.
- **Datenmeister's output.** In Datenmeister mode the sound leaves the cart's chip the same way it does on the cart. What the cart's own output circuit does to it after that (its level next to the YM music, a low cut, its polarity) isn't copied. Instead there's a simple stand-in: one volume, and a filter that only takes out a steady offset (below 4 Hz).
- **Corners the game never reaches.** A few edge cases the game never hits, like asking for more than 53 sprite slots, are handled safely here. On the cart, the chip would read or write unrelated memory of its own.
- **MegaWire details only a module would ever see:** the server name stored for a module is `www.koalakoa.com`, and the restart command in the game's own MegaWire menu doesn't save a MegaWire record. A real MiSTer has no MegaWire module plugged in, so the game looks like a cart with nothing plugged in (MODEM : NONE, no MegaWire icon), unless you turn MegaWire4.0 On.

## Little-Man Firmware

Little-Man Firmware (trademark pending) is the firmware the cart's chip runs in this core. On MiSTer it is one file, `games/Paprium/little_man_firmware.bin`, version 1.0. It holds three things: the firmware itself, our MegaWire code, and the brain of the game's CPU MATE partner. It is the same file, under the same name, that the Pocket core ships.

- The release zip puts it in place already named `little_man_firmware.bin`. Paprium.mgl loads it when you launch the core. It is not auto-loaded by MiSTer by filename. See [docs/INSTALL.md](docs/INSTALL.md).
- The core checks the file at every power-on, before the firmware starts. It isn't signed and it isn't encrypted. The check looks at its length, its version, its fixed layout and two checksums, and that's all.
- If the file is missing, damaged, or was made for a different core version, the screen goes plain red, with no text and no sound, and the game doesn't start. Copy the file from the release again, then start the core again from Paprium.mgl.
- The core and the firmware file go together. 0.3.0 takes Little-Man Firmware 1.0.
- The source is in the Pocket repo's [`firmware/`](https://github.com/thekoalakoa/paprium-pocket/tree/v0.3.0/firmware) folder, under GPL-3.0-or-later, with [THIRD_PARTY_NOTICES.md](https://github.com/thekoalakoa/paprium-pocket/blob/v0.3.0/firmware/THIRD_PARTY_NOTICES.md).
- The **Little-Man** page in the OSD is the cheats. It has nothing to do with the firmware file.

## Known issues

- **Audio & Video page:** Aspect Ratio, Scandoubler Fx, Audio Filter, FM Chip and Stereo Mix may have little or no effect, or may disturb video sync.
- A first launch with no save file starts at the mini-game. That is the cart's own behaviour, not a bug. Play or skip it, then hit Reset and the game boots properly.

## Building from source

The release files are all you need to play. To build the core yourself:

1. Install Quartus Prime Lite 21.1.1. The device is Cyclone V `5CSEBA6U23I7`, revision `MegaDrive`.
2. Open `MegaDrive.qpf` and run a full compilation, or run `quartus_sh --flow compile MegaDrive` from the repository root.
3. The bitstream is written to `output_files/MegaDrive.rbf`. Rename it to `Paprium.rbf` for `_Console`.

The firmware is no longer built into the bitstream. Paprium.mgl loads `games/Paprium/little_man_firmware.bin` when you launch the core. To rebuild that file, use the Little-Man Firmware source in [paprium-pocket](https://github.com/thekoalakoa/paprium-pocket/tree/v0.3.0/firmware). The CPU MATE brain is a separate release download and is not in either repository; see [docs/firmware/README.md](docs/firmware/README.md).

The release bitstream was fitted with seed 1, which is what `MegaDrive.qsf` says, so `quartus_sh --flow compile MegaDrive` uses that same seed. A fresh fit is not guaranteed to match the released bitstream bit for bit. The `Paprium.rbf` in the release zip is the reference.

`clean.bat` removes Quartus build output.

## Lineage

This core stands on the projects below, and on the [Pocket port](https://github.com/thekoalakoa/paprium-pocket) it is adapted from. It's GPLv3 all the way through, except for the parts under permissive licences: the BSD-licensed parts of the cartridge (NEORV32, krikzz's mega-ppm code, the WavPack decoder and two routines from the toolchain's C library) and VM2413, which keeps its own original terms (see [Licence](#licence)). Every one of them stays credited. Our own changes to those parts are GPLv3 like everything else; see [Licence](#licence). The work that got this core going but isn't in it anymore is credited under [History](#history).

| | |
|---|---|
| [Nuked-MD-FPGA](https://github.com/nukeykt/Nuked-MD-FPGA) | nukeykt — the Mega Drive core (`rtl/nuked-md/`) |
| [FX68K](https://github.com/ijor/fx68k) | Jorge Cwik (ijor) — the 68000 (`rtl/fx68k/`) |
| [MegaDrive_MiSTer](https://github.com/MiSTer-devel/MegaDrive_MiSTer) | Sorgelig (Alexey Melnikov) and the MiSTer contributors — the MiSTer framework (`sys/`) and the core built around it |
| [Paprium_MegaDrive_MiSTer](https://github.com/MisterPezz82/Paprium_MegaDrive_MiSTer) | MisterPezz82 — the original MiSTer Paprium port this core started from: the cartridge RTL, serving patches as ROM reads, and the SDRAM port-2 counter |
| [mega-ppm](https://github.com/krikzz/mega-ppm) | krikzz — the FPGA sources the cartridge files `fpgio.sv`, `mcu_core.sv`, `memory.sv`, `ramdp_io.sv` and `structs.sv` come from, and `audio_sfx.sv` and `audio_clock.sv`, which are still in the repository but aren't built into the bitstream (BSD-3-Clause). The firmware every release up to 0.2.6 was built from is credited under [History](#history). |
| 0.2.6 firmware code still carried | Code from the 0.2.6 firmware that this release's firmware file still has in it: krikzz's mega-ppm code (BSD-3-Clause) in the 0.2.6 command bodies `firmware/interim/s1/bodies_s1.c` (moved over from mega-ppm's `paprium.c`), which the 0.3.0 firmware still links, and in the 0.2.6 build's source files kept in `firmware/legacy/026/`, `firmware/interim/` and `firmware/board/` of the Pocket repository's `firmware/` folder; the 0.2.6 LZO decoder in `firmware/legacy/026/mame.c`, ported from Genesis Plus GX's Paprium support (source for the 0.2.6 build only); and the parts of `mame.c` that mega-ppm based on TheHpman's MAME Paprium work. Each one keeps its credit, and krikzz's code keeps its notice. |
| [NEORV32](https://github.com/stnolting/neorv32) | Stephan Nolting — the RISC-V processor the cart's chip runs on (it comes in with MisterPezz82's cartridge RTL), plus the linker script our firmware's linker scripts are based on (BSD-3-Clause). Its runtime, which the firmware linked up to 0.2.6, is credited under [History](#history) |
| [WavPack](https://github.com/dbry/WavPack) | Conifer Software — the WavPack 4.0 "tiny decoder" in the firmware, as the Rockbox project carries it. It unpacks the game's sound bank from your own copy of the game (BSD) |
| newlib | the C library from the xPack RISC-V GCC toolchain: its `memcpy` and `memset` are linked into the firmware |
| VM2413 | Mitsutaka Okazaki (`rtl/VM2413/`), under its own original terms, not the GPL. See [Licence](#licence) |

**The cart's firmware is our own: Little-Man Firmware.** Our team wrote it from our own study of how the cart behaves. It's GPL-3.0-or-later. It ships as `games/Paprium/little_man_firmware.bin` (Little-Man Firmware 1.0 goes with this release). Paprium.mgl loads it.

### Menu switches, controllers and the CPU MATE link

Serving patches as ROM reads is MisterPezz82's idea, and the Arcade Stage list comes from their Paprium MiSTer core. krikzz found the arcade start-stage word. The MiSTer Paprium team's 32X and Mega CD detection stubs are where the add-on answers began, and we worked out the CPU MATE link's restart rule together with them.

### Research credits

Thanks to Project Little Man, TheHpman (MAME Paprium research), MAVProxyUser (Genesis Plus GX Paprium work) and the Paprium preservation community.

### What this port adds

The music, the firmware, the sprite decoder and the controllers were done first on the Pocket core and brought here. On MiSTer this port adds the SD layout, the OSD, and the way Paprium.mgl loads the firmware file, `games/Paprium/little_man_firmware.bin`.

## History

Releases up to 0.2.6 stood on work that 0.3.0 doesn't run the same way anymore. That work got this core going, so it stays credited here. Whatever of it this release still carries is listed in [Lineage](#lineage) too.

| | |
|---|---|
| [mega-ppm](https://github.com/krikzz/mega-ppm) — krikzz | The replacement cartridge MCU firmware (BSD-3-Clause). Every release from the first public builds to 0.2.6 ran it, built with this project's changes in `patches/mega-ppm-pocket.patch`: the elevator, animation and Boom Box fixes, and 0.2.6's cartridge rules. 0.3.0 runs our own firmware. krikzz's image converter has been replaced by our own; the image files keep its layout |
| krikzz's first-level door fix | The palette fix for the first level's door (object 107, sprite 4) that earlier releases carried, reported by MisterPezz82 and shipped in their V.05. From 0.3.0 the cart's own palette rule gives the door its colours |
| MisterPezz82's SFX engine and MD+ adapter | `audio_sfx.sv`, the 8-channel sound-effect engine adapted from mega-ppm's, and `paprium_mdp_adapter.sv`, the MD+ link the album played through: the 0.2.x sound path. From 0.3.0 our rebuild of the cart's synthesiser plays the sound effects and the music |
| The album path | Up to 0.2.6 the music was the released soundtrack, which you supplied as a `paprium.pcm` file. From 0.3.0 our rebuild of the cart's synthesiser plays the music, and the soundtrack file isn't used. |
| [Paprium-Arcade](https://github.com/adroxe/Paprium-Arcade) — adroxe | The 0.2.6 Arcade Mode unlock and the Mode-button coin. In 0.3.0 Arcade Mode is a virtual Grand Stick III: the game reads its switches and its coin, and the stick's ARCADE switch turns on the game's own arcade mode. |
| [Genesis Plus GX](https://github.com/ekeeke/Genesis-Plus-GX) | The 0.2.x firmware's LZO decoder was ported from its Paprium support, because stock mega-ppm's decoder broke the subway, among other spots. |
| TheHpman's MAME Paprium work | `rom.cpp`, which mega-ppm's `mame.c` says it's based on: the firmware in the releases up to 0.2.6 was built on it |
| NEORV32's runtime | Stephan Nolting — the start-up code (`crt0.S`) and the `neorv32_*` library the firmware linked up to 0.2.6 (BSD-3-Clause). 0.3.0's firmware has its own start-up code; the NEORV32 processor and the linker script are still in (see [Lineage](#lineage)) |

Up to 0.2.6, the firmware changes were patches on top of krikzz's [mega-ppm](https://github.com/krikzz/mega-ppm). They're in [patches/](patches/) and rebuild that firmware from a clean mega-ppm clone. From 0.3.0 on, the cart's chip runs our own firmware: see [Little-Man Firmware](#little-man-firmware).

## Licence

Copyright (C) 2026 Marsupial Solutions LLC, for the changes made in this repository and for the cartridge firmware. The projects it's built on keep their own copyright; see [Lineage](#lineage), [History](#history) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Paprium_MiSTer as a whole is licensed under the **GNU General Public License, version 3 or (at your option) any later version** (GPL-3.0-or-later). See [`LICENSE`](LICENSE).

**The firmware is our own.** Our team wrote the cart firmware, Little-Man Firmware, from our own study of how the cart behaves. It's GPL-3.0-or-later like the rest of the core. On MiSTer it ships next to the bitstream as `games/Paprium/little_man_firmware.bin`. Paprium.mgl loads it. It isn't signed and it isn't encrypted. The file also carries the MegaWire code, built from the same source under the same licence, and the CPU MATE brain (see below).

**Little-Man Firmware** (trademark pending) is Marsupial Solutions LLC's name for this firmware.

**We keep the BSD notices for everything still carried**: the NEORV32 processor (in the bitstream) and the NEORV32 linker script our firmware's linker scripts are based on (in the firmware source, with the Free Software Foundation notice the script carries); krikzz's mega-ppm code in the cartridge files `rtl/PAPRIUM/fpgio.sv`, `mcu_core.sv`, `memory.sv`, `ramdp_io.sv` and `structs.sv` (and in `audio_sfx.sv` and `audio_clock.sv`, which stay in the repository but aren't built), and in the firmware files based on mega-ppm that this release still carries (the Pocket repository's `firmware/THIRD_PARTY_NOTICES.md` lists them); the WavPack decoder (in the firmware); and the toolchain C library's `memcpy` and `memset` (in the firmware). Their original code stays under its BSD licence. Their copyright notices and licence texts are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Our own changes to that code aren't BSD. They're GPLv3-or-later, like the rest of this core. The firmware file and the bitstream are distributed under the GPL, with the BSD notices kept.

The VM2413 exception, and the other third-party notices, are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and in the appendix of [`LICENSE`](LICENSE).

**CPU MATE.** The partner's brain ships inside the firmware file. It's a reverse-engineered emulation of the game's CPU partner. Its files aren't part of this repository's source. It's only useful together with your own copy of the game.

**The game.** You bring your own copy of the game. The ROM, and anything taken from it, never ships: not in this repository, not in a release, not in any download. This core does not write a sound-cache file.

Paprium is a trademark of its owners. This project is not affiliated with WaterMelon. It is a free, non-commercial project: it is not sold, and the game is not included.

Paprium game content (WaterMelon IP)
This project's GPLv3 license covers only our code. It does not include, and grants no rights to, Paprium's game ROM, code, music, graphics or other assets, which are owned by WaterMelon.

Do not distribute ports, forks or modified builds of this project bundled with Paprium's ROM, decompiled game code or assets. Doing so infringes WaterMelon's copyright and is not covered by our license.
Players must supply their own legally owned copy of the game.
Any port or modification of our code that ships with WaterMelon content without WaterMelon's written permission is unauthorized, and we will report it.
