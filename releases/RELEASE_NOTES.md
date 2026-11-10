# Paprium for MiSTer 0.3.0

This release mirrors [Paprium for Analogue Pocket 0.3.0](https://github.com/thekoalakoa/paprium-pocket/releases/tag/v0.3.0), adapted for MiSTer.

**Downloads**
- `Paprium_MiSTer_0.3.0.zip`: the core. It puts `Paprium.rbf` and `Paprium.mgl` in `_Console`, and Little-Man Firmware 1.0 in `games/Paprium/little_man_firmware.bin`.

**Before you install, back up your save** (`saves/Paprium/Paprium.sav`) to your PC. On the first start we convert a 0.2.x save, once, into the cartridge's own format. Then follow [docs/INSTALL.md](https://github.com/thekoalakoa/Paprium_MiSTer/blob/main/docs/INSTALL.md).

## The short version

0.3.0 makes the core act like the real cartridge. The music is made the way the cartridge makes it, in both of the game's sound options (YM and Datenmeister), so you don't need a soundtrack file anymore. The cartridge's chip runs our own firmware, Little-Man Firmware 1.0. Our team wrote it from our own study of how the cart behaves. Each start takes longer while the core unpacks the game's sounds from your copy of the game. There is no progress bar, and no sound-cache file is kept, so this happens every time you launch the core.

## Install

1. Unzip `Paprium_MiSTer_0.3.0.zip` onto the SD card. It replaces `_Console/Paprium.rbf` and `_Console/Paprium.mgl`, and puts the firmware at `games/Paprium/little_man_firmware.bin`.
2. Keep your `Paprium.md` where it is, in `games/Paprium/Paprium/`. No game or music is included.
3. Launch `Paprium.mgl`. It loads the firmware first, then the game:

   ```
   <mistergamedescription>
       <rbf>_Console/Paprium</rbf>
       <!-- 0.3.0: load the Little-Man firmware first, from games/Paprium/little_man_firmware.bin, through the OSD's "Load Little-Man Firmware" row (F4), then the game. -->
       <file delay="1" type="f" index="4" path="/media/fat/games/Paprium/little_man_firmware.bin"/>
       <file delay="1" type="f" index="1" path="/media/fat/games/Paprium/Paprium/Paprium.md"/>
   </mistergamedescription>
   ```

   The firmware is not auto-loaded by MiSTer by filename.

You can delete `paprium.pcm`, and the `paprium.cue` next to it. 0.3.0 doesn't use either. If you might go back to 0.2.6, keep them, because 0.2.6 needs the soundtrack for music. If you still have a `boot1.rom` or `LittleMan.bin` in `games/Paprium/` from an earlier test build, you can delete it. A leftover `config/Paprium.s1` is only Main's memory of the old 0.2.6 soundtrack pick; 0.3.0 doesn't use it, and you can delete it too.

**If the screen stays plain red**, Paprium.mgl couldn't load a good `little_man_firmware.bin`. Copy the file from this release into `games/Paprium/little_man_firmware.bin` and start the core again from Paprium.mgl. The game won't start until that file is right.

## New

- **The music, made the way the cartridge makes it.** We rebuilt the cartridge's sound chip in the core's logic, and our music player runs in the firmware the way the cartridge's does. So the music follows the game like it does on a cart: the low-health music, the sax man's cues, the Boom Box's X, Y and Z effects and the fades.
- **Sound effects on our rebuild of the cartridge's synthesiser**, filter and echo included.
- **Little-Man Firmware**, our own firmware for the cartridge's chip, now its own file. On MiSTer it lives at `games/Paprium/little_man_firmware.bin`, and Paprium.mgl loads it. It holds the firmware, our MegaWire code and the CPU MATE partner's brain. It's GPL-3.0-or-later, and the source is in the Pocket repo's `firmware/` folder. If the file is missing, damaged, or was made for a different core version, the screen goes plain red and the game won't start (see INSTALL).
- **A longer start.** The core unpacks the game's sounds from your copy of the game. The screen stays black while it does that, with no progress bar. MiSTer does not keep a sound-cache file, so the unpack happens every time you launch the core.
- **Arcade Mode is now a virtual Grand Stick III**, with Off, On, Multiplayer and Stick Only. On and Multiplayer flip the stick's ARCADE switch, so the game turns on its own arcade mode with no change to the ROM. Mode drops a coin, and like a real stick, the first coin after power-on or a reset doesn't give a credit. Stick Only is the stick with every switch off: the normal game, with Mode as the stick's Mode button. Also new: **Arcade Coins** and **Attract Only**.
- **3-Player Mode** (Off by default): an EA 4-Way Play, for the game's three-player modes with three controllers.
- **TeraDrive** in the Console list.
- **Load Little-Man Firmware** in the OSD, for testing a firmware file by hand. Normal play just uses `little_man_firmware.bin`, loaded by Paprium.mgl.

The CPU MATE partner, the Scum! cheats, and the console and Mega CD options from 0.2.6 are all still here. The old diagnostic rows, and the separate Console Reset, are gone. The regular **Reset** in the OSD still does a full reset, cart included, and so does the **USER** button on the MiSTer.

## Changed (read this before you upgrade)

- **Saves** now use the cartridge's own format: 8 KB, the size of the cart's save chip. We convert a 0.2.x save once, on the first start. We haven't tested going back to 0.2.x with a converted save, so keep a copy of your 0.2.x save.
- **No more soundtrack file.** 0.3.0 doesn't read `paprium.pcm` or `paprium.cue`, so you can delete them (0.2.6 still needs them).
- **The OSD is simpler.** The old diagnostic rows, and the separate Console Reset, are gone. **Reset** and the **USER** button both do a full reset.
- **6-Button Mode** gives the game real six-button pads on controllers 1 and 2, and the game reads X, Y, Z and Mode itself.
- **The cartridge's watchdog is back.** With the OSD closed, if the game stops sending its once-a-frame signal for about 4 seconds, the cartridge's chip halts, same as a real cart.
- **Sprites, zooms, unpacking the game's data, saves and start-up** now work the way the cartridge does them.
- **Sprites use the cartridge's colours.** Dice's afterimage outline is green like on the cart (0.2.x drew it blue), and the first level's doorway takes its colours from the cartridge's own rule.

## Fixed

- **Hall of Fame name entry**: the highlight bar is clean with Arcade Stage or 6-Button Mode on (a 0.2.6 known issue, verified on the pass 10 hardware run).
- **The Arcade coin** plays the game's coin sound on every press.
- **TMSS**, the licence check later consoles run at power-on, works on every all-in-one Mega CD unit (Wondermega, Wondermega M2 / X'Eye, LaserActive, Aiwa CSD-GM1, CDX).

## Where we differ from the original cartridge

These are the differences you might notice. Each one is on purpose.

- **Starting takes longer.** The core holds the game until the cartridge's chip is ready, checks the firmware file, and unpacks the game's sounds from your copy of the game. There is no progress bar, and no sound-cache file is kept, so the unpack happens every time you launch the core.
- **The OSD** can pause the game while it is open. The cart's watchdog stops counting while the menu is open.
- **Datenmeister's output**: we don't copy what the cartridge's output circuit does to the sound. Instead there's a plain stand-in: one volume, and a filter that only removes a steady offset (below 4 Hz).
- **Corners the game never reaches**, like asking for more than 53 sprite slots, are handled safely here. The cart's chip would read or write unrelated memory of its own.
- **MegaWire details only a module would ever see**: the server name stored for a module is `www.koalakoa.com`, and the restart command in the game's own MegaWire menu doesn't save a MegaWire record.

## Known issues

- **Audio & Video page:** Aspect Ratio, Scandoubler Fx, Audio Filter, FM Chip and Stereo Mix may have little or no effect, or may disturb video sync.
- A first launch with no save file starts at the mini-game. That is the cart's own behaviour. Hit Reset after it.

## Hashes

These are the files in `Paprium_MiSTer_0.3.0.zip`. The rbf is the pass 10 build that was checked on hardware. The mgl loads `little_man_firmware.bin`. The firmware is Little-Man Firmware 1.0, the same file published with Pocket 0.3.0; the copy in the zip is the one from the card that ran that check.

| file | bytes | md5 | SHA-256 |
|---|---|---|---|
| `Paprium_MiSTer_0.3.0.zip` | 1,836,591 | `9e59857b77f00c1b4b3eb7fb6a3a3fd2` | `41e54544f820e57309484278718e1faaa1be1ee1dad7238e4fc75106ed94e4d7` |
| `_Console/Paprium.rbf` | 4,179,336 | `d1b2f73f029f8cf753700327d7b0ffb1` | `9e259a7e791b6f601fce3a3e914eef38f2854e1fa676bca7d59a45008d3e998a` |
| `_Console/Paprium.mgl` | 440 | `7e7c47496937a24440202ffcc13f48ef` | `0b3ca982c5f629c997403831dff2b866dd21363f195babf166d40f8046ec67dc` |
| `games/Paprium/little_man_firmware.bin` (Little-Man Firmware 1.0) | 262,144 | `f8cda67209d0e4d35beb077ae88fb16b` | `6fb90204322c6a5596bfb4d3a743696cbdced5744cf8d4b9f09aa9fc322873e2` |

## Source and licence

- GPL-3.0-or-later. The firmware source (apart from the CPU MATE brain, see the README's Licence section) is in the [paprium-pocket](https://github.com/thekoalakoa/paprium-pocket) repository at tag `v0.3.0`, in its `firmware/` folder.
- What the core is built on, and the notices for parts under other licences: see the README's Lineage, History and Licence sections and `THIRD_PARTY_NOTICES.md` in the repo.
- Under other licences, each with its full notice in `THIRD_PARTY_NOTICES.md`: BSD-3-Clause for krikzz's mega-ppm code in the cartridge logic, and for mega-ppm code this release's firmware file still carries from 0.2.6, and for the NEORV32 processor; Conifer Software's BSD licence for the WavPack decoder and BSD-2-Clause for newlib's `memcpy` / `memset` (both in the firmware file). Nuked-MD-FPGA (GPLv2-or-later) and FX68K (GPLv3) keep their own licence files in the source. VM2413 is under its own original terms, not the GPL.
- Copyright (C) 2026 Marsupial Solutions LLC. Made by Marsupial Solutions LLC: bJam, Freya, Isa, Spec and Koalakoa.
- Little-Man Firmware (trademark pending) is Marsupial Solutions LLC's name for this firmware.
- You bring your own copy of the game. The ROM, and anything taken from it, never ships: not in this repo, not in this release, not in any download.
- Paprium is a trademark of its owners. This project is not affiliated with WaterMelon. It is a free, non-commercial project: it is not sold, and the game is not included.

## Building it yourself

Players do not need this. The firmware is already in `games/Paprium/little_man_firmware.bin`.

The firmware is no longer built into the bitstream, so building the core is:

```bash
quartus_sh --flow compile MegaDrive
```

The release bitstream was fitted with seed 1, which is what `MegaDrive.qsf` says, so that command uses the same seed. To rebuild the firmware file, use the Pocket `firmware/` tree and the CPU MATE brain download, which is not in the repository. See [docs/firmware/README.md](https://github.com/thekoalakoa/Paprium_MiSTer/blob/main/docs/firmware/README.md). A fresh fit is not guaranteed to reproduce the released bitstream bit for bit; the `Paprium.rbf` in the release zip is the reference.

## Credits

This core is a port of the [Paprium Pocket core](https://github.com/thekoalakoa/paprium-pocket): the music and sound rebuild, Little-Man Firmware, the CPU MATE, the Scum! options, the console and Mega CD options and the fixes come from it. The rest of the lineage is in the [README](https://github.com/thekoalakoa/Paprium_MiSTer#lineage).
