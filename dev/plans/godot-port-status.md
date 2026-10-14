# Godot port: status against the blueprint

**As of October 14, 2026.** Branch `claude/nice-brahmagupta-dm3mx6`, folder `godot/`, Godot 4.7.2. Baseline: browser v0.10.9 (`4c26769`, protocol `yard-29`).

- The plan this tracks is `dev/plans/godot-conversion-blueprint.md`.
- How to run and test the build is in `godot/README.md`.

## The short version

The Godot build plays every solo co-op game the browser has:
- all four classes;
- all six co-op modes: 5 raids, 10 raids, Endless, Blitzkrieg Rush, Operation Whiteout and City Black Out;
- all four maps at both sizes, and the city;
- three difficulties and 20 modifiers;
- Delgado, every raider type and all 16 bosses;
- the armory, the skill tree, sound and music.

The rules are ported from the browser code and checked against it by 177 automated tests. Map layouts are compared with the browser's tile for tile.

Still to do:
- menus and settings (the next game is set up with keys on the pause screen for now);
- controller, touch and remapping;
- lighting and night;
- cosmetics;
- accounts;
- online play;
- the casino;
- a Windows build for Steam or Epic.

| Status | Blueprint items |
|---|---|
| Done (for solo play) | 24 |
| Partly done | 16 |
| Not started | 37 |
| Measured, not finished | 1 (performance) |
| Not a client job | 2 (PAL-064 trust rules and PAL-080 SLIM's wallet live on the server) |

Nobody has played it by hand yet. It has been checked by:
- the tests;
- a bot that plays a full five-raid game, shopping and firing rockets, and wins, and bot games on Riverbend, Quarry, Frostpeak and the XL Yard;
- still frames rendered in the container.

The sounds have never been listened to, because the container has no speakers.

## Feature by feature

**Done** means it matches the browser for solo play on the Yard. **Partly** says what is missing.

### Core game

| ID | Feature | Status | What's in, what's missing |
|---|---|---|---|
| PAL-001 | Startup and assembly | Partly | The project boots straight into a game. No boot sequence or catalog resources yet. |
| PAL-002 | Classes and tuning | Done | All four classes, the three materials, the formulas, the difficulty table. Chosen with C on the pause screen until the menus. |
| PAL-003 | Match state | Partly | Solo phases, timers and the raid loop. No roster or match id (needed online). |
| PAL-004 | Co-op 5 / 10 / Endless | Done | Raid mix and scaling, Endless's climb and day/night cycle, golden hour and night raids (the night itself isn't drawn yet), bosses, build timers, salvage. |
| PAL-005 | Base Battle and Free-for-all | Not started | |
| PAL-006 | Blitzkrieg Rush | Done | 15 raids, Blitz bosses, the five-minute Final Blitz, the evac ring. |
| PAL-007 | Operation Whiteout | Done | Four chapters across four maps, the winter boss order, map evacs (stake damage carries, resources open, a failed evac ends it), the Whiteout Gauntlet. Solo rules: the left-behind rules for a crew come with online. |
| PAL-008 | City Black Out | Done | The 64x64 city, eight POIs with their perks, attacks from the nearest edge, holding and losing, READY UP, the final push, the Supreme Destroyer, the mini-map. Missing: the lamp light pools (with lighting). |
| PAL-009 | Co-op maps | Done | The Yard, Riverbend, Ashfall Quarry and Frostpeak at standard and XL size, tile for tile. Missing: each map's own scenery outside the fence. |
| PAL-010 | PvP maps | Not started | |
| PAL-011 | Height levels, ramps and stairs | Done | Frostpeak's terraces in movement, pathing, bullets, blasts, aiming and drawing. |
| PAL-012 | Terrain changes | Done | Fire spreading, frost fields, rock slabs, debris, water and wading, floods, bridges (rammed by the Ferryman), pits from cracked ground, burning drums. |
| PAL-013 | Movement, collision, pathing | Done | Flow-field pathing, wall sliding, doors open for the crew. |
| PAL-014 | Aim and targeting | Partly | Mouse aim. Missing: aim assist, aiming at a body rather than the ground, the touch lock-on. |
| PAL-015 | Building and destruction | Done | Place, upgrade, repair, doors, costs, cooldowns, refusal messages, salvage from ruins. |
| PAL-016 | Gathering | Done | Yields, caps, regrowth, kiln and scrap unlocks, dropped packs. |
| PAL-017 | Soldier | Done | The burst carbine (3/5/7/9/9 rounds) and rockets. |
| PAL-018 | Sniper | Done | The piercing bolt rifle, two ammo slots, stealth. |
| PAL-019 | Grenadier | Done | The pump shotgun loaded a shell at a time, extra grenades, Molotovs. |
| PAL-020 | Quartermaster | Done | Bigger packs, cheap stake repairs, sprint, patching up Delgado by touch, the SMG. |
| PAL-021 | Armory, stake repair, Delgado's level | Done | All levels at the browser's prices and steps. |
| PAL-022 | Special ammo | Done | All four types with their ranks. The Soldier's single slot (the Sniper's two come with the Sniper). |
| PAL-023 | Skill tree | Partly | All 19 nodes, costs, gates and perks. Points are earned by the server's rule but saved locally. Reset is free; the browser charges 40 shards. |
| PAL-024 | Modifiers | Done | All 20, with the browser's mode rules (which ones Blitz and the campaign allow). Chosen in code until the setup menu. |
| PAL-025 | Abilities and sprint | Done | Soldier rockets, Sniper stealth, Molotovs, Quartermaster sprint. |
| PAL-026 | Raiders | Done | All seven types, with their AI. |
| PAL-027 | Bosses | Done | All 16, with every attack and warning, each in its mode. Missing: the October Pumpkin Butcher look. |
| PAL-028 | Delgado | Done | Defend or follow; builds his ring of walls safely; gathers; repairs and puts out fires; revives you; hands over materials; restocks grenades; his shotgun and levels. |
| PAL-029 | Damage, going down, revives | Done | Solo rules. PvP's spawn protection comes with PvP. |
| PAL-030 | Dead End and results | Partly | The dead-end check is in. A simple win/lose screen with the end reason, stats and skill points. Missing: the browser's full results screen. |

