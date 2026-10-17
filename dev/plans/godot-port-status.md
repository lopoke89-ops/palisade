# Godot port: status against the blueprint

**As of October 17, 2026.** Branch `claude/nice-brahmagupta-dm3mx6`, folder `godot/`, Godot 4.7.2. Baseline: browser v0.10.9 (`4c26769`, protocol `yard-29`).

- The plan this tracks is `dev/plans/godot-conversion-blueprint.md`.
- How to run and test the build is in `godot/README.md`.

## The short version

The Godot build has every part of the browser game:
- all four classes;
- all six co-op modes: 5 raids, 10 raids, Endless, Blitzkrieg Rush, Operation Whiteout and City Black Out;
- all four maps at both sizes, and the city;
- three difficulties and 20 modifiers;
- Delgado, every raider type and all 16 bosses;
- the armory, the skill tree, sound and all the music.

It has menus, settings, remappable keys and controller buttons, touch controls, and the browser's lighting, scenery and character figures.

It has the cosmetics: the whole catalog, the locker and its payouts, cases and their openings, the shaded wardrobe figure with every skin and headgear, auras, tracers, kill effects and the 78 lobby backgrounds. The art is compared with the browser's own drawing, sheet against sheet.

It has accounts on the browser's own Supabase project, so one account works in both games: guest accounts, sign-in, the cloud locker and skill tree, server-checked run rewards, and case openings that resume after a crash.

It plays online with the browser, in one room, either side hosting: co-op, Base Battle and Free-for-all, up to four players. It has friends, invitations and open games.

It has the casino: the floor, and all seven table games on the browser's tables server. Its best runs and save backup use the browser's formats.

It builds a Windows .exe with `godot/tools/export_windows.sh`.

How it was checked:

| Test | Checks |
|---|---|
| Sim | 208 |
| Client | 56 |
| Godot to Godot online | 24 |
| Friends | 20 |
| Tables | 82 |
| Casino relay | 98 |
| Music | 27 |
| Cross-play with the browser (co-op and PvP) | 38 |
| Casino relay cross-play with the browser | 50 |

- Map layouts are compared with the browser's tile for tile.
- A bot plays a full five-raid game, shopping and firing rockets, and wins.
- Still frames are rendered in the container.
- The exported Windows pack boots and runs under the Linux engine with no script errors.

