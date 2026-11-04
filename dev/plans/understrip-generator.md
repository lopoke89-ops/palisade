# THE UNDERSTRIP: the level generator (spec)

**Status:** draft written at M0, so the room kit's format is settled before code; finished in M1 (work order section 15). The browser and the Godot port must build the same level from the same seed, so everything below is exact.

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
  - The run seed comes from the host. Each level's seed is `hash32(runSeed, region, level)`, so a level can be rebuilt on its own (rejoin, desync checks).
  - The level's merchant stock and chest contents each get their own sub-seed, `hash32(levelSeed, n)`. Buying from one merchant then never changes what the next one rolls.
- **Picks:**
  - A weighted pick sums the weights in kit order and walks them.
  - Ties and iteration order always follow the kit's array order, never object-key order.

## The grid
- A level is a square of **cells, 8 × 8 tiles each**: 7 × 7 cells (56 tiles) for normal levels, 8 × 8 (64 tiles) for a boss level. This keeps every level within the 48–64 limit (section 5.2).
- A piece covers `size` cells.
- Doorways sit in pairs at tiles 3–4 of a cell edge, so any two pieces placed side by side either share a doorway or meet wall to wall.
- Cells left empty are solid rock.

## Steps
1. **Entrance.**
   - Pick a random cell on the grid's edge.
   - Place the entrance piece there, turned so its doorway faces inward.
2. **Critical path.**
   - From the entrance doorway, grow a path of **8–12 pieces** (the count is a pick).
   - Each step, try the pieces that fit (free cells, a doorway matching the open one, within each piece's `max`), weighted by `weight`, in every allowed rotation and mirror.
   - Corridors and junctions only for the first two steps, so the start isn't a room.
   - If nothing fits, step back one piece and try again; give up after 400 tries and restart with `seed+1`. That restart is part of the spec: both versions must do it the same way.
3. **The end of the path:**
   - **Normal levels:** the exit piece.
   - **Boss levels:** the antechamber (its gate facing on), then the arena.
4. **The breather** goes on the path between 40% and 70% of the way along, never next to the entrance or the exit.
5. **Branches.**
   - From the path's open doorways, grow side branches of 1–3 pieces until **30–40% of all pieces** are on branches.
   - Merchants (1–2) and caches go only at branch ends, and every level has at least one merchant.
   - The Collector (1 level in 3, by sub-seed) gets the longest branch and an elite guard.
6. **Shortcut.**
   - Find a pair of a late path cell (the last third) and an early one (the first half) that are one cell apart with a free cell between them.
   - Put the shortcut piece there, with its `opensFrom` side toward the late cell.
   - If no pair exists, regrow the branches with the next sub-seed. A level without a shortcut is never accepted.
7. **Seal** every doorway that doesn't meet another piece's doorway (its two tiles become wall).
8. **Lay** the tiles into `terr`, and collect the markers into the layout.
9. **Check** (both versions, every level):
   - every placed piece can be reached from the entrance with all shortcuts open;
   - the exit can be reached with the shortcut shut;
   - the entrance-to-exit path has 8–12 pieces;
   - 30–40% of pieces are on branches.

## What's chosen from the seed (so the host and every guest agree)
- The layout.
- Which ambush spots hold a raider.
- The elite in each room cluster.
- Chest contents.
- Merchant stock (`dev/plans/understrip/tables/merchants.csv`).
- Which shrines have a Shrine Keeper.

## What isn't
Raider waves after the level loads, bosses' choices of move, and loot rolls on kills. These are the host's in play, sent as now.

## Tests (M1)
- `understrip_gen` (node): 10,000 seeds per region. Every level passes step 9, and the same seed always gives the same tile hash.
- A two-client test: the host's and the guest's tile hashes and marker lists match.
- Godot (port sweep): the same 10,000 seeds give the same hashes as the browser, against a fixture file of `seed → hash`.

## Known M1 risk: walls in front of the player
The iso view draws walls nearer the camera over whatever stands behind them. City buildings do this on purpose (`cityOccluders` in `06e-city.js`). In one- and two-tile tunnels, a full-height wall would hide the player, raiders and telegraphs. M1 must settle this before the slice is played. The usual answer, and the recommendation: walls on the camera side of anyone on screen draw low (a knee-high cut-away), walls behind draw full height. This is display only; collision and sight lines are unchanged.