### Presentation

| ID | Feature | Status | What's in, what's missing |
|---|---|---|---|
| PAL-031 | Camera and zoom | Partly | The browser's projection, follow and shake. Missing: the zoom setting, spectating, the casino offset. |
| PAL-032 | Draw order and see-through walls | Partly | The browser's draw order. Missing: walls fading when you stand behind them. |
| PAL-033 | Lighting and weather | Not started | No day, dusk or night (the browser's raid 5 is at night), no storm. |
| PAL-034 | Characters | Partly | A cut-down figure with each raider's and boss's look and weapon. The full figure with wardrobe items is not ported. |
| PAL-035 | Tracers, auras, kill effects | Not started | Plain tracers and particles only. |
| PAL-036 | Backgrounds | Not started | |
| PAL-037 | Cosmetics catalog (374 items) | Not started | |
| PAL-038 | Main menu, setup, lobby | Not started | The game starts straight into a match. |
| PAL-039 | Index and help | Not started | |
| PAL-040 | HUD and nameplates | Partly | Top bar, stake bar, boss bar, kit panel, Delgado status, build hints, the Final Blitz, map evac and Gauntlet clocks, the Black Out phase and mini-map. Missing: nameplates, off-screen arrows. |
| PAL-041 | Settings | Not started | Volume and music levels are fixed at the browser's defaults. |
| PAL-042 | Keyboard and mouse | Done | The browser's keys (WASD, Space, 1-3, F, G, Q, E, H, Enter, Esc/P, K). No remapping yet. |
| PAL-043 | Touch | Not started | |
| PAL-044 | Controller | Not started | |
| PAL-045 | Overlays and focus | Partly | Pause, armory and skill tree screens. |
| PAL-046 | Chat and messages | Partly | Messages and floating text. No chat (that comes with online). |
| PAL-049 | Music | Partly | 5 of 7 tracks routed (build, three raid tracks, results). Missing: the menu and finale tracks, and the casino's 11-track shuffle. |
| PAL-050 | Sound effects | Partly | 49 of the browser's synth recipes, with distance, wall muffling and voice limits. Missing: tracer, kill-effect, UI and casino sounds. |

### Accounts, online, casino, release

| ID | Feature | Status | What's in, what's missing |
|---|---|---|---|
| PAL-047 | Locker | Not started | |
| PAL-048 | Cases | Not started | |
| PAL-051 | Startup and offline | Not started | |
| PAL-052 | Pause and focus | Partly | Solo pause. Online play keeps running in the browser; not built yet. |
| PAL-053 | Errors and recovery | Not started | |
| PAL-054 | Local saves | Partly | The skill-tree profile only. |
| PAL-055 to 060 | Sign-in, cloud locker, reward claims, friends, invites, hosting and joining | Not started | Same Supabase project and accounts as the browser, so progress carries over. |
| PAL-061 to 063 | Network protocol, host checks, rejoining | Not started | The plan is cross-play with the browser through PeerJS/WebRTC. |
| PAL-065 to 075 | Casino floor and all seven games | Not started | The game servers already exist; only the Godot screens are missing. |
| PAL-076 | Performance | Measured | The ground and the city's buildings are painted once into chunks that Godot culls off screen. A city frame costs about 3.6 ms of drawing and a crowded final push about 3 ms of sim, on the container's CPU. Still to measure on a real PC. |
| PAL-077 | Accessibility | Not started | |
| PAL-078 | Build and release | Partly | Project, tests and render checks run headless. Missing: the Windows .exe (export templates about 1 GB), code signing, Steam or Epic integration. |
| PAL-079 | Casino relay client | Not started | |

## Where the Godot build knowingly differs from the browser today

1. **Skill points:** they are saved on the player's PC, not the account, until accounts are ported. Reset is free.
2. **Game setup:** with no menus yet, the next game's class, map, size, mode and difficulty are picked with keys on the pause screen. Modifiers can only be set in code.
3. **Warning drawings:**
   - These are exact ports of the browser drawing: the Demolisher, Butcher and Stormcaller, the new moves (Thunderstrike to Overdrive), the Foreman, winter, and the Destroyer's rockets.
   - These follow the browser's colours and shapes, but I didn't port their exact drawing code: the Blitz variants' own warnings and the Destroyer's other attacks.
4. **Characters:** a simplified figure, no wardrobe.
5. **No night:** night raids, the Quarry and the city are dark in the browser. Here the rules know it's night (the raid announcement says so), but nothing is drawn darker yet.
6. **Sound noise:** each effect's noise is fixed when it's rendered. The browser picks a new noise each time it plays.
7. **Precision:** in the sim, directions are 32-bit (Godot's `Vector2`); positions and timers are 64-bit as in the browser. This matters only for cross-play, where the host's numbers win anyway.

## Suggested order for the rest

The order follows the blueprint's phases, aimed at a Windows release on Steam or Epic with browser cross-play:

1. **Presentation:** night and lighting, storm, the fence and trees, see-through walls, the full character figure, tracers and nameplates.
2. **Menus and settings:** main menu, game setup (mode, map, size, class, difficulty, modifiers), settings saved between runs, the results screen, help.
3. **Input:** controller, touch, remapping.
4. **The Windows .exe.**
5. **Accounts:** sign-in, cloud locker, reward claims and the skill tree on the server.
6. **Online:** the PeerJS cross-play probe first, then hosting, joining, the snapshot protocol, rejoining, PvP and chat.
7. **The casino:** the relay client, the floor and the seven games. The servers already exist.
8. **Cosmetics:** locker, cases and the full wardrobe.
9. **Release:** accessibility, performance on real hardware, signing, and the Steam or Epic store build.
