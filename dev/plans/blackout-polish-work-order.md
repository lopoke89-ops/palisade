# v0.9.7.3 work order: CITY BLACK OUT POLISH

| | |
|---|---|
| **Status** | Plan. Written October 4 from Big U's bug report. **All decisions made by Big U on October 4** (B1, B2, B4 and B5 changed from the proposals). Nothing is built yet |
| **Build** | v0.9.7.3, client only. Protocol stays `yard-27` (presentation only; nothing new goes over the network) |
| **Server** | None |
| **Scope** | Messages in **every mode** (B1, B2). Streetlamps and the mini-map in City Black Out |
| **Risk** | Low. Every change is layout, timing or lighting values, each behind `isCity()` / `blackout()` |

## Tickets

| ID | Title | Severity | Area |
|---|---|---|---|
| PAL-0973-1 | Phase banners too big, off-centre and in the way (every mode) | **High**: blocks the play area during fights | HUD / messages |
| PAL-0973-2 | Streetlamps barely light the city | Medium: hurts readability at night | Rendering / lighting |
| PAL-0973-3 | Mini-map in the wrong corner | Medium: layout | HUD / mini-map |

---

## PAL-0973-1: Phase banners too big and in the way

**Reported (Big U):** the pop-ups are too big in City Black Out. Keep the style, move them out of the way toward the top, and make them fade 1.5 seconds sooner. Follow-up: do it in **every mode**, bring the times **closer to the original** (3 s before v0.9.7.1), and **centre the text**, which reads off-centre.

**Repro:**
1. Start City Black Out, any size, solo or co-op.
2. Let the gathering end. "POI UNDER ATTACK · …" appears.

- **Actual:** the banner sits in the middle of the screen (`#toast`, `top: 36%`) and stays 6 s.
  - Desktop 1366×820: 672×139 px at y 295–434, right over the fight.
  - Phone portrait 390×844: full width, 158 px tall, at y 304–462.
  - Phone landscape 844×390: 672×137 px at y 140–277, a third of the screen.
- **Expected:** the same banner style (dark panel, coloured top and bottom band, title plus detail line), smaller, at the top of the screen, gone 1.5 s sooner.

**Root cause:** v0.9.7.1 made phase messages bigger and longer for readability, in every mode. The positioning is one rule for all modes (`style.css`, `#toast` / `#toast.phase`), and the times are fixed in `toastShow()` (`11-hud-chat.js`: phase 6 s, minor 3.5 s). In Black Out, messages arrive back to back (attack, held, next target), so a big banner in the centre is on screen most of the run.

**Fix spec (every mode, B1):**
- **Smaller banner, same style:**
  - title from `clamp(28px, 8vw, 46px)` to `clamp(18px, 4.6vw, 28px)`;
  - detail line 13 px (14 px on desktop), up to two lines;
  - padding 8 / 12 px;
  - the coloured bands stay at 3 px.
  - Target height: no more than about 90 px on desktop and 100 px on phones.
- **Top placement, measured from the live HUD each frame (as the mini-map already is), never a fixed pixel row:**
  - **Desktop:** top of the screen (12 px + safe area), centred in the gap between the vitals (right edge 324) and the phase box (left edge 1164), at most 640 px wide.
  - **Phone landscape:** top of the screen, from the left gutter to the mini-map's left edge minus 8 px (see PAL-0973-3); the vitals sit bottom-left there, so the top-left is free.
  - **Phone portrait:** the top row is full (vitals left, phase box right, y 12–135), so the banner goes **right under the top HUD**, full width, below the tip box if one is showing. See B3 for how it shares space with the mini-map.
- **Centred text:**
  - the title and the detail line are centred on the panel's own centre, not the screen's or the gap's;
  - the panel's box is the measured gap, with no stray side padding from the old `left: 16px / right: 16px` rule;
  - check: the text's centre is within 2 px of the panel's centre at all three sizes.
