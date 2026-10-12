# MCU firmware

The cartridge's MCU runs krikzz's [mega-ppm](https://github.com/krikzz/mega-ppm) firmware on the core's NEORV32
(RISC-V) soft CPU. This repository carries our changes as one patch against mega-ppm's pinned commit `84be6bd`
(`patches/mega-ppm-pocket.patch`), plus the tools that build it into the four memory init files the RTL reads:

| image | what | read by |
|---|---|---|
| `rtl/PAPRIUM/mcu.txt` | IROM, first 32 KB | `mcu_core.sv` (`$readmemh`) |
| `rtl/PAPRIUM/mcu_ext.txt` | IROM extension, 22 KB | `mcu_core.sv` |
| `rtl/PAPRIUM/wram_hi.txt` | cart WRAM, even bytes (16,384 lines) | `memory.sv` |
| `rtl/PAPRIUM/wram_lo.txt` | cart WRAM, odd bytes | `memory.sv` |

The IROM is 54 KB: the first 32 KB plus a 22 KB extension. The CPU MATE brain (below) fills it from 0x5360; the
firmware's own code sits under it, and a few boot-only functions after it. The CPU MATE glue runs from a code window
in the cart WRAM (0x2C00-0x6BFF). `scripts/firmware/paprium_mcu.ld` places all of it.

## The CPU MATE brain is not in the repository

The CPU MATE partner is driven by a "brain" that runs on the MCU. It is made from the game's own code, so it does
not belong in git. It is the same brain as the Paprium Pocket core's 0.2.6, and ships as the release download
`cpu-mate-brain_0.2.6.zip`, three files with these md5s:

| file | md5 | where it goes |
|---|---|---|
| `brain.bin` | `1b64e14d710e8768d3385d1421162bc7` | IROM 0x5360-0xD2EB |
| `cf.bin` | `a5fa37b435f26f9fc2c8fd62d218d7ef` | start of the WRAM code window, 0x80002C00 |
| `rodata.bin` | `5b1d74f454b578196ed1e82548f01b99` | 0x80004110 (after `cf.bin` and 64 zero bytes) |

Unzip it in the top folder of your clone. It makes `cpu-mate-brain/`, which the repository ignores (any other folder
works too). The MiSTer firmware has no build without the brain, so the four init files are not in the repository
either; they are git-ignored. Never commit them.

## Building it

Needs bash (Git Bash on Windows works), git, tar, Python 3, the
[xPack riscv-none-elf GCC 15.2.0](https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases) toolchain and
a clone of mega-ppm. No `make`.

```bash
git clone https://github.com/krikzz/mega-ppm.git ../repos/mega-ppm     # or pass --mega-ppm DIR
./scripts/build_mcu.sh --brain cpu-mate-brain                          # checks the md5s; installs the release firmware
```

`build_mcu.sh` reads the pinned commit with `git archive` (your clone's checkout and branch do not matter and are never
touched), applies the patch, compiles, links, splits the result into the four images, prints their md5s, says whether
they are the shipped build, and installs them into `rtl/PAPRIUM/`. `--no-install` leaves `rtl/PAPRIUM/` alone;
`--help` lists the rest. Another GCC version builds working firmware with other md5s.

With the 0.2.6 brain it gives the MiSTer 0.2.6 RELEASE images byte for byte (LF line ends):

| image | md5 |
|---|---|
| `mcu.txt` | `47644152a84ef5ca2333037ebbd1d9c4` |
| `mcu_ext.txt` | `4c23775c3b728107ca4985a07e1af6a2` |
| `wram_hi.txt` | `3fe6acc44730cfc1d94dfe4d942bbf95` |
| `wram_lo.txt` | `256d3b2a941f985117c50907f4becc0a` |

These are the MiSTer core's own images; the Pocket core's firmware differs around the brain. Then build the core in
Quartus (`MegaDrive.qpf`; the 0.2.6 fit used seed 3, already set in `MegaDrive.qsf`). A fresh fit is not guaranteed to
reproduce the released bitstream bit for bit; the `Paprium.rbf` in the release zip is the reference.
