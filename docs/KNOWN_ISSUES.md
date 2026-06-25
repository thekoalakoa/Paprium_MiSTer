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
- **Status:** Fix HW-tested — improved (2026-06-22). Anti-starvation build runs;
  user reports noticeably fewer/no animation skips in dense scenes. Keeping
  `STARVE2_LIMIT=24`; can lower further if any residual skipping is seen.
- **Confirmed ours-specific:** user reports the real EverDrive Pro / cart does
  **not** skip like this at the same enemy density. So it is not the inherent
  Mega Drive VRAM-DMA ceiling — it's our port.
- **Findings:**
  - **MCU clock ruled out.** mega-ppm clocks the NEORV32 at **50 MHz**
    (`top.sv`); our port runs it at **53.69 MHz** (`clk_sys`) — ~7% *faster*.
  - **Mechanism = per-frame VRAM DMA budget.** Each frame the 68000 does
    `cmd_AE_frame_start` → many `cmd_AD_obj_add` → `cmd_AF_frame_end`, with
    `cmd_EC_vram_budget` setting the budget. `ppm_obj_frame_end()` (`mame.c`):
    `dma_remaining = dma_budget - dma_total`, renders the draw list, and a **VRAM
    slot cache** (`usage`/`age`) means only *changed* animations cost DMA. If the
    MCU can't compose/emit a fresh tile in time, the object keeps its old VRAM
    tile → **slide / missing hit & grab**.
  - **ROOT CAUSE = shared-SDRAM port starvation.** mega-ppm gives the MCU a
    *dedicated* SDRAM; we share one chip via `sdram.sv` with **strict fixed
    priority refresh → port0 → port1 → port2**:
    - port0 (`addr0`) = ROM download — idle during play
    - port1 (`addr1`) = console 68000/VDP/Z80 + the **stream-window tile reads**
    - port2 (`addr2`) = **Paprium MCU — lowest priority**
    Port1 *always* beats port2. Dense scenes = heavy port1 stream traffic, so the
    MCU starves. Worse, `paprium_mcu_mem.sv` issues **two 16-bit port2 round-trips
    per 32-bit MCU access**, doubling the requests that lose every tie. The MCU
    falls behind on reading anim data / writing composed tiles → effective budget
    below real hardware → skipping that scales with enemy count.
- **Proposed fix (low-risk, surgical):** add an **anti-starvation bump** in
  `sdram.sv` — if `req2` stays pending while port1 keeps winning for more than N
  arbitration rounds, let port2 win one access. Bounds the MCU's worst-case SDRAM
  latency; the console only loses an occasional slot (and port0 is idle anyway).
  Only triggers when port2 is genuinely starved, so it's safe for non-Paprium
  cores (port2 = SVP then; may even help Virtua Racing). Needs a build + on-HW
  test in a dense fight.
- **May share a root cause with the subway stall (B).**

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
- **Status:** Open — the sprite-attribute fix had NO observable effect on HW.
- **HW result (2026-06-25):** the field-wise priority/palette composition below
  was built and tested — the elevator is still glitchy in the same way, at the
  same point in the level. So the elevator sprites apparently do NOT set both the
  tile and object priority/palette bits (the hypothesis was wrong). The change
  did no damage to other scenes, so it's kept in V.04 but is **not** an elevator
  fix and isn't claimed in the release notes. Next lead: the muted `0xB0`
  `paprium_sprite_init` / `0x88` setup commands, or a different decode path.
- **Confirmed:** also broken on EverDrive Pro → firmware, not core/VDP.
- **Not decompression.** Verified our `0x80`/`0x81` decoders match GPGX exactly.
- **Lead — XOR vs tile-precedence in the sprite attribute.** GPGX
  (`paprium_sprite`, lines 1287-1289) builds each sprite's attribute field-wise:
  `priority = tileP ? tileP : objP` (tile wins), `palette = tilePal ? tilePal :
  objPal` (tile wins), `flip = tileFlip ^ objFlip`. Ours (`ppm_obj_render`,
  `mame.c:544`) XORs the whole word:
  `attrs = ((spr_data->attrs & 0xf8) << 8) ^ intf_obj->attrs ^ (vram_block+ofs)`.
  These agree only while the object's priority/palette bits are 0 (most scenes).
  When both the tile and the object set priority, XOR → 0 (sprite drops behind
  the BG); when both set palette, XOR scrambles it (wrong colours). Matches the
  elevator's "background priority + corruption" and its scene-specificity.
