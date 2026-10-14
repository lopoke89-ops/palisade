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

The rules are ported from the browser code and checked against it by 177 sim tests and 16 client tests. Map layouts are compared with the browser's tile for tile.

It has menus, settings, remappable keys and controller buttons, touch controls, and the browser's lighting, scenery and character figures.

Still to do:
- cosmetics;
- accounts;
- online play;
- the casino;
- a Windows build for Steam or Epic.

| Status | Blueprint items |
|---|---|
| Done (for solo play) | 34 |
| Partly done | 13 |
| Not started | 30 |
| Measured, not finished | 1 (performance) |
| Not a client job | 2 (PAL-064 trust rules and PAL-080 SLIM's wallet live on the server) |

Nobody has played it by hand yet. It has been checked by:
- the tests;
- a bot that plays a full five-raid game, shopping and firing rockets, and wins, and bot games on Riverbend, Quarry, Frostpeak and the XL Yard;
- still frames rendered in the container.

The sounds have never been listened to, because the container has no speakers.

## Feature by feature

**Done** means it matches the browser for solo play. **Partly** says what is missing.

### Core game

| ID | Feature | Status | What's in, what's missing |
|---|---|---|---|
| PAL-001 | Startup and assembly | Partly | Boots to the main menu over the demo yard. No splash or catalog resources yet. |
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
| PAL-014 | Aim and targeting | Done | Mouse aim at a body or the ground, stick aim with the browser's aim assist, the touch lock-on for grenades and rockets. |
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
| PAL-030 | Dead End and results | Done | The dead-end check and the browser's after-action screen: title, eyebrow, lede for every ending (evac, left behind, failed evac, crew lost, Black Out), stats, skill points. Rewards (cases, shards) come with accounts. |

### Presentation

| ID | Feature | Status | What's in, what's missing |
|---|---|---|---|
| PAL-031 | Camera and zoom | Partly | The projection, follow, shake (with the setting) and zoom (setting and mouse wheel). Missing: spectating (online). |
| PAL-032 | Draw order and see-through walls | Done | The browser's draw order; walls and near trees go see-through in front of people; the city's buildings redraw over whoever is behind them. |
| PAL-033 | Lighting and weather | Done | Overcast, golden hour and night eased the browser's way, with every light pool (soldier, stake, POIs, lamps, fires, kilns, drums, flashes); storms with rain, dust or ash; the vignette and low-health edge. |
| PAL-034 | Characters | Partly | The browser's full flat figure (drawPerson, gunArms, drawDowned) for everyone, with every raider, boss, Delgado and class kit. Players use it too; the browser's shaded wardrobe figure for players comes with cosmetics. |
| PAL-035 | Tracers, auras, kill effects | Partly | The standard tapered tracer, raiders' orange rounds, additive muzzle and blast glows. Cosmetic trails, auras and kill effects come with cosmetics. |
| PAL-036 | Backgrounds | Not started | |
| PAL-037 | Cosmetics catalog (374 items) | Not started | |
| PAL-038 | Main menu, setup, lobby | Partly | Main menu over the demo yard and Match Setup with all solo choices. The lobby comes with online play. |
| PAL-039 | Index and help | Done | Classes, raiders, bosses (every attack, health and weakness, the eight POIs) and how to play. Portraits are not drawn yet. |
| PAL-040 | HUD and nameplates | Done | Top bar, stake bar, boss bars, kit panel, Delgado, build hints, mode clocks, the Black Out phase and mini-map, nameplates, key-cap prompts, crosshair, shell row, off-screen arrows, frame counter. Laid out for desktop; the browser's phone layouts are not ported. |
| PAL-041 | Settings | Done | Volume, music, shake, zoom, message time, frame rate, fullscreen, vsync, frame counter, tips, rumble, saved in user://settings.json. The browser's backup export and import come with accounts. |
| PAL-042 | Keyboard and mouse | Done | The browser's keys, every one remappable in Settings › Controls. |
| PAL-043 | Touch | Done | Two thumb sticks with aim assist, on-screen buttons, the grenade and rocket lock-on. Not yet tried on a real touch screen. |
| PAL-044 | Controller | Done | The browser's button table (Xbox and PlayStation names), remappable, aim assist, hold to build, rumble, menu navigation, the armory and skill tree. Not yet tried with a real pad. |
| PAL-045 | Overlays and focus | Done | Pause, armory, skill tree, settings and the after-action screen; the controller and keys move between their buttons. |
| PAL-046 | Chat and messages | Partly | Messages and floating text. No chat (that comes with online). |
| PAL-049 | Music | Partly | 5 of 7 tracks routed (build, three raid tracks, results). Missing: the menu and finale tracks, and the casino's 11-track shuffle. |
| PAL-050 | Sound effects | Partly | 49 of the browser's synth recipes, with distance, wall muffling and voice limits. Missing: tracer, kill-effect, UI and casino sounds. |

### Accounts, online, casino, release

| ID | Feature | Status | What's in, what's missing |
|---|---|---|---|
| PAL-047 | Locker | Not started | |
| PAL-048 | Cases | Not started | |
| PAL-051 | Startup and offline | Not started | |
| PAL-052 | Pause and focus | Partly | Solo pause and the pause menu. Online keeps running in the browser; that comes with online. |
| PAL-053 | Errors and recovery | Not started | |
| PAL-054 | Local saves | Partly | Settings and the next game's setup, and the skill-tree profile. The browser's best scores and backup are not ported. |
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

1. **Hands-on pass:** play it on a Windows PC with a mouse, a controller and a touch screen; tune what the tests can't judge (feel, readability, sound).
2. **The Windows .exe:** export templates, icon, version info.
3. **Accounts:** sign-in, cloud locker, reward claims (cases, shards) and the skill tree on the server.
4. **Online:** the PeerJS cross-play probe first, then hosting, joining, the lobby, the snapshot protocol, rejoining, spectating, PvP (Base Battle, Free-for-all) and chat.
5. **The casino:** the relay client, the floor and the seven games. The servers already exist.
6. **Cosmetics:** locker, cases, the shaded wardrobe figure, trails, auras, kill effects, backgrounds.
7. **Release:** accessibility, phone-size HUD layouts if mobile is wanted, performance on real hardware, signing, and the Steam or Epic store build.
