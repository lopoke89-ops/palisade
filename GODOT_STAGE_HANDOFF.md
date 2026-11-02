# Godot stage handoff

**Repository:** `lopoke89-ops/palisade`. **Working branch:** `claude/palisade-godot-milestones-ggzdpn`.

## Recovery references
- Starting point: `origin/claude/nice-brahmagupta-dm3mx6` at `b59291f`, from the previous session. It holds the 3D game, the browser-style menu shell, PLAY, Locker and armory, and the test fix. It was merged into the working branch as `6c449c8`, with an identical tree.
- Model library art in `godot/palisade_art/` is pinned to library commit `7554023` (branch `weapons-v1`). The 423 files came from the previous session and were already public on its branch. This stage adds no library files.
- Lost from the previous session: the menu agent's edits after its 02:31 UTC commit, which were never committed. They were small: a scroll gutter, a name-label tweak and screenshot timing.

## Completed milestones
- **Stage 1: the hub menu matches the browser.**
  - **Background:** the painted lobby background (the equipped one, as the browser draws it) now sits behind every menu page. The 3D terrain environment is no longer shown.
  - **Characters:** `lobby3d.gd` stands the 3D crew on the browser's own stage spots, scales and turn angles (`Menus.STAGE2D`), fitted into each page's hero box. They hold the weapon forward (`Aim_Loop`). Pads are drawn in the browser's colours, and the Locker lifts the player as the browser does.
  - **Overlay:** `Menus.Hero2D` draws the empty spots' "+" and the others' name plates.
  - **Locker:** the case buttons stay full-strength when they can't be pressed, as in the browser. OPEN and OPEN 5 use the browser's 23 px size in equal columns.
  - **Removed:** `lobby_layout.gd`, the captured Blender cameras, which are no longer used.

- **Stage 2: display settings.** Settings › WINDOW now has:
  - DISPLAY MODE: windowed, fullscreen (borderless) or exclusive.
  - WINDOW SIZE: 16:9 sizes that fit the screen. The window is centred, and greyed out in fullscreen.
  - VSync.
  - FPS LIMIT: off, 60, 120, 144 or 240, used while the browser's FRAME RATE is on AUTO; FRAME RATE 30 or 60 still wins.
  - The settings are kept in `user://settings.json` as `windowMode`, `winSize` and `fpsCap`. The old `fullscreen: true` carries over.
  - The save backup leaves them out, so its code stays the browser's.
  - A size you drag the window to isn't undone when another setting changes.

- **Stage 3: graphics settings.** A GRAPHICS card in Settings (in the menus and from the pause menu) has:
  - The 3D models switch. F9 still switches them in a game.
  - QUALITY LOW / MEDIUM / HIGH, the existing `Quality3D` presets.
  - RENDER SCALE, 50–100%.
  - These are kept in `gfx3d` / `models3d`. Builds without the model library say the world is 2D.
  - Fixed: turning the 3D models back on from Settings did nothing, because `apply_settings` only rebuilt the 3D view when it already existed. It now always calls `setup_3d()`, which is idempotent.

- **Stage 4: Windows build and integration check.** No game code changed.
  - `tools/export_windows.sh` exports `export/palisade/Palisade.exe` (318 MB, pack embedded, 423 art files) with the WebRTC DLL beside it. The export log has no errors.
  - New `tools/check_export.gd` checks a build from its own pack.
  - `display_shot.gd.uid`, missing from Stage 2, is added.

- **Stage 5: animated skins have their effects.** The 3D models were still and lost the browser's skin effects; they are back in the menus, the Locker and games.
  - The 30 aura skins have their auras, drawn by the browser's own code at each person's feet.
  - The eight glow skins (ghost, galaxy, cyber, phantom, storm 1–4) have their glowing ground rings.
  - Galaxy (stars), Holo (colour bands) and the gold clown, police and knight (glitter) move again, through a shader over the body. Reduce motion holds them still.
  - On the stage, your aura moves and the others' hold still, as in the browser.
  - Fixed on the way: going into a game and back to the menu crashed once the stage had its aura layer (`menus.close()` freed it).

- **Stage 6: THE CASINO opens an online room.** ENTER THE CASINO now does what the browser's `casEnter` does:
  - It opens a casino lobby on the relay and walks straight in (`autoCasino`). The crew drops in by the `R…` code or an invitation.
  - Hosting a lobby already: everyone in it comes too. In someone else's room: "Leave your current crew first".
  - The button is disabled without an account that can play, as in the browser.
  - `PalNet.host_room(casino)` hosts on the relay. It takes the relay's code and incarnation (casino room `R:code:incarnation`), and re-sends a full snapshot or the lobby when a guest's socket resumes.
  - Fixed: someone dropping into a Godot-hosted casino spawned off the map. `respawn_at` lacked the browser's casino branch (`CAS.spawn`); one sim line.
  - The local casino with no room is now `casino_alone()`, used by the offline screenshot tests.
  - Fixed: `Hero2D` drew at font size 0 while the page was still laying out (a logged error).

