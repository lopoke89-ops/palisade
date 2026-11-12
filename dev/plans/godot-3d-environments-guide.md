# Palisade desktop: how the 3D environments are made

A starting point for agents and artists working on the desktop game's environments: modeling, design,
set dressing and performance. It describes the code as it is at `4aff8f3` on `codex/understrip-integration`
(the desktop release branch `claude/palisade-godot-milestones-ggzdpn` points at the same commit) and the model
library at `2852ba9` on `understrip-on-weapons`.

Paths are from the repository root unless they name the model library.

---

## 1. Rules before you start

These hold for every environment change. Each one has broken something before or is a release gate.

1. **The sim is the authority and the 3D view only reads it.** `godot/scripts/view3d/` never changes the game's
   state. Collision, line of sight, bullets and pathing come from `sim.gd` tiles, never from meshes. A prop that
   looks solid is not solid unless it replaces a solid tile in the map data.
2. **Browser parity.** The browser game (`dev/src/js/*.js`, live on GitHub Pages) and the desktop game play together
   online, and a level is rebuilt on every machine from the same seed. Anything that changes tiles, markers, the
   level generator or a random number stream must change identically in both clients. Purely visual dressing may
   differ between the clients, but its placement must not consume the game's random numbers (see §9).
3. **Don't touch gameplay randomness.** Use the deterministic tile hash `Pal.hash2(i, j)` (or a hash of your own)
   for visual variety. Never call `randf()`/`randi()` for something that has to look the same every frame or on
   every machine.
4. **Readability beats detail.** The camera is a fixed, high, orthographic view. The player, raiders, floor loot,
   boss telegraphs and doorways must stay readable at every brightness setting.
5. **Measure.** Capture the same view before and after, and record frame time (§11). Keep the added 3D update
   cost within about 10% of the baseline, as the set-dressing plan asks.
6. **Ask before committing, pushing or releasing.** Big U (the owner) signs off visuals from renders. Show a
   render and get a yes before building the next batch.
7. **Protect the owner's saves.** Running the real game rewrites the account, locker and profile saves in
   `%APPDATA%\Godot\app_userdata\Palisade`. Run tests and renders with an isolated `APPDATA` (§12).

---

## 2. The big picture

The desktop game is a Godot 4.7.2 port of the browser game. The browser draws a 2D isometric picture. The desktop
game runs the same simulation and then draws it in 3D, with the 2D HUD on top.

```
sim.gd (+ sim_understrip.gd, us_deep.gd)    the game: tiles, walls, raiders, bosses, loot. Authoritative.
        │  read every frame
        ▼
main.gd ── View3D (scripts/view3d/view3d.gd)  orthographic camera matched to the 2D projection
             ├─ V3World    (v3_world.gd)      ground, terrain, walls, props, build ghost
             │    ├─ V3Scenery (v3_scenery.gd) static scenery: forest, fence, city, casino
             │    └─ UsView3D  (us_view3d.gd)  THE UNDERSTRIP's tunnels and their props
             ├─ V3Actors   (v3_actors.gd)     people: players, Delgado, raiders, bosses (library GLBs)
             └─ V3Fx       (v3_fx.gd)         tracers, kill effects, particles, fire
main.gd ── 2D layers over the 3D: night/darkness (light.gdshader), labels, HUD (hud.gd)
```

The environments are almost entirely **generated in code**. They use vertex-coloured, low-poly boxes, prisms,
cones and quads, built from the same numbers and colours the browser's 2D painter uses. Only people, the eight
library weapons, tracers, kill effects and the player ring come from the Blender model library as GLB files. THE
UNDERSTRIP's nine guns are built in code too (`scripts/us_weapons.gd`: boxes and tubes into one cached mesh per gun).
**No environment prop in play is a GLB today.**

Environments in the game:

| Environment | Where it's built | Map data from |
|---|---|---|
| The Yard, Riverbend, Ashfall Quarry, Frostpeak (co-op maps, 2 sizes) | `v3_world.gd` (terrain, walls, props) and `v3_scenery.gd` (outside band, forest, fence, Frostpeak props) | `scripts/pal_maps.gd` |
| City Black Out (64×64) | `v3_scenery.gd` `_city`, `poi`, `city_ground_detail` | `pal_maps.gd`, colours in `scripts/city_view.gd` |
| The casino floor | `v3_scenery.gd` `_casino`, `_casino_furniture`, `_casino_live` | `scripts/casino_view.gd` |
| THE UNDERSTRIP (10 generated levels in 3 regions) | `us_view3d.gd` | `scripts/pal_understrip_gen.gd`, room kits in `godot/data/understrip/rooms-r1..3.json` |
| Menus, lobby and Locker stage | `scripts/lobby3d.gd`: 3D crew over the **painted 2D** lobby background | `scripts/backgrounds.gd`, `scripts/us_scenes.gd` |

With the model library missing or Settings › GRAPHICS › 3D models off (F9 in a game), the game falls back to the 2D
drawing (`main.gd`, `scenery.gd`, `city_view.gd`, `casino_view.gd`). The 3D colours are taken from that 2D code,
so the two must stay in step.

---

## 3. File map

