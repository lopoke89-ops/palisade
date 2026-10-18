# Palisade: Godot client

The Godot 4.7 port of the browser game, built against v0.10.9 (`4c26769`, protocol `yard-29`).
The plan is in `dev/plans/godot-conversion-blueprint.md`. It plays every solo co-op game the browser has:
- all four classes;
- 5 raids, 10 raids, Endless, Blitzkrieg Rush, Operation Whiteout and City Black Out;
- all four co-op maps at both sizes, and the 64x64 city;
- the three difficulties and all 20 modifiers;
- Delgado, all seven raider types, all 16 bosses, the armory, the skill tree, sound and music.

It also plays online with the browser (co-op, Base Battle and Free-for-all), has friends and invitations, and has the casino with all seven table games.

It opens on the main menu over the demo yard: PLAY, PLAY ONLINE, THE CASINO, FRIENDS, MATCH SETUP (length, map, size, threat, class, modifiers), LOCKER, SKILL TREE, ACCOUNT, INDEX, SETTINGS. Settings and the next game's setup are kept in `user://settings.json`.

Settings › WINDOW has the PC's display settings, which the browser doesn't have:
- **Display mode:** windowed, fullscreen (borderless) or exclusive fullscreen.
- **Window size:** 16:9 sizes that fit the screen. The window is centred and can still be resized by hand.
- **VSync.**
- **FPS limit:** off, 60, 120, 144 or 240, used while FRAME RATE (the browser's setting) is on AUTO.

The save backup leaves these out, so its code stays the browser's.

## Run it

1. Install Godot 4.7.x (standard build, not .NET).
2. Open `godot/project.godot` in the editor.
3. Press F5.

Controls (the browser's; every key and controller button can be changed in Settings › Controls):

| Action | Keyboard and mouse | Controller |
|---|---|---|
| Move | WASD / arrows | left stick |
| Aim and fire | mouse, left button | right stick (aim assist), RT |
| Build or repair the faced tile | Space | A (hold to keep building) |
| Material | 1 / 2 / 3 | ◀ / ▶ |
| Wall or door | F | Y |
| Grenade | G (at the cursor) | LT |
| Class ability: Soldier rocket, Sniper stealth | Q | B (the Quartermaster sprints) |
| Sprint (Quartermaster) | Shift | B |
| Reload (Grenadier) | R | (unset) |
| Armory, at the stake between raids | E / U | X |
| Delgado: follow you / defend the stake | H | (unset) |
| Start the raid early; ready up in Black Out | Enter | VIEW |
| Pause | Esc / P | MENU |
| Skill tree | K | (unset) |
| Zoom | mouse wheel | |
| Developer: bring in the next boss (editor runs only) | F8 | |

In the menus the d-pad or left stick moves, A presses, B goes back. On a touch screen the left thumb moves, the right thumb aims (and fires when pushed past half), and on-screen buttons build, throw (locked onto the nearest raider in reach), use the ability, open the armory, pick materials, start the raid and pause.

## What is ported

Each part follows the browser code, with function names kept so the two read side by side.

| Area | Browser source | Godot |
|---|---|---|
| Tuning constants, `hash`, walls | `01-setup.js`, `04-state-armory.js` | `scripts/pal.gd` |
| Projection and camera | `02-view.js`, `17-scenery.js` | `scripts/iso_view.gd` |
| Sim | `06-world.js`, `09-actions.js`, `10-phases-bosses.js`, `12-players.js`, `14-raiders.js` | `scripts/sim.gd` |
| Delgado | `13-dell.js`, `13b-commands-recovery.js` | `scripts/sim.gd` |
| Drawing and HUD | `15-render.js`, `16-characters.js`, `17-scenery.js` | `scripts/main.gd` |
| Maps and the city | `06b-maps.js`, `06d-elevation.js`, `06e-city.js` | `scripts/pal_maps.gd` |
| Modes and modifiers | `01b-mods-skills.js`, `10b-mods-play.js`, `10c-blitz.js`, `10d-winter-campaign.js`, `10f-blackout.js` | `scripts/sim.gd` |
| The city's look and the Black Out HUD | `06e-city.js`, `16f-blackout-hud.js` | `scripts/city_view.gd`, `scripts/ground_chunk.gd` |
| Characters | `16-characters.js` | `scripts/figure.gd` |
| Forest, fence, lighting, storm, nameplates | `17-scenery.js`, `10b-mods-play.js`, `16h-nameplates.js` | `scripts/scenery.gd`, `shaders/`, `scripts/main.gd` |
| Menus and settings | `page.html`, `19c-home.js`, `19e-index.js`, `22-loop-menus.js` | `scripts/menus.gd`, `scripts/pal_settings.gd` |
| Controller and touch | `08-input.js`, `08b-pad.js` | `scripts/pal_input.gd` |
| Sound and music | `03-audio.js` | `scripts/pal_audio.gd`, `tools/render_sfx.gd`, `tools/convert_music.sh` |
| Cosmetics catalog, locker, rewards, cases | `18-cosmetics.js`, `18a`/`18e` catalogs, `16d`/`16e` data | `data/cosmetics.json` (made by `tools/cos_extract.js`), `scripts/pal_locker.gd` |
| The shaded wardrobe figure and outfit looks | `16-characters.js` (`paintWardrobeCharacter`, `buildLook`) | `scripts/wardrobe.gd` |
| Outfit auras | `16b-auras.js` | `scripts/cos_fx.gd` |
| A canvas 2D context for the cosmetic art | (the browser's canvas) | `scripts/ctx2d.gd` |
| Tracers, kill finishers, cosmetic particles | `20a-cosmetic-art.js`, `20b-winter-effects.js`, `20c-hybrid-effects.js`, `20-locker-ui.js` (`killFx`) | `scripts/cos_art.gd`, `scripts/main.gd` |
| Lobby backgrounds | `18b-backgrounds.js`, `18c-background-depth.js`, `18d-winter-scenes.js`, `18f-hybrid-scenes.js` | `scripts/backgrounds.gd` |
| Locker screen, case openings, reward cards | `20-locker-ui.js`, `20b-case-openings.js` | `scripts/locker_ui.gd`, `scripts/case_open.gd`, `scripts/menus.gd` |

What `sim.gd` covers:
- **Pathing and collision:** the Dijkstra flow field, `bestStep`, `moveEnt`, `losClear`.
- **Building:** place, upgrade, repair and door.
- **Soldier:** the burst carbine and grenades.
- **Gathering.**
- **Damage:** bullet sub-stepping and wall hit chances, explosions with fire, salvage from ruins, downed and respawn.
- **Raids:** the Yard layout and the raid and build loop to a five-raid win, with the browser's `waveMix`.
- **Raiders:** all seven types with their AI.
  - Riflemen, and spotters who mark you so the riflemen aim far better.
  - Grenadiers, and breachers who plant satchel charges.
  - Shieldbearers, whose riot shield stops 20 rounds from the front.
  - Field medics, who heal the raiders around them.
  - Firebrands, whose bottles leave burning ground and set wood alight.
- **Delgado:** his full AI.
  - He builds and upgrades a 4×4 perimeter with doors round the stake, gathers for it, repairs and douses walls, and revives you.
  - He shoots his shotgun and restocks your grenades.
  - H switches him between defending and following you.
- **Bosses:** every fifth raid brings one, in the Yard's order: the Butcher, the Demolisher, then the Stormcaller.
  - On a five-raid game you meet the Butcher on raid 5.
  - Each has the browser's health (+25%), attacks and warnings:
    - the Butcher's slash wedge and charge lane, and his rage below 40%;
    - the Demolisher's red line and his rocket fans;
    - the Stormcaller's tracking bolt that locks, stuns and jumps, and fires twice below half health.
  - A boss pays 40 salvage to whoever lands the kill, and hits from his weak ammo deal +35%.
- **The other bosses:** they fight on the Yard.
  - In the browser they come with their own modes, which aren't ported yet, so for now they're reached with F8 in editor runs.
  - The Foreman: he burrows, can't be hit underground, bursts up, throws slabs that stay as cover, and calls a rockfall.
  - The Blitzkrieg variants: the Blue Butcher's wall-breaking arcs, the Arsonist's napalm chains, the Tempest's twin bolts, the Bulldozer's charge and daze, and the Harbinger's arcing missiles.
  - Each Blitz variant has its two extra moves (Cyclone, Storm Cage, Flamethrower, Ring of Fire, Seismic Slam, Overdrive). The Stormcaller's Thunderstrike and Static Pulse are in too.
  - The winter bosses: the Rime Colossus (ruptures, and a dash that leaves slowing frost), the Frostbound Butcher and the Permafrost Foreman.
  - The Supreme Destroyer: back rockets, the fire and lightning barrels, poison gas, mines and the orbital cannon.
  - The three Ferryman bosses need the Riverbend map and are not in yet.
- **Skill tree:** all 19 nodes at the browser's costs, including the lifetime-point gates on the ammo tiers and Molotovs needing Extra Pouch.
  - Perks apply from the next game: damage, fire rate, range, health, Second Wind, revive speed, speed, Kevlar, Pack Mule, rockets.
  - The ammo ranks power armor-piercing, incendiary, explosive and lightning rounds.
  - Points come by the server's rule: 1 per 5 raids held, carried between runs, plus 1 per boss.
  - Points are kept locally in `user://profile.json` until accounts are ported. Reset is free for now; the browser charges 40 shards.
- **Classes:** the Sniper (a piercing bolt rifle, two ammo slots, stealth), the Grenadier (a pump shotgun loaded a shell at a time, extra grenades, Molotovs) and the Quartermaster (bigger packs, cheap stake repairs, sprint, patching up Delgado by touch).
- **Maps:**
  - Riverbend: wading, bridges, floods from raid 3, and the Ferryman on his raft with harpoons and boarding crews.
  - Ashfall Quarry: rock outcrops, burning drums, cracked ground that heavy blasts break into pits.
  - Frostpeak: three terraces with cliffs, stairs and ramps, with height in movement, bullets, blasts and aiming.
  - XL: every map at 24x24, laid out tile for tile as the browser does.
- **Modes:**
  - 5 and 10 raids and Endless, with golden hour and night raids, and Hard and Easy.
  - All 20 modifiers.
  - Blitzkrieg Rush: 15 raids of Blitz bosses and the five-minute Final Blitz to the evac ring.
  - Operation Whiteout: four chapters across the four maps, 15-second map evacs between them, and the Whiteout Gauntlet.
  - City Black Out:
    - eight POIs attacked one by one, each with its perk (radio warning, power, hospital, armory refills, salvage, extra piles, high ground);
    - READY UP, then the five-minute final push and the Supreme Destroyer;
    - the mini-map.
- **Armory:** spend salvage at the stake between raids. Kills pay the browser's bounties.
  - The five upgrades go to 8 levels at the browser's costs and steps.
  - Delgado's level, the stake repair (+50 for 25), and the four ammo types, at skill rank 0 until the account skill tree is ported.
  - The Soldier's rockets.
- **Cosmetics:** the whole catalog (skins, headgear, tracers, kill effects, backgrounds, the milestone ladders), kept on the account's server when signed in (with a copy in `user://locker.json`), or locally when offline.
  - A run pays out exactly as the browser's no-account `localRun` does: cases, shards, milestones, skill points and unlocks (checked against the browser for eight runs).
  - Players wear their outfit in the browser's shaded wardrobe figure, with its aura, tracer (and the tracer's sound and shed motes) and kill effect.
  - The Locker: case boxes (open one or five, buy with shards or three skill points), every item by tab and collection, equip with a click. Openings play the crate, the reel and the reveal.
  - The menus sit on the equipped lobby background, and the after-action screen shows the rewards as cards.

## Accounts

`scripts/pal_account.gd` is `19-accounts.js` on the same Supabase project and public key, so an account and its locker, skills and rewards work in both games.
- At first launch a guest account is made quietly. The Account page (main menu) adds an email, signs in with email and password, sends a password reset, sets the username and signs out (back to the guest).
- Email links (confirming an address, resetting a password) open the website, which finishes them; the player then signs in here.
- Signed in, the server owns the locker and skill tree. The PC keeps a copy, so menus open at once and solo plays offline.
- Finished runs go to `claim_match_reward` through a queue in `user://claims.json` (8 runs, 30 days, per account).
- Case openings use `open_cases_v0964` with an operation ID saved in `user://opening.json`, so a crash or lost connection resumes the same opening instead of opening more.
- This PC's progress from before it had an account goes in once, through the account's one-time `import_local_save`.
- Godot reads no system proxy settings: `HTTPS_PROXY` and `SSL_CERT_FILE` in the environment are honoured.
- Tests set `PalAccount.offline` and never touch the network; `tests/client_test.gd` runs the account against a stand-in server. `tests/account_live.gd` is the live check: it makes one guest account (named `godot_test_…`), walks it through the real server and prints its ID so it can be deleted.

## Online play

PLAY ONLINE (main menu) hosts a room or joins one by its 4-character code. Rooms are the browser's own, so the desktop game and the browser play together either way round.
- **Transport:** `scripts/peer_net.gd` is the PeerJS signalling protocol over WebSocket, with WebRTC data channels from the `webrtc-native` GDExtension in `addons/webrtc` (Linux and Windows x86_64). It uses the same PeerJS server and TURN relay as the site.
- **Protocol:** `scripts/pal_net.gd` is protocol `yard-29`, word for word. The host runs the sim; guests send input and get snapshots, wall diffs and events.
  - Up to 6 players, as in the browser. The lobby picks the game, map, size, threat, modifiers, the job, and locks the room.
  - Everyone readies up and keeps their class, outfit and skills (checked against their account).
  - Chat (Enter), a kill feed, nameplates and edge arrows for players off screen, and a spectator camera while down.
  - A guest whose game restarts gets back in within an hour with the same kit.
- **PvP:** Base Battle (two teams, two stakes, a truce to build, then a storm) and Free-for-all, on their own maps, with the browser's PvP rewards.
- **Rewards:** online runs pay out as solo runs do. Leaving early pays what was held up to then.

## Friends and invitations

FRIENDS (main menu) needs a signed-in account (not a guest). It uses the same server tables and calls as the browser, through `scripts/pal_social.gd`.
- **Tabs:** friends (with who is online and in a game), requests (accept or decline), mail (invitations) and recent players. Search finds players by username.
- **Invites:** INVITE A FRIEND in the lobby sends the room. The invitation shows up in the friend's mail, in either game, and joins with one press.
- **Open games:** a host can list the room. OPEN GAMES on the online page shows listed rooms with their mode and player count.

## The casino

THE CASINO (main menu) opens Palisade Falls Casino alone. An online host can also pick the casino as the room's game. The floor is the browser's: seven games, 16 slot cabinets, the Plinko board, dealers, lights and the bar. Nobody fights or builds in there.
- **Playing:** walk up to a seat and press E (X on a controller) to sit. The table's sheet opens on the right; HIDE puts it away and leaves you seated; STAND UP, Esc or leaving the casino gives the seat back.
- **Games:** blackjack, hold'em (SLIM sits in), roulette, baccarat, craps, slots and Plinko. They run on the browser's `tables` server, so it holds the shards and decides every result.
  - `scripts/pal_tables.gd` is the browser's table client. Every money move has an operation id that is reused on retries, so a dropped connection never pays twice.
  - `scripts/casino_ui.gd` draws the sheets: bets, chips, cards, dice, the wheel, reels, the Plinko ball, receipts, hand history, house rules and the fair-play seed.
  - CHECK replays a round from its revealed seeds, as the browser does, for every game.
- **Signing in:** the tables need a signed-in account with an email (not a guest), as in the browser.
- **Browser casinos:** the desktop game joins a browser-hosted casino by its `R…` code over the casino relay (`scripts/casino_relay.gd`).
  - The relay lets the desktop game in because it sends no browser Origin (`NATIVE_CLIENTS`, on by default). A relay deployed before that change turns it away, and joining says so.
  - A casino hosted from the desktop game uses a normal 4-character room, which browsers join as usual.
- **Music:** the casino has its own shuffled 11-track playlist with crossfades between tracks. Big wins and big losses dip the music under their fanfare.

## Saves and backup

- **Best runs:** each length, threat, map, size and modifier set keeps its best run in `user://best.json`. The main menu shows the best for the next game's setup.
- **Save code:** SETTINGS › SAVE BACKUP copies the browser's own `PALISADE-SAVE-1` code (locker, best runs, settings) and restores from one, so a code from the browser works here and the other way round.
- **Interrupted runs:** a run in progress is saved as a draft. If the game is closed or crashes, the next start pays what was held.

## The 3D models

The menus, the online lobby and the Locker use the 3D model library (the private repo lopoke89-ops/palisade-3d-model-library).
- **What's in the game:** `palisade_art/` is the runtime part of the library: its catalog, animation manifest, lobby layouts, weapon profiles and the class, skin, headgear, lobby environment, ring and weapon models. `palisade_art/LIBRARY.txt` names the library commit it came from.
- **Updating it:** `godot/tools/sync_art.sh /path/to/palisade-3d-model-library` copies a new revision in. Godot then imports the models with the library's settings (60 fps clips, neutral tracks kept, clip names kept, the import script `tools/import/palisade_post_import.gd`). These are set as the scene importer defaults in `project.godot`, so they apply without `.import` files.
- **Characters:** `scripts/art_library.gd` builds a dressed character from the game's own IDs. It uses the class model for the standard skin and the skin model otherwise, applies the headgear with the library's fit and replacement-head rules, and swaps in the class's weapon (carbine, bolt rifle, pump or SMG) where the skin was posed with another gun.
- **The stage:** the menus keep the browser's painted lobby background (the equipped one), and `scripts/lobby3d.gd` stands the crew over it in 3D, where the browser paints them.
  - Each person stands on the browser's stage spot (`Menus.STAGE2D`, a 1000x780 canvas fitted into the page's hero box) at its scale, holding their weapon forward (`Aim_Loop`) and turned as the browser turns them. You turn slowly.
  - The camera is orthographic and pitched 12.7°, so the pads lie at the browser's flattened ellipse. The page draws the empty spots' "+" and the others' name plates over it (`Menus.Hero2D`, which also paints the 2D figures when the models aren't in a build).
  - On PLAY and INDEX you stand alone. In an online lobby the whole room stands there, you in front and up to five more. The Locker lifts you to leave room under your feet, as the browser does.
  - The library's 3D lobby environments are not shown: the menus use the painted backgrounds, as in the browser.
