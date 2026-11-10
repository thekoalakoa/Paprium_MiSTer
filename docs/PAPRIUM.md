# Paprium on the MiSTer Mega Drive core

This is the MiSTer port of the [Paprium Pocket core](https://github.com/thekoalakoa/paprium-pocket). It is a Mega Drive core with Paprium's cartridge hardware added.

From 0.3.0 the cart's chip runs our own firmware, Little-Man Firmware, and the music is made the way the cartridge makes it. You don't need a soundtrack file. Installation, the OSD, and the licence are in the root `README.md` and in [INSTALL.md](INSTALL.md).

## Arcade Mode

From 0.3.0, Arcade Mode lives under **SCUM! (Needs Reset) > Grand Stick Options**. It is a virtual Grand Stick III, with Off, On, Multiplayer and Stick Only. On and Multiplayer flip the stick's ARCADE switch, so the game turns on its own arcade mode. The 0.2.6 unlock that was based on [adroxe's Paprium-Arcade](https://github.com/adroxe/Paprium-Arcade) is no longer how this works; that work is still credited in the README's History.

## Paprium source files (`rtl/PAPRIUM/`)

The cartridge logic, the processor that runs the firmware, and the rebuild of the cart's sound chip live in `rtl/PAPRIUM/`. The firmware itself is not built into the bitstream. Paprium.mgl loads it from `games/Paprium/little_man_firmware.bin`. See [firmware/README.md](firmware/README.md).

The 0.2.x soundtrack path is not used, and the old soundtrack loader is no longer in the tree. 0.3.0 makes the music the way the cartridge does.

## Credits

Little-Man Firmware was written by our team from our own study of how the cart behaves. The core is built on the MiSTer Nuked-MD Mega Drive core. The full lineage is in the root README.