| File | What it owns |
|---|---|
| `godot/scripts/view3d/view3d.gd` | Camera, sun, fill light, environment, units (`PXV`, `TER`, `WALL_H`, `CHAR`), `at()`, `screen_of()`, frame order |
| `godot/scripts/view3d/v3_mesh.gd` | `V3Mesh`: the geometry builder (`box`, `prism`, `cone`, `disc`, `bar`, `quad`, `tri`, `commit`) |
| `godot/scripts/view3d/v3_world.gd` | Map/terrain rebuild, ground per map, water, pits, cracks, rocks, drums, Frostpeak terraces, walls MultiMesh, debris, resource piles, kilns, scrap, stakes, the build ghost, see-through inputs |
| `godot/scripts/view3d/v3_scenery.gd` | Land outside the yard, trees, fence or quarry rim, Frostpeak caches/beacon/rails/flags, city buildings/lamps/POIs, the whole casino |
| `godot/scripts/view3d/us_view3d.gd` | Understrip floors (per region and hazard), tunnel walls (MultiMesh, lowered near the player), wall paint and graffiti, shrines, lift, traders, Keeper, chests, loot, salvage, flares, hazards, telegraphs, drones |
| `godot/scripts/view3d/quality3d.gd` | Quality knobs and the LOW/MEDIUM/HIGH presets |
| `godot/shaders/v3/world.gdshader` | Ground, props, trees, buildings: flat-lit vertex colour, emission from vertex alpha, see-through dither |
| `godot/shaders/v3/wall.gdshader` | Player-built walls and doors: per-material patterns, damage, char, flash, see-through |
| `godot/shaders/v3/water.gdshader`, `flood.gdshader` | River water and the flood sheet |
| `godot/shaders/light.gdshader` | The 2D night/darkness overlay: a shade with up to 96 light holes and 6 flashlight cones |
| `godot/scripts/main.gd` `_update_light` (≈ line 2948) | Which lights exist, where and how strong; `US_DARK`, `US_DARK_L` |
| `godot/scripts/scenery.gd` | Shared helpers both renderers use: `BAND` (7), `gen_forest`, `out_water`, `ramp_near`, `is_ramp` |
| `godot/scripts/pal_understrip.gd` | `PLAN`: the ten Understrip levels and their regions/bosses |
| `godot/scripts/pal_understrip_gen.gd` | The seeded level generator (bit-for-bit match with `dev/src/js/06g-understrip.js`) |
| `godot/scripts/sim_understrip.gd` | Turns a generated level into the sim's layout (`sim.lay`: lamps, neon, shrines, chests, merchants, exit, gate, doors…) |
| `godot/scripts/art_library.gd` | Loads library GLBs (`instantiate_file`, `instantiate_id`, cached `PackedScene`s), dresses characters |
| `godot/tools/sync_art.sh` | Copies the library's runtime files into `godot/palisade_art/` and pins the library commit |
| `godot/tools/import/palisade_post_import.gd` | Import script applied to every GLB (vertex colours on, loop flags, lobby ground/sky fixes) |
| `dev/plans/understrip-set-dressing-plan.md` | The approved-for-review (not yet built) dressing plan for all ten Understrip levels |
| `dev/plans/understrip/mood-boards.md` | Region palettes and the content rules (what must never appear) |
| `dev/plans/understrip-generator.md` | The generator spec: seeds, grid, steps, markers |

The browser's matching painters: `dev/src/js/17-scenery.js` (forest, fence, lighting), `06e-city.js` (city),
`15b-understrip-look.js` (tunnel look and props), `10k-understrip-regions.js` (Shelter 7 / Area 67 floors and hazards).

---

## 4. Coordinates, units and the camera

**World axes.** One tile is one unit. Sim `x` is world **X**, sim `y` is world **Z**, and **Y** is up.
`View3D.at(x, y, z)` returns a world point on the ground at a sim position, including Frostpeak terrace height.

**Heights come from the 2D's pixels.** The 2D game measures heights in "base pixels". `view3d.gd` converts them:

| Constant | Formula | Value (units) | Meaning |
|---|---|---|---|
| `PXV` | 1 / (32·√2·cos 30°) | 0.02552 | one 2D base pixel of height |
| `PXH` | 1 / (32·√2) | 0.02210 | one 2D base pixel across the screen |
| `WALL_H` | 27.2·PXV | 0.694 | a built wall (`WH`) |
| `TER` | 24·PXV | 0.612 | one Frostpeak terrace step |
| `CHAR` | library metres → tiles | 0.52 | a 1.8 m soldier stands about 0.94 tiles tall |

So **1 tile ≈ 1.92 m** at character scale. A yard wall is about 1.33 m and an Understrip tunnel wall (1.25 units,
`us_view3d.gd`) about 2.4 m. Use these figures when modeling to scale.

**The camera** (`View3D._init`, `sync_camera`) is orthographic, pitched 30° and turned 45°. It reproduces the 2D
projection exactly, so the HUD's nameplates, prompts, crosshair, boss warnings and night light pools line up with
no extra work. Its axes are:

- screen right `CAM_R = (1/√2, 0, −1/√2)`;
- screen up `CAM_U`;
- toward the viewer `CAM_B = (0.612, 0.5, 0.612)`.

What this means for modeling:

- **For fixed, axis-aligned scenery you only see the top, the south face (+Z) and the east face (+X).** `V3Mesh.box`
  colours those three with the 2D's top/left/right colours. North and west faces are darkened copies that only show
  through shadows. Spend detail on the visible faces. This does not hold for anything that turns: people, weapons,
  drones and any prop placed at an angle are seen from every side they can face, so check each one.
- **"Nearer the camera" means larger `x + y`.** The see-through rule and the wall lowering both use `x + y`
  ("depth") and `x − y` ("across").
