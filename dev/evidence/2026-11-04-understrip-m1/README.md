# THE UNDERSTRIP · M1 (the region 1 vertical slice) report, November 4, 2026

The brief: [`dev/plans/understrip-work-order.md`](../../plans/understrip-work-order.md), milestone M1. Browser build only (`dev/src`).
Not released: `main` and the published site are unchanged (v0.11.1). The director's fun test is next.

## What's playable
PLAY › LENGTH › **UNDERSTRIP**, solo or hosted online (co-op, up to six). Region 1, The Flood Tunnels:

- **Three levels from the run's seed.** Two tunnel levels, then the count room. Each is built from the region 1 room kit
  (`dev/data/understrip/rooms-r1.json`, 18 pieces) by the generator (`06g-understrip.js`, spec
  [`understrip-generator.md`](../../plans/understrip-generator.md)): a critical path of 8-12 pieces, 30-40% of pieces on
  branches, a breather with a Neon Shrine, at least one merchant, caches, and a shortcut door that opens from its far side only.
- **No stake, no build phase, no gathering, no Delgado, and no healing out of a fight** (D9).
- **Lucky Juice:** 3 charges, 0.8 s to drink (walking at 40%), heals 45% when the drink ends. C drinks (the controller's
  build-kit button; the DRINK button on touch).
- **Neon Shrines:** E rests: Lucky Juice refilled, everyone back up (the bled-out too), and the squad's comeback point. The
  level's raiders come back. You can't rest with raiders hunting within 8 tiles.
- **Falling:** a downed player can be got up by a teammate; left 20 s, they bleed out until the next rest or level. When the
  whole squad is down, a shared life goes (3 to start) and everyone comes back at the last shrine (or the lift) with their
  juice refilled, and the raiders and the boss reset. With no lives left the run ends. Salvage you carried stays where you
  fell: walk over it to take it back; fall again first and it's gone.
- **The lift:** everyone standing in the green ring for 3 s goes down; downed players come along at 25%.
- **Raiders in the dark:** they wait where the seed put them (some in ambush in dark side rooms) until they see you, hear you
  close by, hear a shot within 8 tiles, or are hit; then they alert the ones near them and hunt the nearest of you along that
  player's own path field. Badly hurt ones fall back to the group for 4 s. Hunters' footsteps are heard through walls.
  Region looks for the raiders come in M3.
- **Flash floods:** the low ground (Riverbend's rules) floods for 18 s every 75-115 s, with a 5 s warning.
- **The Tunnel Trader** (E beside him): the armory's upgrades, and his stock from the seed (grenades, Spare Juice, barricades,
  road flares) with what's left. SPACE places a barricade (120 HP) or throws a flare (lights 4 tiles for 15 s); F switches.
- **Chests** in caches pay 15-30 salvage, sometimes an item.
- **The Pit Boss** (count room): the gate seals 4 s after the first of you steps through (the rest are pulled in). Moves as the
  [boss move sheet](../../plans/understrip/boss-move-sheets.md): chip tosses (landing rings), the cash-box swing (wedge), calls
  for security at 75% and 25%; at half health 3 s with no damage, the floor floods, and stage 2 adds the card spray (cone) and
  the floor rush (lane, then dazed 1 s). The bar shows each stage's own health, with two stage pips. Down: the gate opens, the
  arena's shrine and the lift wake. 1,200 health for one player on Normal (+35% per extra player).
- **The look:** tunnel walls stand only where they face the floor, and draw low in front of you; darkness with a light cone
  where you aim, lamps, neon, shrines, flares and muzzle flashes; 15% closer in; no edge arrows to raiders still waiting.
  Settings › DUNGEON BRIGHTNESS raises the darkness floor (4 steps).
- **The sound:** the casino's playlist, low-passed (650 Hz) as if heard through concrete; the boss fight gets a raid track.
- **The end:** OUT OF THE COUNT ROOM, or THE TUNNELS KEPT YOU, with depth, kills, falls, rests, time and lives. No rewards yet
  (the case and shards are M3), and the mode saves no run drafts.

