# MiSTer port map — graft strategy

**Status:** decision locked — **Option A**  
**Compared:** 2026-09-08 via GitHub API (no clones)  
**Pins:**

| Tree | Ref | Tip |
|---|---|---|
| Pezz shell | `MisterPezz82/Paprium_MegaDrive_MiSTer` @ `paprium-mdplus-port` | `2c256d5910e2` (V.06, 2026-07-25) |
| Stock MiSTer MD | `MiSTer-devel/MegaDrive_MiSTer` @ `main` | `083e1b1f4db8` (2026-09-02) |
| Pocket shipping | `thekoalakoa/paprium-pocket` @ tag `0.2.1` | `de08e5f999fb` |

---

## Recommendation

**Choose Option A — Pezz MiSTer shell + Pocket `0.2.1` overlays.**

Do **not** start from stock `MegaDrive_MiSTer` and try to drop in Pocket `rtl/PAPRIUM` wholesale (Option B).

### Rationale (short)

1. **Pezz already solved the MiSTer board contract.** Same Quartus/`sys/` layout as stock, plus working Paprium hooks in `MegaDrive.sv`, `rtl/cartridge.sv`, `rtl/sdram.sv`, `rtl/mdp_audio.sv`, `rtl/pad_io.sv`, `files.qip`. Stock has **zero** `rtl/PAPRIUM/`.
2. **CDDA on MiSTer is HPS/MD+, not Pocket APF.** Pezz bridges MCU → core MD+ via `paprium_mdp_adapter.sv` (blob **identical** to Pocket `0.2.1`). Pocket’s `paprium_cdda_{buf,fetch,play}.sv` + `paprium_ima_decode.sv` replace the missing HPS with APF dataslot/openfile streaming — useless (and wrong) on DE10-Nano.
3. **The Pocket shipping delta is small and overlay-shaped.** Shared PAPRIUM blobs that differ are firmware + a handful of SV files; NEORV32 VHDL and `mdp_adapter` match Pezz already.
4. **Option B re-pays Pezz’s integration cost** (SSF2 suppress, SDRAM port-2 MCU, stream-pointer ack, SFX M10K sizing, MD+ 48 kHz Paprium path, save path) while still needing to **strip** Pocket APF CDDA and rewire to HPS — net more work, more risk, same destination.

---

## Graft strategy table

| Option | Idea | Pros | Cons |
|---|---|---|---|
| **A — Pezz shell (CHOOSE)** | Fork/re-home Pezz tree; overlay Pocket `0.2.1` firmware + DIFF SV; keep Pezz MD+/HPS CDDA | MiSTer `sys/` + Paprium hooks already HW-proven; CDDA path correct for MiSTer; smallest delta | Rebase/credit Pezz carefully; merge Pocket cart/SFX/firmware fixes by file, not by “copy whole PAPRIUM” |
| B — MegaDrive_MiSTer shell | Stock MiSTer + graft Pocket `rtl/PAPRIUM` (+ patches) | Clean MiSTer-devel history | Re-do cart/MCU/SDRAM/top integration; must **not** keep Pocket CDDA RTL; larger rewrite before first boot |

**Decision:** **Option A.**

---

## Top-level trees

### Pezz — `Paprium_MegaDrive_MiSTer` (`paprium-mdplus-port`)

MiSTer-shaped Nuked-MD core + Paprium:

```text
MegaDrive.qpf/.qsf/.sdc/.sv   hps_ext.sv   files.qip   clean.bat
README.md   docs/   releases/   scripts/
rtl/          # stock MD RTL + PAPRIUM/ + SVP/ + VM2413/ + nuked-md/
sys/          # full MiSTer framework (HDMI/audio/OSD/SDRAM/…)
```

### Stock — `MegaDrive_MiSTer` (`main`)

Same skeleton **without** Paprium:

```text
MegaDrive.qpf/.qsf/.sdc/.sv   hps_ext.sv   files.qip   clean.bat
README.md   releases/
rtl/          # NO rtl/PAPRIUM/
sys/          # full MiSTer framework
```

