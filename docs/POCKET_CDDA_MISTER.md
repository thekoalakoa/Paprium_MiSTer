# Pocket CDDA → MiSTer — port plan (docs only)

**Status:** M2(+partial M3) on `main` — Pocket CDDA stack **wired** in `MegaDrive.sv`; `paprium_cdda_fetch` is a **DDRAM** master (no APF); Paprium BGM disconnected from `hps_ext`/cue. Full ~543 MB HPS one-shot fill still needed for soak (ioctl FS3 ≤ ~128 MiB).  
**Date:** 2026-09-08 (America/New_York)  
**Goal correction (B Jam):** music and behavior must match **paprium-pocket `0.2.1`**, including **`paprium.pcm` (PPAD IMA ADPCM)** — **not** Pezz MD+ WAV+`.cue`.  
**Shell:** Pezz MiSTer only (`sys/`, Quartus, DE10).  
**Pins:**

| Tree | Ref | Tip / note |
|---|---|---|
| Pocket shipping | `thekoalakoa/paprium-pocket` @ tag `0.2.1` | `de08e5f999fb` |
| Pezz shell | `MisterPezz82/Paprium_MegaDrive_MiSTer` @ `paprium-mdplus-port` | `2c256d5910e2` (V.06) |
| This repo | `thekoalakoa/Paprium_MiSTer` @ `main` | Pezz shell + Pocket overlays; **CDDA/IMA sources present, unwired** |

> **Supersedes** the CDDA half of `docs/MISTER_PORT.md` where that doc said “keep Pezz HPS/MD+ WAV+cue” and “do not import Pocket CDDA RTL.” Shell choice (Option A — Pezz) still stands. Music path choice does **not**.

---

## 0. One-sentence outcome

**Keep every Pocket `0.2.1` shipping fix already grafted (SFX, firmware, cart, backup path fixes); restore the Pocket CDDA stack with `paprium.pcm`; replace APF dataslot I/O with a MiSTer DDR/HPS blob reader; disconnect Pezz cue/WAV MD+ music for Paprium.**

---

## 1. What is already correct on `main` (must-keep)

These are **shipping Pocket `0.2.1` behavior**, already overlaid on the Pezz shell. Do **not** regress them while restoring CDDA.

### 1.1 Firmware (`mcu.txt` + `patches/`)

| Artifact | Role |
|---|---|
| `rtl/PAPRIUM/mcu.txt` | Pocket `0.2.1` NEORV32 image (sha256 `aac9c12f…`; **identical** Pocket ↔ current seed) |
| `patches/mega-ppm-pocket.patch` | Corresponding source vs `krikzz/mega-ppm` (GPLv3) |
| `patches/README.md`, `scripts/build_mcu.sh` | Rebuild path into `mcu.txt` |

**Must keep from the patch (non-exhaustive; all of `0.2.1`):**

- **SFX channel re-arm** (`sfx.c`) — loop-after-end / punk-TV / subway ambience
- **Real LZO `0x81`** (`mame.c`) — GPGX-aligned decompress (anim residency)
- **Elevator / anim / walk / busy-handshake work** — stream walk budgeting, anim-over audit, residency vs fill tradeoffs recorded in patch comments; IMEM grown to **32 KB** so firmware can stay at `-O2` instead of starving at `-Os`
- **One-shot BGM** — `mdp_play_once()` → MD+ `$11xx` (adapter already decodes `track_loop=0`)
- **`0x88 audio_setting`** — VM DAC / NTSC bits at cart RAM `0x1800`/`0x1801`

### 1.2 SFX RTL (Pocket echo / pan / mixer)

| Path | Why keep |
|---|---|
| `rtl/PAPRIUM/audio_sfx.sv` | Pocket echo ring (~166 ms @ 33%), amp ×1.25, pan, cheap rate dividers off 48 kHz `dac_next_sample` (ALM-friendly) |
| `rtl/PAPRIUM/structs.sv` | `SfxOut.echo` / `.amp` bits the mixer needs |
| `rtl/PAPRIUM/audio_clock.sv` | Shared 48 kHz clocking |
| `rtl/PAPRIUM/paprium_cart.sv` | SFX/CMDLOG params; wires SFX into cart; Pocket cart deltas |

