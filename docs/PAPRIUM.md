# Paprium on the MiSTer Mega Drive core

Runs the original **Paprium** cartridge (WaterMelon) — including its NEORV32
RISC-V coprocessor — on the MiSTer FPGA Mega Drive core. Hardware-verified on
DE10-Nano: it boots, renders correctly, plays CDDA background music, and plays
the full per-channel cartridge sound effects. The SVP chip (Virtua Racing) is
retained.

## How it works

- **Console vs MCU split.** The 68000 / VDP-DMA / Z80 use the core's stock
  cartridge path on SDRAM port 1. The Paprium MCU (NEORV32) uses SDRAM port 2
  (normally the SVP's). They share one writable SDRAM-backed 8 MiB ROM plus a
  2 MiB decompression workspace; the 68000↔MCU mailbox and MCU work RAM are
  on-chip.
- **Decompression / graphics.** The MCU decompresses graphics into the workspace;
  the 68000/VDP read them back through the streaming window via an
  auto-incrementing pointer.
- **Background music (CDDA).** The MCU's native MD+ commands are bridged to the
  core's MD+ engine and CDDA mixer by `paprium_mdp_adapter.sv`, with an
  EverDrive-FIFO stub so `mdp_init()` completes. No ROM audio conversion is
  required.
- **Sound effects.** Paprium's own self-contained cartridge PCM engine (eight
  channels, each with a FIFO and per-channel sample-rate / pitch / pan / volume)
  is ported as `audio_sfx.sv` and mixed with FM/PSG and CDDA at the top level.

## Key implementation notes

- **Copy protection.** Paprium's anti-emulation routine writes `0xA130F3` while
  executing from the cartridge. The stock Mega Drive SSF2 bank logic remapped the
  running code out from under it — an illegal-instruction loop hidden under the
  legal screen. Fix: suppress SSF2 banking when the Paprium mapper is active
  (`rtl/cartridge.sv`); the real cartridge has no SSF2 banking.
- **Stream-pointer cadence.** The stream pointer must advance once per *delivered*
  word. Advancing on the raw combinational bus strobe double-counted glitches
  from the cycle-accurate VDP and desynced the stream (per-pixel tile noise on
  backgrounds, clean font/UI). Fix: advance on the registered per-word
  read-completion ack (`rtl/PAPRIUM/paprium_cart.sv`).
- **SFX FIFO sizing.** The eight channel FIFOs use a right-sized 256×16 dual-port
  RAM (`sfx_fifo_ram`), not the port's 65536×16 (1 Mbit) general-purpose
  `ram_dp16`. That keeps the core at ~92% M10K **with the SVP retained**.
- **Byte order.** The MCU is little-endian (NEORV32) and the 68000 big-endian on
  one shared SDRAM. mega-ppm's `sdram_io.sv` crosses the SDRAM byte-enables
  because its board physically crosses the DQ byte lanes; the MiSTer SDRAM is
  straight-wired, so `rtl/PAPRIUM/paprium_mcu_mem.sv` keeps the byte-enables
  straight to reproduce the same net layout.

## Building

Quartus Prime 25.1 Standard. Open `MegaDrive.qpf` and run a full compilation, or:

```
quartus_sh --flow compile MegaDrive
```

Output: `output_files/MegaDrive.rbf`.

## Paprium source files (`rtl/PAPRIUM/`)

| File | Role |
|---|---|
| `paprium_cart.sv` | Top-level Paprium wrapper: MCU, mailbox, stream window, adapters |
| `paprium_mcu_mem.sv` | MCU flash/workspace adapter on SDRAM port 2 |
| `paprium_mdp_adapter.sv` | MCU BGM commands → core MD+ engine (CDDA) |
| `audio_sfx.sv`, `audio_clock.sv` | Cartridge PCM SFX engine + per-channel rate clocks |
| `mcu_core.sv`, `mcu.txt`, `risc-v/` | NEORV32 MCU + mega-ppm firmware |
| `ramdp_io.sv`, `fpgio.sv`, `memory.sv`, `structs.sv` | Mailbox, FPGA IO, RAMs, shared types |

The shipped core has no debug surface: CDDA owns the DDR audio channel
unconditionally and there is no OSD debug option.

## Credits

The MCU firmware (`mcu.txt`, `risc-v/`) is the publicly available `mega-ppm`
firmware by krikzz (<https://github.com/krikzz/mega-ppm>). Built on the MiSTer
Nuked-MD Mega Drive core.
