# THE UNDERSTRIP → Godot: port plan

Draft, November 4, 2026. This is the "port sweep" that work order section 15 left for later. It brings the desktop game
(`godot/`) from v0.11.0 up to the browser's v0.12.3, the Understrip included. The browser is the reference; the Godot
side copies it, keeping the function names so the two read side by side (as the rest of the port does).

## 1. Where things stand

| | Browser | Godot |
|---|---|---|
| Version | v0.12.3 (`25e725e`) | v0.11.0 (`6628ddf`) |
| Protocol | yard-31 | yard-30 |
| Understrip | all of it, live | none |

The gap is v0.11.1 and v0.12.0–v0.12.3: about 1,900 changed lines over 39 browser files.
- **Understrip-only files:** 1,689 lines (216 KB of dense JS) in `06g`, `10h`–`10k`, `15b`, `16i`, `18g`, `18h` and `20d`, plus
  `dev/data/understrip/rooms-r1..r3.json`.
- **Hooks in shared files** (about 130 lines):
  - `L.under` spawns and no Delgado;
  - the tunnel terrain kinds in `terrSolid` and `terrShot`;
  - no building in the mode;
  - the HUD's boss bars (the Gatekeeper's pilot);
  - shields from behind (`e.ub&1`);
  - the dark outside;
  - no tile grid underground;
  - `MODE_ZOOM`;
  - boss pools that leave out the mode's bosses (`boPool`).
- **v0.11.1:** the roll goes the way you're moving (`moveIntent`, `rollSeen`). It's small, and the protocol is unchanged.

### What already works, and what doesn't
- **Other modes online:** a yard-30 desktop copy still plays every other mode with a yard-31 browser host. Yard-31 only adds
  fields older copies ignore. An UNDERSTRIP room refuses it.
- **UNDERSTRIP CASES don't show in the desktop locker.** v0.12.3 pays up to 20 a run.
  - The desktop keeps them in the bag (`pal_locker.gd` loads every key), so nothing is lost.
  - It lists only the cases in its catalogue, so they're invisible there and can't be opened.
  - Its opener is `open_cases_v0964` (catalog 4), which the server refuses for catalog-6 cases. It has none of the 30
    items' art either.
  - What the desktop draws for an Understrip item a player wears is untested. G0 checks it first.
  - **G0 deals with this first.**

### Baseline on Big U's PC (November 4, Godot 4.7.2 headless)
- `tests/sim_test.gd`: all passed, in 75 s.
- `tests/client_test.gd`: 55 of 56 checks pass. The miss is "BUY trades 12 shards for a Halloween Case", in 4 runs out of 4.
  - Nothing in `godot/` changed since v0.11.0, so the failure predates this work.
  - A likely cause, not checked: the test expects exactly 18 shards after opening a case, and a duplicate pays shards.
  - Look at it in G0.

### G0 status (November 4, built here, not committed)
- **The roll (v0.11.1):** it goes the way you're moving; standing still, it's the back roll. Guests read other players'
  rolls off their travel. The binding is now ROLL. Four new checks are in `tests/sim_test.gd`.
- **The UNDERSTRIP CASE:**
  - `data/cosmetics.json` was regenerated: the 30 items, the case, 10 skins, 5 tracers, 5 backgrounds, the Visitor's aura,
    5 kill-effect lengths, and the 5 new hats in each skin's allowed list. Nothing else in the file changed.
  - Opening goes through `open_cases_v012`.
  - The 10 skins' models and the 5 hats are in `scripts/us_models.gd`, hooked into the wardrobe where the browser hooks them.
  - The tracers and kill effects are in `scripts/cos_art.gd`; the backgrounds in `scripts/us_scenes.gd`.
- **Checked against the browser:**
  - The wardrobe looks match field for field: all 191, the 15 new ones included.
  - Side-by-side sheets of the new skins, hats, tracers, kill effects and backgrounds match the browser's (the browser
    references were made in Firefox).