Blob SHAs already match Pocket `0.2.1` on `main` for `audio_sfx.sv`, `paprium_cart.sv`, `structs.sv`, `paprium_mdp_adapter.sv`, `mcu.txt`, etc. (see `docs/CART_OVERLAY_REVIEW.md`).

### 1.3 Cart / MCU / MiSTer integration (keep Pezz shell + Pocket DIFF)

| Keep | Notes |
|---|---|
| Pezz `MegaDrive.sv` / `rtl/cartridge.sv` / `rtl/sdram.sv` / `rtl/pad_io.sv` | Board contract, SDRAM port-2 MCU, SSF2 suppress, stream-pointer ack |
| `paprium_mdp_adapter.sv` | **Identical** Pocket ↔ Pezz; MCU MD+ command decode — **reuse as the CDDA command front-end** |
| `paprium_backup.sv` | **MiSTer 16-bit `.sav` port** (Pocket APF 8-bit port must stay discarded) |
| `mcu_core.sv` | **32 KB IMEM** + `$readmemh("rtl/PAPRIUM/mcu.txt")` |
| Mix constants | Paprium CDDA **+10 dB** (`cdda_mult = 294/256`) and SFX mix / clip path in `MegaDrive.sv` |

### 1.4 Explicit non-goals for this plan

- No FX68K soak / Paprium ISA experiments  
- No wholesale rewrite of Pezz `sys/`  
- No return to Pezz cue/WAV as the Paprium music asset  
- No RTL implementation in the first docs PR beyond optional “add files, leave unwired”

---

## 2. What is missing / wrong today

| Item | Pocket `0.2.1` | `Paprium_MiSTer` `main` today |
|---|---|---|
| Music asset | **`paprium.pcm`** (~543 MB PPAD IMA ADPCM) | **`paprium.pcm`** in DDR @ `0x04000000` (HPS/ioctl); cue/WAV not used for Paprium |
| Producer | `paprium_cdda_fetch.sv` → APF dataslot **id 300** | **`paprium_cdda_fetch.sv` → DDRAM read master** (Option D) |
| Ring + decode | `paprium_cdda_buf.sv` holds **IMA**; `paprium_ima_decode.sv` on read side | Same Pocket buf/ima (wired) |
| Consumer | `paprium_cdda_play.sv` (48 kHz, fade, mute, volume) | Same play module → `cdda_l/r` when `paprium_active` |
| Loop semantics | Honors MCU `$11xx` / `$12xx` in **FPGA** | Same (FPGA); Pezz cue path gated off for Paprium |

`rtl/PAPRIUM/` on `main` now has Pocket `0.2.1` `paprium_cdda_*.sv` / `paprium_ima_decode.sv` (**unwired**). Remaining gap: MiSTer DDR fetch + wire-up (M2+); Pezz MD+ still owns live music.

---

## 3. Pocket `0.2.1` CDDA — how it works (gh + local pin)

Inspected via GitHub API @ tag `0.2.1` and local clone `de08e5f`:

| File | Size | Blob SHA (git) |
|---|---|---|
| `rtl/PAPRIUM/paprium_cdda_fetch.sv` | 17741 | `cf89355a3e43…` |
| `rtl/PAPRIUM/paprium_cdda_buf.sv` | 6763 | `b8f4f6ac8b08…` |
| `rtl/PAPRIUM/paprium_cdda_play.sv` | 6076 | `2b9d2885e9b6…` |
| `rtl/PAPRIUM/paprium_ima_decode.sv` | 9807 | `78706ab89049…` |

Design reference: Pocket `docs/CDDA_DESIGN.md` (still authoritative for format + musical constants).

### 3.1 How bytes are obtained (APF dataslot — **not** openfile)

Shipping path abandoned `0x0192 openfile` (hardware always returned malformed-path err 4). Final design:

1. **One deferload dataslot**, id **`300`**, filename **`paprium.pcm`**  
   (`pkg/pocket/Cores/Koala_Koa.Paprium/data.json`: `"id": 300`, `"deferload": true`).
2. Core issues **`target_dataslot_read`** (APF cmd **0x0180**) with:
   - `target_dataslot_id = 300`
   - `target_dataslot_slotoffset` = byte offset in the blob
   - `target_dataslot_bridgeaddr` = landing window (`0x30000000` audio ring / `0x50000000` header)
   - `target_dataslot_length` = 24 (magic), 16 (table entry), or **4096** (chunk)
