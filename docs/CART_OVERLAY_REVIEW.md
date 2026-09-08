# Cart overlay review — Pocket 0.2.1 on Pezz MiSTer shell

**Reviewed:** 2026-09-08 (America/New_York)  
**Tree:** `thekoalakoa/Paprium_MiSTer` @ `main`  
**Overlay tip:** `55cd1f82c4f3` (Pocket 0.2.1 deltas on Pezz)  
**Pezz parent:** `2c256d5910e2` (Paprium V.06 / `paprium-mdplus-port`)  
**Pocket pin:** `thekoalakoa/paprium-pocket` @ tag `0.2.1` (`de08e5f999fb`)  
**Method:** `git diff` / `git show` against seeded remotes; no Quartus run.
**Status:** **FIXED 2026-09-08** — both blockers (Pezz `paprium_backup.sv` + `$readmemh` path) applied on `main`; GO for first Quartus.

---

## Summary / risk level

| | |
|---|---|
| **Verdict** | **GO for first Quartus** (blockers addressed) |
| **Risk** | **Low–Medium** — prior compile/load breaks fixed; bring-up still needs Pezz SD / cue+WAV |
| **Shell hooks** | Pezz `MegaDrive.sv` / `rtl/cartridge.sv` / `rtl/sdram.sv` / `rtl/mdp_audio.sv` / `rtl/pad_io.sv` / MD+ path **unchanged** by the overlay (good) |
| **CDDA** | Pezz HPS / MD+ preserved; Pocket APF CDDA **not** imported (good) |
| **MD+ bridge** | `paprium_mdp_adapter.sv` **SAME** blob tip = Pezz = Pocket (`sha256` prefix `748f9437318e7fc8…`) |

**FIXED (2026-09-08):** both blocking items below are applied on `main` (see follow-up commit). Optional: tie off unused `cmdlog_*` ports if Quartus warns.

~~Must fix before first fit (2 items):~~ **Addressed:**

1. ~~Restore Pezz `paprium_backup.sv`~~ — **FIXED:** restored Pezz 16-bit HPS `.sav` port from `2c256d5910e2` (Pocket 8-bit APF port discarded).
2. ~~Fix `$readmemh` path~~ — **FIXED:** `mcu_core.sv` uses `"rtl/PAPRIUM/mcu.txt"` again; **32 KB IMEM kept** (`rom[32768/4]`, `addr[14:0]`).

---

## Overlay file set (what changed)

`55cd1f82c4f3` vs `2c256d5910e2` touched only:

| Path | Role |
|---|---|
| `rtl/PAPRIUM/paprium_cart.sv` | Cart wrapper (SFX/CMDLOG params + cmdlog hooks) |
| `rtl/PAPRIUM/audio_sfx.sv` | SFX engine (echo/amp, area aclk, ch7 dbg) |
| `rtl/PAPRIUM/paprium_backup.sv` | Backup RAM host port (**Pocket APF — wrong for MiSTer**) |
| `rtl/PAPRIUM/mcu_core.sv` | IMEM 16→32 KB + `$readmemh` path |
| `rtl/PAPRIUM/mcu.txt` | Pocket firmware image |
| `rtl/PAPRIUM/structs.sv` | `SfxOut.echo` / `.amp` |
| `patches/`, `scripts/build_mcu.sh`, docs/README | Non-RTL seed |

**Not touched (Pezz shell stays authoritative):**  
`MegaDrive.sv`, `files.qip`, `rtl/cartridge.sv`, `rtl/sdram.sv`, `rtl/mdp_audio.sv`, `rtl/pad_io.sv`, `rtl/md_plus.sv`, `hps_ext.sv`, `rtl/PAPRIUM/paprium_mdp_adapter.sv`, Pocket CDDA modules (absent).

---

## Per-file findings

### 1. `paprium_cart.sv` (Pezz → overlay)

**Delta (behavioral):**

- Parameters: `#(parameter SFX = 1'b1, parameter CMDLOG = 1'b0)`.
- New ports: `cmdlog_read_addr[13:0]`, `cmdlog_read_data[7:0]` (diagnostic only).
- `generate if (CMDLOG)` would instantiate `paprium_cmd_log` — **module not in this tree** (intentionally omitted); default `CMDLOG=0` folds to `cmdlog_read_data = 0`.
- `generate if (SFX)` wraps SFX; shipping default `SFX=1`. Wires Pocket `dbg_ch7_*` from `audio_sfx` into the (elided) logger.
- Core cart / mailbox / stream / `mem_*` / MDP / **16-bit save** ports **unchanged** vs Pezz.

