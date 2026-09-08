# Paprium MiSTer — fork brief

**Owner:** Paprium MiSTer agent  
**Date:** 2026-09-08  
**Status:** repo created; next is graft-strategy doc before any large rewrite

## Goal

Standalone MiSTer core for Paprium (WaterMelon), carrying **Pocket shipping 0.2.1** behavior (firmware + Paprium RTL deltas that fixed elevator #8, anim/walk, SFX, CDDA path, etc.) onto the MiSTer framework — not a Pocket openFPGA tree with a MiSTer sticker.

## Base pin (do not move without explicit ask)

| Item | Value |
|---|---|
| Upstream source | `thekoalakoa/paprium-pocket` |
| Tag | `0.2.1` |
| Commit | `de08e5f999fba2f820026e5c9d49088b9850aa52` |
| Explicitly **not** base | `fx68k-soak-0.2.1` / any FX68K soak experiments |

Shipping notes from Pocket: anim attacks + walk screen-transition fixes; bitstream/fw era around c2bf6e66 / fd872d74. Nuked MD path only for this tree.

## Why a new repo (not a branch on paprium-pocket)

- Pocket stays Cyclone V 5CEBA4 / APF / openFPGA ship path (#8 stay-fixes, Claude fits).
- MiSTer needs `sys/`, board top, SDRAM/HDMI/audio/OSD/joysticks, DE10-Nano Quartus layout — different top, different build, different SD layout.
- Keeps FX68K flicker soak (Paprium ISA) and Pocket diagnostics out of the MiSTer history.

## Lineage (credit stays GPLv3)

1. Nuked-MD-FPGA → MegaDrive_MiSTer → drizzt openFPGA-MegaDrive → paprium-pocket  
2. MisterPezz82/Paprium_MegaDrive_MiSTer — cartridge RTL / MCU / mailbox baseline Pezz already has on MiSTer  
3. krikzz/mega-ppm — MCU firmware; Pocket `patches/` are the 0.2.1 delta we must carry  

**Positioning vs Pezz:** Pezz is the existing MiSTer Paprium core. We are not “another Mega Drive core.” We are a **Pocket-0.2.1-lineage** MiSTer core: bring Pocket’s proven firmware/RTL fixes + CDDA stack onto MiSTer `sys/`, preferably by forking/re-homing from Pezz’s MiSTer shell *or* grafting Pocket `rtl/PAPRIUM` + patches onto a MegaDrive_MiSTer-shaped tree. First implementation PR should pick one graft strategy after a short tree diff — no large rewrite until that choice is written down.

## In scope

- New repo layout + README/INSTALL/BUILD docs (branch-sized docs)
- MiSTer framework port: `sys/`, board top, SDRAM, HDMI, audio, OSD, joysticks
- Carry Pocket `0.2.1` Paprium firmware patches and relevant `rtl/PAPRIUM` / CDDA pieces
- Quartus project for DE10-Nano; release zip layout for MiSTer SD
- Prefer cloud agents for repo work when available; keep history separate from Pocket

## Out of scope (unless B Jam routes)

- Pocket ship path / Claude FPGA fit cards / Analogue Pocket #8 diagnostics
- FX68K soak / flicker / Paprium ISA custom-68k research
- MWMM / chip-synth reverse (Spec appendix; not this fork’s day one)

## Repo

**Canonical:** https://github.com/thekoalakoa/Paprium_MiSTer

## First milestones

1. ~~Create repo + seed fork brief~~
2. Doc-only: `docs/MISTER_PORT.md` — graft strategy Pezz-shell vs MegaDrive_MiSTer-shell, file map, what Pocket files die (APF/`platform`/`pkg/pocket`)
3. Skeleton: MiSTer `sys/` + top that builds *something* (even boot splash) before full Paprium graft
4. Bring firmware + CDDA path; hardware soak on DE10 / MiSTercade
   - Firmware/SFX/cart overlays: already on `main` (must-keep)
   - Remaining: restore Pocket CDDA/`paprium.pcm` — see `docs/POCKET_CDDA_MISTER.md` (not Pezz cue/WAV)

## Working style

Sharp technical collaborator; plain human notes when useful. One stream at a time. Prefer docs before large rewrites. Do not touch Pocket shipping or FX soak branches.