3. APF writes into the BRIDGE; `data_loader` instances catch writes (masks `4'h5` header, `4'h3` ring) and cross into `clk_sys`.

So: **random-access read of one large file by (slot, offset, length)** — that is the contract to replace on MiSTer.

### 3.2 Blob format (`PPAD`)

```
0x00   "PPAD"
0x04   u32 version=1, rate=48000, channels=2, block_samples=505, ntracks≥64
0x18   64 × { u64 offset, u32 adpcm_bytes, u32 pcm_samples }
0x1000 IMA ADPCM data (512 B frames; tracks padded to 4096 B chunks)
```

Fetch **vetoes** the blob (`S_MAGIC`) before any table walk. Wrong/missing magic → `playing=0`, silence (no noise from stale raw-PCM). Size on disk ~**543 MB** (vs ~2.09 GB raw PCM).

### 3.3 Module data path

```
paprium_mdp_adapter
        │ mdp_track_request / stop / fade / volume / resume
        ▼
paprium_cdda_fetch  (clk_74a)  ──APF dataslot read──► SD file paprium.pcm
        │ chunk Gray flow
        ▼
data_loader → paprium_cdda_buf  (16 KB ring holds IMA)
        │
        ▼
paprium_ima_decode  (read-side; 512 B frame → 505 stereo samples)
        │
        ▼
paprium_cdda_play   (48 kHz /1119, fade, ~50 ms mute, volume)
        │
        ▼
core_top / MegaDrive mix  (+ paprium_sfx_*; CDDA +10 dB)
```

Status back to MCU: `mdp_playing`, `mdp_current_track` (synced from fetch).

### 3.4 Top-level hooks Pocket `core_top` needs (map → MiSTer)

| Pocket hook | Purpose | MiSTer analogue |
|---|---|---|
| `target_dataslot_read/ack/done/err` + id/offset/addr/length | Producer I/O | **Replace** (see §5) |
| `data_loader` @ `4'h5` / `4'h3` | Land header + chunks | Drop with APF; feed buf write port directly from new reader |
| `clk_74a` vs `clk_sys_53_69` + `synch_3` toggles | CDC for pulses / Gray chunks | Keep pattern; fetch may move to `clk_sys` if reader is DDRAM-synchronous |
| `PAPRIUM` generate | Gate CDDA stack | Same in `MegaDrive.sv` |
| Mix `cdda_l/r` + SFX + FM/PSG | Audio out | Already in Pezz `MegaDrive.sv` — retarget source of `cdda_*` |
| `mdp_*` from cart / adapter | Command channel | **Keep**; stop feeding `hps_ext` for Paprium |

---

## 4. Pezz MD+ path — what to disconnect vs keep

### 4.1 Current Pezz wiring (seed-work / Pezz V.06)

```
MCU → paprium_mdp_adapter → mdp_* pulses
                              ├─► hps_ext (EXT_BUS 0x60/61/62) ─► Main_MiSTer mdplus.cpp
                              │         ▲                              │ cue+WAV → DDR 64 KB PCM ring
                              │         └──── playing / wr_ptr ────────┘
                              └─► mdp_audio (DDRAM master) ─► cdda_l/r ─► mix (+10 dB if paprium_active)
```

Also: `md_plus.sv` cart MD+ path muxed when `!paprium_active` (non-Paprium MD+ games).

### 4.2 Disconnect for Paprium music (required)

| Piece | Action |
|---|---|
| `hps_ext` MDP STATUS/ACK/AUDIO for **Paprium** | **Stop** forwarding Paprium `mdp_*` into EXT_BUS; do not require `mdplus.cpp` for Paprium |
| Main_MiSTer `support/megadrive/mdplus.cpp` cue/WAV | **Not used** for Paprium soundtrack |
| SD layout `paprium.cue` + `01 ….wav` … | **Replace** with single **`paprium.pcm`** under the Paprium games dir |
| `mdp_audio.sv` as HPS-fed PCM consumer | **Replace** with Pocket `paprium_cdda_play` (+ buf/ima), or gut `mdp_audio` until unused |
| Docs that mandate cue/`REM NOLOOP` for music | Rewrite: loop is FPGA `$11`/`$12` (Pocket). Cue notes become historical only |

