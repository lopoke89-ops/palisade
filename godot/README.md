# Palisade: Godot client

The Godot 4.7 port of the browser game, built against v0.10.9 (`4c26769`, protocol `yard-29`).
The plan is in `dev/plans/godot-conversion-blueprint.md`. It plays every solo co-op game the browser has:
- all four classes;
- 5 raids, 10 raids, Endless, Blitzkrieg Rush, Operation Whiteout and City Black Out;
- all four co-op maps at both sizes, and the 64x64 city;
- the three difficulties and all 20 modifiers;
- Delgado, all seven raider types, all 16 bosses, the armory, the skill tree, sound and music.

It opens on the main menu over the demo yard: PLAY, MATCH SETUP (length, map, size, threat, class, modifiers), SKILL TREE, INDEX, SETTINGS. Settings and the next game's setup are kept in `user://settings.json`.

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

## Not yet

These are later phases:
- **Accounts:** the skill tree saves locally until then.
- **PvP:** Base Battle and Free-for-all come with online play.
- **Cosmetics:** skins, headgear, tracers and kill effects, the locker and cases, and the shaded wardrobe figure the browser draws for players.
- **Music:** the menu and finale tracks, and the casino playlist.
- **Network:** online play (PeerJS cross-play probe, casino relay client).

Players are drawn with the browser's flat `drawPerson` figure (as raiders and Delgado are); the browser's shaded wardrobe figure for players comes with cosmetics.

## Sound

- **Effects:** `sfx/*.wav` are the browser's synth recipes, rendered by `tools/render_sfx.gd` with the Web Audio formulas.
  - They are stored at half level for headroom and played back at the browser's mix.
  - The browser's rules carry over: distance falloff, the low-pass muffle for each wall in between, and the voice limits.
  - To change a sound, edit its recipe and run `godot --headless --path godot --script res://tools/render_sfx.gd`.
- **Music:** Godot can't play the site's Opus or AAC files, so `music/*.ogg` are the site's tracks re-encoded as Ogg Vorbis.
  - Each track is cut to its exact loop length by `tools/convert_music.sh` (needs ffmpeg).
  - The build phase plays *between raids*, the raids cycle *attitude*, *cool* and *express*, and the end screen plays *results*.
  - Tracks fade in over 1.6 s and fade out as the browser's do.

## Tests

```sh
godot --headless --path godot --script res://tests/sim_test.gd           # exit 0 = pass
godot --headless --path godot --script res://tests/client_test.gd        # settings, bindings, menu flow, touch
xvfb-run godot --path godot --script res://tests/shot.gd -- /tmp/shot.png # renders a raid frame
xvfb-run godot --path godot --script res://tests/menu_shot.gd -- /tmp/m   # the main menu, setup, controls, results
xvfb-run godot --path godot --script res://tests/shot.gd -- /tmp/city.png city            # a Black Out attack
xvfb-run godot --path godot --script res://tests/shot.gd -- /tmp/frost.png map frost std  # any map, size and class
```

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
