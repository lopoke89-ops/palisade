# THE UNDERSTRIP · M5 (release) report: v0.12.0, November 4, 2026

The brief: [`dev/plans/understrip-work-order.md`](../../plans/understrip-work-order.md), milestone M5 (version bump,
STATUS.md entry, evidence, build). **Built, not released.** The release build is on branch `claude/nifty-lamport-jdl74i`,
made from `main` at v0.11.1 (`f13c745`), which hasn't moved since. **Merging it to `main` publishes the site (GitHub
Pages serves `main`'s `index.html`) and waits for Big U's go.** So does the server migration; see
[`dev/supabase/PENDING_DEPLOY_v012_understrip.md`](../../supabase/PENDING_DEPLOY_v012_understrip.md).

## The release
- **Version v0.12.0**, protocol **`yard-31`** (the menu's footer; STATUS.md has the entry).
- **The build:** `python3 dev/build.py` with terser, as every release: `index.html` 1,120,969 bytes minified (v0.11.1 was
  940,838; the mode, its levels' room kits and the case's art), service worker cache `palisade-<build hash>`. Both are
  committed on the branch in their own "Site build" commit, the way earlier releases were.
- **Everything in it**, milestone by milestone:
  - [M0](../2026-11-04-understrip-m0/README.md): the paper.
  - [M1](../2026-11-04-understrip-m1/README.md): region 1 and the Pit Boss.
  - [M2](../2026-11-04-understrip-m2/README.md): weapons and loot.
  - [M3](../2026-11-04-understrip-m3/README.md): regions 2-3, three bosses, the merchants, the case, the server work.
  - [M4](../2026-11-04-understrip-m4/README.md): help, accessibility, balance and budgets.
- **Changed for the release:** the PLAY page's copy still described M1's run ("two levels, then the Pit Boss"). It now
  describes the whole descent (map row, the selected-mode card, the map's line).

## What goes live with the merge, and what doesn't
| | With the merge alone | Needs the migration too |
|---|---|---|
| THE UNDERSTRIP, solo and online, all ten levels | yes | |
| The case's items, rewards and openings **without an account** | yes (the device's own locker) | |
| Rewards for **signed-in** players | held in their claim queue until the server knows the mode | yes |
| Opening UNDERSTRIP CASES on an account | (accounts can't have any yet) | yes |
| Friend invitations to an UNDERSTRIP room (`room_register`) | refused by the server, as an unknown mode | yes |
| The `import_local_save` security fix | | yes (and it changes the live game at once; the deploy note has the options) |

The desktop game (Godot) has no UNDERSTRIP yet (work order 15: the port sweep comes after). A `yard-30` copy keeps
playing every other mode with a `yard-31` host and is refused only by an UNDERSTRIP room.

## Tests on the release build
**The full suite on the minified release build: 117 of 120 passed** (17.8 min). The three that didn't are
`casino_relay_tables`, `casino_relay_games` and `casino_relay_rooms`, which fail in under a second on untouched `main` too
(as in M1-M4). All eleven `understrip_*` tests pass, including `understrip_squad` (four players, the whole descent), and so
do `blackout_perf`, `fps_mode`, `csp` (the release page's content security policy) and `index_page`.

From M4, on the same code: ten four-player runs of the whole descent, 10 of 10.

## Bench numbers (from M4, the same code paths; this machine, software drawing, a phone-sized page)
| Case | Median frame | p90 | Notes |
|---|---|---|---|
| `stress.js` E: the finale, 4 players, drones out | 19.3 ms | 23.2 ms | 30 FPS on a phone needs 33 ms |
| `stress.js` F: Area 67, 2 players, every raider hunting | 17.3 ms | 32.6 ms | at the edge of 30 FPS at p90 |
| `stress.js` A: Endless 20 against `main` | 11.2 vs 11.4 ms | | unchanged |
| `stress.js` B: 6 players, a boss raid, against `main` | 14.0 vs 12.6 ms | | 7-11% slower in plain runs; faster under the profiler and on the identical frozen frame (8.3 vs 9.6 ms). See M4; **re-check on real hardware before or after the merge** |
| `caseperf.js`: the UNDERSTRIP CASE's reel | 16.7 ms | 16.8 ms (p95) | 60 FPS, like the Supply Case |

## Screens
In [`images/`](images/), from `dev/test/understrip_capture_m5.js`: `play-card` (the PLAY page with THE UNDERSTRIP and the
v0.12.0 footer), `locker-case` (the UNDERSTRIP CASE in the Locker), `case-opened` (an opening landing on one of its items),
`lobby-stripnight` (High Roller in front of The Strip at Night). The gameplay screens are in the M1-M4 folders; the
four-angle catalogue sheets are in [`dev/catalog/cosmetics/`](../../catalog/cosmetics/README.md).

## Left for after the merge
- Big U's go for the merge and, separately, for the migration (and when its import fix goes live).
- After the migration: refresh `schema.sql`, the catalogue snapshot and the full catalogue capture (the deploy note's
  housekeeping list).
- The README's "PUBLISHED RELEASE" line, once it's live.
- The director's fun test (run lengths are estimates: [M4](../2026-11-04-understrip-m4/README.md)) and the stress case B
  re-check on real hardware.