### 4.3 Keep (SFX and shell)

| Piece | Why |
|---|---|
| Cart SFX engine path (`paprium_sfx_l/r` → mix) | Pocket SFX; unrelated to CDDA producer |
| `cdda_mult` +10 dB when `paprium_active` | Same A/B constant Pocket carried over |
| `paprium_mdp_adapter` | Command decode shared |
| Non-Paprium `md_plus` + optional HPS MD+ | Only if we still want generic MD+ ROMs on this RBF; can stay behind `!paprium_active`. If that path is unwanted, leave dormant — do not let it own Paprium BGM |
| DDRAM channel ownership | Pezz already gives CDDA the DDRAM port — **reuse** for either whole-blob storage or the small PCM/IMA landing region |
| `rate_48k` / 1119 divider idea | Keep **48 kHz** consume; Pocket play already hardcodes it |

---

## 5. MiSTer replacement for APF dataslot (large ~543 MB blob)

### 5.1 Patterns available

| Mechanism | Typical use | Fit for `paprium.pcm` |
|---|---|---|
| **ioctl download** (`hps_io` → `ioctl_download/wr/addr/data`, index-selected) | ROM/BIOS into SDRAM/BRAM at load | **Yes for full preload** into DDR: 543 MB < DE10 1 GB DDR3; slow once at boot, then FPGA-owned |
| **HPS EXT_BUS + shmem DDR ring** (Pezz `hps_ext` / `mdplus.cpp`) | Continuous stream of **decoded PCM** from many WAVs | Wrong asset shape; would need a **new** HPS helper that understands **PPAD** seeks |
| **SD block / `img_mounted` + `sd_lba`** | Floppy/CD images | Possible but heavier; overkill if ioctl preload works |
| **BRAM-only** | Pocket 16 KB ring | Insufficient for the **file**; ring stays 16 KB — file lives in DDR or on SD via HPS |

### 5.2 Recommended approach — **Option D: DDR-resident PPAD + Pocket consumer RTL**

**Idea:** At ROM/core load, HPS (or ioctl secondary index) copies **`paprium.pcm`** into a fixed DDRAM base (e.g. high DDR, clear of the old 64 KB MD+ ring or replacing it). FPGA `paprium_cdda_fetch` is rewritten as a **DDRAM read master** that performs the same state machine as Pocket (`S_MAGIC` → `S_HDR` → chunked `S_READ`), but substitutes:

| Pocket APF | MiSTer |
|---|---|
| `target_dataslot_slotoffset` | DDRAM byte address = `BLOB_BASE + offset` |
| `target_dataslot_length` | burst length / beat count |
| BRIDGE + `data_loader` | DDRAM_DOUT → write into `paprium_cdda_buf` (or small bounce FIFO) |
| `clk_74a` fetch domain | Prefer **`clk_sys`** next to DDRAM (drop APF CDC), keep Gray/chunk protocol to buf **or** simplify to single clock |

**Keep unchanged (or nearly):**

- `paprium_cdda_buf.sv`
- `paprium_ima_decode.sv`
- `paprium_cdda_play.sv`
- `paprium_mdp_adapter.sv` command pins
- Mix / +10 dB / SFX

**Rewrite / new:**

- `paprium_cdda_fetch.sv` — strip APF ports; add DDRAM read port (can mirror `mdp_audio`’s master style)
- `MegaDrive.sv` — instantiate Pocket stack; **do not** drive Paprium `mdp_*` into `hps_ext`; point `cdda_l/r` at `paprium_cdda_play`
- `files.qip` — add the four CDDA/IMA sources
- Optional thin HPS: `ioctl` index for `paprium.pcm` **or** `FileLoad` into shmem once in a tiny `paprium_pcm.cpp` (not cue parsing)

**Why this beats “teach mdplus.cpp PPAD”:**

- Loop / fade / one-shot stay in FPGA (Pocket semantics; no cue `REM NOLOOP` tax)
- Magic/table checks stay in FPGA (fail silent, same as Pocket)
- No dependency on Main_MiSTer MD+ cue parser for Paprium
- Reuses the hard-won IMA read-side decode (M10K budget already solved on Pocket)

**Risks / mitigations:**

