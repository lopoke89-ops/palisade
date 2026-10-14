# Palisade: Godot client

The Godot 4.7 port of the browser game, built against v0.10.9 (`4c26769`, protocol `yard-29`).
The plan is in `dev/plans/godot-conversion-blueprint.md`. This is **Phase 1, the first fidelity slice**.

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
| Grenade at the cursor | G / Q |
| Start the raid early | Enter |
| Pause | Esc / P |

## What is ported

Each part follows the browser code, with function names kept so the two read side by side.

| Area | Browser source | Godot |
|---|---|---|
| Tuning constants, `hash`, walls | `01-setup.js`, `04-state-armory.js` | `scripts/pal.gd` |
| Projection and camera | `02-view.js`, `17-scenery.js` | `scripts/iso_view.gd` |
| Sim | `06-world.js`, `09-actions.js`, `10-phases-bosses.js`, `12-players.js`, `14-raiders.js` | `scripts/sim.gd` |
| Drawing and HUD | `15-render.js`, `16-characters.js`, `17-scenery.js` | `scripts/main.gd` |

What `sim.gd` covers:
- **Pathing and collision:** the Dijkstra flow field, `bestStep`, `moveEnt`, `losClear`.
- **Building:** place, upgrade, repair and door.
- **Soldier:** the burst carbine and grenades.
- **Gathering.**
- **Damage:** bullet sub-stepping and wall hit chances, explosions with fire, salvage from ruins, downed and respawn.
- **Raids:** the Yard layout and the raid and build loop to a five-raid win.
- **Riflemen:** their full AI.

## Not yet

These are later phases:
- **Raiders:** the other six types and bosses.
- **Delgado:** his AI (for now he holds his post at the stake and can be revived).
- **Progression:** armory, perks and mods.
- **Other content:** maps, elevation, other classes.
- **Presentation:** cosmetics, audio, lighting and trees.
- **Network:** online play (PeerJS cross-play probe, casino relay client).

The character figure is a cut-down `drawPerson` without wardrobe items.

## Tests

```sh
godot --headless --path godot --script res://tests/sim_test.gd           # exit 0 = pass
xvfb-run godot --path godot --script res://tests/shot.gd -- /tmp/shot.png # renders a raid frame
```

`sim_test.gd` checks the following:
- `hash` matches the browser bit for bit;
- the Yard layout, projection, build rules and costs, gathering, blast damage and salvage;
- a bot playing raid 1 to the end;
- same seed + same inputs = same game.

Note: `Vector2` is 32-bit in Godot, while the browser's numbers are 64-bit. Positions and timers are kept as 64-bit floats in the sim; only directions use `Vector2`.