- **Boss bars stay where they are** (B4). The banner gets out of their way:
  - **desktop:** no clash, since the banner is in the top row and the bars are under the HUD;
  - **phone portrait:** the bars sit right under the top HUD, so while any are drawn the banner goes just below them;
  - **phone landscape:** the bars are a strip across the top, so the banner goes just below the strip.
  - The banner reads the bars' height from `drawBossBars`' own layout (one, two, three to four, or the combined bar) each frame.
- **Times (every mode, B2), back toward the original 3 s:**
  - **phase messages 6 → 4.5 s, minor 3.5 → 3 s** (the pre-v0.9.7.1 time);
  - Settings → Message time still multiplies these (×1.5, ×2);
  - the queue, tap-to-dismiss and the "latest phase message under the phase box" stay as in v0.9.7.1.

**Acceptance criteria:**
- [ ] At 1366×820, 390×844 and 844×390, in Black Out and in a normal raid, a phase banner sits in the top band and overlaps none of: vitals, phase box (pause, timer, READY / START button, phase note), build kit, mini-map (except as B3 allows), joysticks, **boss bars** (with one, two, and four bosses up).
- [ ] Title and detail text are centred on the panel (within 2 px).
- [ ] Banner height is at most 90 px on desktop and 100 px on phones, with a two-line detail.
- [ ] A phase message is gone 4.5 s after it shows, a minor one after 3 s (×1); ×1.5 and ×2 scale them.
- [ ] Back-to-back messages still queue in order; none is lost.

**Tests:**
- Update `toast_queue`:
  - new times (4.5 / 3 s);
  - top placement, height, text centring and no overlaps at the three sizes, in Black Out and in a normal raid, with boss bars up.
- `hud_layout` gains Black Out with a banner up.

---

## PAL-0973-2: Streetlamps barely light the city

**Reported (Big U):** the streetlights don't light up the map as much as he wants. Make them brighter, or light more area.

**Repro:** start City Black Out with the Power Station held, and look along any road at night.
- **Actual:** each lamp cuts a small, faint hole in the darkness. The pools never meet, so the roads read as dark with dots.
- **Expected:** lit roads you can see along, the main difference the Power Station makes.

**Root cause (`06e-city.js`):**
- `cityLights()` stamps each lamp at a radius of **1.9 tiles** and **60%** strength (`hole(…, TW2*1.9, .6)`).
- Lamps stand every **6 tiles** along the sidewalks (`layCity`, `i%6` / `j%6`), so neighbouring pools are about 2 tiles apart.
- The night darkness in the city is `L .70` (`.80` with the power out).

**Fix spec:**
- **Bigger, stronger pools** (B5): radius **1.9 → 3.2 tiles**, strength **0.60 → 0.85**.
- **More lamps** (B5): spacing **6 → 4 tiles** along every sidewalk (about 50 → 75 lamps on the 64×64 city). With 3.2-tile pools 4 tiles apart, the roads read as one continuous lit strip, with brighter spots under each lamp.
- **Warm colour:** a faint sodium-orange glow on each pool (the same additive glow sprite the muzzle flashes use, at about 18% strength), so lamplight reads as streetlight, not just less dark.
- **Lamp heads:** the lit bulb on each lamp post gets a small bright halo, so the source is visible from a distance.
- **Unchanged:**
  - the Power Station rule: lose it and the lamps go dark, and the city's darkness rises to `.80`;
  - Main Command's floodlights and the POI light pools;
- **Cost:** the hole sprites are cached per size and only on-screen lamps are stamped. More lamps means roughly 15–30 lamp stamps a frame instead of 10–20, plus the same number of glow sprites. `blackout_perf` records it.

**Acceptance criteria:**
- [ ] With the Power Station held, a road between two lamps reads as continuously lit: the darkness between pools is no more than half of the unlit night darkness. A pixel test samples the midpoint between two lamps.
- [ ] Power Station lost: no lamp light, no glow (as today).
- [ ] `blackout_perf` desktop and phone averages stay within the v0.9.7 gate (city at most 1.6× Quarry XL).

