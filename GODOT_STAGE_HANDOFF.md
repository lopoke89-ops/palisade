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
Graphics settings, 3D quality group: a GRAPHICS card in Settings with the 3D models switch, a LOW / MEDIUM / HIGH preset and render scale, using the existing `Quality3D` knobs (`gfx3d`).