Pezz vs stock **blob DIFF** (same paths, different content):  
`MegaDrive.sv`, `files.qip`, `rtl/cartridge.sv`, `rtl/sdram.sv`, `rtl/mdp_audio.sv`, `rtl/pad_io.sv`.  
**SAME:** `hps_ext.sv`, `rtl/md_plus.sv`, `rtl/nuked-md.qip`.  
**Pezz-only dir:** `rtl/PAPRIUM/`.

### Pocket — `paprium-pocket` @ `0.2.1`

openFPGA / APF ship tree (not MiSTer):

```text
gateware.json   generate.tcl   LICENSE   README.md
patches/        # mega-ppm-pocket.patch → builds mcu.txt
pkg/pocket/     # Cores JSON, Assets, Platforms (APF package)
platform/pocket/  # APF glue
projects/       # megadrive_pocket.qpf/.qsf
target/pocket/  # core_top, bridge, dataslot, I2S, …
rtl/
  PAPRIUM/      # cart/MCU/SFX + Pocket CDDA stack
  upstream/     # vendored MegaDrive_MiSTer-ish RTL
  cartridge.sv  sdram.sv  core.qip  paprium.qip  …
docs/   scripts/   support/   tools/   hooks/   build-logs/
```

**No `sys/`.** Board surface is `platform/` + `target/pocket/`.

---

## Where Paprium / cart / MCU / CDDA live

| Concern | Pezz (MiSTer) | Pocket `0.2.1` | Stock MegaDrive_MiSTer |
|---|---|---|---|
| **Cart wrapper / mapper / stream window** | `rtl/PAPRIUM/paprium_cart.sv` + hooks in `rtl/cartridge.sv` | `rtl/PAPRIUM/paprium_cart.sv` (+ Pocket top wiring in `target/pocket/core_top.sv`) | — (generic cart only) |
| **MCU (NEORV32 + mega-ppm)** | `rtl/PAPRIUM/mcu_core.sv`, `mcu.txt`, `risc-v/` | same paths; **`mcu.txt` / `mcu_core.sv` DIFF** vs Pezz | — |
| **MCU↔68000 mailbox / mem** | `ramdp_io.sv`, `paprium_mcu_mem.sv`, `memory.sv`, `fpgio.sv` | same; most **SAME** as Pezz | — |
| **SFX PCM engine** | `audio_sfx.sv`, `audio_clock.sv` | same; **`audio_sfx.sv` DIFF** (larger) | — |
| **Backup RAM** | `paprium_backup.sv` → MiSTer `.sav` | `paprium_backup.sv` DIFF | stock save path only |
| **BGM command decode** | `paprium_mdp_adapter.sv` → core MD+ | **SAME blob** as Pezz | `md_plus.sv` / `mdp_audio.sv` unused for Paprium |
| **CDDA consumer / producer** | **HPS +** `rtl/md_plus.sv` + `rtl/mdp_audio.sv` (DDR ring; WAV+`.cue` on SD) | **APF dataslot streamer:** `paprium_cdda_fetch/buf/play.sv` (+ optional `paprium_ima_decode.sv`); no HPS | HPS MD+ present, no Paprium bridge |
| **Firmware source-of-truth** | baked `mcu.txt` (older / smaller) | `patches/mega-ppm-pocket.patch` + `scripts/build_mcu.sh` → `mcu.txt` | — |

### `rtl/PAPRIUM/` blob compare — Pezz vs Pocket `0.2.1`

| Status | Files |
|---|---|
| **SAME** | `audio_clock.sv`, `fpgio.sv`, `memory.sv`, `paprium_defs.sv`, `paprium_mcu_mem.sv`, **`paprium_mdp_adapter.sv`**, `ramdp_io.sv`, entire `risc-v/*.vhd` (incl. `neorv32_application_image.vhd`) |
| **DIFF (overlay from Pocket)** | `mcu.txt` (35 658 → 44 991 B), `mcu_core.sv`, `paprium_cart.sv`, `audio_sfx.sv`, `paprium_backup.sv`, `structs.sv` |
| **Pocket-only (do not import for MiSTer CDDA)** | `paprium_cdda_buf.sv`, `paprium_cdda_fetch.sv`, `paprium_cdda_play.sv`, `paprium_ima_decode.sv`, `paprium_cmd_log.sv` (diag) |

---

## Pocket-only APF pieces to drop (do not import)

