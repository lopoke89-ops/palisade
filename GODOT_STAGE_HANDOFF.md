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
Stage 6: THE CASINO opens an online casino room (the relay), as in the browser, instead of a solo room.

Queued after it, as you asked:
- Stage 7: omnidirectional rolling in both the browser and Godot. You roll the way you're looking, and a still roll stays the back roll. It changes the shared sim and the protocol, so both builds move together.
- Your playtest and performance tuning.
