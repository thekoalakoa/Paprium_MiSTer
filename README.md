# Paprium_MiSTer

Standalone **MiSTer** core for **Paprium** (WaterMelon).

**Seeded from** [MisterPezz82/Paprium_MegaDrive_MiSTer](https://github.com/MisterPezz82/Paprium_MegaDrive_MiSTer) branch `paprium-mdplus-port` (`2c256d5910e2`, V.06), with **Pocket shipping `0.2.1` overlays** (firmware + Paprium RTL deltas, including Pocket CDDA/IMA) on top. MiSTer framework (`sys/`, HDMI, SDRAM, OSD, controls) comes from Pezz; shipping fixes come from Pocket. This is **not** a Pocket openFPGA tree, and it is **not** based on FX68K soak experiments.

> **Pins:** Pezz `2c256d5910e29e28fc21df5f65b68d70069880c3` · Pocket tag [`0.2.1`](https://github.com/thekoalakoa/paprium-pocket/releases/tag/0.2.1) (`de08e5f999fba2f820026e5c9d49088b9850aa52`).

## Status

Option A graft landed (Pezz shell + Pocket overlays). **Paprium BGM uses Pocket `paprium.pcm` (PPAD IMA)** via the Pocket CDDA stack on DDRAM — **not** Pezz cue/WAV / `mdplus.cpp`. Port map: [docs/MISTER_PORT.md](docs/MISTER_PORT.md). CDDA plan: [docs/POCKET_CDDA_MISTER.md](docs/POCKET_CDDA_MISTER.md).

No bitstream in this repo yet — next step is Quartus build + hardware soak.

## What you must supply

Same as Pocket: **your own cartridge dump** and **`paprium.pcm`** for background music (PPAD IMA ADPCM blob, ~543 MB). Neither is included or linked here.

### SD layout (Paprium)

```
/media/fat/games/MegaDrive/Paprium/
  Paprium.md       # your dump (name as required by the core)
  paprium.pcm      # REQUIRED for music — not cue/WAV
```

- **Music = `paprium.pcm`, not `.cue` / WAV.**
- Missing or invalid `paprium.pcm` → **silent BGM**; gameplay + Pocket SFX still work (`blob_ok=0`).
- Build the blob with Pocket `0.2.1` scripts from a legal rip.
- FPGA DDR base for the blob: **`0x04000000`** (see `PAPRIUM_PCM_BASE` in `MegaDrive.sv`). Full ~543 MB load needs an HPS one-shot fill into that address (ioctl FS3 is capped by `ioctl_addr` width ~128 MiB — fine for test stubs only).

## Lineage (GPLv3)

- [Nuked-MD-FPGA](https://github.com/nukeykt/Nuked-MD-FPGA)
- [MegaDrive_MiSTer](https://github.com/MiSTer-devel/MegaDrive_MiSTer)
- [Paprium_MegaDrive_MiSTer](https://github.com/MisterPezz82/Paprium_MegaDrive_MiSTer) (Pezz — MiSTer shell)
- [paprium-pocket](https://github.com/thekoalakoa/paprium-pocket) (Pocket `0.2.1` overlays)
- [mega-ppm](https://github.com/krikzz/mega-ppm)

## Licence

GPLv3 — see upstream projects.