**Wiring vs Pezz `rtl/cartridge.sv` + `MegaDrive.sv`:**

| Concern | Result |
|---|---|
| Cart/MDP/SFX/mem/save ports Pezz already wires | Match tip module (same names/widths) |
| Pocket-only `cmdlog_*` | **Unwired** in `cartridge.sv` (2 ports). Harmless with `CMDLOG=0`; may warn |
| Pezz-only ports Pocket cart expects differently | **None** on the cart boundary — Pezz instance still valid |
| SDRAM port-2 MCU path | Still via `mem_*` → `cartridge.sv` → `sdram` port 2; overlay did not change that |

**Go after backup/`readmemh` fixes.** Optional follow-up: `.cmdlog_read_addr(14'd0)` / leave `cmdlog_read_data` open, or `/* synopsys translate_off */` — not required to compile if Quartus treats dangling inputs as warnings.

---

### 2. `audio_sfx.sv` — size / ports / M10K / clocks

| | Pezz parent | Overlay (Pocket 0.2.1) |
|---|---|---|
| Lines / bytes | 324 / ~8.0 KB | 467 / ~14.1 KB |
| Top ports | `mcu`, `snd`, `mcu_dati_sfx`, `snd_l/r` | + `dbg_ch7_vol/empty/wr` (wired inside cart) |
| Rate clocks | 5× `dac_clocker` @ 24/12/9.6/6/5.333 kHz | Cheap dividers off existing 48 kHz `dac_next_sample` (area win; phase-locked) |
| Effects | No echo/amp | Echo ring + amp (GPGX-aligned); needs `structs.sv` bits |
| FIFO RAM | 8× 256×16 ≈ **8 M10K** (unchanged intent) | same |
| Echo RAM | — | `echo_ram[8192]` × 32-bit ≈ **256 Kbit ≈ 26 M10K** (comment: “62 free” is **Pocket** budget) |

**MiSTer assumptions:**

- Device is `5CSEBA6U23I7` (**553 M10K**). +~26 for echo and +~13 for 32 KB IMEM are fine vs DE10 headroom; Pocket’s ALM squeeze does not apply.
- `CLK_FREQ` still `53_693_175` in `paprium_defs.sv`; 48 kHz `dac_clocker` in cart unchanged.
- No Pocket APF audio clocks introduced.

**Safe** for MiSTer once the two hard fixes land.

---

### 3. `mcu_core.sv` / `mcu.txt` — IMEM 16 KB vs 32 KB

| | Pezz | Overlay |
|---|---|---|
| `mcu_irom` depth | `rom[16384/4]`, `addr[13:0]` | `rom[32768/4]`, `addr[14:0]` |
| `$readmemh` | `"rtl/PAPRIUM/mcu.txt"` | `"mcu.txt"` ← **breaks Pezz project layout** |
| `mcu.txt` size | 35 658 B / **3962** hex words (~15.8 KB image) | 44 991 B / **4999** words (~20.0 KB image) |

**Conclusion:** Pezz’s **16 KB** ceiling cannot hold Pocket firmware (~20 KB). Overlay’s **32 KB** IMEM is **required**, not optional. Address truncation from full `mcu.addr` into `[14:0]` is intentional (same pattern as Pezz `[13:0]`).

**Must fix:** ~~restore path `"rtl/PAPRIUM/mcu.txt"`~~ — **FIXED 2026-09-08** (path restored; 32 KB IMEM kept). Alternate was add to `MegaDrive.qsf`:

```tcl
set_global_assignment -name SEARCH_PATH rtl/PAPRIUM
```

Prefer restoring the Pezz-style path (no `.qsf` churn).

---

### 4. `paprium_backup.sv` vs Pezz save path (`.sav` / HPS)

| | Pezz (needed) | Overlay (Pocket APF) |
|---|---|---|
| `save_addr` | `[14:0]` | `[15:0]` |
| `save_di` / `save_do` | `[15:0]` | `[7:0]` |
| `dpram_dif` | `#(AW,16,AW,16)` | `#(AW,16,AW+1,8)` + endian nibble invert |

**Call chain (still 16-bit):**

`MegaDrive.sv` → `cartridge.sv` (`save_addr[14:0]`, `save_di/do[15:0]`) → `paprium_cart` (still 16-bit) → **`paprium_backup` (now 8-bit)** → **width mismatch at elaborating `backup_inst`**.

