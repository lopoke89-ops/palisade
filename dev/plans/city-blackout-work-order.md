# v0.9.7 work order: CITY BLACK OUT

Status: **plan; written from Big U's answers on October 3. The open decisions are at the end (D1-D10).** Nothing is built yet.

CITY BLACK OUT is the last game mode before the engine port. It fills the empty sixth slot in the mode picker (today: 5 RAIDS · 10 RAIDS · ENDLESS · BLITZKRIEG · CAMPAIGN).

**The idea:**
- A ruined city at night on a **64×64** map (48×48 if phones can't hold it).
- **Main Command** sits in the center, with roads out to **4 major and 4 minor POIs**.
- After a short gathering start, a POI is hit by a random boss and his wave **every 30 seconds** until all eight have been attacked.
- Then comes a **5-minute final push** on Main Command.
- The last 2 minutes bring **THE SUPREME DESTROYER**.

The table games (blackjack with shard wagers) are a **separate update** (v0.9.7.x), because they need their own server-side dealer.

## What Big U decided

| Topic | Decision |
|---|---|
| Name | **CITY BLACK OUT** |
| Map | 64×64; fall back to 48×48 if phones can't hold a steady frame rate |
| Setting | A ruined town/city at night: power is out; held POIs keep their lights on, lost ones go dark |
| Layout | Main Command in the center; roads link it to every POI |
| POIs | 4 major + 4 minor, each with a perk while held |
| Players | Solo and co-op up to 6 (enemies and boss health scale with crew, as in the other modes) |
| Movement | Moving on roads is faster than off-road |
| Building | Walls and doors anywhere on the map |
| Lost POI | The run goes on; the POI's perk is lost and the final push gets harder. You only lose if Main Command falls |
| Bosses | Random from every boss (standard, Blitzkrieg, winter), no repeats in a row |
| Run length | About 15 minutes |
| Final push | 5 minutes at Main Command: a boss with his own troops every 30 s; the last 2 minutes, the Supreme Destroyer with shieldbearers and grenadiers only |
| Giant boss | **THE SUPREME DESTROYER:** back rockets, a fire-and-lightning gun, poison gas, Minefield, and an Orbital Cannon below 40% health |
| Rewards | A **milestone ladder** now. Big U's new case idea comes after these updates |

## 1. Phase 0: big-map engine work (first, and measured)

Today the whole map is painted into one picture. On a phone, 64×64 would be drawn at about **0.6 pixels per point**, about half as sharp as XL today, and raising the cap risks memory crashes. The numbers (scenery band of 7 tiles, tile width 40 at normal zoom):

| Map | Full picture | Phone sharpness (7.4M px cap) |
|---|---|---|
| 16×16 | 2,500 × 1,375 points | ~1.5 px per point |
| 24×24 (XL) | 3,140 × 1,695 | ~1.2 |
| 64×64 | 6,340 × 3,295 | ~0.6 |

The work:

1. **Map chunks.**
   - The scenery picture is split into **16×16-tile chunks**: 16 for 64×64, 9 for 48×48.
   - Only the chunks on or next to the screen are painted, at full sharpness. Far chunks are dropped, with an LRU budget of about 6 chunks on phones and 12 on desktop.
   - A terrain change (rubble, a fallen building, a destroyed wall's scorch) repaints only its chunk.
   - Existing maps keep the single picture, since they fit, so nothing changes for them.
2. **Culling.** Walls, raiders, fires, decals and particles outside the screen are skipped when drawing. On today's maps this was measured as no gain, but on 64×64 most of the map is off screen.
3. **Pathing on the road network.**
   - Raiders plan their trip over a **road graph** (Main Command, POIs and road junctions as nodes).
   - They do the existing tile pathing only in the last stretch near their target.
   - Wall-aware flow fields are computed **per POI area**, not across the whole map.
4. **Network: send what's near.**
   - Guests get full detail for everything within about 20 tiles of them.
   - For the rest, a small **POI summary**: each POI's health, attacker boss, held or lost, and lights.
   - Slow fields stay as in v0.9.6.3. Protocol `yard-26`.
5. **Mini-map.** A corner mini-map shows Main Command, the 8 POIs (held / under attack / lost), roads, teammates, and the attacking boss. A POI under attack also gets an edge-of-screen arrow, like today's off-screen boss arrow.
6. **The gate** (Big U decided the fallback). A prototype 64×64 city with chunks, culling and 60 test raiders.
   - **Pass:** desktop holds 60 fps, a mid-range phone holds 45+ fps, and memory stays under about 120 MB.
   - **Fail:** switch to 48×48 and re-measure.
   - The measurements go in the evidence folder before the mode is built on top.

## 2. The city map

**Layout:**
- **Main Command** (center): the stake / command post, sandbag walls, a supply depot, and floodlights that always work.
- **Roads:** a ring road around Main Command, with eight spokes out to the POIs and a cross street linking neighboring POIs. Roads are 2 tiles wide, sidewalks 1.
- **Districts between the roads:**
  - ruined blocks: collapsed buildings (solid, and they block bullets);
  - rubble (slow to walk through);
  - alleys;
  - parked wrecks (cover);
  - small parks with trees (wood).
- **Edges:** raiders enter from the four city edges, on the roads mostly.

**Major POIs (one per side, about 22 tiles from Main Command):**

| POI | Look | Perk while held |
|---|---|---|
| **Hospital** | A big white block with a red cross and an ambulance bay | Anyone within 5 tiles heals 3 HP/s; downed teammates there get up 50% faster |
| **Armory Depot** | A fenced compound, ammo crates | Grenades and rockets refill by 1 every 30 s for everyone; standing at the depot refills your special ammo stock |
| **Power Station** | Transformers, cooling stack, sparks | Powers the streetlights on the roads, so you can see further at night. If it falls, the whole city goes darker for the rest of the run |
| **Radio Tower** | A tall lattice mast with blinking lights | Warns which POI is hit next, 15 s before the attack, with a marker on the mini-map. Without it you get 3 s |

**Minor POIs (between the majors, about 16 tiles out):**

| POI | Look | Perk while held |
|---|---|---|
| **Gas Station** | Pumps, a canopy, a mini-mart | +25% salvage from kills nearby |
| **Hardware Store** | A big-box store with a lumber yard | Extra wood and metal piles, refilling every 60 s |
| **Brick Works** | A kiln yard with pallets | Extra brick piles, refilling every 60 s |
| **Parking Garage** | A three-level garage | High ground (uses the elevation system); snipers there get +2 tiles of range |

**Lights:**
- Night look, as on the Quarry.
- Each held POI and Main Command throw a pool of light.
- A lost POI flickers out and stays dark.
- The Power Station also lights the roads.

**New art:**
- ground: road, sidewalk, rubble, and solid ruined-building tiles;
- props: streetlights (on/off), wrecks;
- the eight POI structures;
- night lighting pools.

All of it is drawn in the game's own isometric painter style, like the existing maps.

## 3. How a run goes

| Time | What happens |
|---|---|
| 0:00-0:45 | **Gathering.** Players spread out, gather and build. The map shows all POIs held and lit |
| 0:45 | **Attack 1** on a minor POI. A random boss and his wave come in from the nearest edge (15 s warning with the Radio Tower held, else 3 s) |
| attack | The fight ends when the boss is killed (POI **held**) or the POI's structure is destroyed (POI **lost**). If neither happens in **60 s**, the boss retreats and the POI is held, but damaged (D3) |
| +30 s | The next attack starts 30 s after the last one ends: the **four minor POIs first, then the four majors**, in random order within each group |
| ~11:30 | **Final push** at Main Command, 5:00 on the clock |
| 0:00-3:00 of the push | A boss with his own troops every 30 s (6 bosses), from rotating edges, **at most 4 bosses alive** (D5) |
| 3:00 | **THE SUPREME DESTROYER** arrives. For the last 2 minutes, only shieldbearer and grenadier squads reinforce him, every 20 s |
| end | **Win:** Main Command is standing at 0:00, or the Destroyer is killed earlier (the run ends at once). **Loss:** Main Command falls |

Expected total: about 15-17 minutes, depending on how fast POI fights end.

**POI structures:**
- Each POI has a central structure with health (like a stake), and the attack's raiders target it.
- Players can wall it in during the quiet windows.
- A POI structure that survives keeps its damage; a quiet window repairs it slowly. Repairing it with the existing repair action works too.

**Each lost POI makes the final push harder (D4):**
- **Lost major:** its perk is gone, and **every final-push wave brings one extra troop squad**.
- **Lost minor:** its perk is gone, and **final-push bosses get +5% health** each.
- Losing everything is very hard but still winnable with a full crew.

## 4. THE SUPREME DESTROYER

A huge armored war-machine commander, about twice a normal boss's size.
- **Look:** dark steel, a heavy coat over plate, a rocket pod on his back, and a long two-barrel gun.
- **Color:** a red-orange core glow.
- **Weakness:** **Armor Piercing** (D7).
- **Health:** about 7× a normal boss, scaled by crew size, with the usual multipliers on top (D6). Solo he's beatable by staying on him with grenades and rockets; for a full crew he's a team fight.

Every attack has a warning, as with all bosses:

| Attack | What it does |
|---|---|
| **Back Rockets** | His back pod opens; 6 red landing rings appear around his targets (1.4 s), then rockets arc in. Big damage, breaks wood |
| **Fire-and-Lightning Gun** | He swaps between the two barrels. **Fire**: a stream down a marked lane that leaves burning ground and lights wood. **Lightning**: a tracking blue line, then a bolt that stuns and chains to two more people, like the Stormcaller's but heavier |
| **Poison Gas** | Vents open; a green ring grows around him over 2 s, then a gas cloud fills it for 8 s. It hurts over time, so it forces everyone to range attacks for a while |
| **Minefield** | He scatters about 10 glowing mines across a marked area. They arm after 1 s and blow when someone steps close. Shooting a mine sets it off safely; grenades clear several |
| **Orbital Cannon** (below 40% health) | A satellite targeting circle locks onto a player and follows them for 3 s, then stops for a final 1 s. Then a huge beam hits: massive damage, and it wrecks walls inside. It comes every 20 s while he's below 40% |

He calls **shieldbearer and grenadier squads only**. In the Index he gets his own card, and he counts toward the milestone ladder.

## 5. Rewards (server)

- **Milestone ladder: BLACK OUT**, 5 to 6 cosmetics. Proposed steps (D9):

| Step | Need | Reward |
|---|---|---|
| 1 | Hold 10 POIs total | A city skin, e.g. "Night Shift" |
| 2 | Win 1 run | A headgear |
| 3 | Hold 50 POIs | A tracer |
| 4 | Kill the Supreme Destroyer once | A kill effect |
| 5 | Win a run holding all 8 POIs | A background (the lit-up skyline) |
| 6 | Kill the Destroyer 10 times | A gold skin |

- **Per-run pay** (D8):
  - Supply Case progress like other modes, counting each POI held as a "raid held";
  - shards from salvage;
  - +1 Supply Case per held major POI;
  - a win pays 2 Supply Cases and 25 shards;
  - killing the Destroyer pays +40 shards and +1 skill point.
- **Server work:** a migration built from the live text. It needs Big U's approval, like every release.
  - New mode `blackout` in `claim_match_reward`, with time and POI checks: POIs held can't exceed 8, nor the attacks that time allows.
  - New claim fields `pois_held` and `destroyer`, on claims with `cv: 5`.
  - The lobby length list gets `blackout`.
  - The ladder cosmetics as unlock rows (catalog 5).

## 6. The menu and the rest

- **Mode picker:** the sixth button, **BLACK OUT**. It fills the empty slot.
  - Its setup note: "A night city. Hold eight points as bosses hit them one by one, then defend Main Command against the Supreme Destroyer."
  - Map size is fixed (the map picker hides).
  - Modifiers: the co-op list, minus the Blitzkrieg-only ones.
- **Index:**
  - the Supreme Destroyer card;
  - a short "City Black Out" section listing the POIs and their perks.
- **HUD:**
  - POI status strip, or mini-map;
  - the attack countdown;
  - "POI UNDER ATTACK · HOSPITAL · THE BUTCHER";
  - the final-push clock.
- **Music:** the finale track for the final push, and raid tracks for POI attacks.
- **Online:** host-authoritative as now. Rejoining mid-run restores the POI states.

## 7. Tests and release

- **`blackout_perf`** (Phase 0 gate):
  - chunk painting and eviction;
  - frame time with 60 raiders on desktop and phone viewports;
  - memory budget;
  - the 48×48 fallback.
- **`blackout_map`:**
  - every POI is reachable by road from Main Command;
  - roads are faster to walk;
  - lights follow held/lost.
- **`blackout_run`:**
  - the attack order (minors then majors), 30 s gaps and the 60 s cap;
  - held / lost / retreat outcomes;
  - the perks turn on and off;
  - lost-POI penalties in the final push;
  - the boss cap;
  - the Destroyer arrives at 3:00, his squads are shield and grenadier only, and killing him ends the run.
- **`blackout_destroyer`:** each of the five attacks shows its warning, hurts only inside its area, and draws. The Orbital Cannon only below 40%.
- **`blackout_network`:**
  - the guest sees nearby detail and far POI summaries;
  - the mini-map matches;
  - rejoin restores POIs.
- **`blackout_migration`:** PGlite checks for the new mode, claim limits and ladder unlocks.
- **Release:** full suite, screenshots at three sizes, Big U's approval for the migration, then merge.
- **Version:** v0.9.7, protocol `yard-26`.

**Build order:**
1. Phase 0 and the gate.
2. The city map and POIs.
3. The run loop.
4. The Destroyer.
5. Network and HUD.
6. Server and rewards.
7. Release.

This is the biggest update so far; expect it to take several sessions.

## Decisions for Big U

| # | Question | Proposal |
|---|---|---|
| D1 | Gathering time at the start | 45 s (you said 30 s between attacks; the start gets a little longer to spread out and build) |
| D2 | POI attack order | Minors first, then majors, random within each |
| D3 | A POI fight that runs out the 60 s without the boss dead | The boss retreats; the POI counts as held but keeps its damage |
| D4 | Lost-POI penalties | Lost major: perk gone + one extra squad per final-push wave. Lost minor: perk gone + final-push bosses +5% health |
| D5 | Alive cap in the final push | At most 4 bosses at once (the Destroyer counts as one) |
| D6 | Supreme Destroyer health | About 7× a normal boss, scaled by crew |
| D7 | His weakness | Armor Piercing |
| D8 | Per-run pay | As in section 5 |
| D9 | Ladder steps and rewards | As in section 5 (names and looks to design) |
| D10 | The POI list and perks | As in section 2 |
