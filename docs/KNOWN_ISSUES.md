# Paprium (MiSTer) — Known Issues & Bug Log

A running log of known bugs and our investigation notes. This port is an
EverDrive-Pro-style hack (see `PAPRIUM.md`), so some game behaviour is still
imperfect. Status key: **Open** · **Investigating** · **Fixed**.

> Architecture reminder: the 68000 runs the game; the NEORV32 **MCU** (running
> the `mega-ppm` firmware) handles the cart protocol — decompression, sprite/
> animation/object lists, and BGM requests. Many behaviour bugs are therefore
> MCU-firmware or MCU↔68000-handshake issues, not pure RTL.

---

## Open

### 1. 6-button controller support missing
- **Symptom:** X/Y/Z/Mode aren't recognised. The OSD "6 Buttons Mode" option and
  the mapped Mode button do nothing. 3-button input works (game is playable).
- **Status:** Investigated, open.
- **Notes / leads:**
  - The core's `pad_io.sv` 6-button machinery is generic and works on other MD
    games, so this is Paprium-specific.
  - Disassembly: Paprium's main pad read at ROM `0xaae0` is a standard **3-button**
    read (sets `A10009=$40`, one TH toggle, reads `A10003`). The **6-button
    extended read isn't visible** in the static ROM — likely in MCU-decompressed
    code or dynamically addressed, so we can't see how it diverges from the core.
  - **Next:** a controller-port diagnostic to capture the actual TH-toggle
    sequence Paprium emits vs the JCNT/state `pad_io` returns.

### 2. Animation / enemy AI behaviour incorrect
- **Symptom:** Some animations and enemy AI behaviour are wrong.
- **Status:** Open.
- **Notes / leads:**
  - The MCU drives the sprite/animation/object system and likely AI helpers
    (firmware `paprium_sprite` / object + animation lists). So this is probably
    MCU-firmware behaviour or MCU timing, not VDP/RTL.
  - The `0x81` decompression fix (2026-06-22) corrected some graphics — re-check
    which animations are *still* wrong now.
  - Candidate causes: MCU command timing, an unimplemented/under-implemented MCU
    feature, or animation data that depends on a still-imperfect code path.

### 3. Intercom elevator not working
- **Symptom:** The elevator in the Intercom stage doesn't function.
- **Status:** Open.
- **Notes / leads:**
  - Likely a scripted-event / MCU-command interaction specific to that stage.
  - Candidates: input that isn't registering (does it need a button tied to the
    6-button issue?), an MCU command/response the core doesn't handle, or area-
    specific data. **Next:** identify the elevator trigger (input vs MCU event).

### 4. Subway station stall (before boarding the train)
- **Symptom:** *Occasionally* the game gets stuck in the subway station before
  you get on the train — enemies stop appearing and the screen stops scrolling.
- **Status:** Open.
- **Notes / leads:**
  - "Occasionally" + "everything stops" = a **stall/race**, the game logic
    waiting on something that doesn't arrive.
  - Candidates: an MCU↔68000 mailbox handshake that intermittently hangs, a
    decompression/stream-window stall, or a timing race in object spawning.
  - **Next:** capture the mailbox / stream-pointer / MCU state at the moment of
    the stall (DDR diagnostic) to see what it's waiting on.

### 5. "12 Stage Clear.wav" (end-of-level jingle) doesn't play
- **Symptom:** The stage-clear music (track 12) doesn't play at end of level.
- **Status:** Open.
- **Notes / leads:**
  - BGM is requested by the MCU via MD+ commands, bridged to CDDA by
    `paprium_mdp_adapter.sv`. A specific track not playing points to the
    track-request path for that cue.
  - Candidates: the track index/mapping for the stage-clear cue, handling of
    **short / non-looping** cues vs looping BGM, or the cue simply not being
    requested. **Likely shares a root cause with #6.**
  - **Next:** log the MD+ track-request commands the MCU issues at stage-clear
    and compare to the expected track number.

### 6. Music on the "punk screens" doesn't play
- **Symptom:** The music on the screens the punks see (in-game screen/cutscene)
  doesn't play.
- **Status:** Open.
- **Notes / leads:**
  - Same shape as #5 — a specific BGM cue not triggered/played. Probably the same
    root cause (short/one-shot CDDA cues, or a track-request mapping gap in the
    MD+ adapter). Investigate together with #5.

---

## Recently fixed (for context)

- **Subway & other graphics glitches** — corrected `0x81` LZ decompressor in the
  MCU firmware (GPGX/FBNeo routine vs the broken MAME one). *(2026-06-22)*
- **CDDA played ~8% slow** — WAVs are 48 kHz; CDDA now consumes at 48 kHz for
  Paprium. *(2026-06-22)*
- **Battery save (4 KB SRAM)** — now persists; also stops the fake-8-bit intro
  replaying. *(2026-06-21)*
- **CDDA too quiet vs SFX** — +10 dB Paprium-only boost. *(2026-06-21)*
- **Boot / graphics / CDDA / full cart SFX / SVP retained** — initial working
  port. *(2026-06-21)*
