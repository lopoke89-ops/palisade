# THE UNDERSTRIP: Godot integration handoff

November 4, 2026. Work continues in `C:/Users/lopok/Documents/Palisade/godot-understrip-integration`, branch `codex/understrip-integration`.

## Base and preserved work

This worktree starts at `bench/blackout-flow-speed` (`d2fb034`): the actual 3D desktop renderer plus the measured performance fixes. It includes an uncommitted merge of `godot-understrip-plan` (`25e725e`), bringing the browser through v0.12.3. The two browser merge conflicts were resolved with the browser branch's versions. The original checkout `palisade/` and its uncommitted work are preserved.

The existing G0 changes were applied with a three-way patch. Overlapping roll implementations keep the already-tested 3D branch's implementation and tests; cosmetics, case RPC, fallback art and the client regression fix carry over. The main input merge preserves the 3D branch's chat/input gating. The source patch is backed up at `bench/understrip-g0-original.patch`.

No commits, pushes, PRs, or live database changes were made. This worktree intentionally retains its pending merge; there are no unresolved files. Do not commit without the user's requested review.

## G1 implemented

- `godot/scripts/pal_understrip_gen.gd`: native GDScript port of the browser generator, including unsigned 32-bit multiplication, mulberry32, seed mixing, all piece rotations/mirrors, weighted placement/backtracking, shortcuts, branches, door sealing and markers.
- `godot/data/understrip/rooms-r1..r3.json`: the browser room kits, unchanged.
- `godot/scripts/pal_understrip.gd`: all ten levels' run order and seed selection, terrain conversion and exposed-wall mask.
- `PalMaps`: tunnel terrain constants and collision/shot rules. Junk stops movement but permits shots; concrete, closed shortcuts and tanks stop both. The two inlined collision scans in `sim.gd` also recognize the new terrain.
- `godot/tests/understrip_gen_test.gd` and its tracked fixture: 1,400 tile hashes from the browser, across all three regions and four boss arenas. Includes run-order/terrain checks.

## Verification

Godot 4.7.2 from `bench/godot`:

- Browser generator: `node dev/test/understrip_gen.js 600` passed; 2,200 levels generated and checked twice for determinism/reachability, writing 1,400 fixture entries. Copy its output fixture to `godot/tests/understrip_gen_fixture.json` when deliberately updating the reference.
- Native generator: all 1,400 browser hashes match.
- Existing simulation suite: 232 checks, ALL PASSED (`bench/understrip-sim-console.log`).
- Client suite: 66 checks, ALL PASSED (`bench/understrip-client-isolated.log`). `bench/understrip-client-isolated.py` temporarily redirects user:// strings to `bench/understrip-test-user`, restores original source bytes in a finally block, and touches no real saves. Run it only while no other process is editing this worktree. Normal sandbox runs cannot write the user's AppData.
- Import completes. Sandbox logs include certificate-store/editor-settings access messages; the client suite also reports teardown resource warnings.
- Both staged and unstaged `git diff --check` pass.

## Still required before release

### G2 development slice, added later November 4

The first region now has native simulation and a 3D development view. This supersedes the original G2-next paragraph below; it is not a release sign-off.