Strip these when seeding `Paprium_MiSTer` from Pocket lineage docs/RTL:

| Drop | Why |
|---|---|
| `platform/pocket/**` | APF top, pad controller, Pocket TCL/constraints |
| `target/pocket/**` | `core_top`, bridge cmds, dataslot loader, Pocket PLLs/I2S |
| `pkg/pocket/**` | openFPGA `core.json` / `data.json` / Assets / Platforms |
| `projects/megadrive_pocket.*`, `generate.tcl`, `gateware.json` | Pocket Quartus ship path |
| `support/loader.asm`, Pocket-only `scripts/build_cdda*.sh`, deploy-to-Pocket scripts | APF/loader / PCM asset pipeline |
| `rtl/PAPRIUM/paprium_cdda_*.sv`, `paprium_ima_decode.sv` | Replaces HPS MD+; MiSTer already has MD+ |
| `rtl/PAPRIUM/paprium_cmd_log.sv` | Pocket diagnostic surface |
| FX68K soak / #8 diagnostic branches | Out of scope (see FORK_BRIEF) |

**Keep from Pocket `0.2.1`:** `patches/` (+ README), DIFF PAPRIUM SV/`mcu.txt` listed above, adapted INSTALL/music/cue notes (`docs/paprium.cue`, CDDA *contract* from `docs/CDDA_DESIGN.md` — not the APF implementation).

**Keep from Pezz:** full `sys/`, Quartus project, `MegaDrive.sv` Paprium hooks, MD+/HPS CDDA wiring, integration fixes in `cartridge.sv` / `sdram.sv` / `mdp_audio.sv` / `pad_io.sv`, arcade OSD extras if still wanted.

---

## Option A implementation checklist

1. Seed repo from Pezz `paprium-mdplus-port` (MiSTer shell + baseline Paprium).
2. Overlay Pocket `0.2.1` files: `mcu.txt`, `mcu_core.sv`, `paprium_cart.sv`, `audio_sfx.sv`, `paprium_backup.sv`, `structs.sv`.
3. Vendor `patches/mega-ppm-pocket.patch` + `build_mcu.sh` so firmware stays rebuildable (GPLv3 source).
4. **Leave** `paprium_mdp_adapter.sv` and Pezz MD+/`mdp_audio` path alone (already matches Pocket’s command contract).
5. Do **not** wire Pocket CDDA RTL; SD layout stays Pezz-style: `/media/fat/games/MegaDrive/Paprium/` + WAV + `paprium.cue` (carry Pocket one-shot / `REM NOLOOP` notes).
6. Diff Pezz vs Pocket `paprium_cart`/`audio_sfx` after overlay; resolve any MiSTer-only ports (SDRAM port 2, save, OSD) before first fit.  
   **Done — see [`docs/CART_OVERLAY_REVIEW.md`](CART_OVERLAY_REVIEW.md).** Verdict: **NO-GO as-is**; restore Pezz `paprium_backup.sv` (16-bit HPS) and `$readmemh("rtl/PAPRIUM/mcu.txt")` before first Quartus.
7. Credit: Nuked-MD → MiSTer-devel → Pezz Paprium MiSTer → paprium-pocket `0.2.1` → this tree; krikzz/mega-ppm firmware.

---

## Why Option B loses

Starting from stock `MegaDrive_MiSTer` + Pocket `rtl/PAPRIUM` means:

- Re-implement every Pezz hook (`MegaDrive.sv` ~30 sites, cartridge SSF2 suppress, SDRAM dual-port MCU, mdp_audio Paprium rate, pad/arcade wiring).
- Then **delete** Pocket CDDA modules and re-attach `paprium_mdp_adapter` to HPS MD+ (which Pezz already did; adapter SHA already matches).
- Pocket’s `rtl/upstream/` is a Pocket-vendored MD tree, not a drop-in for current `MiSTer-devel` `sys/` + project files.

Net: duplicate Pezz’s work, fight APF assumptions, slower path to a DE10 boot.

---

## Success criteria for this doc

- [x] Top-level trees for Pezz / stock / Pocket `0.2.1`
- [x] Where Paprium / cart / MCU / CDDA live
- [x] Pocket-only APF pieces to drop
- [x] Clear recommendation: **Option A** with rationale
