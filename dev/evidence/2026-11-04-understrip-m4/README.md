# THE UNDERSTRIP · M4 (balance and polish) report, November 4, 2026

The brief: [`dev/plans/understrip-work-order.md`](../../plans/understrip-work-order.md), milestone M4 (sections 4.2, 11 and 12).
Browser only; not released. The server migration is still not applied (see
[`dev/supabase/PENDING_DEPLOY_v012_understrip.md`](../../supabase/PENDING_DEPLOY_v012_understrip.md)). Builds on
[M3](../2026-11-04-understrip-m3/README.md).

## What changed
### Help and accessibility (work order 12)
- **First-time tips:** one line, the first time on this device that each is near you: a Neon Shrine, a merchant, the boss
  gate, your own dropped salvage. A tap or click skips it; it goes by itself after 9 s; the Tips setting turns them off. The
  mode's opening line now goes after 14 s of play. A guest sees them too (the guest's raid branch used to clear every tip
  each frame).
- **Reduce Motion** (the system setting): Shelter 7's tubes and Area 67's failing lab lights hold steady (the failing ones a
  steady 70%), the neon stops flickering, and the mode's shakes (the bosses' stage changes, the doors, the rushes) are a
  third as strong.
- **Dungeon brightness, top step:** its darkness floor goes from 66% to 58%, and every raider on screen is marked above the
  darkness, as telegraphs already are: a ring at its feet and a pointer over its head (shape as well as colour). The
  third step goes from 78% to 76%.
- Telegraphs were already drawn over the darkness and shape-coded (M1-M3); all actions were already on every input; solo
  pauses anywhere (the merchant screen pauses it too); online the game runs on for the others, as in every mode.

### Sound (the mix pass)
- **Area 67's hum:** the work order cuts the music in region 3 so "only ambience plays", and there wasn't any. Now there's a
  low hum (two sines a fifth apart, the upper one drifting, through a 320 Hz low-pass) at 5% of the music volume, only in
  Area 67 and only while no boss track plays. It follows the music slider.
- Unchanged and checked: region 1's 650 Hz muffle, Shelter 7's 420 Hz with the reverb tail, the four boss tracks, footsteps
  through walls, the vents' hiss and the alarms' siren (positional, so far ones are quiet). `music_routing`,
  `casino_music` and `reel_music` pass.

### Balance
| What | Before | Now | Why |
|---|---|---|---|
| Raiders' health by region | the same everywhere | ×1 / ×1.2 / ×1.4 | deeper is harder; the bosses already climb (1,200 / 1,800 / 2,400 / 3,500) |
| Raiders' health by squad | the same for 1-6 players | +12% each extra player | bosses had +35% a player; raiders didn't scale at all |
| Drones | speed 3.4, packs of 3-6 | speed 2.6, half speed in your light, packs of 4-6 | as `tables/enemies.csv` has always said (M3 had drifted from it) |