- **Tests:** `sim_test` and `client_test` pass.
  - The Halloween check was fixed: the case opened before it can pay shards for a duplicate.
  - The client test checks that the UNDERSTRIP CASE opens through `open_cases_v012`.
- **These are the 2D fallback.** The real desktop models are Blender work (see the correction under section 3).

### The case's 3D models (November 4)
- **Pipeline:** the library's own one, unchanged; the scripts are in `bench`.
  - `benchS_capture.cjs` captures the browser's figures in `rig_source.json`'s format. It's the library's capture with
    one rule adapted for v0.12, and it's byte-identical to the library for std, sahur, tiger and demon.
  - `benchS_upgrade.py` holds the unique models' upgrades.
  - `benchS_rig.py` runs `art/3d/tools/build_character_rigs.py` on them.
- **The 10 skins are signed off by Big U.** All are rigged, with 30 clips each.
  - The 8 base-figure skins are built like usual.
  - The Visitor and the Custodian have their own upgrades:
    - the Visitor: a smooth head, slim arms, long fingers, glossy almond eyes;
    - the Custodian: a glowing cracked lens, vents, rivets, a lamp, a hanging mop.
  - Big U kept the Gunslinger's knees showing through his coat ("it looks like part of his boots"). Revisit it only if
    players say so.
- **Still to make:** the 5 hats, 5 tracers, 5 kill effects and 5 backgrounds; the 4 bosses (from scratch: the 3D game
  needn't follow the browser's look); the models into the library and synced into the game.

## 2. Things the port must match exactly (fixtures)
- **The generator.** `dev/test/understrip_gen.js` writes `dev/test/out/understrip_gen_fixture.json`: seed → level tile hash,
  for every level kind in every region. Godot must give the same hash for every seed. The spec is
  `dev/plans/understrip-generator.md`, and the room kits are data both sides read.
- **Seeded rolls in step on both sides.**
  - The merchant stock is generated from the seed on host and guests, so the order matters: `c_ammo` is last, and
    `usLiftStock` appends last.
  - Loot rolls, weapon tiers and mods, and the case odds.
  - Fixture: a list of (seed, region, source) → item, made by a small Node script, like `maps_ref.json` and `locker_ref.json`.
- **Rewards.**
  - Accounts: the server decides. The desktop sends the claim the browser sends: `mode:'understrip'`, `cv:6`, `raid_from`,
    `raid_to`, `held`, `duration_s`, `win`.
  - No account: `US_PAY` [1,3,6] and `US_WINPAY` 10, as in `18-cosmetics.js`. Copy the pay checks of `understrip_case.js`.
- **Online, yard-31.** The desktop takes either seat with a browser:
  - guest messages `ud ui uu ub uw ut`;
  - the snapshot's `us`;
  - player rows `us` (bits) and `usk` (kit string);
  - raider rows `el`, `est` and `ub`.

  The existing `tests/cross_game.js` and `peer_cross.js` harnesses run it.

## 3. Milestones

Each one ends with its tests passing on this PC (Godot 4.7.2 in `bench\godot`) and a side-by-side screenshot against the browser.