- `sim_understrip.gd` connects generated maps to `Sim.new_game`, disables normal raids, stake defeat, building and passive healing, and implements checkpoint rests, Lucky Juice, shared lives, salvage loss/recovery, bleeding out, lifts, flash floods, arena gates, waiting/alerted raiders, player flow fields and elite attacks. Flow work is capped at two player fields a frame, with a 0.25 s minimum interval.
- `us_pitboss.gd` ports the Pit Boss's two-stage swing, chip lobs, charge, spray, security calls, protected transition and arena flood. Both staged Pit Boss GLBs are copied into the local game catalog; the jacket-off model is selected for stage two. The shared external model-library checkout was not changed or published.
- `us_loot.gd` consumes the browser's exported tables and implements seeded loot and merchant stock, second weapons/mods/signatures, magazines/reserves, weapon swapping, pickups, run perks/relics and region-one weapon hit effects. Chests, elites and the boss produce loot. Normal raiders can drop ammo packs.
- All four merchant kinds are placed, including the Collector's guards. `us_trade_ui.gd` provides native purchase buttons and keeper/lift upgrades. C drinks; E interacts; 1/2 select weapons; F selects the carried item; Space uses it. Shop/interaction, weapon and consumable input paths have a dedicated client check.
- `view3d/us_view3d.gd` draws native floor, exposed walls, obstacles, shrines, lamps, lift, chest/merchant placeholders and pickups. Only visible walls are instanced, and those in front of soldiers lower without changing collision. It draws Pit Boss/elite warnings. The existing lighting shader now supports directional player cones, lamps and flares.
- The HUD displays lives, juice and the level, removes stake/build controls, and restarts the Pit Boss's health fraction for stage two. A running-game capture is at `bench/understrip-g2-arena.png`.

Validation after this work:

- `understrip_sim_test.gd`: 28 gameplay checks passed, including squad wipes, salvage recovery, lift travel, boss wake, stage transition, gate sealing and reopening.
- `understrip_loot_test.gd`: 540 browser loot rolls, 180 merchant-stock fixtures and 12 raider populations (including unsigned boundary seeds) match. Weapon magazine/reserve and merchant/inventory checks pass.
- `understrip_client_test.gd`: seven interaction/UI checks passed in an isolated profile.
- Existing `sim_test.gd`: all 232 checks passed; existing `client_test.gd`: all 66 checks passed. A merge-time encoding mismatch in the old campaign-name assertion was corrected against the original source, rather than changing expected game behavior.
- `godot/tools/understrip_export.cjs`, run with Node from the repository root, regenerates the shared tables and new fixtures directly from the unchanged browser functions.
- Import completes without script parse errors, and both diff whitespace checks pass. Native visual capture renders with the staged model and new lighting; the graphics process reports shader-cache permissions messages and hangs during shutdown after graphics resource leak diagnostics, requiring termination of that test process. The isolated runner restored all temporarily redirected save-path strings. This shutdown issue needs investigation before a Windows build is signed off.

Still outstanding for G2: a full manual region-one run, gameplay and visual tuning against the browser, wounded-raider regroup parity, complete art/environment polish and performance measurement of the new darkness/tunnels. Region-three charge/bounce/lift weapon mechanics and hazards belong with G3 and are not implemented by the basic gun-table port. The mode remains outside normal menus; G4 cross-play and G5 claims must be completed before exposing it as the released ten-level mode. No live claims or database changes were performed during these offline tests.

The original next-work paragraphs below are retained as historical context.

G1 is generation/data groundwork. THE UNDERSTRIP is deliberately not offered in the game menus yet. The ten-level mode must not fall through to normal raid/build behavior.

Next is G2: wire the generated map into `Sim.new_game`, add the crawl state/lives/shrines/lifts/raider activation, implement player loot/weapons/consumables/merchants and the Pit Boss, then the native 3D tunnel view, darkness and near-camera wall lowering. Complete G3's deeper hazards/bosses, G4's yard-31 cross-play, and G5's reward claims and build gates before shipping.

3D art in `bench/` is still staging work, not integrated into the game/library catalog. Do not claim that model previews establish in-game animation or approval. The earlier plan records approval of the ten skins; newer hats/tracers/boss previews need their integration/approval status established. The case's 2D fallback art already merged here does not replace this asset work.

## G2, continued by Claude (November 4, evening)

ChatGPT's G2 work was picked up where it stopped: run logic, loot, merchants, the Pit Boss, the 3D tunnel view and the
light. It was all green at the start. Still nothing committed; the worktree keeps its pending merge.

