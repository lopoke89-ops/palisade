# v0.9.6.3 efficiency: before/after (October 3, 2026)

Same machine and scripts for both builds: `main` at `0756beb` (v0.9.6.2 plus two fixes) served on :8081, the v0.9.6.3 candidate on :8080. Desktop Chromium with software canvas, so drawing costs are exaggerated compared with a phone GPU; byte and request counts are exact.

## State packets (host → each guest, 15 per second)

Six players (five bots), seeded scenes, 60 packets each, two runs per build; the packet counter advances as on a real host.

| Scene | main | v0.9.6.3 | Change |
|---|---|---|---|
| Endless raid 20, Yard 16×16, ~40 raiders | ~2,180 B | ~1,965 B | about −10% |
| Final Blitz, Yard, ~23 raiders | ~1,915 B | ~1,725 B | about −10% |
| Endless raid 20, Frostpeak XL, ~50 raiders | ~3,040 B | ~2,315 B | about −24% (−19% per raider) |

At 15 packets a second a host with five guests sends roughly 140-160 KB/s in these scenes instead of 160-230 KB/s. Raider rows are now 40-65% of a packet; binary packets or sending only moved raiders would be the next step if hosts on mobile data still struggle. `netbench.js` (host + one guest, ~11 raiders): state 8.6 → 7.9 KB/s.

## Page work per second

| Screen | Style passes/s, main → v0.9.6.3 | Per-frame DOM changes |
|---|---|---|
| Phone, PLAY / Locker | 117 → 60 | 7 → 0 |
| Settings (desktop and phone) | 60 → 0 | 7 → 0 |
| In a game, standing still | 60 → 1 | 5-6 → 0 |

Style time: PLAY 6.4 → 4.4 ms/s, Locker 17.7 → 14.9 ms/s (desktop CPU; a phone is several times slower). The remaining 60/s on PLAY and the Locker is the stage character's CSS bob animation. Total CPU on these idle screens is unchanged within noise here; the desktop Auto cap only shows on monitors faster than 60 Hz (the test browser runs at 60).

## Server requests

`poll_backoff.js` checks the rules: friends every 15 s while the menus are in use, never in a hidden tab, once a minute in a match or after 5 idle minutes (15 s with the Friends panel open), one immediate check on returning to the tab; no Open Games refresh in a hidden tab. A signed-in player who leaves the game open in a background tab now makes no friends requests instead of 240-480 an hour.

## Rejected after measuring

Culling off-screen walls and raiders before the depth sort skipped 36-57% of tiles with no measurable frame-time change (the canvas already discards off-screen drawing cheaply).

## Test suite

Full list (64): 55 pass. The 9 failures (`accounts`, `v087`, `lobby`, `v090`, `milestones`, `ultimate_cloud`, `cosmetics_expansion`, `cosmetics_migration`, `boss_milestones`) fail identically on unmodified `main`; they predate this change (expectations not updated for v0.9.5.1-v0.9.6.2: a fourth map, 15 ladders, Sahur hats, `butcher_oct`, winter looks).