- **Stage 7: rolling any way, in the browser and in Godot.** Moving, the roll goes the way you're moving (keys, touch stick or controller). Standing still, it is the back roll, straight back from the aim, as before.
  - Browser (`dev/src`):
    - `moveIntent()` is shared by walking and `localRoll`.
    - A guest works out which way someone else rolls from their travel (`rollSeen`), and the 2D tumble turns the way the roll goes.
    - The binding's label is ROLL.
  - Godot:
    - `Sim.move_in` and `local_roll` do the same, with `Sim.roll_seen` on guests.
    - In 3D, `Dodge_Forward_IP` faces the roll. Within 60° of straight back it stays `Dodge_Backward_IP`, facing the aim.
    - The help text and binding say ROLL.
  - The protocol is unchanged (`yard-30`): guests already sent a unit direction in `dg` and the host already took any direction. An older client still in a cached tab would draw someone's forward roll as a back roll, though they travel the right way.
  - The published browser build at the repo root is not rebuilt (`dev/build.py` is a release step), and the shown version stays v0.11.0.

- **Stage 8: a fresh Windows build with Stages 5–7.** `export/palisade/Palisade.exe` (318 MB, pack embedded) and the WebRTC DLL, exported with `tools/export_windows.sh`. The export log has no errors.
  - `tools/check_export.gd` now also checks the animated skins' effects, a forward roll while moving, the back roll standing still, and the casino floor, all from the pack.
  - The build is delivered as `Palisade-windows.zip` (240 MB), attached in the chat, not published anywhere.

- **Website v0.11.1 (asked for with Stage 8): published.** `main` was fast-forwarded from `a0fd0ae` to `f13c745`, with your approval. GitHub Pages serves v0.11.1 (cache `palisade-9185e10db3`). The release is two commits, in the same shape as v0.11.0:
  - `8078859`: the Stage 7 browser source, and the footer set to v0.11.1.
  - `f13c745`: the site build (`index.html`, `sw.js`; minified, cache `palisade-9185e10db3`).
  - It carries only the browser files. Merging this branch would also bring the 423 model-library files and Stages 1–6's Godot work onto the public site.
  - This branch doesn't carry the footer bump or the site build; they're on `main` only.
- Browser suite on that build: 105/109 on the first run. `back_roll` failed once on its unchanged still-roll check under parallel load, then passed four times. The three `casino_relay_*` tests lacked `dev/render/node_modules` in the scratch checkout and pass with it. So 109/109.

- **Stage 9: playtest results and an in-game HUD plan.**
  - Your playtest of the Stage 8 build on Windows ran smoothly, so no performance tuning was needed.
  - Your one complaint was the in-game UI: not as detailed as the browser's. As you asked, it's planned, not changed. `dev/plans/godot-ingame-hud.md` lists every difference and proposes four stages (H1–H4).
  - No game code changed.

- **Stage 10 (HUD H1): the phase box and tip, built as the browser builds them.** `scripts/hud.gd` replaces the painted top bar with controls in the browser's fonts, sizes and colours (`#top .phase`, `#tip`, `style.css` desktop rules):
  - **Phase box:** the label (BUILD, RAID 1/5 in rust, EVACUATE in green), its clock, and the round-message line.
  - **Meters:** CORE / STAKE / COMMAND and ENEMY, turning rust under 30% or when hit.
  - **Controls:** the grey DELGADO · FOLLOW button, SALVAGE, and START RAID / START NOW / START BATTLE / READY with its key cap (controller buttons in pad mode). The pause and chat buttons are there; the chat button lights for unread lines.
  - **Free-for-all:** the board.
  - **Modes:** the casino, Black Out, Final Blitz, Gauntlet and campaign texts are ported from `hud()` / `boHudPhase` / `casHud`.
  - **Buttons:** they work with the mouse and touch. A click on one isn't a shot, and a touch on one doesn't start a stick. Touch's own painted PAUSE and START are gone.
  - **Tip box:** it replaces the GOOD LUCK banner, with the browser's tips at the browser's moments: the opening tip, then after 4 wood gathers, then after 3 builds, gone when the raid starts. Its lines are balanced as `text-wrap: balance` does. The sim gained `game.gathered`, the browser's counter, display only.
  - **Layers:** the armory and the skill tree paint on a new layer over the HUD, as the browser's overlays do. The Black Out mini-map and the kill feed sit under the phase box (`boMapBox`).
  - **Scale:** the HUD keeps CSS pixels up to 1600×900 and scales up past it, so at 1280×720 it is the browser's size, not shrunk.
  - Still painted until H2–H4: the bottom-left panel, banners, boss bar, kill-feed style, chat lines.