- **Silhouettes read from one angle.** Readability is judged in the gameplay view, not in a turntable.
- Faces that must face the viewer exactly (the Plinko board, flags) are built along `CAM_R`/`CAM_B`; see `_tree`
  kind 1 and the Plinko panel in `_casino_furniture`.

---

## 5. How a map becomes 3D

### The lifecycle (`V3World.frame`)

1. **Map key.** `map_id | N | game number | casino | Understrip level`. When it changes (or `dirty` is set by a
   `"map"` event), everything under `map_root` is freed, the prop cache is cleared and `V3Scenery.build_map`
   rebuilds the static scenery.
2. **Terrain key.** The map key plus `sim.terr_log.size()` and `sim.terr.size()`. When terrain changes (a quarry
   pit, a shortcut door opening), `terr_root` is rebuilt by `_build_terrain`. For THE UNDERSTRIP this creates a
   `UsView3D` and calls its `build()`.
3. **Every frame:**
   - `_vis()` finds the tiles on screen plus a margin (`Quality3D.draw_margin + 2`);
   - `_who()` passes the people the see-through rule watches to the shaders;
   - `_walls()` refills the walls MultiMesh from the visible tiles;
   - `_debris()` rebuilds only when `sim.debris` changes;
   - `_props()` places resource piles, kilns, scrap and stakes from a cache keyed by look;
   - `_ghost()` draws the build preview;
   - `UsView3D.frame()` updates the tunnels;
   - `V3Scenery.frame()` handles the city lamps and the casino's wheel and cards.

Two rules follow from this. **Anything static belongs in `build_map` or `_build_terrain`, built once into a few big
meshes.** Anything that changes belongs in a per-frame path that does as little as possible.

### The geometry builder (`V3Mesh`)

Every environment piece is a `V3Mesh`. It is a list of triangles with a normal, a vertex colour and a UV2
**anchor**, and `commit()` turns it into one `ArrayMesh` surface (one draw call per mesh). Its primitives:

| Call | Builds |
|---|---|
| `box(x0, z0, x1, z1, y0, y1, top, south, east)` | an axis-aligned block, 2D-coloured faces |
| `box_r(...)` | a box from the 2D painter's iso box (ground rect, lift and height in base pixels) |
| `prism(cx, cz, r, y0, y1, side, top, n, r_top)` | posts, drums, trunks, frustums (side shading baked in) |
| `cone(cx, cz, r, y0, y1, light, dark, n)` | pine tiers, spikes (left half lit, as in the 2D) |
| `disc(cx, cz, rx, rz, y, col, n)` | flat ovals: puddles, rings, shadows, decals |
| `bar(a, b, w, col)` | a square-section beam between two points: rails, struts, neon tubes, pipes |
| `quad(a, b, c, d, col)` / `tri(a, b, c, col)` | anything else |

Colours are sRGB hex strings (`Color.html("#34383b")`), exactly as the 2D uses them. Lighting is done in sRGB
because the project uses the Compatibility renderer (see §6).

**Vertex alpha is a glow flag, not transparency.** In `world.gdshader` a vertex alpha below 1 adds emission:
`EMISSION = colour × (1 − alpha) × 1.6`. Lit windows, a kiln's mouth and lamp heads use alpha 0.05–0.6. Real
transparency uses a separate material (`UsView3D.material(see_through=true)`, the build ghost, the felt layer).

**The anchor drives see-through.** `anchor` is a tile position in UV2, or `(-9999, -9999)` for "never fade". The
`mat_front` (trees, front fence: depth 5.5, width 1.6) and `mat_bldg` (city buildings: 4.5, 2.6) materials discard a
dithered share of pixels when the anchor is up to `fade.x` tiles nearer the camera than a watched person and within
`fade.y` across. Set `g.anchor` before adding the faces of anything tall that may stand in front of someone.

### Materials in `V3World`

| Material | Shader | Used for | Fades |
|---|---|---|---|
| `mat_ground` | world | ground, outside band, casino floor | no (optional tile grid lines, `grid`) |
| `mat_props` | world | rocks, drums, piles, kilns, stakes, POIs, back trees, casino furniture | no |
| `mat_front` | world | trees and fence on the near (south/east) side | yes, for anyone (players, Delgado, up to 24 raiders) |
| `mat_bldg` | world | city buildings | yes, for players only |
| `mat_wall` | wall | player-built walls and doors (one MultiMesh) | yes, for the local player |
| `mat_water`, `mat_flood` | water, flood | river and flash flood | no |

`UsView3D` uses its own `StandardMaterial3D`s instead: shaded, unshaded ("glow" layer) and see-through haze.

---

## 6. Light, shadow and darkness

This is the part most likely to surprise someone used to 3D lighting.

- **Renderer:** `gl_compatibility` (`godot/project.godot`) on desktop and mobile. Shaders light in sRGB (`lin()` is
  the identity), so colours in the code are what you get.
- **3D light is deliberately neutral.** There is one sun (`DirectionalLight3D`, orthogonal shadows, max distance 90)
  and one fill light on layer 2 that lights only people. The world shaders add `sun_k = 0.2` of the sun to an
  ambient of 0.45, so a lit face shows its 2D colour and a shadowed face about 45% of it. Golden hour warms and
  lowers the sun (`View3D._light`).
