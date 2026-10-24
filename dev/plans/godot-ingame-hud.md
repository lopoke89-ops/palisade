# Godot in-game HUD: matching the browser

**Written October 24, 2026 (Stage 9).** Nothing here is built yet. This is the plan; each stage below needs its own go-ahead.

## Why

The Stage 8 Windows playtest ran smoothly. Its one complaint was the in-game UI: it isn't as detailed as the browser's.

The menus, the pause menu, the armory, the skill tree and the after-action screen already match. They're the ported pages in `menu_pages.gd` / `menus.gd`, built from `UiKit` controls in the browser's styles.

The gap is the live HUD over the game: everything `main.gd` draws in `_draw_hud()`. The browser builds that layer from HTML (`dev/src/page.html` `#top`, `#kit`, `#keys`, `#tip`, `#toast`, `#chat`) styled by `dev/src/style.css`, and drives it from `hud()` in `11-hud-chat.js`. Godot paints a simpler stand-in on a canvas.

## What's different

Compared side by side at 1600×900, in the same moments: build phase, a raid, a boss, Black Out, Base Battle, Free-for-all, down, paused, after action.

| Part | Browser | Godot now |
|---|---|---|
| Fonts | Big Shoulders Stencil (800/900) for labels, IBM Plex Mono for numbers and text. | Godot's default sans (`ThemeDB.fallback_font`) everywhere in the HUD. The fonts are in `godot/fonts`; the menus use them, the HUD doesn't. |
| Phase | A box at the top right: a big stencil label (BUILD, RAID 1/5 in rust, EVACUATE in green), the clock or raiders left under it, the raid count, a pause button (II) and a chat button online. | One line of small text in a dark full-width top bar. |
| Core / stake | A labelled meter (CORE, STAKE or COMMAND) with its number, flashing when hit or under 30%. Base Battle adds an ENEMY meter, in team colours. | An unlabelled bar at the top right; two thin bars in Base Battle. |
| Delgado | A command chip under the meter (DELGADO · FOLLOW), clickable. | A text line in the bottom-left panel. |
| Salvage, start | SALVAGE n, and a START RAID / START NOW / START BATTLE button with its key cap, clickable. | In the bottom panel text, and "(ENTER: start now)" in the top line. |
| Build kit | A column at the right edge, all clickable: BUILD ON/OFF (B); WALL / DOOR (F); WOOD, BRICK, METAL with key caps, counts and locked "R2"/"R4"; a big yellow PLACE button (what Space does, its cost, or why not); ARMORY (pulses when you can afford something); NADE; ROLL; SPRINT; ROCKET or STEALTH. Each shows its count or cooldown (READY, 3s, GO) and dims when empty. | A bottom-left panel: a health bar (the browser moved health to nameplates in v0.9.9), material counts, "NADES 2 · RKT 5", "PIECE: WALL (F)", the sprint or stealth cooldown as text. No roll state (only the touch buttons show it), nothing clickable. |
| Build target | A dashed yellow outline on the tile. | A filled green tile and a floating "PLACE · 4 WOOD" label. |
| Key bar | A bar along the bottom with every key in key caps, following your bindings (move, aim, grenade, rocket, roll, build, material, door, build kit, armory, start, pause). With a controller it shows the pad's buttons instead (`padBar`). | None. |
| Tip | A boxed hint under the phase box, with a warning-coloured edge ("Walk next to a wood pile to gather…"). | None (only the opening GOOD LUCK message). |
| Banners | Framed banners at the top centre in the stencil font, with coloured rules for threat, good and bad news (RAID 1 OF 5, a boss's name and what it does). They queue and avoid the boss bars and mini-map. | Plain centred text. |
| Boss bars | A framed strip per boss, stacked: the name, WEAK: (element), a percentage, the boss colour, ENRAGED. | One bar, the name only. |
| Kill feed | Stencil lines with a coloured edge at the top right, beside the Black Out mini-map. | Small text lines. |
| Free-for-all | A leaderboard list under the phase box. | Names and kills squeezed into the top line. |
| Black Out | The phase from `boHudPhase` (POI stages, holds), the mini-map in a framed box under the phase box, fading under banners. | The mini-map top right, phase text in the top line. |
| Chat | A chat log and, open, a bar with SEND and quick lines (NICE, HELP!, ON MY WAY, WALL DOWN, NEED MATS, GG). | Chat lines at the bottom left and an input box. |
| Free-for-all respawn | NEXT LIFE AS: a class picker while you're down (also in the pause menu). | Missing. |
| Pause menu | SETTINGS, FRIENDS, ABANDON THE CLAIM. | SETTINGS, RESTART, SKILL TREE, INDEX, ABANDON THE CLAIM. No FRIENDS. (Minor; keep or match, your call.) |

Already the same: nameplates with health over heads, the E ARMORY prompt, the crosshair, edge arrows, floating text and the boss warnings drawn on the ground.

## How

1. **Rebuild the HUD as controls, not paint.** A new `godot/scripts/hud.gd`: a `Control` layer built with `UiKit`, the toolkit the menus already use to match `style.css`. Its parts mirror the browser's elements one for one (`#top .phase`, `#kit`, `#keys`, `#tip`, `#toast`, `#feed`, `#board`, `#chat`), with the same sizes, gaps, colours and fonts, read from `style.css`.
   - It updates from the sim each frame as `hud()` does: the same labels, states (`sel`, `empty`, `on`, `locked`, `far`, `pulse`, `alarm`) and texts.
2. **Clickable like the browser.** The kit buttons, START, the Delgado chip, pause and chat call the same actions as their keys. That's also what touch uses in the browser (one kit for both). The painted touch buttons (`_draw_touch`) fold into it.
3. **World-anchored parts stay painted** in `ui_layer`: nameplates, the build-target outline (switched to the browser's dashed yellow diamond), prompts, floating text, the crosshair, edge arrows and boss warnings.
4. **Layout rules from the browser:** the tip under the phase box; banners placed clear of the boss bars and the mini-map (`toastPlace`); the mini-map under the phase box, fading under banners; the kit column's portrait-phone layout.
5. **No change to the sim, the network or crossplay.** Display only.
6. **Checks:**
   - A new screenshot test, `tests/hud_shot.gd`, in the style of `lobby3d_shot`. It measures each HUD box against the browser's own boxes, read from the DOM by a Playwright script, at 1600×900 and 1280×720, within a few pixels.
   - `client_test` checks for each state: cooldown texts, locked materials, PLACE / why-not, armory pulse, buttons doing what their keys do.
   - All seven suites, `cross_game.js`, then a fresh Windows build for your playtest.

## Stages

Each is one milestone: build it, check it against the browser, save it, stop.

- **H1: foundation and the phase box.**
  - `hud.gd`, the fonts, and the top-right phase box: label, clock or raiders left, raid count, CORE / STAKE / COMMAND and ENEMY meters with numbers and alarm, the Delgado chip, salvage, START with key cap, the pause and chat buttons.
  - The tip box.
  - The old top bar goes.
- **H2: the build kit.**
  - The right-hand column, every button with its state, count and cooldown, clickable: BUILD ON/OFF, WALL / DOOR, materials, PLACE, ARMORY, NADE, ROLL, SPRINT, ROCKET / STEALTH.
  - The dashed target outline.
  - The bottom-left panel and the floating PLACE label go.
- **H3: messages.**
  - The key bar (keyboard bindings, and controller buttons in pad mode).
  - The browser's banners with their colours, queue and placement.
  - Stacked boss bars with weakness, percent and ENRAGED.
  - The kill feed's style.
  - The Free-for-all board.
- **H4: modes and touch.**
  - Black Out (phase stages, framed mini-map, fading).
  - Final Blitz, Gauntlet and evac labels; the casino's HUD (`casHud`).
  - The respawn class picker; the chat log and bar with quick lines; down and spectating states.
  - Touch on phone sizes, through the same kit.

H1 and H2 together fix most of what you'll notice. H3 and H4 finish it.

## Open questions

- Pause menu: keep Godot's extra RESTART / SKILL TREE / INDEX, or match the browser (and add FRIENDS)?
- Godot's opening GOOD LUCK message: keep it, or use the browser's tip box only?
