# Paprium (MiSTer) — Known Issues & Bug Log

A running log of known bugs and our investigation notes. This port is an
EverDrive-Pro-style hack (see `PAPRIUM.md`), so some game behaviour is still
imperfect. Status key: **Open** · **Investigating** · **Fixed**.

> Architecture reminder: the 68000 runs the game; the NEORV32 **MCU** (running
> the `mega-ppm` firmware) handles the cart protocol — decompression, the
> sprite/animation/object lists, and BGM requests. Many behaviour bugs are
> therefore MCU-firmware, MCU **throughput**, or MCU↔68000-handshake issues,
> not pure VDP/RTL.

GitHub issue numbers are referenced as (#n).

---

## Open

### A. Character / enemy animations skipped (#10)
- **Symptom:** Characters slide without the walking animation, hit each other
  without the hit animation, or perform certain grabs without animation. **The
  more enemies on screen, the worse it gets.**
- **Status:** Open — strongest lead so far.
- **Leads:**
  - The "scales with on-screen enemy count" behaviour is the key clue: it points
    to the **MCU running out of per-frame processing time**. The MCU advances
    each object's animation frame and composes sprites every frame; with many
    objects it can't finish in the available window, so the 68000 keeps moving
    positions while the MCU-side animation frame doesn't update → **sliding /
    missing hit & grab animations**.
  - Candidate root causes: NEORV32 MCU clock too slow vs the real cart MCU; a
    per-frame object/time budget being exceeded; or an MCU↔68000 sync that drops
    work when the MCU is late.
  - **Next:** measure how long the MCU takes to process the object list per frame
    vs the budget; check the NEORV32 clock; see if the firmware caps objects.
  - May share a root cause with the subway stall (B) and elevator (C).

### B. Subway station stall before the train (#5)
- **Symptom:** *Occasionally* stuck in the subway station after clearing enemies
  — enemies stop appearing and the screen stops scrolling, can't progress.
  (Video: x.com/NeoCverA/status/2068909870263210445)
- **Status:** Open.
- **Leads:**
  - "Occasionally" + "everything stops" = a **stall/race**: the game waiting on
    something that doesn't arrive (a spawn/scroll trigger).
  - Candidates: an MCU↔68000 mailbox handshake that intermittently hangs; an MCU
    that falls behind (see A) and misses a trigger; a decompression/stream stall.
  - **Next:** capture mailbox / stream-pointer / MCU state at the moment of stall
    (DDR diagnostic) to see what it's waiting on.

### C. Intercom elevator: graphical corruption + background priority (#8)
- **Symptom:** Lots of graphical corruption in the elevator, and background
  **priority** problems (wrong layer ordering).
- **Status:** Open.
- **Leads:**
  - Two parts: (1) graphics *corruption* — possibly a decompression path other
    than the `0x81` one we fixed, or object/sprite data; (2) background
    *priority* — the BG/sprite priority bits are wrong, which is a tile/sprite
    attribute the MCU sets up.
  - **Next:** determine whether the corruption is decompression (which format?)
    vs object composition; check how priority is assigned for that scene.

### D. 6-button controller support missing (#4)
- **Symptom:** X/Y/Z/Mode not recognised; OSD "6 Buttons Mode" and the mapped
  Mode button do nothing. 3-button works (game playable).
- **Status:** Investigated, open.
- **Leads:**
  - Core `pad_io.sv` 6-button is generic and works on other MD games, so this is
    Paprium-specific.
  - Disassembly: Paprium's main pad read at ROM `0xaae0` is a standard **3-button**
    read (one TH toggle). The 6-button extended read isn't visible in the static
    ROM (likely MCU-decompressed or dynamically addressed).
  - **Next:** controller-port diagnostic to capture Paprium's TH-toggle sequence
    vs the JCNT/state `pad_io` returns.

### E. "12 Stage Clear" jingle doesn't play (#9)
- **Symptom:** When the stage ends and the score appears, `12 Stage Clear.wav`
  should play but doesn't.
- **Status:** Open.
- **Leads:**
  - BGM is requested by the MCU via MD+ commands → CDDA (`paprium_mdp_adapter`).
    A specific cue not playing points to the track-request path.
  - Candidates: track index/mapping for the cue; handling of **short / one-shot**
    cues vs looping BGM; or the cue not being requested. **Likely shares a root
    cause with F.**
  - **Next:** log the MD+ track-request commands at stage-clear vs expected.

### F. "Punk TV screen" music doesn't play (#7)
- **Symptom:** When the bad guys are watching TV, a Japanese girl is normally
  singing — it never plays.
- **Status:** Open.
- **Leads:** Same shape as E — a specific one-shot BGM cue not triggered/played.
  Probably the same root cause (short/one-shot CDDA cues or a track-request gap).
  Investigate together with E.

---

## Recently fixed (for context)

- **Subway / train graphics corruption (#6)** — corrected the `0x81` LZ
  decompressor in the MCU firmware (GPGX/FBNeo routine vs the broken MAME one).
  Subway and a couple of other areas now render correctly. *(2026-06-22; pending
  issue close)*
- **CDDA played ~8% slow (part of #7's "sound issues")** — WAVs are 48 kHz; CDDA
  now consumes at 48 kHz for Paprium. *(2026-06-22)*
- **Battery save (4 KB SRAM)** — persists; also stops the fake-8-bit intro
  replaying. *(2026-06-21)*
- **CDDA too quiet vs SFX** — +10 dB Paprium-only boost. *(2026-06-21)*
- **Boot / graphics / CDDA / full cart SFX / SVP retained** — initial working
  port. *(2026-06-21)*
