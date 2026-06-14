# Paprium Mega Drive Port: First Hardware Build

## Purpose

This build tests the minimum real-cartridge architecture needed to reach the
Paprium legal screen on the standalone Mega Drive core.

It is not an audio or gameplay-complete build.

## Included

- Automatic Paprium detection using product code `GM T-574120`.
- Original Paprium ROM loaded normally through the Mega Drive core.
- Existing Mega Drive core cartridge arbitration for 68000, VDP DMA, and Z80
  ROM reads.
- NEORV32 replacement Paprium MCU and current proven firmware image.
- On-chip MCU work RAM.
- On-chip dual-port 68000/MCU mailbox.
- MCU-controlled Mega Drive reset.
- Writable SDRAM-backed ROM through independent SDRAM port 2.
- MCU workspace access through independent SDRAM port 2.
- Paprium narrow streaming window at byte addresses `0x00C000-0x00FFFF`.
- Handshake-driven MCU SDRAM transactions with no guessed completion delay.
- Cheat-code engines disabled to preserve timing and routing headroom.

## Deliberately Excluded

- Native MD+ command adapter.
- Background music.
- Paprium SFX engine.
- Persistent backup-memory integration.
- Debug overlay and MegaCD subsystem.

## First Test

1. Install the generated Mega Drive RBF as a separate test core.
2. Load the unmodified 8 MiB `Paprium.md` ROM.
3. Observe reset behavior and whether the legal screen appears.

For the first test, reload the RBF before reloading the ROM. The current reset
scaffold initializes the Paprium reset-control register when the FPGA is
configured; explicitly re-arming it for same-session ROM reloads is the next
reset-hardening task.

## Build Result

- Quartus Prime 25.1 analysis/synthesis: successful, 0 errors.
- Fitter: successful, 0 errors, 11 warnings.
- Utilization: 33,735 / 41,910 ALMs (80%), 499 / 553 RAM blocks (90%).
- Peak interconnect usage: 65%.
- Assembler: successful, 0 errors.
- Timing analyzer: worst setup slack `-2.165 ns`; hold slack `0.173 ns`.

The detailed worst setup paths run through the stock gate-level VDP
combinational loop into `cartridge.cart_data`. They do not run through the
Paprium MCU, mailbox, or MCU SDRAM transaction adapter.

## Interpretation

### Legal screen appears

This confirms the important first chain:

1. ROM signature enabled the Paprium mapper.
2. MCU booted and accessed ROM/workspace through SDRAM port 2.
3. MCU's writable-ROM patch reached the same SDRAM backing read by the 68000.
4. MCU released the Mega Drive reset.
5. 68000 and VDP reads remained valid through the normal cartridge path.

The next milestone is the first valid 68000-to-MCU mailbox command, followed by
the native MD+ command adapter.

### Black screen or permanent reset

Focus on mapper detection, MCU startup, MCU work RAM, and reset release.

### Legal screen missing but 68000 executes

Focus on the writable-ROM patch, mailbox mapping, and stream-pointer behavior.

### Legal screen appears and then execution stalls

Focus on the first mailbox command and workspace streaming. Audio remains
intentionally silent and should not be treated as the cause.

## Architecture Rule

Do not route normal console reads through the MCU SDRAM adapter. Port 1 remains
the console cartridge path; port 2 remains the Paprium MCU path. The only
shared state is the underlying SDRAM contents.