- **Night and the Understrip's darkness are a 2D overlay, not 3D lights.** `main.gd _update_light` fills
  `light.gdshader` with a coloured shade (alpha `L`) and **up to 96 circular "holes"**, each at a screen position with
  a radius and strength, plus up to 6 flashlight cones (one per Understrip player). The overlay is drawn over the
  3D picture.
  - **To light a new fixture, add a hole in `_update_light`**, keyed off a layout marker. An `OmniLight3D` is the wrong
    tool: it would be crushed under the overlay and costs far more.
  - **A hole only uncovers the picture; it adds no colour.** Coloured light goes on the additive 2D glow layer
    (`main._paint_glow`), drawn over the shade: the casino's neon, the city's lamp glows and `CityDress.glow` use it.
  - **The 96 holes are first come, first served**, in the order `_update_light` adds them: players, Delgado, the
    mode's own lights, raiders, burning walls and drums, kilns, charges, and muzzle flashes last. Nothing is ranked,
    so on a crowded screen the flashes are the first to be cut. Decorative holes must be added after all of these
    (as `CityDress.holes` is) and capped.
  - Understrip darkness: `US_DARK_L = [0.86, 0.8, 0.72, 0.56]` by Settings › DUNGEON BRIGHTNESS (DARK, DIM, LIT,
    BRIGHT); the region tints are in `US_DARK`. The Custodian's stage 2 turns it red, and the Visitor's field failure
    switches the lamps and neon off.
  - Existing Understrip light sources, with radii in `TW2` (half a tile's width on screen): players 1.76, lamps 2.8,
    specimen tanks 1.2, flickering neon 1.9 (steady under Reduce Motion), shrines 1.6 (2.8 once lit), merchants 2.2,
    the open lift 2, flares about 4, salvage 0.9, bosses 1.4.
- **Glow in the dark** comes from the unshaded layer in `UsView3D`. `UsView3D.dim(col, f)` blends a colour from
  `#141312` toward full brightness, because that layer doesn't blend. Neon frames, rings and telegraphs use it.
- **Shadows** follow `Quality3D.shadows`: 0 off, 1 = 1024 map, 2 = 2048 soft. The ground casts no shadows except on
  Frostpeak; water, flood, haze and the ghost never cast.
- **Every light needs a visible fixture**, a lamp, tube or flare, and must leave enemies, loot and warnings readable
  at all four brightness settings (set-dressing plan).

---

## 7. Each environment in detail

### 7.1 The co-op yards (Yard, Riverbend, Ashfall Quarry, Frostpeak)

- **Ground** (`_build_terrain`): one quad per tile in `main._ground_col(i, j, hash)`, plus sparse hash-driven decals
  (grass tufts, quarry gravel).
- **Terrain by tile type:**
  - water (a surface quad over a dark bed) and bridges with planks and rails;
  - quarry pits (`_pit`: a hole with its far walls) and cracks;
  - rock outcrops and burning oil drums (`_terr_item`; the drum flames are V3Fx's, from `world.drums`).
- **Frostpeak** (`_frost_tile`): snowy terrace tops, sloped on ramps and stairs, cliff faces where the ground drops,
  edge highlights, stair treads. `V3Scenery._frost_props` adds the expedition caches, summit beacon, stair
  handrails and route flags.
- **Outside the fence** (`V3Scenery._outside`): a band of `Scenery.BAND` = 7 tiles round the map coloured by distance,
  with water where the river runs out and Frostpeak's terraces continuing behind it.
  - Trees come from `Scenery.gen_forest(sim)`, the same list the 2D uses: pines (snow-capped on Frostpeak), dead
    trees, bushes, boulders and stumps.
  - Back trees go in `mat_props`; front trees and the south/east fence go in `mat_front` so they fade.
  - The fence has posts and two rails, with gaps where the river crosses. The quarry has a rock rim instead.
- **Walls players build** are one `MultiMesh` of unit cubes, refilled every frame from the visible tiles.
  `INSTANCE_CUSTOM` carries the material/door code, damage state, char and hit flash, and `wall.gdshader` paints the
  planks, bricks, ribs, door and damage. The Foreman's slabs use code 4.
- **Props:** resource piles stack in layers as they're used, kilns have a glowing mouth and chimney, plus scrap and
  the stake with its flag (team-coloured in PvP). They are cached by a "look key" string, so a prop's mesh is only
  rebuilt when its look changes.

### 7.2 City Black Out

- **Ground details:** road dashes, rubble, sidewalk seams (`city_ground_detail`).
- **Buildings:** every `T_BLDG` tile is a box whose height and palette come from `Pal.hash2` of its 4×4 block. Lit
  windows face south. Buildings are merged into **one mesh per 8×8 chunk** with `mat_bldg`, so they fade in front of
  the soldiers.
- **Streetlamps:** poles in one mesh; the lamp heads are rebuilt only when the power goes on or off.
- **POIs** (`V3Scenery.poi`): the radio mast, power station, hospital, armory compound, gas station, hardware store,
  brickworks and parking garage, plus a burnt shell once a POI is lost. Their bars and names are painted in 2D at the
  structure's top (`paint_poi_bars`); if you change a POI's height, update its entry there.
- **Storefronts, rooftops and neon** (`scripts/view3d/city_dress.gd`, `CityDress`; the Living World work order's
  first slice, see `living-world-stage0-audit.md`). It is the pattern to copy for dressing any map:
  - `plan()` turns recipes into placement records from the tiles and its own hash `vh` (never the game's random
    numbers): 90 signs in nine districts (the nearest POI, or Main Command), each with its colours, words and one
    landmark, plus 271 rooftop pieces. Everything stands on a building's wall or roof, so nothing looks solid where
    you can walk. What it could not place is listed in `report().skipped`.
  - `chunk()` adds the unlit pieces to each 8x8 building chunk's mesh (no extra draws, and they fade with the
    building). `lit_meshes()` makes one mesh per district with its signs lit and one with them out; play only shows
    or hides them.
  - `frame()` reads the power: a district is lit while the Power Station holds (`game.dark`) and its own POI stands.
    `glow()` draws the halos on the 2D glow layer; `holes()` adds a few holes in the night shade after every
    gameplay light. Flicker and the stutter when a district dies are off under Reduce Motion.
  - `Quality3D.life` (0 off, 1 LOW, 2 MEDIUM, 3 HIGH) sets how much is drawn, never where anything is.

### 7.3 The casino

A fixed 16×16 room: back walls with wainscot, trim and the entrance; slot cabinets with glowing screens; the bar
and stools; the cashier's cage; pillars; velvet ropes; the Plinko board; the tables (blackjack, baccarat, hold'em,
craps, roulette). Live parts:

