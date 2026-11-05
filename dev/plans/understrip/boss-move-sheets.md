# THE UNDERSTRIP: boss move sheets (M0)

**Status:** M0 draft for the director's sign-off. Work order sections 8.2–8.5. The numbers are starting values for M4's balance pass; `tables/bosses.csv` holds the same health figures.

## How to read a sheet

Each move is written the way the game already writes boss moves (`MOVE` in `dev/src/js/10e-boss-moves.js`): a telegraph time (`tell`), a size, damage, a cooldown (`cd`), and what the player does about it.

- **Damage** is before difficulty (×0.55 Easy, ×0.85 Normal, ×1.15 Hard, as `DIFF` scales every boss now). For scale: player health is 90–115 before armor, and the Stormcaller's Thunderstrike does 30.
- **Telegraphs are shape-coded** (section 12), so each one reads without colour:

  | Shape | Means | Already in the game as |
  |---|---|---|
  | **Line / lane** | something travels down it | the Demolisher's rocket line, the Butcher's charge lane |
  | **Circle** | something lands there | Thunderstrike's points, Seismic Slam |
  | **Ring** | a wave moves outward: roll through it or be outside it | Static Pulse |
  | **Wedge / cone** | a sweep in front of the boss | the Butcher's cut, the Flamethrower |

- **No telegraph is ever shorter than 0.6 s**, on any difficulty, in any stage, the finale's desperate stage included. Faster bosses get shorter cooldowns, never shorter warnings.
- **Health** is scaled as every boss's is now (`spawnBoss`: ×`BOSS_HP` 1.25, ×difficulty, +35% per extra player). The "effective" figures are for one player on Normal, both stages together.

## The two-stage framework (all four)

| Part | Rule |
|---|---|
| Stage 2 starts | At 50% health (the Visitor also has a desperate stage at 10%) |
| Transition | 3 s with no damage taken: the boss's "breaks" animation and the arena change. Telegraphs already on the ground finish; no new ones start |
| Health bar | Refills as a second bar in a second colour (the boss colour, then white-hot). Two pips under the name show the stage |
| Network | The stage travels in the boss's existing `st` field family, so a guest draws the same thing from the snapshot (the way the v0.9.6.5 moves did, states 20–30). The Supreme Destroyer uses 40–49 and the winter bosses 101–103, so the new states take 60–89 |
| Gate | Seals when the first player steps through; opens again only on a win or a squad wipe |
| Defeat | One guaranteed drop per player (`tables/loot_sources.csv`), the arena's shrine lights, the exit wakes |

---

## 8.2 THE PIT BOSS · region 1, The Flood Tunnels

> *The casino's floor boss, in a suit that has seen better nights. He tosses chips that go off, and he always has more security on call.*

**Arena:** the old count room (`r1_boss_pitboss` in the room kit), 24 × 24 tiles: low floor in the middle, a dry rim round the edge, four pillars, slot machines for cover.
**Health:** base 2,370 (**2,963 effective**; v0.12.4: each boss 50% more than the one before). **Speed:** 1.6, then 2.1. **Colour:** `#e2b436` (chip gold), then `#ff6a3a`.
**Intro line:** "He throws chips that explode: a ring shows where each one lands. When his jacket comes off, the floor floods and he charges."

### Stage 1

| Move | Telegraph | Tell | Size | Damage | Cooldown | Counter |
|---|---|---|---|---|---|---|
| **Chip Toss** | circle at each landing spot, filling | 0.9 s | 2 chips, radius 1.4 each, up to 8 tiles away | 26 | 3.5 s | Step out of the circle |
| **Cash-Box Swing** (when someone is within 2 tiles) | wedge in front | 0.7 s | range 1.8, half-angle 0.9 rad | 22 + knock 1 tile | 2.5 s | Back off or roll behind him |
| **Call Security** | a radio squawk and a banner | none needed (no damage) | 2 security raiders (rifle) from the arena's doorway | none | at 75% health | Kill them, or keep them busy |

### Transition (50%)
He tears his jacket off. The low floor (`,`) floods ankle-deep for the rest of the fight: half speed for players on it, as Riverbend's low banks do now. The dry rim stays dry.

### Stage 2

