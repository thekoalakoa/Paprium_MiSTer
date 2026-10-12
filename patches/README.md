# Firmware patch against krikzz/mega-ppm

`mega-ppm-pocket.patch` applies to a clean clone of
[krikzz/mega-ppm](https://github.com/krikzz/mega-ppm) at commit `84be6bd` and
produces the cartridge MCU firmware source of this core (0.2.6). It touches
`mcu/appmain.h`, `mcu/mame.c`, `mcu/mame.h`, `mcu/mdp.c`, `mcu/mdp.h`,
`mcu/paprium.c`, `mcu/paprium.h` and `mcu/sfx.c`, and adds the CPU MATE buddy
glue: `mcu/buddy.h`, `mcu/zz_buddy.c`, `mcu/zz_buddy_trap.c` and
`mcu/zz_buddy_brain.c` (the buddy program's entry table).

The patch is kept here because GPLv3 asks that a distributed binary come with its
corresponding source, and the MCU memory init files built into the rbf are a
compiled work. This patch is the source of the firmware part of them.

## Building the firmware

The four memory init files Quartus reads (`rtl/PAPRIUM/mcu.txt`, `mcu_ext.txt`,
`wram_hi.txt`, `wram_lo.txt`) are **not** in this repository, because they contain
the CPU MATE brain, which ships as the release download `cpu-mate-brain_0.2.6.zip`.
See [`docs/firmware/README.md`](../docs/firmware/README.md).

```bash
git clone https://github.com/krikzz/mega-ppm.git ../repos/mega-ppm
./scripts/build_mcu.sh --brain cpu-mate-brain
```

## What the patch changes

- **`sfx.c`**: re-arms a sound channel that has already finished when looping is enabled on it afterwards.
- **`mame.c`**: replaces the format `0x81` decompressor with a port of the Genesis Plus GX `paprium_decoder_lzo` routine.
- **`mame.c`**: first-level door fix (`attr &= ~0x2000` for object 107, sprite 4), as shared by krikzz and MisterPezz82.
- **`mame.c`, `mame.h`**: 0.2.6 sprite and streaming fixes (Solarium float, credits, elevator background, sprite cache), each behind its own `PPM_*` switch in `mame.h`; debug output is off in the release build (`PPM_RELEASE`).
- **`paprium.c`, `mdp.c`, `mdp.h`**: one-shot music cues; adds `mdp_play_once()`.
- **`paprium.c`**: implements the `0x88 audio_setting` command, as Genesis Plus GX does (`paprium_audio_setting`); the in-game restart command (`0xA8`); the Console and MegaWire options read at MCU boot.
- **buddy glue**: runs the CPU MATE buddy program on the MCU when a Mega CD unit is selected; with CD Model None the firmware runs as without it.

## Build notes

- `-march=rv32im_zicsr_zifencei`: GCC 15 split CSR and FENCE.I out of the base ISA. krikzz's Makefile says plain `rv32im`.
- Release flags: `-O2 -DPPM_RELEASE=1 -DBUDDY_LINKED_BRAIN=1 -DBUDDY_STUB_BRAIN=0 -DBUDDY_TRAP_TRAMP=1`.