- **Stage 11 (HUD H2): the build kit, built as the browser builds it.** The browser's kit column (`#kit`, desktop sizes) replaces the painted bottom-left panel. Every button shows its state and works with mouse and touch:
  - BUILD ON/OFF.
  - WALL / DOOR (F).
  - WOOD / BRICK / METAL: key caps, counts, locked R2/R4, and the picked one's yellow edge.
  - The yellow PLACE button: what Space does and its cost, or grey with why not.
  - ARMORY: faint and dashed away from the stake, pulsing when something's affordable.
  - NADE, SPRINT, ROLL and ROCKET / STEALTH: counts and cooldowns (READY, 3s, GO), fading when empty.
  - Like the browser, the column widens past its right edge when a button needs more room (the Quartermaster's SPRINT SHIFT READY).
  - In pad mode the key caps show controller buttons; on touch they hide.
- **The build-kit switch:** the browser's B / d-pad down, now a Godot action (BUILD KIT) and setting (`build`; the save backup already carried it). Off, Space builds nothing and the ghost hides.
- **The build ghost** is the browser's in 2D and 3D: a dashed outline, yellow or red, with the piece faint where it would go (a door shows its slab). The floating "PLACE · 4 WOOD" label goes.
- **Gone with the panel:** the health bar (health is on the nameplates, as in the browser since v0.9.9), the Delgado line (the phase box's button), the AMMO line (the armory shows it) and DROPS.
- **Touch** uses the kit, as the browser does, so the painted touch buttons that copied it are gone; the thumb sticks stay. A touch on a HUD button isn't a stick.

- **Stage 12 (HUD H3): the key bar, banners, kill feed and boss bars, as the browser's.**
  - **Key bar** (`#keys`): every key this soldier has right now, in key caps, wrapping and centred along the bottom. With a controller, the controller's buttons (`padBar`), following your button changes. Hidden on touch and in the casino.
  - **Banner** (`#toast`):
    - The browser's queue: phase messages before minor ones, three waiting at most.
    - Times of 4.5 s / 3 s × MESSAGE TIME.
    - The coloured bands: orange for threats, green for good news, red for bad.
    - Placement: the top row left of the phase box, at most 640 wide, below the boss bars where they'd meet.
    - Its small text balanced on at most two lines, a fade, and a click to dismiss. Its title stays under the clock.
    - Every banner in Godot goes through it now.
  - **Kill feed** (`#feed`): the browser's tags (stencil, a coloured edge, fading out). They sit inside the phase box, so they widen and lengthen it as in the browser (the tip and the mini-map move with it). In Black Out they sit beside the mini-map.
  - **Boss bars** (painted, as the browser paints them on its canvas):
    - one bar a boss, with WEAK: (in ammo mode) and the percentage;
    - slim rows for three;
    - one shared bar and the nearest boss for four or more.
    - The browser shows no ENRAGED, so Godot doesn't either. The Black Out mini-map steps below them.
  - **Chat:** T opens it online, as in the browser (Enter still does too).

## Verification (Stage 12)
- **New test checks:** `tests/hud_shot.gd` now checks the key bar item by item (keys, words and boxes), the banner, the feed lines and the boss bars' box against the browser's. It covers twelve states at 1600×900 and 1280×720: a phase banner with two feed lines, a minor banner, and one, three and four bosses joined the earlier seven. All are within 5 px.
  - Mono text is laid out at the browser's exact 0.6 em a letter.
  - It also checks the banner queue (a phase message jumps the minor ones), a click dismissing a banner, and the controller's buttons in the key bar and on the kit.
- **Compared by eye** against the browser: the banner, the feed in the phase box, the key bar and a boss bar.
- **Suites:** all seven pass.
  - `tables_test` failed once on "CHECK fails when the seed doesn't match its fingerprint", then passed twice. The test swaps the seed's first character for "f", which changes nothing when it already starts with "f" (about 1 run in 16). Not this stage's, not fixed here.
- **Crossplay:** `cross_game.js` 45/45.
- **Screenshot tests:**
  - `lobby3d_shot` passes, and `menus_shot` passes (then the known abort).
  - `casino_play_shot` and `shot city` render without errors.
  - `shot3d raid` errored 2 runs in 5. The same happens on the Stage 11 commit (1 in 4): its scene assumes a wall survives 22 s of random play. Not this stage's, not fixed here.
- **Not done:** a Windows build of this stage.

## Verification (Stage 11)
- **New test checks:** `tests/hud_shot.gd` now also measures every kit box against the browser's, for build, raid, Black Out, Base Battle, Free-for-all, kit off and a Quartermaster, at 1600×900 and 1280×720. All are within 5 px; the worst is 4.4 px (SALVAGE 40).
  - Layout uses the browser's exact letter-spacing, and the count text's synthetic bold, even where Godot draws to the whole pixel.
  - It also presses BRICK, DOOR, WALL, WOOD, PLACE, and BUILD ON/OFF (off, Space builds nothing). It checks that NADE fades and that ROCKET counts the rockets.
- **Suites:** all seven pass.
- **Crossplay:** `cross_game.js` 45/45.
- **Screenshot tests:**
  - `lobby3d_shot` passes.
  - `menus_shot` passes, then the known abort at exit.
  - `shot3d raid` (3D and 2D), `casino_play_shot` and `shot city` render with no script errors.
- **Compared by eye:** the kit against the browser's for a Soldier and a Quartermaster, and the ghosts in 3D and 2D.
- **Not done:** a Windows build of this stage.

## Verification (Stage 10)
- **New test against the browser:** `tests/hud_shot.gd` measures every box of the phase box and tip against the browser's own (`tests/hud_ref.json`, made by `tests/hud_ref.js` from the built site). It covers build, raid, Black Out, Base Battle and Free-for-all, at 1600×900 and 1280×720.
  - All ten are within 5 px. The largest gap is SALVAGE 40, 4.4 px wider because Godot rounds letter-spacing to whole pixels.
  - It also checks the labels' texts, the core alarm, Delgado's button and START.
- **Suites:** all seven pass.
- **Crossplay:** `cross_game.js` 45/45.
- **Screenshot tests:**
  - `lobby3d_shot` passes.
  - `menus_shot` passes, then the known abort at exit.
  - `shot3d raid`, `casino_play_shot` and `shot city` render with no script errors.
- **Compared by eye** against the browser: build, raid and Black Out side by side, plus Base Battle, Free-for-all, the casino, a Black Out attack and the armory over the HUD.
- **Not done:** a Windows build of this stage.

## Verification (Stage 9)
- The same in-game moments were captured in the browser (built from `dev/src`, Playwright) and in Godot at 1600×900: build phase, raid, boss, armory, skill tree, pause, down, after action, Black Out, Base Battle and Free-for-all. The plan's table comes from comparing them, and from the browser's `hud()` and `style.css`.
- Already matching: the armory, the pause menu, the skill tree and the after-action screen (ported pages). The gap is the live HUD drawn in `main.gd` `_draw_hud()`, which also uses Godot's default font rather than the browser's stencil and mono fonts.
- The screenshots stay in this session's scratch, since they show the private 3D art. They aren't committed.

## Verification (Stage 8)
- `check_export.gd` against the new .exe (Linux Godot, `--main-pack`): 12 of 12 OK. The only errors are the expected missing Linux WebRTC library, no audio device, and the known abort at exit.
- Screenshots from the pack: each hub page, Settings, a raid and the casino floor.
- Not done: running it on Windows itself.

## Verification (Stage 7)
- All seven Godot suites pass. `sim_test` has new checks: moving rolls go 2 tiles the way you move (straight and diagonal), a still roll is the back roll, and a guest infers the direction from travel.
- `dev/test/back_roll.js` passes against a site built into scratch from `dev/src`. A new check rolls while walking: it goes the way you walk, toward the aim, 2 tiles.
- `cross_game.js` 45/45. A Godot host and a browser guest each roll while moving, sideways to their aim. Each side applies the other's roll, and works out its direction.
- `shot3d roll` takes a direction. Renders checked: the back roll faces the aim; south and east rolls play the forward roll facing the way they go.

## Verification (Stage 6)
- All seven suites pass. `casino_play_shot` passes, and `casino_floor_shot` renders the casino.
- `relay_cross.js` 67/67, against a local relay (`dev/render/relay.js`, native clients on, as deployed). New part 4: the real game presses ENTER THE CASINO, opens a relay casino and walks in; a browser joins by its code. Both walk, chat crosses, and the game closes it ("The host closed this casino.").
- `cross_game.js` 43/43 (PeerJS crossplay is unchanged).
- The deployed relay (`palisade-casino-staging.onrender.com/healthz`) reports build `a0fd0ae`, which includes "let in the desktop game". So hosting works against the live relay too (not exercised live).
- Not specifically tested: going from a hosted lobby into the casino. It is the same start as a host picking the casino in the lobby.

## Verification (Stage 5)
- All seven suites pass.
- `lobby3d_shot` passes, with new checks: the body effects are on Galaxy, Holo and the gold skins, on the body but not the face, and not on a plain skin; the gold Soldier's aura and the Galaxy's glow are painted, with the ground part just under the crew.
- It now sets its own class: a crashed `client_test` run had left Sniper in this machine's saved settings.
- `menus_shot` renders all 22 pages with no script errors or crashes, then the known abort at exit. `display_shot` passes.
- Side-by-side against the 2D drawing: gold Soldier, Galaxy, Holo, gold Knight, Butcher III and Storm, on the stage and in a 3D raid.

## Verification (Stage 4)
- `check_export.gd` against the .exe, using Linux Godot with `--main-pack`: 8 of 8 OK. The model library loads from the pack, and the hub, Settings (WINDOW and GRAPHICS), the LOW preset and a 3D raid all come up. Screenshots were taken of each hub page, Settings and the raid. The only errors are the expected missing Linux WebRTC library, no audio device, and the known abort at exit.
- Presentation pass: the hub pages match the browser (see Stage 1). A raid and the Butcher fight, rendered at the same moment in 3D and 2D, line up: same camera, HUD, positions and night light. The figures stay blocky.
- Crossplay with the browser (site built into scratch with `dev/build.py`):
  - `cross_game.js` 43/43: co-op both ways, a Free-for-all hosted by Godot, a Base Battle hosted by the browser. It covers walking, back rolls, walls, raiders, chat and knockdowns.
  - `peer_cross.js` 102/102.
- Not done: running the .exe on Windows itself (no Windows machine here).

## Verification (Stage 3)
- All seven suites pass. `client_test` has new checks: LOW reaches the 3D view (no shadows, 24 tracers, viewport at 75%), HIGH with render scale 60%, the switch going off to 2D and back on through Settings, and the card's rows.
- `lobby3d_shot` and `display_shot` pass.
- `shot3d raid`, same moment: LOW draws softer with no shadows, at about 134 ms per 3D frame against 385 ms for HIGH. This machine draws in software, so only the ratio means anything.
- Card screenshots taken in the menus and in game.

## Verification (Stage 2)
- All seven suites pass. `client_test` has new checks: loading and migrating the settings, falling back on bad values, the sizes offered, the save backup leaving the display settings out, and the FPS limit against FRAME RATE.
- `lobby3d_shot` passes.
- New `tests/display_shot.gd`, run on a real window under xvfb with openbox, passes. It checks window size and centring, a resize by hand surviving, FULLSCREEN, EXCLUSIVE, returning to WINDOWED at the chosen size, the FPS limit, and screenshots of both states.
- Fullscreen on X11 needs a window manager. Under a bare xvfb the fullscreen checks fail.
- Not tested on Windows itself; there it goes through Godot's own window API.

## Verification (Stage 1)
- Godot 4.7.2: `sim_test`, `client_test`, `net_test`, `social_test`, `music_test`, `tables_test` and `relay_test` all pass.
- `lobby3d_shot.gd` passes, including a new check that every figure's feet land within 3 px of their browser spot, at 1600x900 and 1280x720.
- `menus_shot.gd` renders all 22 pages and reports `RESULT PASS`. Godot then aborts at exit (code 134, GL leak messages). The old branch does the same, so this predates Stage 1.
- Godot's hero boxes match the browser's DOM to within 1 px on PLAY, MULTIPLAYER and LOCKER. INDEX is 14 px shorter.
- Not run: the Windows export.

## Remaining issues
- The 3D figures are lit a little darker and flatter than the browser's painted ones.
- The browser's pad glow is not reproduced.
- The library's 78 lobby environments are unused in the menus.
- The 3D game view's performance is unmeasured on real hardware.
- The menus leave the 3D crew loaded during games (from the previous session).

## Proposed next milestone
Stage 13 (HUD H4): the rest of the browser's HUD.
- Black Out: the mini-map's frame and colours, and its fading under banners.
- The casino's HUD.
- The chat log and bar with SEND and the quick lines.
- The Free-for-all respawn class picker.
- The down and spectating states.
- Touch on phone sizes, the browser's non-desktop layout.

Then a Windows build of Stages 10–13 for your playtest.
