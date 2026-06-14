# Paprium Cartridge Port Assessment

## Goal

Run the original Paprium ROM on the MiSTer Mega Drive core by emulating the
Paprium cartridge and replacement `mega-ppm` MCU firmware. Use the Mega Drive
core's existing native MD+ audio implementation for background music.

This branch is based on official `MiSTer-devel/MegaDrive_MiSTer` release
`20260603` (`7365a13`).

Reference implementations:

- `D:\Paprium Mister Core work\mega-ppm-main`
- `D:\Paprium Mister Core work\MegaCD_MiSTer-master\rtl\PAPRIUM`

## Important Finding: No ROM Audio Conversion Is Required

The supplied Paprium ROM is not intrinsically MD-MSU or MD+. Paprium sends its
normal cartridge-MCU command `0x8C` to request background music.

The replacement firmware in `mega-ppm-main/mcu/paprium.c` handles that command
and calls `mdp_play()` / `mdp_stop()`. `mega-ppm-main/mcu/mdp.c` then emits
standard MD+ commands:

- `0x12xx`: play track and loop
- `0x13xx`: stop
- `0x15xx`: volume

The official Mega Drive core already implements those commands in
`rtl/md_plus.sv`, streams audio through `rtl/mdp_audio.sv`, and mixes CDDA in
`MegaDrive.sv`.

Therefore the preferred design keeps the original Paprium ROM and MCU command
protocol. The port connects MCU music requests directly to the core's existing
MD+ command interface. It does not reproduce the EverDrive SPI/FIFO transport.

## Existing Mega Drive Core Facilities

The core already provides:

- Normal 68000, VDP-DMA, and Z80 cartridge-bus arbitration.
- A working cartridge SDRAM controller with request/acknowledge transactions.
- Runtime SDRAM port 1 for normal cartridge reads and writes.
- Runtime SDRAM port 2, normally used by SVP, which can serve Paprium MCU
  memory traffic when the Paprium mapper is active.
- Native MD+ overlay registers, HPS command bridge, DDR audio ring buffer, and
  CDDA mixer.
- Existing save-memory infrastructure.

These facilities remove the MegaCD subsystem and its additional SDRAM traffic
from the Paprium integration problem.

## Paprium Components To Port

Port from the existing Paprium work:

- NEORV32 `mcu_core` and replacement MCU firmware image.
- `ramdp_io`: on-chip dual-port 68000/MCU mailbox.
- `fpgio`: reset, streaming-window enable, stream pointer, and volume controls.
- `sdram_io`: Paprium's 2 MiB decompressed/streaming workspace.
- `flash_io`: MCU access to the writable SDRAM-backed 8 MiB ROM.
- Backup RAM behavior.
- MCU work RAM as on-chip block RAM.

Port later, after boot and gameplay:

- Paprium SFX engine from `mega-ppm-main/fpga/audio_sfx.sv`.

Do not port:

- MegaCD subsystem.
- EverDrive SPI/FIFO protocol.
- `mega-ppm` MD+ PCM engine; use the core's native MD+ implementation.

## Proposed Memory Layout

Use one physical MiSTer SDRAM with logical regions:

| Region | Proposed SDRAM word base | Size | Users |
|---|---:|---:|---|
| Paprium flash/ROM | `0x000000` | 8 MiB | 68000/VDP/Z80 + MCU |
| Paprium workspace | `0x480000` | 2 MiB | 68000 + MCU |
| Backup RAM | on-chip/save path | 8 KiB | MCU/HPS |
| MCU work RAM | on-chip block RAM | required firmware size | MCU |
| 68000/MCU mailbox | on-chip dual-port RAM | 8 KiB | 68000 + MCU |

Exact SDRAM bases must be checked against cartridge ROM-size addressing and
the core's SDRAM capacity options before implementation.

## Proposed Bus Architecture

### Normal cartridge port

Keep the Mega Drive core's existing cartridge port for:

- 68000 flash reads.
- VDP DMA flash reads.
- Z80 flash reads.
- 68000 writes where required.

This path already distinguishes and correctly services all Genesis bus owners.

### Paprium MCU port