- **Art from the model library:** `godot/palisade_art` is synced from library branch `understrip-on-weapons` (`238a02f`,
  built on `weapons-v1` so the weapons stay). That brings in the 25 new models: the case's 10 skins, 5 hats and 5
  tracers, and the 5 bosses. The hand-copied `pitboss.glb` and `pitboss_s2.glb` are gone.
  - The Pit Boss is the library's final model. Stage 2 hides its `Equipment_Jacket` slot (`v3_actors.gd`) instead of
    swapping models.
  - `Equipment_Jacket`, `Equipment_Damage` and `Equipment_Pilot` are live slots, so the merge keeps them switchable.
  - Note: a first sync from the library's `main`-based branch stopped halfway, because it has no `weapon_profiles.json`.
    The full sync from `understrip-on-weapons` rebuilt the folder.
- **Menus:** THE UNDERSTRIP is a solo length on PLAY. The online room picker doesn't offer it until G4.
  - It has its own map and length rows, its hint, and a selected card.
  - A NEW MODE card replaces the Whiteout one.
  - The heading reads "SOLO · UNDER THE STRIP" / "FIND THE LIFT.", with the browser's lede and blurb.
- **Noise:**
  - Shots call `us.noise(x, y, 8)` (usNoise). An alerted raider beeps and calls in raiders within 6 tiles who can see
    it (`alert_raider`, usAlert).
  - Hunting raiders make footsteps, at most 3 a frame (`steps`, usSteps). The new `step` sound is rendered last in
    `render_sfx.gd`, so every other `.wav` stays byte-identical.
- **Sounds, as the browser plays them:**
  - going down, LUCKY BREAK, doors, chests, the lift and gate horns, a wipe, the flood warning, loot drops, weapon
    swaps;
  - the flare's throw and the barricade's placing;
  - the charger's tell and charge, and the caller's laser;
  - the Pit Boss: his lock-on, charge, wall hit, chip toss, jacket-off horn, and "SECURITY!" with the siren.
- **Tests:**
  - `understrip_sim_test`: noise only within earshot, the alert spreading, the step sound, the library's jacket slot.
  - `understrip_client_test`: the PLAY rows and the solo length.
  - All suites pass: gen (1,400 hashes), sim, loot, client, `sim_test` (232), `client_test` (66).
  - `tests/understrip_shot.gd` renders the PLAY page, level 1, and the Pit Boss in both stages.

**G2 finished (Claude, later the same evening):**
- **Tracer extras:** `v3_fx.gd` draws each profile's `decor` from `tracer_profiles.json`, as the library's
  `tracer-effects.js` does:
  - poker chips tumbling and gold coins spinning along the streak;
  - the neon tube's buzz and wide tube;
  - the tractor beam's wobbling core;
  - the saucer bolt's pulsing ring.
  - They are drawn about twice the library's size so they read at game distance. Profiles without `decor` are
    unchanged.
- **Tunnel props** (`us_view3d.gd`), the browser's pieces built in 3D:
  - the neon shrine: a cabinet with a pink frame and a "7" that flicker until you rest, then stay lit, plus a ring on the
    one you last rested at;
  - the traders, the Lift Merchant and the Collector, as standing figures, with a mat of wares;
  - the Shrine Keeper robot with its lamp eye and mop;
  - strongboxes, which disappear once opened;
  - the lift's deck, posts and dashed hold ring, with its progress arc;
  - loot of each kind in its rarity's ring; salvage sacks; burning flares.
- **Region 1's look:**
  - the Flood Tunnels' floor shades, cracks, puddles catching neon, and spilt paint;
  - concrete courses and a flood line on the walls;
  - the browser's three graffiti tags, on the same walls (`tag_of` matches `usTagOf`). Each wall's paint is built once,
    then reused.
- **Darkness:**
  - The overlay uses `US.darkL` with the region's tint, and the browser's whole light list: lamps, tanks, flickering neon,
    lit and unlit shrines, traders, the open lift, flares, salvage, bosses.
  - Settings > SCREEN has **DUNGEON BRIGHTNESS** (DARK, DIM, LIT, BRIGHT; `usBright`). On BRIGHT every raider gets a ring
    and a marker over the dark.
