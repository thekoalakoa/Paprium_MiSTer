# Paprium_MiSTer

A standalone **MiSTer FPGA** core for **Paprium** (WaterMelon, Mega Drive / Genesis), ported from the Analogue Pocket Paprium core ([paprium-pocket](https://github.com/thekoalakoa/paprium-pocket)). It is a Mega Drive core with the Paprium cartridge hardware added: the cartridge MCU, its sound effects, and background music streamed from a `paprium.pcm` file that you supply.

This is an EverDrive Pro style implementation, not a faithful reproduction of the original cartridge chipset.

**No ROM or music is included** in this repository or in the release, and none are linked here.

## Current release

[`paprium-20261003`](https://github.com/thekoalakoa/Paprium_MiSTer/releases/tag/paprium-20261003): `Paprium.rbf` and `Paprium.mgl`, hardware-verified on MiSTer.

## Requirements

- A MiSTer (DE10-Nano) with an up-to-date MiSTer main binary.
- Your own Paprium ROM dump, named `Paprium.md`.
- Your own Paprium music file, named `paprium.pcm`.

## Installing

1. Download `Paprium.rbf` and `Paprium.mgl` from the [release](https://github.com/thekoalakoa/Paprium_MiSTer/releases/tag/paprium-20261003) and put both in `_Console` on the SD card.
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
- **Paprium Arcade Mode**: Locked / Unlocked (based on adroxe's Paprium-Arcade unlock).
- **Paprium Arcade Stage**: Off, or a starting stage.
- **Audio & Video** page: Aspect Ratio, Scandoubler Fx, Vertical Crop, Crop Offset, Scale, 320x224 Aspect, Border, Composite Blend, CRAM Dots, Audio Filter, FM Chip, Stereo Mix.
- **Input** page: Swap Joysticks, 6 Buttons Mode.
- **Pause When OSD is Open**: No / Yes.
- **Mount music \*.PCM**: mount `paprium.pcm`.
- **Reset**: reset the core.

An info line reports the music file state: mounted, invalid, ejected or buffer underrun.

Progress saves automatically when the OSD is opened. There is no Hard Reset, Load/Save Backup RAM or Autosave item.

## Known issues

- A first launch with no save file starts at the mini-game.
- Some Audio & Video options (for example Aspect Ratio, Scandoubler Fx, Audio Filter, FM Chip, Stereo Mix) may have little or no visible effect, or may disturb video sync. Fixes are planned.
- The build is hardware-verified but does not fully meet Quartus timing. Long-session testing is still ongoing.

## Building from source

The release files are all you need to play. To build the core yourself:

1. Install Quartus Prime Lite 21.1.1. The device is Cyclone V `5CSEBA6U23I7`, revision `MegaDrive`.
2. Open `MegaDrive.qpf` and run a full compilation, or run `quartus_sh --flow compile MegaDrive` from the repository root.
3. The bitstream is written to `output_files/MegaDrive.rbf`. Rename it to `Paprium.rbf` for `_Console`.

The cartridge MCU firmware is stored pre-built in `rtl/PAPRIUM/mcu.txt`. It is krikzz's [mega-ppm](https://github.com/krikzz/mega-ppm) firmware with the changes in `patches/mega-ppm-pocket.patch`; see `patches/README.md` and `scripts/build_mcu.sh` to rebuild it. `clean.bat` removes Quartus build output.

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
- mega-ppm-derived cartridge files and firmware (`rtl/PAPRIUM/audio_sfx.sv`, `fpgio.sv`, `mcu_core.sv`, `memory.sv`, `ramdp_io.sv`, `structs.sv`, `mcu.txt`, and the code changed by `patches/mega-ppm-pocket.patch`): BSD-3-Clause, Copyright (c) 2025, krikzz.

**Exception:** VM2413 (`rtl/VM2413/`), Copyright (c) 2006 Mitsutaka Okazaki, is distributed under its own original terms, not under the GPL. Those terms include a non-commercial clause; the licence text is kept in the headers of its files.

Paprium is a trademark of its owners. This project is not affiliated with WaterMelon.
