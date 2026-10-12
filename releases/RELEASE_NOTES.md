The game's **CPU MATE** partner on MiSTer, a menu of cheats, arcade and console options, and the
end-credits and Solarium bugs fixed by doing what the original cartridge does. This release mirrors the
[Paprium Pocket core 0.2.6](https://github.com/thekoalakoa/paprium-pocket/releases/tag/0.2.6), adapted for MiSTer.

## Install

Unzip `Paprium_MiSTer_0.2.6.zip` onto the SD card: it puts `Paprium.rbf` and `Paprium.mgl` in `_Console`,
replacing the old files. Your saves and settings carry over. You need the `paprium.pcm` and `Paprium.md` you
already use, in `games/Paprium/Paprium/`; no ROM or music is included. Launch `Paprium.mgl`.
Everything new is **off by default**. With the defaults, the one menu-level difference from the previous
release is that the game no longer shows a MegaWire as connected, which is what a real cartridge does with
nothing plugged in.

## New

**CPU MATE.** With a Mega CD unit chosen in the OSD, Paprium offers its computer-controlled partner, as it
does on a real Mega Drive with a Mega CD:

1. OSD, **SCUM! (Needs Reset)** page: **CD Model** = any unit except None or Unknown, then **Reset**.
2. In the game's Options, switch **CPU MATE** on.
3. At character select, bring the partner in:
   - **With one controller:** turn **6-Button Mode** on (SCUM! (Needs Reset) > Grand Stick Options).
     **Hold Mode** to add the partner; still holding it, move the partner's cursor with the D-pad and press
     **Start** to pick its character. Release Mode to pick your own. It is the game's own six-button control
     with a Mega CD ([Paprium FAQ](https://www.wafflenet.com/paprium.html#questions)).
   - **With a second controller:** press **Start on controller 2**, and again to pick its character.

On the real thing the partner's AI runs on the Mega CD's sub-CPU. Here it is the game's own AI program,
re-implemented to run on the cartridge MCU, behind a Mega CD link that hands the game the partner's moves at
the moment the real sub-CPU would. The game's code is not patched. The brain is built into `Paprium.rbf`;
nothing extra to download to play.

**SCUM! (Needs Reset)**, the new OSD page (change, then Reset):

| Entry | What it does |
|---|---|
| **Grand Stick Options** > **6-Button Mode** | X, Y, Z and Mode reach the game |
| **Grand Stick Options** > **Swap Joysticks** | Swaps controllers 1 and 2 |
| **Grand Stick Options** > **Arcade Mode** | The game's hidden ARCADE PAPRIUM mode (credits, friendly fire). **Mode inserts a coin** |
| **Grand Stick Options** > **Arcade Stage** | The stage Arcade Mode starts on |
| **Little-Man** > **Infinite Life** | Players take no damage, specials cost none; enemies unaffected |
| **Little-Man** > **Infinite Pills** | Blu pills are not spent |
| **Little-Man** > **Infinite Lives** | Lives are not spent |

Nothing touches your ROM file: while a switch is on, the cartridge serves a few replacement words in place of
the game's own, like a Game Genie in the FPGA.

**The machine the game sees**, on the same page, each read at boot (change, then Reset):

| Entry | Choices |
|---|---|
| **Console** | Mega Drive (default), Genesis, Mega Drive 2, Genesis Model 2, Genesis 3, Nomad, Mega Jet, Unknown. Sets the region and the console picture in the Boom Box; the TMSS models boot with no licence screen |
| **CD Model** | None (default), Mega-CD / Sega CD, Mega-CD 2 / Sega CD 2, Wondermega, Wondermega M2 / X'Eye, LaserActive, Aiwa CSD-GM1, CDX, Unknown. Each with its splash and region |
| **32X Mode** | The game believes a 32X is attached; some throwables become 32X boxes |
| **MegaWire4.0** | Off by default, which is what a real cartridge reports with nothing plugged in: MODEM : NONE, no MegaWire icon. Every earlier release showed a MegaWire as connected; On brings that back |

## Fixed

**Enemies that could not be killed, and Pang's KTV Member Card going missing.** When enemies dropped in from
above after a food pickup, an enemy could turn invisible and unkillable and stop the screen scrolling, so the
section could not be finished. In Original mode, beating Pang at Golden Of Seas earns his KTV Member Card, the
pass the bouncer at Digniti KTV asks for. Without it the run ends at Digniti KTV with "THE END?", before The
Vault, Sanophix Labs, The Solarium and the ending, as it does on a real cartridge. Here, Pang still handed the
card over on screen, but it was not always kept in the save. The core's cartridge memory stored single-byte
writes from the console, which a real cartridge does not, so the game's own check of the cartridge concluded
it was not genuine and, until the game was reset or switched off, did both. The cartridge memory now ignores
single-byte writes, and the check passes as it does on a real cartridge. A save that lost the card under an
earlier release does not get it back by itself: clear Golden Of Seas once more in Original mode. Every
earlier release had this.

**The end credits.** After the Bishop fight, sparkles were drawn as squares of background art, and the
credits pictures had damaged tiles. The firmware's sprite cache now works the way the original cartridge's
does, and the sparkle lands clear of the background every time.

**The Solarium float.** At the end of the game, characters froze in mid-walk and floated across the camera
pan. The sprite table is now closed the cartridge's way, with an end mark.

**Freezes in busy fights.** A character could freeze in a pose when its new pose's art was refused a slot.
With the new cache, and the DMA budget and pose hold following the cartridge, a pose that does not fit is held
whole or pre-loaded over a few frames, never drawn in part.

**Animation, the cartridge's way.** When the firmware takes a queued animation, it writes it back into the
game's object record, as the cartridge does, so a dropped weapon settles and a character walking in keeps
walking.

**The Boom Box bars** run at the measured tempo instead of about 20% fast.

## Under the hood

- SDRAM refresh: idle refresh every 838 clocks (counter 836, second refresh at 418), 7.80 us at 107.386 MHz.
- The release firmware compiles all debug output out.
- Fit: seed 3, 26,541 ALM, 393 M10K, worst setup −0.583 ns, hold passes.

## Tested

The previous test build passed the 17-item hardware checklist on 10/10. The final build, with the
cartridge-memory fix, passed a hardware test on a real MiSTer before release.

## Known issues

- The music is the released soundtrack (`paprium.pcm`) rather than the cartridge's own live synthesiser.
- **Audio & Video page:** **Aspect Ratio** seems to do nothing; **Scandoubler Fx** can lose sync; the effect
  of **Audio Filter**, **FM Chip** and **Stereo Mix** is unclear.
- **Hall of Fame name entry, with Arcade Mode, Arcade Stage or 6-Button Mode on:** the blinking bar on the
  entry row can show garbage, worst at the left edge where the initials go, and may miss a press. This is the
  same replacement-word code as the Pocket core's, so the same issue applies. Little-Man alone does not do it.
- **After changing Console or CD Model, a second Reset may be needed** for the correct console picture. Change
  the setting first, then Reset; if it looks wrong, Reset again.

## Building it yourself: the CPU MATE brain download

Players do not need this; the brain is already in `Paprium.rbf`.

The partner's brain is made from the game's own code, so it is not in the repository. It is the second asset
of this release, **`cpu-mate-brain_0.2.6.zip`**: three files and a short README. It is the same brain as the
Pocket core's 0.2.6, byte for byte.

| file | md5 |
|---|---|
| `brain.bin` | `1b64e14d710e8768d3385d1421162bc7` |
| `cf.bin` | `a5fa37b435f26f9fc2c8fd62d218d7ef` |
| `rodata.bin` | `5b1d74f454b578196ed1e82548f01b99` |

Unzip it in the top folder of your clone. It makes `cpu-mate-brain/`, which the repository ignores (any other
folder works too, with `--brain <folder>`). Then build:

```bash
./scripts/build_mcu.sh --brain cpu-mate-brain    # checks the md5s; installs the MiSTer release firmware
quartus_sh --flow compile MegaDrive              # seed 3, set in MegaDrive.qsf
```

With the brain, `build_mcu.sh` gives the MiSTer 0.2.6 firmware images byte for byte: `mcu.txt` `47644152`,
`mcu_ext.txt` `4c23775c`, `wram_hi.txt` `3fe6acc4`, `wram_lo.txt` `256d3b2a`. The four images contain the
brain, so they are git-ignored; never commit them. The brain zip's own README describes the Pocket build; on
MiSTer use the commands above. A fresh fit is not guaranteed to reproduce the released bitstream bit for bit;
the `Paprium.rbf` in the release zip is the reference. Details:
[docs/firmware/README.md](https://github.com/thekoalakoa/Paprium_MiSTer/blob/main/docs/firmware/README.md).

## Checksums

| file | bytes | md5 | SHA-256 |
|---|---|---|---|
| `Paprium_MiSTer_0.2.6.zip` | 1,929,372 | `ea3396b39d3ca571516fbf9227b99d05` | `a905159da93f9e01ade8eb343fe1ebef6ac2cf0c309b8e04b6d3c4a36f32e5b6` |
| &nbsp;&nbsp;`_Console/Paprium.rbf` | 3,912,644 | `86c1447eae06ae154a804d75ff0892b7` | `8f6f048cd93678d6a47c8ec66bd0f553e2ffe6034128dfaf4b7399c29ce6fb51` |
| &nbsp;&nbsp;`_Console/Paprium.mgl` | 266 | `b9bcd0006761c30919115c956c1942d5` | `271f4d172683e54cb4233596cd64b13c3d081051fad5a50e1ed8d414521f9974` |
| `cpu-mate-brain_0.2.6.zip` | 21,372 | `ebdb2367c45b7a8168a83070f3447d10` | `341b3d0cabb996bbcc6c10ccc356c288b528c2934b6620231ef95dbf32159075` |
| &nbsp;&nbsp;`cpu-mate-brain/brain.bin` | 32,652 | `1b64e14d710e8768d3385d1421162bc7` | `bdb2fa1de464f38e6dd0e04ebdaab3a2f890e7f84bc6021a258e333d03b92162` |
| &nbsp;&nbsp;`cpu-mate-brain/cf.bin` | 5,328 | `a5fa37b435f26f9fc2c8fd62d218d7ef` | `c2bd564659b1e425f391de2e1fc286abfd944e2f5070b7d9786a3bc08d6926f2` |
| &nbsp;&nbsp;`cpu-mate-brain/rodata.bin` | 1,336 | `5b1d74f454b578196ed1e82548f01b99` | `5ce54fe2b6307ffc8cc374c665ee3dae217a65e75c6ebc031c2595e3a47b0ad5` |

## Credits

This core is a port of the [Paprium Pocket core](https://github.com/thekoalakoa/paprium-pocket): the CPU MATE,
the Scum! options, the console and Mega CD options, the cartridge-memory fix and the firmware fixes come from
it. The arcade unlock and the Mode-button coin are [adroxe](https://github.com/adroxe/Paprium-Arcade)'s; the
arcade start-stage word was found by krikzz; ROM-read patches, the pad hook and the stage names come from
[MisterPezz82](https://github.com/MisterPezz82/Paprium_MegaDrive_MiSTer)'s Paprium MiSTer core. The cartridge
MCU runs krikzz's [mega-ppm](https://github.com/krikzz/mega-ppm) firmware on Stephan Nolting's
[NEORV32](https://github.com/stnolting/neorv32), both BSD-3-Clause. The Mega Drive core is nukeykt's
[Nuked-MD-FPGA](https://github.com/nukeykt/Nuked-MD-FPGA), the 68000 is Jorge Cwik's
[FX68K](https://github.com/ijor/fx68k), on the [MiSTer](https://github.com/MiSTer-devel) framework. The rest of
the lineage is in the [README](https://github.com/thekoalakoa/Paprium_MiSTer#credits).
