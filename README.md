# Paprium_MiSTer

Standalone **MiSTer** core for **Paprium** (WaterMelon).

**Seeded from** [MisterPezz82/Paprium_MegaDrive_MiSTer](https://github.com/MisterPezz82/Paprium_MegaDrive_MiSTer) branch `paprium-mdplus-port` (`2c256d5910e2`, V.06), with **Pocket shipping `0.2.1` overlays** (firmware + Paprium RTL deltas) on top. MiSTer framework (`sys/`, HDMI, SDRAM, OSD, controls) comes from Pezz; shipping fixes come from Pocket. This is **not** a Pocket openFPGA tree, and it is **not** based on FX68K soak experiments.

> **Pins:** Pezz `2c256d5910e29e28fc21df5f65b68d70069880c3` · Pocket tag [`0.2.1`](https://github.com/thekoalakoa/paprium-pocket/releases/tag/0.2.1) (`de08e5f999fba2f820026e5c9d49088b9850aa52`).

## Status

Option A graft landed (Pezz shell + Pocket overlays). Port map: [docs/MISTER_PORT.md](docs/MISTER_PORT.md). Day-one notes: [docs/FORK_BRIEF.md](docs/FORK_BRIEF.md). Pezz upstream README preserved as [docs/PEZZ_UPSTREAM_README.md](docs/PEZZ_UPSTREAM_README.md).

No bitstream in this repo yet — next step is a Quartus skeleton build / cart overlay review.

## What you must supply

Same as Pocket: **your own cartridge dump** and, optionally, **your own soundtrack** for CDDA (via MiSTer HPS/MD+, not Pocket APF). Neither is included or linked here.

## Lineage (GPLv3)

- [Nuked-MD-FPGA](https://github.com/nukeykt/Nuked-MD-FPGA)
- [MegaDrive_MiSTer](https://github.com/MiSTer-devel/MegaDrive_MiSTer)
- [Paprium_MegaDrive_MiSTer](https://github.com/MisterPezz82/Paprium_MegaDrive_MiSTer) (Pezz — MiSTer shell)
- [paprium-pocket](https://github.com/thekoalakoa/paprium-pocket) (Pocket `0.2.1` overlays)
- [mega-ppm](https://github.com/krikzz/mega-ppm)

## Licence

GPLv3 — see upstream projects.