| Risk | Mitigation |
|---|---|
| 543 MB load time from SD | Show OSD progress; allow “music optional” if file missing (`blob_ok=0` → silent BGM, game still runs) |
| DDR bandwidth vs VDP/MCU | Same channel Pezz already gave CDDA; chunk 4 KB @ << 48 kHz×IMA demand; measure underruns (play already exports counter) |
| ioctl size limits in user_io | Verify on hardware; fallback = HPS `FileReadAdv` loop into shmem (still one-shot fill, not cue stream) |
| Address map clash with cheats/other DDR users | Pick base explicitly; document; assert range in docs |

### 5.3 Rejected / backup options

| Option | Verdict |
|---|---|
| **A — Keep Pezz WAV+cue** | **Rejected** by goal correction |
| **B — HPS streams PPAD on demand into 64 KB PCM ring** (decode in Linux) | Feasible but **forks** Pocket behavior into software; loses FPGA magic check / loop fidelity unless carefully duplicated; larger Main_MiSTer surface |
| **C — HPS streams **IMA chunks** into BRAM ring on EXT_BUS request** | Closest software analogue to dataslot; more handshake work; OK **fallback** if full DDR preload fails ioctl limits |
| **Import Pocket APF/bridge** | Impossible on MiSTer |

---

## 6. File list

### 6.1 Restore from Pocket `0.2.1` (copy blobs)

```
rtl/PAPRIUM/paprium_cdda_fetch.sv   # then edit: APF → DDRAM (first RTL PR)
rtl/PAPRIUM/paprium_cdda_buf.sv      # expect keep
rtl/PAPRIUM/paprium_cdda_play.sv     # expect keep
rtl/PAPRIUM/paprium_ima_decode.sv    # expect keep
```

Optional later: Pocket `scripts/build_cdda_adpcm.py`, `convert_cdda_to_adpcm.py`, `verify_ima_decode.py` / `verify_ppad_header.py` under `scripts/` for asset rebuild docs (not required in first RTL PR).

### 6.2 Must-keep (already on `main` — do not revert)

```
rtl/PAPRIUM/mcu.txt
rtl/PAPRIUM/mcu_core.sv          # 32 KB IMEM + readmemh path
rtl/PAPRIUM/audio_sfx.sv
rtl/PAPRIUM/structs.sv
rtl/PAPRIUM/audio_clock.sv
rtl/PAPRIUM/paprium_cart.sv
rtl/PAPRIUM/paprium_mdp_adapter.sv
rtl/PAPRIUM/paprium_backup.sv     # MiSTer .sav variant
rtl/PAPRIUM/paprium_mcu_mem.sv
rtl/PAPRIUM/ramdp_io.sv
rtl/PAPRIUM/fpgio.sv
rtl/PAPRIUM/memory.sv
rtl/PAPRIUM/paprium_defs.sv
patches/mega-ppm-pocket.patch
patches/README.md
scripts/build_mcu.sh
```

### 6.2b Also added (Quartus Lite 21.1)

`sys/pll_q21.qip` — copy of `pll_q17.qip` so `sys.qip`’s versioned `pll_q*.qip` include resolves under Quartus **21.1** Lite.

### 6.3 Edit (MiSTer shell)

| File | Change |
|---|---|
| `MegaDrive.sv` | Instantiate CDDA stack; mux `cdda_*` from play; gate Paprium away from `hps_ext`; keep SFX mix |
| `files.qip` | Add four CDDA/IMA SV files |
| `hps_ext.sv` | Leave for non-Paprium MD+ **or** stub; Paprium must not depend on it for BGM |
| `rtl/mdp_audio.sv` | Remove from Paprium path (delete later once unused) |
| `README.md` / install docs | **`paprium.pcm`**, not cue/WAV |
| `docs/MISTER_PORT.md` | Errata pointer to this doc for CDDA |
| `docs/paprium.cue` | Demote to historical / converter input only |

### 6.4 Do not import

```
target/pocket/**          # APF core_top, bridge, data_loader
platform/pocket/**
pkg/pocket/**             # except as reference for slot id / filename
paprium_cmd_log.sv        # optional diag only
```

---

## 7. SD / user asset contract (explicit)

```
/media/fat/games/MegaDrive/Paprium/
  Paprium.md          # (or whatever dump name the core expects)
  paprium.pcm         # PPAD IMA blob ~543 MB — REQUIRED for music
```

