# Firmware patch against krikzz/mega-ppm

`mega-ppm-pocket.patch` applies to a clean clone of
[krikzz/mega-ppm](https://github.com/krikzz/mega-ppm) and produces the firmware
this core ships in `rtl/PAPRIUM/mcu.txt`. It touches `mcu/mame.c`, `mcu/mame.h`,
`mcu/mdp.c`, `mcu/mdp.h`, `mcu/paprium.c`, `mcu/paprium.h` and `mcu/sfx.c`.

The patch is kept here, and not only the built binary, because GPLv3 asks that a
distributed binary come with its corresponding source, and `mcu.txt` is a
compiled work. This patch is the source of the changes to it.

## Rebuilding the firmware (optional)

`scripts/build_mcu.sh` is written for Git Bash on Windows. It expects, relative to
the root of this repository:

- the patched mega-ppm clone at `../repos/mega-ppm`;
- an xPack RISC-V toolchain at `../tools/xpack-riscv-none-elf-gcc-15.2.0-1`;
- mega-ppm's `tools/bin_to_verilog.exe`.

```bash
git clone https://github.com/krikzz/mega-ppm.git ../repos/mega-ppm
cd ../repos/mega-ppm && git apply <path-to-this-repo>/patches/mega-ppm-pocket.patch
cd <path-to-this-repo> && ./scripts/build_mcu.sh
```

The script installs the result into `rtl/PAPRIUM/mcu.txt`, which Quartus reads, and
reports whether the firmware changed. Rebuilding the firmware is not needed to
build the rbf: `rtl/PAPRIUM/mcu.txt` is already in the repository.

## What the patch changes

- **`sfx.c`**: re-arms a sound channel that has already finished when looping is enabled on it afterwards.
- **`mame.c`**: replaces the format `0x81` decompressor with a port of the Genesis Plus GX `paprium_decoder_lzo` routine.
- **`mame.c`**: first-level door fix (`attr &= ~0x2000` for object 107, sprite 4), as shared by krikzz and MisterPezz82.
- **`paprium.c`, `mdp.c`, `mdp.h`**: one-shot music cues; adds `mdp_play_once()`.
- **`paprium.c`**: implements the `0x88 audio_setting` command, as Genesis Plus GX does (`paprium_audio_setting`).

## Build notes

- `-march=rv32im_zicsr_zifencei`: GCC 15 split CSR and FENCE.I out of the base ISA. krikzz's Makefile says plain `rv32im`.
- The script builds at `-O2` by default; `-Os` can be passed as the first argument.