MCU-side FSM / 4 KB dual-port intent is otherwise the same; only the host port was Pocket-ized. Overlay file is **byte-identical** to Pocket `0.2.1` backup — wrong host contract for MiSTer.

**Must fix:** ~~`git checkout 2c256d5910e2 -- rtl/PAPRIUM/paprium_backup.sv`~~ — **FIXED 2026-09-08** (Pezz blob restored on `main`). Do **not** keep Pocket endian/`SAVE_BIG_ENDIAN` glue on MiSTer.

---

### 5. `structs.sv`

Adds `SfxOut.echo` and `SfxOut.amp` for Pocket `audio_sfx`. Required companion to the SFX overlay. **OK.**

---

### 6. `paprium_mdp_adapter` + MD+ / HPS CDDA path

| Check | Result |
|---|---|
| Tip vs Pezz vs Pocket `0.2.1` blob | **Identical** (`sha256`…`748f9437318e7fc8`) |
| Overlay diff on `md_plus.sv` / `mdp_audio.sv` / `hps_ext.sv` / MegaDrive MD+ mux | **Empty** |
| Pocket `paprium_cdda_*` / `paprium_ima_decode` / `paprium_cmd_log` in `.qsf` | **Absent** |

Pezz mux (`paprium_active ? ppm_* : mdplus_*`) and `mdp_audio` DDR ring / cue+WAV path remain the CDDA consumer. **Untouched — keep as-is.**

---

### 7. Related Pezz hooks (sanity)

Overlay did not edit these; they remain V.06 behavior the cart still expects:

- **`rtl/cartridge.sv`:** `paprium_quirk`, stream window, SDRAM port-2 mux, arcade/vpad ROM patches, `paprium_cart` instance.
- **`rtl/sdram.sv`:** dual-port MCU workspace (via cartridge port 2).
- **`MegaDrive.sv`:** save buffer, SFX+CDDA mix (+10 dB Paprium CDDA), MD+ status into cart.
- **`rtl/pad_io.sv`:** Pezz pad/arcade integration (no overlay delta).
- **`rtl/mdp_audio.sv`:** HPS PCM path (no overlay delta).

---

## Required follow-up code changes before first fit

> **FIXED 2026-09-08 on `main`:** items (1) and (2) applied — Pezz `paprium_backup.sv` restored; `$readmemh("rtl/PAPRIUM/mcu.txt")` with 32 KB IMEM kept.

1. ~~**Restore Pezz backup (blocking):**~~ **DONE**
   ```bash
   git checkout 2c256d5910e2 -- rtl/PAPRIUM/paprium_backup.sv
   ```
2. ~~**Fix IMEM hex path (blocking)**~~ **DONE** in `rtl/PAPRIUM/mcu_core.sv`:
   ```systemverilog
   $readmemh("rtl/PAPRIUM/mcu.txt", rom);
   ```
   (Keep 32 KB `rom[32768/4]` / `addr[14:0]`.)
3. **Optional:** In `rtl/cartridge.sv` `paprium_cart` instance, tie `.cmdlog_read_addr(14'd0)` if Quartus errors/warns on undriven inputs. Leave `CMDLOG=0`; do **not** import `paprium_cmd_log.sv`.
4. **Do not:** import Pocket CDDA RTL; do not change `paprium_mdp_adapter` / `mdp_audio` / HPS cue path; do not shrink IMEM back to 16 KB.

---

## Explicit gate

| Question | Answer |
|---|---|
| **Safe to try Quartus as-is?** | **Yes** (blockers fixed 2026-09-08) |
| **Must fix X first** | ~~**(1) Pezz `paprium_backup.sv` 16-bit HPS port** and **(2) `$readmemh("rtl/PAPRIUM/mcu.txt")`**~~ — **DONE** |
| After (1)+(2)? | **Yes — safe to try first Quartus fit** (expect M10K bump for echo+IMEM; DE10 budget OK). Functional bring-up still needs Pezz SD layout / cue+WAV as in `MISTER_PORT.md`. |

---

## Success criteria for this review

- [x] Pezz-parent vs overlay tip deltas for overlaid RTL
- [x] Cart port connect audit vs `MegaDrive.sv` / `cartridge.sv`
- [x] `audio_sfx` size/ports/M10K/clock notes for MiSTer
- [x] MCU IMEM 16 vs 32 KB vs firmware image size
- [x] Backup vs Pezz `.sav` / HPS path
- [x] `paprium_mdp_adapter` SAME; MD+ path untouched
- [x] Clear go/no-go + concrete fix list