- **Music = pcm, not cue/wav.**  
- Missing/invalid `paprium.pcm` → BGM silent, gameplay + SFX still work (`blob_ok=0`).  
- Build blob with Pocket scripts from a legal rip; do not ship the soundtrack in-repo.

---

## 8. Milestone order

| # | Milestone | Size | Exit criteria |
|---|---|---|---|
| **M0** | **This doc on `main`** | Docs PR | `POCKET_CDDA_MISTER.md` pushed; README points at pcm-not-cue |
| **M1** | Restore CDDA/IMA sources + `files.qip`; **unwired** (no instantiate) | Small RTL | **DONE** — blobs match Pocket `0.2.1`; qip lists four files; Pezz MD+ untouched |
| **M2** | DDRAM fetch rewrite + `MegaDrive.sv` wire-up; disconnect Paprium from `hps_ext` music | Medium RTL | Sim or bench: magic OK, track table read, underrun counter live |
| **M3** | ioctl / HPS one-shot load of `paprium.pcm` into DDR | Small HPS or ioctl-only | File on SD → DDR; missing file → silent |
| **M4** | Hardware soak | — | BGM + Pocket SFX; one-shots; elevator/anim unchanged vs overlay baseline |
| **M5** | Remove dead Pezz MD+ music deps from Paprium docs/release zip | Docs/cleanup | No cue/WAV instructions for Paprium |

---

## 9. First PR size (concrete)

**PR-0 (now): docs only — target this file.**

- Add `docs/POCKET_CDDA_MISTER.md` (this plan).  
- One-line errata in `docs/MISTER_PORT.md` / README: *Paprium music = Pocket `paprium.pcm`, not Pezz cue/WAV; SFX+firmware overlays remain must-keep.*  
- **No RTL** in PR-0 unless a trivial “add four files to tree, not in qip” is desired; default = **docs only**.

**PR-1 (next, still small):** M1 — copy four Pocket SV files + `files.qip` lines + dead instantiate or `ifdef` off. No fetch rewrite yet. Diff order-of-magnitude: **~4 SV copies + qip + top stubs** (hundreds of lines added, little behavior change).

**PR-2:** M2+M3 — real APF→DDRAM fetch + load path (the first **behavioral** music PR).

---

## 10. Success checklist (for reviewers)

- [x] Pocket fetch/buf/play/ima inspected (dataslot 300, PPAD, top hooks)  
- [x] Pezz `mdp_adapter` / `hps_ext` / `mdp_audio` disconnect vs keep listed  
- [x] MiSTer large-blob path chosen (DDR-resident PPAD; ioctl/HPS fill)  
- [x] Must-keep Pocket SFX + `mcu.txt`/patches + cart overlays called out  
- [x] Music = **pcm**, not cue/wav  
- [x] File restore list + APF replacement interface + first PR size stated  
- [x] M1: four CDDA/IMA SV + `files.qip` on `main`, **unwired** (no instantiate in `MegaDrive.sv` / `paprium_cart.sv`)
- [x] M2 RTL (DDR fetch rewrite + MegaDrive wire-up; Paprium off hps_ext music)
- [~] M3 load path (ioctl FS3 stub + documented DDR base `0x04000000`; full HPS mmap helper TBD)
- [ ] M4 hardware soak

---

## 11. Errata for older graft docs

| Doc | Old claim | Correction |
|---|---|---|
| `MISTER_PORT.md` | Keep Pezz HPS/MD+ WAV+cue; do not import Pocket CDDA RTL | Import Pocket CDDA/IMA; replace APF with DDR blob reader; **pcm** asset |
| `CART_OVERLAY_REVIEW.md` | “CDDA Pezz preserved; Pocket APF not imported (good)” | Good that APF was not imported; **bad** that Pocket CDDA **behavior** was dropped — restore via §5 |
| `PAPRIUM.md` / Pezz README | Cue + WAV required | Historical for Pezz upstream only; this fork uses `paprium.pcm` |
| `FORK_BRIEF.md` | “bring firmware + CDDA path” | Affirmed: firmware/SFX **already** on main; CDDA/pcm is the remaining restore |

---

*End of plan. Implement M1+ only after this doc is on the repo.*