- **Fix (firmware, moderate risk):** split `mame.c:544` to compose priority and
  palette with tile-precedence and keep flip + tile-index as XOR/add, per GPGX.
  Needs HW regression test on normal scenes (the all-XOR works everywhere else,
  so confirm no other scene relied on it). Orthogonal to audio, so it can ride in
  the same firmware build as the music fix and be judged independently (sprite
  regressions vs audio).
- **Also muted in our firmware but real in GPGX (lower priority leads):** `0xB0`
  `paprium_sprite_init`, `0x88` `paprium_audio_setting`. Check if the elevator
  setup uses `0xB0` if the attribute fix isn't sufficient.

### D. 6-button controller support missing (#4)
- **Symptom:** X/Y/Z/Mode not recognised; OSD "6 Buttons Mode" and the mapped
  Mode button do nothing. 3-button works (game playable).
- **Status:** WORKAROUND SHIPPED in V.04 (combo injection — HW-verified working).
- **HW result (2026-06-25):** the combo injection works on hardware — X/Y/Z now
  do their mapped moves. Mapping may need tuning (Z=A+B tentative). Confirmed
  **Super Street Fighter II in 6-button mode is unaffected** (the `~MODE` gate
  works). See the workaround note below. The real handshake is still unsolved
  (kept as a future lead).

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

- **Workaround being tested — combo injection (`pad_io.sv`).** Rather than fix the
  handshake, map X/Y/Z to the equivalent *simultaneous* 3-button combos the game
  already reads, injected into the 3-button frames. User-chosen mapping:
  `Y = Down+B`, `X = B+C`, `Z = A+B` (Z tentative). Gated on `~MODE` so real
  6-button games (run with MODE on) are byte-for-byte unaffected; Up is masked
  while Down is injected. **Only works for simultaneous combos — motion inputs
  (e.g. forward-forward-B dash) are out of scope.** To use it, set OSD
  "6 Buttons Mode" **OFF**. If good, follow up with a dedicated OSD toggle +
  `paprium_active` gating instead of reusing `~MODE`.

### E. "12 Stage Clear" jingle doesn't play (#9)  + F. "Punk TV" song (#7)
- **Symptom:** Specific one-shot music cues never play — the stage-clear jingle
  (`12 Stage Clear.wav`) on the score screen, and the punk-TV song. General level
  BGM is fine.
- **Status:** FIXED in V.04 — cues now play (HW-verified). Minor caveat below.
- **HW result (2026-06-25):** Stage Clear and Continue (and the other one-shots)
  now play — the silence is fixed. **Caveat:** they currently *loop* instead of
  playing once. We use `mdp_play_once` (`MDP_CMD_PLAY_S`, loop=0), so the CDDA
  playback path isn't honouring the no-loop flag at end-of-track — a cosmetic
  follow-up (`mdp_audio` / `md_plus` track-end handling). Shipped as-is.
- **Confirmed:** also silent on the real EverDrive Pro (same firmware gap).
- **Earlier 0x95/0x96 theory was WRONG.** The Genesis Plus GX LittleManProject
  source (`core/cart_hw/paprium.h`) shows 0x95/0x96 are **no-ops there too**, and
  0xD6 (`paprium_music_special`) is debug-only. They are not the cue path.
- **Actual root cause — `cmd_8C` stops one-shot cues.** All music, including the
  one-shots, goes through `0x8C`. GPGX's handler (`paprium_music`) **always plays**
  `track & 0x7F`. Ours (`cmd_8C_bgm_play`) instead does
  `if (arg & 0x80) mdp_play(arg & 0x7f); else mdp_stop();` — so any cue sent with
  **bit 7 clear is STOPPED instead of played.** The one-shot cues (Stage Clear,
  Continue, Game Over, High Score, Ending, punk-TV) are sent bit-7-clear → killed.
  Normal looping BGM is sent bit-7-set → plays → that's why general music works.
- **Mapping is already correct.** GPGX maps each game music index → a named track;
  our `paprium.cue` is built in that exact game-index order (CD track N = game
  index N, `Blank.wav` filling gaps). Verified: "12 Stage Clear.wav" = TRACK 53 =
  index 0x35, so `mdp_play(0x35)` already resolves to the right file. No remap
  needed.
- **Fix (firmware only, low-risk):** in `cmd_8C_bgm_play`, don't stop on
  bit-7-clear. `track = arg & 0x7f; if (track==0) mdp_stop(); else if (arg & 0x80)
  mdp_play(track) /*loop, PLAY_L*/ else mdp_play_once(track) /*one-shot, PLAY_S*/`.
  Add `mdp_play_once()` issuing `MDP_CMD_PLAY_S (0x1100)`; the adapter already
  decodes 0x11 (`paprium_mdp_adapter.sv` → loop=0). Only changes the bit-7-clear
  case, which was already broken — no regression to working looping BGM.

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