| Move | Telegraph | Tell | Size | Damage | Cooldown | Counter |
|---|---|---|---|---|---|---|
| **Card Spray** | cone | 0.7 s | range 5, half-angle 0.45 rad, 6 cards | 8 per card | 3 s | Leave the cone, or roll through it |
| **Floor Rush** | lane, to the far wall | 0.9 s | width 1.2 tiles, speed 8 | 32 + knock 1.5 | 6 s | Step out of the lane; he stops dazed for 1 s at the wall (the punish window) |
| **Chip Toss** | as stage 1 | 0.9 s | 3 chips | 26 | 3 s | As stage 1 |
| **Call Security** | as stage 1 | | 2 raiders (one shield) | | at 25% health | |

**Signature drop:** TIE-PIN (perk: +1 salvage a kill).
**Reuses:** the Demolisher's rocket code for chips (an arc, no trail); `bladeSlash` for the swing; the Butcher's charge (`st 2 → 3`) for the rush; Riverbend's `floodOn` for the flood, kept to the arena's tiles.

---

## 8.3 THE CUSTODIAN · region 2, Shelter 7

> *The shelter's caretaker robot, still cleaning after seventy years, and still keeping people in.*

**Arena:** the shelter's main hall, with four blast doors across it on a rhythm.
**Health:** base 3,556 (**4,445 effective**). **Speed:** 1.0, then 1.2. **Colour:** `#9bbf5a` (shelter olive), then `#ff3a2a` (emergency red).
**Intro line:** "A shock mop and the shelter's own doors. Watch the light over each door: amber means it's about to slam."

### Stage 1

| Move | Telegraph | Tell | Size | Damage | Cooldown | Counter |
|---|---|---|---|---|---|---|
| **Mop Arc** | wedge | 0.9 s | range 3, half-angle 1.1 rad | 24 and a 0.6 s slow; leaves a strip of live water for 3 s (8 HP/s) | 3 s | Back out of the wedge; don't stand in the strip |
| **Door Rhythm** (the arena, not the boss) | the light over the door goes amber, then red | 1.0 s | each door's tile line | 40 + push to the nearer side | each door closes for 3 s every 8 s, out of step | Don't stand in a doorway when it's amber |
| **Sweep** (no target in reach) | | | moves to the furthest player | | | |

### Transition (50%)
Its casing cracks; the shelter goes to red emergency light (lighting change, the brightness floor still applies).

### Stage 2

| Move | Telegraph | Tell | Size | Damage | Cooldown | Counter |
|---|---|---|---|---|---|---|
| **Crush Lane** | lane along a door's track | 1.0 s | 2 door lanes at once | 45 + push | 7 s | Step out of both lanes |
| **Gas Flood** | one quarter of the hall: a hiss and a green tint that grows | 2.0 s | a quarter of the arena, for 8 s | 10 HP/s while inside | 14 s | Leave that quarter; IRON LUNG halves it |
| **Ceiling Turret** | line on the **furthest** player | 0.8 s | 3-shot burst | 9 each | 6 s | Break line of sight; nobody can hang back safely |
| **Mop Arc** | as stage 1 | 0.9 s | | 24 | 2.5 s | |

**Signature drop:** a flare launcher (epic).
**Reuses:** the wedge from `inWedge`; Thunderstrike's line warning for the turret; door lanes are wall tiles that open and close (the barricade work in M2 gives the code for a wall that comes and goes).

---

## 8.4 THE GATEKEEPER · region 3, Area 67

> *A security pilot in a walking suit, guarding the last lab door. Break the suit and you're fighting two things.*

**Arena:** the lab's loading bay, with low crates for cover.
**Health:** base 5,333 (**6,666 effective**). Stage 2's suit has the second half; the pilot has another 20% on top. **Speed:** 0.9; in stage 2 the suit 0.8, the pilot 2.4. **Colour:** `#cfd8dc` (lab white), then the pilot `#7cff6b`.
**Intro line:** "Rockets fall where the circles are. His shield blocks shots from the front: go round it."

### Stage 1

| Move | Telegraph | Tell | Size | Damage | Cooldown | Counter |
|---|---|---|---|---|---|---|
| **Rocket Rain** | circles | 1.1 s | 4 circles round the target, radius 1.2 | 28 each | 5 s | Find the gap |
| **Shield Wall** | the shield rises in front, glowing | 0.6 s | blocks every shot from the front 120° for 4 s | none | 10 s | Flank, or use armor-piercing ammo |
| **Stomp** (someone within 2 tiles) | ring from his feet | 0.8 s | radius 2.5 | 20 + push 1.5 | 4 s | Get out, or roll through |