**Tests:**
- Extend `blackout_map`:
  - lamp spacing (4 tiles) and count, hole radius and strength;
  - a midpoint brightness sample between two lamps, with power held and with power lost.
- `blackout_perf` re-run for the gate.

---

## PAL-0973-3: Mini-map to the top right

**Reported (Big U):** move the mini-map to the top right, under the pause and timer area.

- **Actual (v0.9.7):**
  - desktop: top left, under the vitals;
  - phones: top left, under the tip box (`boMapBox()` in `16f-blackout-hud.js`).
- **Expected:** top right, right under the phase box (pause button and timer).

**Measured layout (live HUD, City Black Out):**

| Size | Phase box (pause + timer) | Build kit starts at | Room under the phase box |
|---|---|---|---|
| Desktop 1366×820 | x 1164–1342, y 12–153 | y 320 | 167 px: the mini-map (170×85) fits |
| Phone portrait 390×844 | x 224–374, y 12–135 (tip box y 145–185) | y 294 | the mini-map (128×64) fits under the tip box |
| Phone landscape 844×390 | x 678–828, y 12–135 | **y 138** (kit is right under it) | **none** |

**Fix spec:**
- **Desktop:** right-aligned with the phase box's right edge, 10 px below its bottom, 170×85.
- **Phone portrait:** right-aligned, 8 px below whichever is lower, the phase box or the tip box. 128×64, which fits above the build kit (y 294).
- **Phone landscape:** no room under the phase box, so the mini-map goes **directly to its left**, top-aligned with it (x about 542–670, y 12–76). That's still the top-right corner, beside the pause and timer.
- **Kill feed:** `#feed` hangs under the phase box today. In Black Out it moves to just below the mini-map, so they never stack on top of each other.
- **Unchanged:** the off-screen attack arrow and everything drawn inside the mini-map.
- **Position math:** like today, positions are read from the live HUD (`getBoundingClientRect`, refreshed with the existing 0.5 s HUD pass), so safe areas, notches and font sizes are covered.

**Acceptance criteria:**
- [ ] At the three sizes, the mini-map sits in the top-right region and overlaps none of: phase box, READY / START button, phase note, build kit, vitals, joysticks, kill feed, the PAL-0973-1 banner (except as B3 allows).
- [ ] When the tip box hides, the portrait mini-map stays put (it doesn't jump up mid-game) (B6).

**Tests:** new `blackout_hud`, covering positions at three sizes with the tip shown and hidden, a banner up, boss bars up, and a kill-feed line. It replaces the mini-map checks spread across `blackout_network` screenshots.

---

## Release plan

1. PAL-0973-3 first (the banner placement depends on where the mini-map is).
2. Then PAL-0973-1.
3. Then PAL-0973-2.
4. Full suite (86 tests plus the new and extended ones).
5. Screenshots at the three sizes, in `dev/evidence/v0.9.7.3/`:
   - a Black Out attack banner;
   - the ready stage;
   - a night road with the power held and with it lost;
   - the mini-map.
6. Big U's OK, then merge.

There is no server work and no protocol change, so guests on v0.9.7.2 can still play with v0.9.7.3 hosts.

## Decisions (all made by Big U, October 4)

| # | Question | Decision |
|---|---|---|
| B1 | Smaller top banner: Black Out only, or every mode? | **Every mode**, same style, with the text centred |
| B2 | 1.5 s shorter: Black Out only, or every mode? | **Every mode**, closer to the original 3 s: phase 4.5 s, minor 3 s |
| B3 | Phone portrait: the banner and the mini-map both want the space under the top HUD | **As proposed:** the banner goes there for its 4.5 s and the mini-map fades out underneath it, then comes back |
| B4 | Boss bars while a banner is up | **They stay where they are**; the banner moves to avoid them (below them on phones) |
| B5 | Streetlamps: bigger pools only, or more lamps too? | **Both:** bigger, brighter pools (3.2 tiles, 85%) plus a warm glow, and lamps every 4 tiles instead of 6 |
| B6 | Portrait mini-map when the tip box hides | **As proposed:** stays where it is for the whole run (no jumping) |
