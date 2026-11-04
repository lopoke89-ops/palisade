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

**Still open for G2:**
- the tunnel view's props are placeholder boxes (shrines, merchants, chests, lift, loot) and the browser's per-region
  look (graffiti, ground detail);
- the browser's tips, prompts and kit or weapon HUD details;
- the tracer `decor` extras in `v3_fx.gd`.

G3 (the deeper bosses, using the library's Custodian, Gatekeeper, Pilot and Visitor), G4 (yard-31) and G5 (claims,
build) are unchanged.
