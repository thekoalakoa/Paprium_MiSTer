# Cartridge firmware

From 0.3.0 the cart's chip runs our own firmware, **Little-Man Firmware**. Our team wrote it from our own study of how the cart behaves. It is GPL-3.0-or-later.

On MiSTer the firmware is not built into `Paprium.rbf`. The bitstream only keeps a small boot stub. **Paprium.mgl** loads **Little-Man Firmware 1.0** from:

```
games/Paprium/little_man_firmware.bin
```

It is not auto-loaded by MiSTer by filename. That is the same firmware file, under the same name, that the Pocket core ships. The 0.3.0 release zip puts it in place already named. If the file is missing, damaged, or was made for a different core version, the screen goes plain red and the game does not start. See [INSTALL.md](../INSTALL.md).

The firmware source is in the Pocket repository's [`firmware/`](https://github.com/thekoalakoa/paprium-pocket/tree/v0.3.0/firmware) folder, with its own design docs and `THIRD_PARTY_NOTICES.md`. To rebuild the file, follow the build steps there.

## The CPU MATE brain is not in the repository

Little-Man Firmware holds three things: the firmware itself, our MegaWire code, and the brain of the game's CPU MATE partner. The brain is a reverse-engineered emulation of the game's CPU partner. It is made from the game's own code, so it does not belong in git.

It ships inside `little_man_firmware.bin`. For people who rebuild the firmware, the brain files are a separate release download. They are the same three files as before (`brain.bin`, `cf.bin`, `rodata.bin`). Unpack them outside the repository, or in `cpu-mate-brain/` at the top of a clone, which git ignores. Never commit them, and never commit a built `little_man_firmware.bin`. Also ignore a leftover `LittleMan.bin` from an earlier test name.

A firmware file built without the brain still runs the game, but the partner just stands there.

## Building the core

Once `little_man_firmware.bin` is on the card (Paprium.mgl loads it when you launch the core), or you have the Pocket firmware build, compile the bitstream with Quartus Prime Lite 21.1.1:

```bash
quartus_sh --flow compile MegaDrive
```

Rename `output_files/MegaDrive.rbf` to `Paprium.rbf` for `_Console`. A fresh fit is not guaranteed to match the released bitstream bit for bit. The `Paprium.rbf` in the release zip is the reference.

## Before 0.3.0

0.2.x built krikzz's [mega-ppm](https://github.com/krikzz/mega-ppm) at its pinned commit `84be6bd` with `patches/mega-ppm-pocket.patch`. [patches/README.md](../../patches/README.md) is the record of that work. That build produced four memory init files (`rtl/PAPRIUM/mcu.txt`, `mcu_ext.txt`, `wram_hi.txt`, `wram_lo.txt`) from the brain download `cpu-mate-brain_0.2.6.zip`. Those init files are still git-ignored, because they contain the brain. The 0.2.6 build script, `scripts/build_mcu.sh`, is kept for that history. 0.3.0 does not use it, or a `--mega-ppm` step, for the shipping firmware.