- **In play:** `scripts/view3d/` draws the game in 3D under the 2D HUD (Settings data `models3d`, on by default; F9 switches it in a game). It only reads the sim, so cross-play is untouched.
  - The camera is orthographic, pitched 30° and turned 45°, so it shows exactly what the 2D projection shows: nameplates, prompts, the crosshair, boss warnings and the night's light pools line up unchanged.
  - People (`v3_actors.gd`): the soldiers in their outfits, Delgado, the seven raiders and the bosses, pooled, with clips from sim state (walk/strafe/run, firing, shell insert, bolt, throws, the rocket, building, gathering, downed, revive, hit, death, the back roll, and each boss's tell, move and recovery).
  - The world (`v3_world.gd`, `v3_scenery.gd`): every map's ground and terrain, walls in one MultiMesh, props, the forest and fence, the city and the casino, built from the 2D's own numbers and colours; see-through by the 2D rules.
  - Effects (`v3_fx.gd`): the library's tracer rounds with their profile ribbons, the kill-effect models with the approved motion, particles, fire, things in flight.
  - Quality knobs for a settings page are in `scripts/view3d/quality3d.gd` (Settings data `gfx3d`): shadows, effects density, draw margin, animation rates, MSAA, effect caps, render scale.
- **Without the models:** if `palisade_art/` is missing (or `models3d` is off), the menus fall back to the painted backgrounds and the game to the 2D drawing.

## Windows build

`tools/export_windows.sh` makes `export/palisade/Palisade.exe` (the game, with its data inside) and the WebRTC DLL next to it. It uses the "Windows Desktop" preset in `export_presets.cfg` and leaves the tests and tools out. If the Godot 4.7.2 export templates are missing, it downloads them once (about 1.3 GB) and keeps only the Windows ones.

```sh
godot/tools/export_windows.sh /path/to/Godot_v4.7.2     # from Linux, macOS or Git Bash on Windows
```

Ship the .exe and the .dll together. The .exe is not code-signed: Windows SmartScreen warns on first run until it is signed with a certificate.

## Not yet

- **Steam or Epic:** no store integration (achievements, overlay, friends). That needs the store accounts.
- **Other platforms:** only Linux and Windows. The WebRTC extension in `addons/webrtc` has no macOS, Android or iOS libraries yet.

In the 2D drawing (without the models), raiders, bosses and Delgado use the browser's flat `drawPerson` figure; players use the shaded wardrobe figure, as in the browser.

## Sound

- **Effects:** `sfx/*.wav` are the browser's synth recipes, rendered by `tools/render_sfx.gd` with the Web Audio formulas.
  - They are stored at half level for headroom and played back at the browser's mix.
  - The browser's rules carry over: distance falloff, the low-pass muffle for each wall in between, and the voice limits.
  - To change a sound, edit its recipe and run `godot --headless --path godot --script res://tools/render_sfx.gd`.
- **Music:** Godot can't play the site's Opus or AAC files, so `music/*.ogg` are the site's tracks re-encoded as Ogg Vorbis.
  - Each track is cut to its exact loop length by `tools/convert_music.sh` (needs ffmpeg).
  - The menus play *main menu*. The build phase plays *between raids*, the raids cycle *attitude*, *cool* and *express*, and the end screen plays *results*.
  - Blitzkrieg Rush, the Whiteout Gauntlet and Black Out's final push play *final blitz*. The casino shuffles its 11 tracks.
  - Tracks fade in over 1.6 s and fade out as the browser's do.

## Tests

```sh
godot --headless --path godot --script res://tests/sim_test.gd           # exit 0 = pass
godot --headless --path godot --script res://tests/client_test.gd        # settings, bindings, menu flow, touch, locker payouts, the Locker
xvfb-run godot --path godot --script res://tests/shot.gd -- /tmp/shot.png # renders a raid frame
xvfb-run godot --path godot --script res://tests/menu_shot.gd -- /tmp/m   # the main menu, setup, controls, results
xvfb-run godot --path godot --script res://tests/shot.gd -- /tmp/city.png city            # a Black Out attack
xvfb-run godot --path godot --script res://tests/shot.gd -- /tmp/frost.png map frost std  # any map, size and class
PAL_COS=gsoldier,crown xvfb-run godot --path godot --script res://tests/shot.gd -- /tmp/s.png  # dressed in an outfit
xvfb-run godot --path godot --script res://tests/cos_shot.gd -- /tmp/cos.png     # tracers and kill effects in play
xvfb-run godot --path godot --script res://tests/locker_shot.gd -- /tmp/lk      # the Locker and a case opening
xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1600x900 --script res://tests/lobby3d_shot.gd -- /tmp/l3   # the 3D crew: main menu, a room of six, the Locker, a smaller window, each on its browser spot
xvfb-run -a -s "-screen 0 1920x1080x24" sh -c 'openbox & sleep 1; godot --path godot --rendering-driver opengl3 --script res://tests/display_shot.gd -- /tmp/d'   # Settings › WINDOW on a real window (fullscreen needs a window manager)
xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1600x900 --script res://tests/shot3d.gd -- /tmp/r raid   # the same moment in 3D and in 2D (r_3d.png, r_2d.png), frame times; scenes in the script
godot --headless --path godot --script res://tests/music_test.gd         # which track each screen and mode plays
godot --headless --path godot --script res://tests/social_test.gd        # friends, invites, open games (against a stand-in server)
```

Online play and the casino run against local servers, never the live ones:

| Test | Needs | Covers |
|---|---|---|
| `godot --headless --path godot --script res://tests/net_test.gd` | `node dev/test/peer-server.js` | two Godot games in a room: lobby, start, input, snapshots, building, shopping, chat, leaving |
| `node godot/tests/cross_game.js` | the peer server and a built site (`dev/build.py`) | Godot and the browser in one game: co-op both ways, a Free-for-all hosted by Godot, a Base Battle hosted by the browser |
| `godot --headless --path godot --script res://tests/relay_test.gd` | `dev/render` node modules | the casino relay client against the real relay with fake sign-in: joining, resuming, refusals, token refresh, a relay restart |
| `node godot/tests/relay_cross.js` | the same, and a built site | casinos over the relay with the browser, both ways, and the real game joining a browser casino |
| `godot --headless --path godot --script res://tests/tables_test.gd` | `dev/test` node modules | every table game against the real `tables` handler on a throwaway Postgres: balances, retries that pay once, CHECK on real and tampered rounds |
| `xvfb-run godot --path godot --script res://tests/casino_play_shot.gd -- /tmp/c` | the same | the casino floor and a table together: sit, play music, stand up |
| `xvfb-run godot --path godot --script res://tests/casino_shot.gd -- /tmp/c` | the same | every game's sheet on screen |

The cosmetic art is checked against the browser's own drawing. Each tool below paints a contact sheet in the browser (from a site built with `dev/build.py`), and the matching test paints the same sheet in Godot:

| Browser (`node godot/tools/…`) | Godot (`xvfb-run godot --path godot --rendering-driver opengl3 --script res://tests/…`) | Covers |
|---|---|---|
| `wardrobe_ref.js <site> sheet.png` (also writes `tests/wardrobe_looks.json`) | `wardrobe_shot.gd -- sheet.png` (also checks all 176 looks match) | every skin and headgear, two headings |
| `fx_ref.js <site> prefix` | `fx_shot.gd -- prefix` | all 76 tracers, all 47 kill finishers at four moments |
| `bg_ref.js <site> sheet.png` | `bg_shot.gd -- sheet.png` | all 78 lobby backgrounds |
| `locker_ref.js <site>` (writes `tests/locker_ref.json`) | `client_test.gd` | eight runs' payouts |

`sim_test.gd` checks the following:
- `hash` matches the browser bit for bit;
- the Yard layout, projection, build rules and costs, gathering, blast damage and salvage;
- the raid mix against the browser's `waveMix` for 15 raid and crew-size cases;
- what each raider type does: the shield stopping frontal fire, satchels breaching, bottles lighting wood, medics healing, spotters marking;
- Delgado building the perimeter and reviving you;
- the boss raid mix and order, each boss's attack, boss bounty;
- all 16 bosses fight a moving soldier, and each uses its own warnings and moves;
- the three other classes: health, guns, ammo, reloads, sprint, stealth, Molotovs;
- every map and size, and the city, laid out tile for tile as the browser does (`tests/maps_ref.json`, made by `node tools/maps_ref.js dev/src/js`), with a path from every spawn;
- river wading and floods, the Ferryman, quarry pits, Frostpeak's terraces;
- each mode and modifier: Endless and night raids, Hard, Elite, On Your Own, No Patch-Ups, Last Stand, Blitzkrieg Rush to the evac;
- Operation Whiteout: the chapter boss order, the map evac to Riverbend, a failed evac, the Gauntlet's waves and cap;
- City Black Out: POI health, paths to every POI, an attack on a POI, losing one and its perk, READY UP, the final push, the Destroyer;
- bot games on every map;
- frost slow, and the Foreman out of reach underground;
- skill points, costs, gates, perks, armor-piercing rank 4 and reset;
- every armory purchase against the browser's numbers, the shop rules, ammo effects, bounties and rockets;
- a bot playing raid 1, then a whole five-raid game with Delgado (it shops between raids and fires rockets at the boss);
- same seed + same inputs = same game.

Note: `Vector2` is 32-bit in Godot, while the browser's numbers are 64-bit. Positions and timers are kept as 64-bit floats in the sim; only directions use `Vector2`.
