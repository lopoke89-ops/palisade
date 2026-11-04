# THE UNDERSTRIP: the level generator (spec)

**Status:** finished in M1, and matches `dev/src/js/06g-understrip.js` (drafted at M0; the steps below are what the code does). The browser and the Godot port must build the same level from the same seed, so everything below is exact. `dev/test/understrip_gen.js` checks 3,000 seeds of each level kind and writes `out/understrip_gen_fixture.json` (seed → tile hash) for the port.

## Inputs and output
- **In:** a 32-bit `seed`, the region (1–3), the level's place in the region (`1`, `2`, or `boss`), and that region's room kit (`dev/data/understrip/rooms-r<region>.json`, checked by `dev/test/understrip_roomkit.js`).
- **Out:** an ordinary map the engine already understands. `terr` is filled from the pieces' tiles through the kit's legend, and the layout (`game.lay`) lists the markers: player starts, the exit, shrines, merchants, chests, ambush spots, lamps, the boss spawn. Raider spawning, pathing (flow fields), lighting and the network then work as they do for any map.

## The random numbers
- **One generator, nothing else:** `mulberry32`, in 32-bit integer arithmetic.
  - It is written out below because both versions must match bit for bit.
  - It never calls `Math.random()` or `rnd()`, so rerunning the generator for a guest never disturbs the game's own random stream.

  ```js
  function mulberry32(a){return function(){a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296}}
  ```

- **Seeds:**
  - The run seed comes from the host (a random 32-bit number at the start of a run; the start message carries it). Level `n` (0, 1, 2)
    of region `r` uses `usHash(runSeed, r, n+1)`, so a level can be rebuilt on its own (a rejoin, a desync check).
  - The level's raiders, each merchant's stock and each chest get their own sub-seed: `usHash(levelSeed, 77)` for the raiders,
    `usHash(levelSeed, 500+m)` for merchant `m`, `usHash(levelSeed, 900+c)` for chest `c`. Buying from one merchant never changes
    what the next one rolls.

  ```js
  function usHash(...v){let h=0x9E3779B9|0;for(const x of v){h=Math.imul(h^(x|0),0x85EBCA6B);h^=h>>>13;h=Math.imul(h,0xC2B2AE35);h^=h>>>16}return h>>>0}
  ```
  - A level's fingerprint (`usTileHash`) is FNV-1a over the tile rows' character codes.
- **Picks:**
  - A weighted pick sums the weights in kit order and walks them.
  - Ties and iteration order always follow the kit's array order, never object-key order.

## The grid
- A level is a square of **cells, 8 × 8 tiles each**: 7 × 7 cells (56 tiles) for normal levels, 8 × 8 (64 tiles) for a boss level. This keeps every level within the 48–64 limit (section 5.2).
- A piece covers `size` cells.
- Doorways sit in pairs at tiles 3–4 of a cell edge, so any two pieces placed side by side either share a doorway or meet wall to wall.
- Cells left empty are solid rock.

## Steps
The numbers live in `US_LEVEL` (`grid`, `path` 8-12, `branch` 30-40%, `tries` 1,500, `restarts` 120). An attempt that fails restarts with
`seed+1`, then `seed+2`, and so on; that restart is part of the spec. Over 3,000 seeds a normal level takes 3.1 attempts on average (at
most 23) and a boss level 9.3 (at most 62); about 3.5 ms a level.

1. **The first piece.**
   - Normal levels start from the entrance; boss levels from the arena and grow backwards (arena, antechamber, path, entrance), so the
     3×3 arena always has room.
   - It goes on a random cell where the cell outside its first doorway, and the one beyond it, are in the grid.
2. **The critical path** (8-12 pieces, the length picked first):
   - Each step tries the pieces that fit an open doorway of the last piece (free cells, a matching doorway, within each piece's `max`),
     weighted by `weight`, in every allowed turn and mirror. A piece needs a second doorway unless it's the last.
   - The first two steps after the entrance are corridors or junctions.
   - The breather goes 40-70% along (never next to the start or the end).
   - The end: the exit (normal levels), or the antechamber then the arena (boss levels; the arena joins only the antechamber's gate,
     and the gate only the arena).
   - A dead end steps back one piece and tries its next option.
3. **The shortcut:**
   - A breadth-first search over free cells from the cell outside a *late* path piece (the last third, after the breather by 2 or more;
     not the exit, antechamber or arena) to the cell outside an *early* one (after the start, at or before the breather).
   - The ways out of a piece are its spare doorways, or, for a one-cell corridor, junction or room, a swap to another one-cell piece
     that has the doorways it already uses plus the new one (a straight corridor becomes a T, say). Links keep pointing at the same sides.
   - A route is kept only if it saves at least two pieces on the walk from the level's start to the late piece (along the path:
     the late piece's place; through the shortcut: the early piece's place + the route + 2). Up to 5 cells (6 on boss levels).
   - The route is filled with one-cell pieces whose doorways cover the sides it needs; the shortcut piece goes on a straight cell,
     turned so it opens from the late side. If nothing fits, the next late doorway is tried; a level without a shortcut is never kept.
4. **Branches** (30-40% of all pieces, the count picked first):
   - First the merchant: straight off the path, or one corridor out.
   - Then branches of 1-3 pieces from spare doorways (or swaps, as above) of path and branch pieces, ending in a cache (75%) or a
     second merchant (25%); a branch that can't place its end piece ends in a corridor or room.
5. **Seal** every doorway that wasn't joined (its two tiles become wall). Two pieces side by side join only where the growth joined
   them, so there are no loops past the shortcut or round the boss gate.
6. **Lay** the tiles and collect the markers. The checks in `understrip_gen` (every level): everything reachable with the shortcut
   open; the exit reachable with it shut; the shortcut shortens the walk from the start; the boss reached only through the gate; the
   path and branch shares; one merchant at least; the map's edge is wall.

## What's chosen from the seed (so the host and every guest agree)
- The layout.
- Which ambush spots hold a raider (75%), and the raiders in each room (`usPopulate` in `10h-understrip.js`, its own sub-seed).
- The elite in each room cluster (M2).
- Chest contents (salvage, and sometimes an item).
- Merchant stock (`dev/plans/understrip/tables/merchants.csv`).
- Which shrines have a Shrine Keeper.

## What isn't
Raider waves after the level loads, bosses' choices of move, and loot rolls on kills. These are the host's in play, sent as now.

## Tests
- `understrip_gen` (node): 3,000 seeds of each kind (the argument raises it). Every level passes the checks, and the same seed always
  gives the same tile hash.
- `understrip_network`: the host's and the guest's tile hashes, layouts and merchant stock match on all three levels.
- Godot (port sweep): the same seeds give the same hashes as the browser, against `out/understrip_gen_fixture.json`.

## Walls in front of the player (settled in M1)
The iso view draws walls nearer the camera over whatever stands behind them. In one- and two-tile tunnels a full-height wall would hide
the player, raiders and telegraphs, so wall tiles in front of you (within about 3.5 tiles toward the camera) draw knee-high
(`15b-understrip-look.js`). Only wall tiles that face open ground are drawn standing at all. Display only: collision and sight are unchanged.
