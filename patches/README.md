# Firmware patches against krikzz/mega-ppm

`mega-ppm-pocket.patch` is our change to
[krikzz/mega-ppm](https://github.com/krikzz/mega-ppm) at commit `84be6bd`. It
produces the firmware this core shipped in `rtl/PAPRIUM/` (`mcu.txt`,
`mcu_ext.txt`, `wram_hi.txt`, `wram_lo.txt`) up to 0.2.6. This folder is the
record of that work.

Up to 0.2.6, the firmware changes were patches on top of krikzz's
[mega-ppm](https://github.com/krikzz/mega-ppm). They're in this folder and
rebuild that firmware from a clean mega-ppm clone. From 0.3.0 on, the cart's
chip runs our own firmware, Little-Man Firmware: see the README's
[Little-Man Firmware](../README.md#little-man-firmware) section. This patch
is not the 0.3.0 firmware.

```bash
git clone https://github.com/krikzz/mega-ppm.git <folder>
./scripts/build_mcu.sh --mega-ppm <folder>  # 0.2.6's build_mcu.sh: applies the patch to 84be6bd itself
```

That command is how the 0.2.6 firmware was rebuilt. It is not a step in a
0.3.0 build. `build_mcu.sh` (the 0.2.6 script) reads the pinned commit with
`git archive`, so the clone itself is never modified, applies the patch in its
own build folder, and installs the four images into `rtl/PAPRIUM/`. The four
memory init files Quartus read for 0.2.6 are not in this repository, because
they contain the CPU MATE brain, which shipped as the release download
`cpu-mate-brain_0.2.6.zip`. See the history section of
[`docs/firmware/README.md`](../docs/firmware/README.md).

The patch is kept here rather than the built binary alone because GPLv3 asks
that a distributed binary come with its corresponding source, and the 0.2.6
images are a compiled work. This is the source of our changes to it. Our
changes are Copyright (C) 2026 Marsupial Solutions LLC and are licensed
GPLv3-or-later, like the rest of this core. The mega-ppm code they change
stays BSD-3-Clause, Copyright (c) 2025 krikzz; its notice is in
THIRD_PARTY_NOTICES.md.

## What the patch changed in 0.2.6

- **`sfx.c`**: re-arms a sound channel that has already finished when looping is enabled on it afterwards.
- **`mame.c`**: swaps one of the data unpackers for a port of Genesis Plus GX's Paprium decoder.
- **`mame.c`**: first-level door fix (`attr &= ~0x2000` for object 107, sprite 4), as shared by krikzz and MisterPezz82.
- **`mame.c`, `mame.h`**: 0.2.6 sprite and streaming fixes (Solarium float, credits, elevator background, sprite cache), each behind its own `PPM_*` switch in `mame.h`; debug output is off in the release build (`PPM_RELEASE`).
- **`paprium.c`, `mdp.c`, `mdp.h`**: one-shot music cues; adds `mdp_play_once()`.
- **`paprium.c`**: implements the in-game audio setting and restart commands, and the Console and MegaWire options read at MCU boot.
- **buddy glue**: runs the CPU MATE buddy program on the MCU when a Mega CD unit is selected; with CD Model None the firmware runs as without it.

## 0.2.6 build notes

- `-march=rv32im_zicsr_zifencei`: GCC 15 split CSR and FENCE.I out of the base ISA. krikzz's Makefile says plain `rv32im`.
- Release flags: `-O2 -DPPM_RELEASE=1 -DBUDDY_LINKED_BRAIN=1 -DBUDDY_STUB_BRAIN=0 -DBUDDY_TRAP_TRAMP=1`.
