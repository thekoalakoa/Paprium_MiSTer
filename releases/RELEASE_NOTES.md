# Paprium for MiSTer 0.3.1

**Downloads**
- `Paprium_MiSTer_0.3.1.zip`: the core. It puts `Paprium.rbf` and `Paprium.mgl` in `_Console`, and Little-Man Firmware 1.0 in `games/Paprium/little_man_firmware.bin`.

**Before you install, back up your save** (`saves/Paprium/Paprium.sav`) to your PC. If you are coming from 0.2.x, the first start converts a 0.2.x save, once, into the cartridge's own format. Then follow [docs/INSTALL.md](https://github.com/thekoalakoa/Paprium_MiSTer/blob/main/docs/INSTALL.md).

## The short version

0.3.1 is a MiSTer update on 0.3.0. The scaler filters work again, including polyphase, adaptive and HQ2x. Firmware and ROM loading is more reliable. There are also timing fixes so the picture stays solid. The game, the music and Little-Man Firmware 1.0 are the same as in 0.3.0.

## Install

1. Unzip `Paprium_MiSTer_0.3.1.zip` onto the SD card. It replaces `_Console/Paprium.rbf` and `_Console/Paprium.mgl`, and puts the firmware at `games/Paprium/little_man_firmware.bin`.
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

You can delete `paprium.pcm`, and the `paprium.cue` next to it. From 0.3.0 on, the core doesn't use either. If you might go back to 0.2.6, keep them, because 0.2.6 needs the soundtrack for music. If you still have an old test firmware file in `games/Paprium/` under another name, you can delete it. A leftover `config/Paprium.s1` is only Main's memory of the old 0.2.6 soundtrack pick; from 0.3.0 on the core doesn't use it, and you can delete it too.

**If the screen stays plain red**, Paprium.mgl couldn't load a good `little_man_firmware.bin`. Copy the file from this release into `games/Paprium/little_man_firmware.bin` and start the core again from Paprium.mgl. The game won't start until that file is right.

## Fixed

- **Scaler filters work again.** Polyphase, adaptive and HQ2x are back, along with the other Scandoubler Fx choices. On 0.3.0 those filters could do little or nothing, or disturb the picture.
- **Firmware and ROM loading is more reliable.** The core waits until the firmware has actually loaded before it starts the cart. If you pick a firmware file with a `.ROM` extension from the OSD, it loads now.
- **Timing fixes** so the picture stays solid.

## Where we differ from the original cartridge

These are the differences you might notice. Each one is on purpose.

- **Starting takes longer.** The core holds the game until the cartridge's chip is ready, checks the firmware file, and unpacks the game's sounds from your copy of the game. There is no progress bar, and no sound-cache file is kept, so the unpack happens every time you launch the core.
- **The OSD** can pause the game while it is open. The cart's watchdog stops counting while the menu is open.
- **Datenmeister's output**: we don't copy what the cartridge's output circuit does to the sound. Instead there's a plain stand-in: one volume, and a filter that only removes a steady offset (below 4 Hz).
- **Corners the game never reaches**, like asking for more than 53 sprite slots, are handled safely here. The cart's chip would read or write unrelated memory of its own.
- **MegaWire details only a module would ever see**: the server name stored for a module is `www.koalakoa.com`, and the restart command in the game's own MegaWire menu doesn't save a MegaWire record.

## Known issues

- **Audio & Video page:** Audio Filter, FM Chip and Stereo Mix may still have little or no effect. Scaler filters, including polyphase, adaptive and HQ2x, are fixed in 0.3.1.
- A first launch with no save file starts at the mini-game. That is the cart's own behaviour. Hit Reset after it.

## Hashes

These are the files in `Paprium_MiSTer_0.3.1.zip`. The rbf is the 0.3.1 build. The mgl loads `little_man_firmware.bin`. The firmware is Little-Man Firmware 1.0, the same file published with Pocket 0.3.0 and with MiSTer 0.3.0.

| file | bytes | md5 | SHA-256 |
|---|---|---|---|
| `Paprium_MiSTer_0.3.1.zip` | 1,852,348 | `b9b88aa25c11d64125f035899e89e2ea` | `0764224a60d2192e7713237d35bccb6738fe5f74a8dd8842125761b12a5b37e3` |
| `_Console/Paprium.rbf` | 4,181,200 | `d30776f49e6b7a64ba8cec1961ecb28a` | `a24f78b319f3750e8ca7baf19993563f4c2d2e8191bf1b3e50981400658bb857` |
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

This core is a port of the [Paprium Pocket core](https://github.com/thekoalakoa/paprium-pocket): the music and sound rebuild, Little-Man Firmware, the CPU MATE, the Scum! options, the console and Mega CD options and the fixes come from it. 0.3.1 is a MiSTer update on that port. The rest of the lineage is in the [README](https://github.com/thekoalakoa/Paprium_MiSTer#lineage).