The new rows are in [`tables/enemies.csv`](../../plans/understrip/tables/enemies.csv) and the spreadsheet is rebuilt
(`build_tables.py` passes; its "case id is taken" check now accepts the case's own entry). The weapons' direct damage
(the table's derived DPS) was reviewed and left as designed: the low figures are the utility guns (the flare launcher's
burn and light, the anti-grav launcher's area lift with +25% damage taken, the taser's stun).

### Run length (work order 4.2: 15-20 minutes a region, 50-60 a run)
An estimate, not a measurement: [`dev/test/understrip_runlength.js`](../../test/understrip_runlength.js) builds 40 runs'
levels with the game's own generator and raider placement and adds the walk, the fights and the bosses at the M4 numbers.
Its stated assumptions (a cautious 2.4 tiles/s, twice the critical path again for branches and backtracking, 80% of
raiders fought, 32 damage a second landed per player, 75 s a level at shrines and merchants, a few squad falls) are for a
competent squad.

| Squad | Region 1 | Region 2 | Region 3 (with the finale) | Run |
|---|---|---|---|---|
| 1 player | 13:09 | 14:29 | 23:54 | 51:32 |
| 2 players | 12:45 | 13:53 | 21:46 | 48:24 |
| 4 players | 12:34 | 13:34 | 20:41 | 46:49 |

A whole run lands at or near the 50-60 minute target. Regions 1 and 2 come out a little under 15 minutes and region 3 a
little over 20, because it carries the finale's fourth level. These are the director's numbers to judge in the fun test.
The knobs are the raider counts per room, the finale (a fourth level, or the Visitor straight after the Gatekeeper) and
D2 (levels per region).

### Performance (work order 11)
Measured with `stress.js` (phone-sized page, software drawing). It now has two UNDERSTRIP cases and a `CASES=` filter:
- **E · the finale, 4 players** (the Visitor's stage 2 in the dark, drones out): **19.3 ms** median frame, 23.2 ms p90;
  update 0.3 ms. That's inside the phone's 30 FPS (33 ms), with 15 enemies alive.
- **F · an Area 67 level, 2 players, every raider hunting, an alarm's drones:** **17.3 ms** median, 32.6 ms p90 (at the
  edge of 30 FPS at p90).
- **The caps:** at most 40 raiders alive (`US.maxAlive`), at most 12 drones; the lighting is the existing single mask pass.
- **The 5% rule** (no existing stress case more than 5% slower): measured against untouched `main` (v0.11.1) on the
  same machine, alternating builds.
  - **A** (Endless raid 20) is unchanged: 11.4 against 11.2 ms median over five runs each.
  - **D** (6 players, Endless 20) is unchanged.
  - **B** (6 players, a boss raid) is slower in the plain runs: 12.6 against 14.0 ms median over nine each (7-11%).
  - On B, the same run under the profiler is the other way round (16.1 on `main` against 15.2), and its scenes differ
    from run to run even on the same build (the stress loop isn't deterministic). So I measured the drawing directly: the
    same frozen B frame rendered 200 times draws **faster** on this build (mean 8.3 against 9.6 ms over five runs each).
  - The code added outside the mode is a few checks per frame (`game.us`, a drone's type, `st.us`), and nothing in the
    character painter's cache key changes for other modes.
  - My read: B's gap is the scenes, not the drawing. It's left open to re-check on real hardware before release.
- **The case's reel** (`caseperf.js`, now with `CASE=`): the UNDERSTRIP CASE holds 60 FPS on the phone-sized page like the
  Supply Case (16.7 ms frames, p95 16.8; about 228 ms of CPU a second against 224-236).

## Found and fixed while testing
- A comment added mid-line cut off the lamp timer's next statement in `10k` (the same trap as M1's): Shelter 7 and Area 67
  threw an error as soon as their lamps were drawn, **unless** Reduce Motion was on (the new early return came first, so
  `understrip_m4` passed). Fixed, and every comment added in M3 and M4 was re-checked by a script that compares each added
  comment against the code that line used to have.
- The first-time tips stopped at the first nearby thing even when its tip was already seen (the Shrine Keeper stands by the
  breather shrine): now the first unseen one that's near shows.

## Tests
**The full suite on the final build: 117 of 120 passed** (18.8 min). The three that didn't are `casino_relay_tables`,
`casino_relay_games` and `casino_relay_rooms`, which fail in under a second on untouched `main` too (as in M1-M3). Every
`understrip_*` test passes, and `blackout_perf` and `fps_mode` pass.

**Ten four-player runs** (work order 13: no crash or desync in 10): `understrip_squad` ten times in a row on the final
build, a host and three guests down all ten levels each time. **10 of 10 passed** (137-147 s each): the same level on all
four phones on every level, each boss's gate, stage and doors on every guest, four bosses down, the lives, OUT OF AREA 67
on every phone, and no page errors.

New test (tag `understrip`): `understrip_m4`, with the system's Reduce Motion on.
- **Tips:** each of the four first-time tips shows once, goes by itself within 9 s, can be skipped with a tap, and is
  remembered. With the Tips setting off, none show.
- **Reduce Motion:** Shelter 7's tubes hold at full and Area 67's failing lights at 70%, and a shake is a third as strong.
- **Brightness:** only the top step marks raiders.
- **Raiders' health:** ×1, ×1.2 and ×1.4 by region, and +12% for a second player.
- **Drones:** half speed in your light.
- **The hum:** Area 67 has it; Shelter 7 doesn't (it has its music).

Tools added (not in the suite): `understrip_runlength.js` (the estimate above), `understrip_capture_m4.js` (the screens),
two `stress.js` cases and its `CASES=` filter, and `caseperf.js`'s `CASE=` setting.

## Screens
In [`images/`](images/), from `dev/test/understrip_capture_m4.js`: `tip-shrine` (a first-time tip), `brightness-1-of-4` and
`brightness-4-of-4` (the same dark Shelter 7 room: on the top step every raider is marked).

## Not in M4
The release (M5): version bump, STATUS.md entry, the build, merging to `main`, which waits for the director's go, as does
the server migration.