- the roulette wheel is a node turned every frame;
- cards and chips are an `ImmediateMesh` rebuilt each frame from `casino_ui`'s table views;
- slot glow is drawn on the 2D glow layer (`View3D._frame`).

### 7.4 THE UNDERSTRIP

**Where a level comes from.**

1. `PalUnderstrip.PLAN` lists the ten levels:
   - region 1, the Flood Tunnels: levels 1–2, then the Pit Boss in the Count Room;
   - region 2, Shelter 7: levels 4–5, then the Custodian in the Main Hall;
   - region 3, Area 67: levels 7–8, then the Gatekeeper in the Loading Bay and the Visitor in the Containment Hall.
2. `PalUnderstripGen.generate` grows a level of **8×8-tile cells** (7×7 cells = 56 tiles normally, 8×8 = 64 for boss
   levels) from the region's room kit, `godot/data/understrip/rooms-rN.json`. That file is identical to
   `dev/data/understrip/rooms-rN.json`.
3. A kit piece is a role (`entrance`, `corridor`, `junction`, `room`, `breather`, `merchant`, `cache`, `shortcut`,
   `exit`, `boss_ante`, `boss_arena`), a weight, a max count and an ASCII grid. The kit's legend:

   | Char | Tile | Meaning |
   |---|---|---|
   | `#` `%` | `T_CONC` | tunnel wall, pillar (solid, blocks shots and sight) |
   | `o` | `T_DRUM` | low cover: solid, bullets pass over |
   | `.` `,` `~` `=` | `T_GROUND`, `T_LOW`, `T_WATER`, `T_BRIDGE` | floor, floods, channel (half speed), grate bridge |
   | `D` `G` `K` | doorway, boss gate, shortcut door | |
   | `P` `E` `S` `M` `C` `A` `B` | player start, exit lift, shrine, merchant, chest, ambush, boss spawn | markers |
   | `L` `n` | work lamp, neon grate | light markers |

4. `sim_understrip.gd` turns the result into `sim.lay`: `lamps`, `neon`, `exit`, `shrines`, `chests`, `merchants`
   (trader, lift man, Shrine Keeper, Collector), `gate`, `doors`, `arena`, `edges` (wall tiles that face open
   ground), `haz` (per-tile hazard code: acid, radiation, gravity, gas, blast doors), `vents`, `blast`, `tanks`.
   `sim.lay.us.rooms` keeps every placed room with `id`, `role`, `tag`, `x`, `y`, `w`, `h`, `light` and
   `opensFrom`. **This is the hook for room-aware dressing.**

**How `UsView3D` draws it.**

- **`build()`, once per level:**
  - the floor: one quad per open tile, in the region's shades (`ground_col` for region 1, `reg_ground` for hazard
    floors and regions 2–3), with decals from `ground_detail`/`reg_detail` (cracks, puddles, paint, trefoils,
    grates, gravity rings, alien growth, lab tiles);
  - junk piles and specimen tanks;
  - lamp posts with glowing heads;
  - shrine cabinets, the lift deck and the traders (static figures with a mat of wares).

  These are combined into four meshes: floor, props, glow and flood water.
- **Walls:** a `MultiMesh` of `BoxMesh` instances sized `N × N`. **Only wall tiles that face open ground (`lay.edges`)
  are drawn**, as 1.25-unit columns coloured per region (`WALL_COL`). Shutters, blast doors and the boss gate get
  their own colours.
- **Near-camera wall lowering:** a wall less than 3.5 tiles nearer the camera than any player, and within 1.8 tiles
  across, drops to 0.28 tall. This is display only; collision and sight are unchanged. Anything you hang on walls
  must lower with it or hide, as the wall paint does.
- **Wall paint:**
  - concrete courses and a flood line on the two visible faces;
  - Shelter 7's orange band and Area 67's growth;
  - region 1's three graffiti styles (`tag_of` matches the browser's `usTagOf` bit for bit).

  Each wall's paint is built the first time it's on screen, cached in `tags`, and copied into `walls_live` every
  frame while that wall stands full height.
- **`frame()`, every frame,** rebuilds three meshes from scratch:
  - `warning` (unshaded): shrine neon, the lift ring, elite and boss telegraphs, hazard outlines;
  - `live` (shaded): chests, the Keeper, loot, salvage, flares, drones;
  - `haze` (see-through): vent gas, blast warnings, boss floor effects.

  Floor weapons are `UsWeapons` nodes (code-built meshes, cached per gun: not GLBs), kept in `weapon_loot`.

