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

- **The 6-button handshake (per community reference on #4):** the pad has an
  internal counter that advances on every TH (bit 6 / select) transition and
  resets after ~1.5 ms of TH inactivity. XYZ are revealed by toggling TH ~3×
  quickly within one read:
  | Step | TH | data (s a c b r l d u) |
  |---|---|---|
  | 1 | 0/1 | normal 3-button frame |
  | 2 | 0/1 | normal again |
  | 3 | 0 | directionals **0000** (6-btn signature) |
  | 3 | 1 | **C B Mode X Y Z** (the extras) |
  | 4 | 0 | directionals **1111** (confirm) |
  Two failure layers: (1) the game's pad read doesn't walk the full handshake
  (only sees the 3-button frame); (2) the core/config exposes a 3-button pad.

- **Our core is correct (rules out layer 2).** `pad_io.sv` returns exactly the
  protocol frames: JCNT=2/TH=0 → `{Start,A,0000}`, JCNT=3/TH=0 → `{Start,A,1111}`,
  JCNT=3/TH=1 → `{C,B,Mode,X,Y,Z}`. It implements the TH-edge counter and the
  ~1.5 ms reset (`JTMR > 11600*7`), and `status[5]` (OSD "6 Buttons Mode") is the
  enable. Since you've confirmed `status[5]=On` still fails, the core side is OK.

- **So it's layer 1 (the read).** Findings: Paprium's pad read at ROM `0xaae0`
  is a standard **3-button** read (single TH toggle — bails after step 1). Its
  full 6-button read isn't visible in the static ROM (likely MCU-decompressed or
  dynamically addressed). Since 6-button *does* work on real hardware, the most
  likely cause is the replier's **pitfall #2: the read is stalled/interrupted
  past ~1.5 ms, so the core's counter resets mid-sequence and never reaches
  step 3.** On real HW the read halts the Z80 to avoid bus contention; on this
  cycle-accurate core the Paprium MCU and/or interrupt timing may be stretching
  the read past the reset window.

- **Things to check next:**
  - HW controller-port diagnostic: log the TH-toggle sequence Paprium emits and
    the JCNT/state the core reaches — does it ever reach JCNT=3, or reset first?
  - Is the gap between toggles exceeding ~1.5 ms (`JTMR` reset)? If so, the reset
    threshold or the bus timing during Paprium's read is the culprit.
  - Locate Paprium's real (multi-toggle) 6-button read routine.

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
