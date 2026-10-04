# Paprium_MiSTer

A **MiSTer** FPGA core for **Paprium** (WaterMelon, Mega Drive / Genesis). It is a Mega Drive core with Paprium cartridge support added (Paprium MCU behaviour). Background music is read from a `paprium.pcm` file that you supply.

You need your own Paprium ROM dump and your own `paprium.pcm`. Neither is included in this repository or in the release, and none are linked here.

## Status

- Hardware-verified.
- A 30+ minute soak is still open.
- Download: Paprium.rbf and Paprium.mgl are attached to the [paprium-20261003 release](https://github.com/thekoalakoa/Paprium_MiSTer/releases/tag/paprium-20261003) on the GitHub Releases page of this repository.
- Release rbf: md5 `2b1befb0aefb720aa8a0eaa9cf4e21e9`, 3,823,828 bytes, compiled with Quartus Prime Lite 21.1.1, seed 1 (as set in `MegaDrive.qsf`).

### Build numbers

| Item | Value |
|---|---|
| ALM | 25,733 / 41,910 |
| M10K | 339 / 553 |
| DSP | 61 / 112 |
| clk_107m setup | WNS -0.761 |
| clk_53m setup | WNS -0.117 |
| Hold (minimum) | -0.116 by corner scan |

This build has a **timing exception** on clk_107m and clk_53m (negative setup slack) and a negative hold slack in the corner scan. It was verified on hardware, but it does not meet timing.

## Installing

1. Download `Paprium.rbf` and `Paprium.mgl` from the [Releases page](https://github.com/thekoalakoa/Paprium_MiSTer/releases) of this repository (release `paprium-20261003`) and put both in `_Console` on the MiSTer SD card.
2. Copy your own ROM dump (named `Paprium.md`) and your own music file (named `paprium.pcm`) into `games/Paprium/Paprium`.

Resulting layout on the SD card:

```
_Console/Paprium.rbf                          (the core, from the release)
_Console/Paprium.mgl                          (launcher, from the release; same file as releases/Paprium.mgl)
games/Paprium/Paprium/Paprium.md              (your ROM dump)
games/Paprium/Paprium/paprium.pcm             (your music file)
```

`releases/Paprium.mgl` is the launcher. It loads `_Console/Paprium` and mounts the two files at these paths:

```
/media/fat/games/Paprium/Paprium/paprium.pcm   (mounted as the music file)
/media/fat/games/Paprium/Paprium/Paprium.md    (loaded as the ROM)
```

Start the game by launching `Paprium.mgl`.

## OSD

The OSD of the shipped core contains exactly these items:

- **Load \*.BINGENMD** - load a ROM.
- **Load \*.PCM** - load a music file.
- **TMSS** - Disabled / Enabled.
- **Paprium Arcade Mode** - Locked / Unlocked.
- **Paprium Arcade Stage** - Off, then a list of stages.
- **Audio & Video** page: Aspect Ratio, Scandoubler Fx, Vertical Crop, Crop Offset, Scale, 320x224 Aspect, Border, Composite Blend, CRAM Dots, Audio Filter, FM Chip, Stereo Mix.
- **Input** page: Swap Joysticks, 6 Buttons Mode.
- **Pause When OSD is Open** - No / Yes.
- **Mount music \*.PCM** - mount the `paprium.pcm` music file.
- **Reset** (Reset core).

The OSD also shows a Music PCM info message: mounted, invalid, ejected or buffer underrun.

There is no Hard Reset item, no Load Backup RAM / Save Backup RAM item and no Autosave item. Progress saves automatically when the OSD is opened.

## Building from source (optional)

The release files above are all you need to play. To build the rbf yourself, the project is a standard Quartus project.

1. Install Quartus Prime Lite 21.1.1 (the shipped build used this version). The device is Cyclone V `5CSEBA6U23I7`, top-level entity `sys_top`, revision `MegaDrive`, as set in `MegaDrive.qsf`.
2. Open `MegaDrive.qpf` and run a full compilation, or from the repository root run:

   ```
   quartus_sh --flow compile MegaDrive
   ```

3. The bitstream is written to `output_files/MegaDrive.rbf` (`GENERATE_RBF_FILE` is on in `MegaDrive.qsf`). Rename it to `Paprium.rbf` to use it in `_Console`.

Notes:

- `build_id.v` (the build date shown in the OSD version line) is generated at the start of every compile by `sys/build_id.tcl` and is not stored in the repository.
- The MCU firmware is stored pre-built in `rtl/PAPRIUM/mcu.txt`. The changes made to the upstream firmware are in `patches/mega-ppm-pocket.patch`, with instructions in `patches/README.md` and `scripts/build_mcu.sh`.
- `clean.bat` removes Quartus build output.

## Credits and licence

All of this comes from files already in this repository.

- Lineage (as recorded in this repository's earlier README and fork notes): [Nuked-MD-FPGA](https://github.com/nukeykt/Nuked-MD-FPGA), [MegaDrive_MiSTer](https://github.com/MiSTer-devel/MegaDrive_MiSTer), drizzt openFPGA-MegaDrive, [Paprium_MegaDrive_MiSTer](https://github.com/MisterPezz82/Paprium_MegaDrive_MiSTer), [paprium-pocket](https://github.com/thekoalakoa/paprium-pocket) and [mega-ppm](https://github.com/krikzz/mega-ppm).
- `docs/PEZZ_UPSTREAM_README.md` lists these as prior work: Krikzz / mega-ppm, adroxe / Paprium-Arcade (the Arcade Mode unlock IPS), Project Little Man, TheHpman / MAME Paprium research, MAVProxyUser / Genesis Plus GX Paprium PR, and the Paprium preservation community.
- `MegaDrive.sv` carries the header "Copyright (c) 2023 Alexey Melnikov" under the GNU General Public License, version 2 or (at your option) any later version.
- `rtl/fx68k` includes FX68K, "Copyright (c) 2018 by Jorge Cwik" (`rtl/fx68k/README.md`); its `LICENSE` is the GNU General Public License version 3.
- `rtl/nuked-md/LICENSE` is the GNU General Public License version 2.
- The earlier README's licence line read: "GPLv3 - see upstream projects."

No ROM or music file is part of this repository or of the release.