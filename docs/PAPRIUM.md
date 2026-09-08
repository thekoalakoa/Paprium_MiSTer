# Paprium on the MiSTer Mega Drive core

> **Errata (this fork):** Paprium **background music** is Pocket **`paprium.pcm` (PPAD IMA)** on the FPGA CDDA stack — **not** Pezz MD+ cue/WAV. The cue/`REM NOLOOP` notes below are **historical for Pezz upstream only**. See [`POCKET_CDDA_MISTER.md`](POCKET_CDDA_MISTER.md) and the root README.

> **This is a hacky way to *experience* Paprium (WaterMelon) on MiSTer — not a
> faithful reproduction of the cartridge.** Paprium's custom **DATENMEISTER**
> chipset is not reproduced. This port takes the same approach as the **EverDrive
> Pro** workaround: it runs the `mega-ppm` replacement MCU firmware and uses
> **MD+ CDDA for the music** instead of the original **DT128M16VA1LT** chipset.
> Think of it as "Paprium, EverDrive-Pro style, on MiSTer."

With that understood, it is hardware-verified on DE10-Nano: it boots, renders
correctly, plays CDDA background music, and plays the full per-channel cartridge
sound effects. The SVP chip (Virtua Racing) is retained.

## How it works

- **Console vs MCU split.** The 68000 / VDP-DMA / Z80 use the core's stock
  cartridge path on SDRAM port 1. The Paprium MCU (NEORV32) uses SDRAM port 2
  (normally the SVP's). They share one writable SDRAM-backed 8 MiB ROM plus a
  2 MiB decompression workspace; the 68000↔MCU mailbox and MCU work RAM are
  on-chip.
- **Decompression / graphics.** The MCU decompresses graphics into the workspace;
  the 68000/VDP read them back through the streaming window via an
  auto-incrementing pointer. The firmware's `0x81` LZ decompressor (`mame.c`)
  was replaced with the correct Genesis Plus GX / FinalBurn Neo routine
  (`paprium_decoder_lzo`) — the MAME-derived one is broken and corrupts the
  subway and a few other areas (fix per krikzz; not yet in stock mega-ppm).
- **Background music (CDDA).** MCU MD+ commands (`paprium_mdp_adapter.sv`) drive
  the Pocket CDDA stack (`paprium_cdda_{fetch,buf,play}` + IMA decode) reading
  **`paprium.pcm`** from DDR. Loop/one-shot stay in FPGA (`$11xx`/`$12xx`).
  Consume rate is **48 kHz**. Pezz cue/WAV / `hps_ext` music is **not** used for Paprium.
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

## Extras (V.05)

- **Arcade Mode unlock** (main OSD page): applies adroxe's `paprium_arcade.ips`
  (<https://github.com/adroxe/Paprium-Arcade>) on the fly as a ROM-read
  substitution — the ROM file is never modified. Unlock + reset = "ARCADE
  PAPRIUM" (friendly fire on, Insert Coin/credits). The IPS's Mode-button
  credit check is re-targeted at an FPGA "coin chute" register, so **pressing
  the MiSTer-mapped Mode button (port 1) inserts a coin** — no 6-button pad
  protocol involved; works in 3-button mode.
- **Arcade Stage select** (main OSD page): boots arcade mode into any of the 25
  stages (per krikzz: ROM start-stage byte at `0x0B0A15`, substituted live).
- **One-shot music (cue requirement):** Main_MiSTer's MD+ player loops every
  track unless the cue says otherwise. Your `paprium.cue` needs `REM NOLOOP`
  after the `INDEX 01` line of the one-shot tracks (12 Continue, 29 Game Over,
  36 High Score, 53 Stage Clear) — or just use the reference
  [`paprium.cue`](paprium.cue) shipped here.
- **Controls:** play Paprium with OSD "6 Buttons Mode" = **No** — X/Y/Z are
  mapped to combos (Y=Down+B, X=B+C, Z=A+B) and Mode inserts coins. (In
  6-button mode X/Y/Z do nothing: the game's own 6-button read doesn't work on
  this port — same as EverDrive — and the combo injection disables itself to
  keep real 6-button games untouched.)

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