---

## 8. The model library pipeline

The library is a separate private repository, `lopoke89-ops/palisade-3d-model-library`, checked out at
`Documents\Palisade\model-library-github`. The game pins a revision of it.

```
Blender sources (art/3d/source/*.blend)
  └─ Python builders (art/3d/tools/*.py, run with blender --background --python …)
       export_models.py        catalog → standalone GLBs (shared baked colour/normal tiles, vertex palettes)
       build_character_rigs.py rigs, slots, sockets, 60 fps clips
       lobby_export.py         the 78 lobby environments (Palisade_Dynamic_Lobbies.blend)
       tools/understrip/*.py   THE UNDERSTRIP's skins, hats, tracers, bosses (absolute paths: adjust first)
  └─ verify_models.cjs, verify_* (glTF validation, animation checks)
  └─ catalog.json (ids, files, sha256, counts)
        │
godot/tools/sync_art.sh <library checkout>   → godot/palisade_art/ (+ LIBRARY.txt: repo, commit, branch)
        │
Godot import (project.godot [importer_defaults] → tools/import/palisade_post_import.gd)
```

Conventions to keep:

- **glTF is right-handed, Y up, metres.** Characters face +Z. Tracers have their origin at the nose, pointing +X.
  Kill effects are centred. The game converts metres to tiles with `View3D.CHAR` (0.52).
- **Colour lives in vertex colours**, multiplied by shared baked tiles (`surface_type` roles such as wood, fabric,
  canvas, each with a 256² colour and normal map). The import script turns vertex-colour albedo on; without it,
  surfaces import white.
- **Materials are shared by role** (`game_material`). Don't give each prop its own material; draw calls and memory
  scale with materials.
- **Import settings** (from the library's blueprint): root scale 1.0, animation FPS 60, *Remove Immutable Tracks off*,
  *Use Name Suffixes off*, named skins on, import script `res://tools/import/palisade_post_import.gd`. They are set
  as importer defaults in `project.godot`, so new GLBs get them with no `.import` editing.
- **Pin and record.** After a sync, `palisade_art/LIBRARY.txt` names the library commit. Reused assets stay
  byte-identical unless they are deliberately revised (the catalog carries sha256s).
- **Sign-off flow:** render each new model (the bench scripts in `bench/` make turntables and contact sheets), show
  Big U, get a yes, then export and sync.

What the library has and doesn't have for environments:

- It has **78 lobby environments** (`models/backgrounds/*.glb`, 17 MB) with cameras and party slots in
  `lobby_layouts.json`. They are synced into the game and exported with it, but **not shown**: the menus use the
  painted 2D backgrounds, as the browser does.
- It has **no in-play environment prop kit.** The set-dressing plan calls for one: 30–40 modular props plus one
  landmark per region and four boss-arena perimeters. Building it is new work in the library.

---

## 9. Recipes

### Add a procedural prop to a yard, the city or the casino

1. Find the 2D version first (`scenery.gd`, `city_view.gd`, `casino_view.gd` or the browser's `17-scenery.js` /
   `06e-city.js`) and reuse its colours and proportions. Heights in base pixels × `PXV`, widths × `PXH`.
2. Static: add it in `V3Scenery.build_map`'s path (`_outside`, `_city`, `_casino_furniture`) into an existing
   `V3Mesh`, so it merges into an existing draw. Use `mat_front` or `mat_bldg` with `g.anchor` set if it is tall
   and can hide someone.
3. Changes during play: give it a look key and use `V3World._prop(id, skey, build)`. The mesh is cached per key,
   and props off screen are hidden.
4. Add the matching 2D drawing if the prop matters with the 3D view off.

### Add a static dressing prop to the Understrip

1. Decide where it goes from data, not by hand: a layout marker, a room from `sim.lay.us.rooms` (role and rectangle),
   or a wall tile from `lay.edges`. Pick variants with a hash of (run seed, level, room id, slot), **never** the
   level, raider or loot RNG (`usHash`/`mulberry32` sub-seeds belong to the game).
2. Keep it out of the clearances: doorways (`D`, `G`, `K`), the lift ring (1.6 tiles round `exit`), shrines,
   merchants, chests, loot, combat lanes, and hazard floors whose telegraphs must read.
3. Build it in `UsView3D.build()` into the `props` mesh (shaded) or the `glow` mesh (lights), so it costs nothing
   per frame. If it is wall-mounted, attach it the way `wall_face` does so it hides when the wall lowers.
4. If it should block movement, that is a **gameplay change**: it must replace a solid tile in the room kit or the
   generator in both clients, with a new generator fixture (`understrip_gen_test`). It needs a separate decision.

### Use a GLB prop instead of code geometry

There is no environment-GLB path yet. The nearest patterns are the library weapons (`ArtLibrary`, cached
`PackedScene`s) and the Understrip's floor guns (`UsWeapons.build`: a code-built mesh cached per gun, one node per
gun on the floor, freed when the loot goes). For many identical props:

- load once with `ArtLibrary.instantiate_file` (it caches the `PackedScene`);
- prefer a `MultiMesh` of the GLB's mesh for repeats;
- never instantiate one node per decorative instance per frame;
- dispose of everything on a level change, and check node counts don't grow over repeated descents (§12).

### Add a light

Add a marker (kit `L`/`n`, or a dressing record), draw its fixture in the glow mesh, and add a `hole.call(...)` in
`main.gd _update_light` inside the `sim.understrip()` block. The budget is 96 holes per frame on screen, shared
with players, flashes and fire. Flicker must respect `PalSettings.reduce_motion`.