When the Paprium mapper is active, repurpose runtime SDRAM port 2 for MCU
flash/workspace accesses. Arbitrate the MCU's logical flash and workspace
requests before port 2 and translate them to their physical SDRAM regions.

This gives CPU/VDP traffic and MCU traffic independent request/acknowledge
channels. It avoids returning cached data and avoids inferring bus ownership.

### Mailbox and work RAM

Keep both on-chip:

- Mailbox: true dual-port RAM, one side for the Genesis bus and one for MCU.
- MCU work RAM: block RAM, not shared SDRAM.

## MD+ Integration

The clean implementation should not make the MCU simulate a 68000 write to the
MD+ overlay. Instead, expose a small internal command adapter:

- MCU BGM play request -> `mdp_track_request`, `mdp_track_num`,
  `mdp_track_loop`.
- MCU stop request -> `mdp_stop_request`.
- MCU volume request -> `mdp_volume_request`, `mdp_volume`.
- Return sufficient status to satisfy `mdp_init()` and command polling.

The adapter can either:

1. Emulate the MD+ register block at the MCU's existing `0x07000000` mapping,
   which minimizes firmware changes; or
2. Modify and rebuild the replacement MCU firmware to use a simpler dedicated
   FPGA register block.

Option 1 is preferred initially because it preserves the proven firmware.

### Required MCU firmware compatibility change

`mega-ppm-main/mcu/mdp.c` currently uses the physical EverDrive MCU FIFO to:

- Ask for the current CUE path with `ed_cmd_rom_path()`.
- Mount that CUE with `ed_cmd_cd_mount()`.

Those calls have no equivalent inside the MiSTer FPGA and should be skipped in
a MiSTer firmware build. MiSTer's HPS-side MD+ support owns track discovery and
streaming.

The current implementations also expose different first ID words:

- `mega-ppm` firmware expects `0x5241, 0x5445`.
- The Mega Drive core's 68000-facing MD+ overlay returns `0x4241, 0x5445`.

The proposed MCU-facing adapter should return the IDs expected by the existing
firmware. This avoids changing normal play/stop/volume code. Alternatively, the
MiSTer firmware build can accept either first ID word.

Recommended minimal firmware variant:

1. Keep `mdp_play()`, `mdp_stop()`, and `mdp_set_vol()` unchanged.
2. Skip EverDrive FIFO path lookup and CUE mounting in `mdp_init_()`.
3. Accept the MCU-facing adapter IDs and issue initial pause/volume commands.
4. Keep all Paprium command handlers unchanged.

## ROM Patching

The replacement MCU firmware currently writes:

```c
*(u16 *)&ppmio.flash[0x81104] = 0x4e71;
```

The port should retain writable ROM backing so the firmware works unchanged.
An offline ROM patch is useful for diagnostics, but should not be the final
architecture.

No broader conversion from MD-MSU to MD+ is expected.

## Implementation Stages

1. Add Paprium mapper selection and reset sequencing.
2. Add the on-chip MCU, MCU work RAM, and mailbox.
3. Connect normal Genesis cartridge traffic to Paprium flash/mailbox mapping.
4. Give MCU flash/workspace traffic an independent SDRAM port.
5. Confirm legal screen and first 68000-to-MCU mailbox command.
6. Connect MCU BGM commands to the native MD+ engine.
7. Add save-memory behavior.
8. Add Paprium SFX engine.
9. Remove temporary diagnostics and validate reset/save/audio behavior.

## Main Risks

- FPGA resource/timing impact from NEORV32 and Paprium logic.
- Correctly integrating Paprium's streaming window with VDP DMA behavior.
- Ensuring MCU writes to SDRAM-backed flash complete exactly once.
- HPS-side MD+ track-file naming/mount expectations.
- SFX engine resource use and audio mixing levels.

## Difficulty Estimate

Booting Paprium with silent audio: medium-to-high, but structurally cleaner
than the current MegaCD integration.

Adding BGM through native MD+: low-to-medium once MCU communication works.

Adding full Paprium SFX behavior: medium-to-high and separable from boot.

The recommended next milestone is a Mega Drive-core build that shows the legal
screen and records the first valid 68000 mailbox command. Music and SFX should
not be on that milestone's critical path.
