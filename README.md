# Paprium_MiSTer

A standalone **MiSTer FPGA** core for **Paprium** (WaterMelon, Mega Drive / Genesis), ported from the Analogue Pocket Paprium core ([paprium-pocket](https://github.com/thekoalakoa/paprium-pocket)). It is a Mega Drive core with the Paprium cartridge hardware added: the cartridge MCU, its sound effects, and background music streamed from a `paprium.pcm` file that you supply.

This is an EverDrive Pro style implementation, not a faithful reproduction of the original cartridge chipset.

**No ROM or music is included** in this repository or in the release, and none are linked here.

## Current release

**0.2.6**, from the [latest release](https://github.com/thekoalakoa/Paprium_MiSTer/releases/latest): `Paprium_MiSTer_0.2.6.zip` (`_Console/Paprium.rbf` and `_Console/Paprium.mgl`), hardware-tested on MiSTer.

## What's new in 0.2.6

- **Console list** with per-console region (the region follows the chosen console).
- **Mega CD unit picker** (CD Model): choosing a real CD unit enables the CPU MATE buddy, cart-accurate and running on the cartridge MCU; None or Unknown CD gives no buddy.
- **MegaWire4.0** option, Off by default (Off hides its icon and options row).
- **Grand Stick Options** page and **Little-Man** cheats (Infinite Life, Pills, Lives).
- Fixes: Solarium float, credits after Bishop, elevator background band, BOF Naming restart, and an SDRAM read fix.

### Notes
- Backing out of a sub-page returns to the main menu.
- The CD Model label shortens to "CD Mo:" for the two longest unit names.
- After changing Console or CD Model, a second reset may be needed for the correct picture.

## Requirements

- A MiSTer (DE10-Nano) with an up-to-date MiSTer main binary.
- Your own Paprium ROM dump, named `Paprium.md`.
- Your own Paprium music file, named `paprium.pcm`.

## Installing

1. Download `Paprium_MiSTer_0.2.6.zip` from the [latest release](https://github.com/thekoalakoa/Paprium_MiSTer/releases/latest) and unzip it onto the SD card: it puts `Paprium.rbf` and `Paprium.mgl` in `_Console`, replacing any older copies.
2. Put your `Paprium.md` and `paprium.pcm` in `games/Paprium/Paprium`.
3. Launch `Paprium.mgl`. It starts the core, loads the ROM and mounts the music file.

SD card layout:

```
_Console/Paprium.rbf
_Console/Paprium.mgl
games/Paprium/Paprium/Paprium.md
games/Paprium/Paprium/paprium.pcm
```

The launcher (`releases/Paprium.mgl`) expects exactly these paths:

```
/media/fat/games/Paprium/Paprium/Paprium.md    (ROM)
/media/fat/games/Paprium/Paprium/paprium.pcm   (music)
```

## OSD guide

- **Load \*.BINGENMD**: load a ROM by hand.
- **Load \*.PCM**: load a music file by hand.
- **TMSS**: Disabled / Enabled.
- **SCUM! (Needs Reset)** page (change, then Reset):
  - **Grand Stick Options** page: 6-Button Mode, Swap Joysticks, Arcade Mode (based on adroxe's Paprium-Arcade unlock), Arcade Stage.
  - **Console**: Mega Drive, Genesis, Mega Drive 2, Genesis Model 2, Genesis 3, Nomad, Mega Jet, Unknown. Sets the region and console type.
  - **CD Model**: None, Mega-CD / Sega CD, Mega-CD 2 / Sega CD 2, Wondermega, Wondermega M2 / X'Eye, LaserActive, Aiwa CSD-GM1, CDX, Unknown CD. A real unit turns on the CPU MATE buddy.
  - **32X Mode**: Off / On.
  - **MegaWire4.0**: Off / On.
  - **Little-Man** page: Infinite Life, Infinite Pills, Infinite Lives.
- **Audio & Video** page: Aspect Ratio, Scandoubler Fx, Vertical Crop, Crop Offset, Scale, 320x224 Aspect, Border, Composite Blend, CRAM Dots, Audio Filter, FM Chip, Stereo Mix.
- **Pause When OSD is Open**: No / Yes.
- **Mount music \*.PCM**: mount `paprium.pcm`.
- **Reset**: reset the core.

An info line reports the music file state: mounted, invalid, ejected or buffer underrun.

Progress saves automatically when the OSD is opened. There is no Hard Reset, Load/Save Backup RAM or Autosave item.

## Known issues

- A first launch with no save file starts at the mini-game.
- Audio & Video page: Aspect Ratio, Scandoubler Fx, Audio Filter, FM Chip and Stereo Mix may have little or no effect, or may disturb video sync. Fixes are pending.
- With Arcade Mode or 6-Button on, the Hall of Fame name bar can show garbage at its left edge and may miss a press.

## Building from source

The release files are all you need to play. To build the core yourself:

1. Install Quartus Prime Lite 21.1.1. The device is Cyclone V `5CSEBA6U23I7`, revision `MegaDrive`.
2. Open `MegaDrive.qpf` and run a full compilation, or run `quartus_sh --flow compile MegaDrive` from the repository root.
3. The bitstream is written to `output_files/MegaDrive.rbf`. Rename it to `Paprium.rbf` for `_Console`.

Before step 2, download `cpu-mate-brain_0.2.6.zip` from the release, unzip it in the top folder of your clone (it makes `cpu-mate-brain/`, which git ignores), and run `./scripts/build_mcu.sh --brain cpu-mate-brain`. It checks the brain md5s and installs the cartridge MCU's four memory init files (`rtl/PAPRIUM/mcu.txt`, `mcu_ext.txt`, `wram_hi.txt`, `wram_lo.txt`), which are not in the repository. See [`docs/firmware/README.md`](docs/firmware/README.md). The firmware is krikzz's [mega-ppm](https://github.com/krikzz/mega-ppm) with the changes in `patches/mega-ppm-pocket.patch` (see `patches/README.md`). `clean.bat` removes Quartus build output.

## Credits

- [Nuked-MD-FPGA](https://github.com/nukeykt/Nuked-MD-FPGA) by nukeykt: the Mega Drive core (`rtl/nuked-md/`).
- [MegaDrive_MiSTer](https://github.com/MiSTer-devel/MegaDrive_MiSTer) and the MiSTer framework (`sys/`) by Sorgelig (Alexey Melnikov) and the MiSTer contributors.
- [FX68K](https://github.com/ijor/fx68k) by Jorge Cwik: the 68000 CPU core (`rtl/fx68k/`).
- [NEORV32](https://github.com/stnolting/neorv32) by Stephan Nolting: the RISC-V soft CPU that runs the cartridge MCU firmware (`rtl/PAPRIUM/risc-v/`).
- [mega-ppm](https://github.com/krikzz/mega-ppm) by krikzz: the Paprium cartridge MCU firmware and cartridge logic, and the first-level door fix.
- [Paprium_MegaDrive_MiSTer](https://github.com/MisterPezz82/Paprium_MegaDrive_MiSTer) by MisterPezz82: the original MiSTer Paprium port this core started from.
- [Paprium-Arcade](https://github.com/adroxe/Paprium-Arcade) by adroxe: the Arcade Mode unlock.
- VM2413 by Mitsutaka Okazaki (`rtl/VM2413/`).
- Project Little Man, TheHpman (MAME Paprium research), MAVProxyUser (Genesis Plus GX Paprium work), and the Paprium preservation community.

## Licence

Paprium_MiSTer as a whole is licensed under the **GNU General Public License, version 3 or (at your option) any later version** (GPL-3.0-or-later). See [`LICENSE`](LICENSE), which also lists the third-party components:

- Nuked-MD-FPGA (`rtl/nuked-md/`): GPL-2.0-or-later (`rtl/nuked-md/LICENSE`).
- FX68K (`rtl/fx68k/`): GPL version 3 (`rtl/fx68k/LICENSE`).
- MiSTer core files (`MegaDrive.sv`, `rtl/cartridge.sv`, `rtl/md_io.sv`): GPL-2.0-or-later. `rtl/sdram.sv`: GPL-3.0-or-later.
- MiSTer framework (`sys/`): GPL, per file header (for example `sys/sys_top.v` GPL-2.0-or-later, `sys/hps_io.sv` and `sys/scandoubler.v` GPL-3.0-or-later).
- NEORV32 (`rtl/PAPRIUM/risc-v/`): BSD-3-Clause, Copyright (c) 2020, Stephan Nolting (`rtl/PAPRIUM/risc-v/LICENSE`).
- mega-ppm-derived cartridge files and firmware (`rtl/PAPRIUM/audio_sfx.sv`, `fpgio.sv`, `mcu_core.sv`, `memory.sv`, `ramdp_io.sv`, `structs.sv`, and the code changed by `patches/mega-ppm-pocket.patch`): BSD-3-Clause, Copyright (c) 2025, krikzz.

**Exception:** VM2413 (`rtl/VM2413/`), Copyright (c) 2006 Mitsutaka Okazaki, is distributed under its own original terms, not under the GPL. Those terms include a non-commercial clause; the licence text is kept in the headers of its files.

Paprium is a trademark of its owners. This project is not affiliated with WaterMelon.
Paprium game content (WaterMelon IP)
This project's GPLv3 license covers only our code. It does not include, and grants no rights to, Paprium's game ROM, code, music, graphics or other assets, which are owned by WaterMelon.

Do not distribute ports, forks or modified builds of this project bundled with Paprium's ROM, decompiled game code or assets. Doing so infringes WaterMelon's copyright and is not covered by our license.
Players must supply their own legally owned copy of the game.
Any port or modification of our code that ships with WaterMelon content without WaterMelon's written permission is unauthorized, and we will report it.
