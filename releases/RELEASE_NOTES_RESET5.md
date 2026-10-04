# Paprium MiSTer core — RESET5 s1 (DRAFT release notes)

Paprium MiSTer core — RESET5 s1, hardware-verified (the maintainer, 2026-10-03).

## Timing exception
Timing exception on clk_107m: WNS -0.761 (TNS -25.006, 73 failing rows); clk_53m WNS -0.117 (TNS -0.117, 1 row); hold min -0.116 by corner scan (STA summary 0.072). mcu_dati rows 0, streaming_pcm rows 0.

## Build
- ALM 25,733/41,910, M10K 339/553, DSP 61/112 (registers 44,081).
- rbf md5 2b1befb0aefb720aa8a0eaa9cf4e21e9, 3,823,828 bytes, Quartus 21.1.1, seed 1.

## Changes vs RESET1
- No Hard Reset item, no Load/Save Backup RAM items, no Autosave item.
- The OSD order is Mount music, Reset core, then the Music PCM info line (the I, info line moved after R[0],Reset so the Reset core row no longer resolves to the wrong menu item on Main MiSTer_20260823).
- Progress saves automatically when the OSD is opened.
- A first launch with no save starts at the mini-game.

## Open item
The 30+ minute soak (song change, FX cuts, save and reload) is still open.

## Launcher
Paprium.mgl, only the rbf line differs from the test launcher.