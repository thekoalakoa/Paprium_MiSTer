# Paprium MiSTer core - release paprium-20261003

Hardware-verified.

## Timing exception
Timing exception on clk_107m: WNS -0.761 (TNS -25.006, 73 failing rows); clk_53m WNS -0.117 (TNS -0.117, 1 row); hold min -0.116 by corner scan (STA summary 0.072). mcu_dati rows 0, streaming_pcm rows 0.

## Build
- ALM 25,733/41,910, M10K 339/553, DSP 61/112 (registers 44,081).
- rbf md5 2b1befb0aefb720aa8a0eaa9cf4e21e9, 3,823,828 bytes, Quartus 21.1.1, seed 1.

## OSD
- There is no Hard Reset item, no Load/Save Backup RAM item and no Autosave item.
- The OSD order is Mount music, Reset core, then the Music PCM info line (the info line comes after Reset so the Reset core row does not resolve to the wrong menu item on Main MiSTer_20260823).
- Progress saves automatically when the OSD is opened.
- A first launch with no save starts at the mini-game.

## Open item
The 30+ minute soak (song change, FX cuts, save and reload) is still open.

## Files
`Paprium.rbf` and `Paprium.mgl` (this directory's `Paprium.mgl`) are attached to the GitHub release. The user supplies their own ROM and `paprium.pcm`; none are included.