### Change a region's look

Floor shades: `ground_col`/`reg_ground`. Decals: `ground_detail`/`reg_detail`. Wall colour: `WALL_COL`. Wall
paint: `wall_face`. Darkness tint: `US_DARK`. Match the browser's `15b-understrip-look.js`/`10k-understrip-regions.js`
or agree a deliberate difference with Big U. The region palettes are in `dev/plans/understrip/mood-boards.md`.

---

## 10. The set-dressing plan and its contract

`dev/plans/understrip-set-dressing-plan.md` (5 November 2026) is a proposal for review. **No dressing from it has
been built.** Its direction is grounded industrial decay with a gradual turn toward alien intrusion:

- the Flood Tunnels as the casino's storm drains and dumping ground;
- Shelter 7 as a civil-defence shelter that tried to keep running;
- Area 67 as a lab overrun by growth.

It gives each of the ten levels a landmark.

Every dressed room should answer three questions:

1. What was this room used for?
2. How did people work, move or live here?
3. What happened before the player arrived?

Build in three layers: building systems, then room equipment, then evidence of use.

Its phases, each with a review gate:

1. A baseline and art brief.
2. **One complete Flood Tunnels sample**: a room, its corridor, and a merchant/shrine corner, reviewed in both clients.
3. One sample room each for Shelter 7 and Area 67.
4. The full descent.
5. Cohesion and validation.

Its acceptance rules, which every dressing PR should meet:

- Purpose readable from the gameplay camera; one memorable feature per level.
- Doorways, routes, interactions, enemy silhouettes, floor loot and telegraphs readable and reachable.
- Same seed → same dressing placement and the same collision/navigation in browser and Godot; generator, combat
  and loot results unchanged.
- Reused library assets byte-identical unless deliberately revised, with an asset/hash manifest.
- Added frame time within about 10% of the measured baseline; no growing node counts or leaked viewports across
  repeated level changes.

The content rules in `mood-boards.md` are hard limits. They forbid:

- showing people living in the tunnels;
- real casino names;
- real military or agency insignia;
- logos or mascots borrowed from existing games (Shelter 7 uses its own tortoise mascot and its own "7" stencil).

---

## 11. Performance

**Quality knobs** (`quality3d.gd`; the presets apply at once from Settings › GRAPHICS):

| Knob | LOW | MEDIUM | HIGH |
|---|---|---|---|
| shadows | off | 1024 | 2048 soft |
| effects density | 0.4 | 0.7 | 1.0 |
| draw margin (tiles) | 1 | 2 | 3 |
| animation rate near / far | 30 / 12 | 45 / 15 | 60 / 20 |
| MSAA | off | 2× | 2× |
| max kill effects / tracers | 4 / 24 | 6 / 36 | 8 / 48 |
| render scale | 75% | 100% | 100% |
| life (the city's dressing: `CityDress`) | 1: signs and shops, tight halos, 2 holes | 2: + rooftops, street spill, flicker, 5 holes | 3: + roofline tubes, 8 holes |

**Measured** (this PC, the Black Out final push on HIGH, after `353857a`; from `bench/HANDOFF.md`):

- about 68 FPS;
- the 3D view's CPU update is about 3.25 ms, of which the world is the smallest part (~0.8 ms before that commit;
  ground decals, walls and props were then trimmed);
- characters dominate rendering (~3.7 ms of 5.3 ms), at 372 surfaces for 280 materials.

A fresh baseline of every environment at all three presets (12 November 2026, `a08ef40`) is in
`living-world-stage0-audit.md` §2, with the script that makes it (`bench\living\lw_bench.gd`). On this PC the push
on HIGH is now about 82 FPS.

**Environment cost is small everywhere except THE UNDERSTRIP.** The yards, the city and the casino spend 0.1 to
0.5 ms a frame on the world. The tunnels spend 2.9 to 5.7 ms, the largest single cost in that mode.

How to keep it small:

- **Merge static geometry.** One `V3Mesh` per layer or chunk, not one node per prop. The city's 8×8 chunks show how
  to keep merged meshes cullable.
- **Share materials.** A new material is a new draw and a possible shader compile. Use vertex colour for variety.
- **Per-frame meshes are the expensive pattern.** `UsView3D.frame()` rebuilds `warning`, `live` and `haze` from
  scratch every frame, rewrites every wall instance on screen and copies the cached wall paint into a new mesh each
  frame. **Measured: this is the 2.9 to 5.7 ms above.** Dressing must not go into that path, and the path itself is
  the first optimization to make (`View3D.parts_us` gives world/people/effects timings, `View3D.frame_us` the total).
- **The wall MultiMesh** in the tunnels allocates `N×N` instances and draws `visible_instance_count`; the yard's
  wall MultiMesh resizes to the visible count.
- **Transparency and overdraw.** Haze, gas and see-through effects are alpha-blended without depth writes. Keep them
  low and few.
- **No real-time lights for fixtures** (§6). Fake the glow with vertex alpha and an overlay hole.
- **The lobby environments ship unused** (17 MB of GLBs in the export). Excluding them would shrink the build, but
  first check nothing loads them.

How to measure:

- `godot/tests/shot3d.gd` renders the same moment in 3D and 2D and reports frame times. `PAL_FRAMES=n` measures n
  frames; its scenes are `raid`, `boss <key>`, `river`, `quarry`, `frost`, `city`, `base`, `casino`, `push`, `blitz`
  and more.
