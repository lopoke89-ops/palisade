# Living World: Stage 0 audit, coverage matrix and first slice

The first return on [the Living World work order](palisade-living-world-graphics-work-order.md): a checked audit,
a coverage matrix for every playable environment, fresh measurements, a ranked plan, and the first prototype
(City Black Out's storefronts, rooftops and neon). 12 November 2026.

**Status of the work.** Nothing here is committed, pushed or released. The prototype is in the working tree of
`codex/understrip-integration` (HEAD `a08ef40`, art pinned to library `2852ba9`). Measurements, renders and scripts
are in `Documents\Palisade\bench\living\`. No plugin was installed, no renderer was changed, no model was edited.

---

## 1. What was checked, and what the guide had wrong

Checked against the code at `a08ef40` with Godot `4.7.2.stable.official.ed1daf0bf`, renderer `gl_compatibility`
(OpenGL 3.3, NVIDIA 621.14) on this PC (RTX 3060, i5-10600KF, Windows 10, 1920x1080 at 60 Hz).

| Claim | Verdict | Evidence |
|---|---|---|
| Environments are built in code, not from GLBs | True | `v3_world.gd`, `v3_scenery.gd`, `us_view3d.gd` build every map from `V3Mesh` |
| The Understrip's floor guns are GLBs (guide §7.4, §9) | **False** | `us_weapons.gd` builds each of the nine guns from boxes and tubes with `SurfaceTool`, cached per gun. The eight library weapons (`palisade_art/models/weapons`) are GLBs. Guide corrected. |
| "You only see the top, south and east faces" | True for fixed scenery only | Anything that turns (people, guns, drones) shows every side. Guide corrected. |
| Darkness and light are a 2D overlay with 96 holes | True | `light.gdshader`, `main._update_light` |
| The holes are prioritised | **False** | They are first come, first served: players, Delgado, the mode's lights, raiders, burning walls, drums, kilns, charges, then muzzle flashes. On a crowded screen the flashes are cut first. Guide corrected. |
| A hole lights a surface | **False** | A hole only removes shade. Coloured light is drawn on the additive 2D glow layer (`main._paint_glow`), which the casino's neon and the city's lamps already use. Guide corrected. |
| The city map is random per game | False | `PalMaps.lay_city` is a pure function of the tile position (64x64): the same city every game. Landmarks can be authored against it. |
| Black Out's power can come back | Not in the code | `game.dark` is only ever set to true (`sim.gd` 6380). The prototype handles both directions anyway. |
| The perf commits from `bench/HANDOFF.md` are in this branch | True | `96f6305` … `d2fb034` are all ancestors of HEAD |
| The art catalog | 427 assets | 130 skins, 81 tracers, 78 lobby backgrounds, 57 hats, 48 kill effects, 21 bosses, 7 raider types, 4 player classes, Delgado; 163 rigged; 276 MB synced |
| The historic "~68 FPS on the push" | Out of date | Fresh numbers in §2. The push on HIGH now runs 82 FPS here. |

Not checked in this pass: the model library's own sources and animation manifest, every character at gameplay
size, and the browser game. Those belong to the character and weapon audit (§5).

---

## 2. Fresh baseline

`bench\living\lw_bench.gd` (made from the earlier `bench.gd`) starts each scene from seed 20261102, saves a held
capture, then measures 600 live frames after 120 warm-up frames with vsync off. Results: `bench\living\base.json`,
captures `bench\living\base_<scene>_<tier>.png` (48 pictures). 1920x1080, DUNGEON BRIGHTNESS at its default, Reduce
Motion off, revision `a08ef40`.

Frame time in milliseconds on HIGH (LOW in brackets). "View" is the game's own timing of its 3D update on the CPU;
"world" is the environment's share of it.

| Scene | What it is | p50 | p95 | p99 | Script | View | World | Draws |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| raid | The Yard, 12 raiders | 4.88 (4.46) | 7.92 | 8.62 | 2.82 | 1.45 | 0.19 | 319 |
| yardxl | The Yard 24x24, 12 raiders | 4.78 (4.62) | 7.86 | 8.38 | 2.76 | 1.27 | 0.24 | 308 |
| river | Riverbend, flood, the Ferryman | 5.13 (4.33) | 8.09 | 8.72 | 2.81 | 1.52 | 0.19 | 318 |
| quarry | Ashfall Quarry at night, pits | 4.17 (3.56) | 7.34 | 8.65 | 2.42 | 1.30 | 0.17 | 271 |
| frost | Frostpeak | 4.83 (4.01) | 6.61 | 7.37 | 2.82 | 1.18 | 0.16 | 245 |
| base | PvP Base Battle | 3.00 (2.67) | 4.59 | 5.17 | 1.30 | 0.61 | 0.20 | 208 |
| city | Black Out, a POI attack, power on | 5.07 (4.21) | 5.90 | 6.22 | 2.63 | 1.05 | 0.33 | 290 |
| citydark | the same, power lost | 5.16 (4.29) | 7.78 | 8.47 | 2.82 | 1.27 | 0.34 | 313 |
| push | Black Out final push, 52 enemies | 12.21 (10.15) | 14.77 | 16.17 | 7.05 | 3.61 | 0.48 | 683 |
| blitz | Final Blitz, 4 bosses, 14 raiders | 5.87 (4.72) | 12.00 | 12.80 | 3.34 | 1.91 | 0.17 | 383 |
| casino | The casino floor | 3.67 (3.13) | 7.89 | 8.35 | 1.98 | 1.36 | 0.09 | 168 |
| us0 | Flood Tunnels 1 | 7.58 (6.80) | 8.44 | 8.96 | 5.41 | 3.84 | **2.89** | 142 |
| us2 | The Count Room, Pit Boss awake | 10.59 (9.73) | 11.34 | 12.03 | 8.24 | 6.46 | **5.69** | 168 |
| us3 | Shelter 7 1 | 8.54 (8.36) | 10.66 | 11.45 | 6.36 | 4.77 | **3.81** | 171 |
| us6 | Area 67 1 | 9.12 (8.77) | 10.76 | 12.28 | 7.00 | 5.30 | **4.51** | 153 |
| us9 | The Containment Hall, the Visitor | 9.89 (9.73) | 10.88 | 11.62 | 7.47 | 5.62 | **4.67** | 158 |

What the numbers say:

1. **THE UNDERSTRIP's environment costs ten to thirty times what any other map's does**: 2.9 to 5.7 ms a frame on
   the CPU, against 0.1 to 0.5 ms everywhere else. It is the largest single cost in the mode, bigger than the people
   and the effects together, and it is the same on LOW because it is script time, not GPU time. The cause is
   `UsView3D.frame()` (`us_view3d.gd` 168–249): every frame it loops every wall tile on screen, re-parses colour
   strings, rewrites the wall instances, copies each wall's cached paint into new arrays, and builds four new meshes
   (wall paint, warnings, live props, haze). The guide listed this as an unmeasured suspicion; it is now measured.
   **Dressing the tunnels before fixing this would stack new cost on the game's worst frame.**
2. Everywhere else the environment is nearly free today (0.1 to 0.5 ms), so the city and the yards have room for
   dressing as long as it is built once and not per frame.
3. The push is the heaviest moment (12 ms on HIGH, 16 ms at the 99th percentile): inside a 60 FPS frame, but with
   only about 4 ms spare. Anything added to the city has to be measured in that scene.
4. LOW is only 5–15% faster than HIGH on this PC because the game is CPU-bound here. **This PC cannot stand in for
   a weak one.** LOW on integrated graphics is unmeasured.
5. First-use hitches exist (298 ms once on `yardxl`, 177 ms once on `raid` at MEDIUM): a one-off on a map's first
   frames, worth a separate look.

The run's memory and node counts climb through the first third and then hold (nodes 1,870–2,010, video memory
303–313 MB), because one process played every scene in turn and the caches filled. They are not per-scene figures.

---

## 3. Coverage matrix

Every playable environment found in the source (`pal_maps.gd`, `sim.gd`, `pal_understrip.gd`, `casino_view.gd`).
"Clear" lists what dressing must keep free. "Check" is the scene that proves it. Status: **P** prototyped in this
pass, **—** not started.

### Co-op maps (each in 16x16 and 24x24; modes 5 raids, 10 raids, endless, Final Blitz, campaign)

| Map | Landmark | Three story clusters | Motion and sound | Assets needed | Clear | Check | Status |
|---|---|---|---|---|---|---|---|
| The Yard | The camp's repair bench and flag by the stake | Tool racks and a half-fixed fence panel; sorted supply stacks by Delgado's route; wheel ruts and a worn path to the east gate | Tarp and flag in the wind, dust on the east side, one lit work lamp | Bench, racks, crates, tarp, ruts and path decals | Build cells, the stake, piles, spawn edge, Delgado's path | `raid`, `yardxl` | — |
| Riverbend | The flood gauge and winch at the upper bridge | Bridge repairs with spare planks; an abandoned cart at the ford; waterline marks and sandbags on the banks | Reeds, ripples, water sound that rises with the flood | Gauge post, winch, cart, reeds, sandbags, waterline decal | Bridges, banks, flood sheet, the Ferryman's raft lane | `river` | — |
| Ashfall Quarry | The headframe and winch over the pit | Ore staging with hoses; a warning board and a damaged site hut on the rim; drum fires with tool litter | Drum flicker (exists), dust falls, a winch creak | Headframe, hut, hoses, boards, ore heaps | Pits and cracks (they change in play), ramps, drums, the rim | `quarry` | — |
| Frostpeak | The summit beacon (exists) and its antenna | Expedition caches with marked routes (caches and flags exist); a shelter with rope hardware; drifted snow against the handrails | Flags and snow drift in wind, beacon pulse | Shelter, rope and anchor kit, antenna fittings, drift decals | Terrace edges, ramps, stairs, handrails, the evac site | `frost` | — |
| The Whiteout Gauntlet (campaign finale on Frostpeak) | The beacon lit for evacuation | Reuses Frostpeak's kit with storm state | Whiteout wind, beacon alarm | None new | As Frostpeak, plus the evac ring | campaign run to wave 13 | — |
| Final Blitz and evac (any co-op map) | The evac site's ring (exists) | Reuses the map's kit | Shell warnings (exist) | None new | Evac ring, shell markers | `blitz` | — |
| Weather (dust, rain, ash) and NIGHTMARE night | — | States, not places: dressing must read under each | Storm streaks (exist) | None new | — | each map with the WEATHER mod | — |

### PvP (16x16; the Yard, Riverbend and the Quarry each as Base Battle and Free-for-all)

| Layout | Rule | Check | Status |
|---|---|---|---|
| Base Battle x3 (point-mirrored) | Dressing is mirrored with the layout: tile (i, j) and (15−i, 15−j) get the same piece. Nothing taller than cover inside the play area. | `base` | — |
| Free-for-all x3 (four-way turned) | Dressing is turned with the layout. Only outside the fence or flat on the ground. | a `ffa` scene (to add) | — |

### City Black Out (64x64, always night; eight POIs and Main Command)

| District | Landmark sign | Colours | Story | Status |
|---|---|---|---|---|
| Main Command | CITY BANK | cyan, white | Banking and offices round the plaza | **P** |
| Radio Tower | MOTH RADIO | cyan, pink | Hi-fi, film and record shops | **P** |
| Power Station | AMP WORKS | yellow, orange | Electrical trade | **P** |
| Hospital | ST ELM + | green, white | Clinics and pharmacies; battery-backed signs stay on in a blackout | **P** |
| Armory Depot | IRON PAWN | red, amber | Pawn, surplus, locks | **P** |
| Gas Station | OWL DINER | orange, cyan | Roadside food and motels | **P** |
| Hardware Store | NAIL + KEY | yellow, green | Paint, keys, lumber | **P** |
| Brick Works | RED KILN | orange-red, yellow | Kilns, tile, a bar | **P** |
| Parking Garage | KITE HOTEL | violet, pink | Arcade, noodles, a hotel | **P** |

City-wide: clear = roads, sidewalks, plazas, POI structures and their bars, lamps, building see-through.
Check = `city`, `citydark`, `push`, and `bench\living\lw_city_shots.gd` (11 fixed spots). Still to do for the city:
ground-level history (crosswalks, manholes, stains, delivery clutter drawn flat), sound, window activity, vents.

### The casino (16x16)

| Landmark | Three story clusters | Motion and sound | Clear | Check | Status |
|---|---|---|---|---|---|
| The cashier's cage (exists) with a lit cage sign | Service stations behind the bar; table accessories laid out; a staff-only edge with carts | Small sign cycles; slot glow and the wheel exist | Seats, table interactions, cards and bets, the entrance | `casino` | — |

### THE UNDERSTRIP (10 generated levels; landmarks as the set-dressing plan has them)

| # | Level | Landmark | Room recipe tied to a real role | Status |
|---|---|---|---|---|
| 1 | Flood Tunnels 1 | A large storm outfall | `corridor`: pipe runs and a drain line; `merchant`: a staff-access counter | — |
| 2 | Flood Tunnels 2 | A damaged pump station | `room`: pump and failed sandbag line; `breather`: a maintenance break corner | — |
| 3 | The Count Room (Pit Boss) | Counting cages round the arena | `boss_ante`: bag storage and a shuttered counter; `boss_arena`: perimeter only | — |
| 4 | Shelter 7 1 | The check-in desk | `room`: numbered bunks and lockers; `cache`: ration shelves | — |
| 5 | Shelter 7 2 | The generator and filter plant | `room`: switchgear; `junction`: duct runs with direction stencils | — |
| 6 | The Main Hall (Custodian) | The central status board | `boss_ante`: cleaning and service carts; `boss_arena`: blast-door frames | — |
| 7 | Area 67 1 | The decontamination frame | `room`: lab benches; `corridor`: cable trunks | — |
| 8 | Area 67 2 | The breached containment cell | `room`: stripped stations with growth; `cache`: specimen storage | — |
| 9 | The Loading Bay (Gatekeeper) | The suit-service gantry | `boss_arena`: cargo racks and freight marks on the perimeter | — |
| 10 | The Containment Hall (Visitor) | The containment ring | `boss_arena`: observation stations and power routes on the perimeter | — |

Clear, every level: doorways and shortcut doors, the boss gate, the lift ring (1.6 tiles), shrines, merchants,
chests, loot, ambush and spawn tiles, hazard floors and their telegraphs, and one-tile routes. Wall pieces must drop with the wall when it lowers near the camera. Check = `us0`, `us2`, `us3`, `us6`,
`us9` and the `understrip_*_shot.gd` tests. Content rules hold: no tunnel camps, no real casino names, no real agency
insignia, no borrowed mascots.

### Menus and the Locker stage

The 78 lobby background models ship in the build (17 MB) and are never shown. Whether to show them or drop them is
Big U's call (§7).

---

## 4. The first prototype: the city gets storefronts, rooftops and neon

Chosen because the city was the plainest map (identical dark boxes), it is always night, its layout never changes,
and its environment cost had the most room. It is the work order's Stage 1 neon sample done inside the real map.

**What it adds** (`godot/scripts/view3d/city_dress.gd`, new; small hooks in `v3_scenery.gd`, `main.gd`,
`quality3d.gd`):

- **90 signs** across nine districts: 43 shop fronts (a door, lit shop windows and a wall sign), 36 roof marquees
  and 11 sign towers, with block letters built from quads. Each district has its own two colours, its own trade
  words and one landmark sign nearest its POI.
- **271 rooftop pieces** on buildings that carry no sign: AC units, water tanks, vent stacks, skylights, antenna
  masts and stair huts.
- **Power that follows the game.** A district's signs are lit while the Power Station holds *and* that district's
  own POI stands. When either falls, the district stutters out over 1.1 seconds. Nine battery-backed signs (the
  hospital's, and every "+" and "24H") stay on, dimmer. Five signs are dead from the start, seven flicker, and about
  one in five has a dead letter.
- **Glow in three layers:** the lit letters themselves; an additive halo and street spill on the existing 2D glow
  layer (one texture, so it batches); and a capped number of holes in the night shade so the nearest signs show at
  full strength.

**The rules it keeps:**

- The sim reads none of it. Nothing is solid: everything sits on a building's wall or roof (already blocked tiles),
  never on a walkable tile.
- Placement is a pure function of the tile and a hash with its own multipliers (`CityDress.vh`). It never touches
  the game's random numbers, so every machine dresses the city the same, at every setting.
- Signs fade with their building when a soldier stands behind it (same anchor, same material), and the halo dims.
- Signs' holes are added last and stop at the 96 limit, so they can never take a gameplay light's place.
- Reduce Motion: no flicker, no stutter; signs switch cleanly.
- Records are data only (`plan()`), geometry is separate (`chunk()`, `lit_meshes()`), and the per-frame part only
  walks the signs on screen (`frame()`, `glow()`, `holes()`). Placements a recipe wanted but could not make are
  listed (`report().skipped`: 51 blocks with no face on a street, 8 towers with no free corner), not forced.

**The new setting.** `Quality3D.life`, 0 to 3, set by the presets:

| life | Preset | Signs, shops | Rooftops | Halo | Street spill, flicker | Roofline tubes | Holes at once |
|---:|---|---|---|---|---|---|---:|
| 0 | (off: the city as it was) | — | — | — | — | — | 0 |
| 1 | LOW | yes | — | tight, up to 14 signs | — | — | 2 |
| 2 | MEDIUM | yes | yes | wider, up to 28 signs | yes | — | 5 |
| 3 | HIGH | yes | yes | wider, up to 44 signs | yes | yes | 8 |

The hole ceilings are below the work order's provisional 4, 8 and 12: the first measurement showed each extra hole
costs every pixel of the night shader. With 2, 5 and 8 the nearest signs and every landmark in view still get one.

Landmarks and words are the same at every level; only how much is drawn changes.

**Cost, measured.** Whole frames first: alternating runs with the dressing off and on, 600 live frames each, in
the three city scenes (§6 has the commands). Milliseconds, "off → on":

| Scene | Preset | p50 off → on (ms) | p99 off → on | View update off → on | World off → on | Draws off → on | Triangles off → on |
|---|---|---:|---:|---:|---:|---:|---:|
| city | LOW | 4.34 → 4.77 (+10.1%) | 5.51 → 6.57 | 0.93 → 1.05 | 0.29 → 0.37 | 214 → 220 | 126031 → 130544 |
| city | MEDIUM | 5.20 → 5.22 (+0.3%) | 12.57 → 13.23 | 1.56 → 1.55 | 0.32 → 0.38 | 300 → 306 | 217367 → 230254 |
| city | HIGH | 5.02 → 5.22 (+4.0%) | 12.80 → 12.72 | 1.47 → 1.48 | 0.33 → 0.39 | 301 → 306 | 217660 → 230415 |
| citydark | LOW | 4.39 → 4.62 (+5.4%) | 7.44 → 7.09 | 1.14 → 1.20 | 0.30 → 0.35 | 223 → 229 | 128614 → 133119 |
| citydark | MEDIUM | 4.84 → 4.95 (+2.3%) | 7.60 → 7.43 | 1.19 → 1.24 | 0.31 → 0.36 | 317 → 322 | 222120 → 234658 |
| citydark | HIGH | 5.09 → 5.03 (-1.3%) | 8.08 → 8.75 | 1.28 → 1.29 | 0.33 → 0.38 | 316 → 319 | 221952 → 234038 |
| push | LOW | 10.22 → 10.70 (+4.7%) | 13.91 → 18.86 | 3.21 → 3.39 | 0.42 → 0.53 | 418 → 425 | 171821 → 179013 |
| push | MEDIUM | 11.75 → 12.06 (+2.7%) | 15.85 → 17.31 | 3.50 → 3.57 | 0.46 → 0.54 | 694 → 701 | 307649 → 328731 |
| push | HIGH | 11.87 → 12.30 (+3.6%) | 16.59 → 15.76 | 3.56 → 3.65 | 0.47 → 0.56 | 695 → 702 | 307963 → 329066 |

Each figure is the mean of two runs. A single run varies by about ±0.3 ms, so differences under that are noise
(one cell even shows the dressed city faster). The table was measured before the last trim of the glow painter,
so it slightly overstates the cost.

Timed directly (`bench\living\lw_dress_cost.gd`: the dressing's own script time per frame, final code):

| Preset, spot | Signs on screen | Per-frame update | Holes | Glow painter | Total added |
|---|---:|---:|---:|---:|---:|
| LOW, Main Command | 39 | 0.043 ms | 0.004 ms | +0.048 ms | **0.09 ms** |
| LOW, Parking Garage | 13 | 0.023 ms | 0.004 ms | +0.050 ms | **0.08 ms** |
| MEDIUM, Main Command | 39 | 0.044 ms | 0.009 ms | +0.104 ms | **0.16 ms** |
| MEDIUM, Parking Garage | 13 | 0.023 ms | 0.009 ms | +0.065 ms | **0.10 ms** |
| HIGH, Main Command | 39 | 0.044 ms | 0.013 ms | +0.136 ms | **0.19 ms** |
| HIGH, Parking Garage | 13 | 0.024 ms | 0.014 ms | +0.062 ms | **0.10 ms** |

Building the plan takes 35 ms once per city, not per frame. The picture costs 6 to 7 more draw calls and 4,500
(LOW) to 21,000 (HIGH) more triangles.

**Against the work order's allowance** (about 10% of the matched frame and of the view update): the push, the
heaviest scene, goes from 11.87 to 12.30 ms at the median on HIGH (+3.6%), and its view update from 3.56 to
3.65 ms (+2.5%). It stays inside a 60 FPS frame. LOW on weak hardware is still unmeasured.

**Checks that passed:**

- **With `life` 0 the city is the city as it was.** Four spots, power on and off, rendered from HEAD's code and from
  the working tree at `life` 0: every differing pixel is inside the 60x85 pixel box of the soldier's own animated
  figure, and two runs of the same code differ there by more (`bench\living\identity.sh`).
- **Nothing grows.** Eight rounds of map changes (32 city builds across all four levels, a blackout in each round,
  the Yard between) end with the same node, object, resource and buffer counts as the first round
  (`lw_transitions.gd`: STEADY).
- **Headless suites pass:** `sim_test`, `client_test`, `understrip_gen_test`, `understrip_sim_test`,
  `understrip_client_test`, `understrip_deep_test`, `understrip_playtest_test`, `menu_stage_cleanup_test`,
  `music_test`.
- No leak or script-error line in any measurement run's log. (The first draft did leak at exit: the helper held
  its owner, a reference cycle. Fixed by holding the world node instead.)

**Not checked:** an exported build, online play with a browser guest, controller and touch layouts, and the
Settings page (the presets set the new knob; it has no switch of its own yet).

**Review pictures.** `bench\living\review\` has the sheets: before and after at two spots, the blackout, LOW
against HIGH, all nine districts, and `6_power_loss.gif` (the Power Station falling). The full set is in
`bench\living\shots\`: 11 spots, each with the dressing off, on LOW and on HIGH, with the power on and off.

**Known limits of the prototype:**

- No sound yet. No ground-level history yet (it has to be flat to stay walk-through honest).
- The 2D view (3D models off) shows none of it. That is allowed for decoration, but it means the two views differ.
- Letters are 3x5 blocks: readable at the default zoom on landmark signs, small on single-tile shop signs.
- Names and words are placeholders I made up. They are easy to change (`CityDress.DISTRICT`).
- The halo is not hidden by buildings in front of a sign; with buildings this low it rarely shows.

---

## 5. Ranked plan

Ranked by what the player sees most, against cost and risk.

1. **Review the city slice.** Big U looks at the pictures and the clip and says keep, change or drop. Nothing wider
   is built on it before that.
2. **Fix the Understrip's per-frame rebuild** (§2, finding 1): keep the wall instances and the wall-paint mesh until
   the visible set or a wall's lowered state changes; stop re-parsing colours; rebuild `live`, `warning` and `haze`
   only when their inputs change or animate. Target: world update under 1 ms. Proof: identical screenshots on fixed
   seeds, the five `us*` scenes before and after. This is pure headroom and should land before any tunnel dressing.
3. **Finish the city slice to the work order's Stage 2:** flat street history (crosswalks, manholes, stains),
   two or three sound emitters with distance limits, slow window changes, then one refined soldier, one common
   raider and one gun shown in it.
4. **The Understrip proof (Stage 3):** one Flood Tunnels room, its corridor and a shrine/merchant corner, placed
   from `sim.lay.us.rooms` with the same recipe/placement/geometry split, wall pieces dropping with the walls.
5. **Yards and the casino:** one landmark and three clusters each, outside the build area or flat.
6. **Character and weapon audit** (not started): rank the 163 rigged models and 17 guns by time on screen. Start with
   the seven raider types (they fill the screen in a push) and the nine Understrip guns (box-and-tube builds).
7. **Renderer and plugin research:** only the built-in glow and SSAO were tried here (below). Mobile, Forward+,
   ProtonScatter and Terrain3D are untested and nothing in this slice needed them.

**Built-in glow and SSAO in the Compatibility renderer** (tested locally with `bench\living\lw_glow_probe.gd`):

| Variant | GPU time a frame | What changed on screen | Verdict |
|---|---:|---|---|
| As it is | 0.96 ms | — | — |
| `Environment.glow` (threshold 0.85, screen blend) | 1.35 ms | 9% of pixels, faintly: the signs bloom a little | Works, **defer**: the 2D halo already does this for less |
| `Environment.glow`, strong (threshold 0.7, additive) | 1.30 ms | The whole picture lifts slightly | Works, **reject** as tuned: it flattens the night |
| `Environment.ssao` (radius 0.6) | 2.07 ms | 12% of pixels, barely visible at this camera distance | **Reject** for now: +1.1 ms for almost nothing |

So both features run in this project's Compatibility renderer with its custom shaders and the 2D overlay, as the
4.7 documentation says. Neither earns its cost at the gameplay camera today. Pictures:
`bench\living\review\7_engine_glow_ssao_test.jpg`. Everything else in the work order's §9 table is **unverified**:
no other renderer, plugin or engine version was tried.

---

## 6. How to reproduce

From Git Bash in `Documents\Palisade\bench`, always with the throwaway profile so the real saves are untouched:

```bash
export APPDATA="$(cygpath -w "$PWD/v0125-test-profile")"
G=godot/Godot_v4.7.2-stable_win64_console.exe
P=../godot-understrip-integration/godot
L=C:/Users/lopok/Documents/Palisade/bench/living
```

- Baseline, every environment at LOW, MEDIUM and HIGH (about 15 minutes):
  `$G --path $P --rendering-driver opengl3 --resolution 1920x1080 --script $L/lw_bench.gd -- $L/base.json warm=120 frames=600`
- One scene with the dressing off: add `scenes=city,citydark,push "gfx={'life':0}"`.
- Review pictures and the clip: `$G --path $P --rendering-driver opengl3 --resolution 1920x1080 --script $L/lw_city_shots.gd -- $L/shots tiers=0,1,3`
- Repeated map changes: `$G --path $P --rendering-driver opengl3 --script $L/lw_transitions.gd -- rounds=8`
- Built-in glow and SSAO: `$G --path $P --rendering-driver opengl3 --resolution 1920x1080 --script $L/lw_glow_probe.gd -- $L/glow`
- The dressing's own cost: `$G --path $P --rendering-driver opengl3 --resolution 1920x1080 --script $L/lw_dress_cost.gd`
- Is `life` 0 the old picture: `bash living/identity.sh` (it swaps three scripts for HEAD's and puts them back)
- Review sheets: `python living/make_sheets.py` (run it without the `APPDATA` override: Pillow is in the user site)
- Headless suites: `node rel0125_godot_tests.cjs sim_test client_test understrip_gen_test menu_stage_cleanup_test`

`lw_bench.gd` is generated: edit `lw_scenes.gd.txt` or `make_lw_bench.py` and run `python living/make_lw_bench.py`.

---

## 7. Decisions for Big U

1. **The city slice:** keep the direction? Change the names, colours, density, or how bright the signs are?
2. **The 2D view:** leave it without the dressing, or draw simple signs there too?
3. **Order of work:** fix the Understrip's frame cost next (my recommendation), or go straight to more dressing?
4. **Props as Blender models or code-built pieces?** The city slice needed no models. Tunnel props (pumps, bunks,
   lab benches) are where authored models would start to pay.
5. **The LOW target machine.** Without one, LOW's cost on weak hardware stays unmeasured.
6. **The 78 unused lobby models:** show them in the menus, or drop 17 MB from the build?
