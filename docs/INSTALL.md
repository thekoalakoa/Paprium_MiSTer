# Paprium for MiSTer: installation (0.3.0)

This is a standalone MiSTer core for **Paprium** (WaterMelon). It is a Mega Drive core with Paprium's cartridge hardware added, ported from the [Analogue Pocket Paprium core](https://github.com/thekoalakoa/paprium-pocket).

**You need your own copy of the game.** This project doesn't include one and won't link one. WaterMelon have stopped trading and the game isn't sold anymore, but that doesn't make it public domain. It's still their work.

This release only adds Paprium files (`Paprium.rbf`, `Paprium.mgl`, and the firmware file). It does not replace MiSTer Main, Linux, or other system files.

---

## What you need

- A MiSTer (DE10-Nano) with an up-to-date MiSTer main binary.
- Your own copy of the game, named `Paprium.md`.
- The 0.3.0 download from the [release page](https://github.com/thekoalakoa/Paprium_MiSTer/releases/latest): **`Paprium_MiSTer_0.3.0.zip`**.

You can forget the soundtrack file `paprium.pcm`, and the `paprium.cue` next to it. 0.3.0 doesn't read either.

---

## Before you install: keep a copy of your save

First, copy your save to your PC:

```
saves/Paprium/Paprium.sav
```

That's your game progress. The first time 0.3.0 starts, it converts a 0.2.x save once into the cart's own format (see [First start](#first-start)). Going back to 0.2.6 with a converted save hasn't been tested, so hang on to that copy until you're sure you're staying on 0.3.0.

---

## Install

1. **Copy your save** like above.
2. **Unzip `Paprium_MiSTer_0.3.0.zip` onto the SD card** and merge with the folders already there. It puts `Paprium.rbf` and `Paprium.mgl` in `_Console`, replacing any older copies, and puts Little-Man Firmware 1.0 at `games/Paprium/little_man_firmware.bin`.
3. **Keep your copy of the game where it is**, named exactly this:

   ```
   games/Paprium/Paprium/Paprium.md
   ```

   `Paprium.mgl` only ever loads that path. Any other name won't be found. You can still load a ROM by hand from the OSD if you need to. The mgl itself is:

   ```
   <mistergamedescription>
       <rbf>_Console/Paprium</rbf>
       <!-- 0.3.0: load the Little-Man firmware first, from games/Paprium/little_man_firmware.bin, through the OSD's "Load Little-Man Firmware" row (F4), then the game. -->
       <file delay="1" type="f" index="4" path="/media/fat/games/Paprium/little_man_firmware.bin"/>
       <file delay="1" type="f" index="1" path="/media/fat/games/Paprium/Paprium/Paprium.md"/>
   </mistergamedescription>
   ```

   It loads the firmware first, from `games/Paprium/little_man_firmware.bin`, then the game. The firmware is not auto-loaded by MiSTer by filename.
4. **Optional: delete the old soundtrack files**, `games/Paprium/Paprium/paprium.pcm` and the `paprium.cue` next to it. 0.3.0 never touches them. If you think you might go back to 0.2.6, keep them, since 0.2.6 needs the soundtrack for music. If you still have a `boot1.rom` or `LittleMan.bin` in `games/Paprium/` from an earlier test build, you can delete it. A leftover `config/Paprium.s1` is only Main's memory of the old 0.2.6 soundtrack pick; 0.3.0 doesn't use it, and you can delete that too. 0.3.0 uses `little_man_firmware.bin`, which Paprium.mgl loads.

Once you're done, the card should have:

```
_Console/Paprium.rbf
_Console/Paprium.mgl
games/Paprium/little_man_firmware.bin                Little-Man Firmware 1.0
games/Paprium/Paprium/Paprium.md           your own copy of the game
saves/Paprium/Paprium.sav                  your save
```

Put the card in the MiSTer and launch **Paprium.mgl**. Paprium.mgl loads the game and the firmware file. The firmware is not auto-loaded by MiSTer by filename.

---

## First start

Each time you start the core, the screen stays black while it unpacks the game's sounds from your copy of the game. There is no progress bar, and MiSTer does not keep a sound-cache file, so this happens on every launch. Don't press anything. Then the game starts.

The first start also **converts a 0.2.x save**, just once. Every save slot that has a game in it gets rewritten in the cart's own format, in the same spot. It only happens once: if a save is already in the cart's format, it's left alone. From 0.3.0 on the save file is 8 KB, the same size as the cart's own save chip (0.2.x saves are smaller).

**If you have no save at all**, the game starts on its first-boot **mini-game**, the same as a brand-new cart does. That's the cart's own behaviour, not a bug in the core. With **3-Player Mode** on (or Arcade Mode on Multiplayer) the mini-game may only listen to controller 3, just like on a real console with the adapter plugged in, so leave those off for the first boot. Play or skip the mini-game, then hit **Reset** in the OSD and the game boots properly.

You only get the mini-game once. The cart records it in its save, and the save lives on the SD card, so no reset or power cycle brings it back. If you want to see it again (with the language-selection screen), rename your save file. Don't delete it, it's your progress. Rename it back afterwards and you'll carry on where you left off.

---

## A plain red screen

If the screen goes **plain red**, with no text and no sound, and the game never starts, the core has turned down the firmware file. Either the file is missing, damaged, or it was made for a different core version.

Here's the fix:

1. Copy `little_man_firmware.bin` from the 0.3.0 release zip into `games/Paprium/`, replacing the one that's there. The name has to be exactly `little_man_firmware.bin`.
2. Start the core again from **Paprium.mgl**.

The firmware's red screen has no text at all. Don't mix it up with the game's own red "0012" screen. That one shows up on purpose when you set Arcade Coins to "Inf. Credits (0012)".

---

## The core and the firmware file belong together

The core and the firmware file have to match:

- **0.3.0 takes Little-Man Firmware 1.0.** Every core release says which firmware version it takes.
- **A firmware-only update is just a file swap.** Replace `games/Paprium/little_man_firmware.bin` and start the core from Paprium.mgl. Each firmware release will say which core versions it runs on.
- **A firmware file made for a different core version gets turned down** with the red screen above.
- For testing, **Load Little-Man Firmware** in the OSD can load a file by hand. For normal play, leave `little_man_firmware.bin` where the zip put it, and launch Paprium.mgl, which loads it.

---

## Going back to 0.2.6

1. Put the 0.2.6 `Paprium.rbf` and `Paprium.mgl` back in `_Console` (from the 0.2.6 zip, or from the backup you made before installing 0.3.0).
2. Put back the copy of `Paprium.sav` you made before you installed 0.3.0.
3. 0.2.6 still needs `paprium.pcm` for its music, same as before, in `games/Paprium/Paprium/`, and the `paprium.cue` next to it if you used one. If you kept `config/Paprium.s1`, 0.2.6 can use that to remember the soundtrack path.

0.2.6 doesn't use `little_man_firmware.bin`. You can leave that file on the card. A leftover `boot1.rom` or `LittleMan.bin` from an earlier test build isn't used either, and you can delete it.

---

## OSD settings

You get to these from the MiSTer OSD while the core is running. Anything under **SCUM! (Needs Reset)** is read when the game boots, so change it first and then hit **Reset**. The **USER** button on the MiSTer does the same full reset as **Reset** in the OSD.

For what each one does, plus CPU MATE, see the [OSD guide](../README.md#osd-guide) in the README.

### The in-game "VM DAC" option

Paprium's own options menu has a **VM DAC** checkbox. It picks between the game's two sound options, YM and Datenmeister, and in 0.3.0 both work the way the cart's do. Up to 0.2.6 it made no audible difference here. What the cart's own output circuit does in Datenmeister mode isn't reproduced: see [Known differences](../README.md#known-differences-from-the-original-cartridge).

---

## Credits

The credits, with what each project gave this core, are in the README's [Lineage](../README.md#lineage) and [History](../README.md#history). Licensed under GPLv3 or later; the notices for the parts under other licences are in `THIRD_PARTY_NOTICES.md`, in the repository and in the release package.