### Transition (50%)
The pilot ejects. The suit keeps fighting, empty. **Killing either one ends the fight.**

### Stage 2

| Target | Move | Telegraph | Tell | Size | Damage | Cooldown | Counter |
|---|---|---|---|---|---|---|---|
| Suit (slow, heavy: the stage-2 bar) | **Ground Pound** | circle | 1.2 s | radius 3 | 34 | 5 s | Out of the circle |
| Suit | **Rocket Rain** | circles | 1.1 s | 3 circles | 28 | 7 s | |
| Pilot (fast, weak: 20% more health) | **Sidearm** | line | 0.6 s | 3 shots | 9 each | 2 s | Strafe; he's the quick kill if you can catch him |
| Pilot | **Dive** | none (it's a dodge) | | rolls away every 4 s | | | Wait out the roll, then shoot |

**Signature drop:** the anti-grav launcher (legendary).
**Reuses:** Thunderstrike's circles; Static Pulse's ring for the stomp; the shield raider's frontal block (`ETYPES.shield`) on a boss; the second body is a second enemy that shares the boss bar's stage.

---

## 8.5 THE VISITOR · the finale, Area 67 core

> *What the government kept in the dark, in a field that is failing.*

**Arena:** the containment hall: specimen tanks round the walls, the field in the middle.
**Health:** base 8,000 (**10,000 effective**, solo on Normal): 50% stage 1, 40% stage 2, then 10% desperate. **Speed:** 1.2, then 1.4. **Colour:** `#b8a8ff`, then its own glow only.
**Intro line:** "Psychic rings: roll through them. When the lights go out, a flash shows where it will be next."

### Stage 1

| Move | Telegraph | Tell | Size | Damage | Cooldown | Counter |
|---|---|---|---|---|---|---|
| **Psychic Pulse** | a ring that glows, then moves out | 0.8 s, then travels 6 tiles/s | out to 9 tiles, 0.6 tiles thick | 24 | 4 s | Roll through it (`rollSafe`) or be outside 9 tiles |
| **Tank Throw** | a circle with the tank's shadow growing in it | 1.2 s | radius 1.3 | 30; leaves acid for 4 s (6 HP/s) | 6 s | Out of the circle, then out of the acid |

### Transition (50%): the scripted blackout
The containment fails and the room's lights go out. Only the Visitor's glow, players' light cones, flares and muzzle flashes light the room (the brightness floor still applies; Reduce Motion softens the flicker).

### Stage 2

| Move | Telegraph | Tell | Size | Damage | Cooldown | Counter |
|---|---|---|---|---|---|---|
| **Blink** | a white flash marks the spot it will appear | 0.9 s | arrives with a ring, radius 2 | 16 | 5 s | Move away from the flash |
| **Drone Swarm** | a hum and a banner | none needed | 6 drones (10 HP each; at most 12 alive) | 4 on touch | 14 s | Light kills them: they take double damage in a light cone |
| **Gravity Well** | a swirling ring | 1.0 s | radius 6; pulls 1.2 tiles/s for 3 s | 12 HP/s in the middle (radius 1.2) | 12 s | Walk out against the pull; LEAD BOOTS ignores it |
| **Psychic Pulse** | as stage 1 | 0.8 s | | 24 | 4 s | |

### Desperate (10%)
Every cooldown ×0.7; telegraphs unchanged. No transition pause: it simply gets faster, and the music swells.

**Signature drops:** the Visitor skin (the first kill, guaranteed) and THE VISITOR'S EYE (gold relic).
**Reuses:** Static Pulse for the rings; Thunderstrike's circle for the tank; the drones are a new small enemy type (`ECODE` gains entries at the end, never reordered).

---

## Elites (section 8.1)

| Elite | Base | Extra trick | Telegraph | Tell | Damage |
|---|---|---|---|---|---|
| **Charger** | shield raider, 165 HP | charges down a lane | lane | 0.8 s | 24 + knock |
| **Caller** | spotter, 75 HP | a laser on a player for 1.5 s calls a mortar | circle, radius 1.5 | 1.2 s | 26 |

## For the director
- [ ] Each boss's moves feel fair on paper (every one has a telegraph of at least 0.6 s and a clear answer).
- [ ] The health figures (1,200 / 1,800 / 2,400 / 3,500 effective) as the M4 starting point.
- [ ] Stage 2 of the Gatekeeper: killing **either** body ends it (as the work order says).