- **HUD:**
  - The kit adds the found gun (its name and magazine/reserve, bordered in its rarity), the item SPACE places
    (BARRICADE or FLARE), and the other item (F swaps).
  - Prompts: the loot at your feet (name, line, TAKE); the merchant's name in its colour; REST AT THE SHRINE / REST AGAIN;
    SERVICE DOOR; YOUR SALVAGE; and THE LIFT.
  - First-time tips for the shrine, merchants, the boss gate and your salvage, once per player (`user://us_tips.json`).
    They time out after 9 s, and the Tips setting still turns them off.
  - The results card shows while the lift goes down.
- **Sim:**
  - `level_done()` ports `usLevelDone`: the level's `[level, kills, seconds, found]` line in `us.log` (which the card and
    G5's rewards read), `us.regions`, the CLEARED toast, and downed players riding down at 25%.
  - The lift needs at least one living player.
- **Tests:**
  - `understrip_sim_test` also checks the level log and the graffiti hash.
  - New `tests/understrip_props_shot.gd` renders the shrine, a trader, the lift, a chest, loot with salvage and a flare,
    a loot prompt, the results card and the five tracers. It turns tips on in memory only and deletes the tips file it
    creates.

Not ported, because it belongs with G3: Shelter 7's and Area 67's own floors, walls, hazards and lamp timings
(`usRegGround`, `usLampOn`), and the Visitor's lights-out.

## G3 (Claude, November 4, night)

A whole solo run now plays through to OUT OF AREA 67. New file `scripts/us_deep.gd` (`UsDeep`) ports 10k and the
deeper half of 10i:
- **Hazards:** the hazard map, vents, blast doors, tanks and lamp timers come with every layout (`haz_lay`).
  - Shelter 7: radiation floors, and gas vents that hiss for 2 s and then leak for 6 s.
  - Area 67: acid floors and low-gravity floors (bullets and lobs slow to 60% over them).
  - Lamps follow `usLampOn`: Shelter 7's tubes flicker; Area 67's lights fail on its second level.
- **Area 67's alarms and drones:** the first raider to start hunting in a room trips its alarm; 3 s later a drone pack
  comes (4-6, at most 12 alive). Drones fly their own path to you, sting on touch, and take double damage in your light.
  Rooms keep their waiting drones too. Resting clears the alarms.
- **Bosses**, each at the browser's health (BOSS_HP 1.25, +35% a player), with their stage changes, telegraphs and floor
  effects (`us.bfx`):
  - the Custodian: mop arc with live water, blast doors on their rhythm, then crush lanes, gas quarters and a ceiling
    turret;
  - the Gatekeeper: rockets, shield (blocks front shots like a shieldbearer's), stomp, ground pound. At half health the
    pilot ejects as a second body with a sidearm and dodge; downing either one ends the fight;
  - the Visitor: psychic rings, tank throws with acid. At half health the lights go out, and it blinks, calls drone
    swarms and casts gravity wells. Under 10% it gets desperate (every cooldown x0.7).
  - Down: each boss's message, a drop for each player plus the boss's own (tie-pin, flare launcher, anti-grav launcher,
    the Visitor's Eye). The floor clears, the doors open, the drones drop.
  - Squad wipe: the boss and what he called go, and he starts again.
- **Fix:** the Pit Boss's health now uses the browser's formula (x BOSS_HP 1.25). Solo he has 1,200, not 960;
  `understrip_sim_test` was updated.
- **3D:**
  - each region's floors, hazard floors and details, wall colours and paint (Shelter 7's orange band, Area 67's
    growth);
  - specimen tanks; low gas clouds;
  - blast doors and the boss gate in their own colours, with an amber warning before a door slams;
  - every telegraph and floor effect (see-through layer `haze`);
  - drones as hovering lenses;
  - the library's Custodian (`Equipment_Damage` shows in stage 2), Gatekeeper (`Equipment_Pilot` hides once the pilot
    is out), the pilot (`enemy:gatekeeper_pilot`) and the Visitor, with their Tell/Execute/Recover clips by state.
  - Light: the Custodian's red, and the Visitor's blackout (no lamps or neon, darker).
  - Labels: GAS, DOOR, TURRET, SHIELD, and the stage changes. The boss bars show each stage, and the pilot has his own
    bar.
  - Each level opens with the browser's line (a new region's dangers, or the boss waiting past the gate).