| Status | Blueprint items |
|---|---|
| Done | 73 |
| Partly done | 4 (PAL-038, 053, 077, 078) |
| Not started | 0 |
| Measured, not finished | 1 (performance) |
| Not a client job | 2 (PAL-064 trust rules and PAL-080 SLIM's wallet live on the server) |

What hasn't been checked:
- **Played by hand:** nobody has yet, and the sounds have never been listened to (the container has no speakers).
- **On Windows:** the .exe has not been run there. Wine in the container crashes on Godot's own Windows template, before any game code runs.
- **Friends:** tested against a stand-in server, not live, because that needs two signed-in accounts.
- **Live servers:** online play and the casino were tested against local copies of the PeerJS server, the casino relay and the tables server, never the live ones.

## Feature by feature

**Done** means it matches the browser. **Partly** says what is missing.

### Core game

| ID | Feature | Status | What's in, what's missing |
|---|---|---|---|
| PAL-001 | Startup and assembly | Done | Boots to the main menu over the demo yard. The catalog is `data/cosmetics.json`; the rules are GDScript constants. |
| PAL-002 | Classes and tuning | Done | All four classes, the three materials, the formulas, the difficulty table. |
| PAL-003 | Match state | Done | Phases, timers, the raid loop, the roster of up to four players and the match id. |
| PAL-004 | Co-op 5 / 10 / Endless | Done | Raid mix and scaling, Endless's climb and day/night cycle, golden hour and night raids, bosses, build timers, salvage. |
| PAL-005 | Base Battle and Free-for-all | Done | Two teams with two stakes, the truce, the storm, spawn protection, kills and the PvP rewards; Free-for-all. Checked in cross-play with the browser. |
| PAL-006 | Blitzkrieg Rush | Done | 15 raids, Blitz bosses, the five-minute Final Blitz, the evac ring. |
| PAL-007 | Operation Whiteout | Done | Four chapters across four maps, the winter boss order, map evacs (stake damage carries, resources open, a failed evac ends it), the Whiteout Gauntlet, and the left-behind rules for a crew. |
| PAL-008 | City Black Out | Done | The 64x64 city, eight POIs with their perks, attacks from the nearest edge, holding and losing, READY UP, the final push, the Supreme Destroyer, the mini-map, the lamp light pools. |
| PAL-009 | Co-op maps | Done | The Yard, Riverbend, Ashfall Quarry and Frostpeak at standard and XL size, tile for tile. Missing: each map's own scenery outside the fence. |
| PAL-010 | PvP maps | Done | Every PvP layout and its spawns, from the browser's `layPvp`. |
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
| PAL-023 | Skill tree | Done | All 19 nodes, costs, gates and perks. Signed in, it is the account's (skill_buy, skill_respec at 40 shards). Offline it is a local one. |
| PAL-024 | Modifiers | Done | All 20, with the browser's mode rules (which ones Blitz and the campaign allow), chosen in Match Setup or the lobby. |
| PAL-025 | Abilities and sprint | Done | Soldier rockets, Sniper stealth, Molotovs, Quartermaster sprint. |
| PAL-026 | Raiders | Done | All seven types, with their AI. |
| PAL-027 | Bosses | Done | All 16, with every attack and warning, each in its mode. Missing: the October Pumpkin Butcher look. |
| PAL-028 | Delgado | Done | Defend or follow; builds his ring of walls safely; gathers; repairs and puts out fires; revives you; hands over materials; restocks grenades; his shotgun and levels. |
| PAL-029 | Damage, going down, revives | Done | Co-op and PvP rules, with spawn protection. |
| PAL-030 | Dead End and results | Done | The dead-end check and the browser's after-action screen: title, eyebrow, lede for every ending (evac, left behind, failed evac, crew lost, Black Out), stats, skill points, rewards as cards, and the PvP results. |

### Presentation

| ID | Feature | Status | What's in, what's missing |
|---|---|---|---|
| PAL-031 | Camera and zoom | Done | The projection, follow, shake (with the setting), zoom (setting and mouse wheel), and the spectator camera while down online. |
| PAL-032 | Draw order and see-through walls | Done | The browser's draw order; walls and near trees go see-through in front of people; the city's buildings redraw over whoever is behind them. |
| PAL-033 | Lighting and weather | Done | Overcast, golden hour and night eased the browser's way, with every light pool (soldier, stake, POIs, lamps, fires, kilns, drums, flashes); storms with rain, dust or ash; the vignette and low-health edge. |
| PAL-034 | Characters | Done | The browser's flat figure (drawPerson, gunArms, drawDowned) for raiders, bosses and Delgado, and the shaded wardrobe figure (paintWardrobeCharacter) for players: every skin, headgear, winter model and gold edition, standing, walking and downed. All 176 looks match the browser's. |
| PAL-035 | Tracers, auras, kill effects | Done | Every tracer stamp (flag colours per round, shed motes, its sound), every outfit aura, all 47 painted kill finishers with their particles, rings, flashes and sounds. |
| PAL-036 | Backgrounds | Done | All 78 lobby backgrounds with their motion and scenic layers; 'lighter' blending adds light as the canvas does. |
| PAL-037 | Cosmetics catalog (374 items) | Done | `data/cosmetics.json`, extracted from the built site: items, rarities, cases, ladders, skins, tracers, flags, auras. |
| PAL-038 | Main menu, setup, lobby | Partly | Main menu on the equipped lobby background, Match Setup, and the online lobby with every choice, ready-up, sides, lock, invites and chat. Missing: the browser's stage with the crew standing on it (the lobby is a roster list). |
| PAL-039 | Index and help | Done | Classes, raiders, bosses (every attack, health and weakness, the eight POIs) and how to play. Portraits are not drawn yet. |
| PAL-040 | HUD and nameplates | Done | Top bar, stake bar, boss bars, kit panel, Delgado, build hints, mode clocks, the Black Out phase and mini-map, nameplates, key-cap prompts, crosshair, shell row, off-screen arrows, frame counter. Laid out for desktop; the browser's phone layouts are not ported. |
| PAL-041 | Settings | Done | Volume, music, shake, zoom, message time, frame rate, fullscreen, vsync, frame counter, tips, rumble, reduce motion, saved in user://settings.json. The save backup is the browser's own code. |
| PAL-042 | Keyboard and mouse | Done | The browser's keys, every one remappable in Settings › Controls. |
| PAL-043 | Touch | Done | Two thumb sticks with aim assist, on-screen buttons, the grenade and rocket lock-on. Not yet tried on a real touch screen. |
| PAL-044 | Controller | Done | The browser's button table (Xbox and PlayStation names), remappable, aim assist, hold to build, rumble, menu navigation, the armory and skill tree. Not yet tried with a real pad. |
| PAL-045 | Overlays and focus | Done | Pause, armory, skill tree, settings and the after-action screen; the controller and keys move between their buttons. |
| PAL-046 | Chat and messages | Done | Messages, floating text, the kill feed, and chat in the lobby and in game (Enter). |
| PAL-049 | Music | Done | All 7 tracks routed as the browser does (menu, build, three raid tracks, the finale, results) and the casino's 11-track shuffle with crossfades; big casino results dip the music. |
| PAL-050 | Sound effects | Done | The browser's synth recipes for the game, the 15 tracer sounds, 30 kill-effect sounds, the case reel's ticks and the 14 casino sounds, with distance, wall muffling and voice limits. |

### Accounts, online, casino, release

| ID | Feature | Status | What's in, what's missing |
|---|---|---|---|
| PAL-047 | Locker | Done | The Locker screen: the outfit on show, every item by tab and collection, equip, milestone ladders, unlock progress. The account's locker when signed in, a local one offline. |
| PAL-048 | Cases | Done | Case rewards for every mode (the server's claim_match_reward when signed in; offline, the browser's localRun, checked against it), opening one or five with the crate, reel and reveal (open_cases_v0964 with a saved operation ID that resumes), buying with shards or skill points, reward cards. |
| PAL-051 | Startup and offline | Done | A guest account at first launch; solo plays offline with the PC's copy of the locker, and run rewards wait in the claims queue. |
| PAL-052 | Pause and focus | Done | Solo pauses (also when the window loses focus); online never pauses, as in the browser. Closing the window leaves the run and pays what was held. |
| PAL-053 | Errors and recovery | Partly | The browser's messages for room, version, full, locked, kicked, host-left, relay and sign-in failures; a guest's session survives a restart for an hour; a crashed run pays at the next start. Not every failure has been injected in a test. |
| PAL-054 | Local saves | Done | Settings, the next game's setup, the skill-tree profile, best runs, and the browser's PALISADE-SAVE-1 backup code (checked both ways against the browser's own). |
| PAL-055 | Sign-in and profile | Done | The browser's Supabase project and accounts: a guest account made quietly at first launch, add an email, sign in with email and password, forgot password, sign out (back to the guest), username. Email links (confirm, reset) finish on the website. Token refresh. An HTTPS proxy and extra CA from the environment are honoured. |
| PAL-056 | Cloud inventory | Done | get_my_locker, the one-time import_local_save of this PC's progress, equip, buy_case, buy_case_sp, open_cases_v0964, skill_buy and skill_respec. The PC keeps a copy for instant menus and offline play. |
| PAL-057 | Reward claims | Done | Finished runs go to claim_match_reward through a per-account queue (8 entries, 30 days) that survives restarts; a refusal is said plainly, a lost connection keeps the run until it is back, the play-time budget is waited out. |
| PAL-058 to 060 | Friends, invites, hosting and joining | Done | Friends, requests, mail, recent players, search, invitations into a room, open games, hosting and joining by code. Friends tested against a stand-in server, not live. |
| PAL-061 to 063 | Network protocol, host checks, rejoining | Done | Protocol yard-29 over PeerJS and WebRTC (the webrtc-native extension), with the host's checks on speed, building and buying; a guest who drops gets their kit back. Cross-play with the browser checked both ways. |
| PAL-065 to 075 | Casino floor and all seven games | Done | The floor, seats and dealers, and blackjack, hold'em, roulette, baccarat, craps, slots and Plinko on the browser's tables server, with receipts, history and the fairness CHECK. |
| PAL-076 | Performance | Measured | The ground and the city's buildings are painted once into chunks that Godot culls off screen. A city frame costs about 3.6 ms of drawing and a crowded final push about 3 ms of sim, on the container's CPU. Still to measure on a real PC. |
| PAL-077 | Accessibility | Partly | Every key and button remappable, the menus and tables work without a mouse (a controller cursor on the roulette board), reduce motion, message time. No localization or text scaling. |
| PAL-078 | Build and release | Partly | `tools/export_windows.sh` builds Palisade.exe and the WebRTC DLL. Missing: a run on real Windows, an icon and version info, code signing, Steam or Epic integration. |
| PAL-079 | Casino relay client | Done | `casino_relay.gd`: hello, heartbeat with token refresh, resume after a drop, lock, remove. Checked against the real relay running locally. The relay now lets in the desktop game, which sends no Origin; the live one needs a deploy for that. |

## Where the Godot build knowingly differs from the browser today

1. **Skill points offline:** with no account (offline), the skill tree is a local one and reset is free. With an account it is the account's, and reset costs 40 shards as in the browser.
2. **Warning drawings:**
   - These are exact ports of the browser drawing: the Demolisher, Butcher and Stormcaller, the new moves (Thunderstrike to Overdrive), the Foreman, winter, and the Destroyer's rockets.
   - These follow the browser's colours and shapes, but I didn't port their exact drawing code: the Blitz variants' own warnings and the Destroyer's other attacks.
3. **Email links:** confirming an email and resetting a password finish on the website; the player then signs in here with their password.
4. **Sound noise:** each effect's noise is fixed when it's rendered. The browser picks a new noise each time it plays. The roulette ball's whir is one recording started part way in when you join a spin late.
5. **Precision:** in the sim, directions are 32-bit (Godot's `Vector2`); positions and timers are 64-bit as in the browser. This matters only for cross-play, where the host's numbers win anyway.
6. **Casino rooms:** a casino hosted from the desktop game is a normal 4-character room, not a relay room. Browser-hosted casinos (`R…` codes) are joined over the relay.
7. **The lobby:** a roster list, not the browser's stage with the crew standing on it.

## What's left

1. **Deploy the relay:** the relay now admits the desktop game (no Origin; a wrong Origin is still refused). Merge to `main` and run a manual deploy of `palisade-casino-relay` on Render; until then the desktop game can't join browser-hosted casinos.
2. **Hands-on pass:** play it on a Windows PC with a mouse, a controller and a touch screen; tune what the tests can't judge (feel, readability, sound).
3. **Release:** an icon and version info, code signing, the Steam or Epic store build and its integration (needs those accounts), performance on real hardware, phone-size HUD layouts if mobile is wanted.
4. **Small gaps:** the lobby stage, each map's scenery outside the fence, the Pumpkin Butcher look, Index portraits, localization.