| | What | Browser source | Godot (new or changed) | Proof |
|---|---|---|---|---|
| **G0** | **Catch-up and the case.** v0.11.1's roll. The UNDERSTRIP CASE in the locker: the 30 items in `data/cosmetics.json` (`tools/cos_extract.js`); opening through `open_cases_v012`; the hats, tracers, kill effects and backgrounds through `ctx2d.gd`. The 10 skins' models (`16i`) come in G4; until then a skin shows a placeholder card ("wear it in the browser"). | `08-input`, `09-actions`, `18g`, `18h`, `20d`, `20b` | `pal_input.gd`, `pal_account.gd`, `cos_art.gd`, `backgrounds.gd`, `locker_ui.gd` | `client_test.gd` opens one; the art screenshots |
| **G1** | **The generator and room kits.** Levels built from the seed, the shortcut, the arenas | `06g`, `rooms-r*.json` | `pal_understrip_gen.gd` | Every hash in the fixture matches |
| **G2** | **Region 1 playable, solo.** Tunnels and the low near walls (D17); the darkness, the light cone and glow (a lighting task: Godot has only the night holes in `main._update_light`, so this needs a light layer or shader); the flood; raider AI and the elites; the Pit Boss; shrines, lives, LUCKY BREAK, bleeding out; the merchants, weapons, perks, relics and loot; the HUD | `10h`, `10i` (Pit Boss), `10j`, `15b`, hooks in `12`, `14`, `11`, `17` | `sim.gd` (or `sim_understrip.gd` beside it), `us_view.gd`, `main.gd` | `understrip_m2.js`'s checks as `us_test.gd`; a frame against the browser's |
| **G3** | **Regions 2 and 3 and the finale.** Shelter 7's gas vents; Area 67's alarms and drones; the other three bosses (two stages each); the Visitor's finale; graffiti and neon in region 1 (v0.12.1) | `10i`, `10k`, `15b` | the same files | A whole solo run to OUT OF AREA 67 (`understrip_m3.js` / `understrip_run.js` as tests) |
| **G4** | **Online, and the skins' models.** yard-31 both ways (host and guest with a browser); the 10 skins' models | `21-online`, `10h`'s net part, `16i` | `pal_net.gd`, `peer_net.gd`, `wardrobe.gd`, `figure.gd` | `understrip_network.js` / `understrip_squad.js` as cross-play runs; the four angles of every skin |
| **G5** | **Rewards and release.** Claims with `cv:6`; no-account pay; the PLAY card; the Index; the README's port table; a Windows build | `18-cosmetics`, `19c`, `19e` | `pal_locker.gd`, `menus.gd` | The pay checks; a full run's claim against a disposable Postgres, as `understrip_server.js` does |

**Correction (November 4): the desktop game is 3D, and the case needs new Blender models.**
- The desktop game Big U ships is the unmerged branch `claude/palisade-godot-milestones-ggzdpn` (Stage 13, the Windows
  build). Its 3D view (`scripts/view3d/`) shows every character and cosmetic from the 3D model library
  (`lopoke89-ops/palisade-3d-model-library`, pinned in `godot/palisade_art/LIBRARY.txt`).
- `main`'s 2D painters (`wardrobe.gd`, `cos_art.gd`, `backgrounds.gd`) are only the fallback used when `palisade_art` is
  missing. G0's 2D work is that fallback, not the real models.
- So all 30 case items need Blender models in the library, made to Big U's quality bar, then synced into the game:
  - 10 skins, rigged to the shared humanoid skeleton so they use the library's clips;
  - 5 hats, fitted to HeadSocket;
  - 5 tracer bullets, 5 kill effects and 5 lobby environments.
- The mode's raiders, bosses and tunnel kits (G2, G3) need models too.
- That branch already has v0.11.1's roll (Stage 7), so G0 moves onto it.

## 4. Performance
- The browser's v0.12.2 lesson applies: on the big maps, don't draw what's off the screen. Build it in from G2.
- The darkness layer is the new cost. Measure it on this PC (the push and raid hold 60 FPS today, per `bench\HANDOFF.md`).
- The C++ (GDExtension) plan stays on hold unless the Understrip misses 60.

## 5. Decisions (Big U, November 4, 2026)
- **Who builds it:** this session (Claude, in Big U's clone), asking before each commit.
- **Order:** G0 ships on its own first, then G1–G5.
- **Online:** the first desktop Understrip release includes online play with the browser (G4). So the mode ships on the
  desktop after G5, with G4 in it.

### The questions as they were put
1. **Who builds it:** devilsposterboy's Claude session from this plan (as with the browser version), or this session.
2. **Order:** G0 first, now (it fixes the desktop locker for players who earn the new cases), then G1–G5. Or the whole
   thing in one go.
3. **Online in the first desktop release (G4), or solo first.** Solo first ships sooner; until then a desktop player can't
   join a friend's Understrip room (the server and the browser already refuse it cleanly).
