# Paprium on the MiSTer Mega Drive core

This is an EverDrive Pro style implementation of Paprium (WaterMelon) on MiSTer, not a faithful reproduction of the cartridge. Paprium's custom DATENMEISTER chipset is not reproduced. The core runs the `mega-ppm` replacement MCU firmware (a NEORV32 soft CPU) and plays background music from a `paprium.pcm` file that you supply.

See the root `README.md` for installation, OSD items, build numbers and known limits.

## Arcade Mode

The main OSD page has two Paprium items: **Paprium Arcade Mode** (Locked / Unlocked) and **Paprium Arcade Stage** (Off, then a list of stages). The Arcade Mode unlock is based on adroxe's Paprium-Arcade IPS (<https://github.com/adroxe/Paprium-Arcade>); see `docs/PEZZ_UPSTREAM_README.md` for the credit.

## Paprium source files (`rtl/PAPRIUM/`)

| File | Role |
|---|---|
| `paprium_cart.sv` | Top-level Paprium wrapper: MCU, mailbox, stream window, adapters |
| `paprium_mcu_mem.sv` | MCU flash/workspace adapter |
| `paprium_mdp_adapter.sv` | MCU background-music commands to the core's music engine |
| `paprium_pcm_load.sv`, `paprium_cdda_*.sv`, `paprium_ima_decode.sv` | `paprium.pcm` loading, fetch, buffering, IMA decode and playback |
| `paprium_backup.sv` | Save RAM handling |
| `audio_sfx.sv`, `audio_clock.sv` | Cartridge sound-effect engine and per-channel rate clocks |
| `mcu_core.sv`, `mcu.txt`, `risc-v/` | NEORV32 MCU and the `mega-ppm` firmware |
| `ramdp_io.sv`, `fpgio.sv`, `memory.sv`, `structs.sv`, `paprium_defs.sv` | Mailbox, FPGA IO, RAMs, shared types and definitions |

## Credits

The MCU firmware (`mcu.txt`, `risc-v/`) is the publicly available `mega-ppm` firmware by krikzz (<https://github.com/krikzz/mega-ppm>), with the changes in `patches/mega-ppm-pocket.patch`. The core is built on the MiSTer Nuked-MD Mega Drive core.