- **Tests:**
  - New `understrip_deep_test` (34 checks): the layouts, radiation, vents, drones and light, each boss through his stages
    to his drop, and the last lift to the win.
  - New `understrip_deep_shot.gd` renders Shelter 7, each boss in both stages, and Area 67's drones.
  - All seven suites pass.
- **Build:** a Windows build of this worktree is at `Documents\Palisade\Understrip Test Build\Palisade.exe`. The 4.7.2
  export templates are installed in `%APPDATA%\Godot\export_templates`.

Not ported: Area 67's ambient hum (`usAmbience`), and the regions' raider uniforms (`usLook`; the 3D raiders use the
library's models).

## G4 and G5, and Area 67's music (Claude, November 4, late)

- **Area 67 and the regions' sound** (`pal_audio.gd`): the mode routes music as `usMusicRoute` does.
  - Outside a boss fight, the casino upstairs plays through the concrete: low-passed at 650 Hz in the Flood Tunnels,
    and at 420 Hz with a reverb tail in Shelter 7, on a new `Music` bus.
  - Each boss fight has its own track: express, attitude, cool, then the finale.
  - In Area 67 the music cuts out and the low hum plays (`usAmbience`: 55 Hz and a drifting 82.6 Hz, low-passed).
  - `music_test` checks the routes.
- **Still not ported:** the regions' raider uniforms (`usLook`). The 3D raiders share one merged material per model, so
  Shelter 7's olive and Area 67's white need uniform variants of the raider models from the library (a Blender task).
- **G5, the rewards** (`pal_locker.gd`):
  - The claim counts the levels finished (the run log) and sends `cv:6` with the map `understrip`, as the browser's
    `runClaim` does; the server counts the regions.
  - With no account, the local pay is `US_PAY` [1,3,6] a region plus `US_WINPAY` 10 for the finish (cases, skill
    points, shards ×2). A finish under 15 minutes isn't a win.
  - The reward text says "for the regions cleared" and "more levels".
  - Drafts and best runs count levels.
  - `tests/locker_ref.json` gains four Understrip runs, generated by the browser's own `localRun` (bench
    `locker_ref_ff.js`); the eight older entries are unchanged. `client_test` matches all four.
- **G4, online** (yard-31; `scripts/us_net.gd`, `pal_net.gd`):
  - The browser's fields are appended at the ends of the rows. Enemy codes `boss:pitboss` … `drone` are added.
  - The start message carries `us` [seed, level, lives]; the snapshot carries `us`; player rows carry `us` bits and the
    `usk` kit; raider rows carry `el`, `est` and `ub`.
  - The host takes guests' `ud ui uu ub uw ut`; a guest's buttons, the trade screen and the keeper's upgrades send
    them. A guest follows the host's lift with `change_level(n, true)`.
  - The online room picker offers the mode.
  - **Fixed in passing:** `_send_events` halved oversized messages through a lambda that called itself, which GDScript
    can't do, so any batch over 12 KB crashed. It's now `_split_events`.
- **Cross-play check** (bench `understrip_cross.js` with `cross_game_driver.gd` roles `ushost` / `usguest`; Chromium, as
  `tests/cross_game.js`):
  - **Godot hosts, the browser joins:** 14/14. The same tunnels from the seed, the drink, loot taken into the kit, drones
    and an elite, the lift down to level 2; no errors on either side.
  - **The browser hosts, Godot joins:** fails at connecting, as does the original co-op join on this PC. The WebRTC
    plugin's DTLS handshake fails ("SSL - The requested feature is not available") when Godot calls a current browser
    (Chrome 157, Firefox). Godot to Godot (`net_test`) works. The earlier passing runs used an older Chromium. Not
    caused by this work; until it's fixed, a desktop player can't join a browser-hosted room.

G3 (the deeper bosses, using the library's Custodian, Gatekeeper, Pilot and Visitor), G4 (yard-31) and G5 (claims,
build) are unchanged.
