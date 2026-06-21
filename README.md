Paprium for MiSTer Mega Drive

A MiSTer Mega Drive core fork bringing Everdrive Pro Style Paprium support to Mister FPGA, with working MCU/cart behaviour, streamed graphics, CDDA/MD+ music, 

This project builds on years of community reverse-engineering, preservation, emulator work, and flash-cart development.

Based on prior work by:
Krikzz / mega-ppm
Project Little Man
TheHpman / MAME Paprium research
MAVProxyUser / Genesis Plus GX Paprium PR
Paprium preservation community

Special thanks:
MiSTer Mega Drive core developers
Genesis Plus GX / MAME contributors
Everyone who helped test, document, and preserve Paprium


ROM and WAV assets are not included.
Bring your own Paprium dump and audio files.

If only there were some kind of archive on the internet...

## Required Files

Create this folder on your MiSTer SD card:

```text
/media/fat/games/MegaDrive/Paprium/
Place the ROM and WAV files there:

├── Paprium.md
├── paprium.cue
├── 01 Theme of Paprium.wav
├── 02 90's Acid Dub Character Select.wav
├── 03 Bone Crusher.wav
├── 04 Drumbass Boss.wav
├── 05 Asian Chill.wav
├── ...
└── 52 Waterfront Beat.wav
Load Paprium.md from the Mega Drive Paprium core.
