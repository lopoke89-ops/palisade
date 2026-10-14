# Palisade: Godot client

The Godot 4.7 port of the browser game, built against v0.10.9 (`4c26769`, protocol `yard-29`).
The plan is in `dev/plans/godot-conversion-blueprint.md`. This is **Phase 1, the fidelity slice**: the Yard on Normal, the Soldier, Delgado, all seven raider types, 13 of the browser's 16 bosses, the armory, the skill tree, sound and music.

## Run it

1. Install Godot 4.7.x (standard build, not .NET).
2. Open `godot/project.godot` in the editor.
3. Press F5.

Controls:

| Action | Keys |
|---|---|
| Move | WASD / arrows |
| Aim and fire | mouse, left button |
| Build or repair the faced tile | Space |
| Material | 1 / 2 / 3 |
| Wall or door | F |
| Grenade at the cursor | G |
| Rocket at the cursor (5, +2 each build phase) | Q |
| Armory, at the stake between raids | E / U |
| Delgado: follow you / defend the stake | H |
| Start the raid early | Enter |
| Pause | Esc / P |
| Skill tree (paused or at the end of a run) | K |
| Developer: bring in the next boss (editor runs only) | F8 |

## What is ported

Each part follows the browser code, with function names kept so the two read side by side.

| Area | Browser source | Godot |
|---|---|---|
| Tuning constants, `hash`, walls | `01-setup.js`, `04-state-armory.js` | `scripts/pal.gd` |
| Projection and camera | `02-view.js`, `17-scenery.js` | `scripts/iso_view.gd` |
| Sim | `06-world.js`, `09-actions.js`, `10-phases-bosses.js`, `12-players.js`, `14-raiders.js` | `scripts/sim.gd` |
| Delgado | `13-dell.js`, `13b-commands-recovery.js` | `scripts/sim.gd` |
| Drawing and HUD | `15-render.js`, `16-characters.js`, `17-scenery.js` | `scripts/main.gd` |
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
- **Armory:** spend salvage at the stake between raids. Kills pay the browser's bounties.
  - The five upgrades go to 8 levels at the browser's costs and steps.
  - Delgado's level, the stake repair (+50 for 25), and the four ammo types, at skill rank 0 until the account skill tree is ported.
  - The Soldier's rockets.

## Not yet

These are later phases:
- **Accounts:** the skill tree saves locally until then.
- **Ferryman bosses:** they need the river map.
- **Progression:** armory, perks and mods.
- **Other content:** maps, elevation, other classes, difficulties.
- **Presentation:** cosmetics, lighting, trees and the fence.
- **Music:** the menu and finale tracks, and the casino playlist.
- **Network:** online play (PeerJS cross-play probe, casino relay client).

The character figure is a cut-down `drawPerson` without wardrobe items.

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
xvfb-run godot --path godot --script res://tests/shot.gd -- /tmp/shot.png # renders a raid frame
```

`sim_test.gd` checks the following:
- `hash` matches the browser bit for bit;
- the Yard layout, projection, build rules and costs, gathering, blast damage and salvage;
- the raid mix against the browser's `waveMix` for 15 raid and crew-size cases;
- what each raider type does: the shield stopping frontal fire, satchels breaching, bottles lighting wood, medics healing, spotters marking;
- Delgado building the perimeter and reviving you;
- the boss raid mix and order, each boss's attack, boss bounty;
- all 13 bosses fight a moving soldier, and each uses its own warnings and moves;
- frost slow, and the Foreman out of reach underground;
- skill points, costs, gates, perks, armor-piercing rank 4 and reset;
- every armory purchase against the browser's numbers, the shop rules, ammo effects, bounties and rockets;
- a bot playing raid 1, then a whole five-raid game with Delgado (it shops between raids and fires rockets at the boss);
- same seed + same inputs = same game.

Note: `Vector2` is 32-bit in Godot, while the browser's numbers are 64-bit. Positions and timers are kept as 64-bit floats in the sim; only directions use `Vector2`.