- For the Understrip, render fixed seeds with `understrip_shot.gd` / `understrip_deep_shot.gd` /
  `understrip_props_shot.gd` and read `frame_us`/`parts_us`. Compare dressed and undressed at the same settings and
  brightness.
- Prove the picture didn't change when you only optimized: same seeds, identical screenshots.

---

## 12. Rendering, testing and review on this PC

The engine used for the tests is `bench\godot\Godot_v4.7.2-stable_win64_console.exe`. Always give it an isolated
profile, so the owner's saves aren't rewritten. From Git Bash in `Documents\Palisade`:

```bash
APPDATA="$(cygpath -w "$PWD/bench/v0125-test-profile")" bench/godot/Godot_v4.7.2-stable_win64_console.exe --path godot-understrip-integration/godot --rendering-driver opengl3 --resolution 1600x900 --script res://tests/understrip_props_shot.gd -- "C:/Users/lopok/Documents/Palisade/bench/env/props"
```

Visual tests (each script's header has its arguments; the README's `xvfb-run` lines are for Linux):

| Script | Shows |
|---|---|
| `tests/shot3d.gd -- <prefix> <scene>` | any map/mode in 3D and 2D, with frame times |
| `tests/understrip_shot.gd -- <prefix>` | the PLAY page, region 1's first level, the Pit Boss in both stages |
| `tests/understrip_props_shot.gd -- <prefix>` | shrine + Keeper, trader, lift, chest, loot, salvage, flare, the five tracers |
| `tests/understrip_deep_shot.gd -- <prefix>` | Shelter 7 vents, the Custodian, Area 67 drones, the Gatekeeper and pilot, the Visitor |
| `tests/understrip_visitor_shot.gd`, `tests/understrip_playtest_ui.gd` | the Visitor fight and UI (these write into `bench/` themselves) |
| `tests/lobby3d_shot.gd -- <prefix>` | the menu stage and crew |

Headless checks to run after any environment change (all must still pass):

- `understrip_gen_test`, `understrip_sim_test`, `understrip_deep_test`, `understrip_playtest_test`;
- `menu_stage_cleanup_test` (scene disposal);
- `sim_test`, `client_test`.

`bench/rel0125_godot_tests.cjs` runs the whole set with a timeout. Cross-play is `bench/understrip_cross.js A`
(`bench/rel0125/cross_fix_runs.sh N` repeats it).

Things that have bitten before:

- **The exported exe ignores `--script`.** To test the pack, run the console engine with `--main-pack <exe>` and
  absolute script paths.
- **`bench/run_us_tests.sh` copies an old (4 November) save backup over the real saves** at the end. Don't use it as-is.
- **Leaked 3D resources crash the game on exit** (0xC0000005). Free anything detached from the tree in `_exit_tree`
  (see `Menus._exit_tree`), and confirm a clean exit with `bench/shutdown_recheck.cjs`.
- **Check repeated level changes** for growing node and mesh counts.

The command above was run on 12 November 2026 (exit 0, no errors). Its 12 renders in `bench\env\props_*.png` show the
tunnels as they are now, undressed, and serve as the starting baseline.

Review deliverables Big U expects: fixed-seed renders at the gameplay camera (before and after, the same views),
region contact sheets, frame-time numbers, and for models a turntable and an in-game shot.

---

## 13. Where to start, by workstream

**Modeling** (in the model library repository):

- Draft the environment prop kit's first batch for the Flood Tunnels sample:
  - pipe straights, elbows, valves and brackets;
  - a drain grate and outfall, a pump, an electrical box;
  - a pallet, crates, sandbags;
  - a dumped slot cabinet with no real casino names.
- Keep everything in scale (1 tile ≈ 1.92 m; tunnel walls 2.4 m), with shared role materials and vertex colour, and
  with detail on the south and east faces.
- Decide with Big U whether props are GLBs from the library or code-built `V3Mesh` pieces. Today everything is code;
  GLBs give richer shapes but need the instancing path in §9.

**Design:**

- Turn the plan's ten level themes into room recipes for each kit role, 3–4 variants each, with:
  - wall strips, corners and a focal point;
  - clearances and camera-sensitive zones.
- Base them on the real kit pieces (`rooms-rN.json`) and on `sim.lay.us.rooms`.
- Agree the dressing-record format both clients read: arrangement id, position, rotation, variant. Keep it separate
  from renderer geometry.

**Set dressing:**

- Build phase 2 of the plan: one Flood Tunnels room, its corridor and a shrine/merchant corner, placed from data
  with a dressing hash.
- Render a fixed seed before and after. Measure. Get sign-off before going wider.

**Optimization:**

- Profile `UsView3D.frame()` on a busy boss level (Visitor stage 2, drones, gas) and see what the per-frame
  rebuilds cost.
- If they matter: keep the wall paint as one cached mesh per visible set instead of copying arrays every frame;
  reuse materials; split rarely-changing pieces out of `live`.
- Prove identical screenshots.

---

## 14. Open questions for Big U

- Props as library GLBs, or code-built pieces like the rest of the world?
- Should dressing match in the browser (equivalent 2D drawings, as the plan says), or may the 3D game go further
  (Big U has said the 3D bosses needn't follow the browser)?
- The performance target machine and budget for the Understrip on LOW.
- Whether the 78 lobby environments should appear in the desktop menus or be left out of the build.
- The raider uniforms per region (`usLook`) are still not ported. The 3D raiders share one merged material per
  model, so they need Blender variants.