## Decisions taken while building (calls the director may want to change)
| What | Call |
|---|---|
| Resting brings back players who bled out | Yes, at the shrine (so a co-op squad isn't waiting out a whole level) |
| Ammo | The class gun keeps infinite ammo; consumables are the stock (the second weapon's reserve is M2) |
| The Pit Boss's look | Built on the shared figure (dark suit, red tie, the Butcher's blade swing); his own model is M3 art |
| Teammates holding a dropped salvage pile | Not needed yet: piles don't time out, they only go if the owner falls again |
| The Tunnel Trader's figure | The shared figure in a cashier's purple; art in M3 |
| Online compatibility | The rooms' protocol is `yard-31`. A `yard-30` copy (an old tab, or the desktop game) is refused only by an UNDERSTRIP room; it still plays every other mode with a `yard-31` host, and guests announce both versions so older hosts still take them. The casino relay is still told `yard-30`, so it needs no redeploy |

## Files
- New: `06g-understrip.js` (generator), `10h-understrip.js` (the mode), `10i-understrip-bosses.js` (the Pit Boss),
  `15b-understrip-look.js` (the tunnels' look); `dev/data/understrip/rooms-r1.json`.
- Hooks in: maps, newGame and the shop rules, update, downs, the dead-end check, raider targeting and the light level, input
  (keys, controller, touch), the HUD and key bars, prompts, the armory screen, the end screen, music, the boss telegraphs and
  bars, the zoom, settings, the PLAY card and setup sheet, and the network (start message, snapshot, player bits, guest
  requests). The Pit Boss is kept out of Black Out's random boss pool.
- `build.py` inlines the room kits.

## Tests
**The full suite on this build: 108 of 113 passed** (15.2 min). The five that didn't:
- `casino_relay_tables`, `casino_relay_games`, `casino_relay_rooms`: fail in under a second on untouched `main` too (the same
  run on `main` before any of this: 105 of 109, these three and `v087`). Not this work.
- `v0965_bosses`: counted 16 boss weaknesses, expected 15 (the Pit Boss's is new). The test's count is updated and it passes.
- `blackout_run`: failed once in the parallel batch (a POI's quiet-time repair) and passes on its own, run again after the
  last build (it passed on `main` too; its numbers don't touch anything changed here).

Run again on the last build, on their own: `blackout_run`, `v0965_bosses`, `index_page`, `back_roll`, `lobby`, `menu_audit`,
`understrip_run`, `understrip_network`: all pass.

The new tests (tag `understrip`):
- `understrip_roomkit` (node): the room kit's edges, doorways, connectivity, corridor widths, markers and shortcut doors.
- `understrip_gen` (node): 3,000 seeds of each level kind built and checked at tile level (deterministic; everything
  reachable; the exit without the shortcut; the shortcut saves the walk from the start; the boss only through the gate;
  8-12 path pieces; 30-40% on branches; a merchant). Mean 3.1 attempts a normal level, 9.3 a boss level; 3.5 ms a level.
- `understrip_run`: the whole solo run as listed above, start to both endings.
- `understrip_network`: two phones. The same level from the same seed on all three levels (tiles, layout, merchant stock);
  the guest's drink, rest, shortcut and trade go through the host; bleeding out and the dropped salvage; the squad's fall;
  the lift; the gate, the boss's second stage and his fall; an older copy refused only by an UNDERSTRIP room.

Existing tests changed: `blackout_network`, `campaign_network`, `casino_map`, `back_roll` expect `yard-31`; `index_page` 16
boss cards and `v0965_bosses` 16 weaknesses (the Pit Boss is on the Index now, weak to explosive ammo); `v090` leaves the
tunnels out of its every-map checks (as it leaves out the casino).

Found and fixed while testing: a note left mid-line in `02-view.js` cut off the tile-size line (every mode drew at the
default size; `zoom_setting` caught it), and one in `17-scenery.js` put edge arrows on every raider; both lines are fixed
and every other note added in this work was checked to end its line.

## Screens
In [`images/`](images/), from `dev/test/understrip_capture.js` (a seeded solo run, 1280×800 at 2x, and an iPhone 13):
`tunnels`, `shrine`, `trader`, `lift`, `boss-stage1` (the swing's wedge and a chip's landing ring), `boss-stage2-rush` (the
lane, the second bar), `boss-stage2-spray` (the cone), `results`, `play-card`, `phone-portrait`; and `level-normal-7`,
`level-boss-7`, `level-normal-42`, `level-boss-42` (generated levels drawn top-down by `dev/plans/understrip/draw_levels.py`).

## How to play this build
It isn't on the website (that's `main`). From a checkout of this branch:

```bash
python3 dev/build.py
```

```bash
python3 -m http.server 8000
```

Then open http://localhost:8000/ and pick PLAY › LENGTH › UNDERSTRIP. Online co-op works between two browsers on the same
build.

## Not in M1 (by the work order's milestones)
Second weapons, perks, relics, elites and chests' loot tables (M2); regions 2-3, the other bosses, the other merchants, the
case, the cosmetics and rewards (M3); the balance pass, the performance budget, first-time tips and the audio mix (M4).
