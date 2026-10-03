# v0.9.6.5 work order: the Index, boss weaknesses, and +25% boss health

Status: **plan; all decisions answered by Big U on October 3, except his OK on the Bulldozer's replacement move (Overdrive, section 6).** Nothing is built yet.

A small update with three parts:

1. Turn the **CLASSES** page into an **INDEX** of classes, raiders and bosses.
2. Give every boss a **weakness** to one ammo type.
3. Raise **every boss's health by 25%**.

It also answers the question: which bosses have the most attacks, and which have the fewest?

## 1. How many attacks each boss has

This audit counts each distinct, telegraphed move from the boss AI code (`10-phases-bosses.js`, `10c-blitz.js`, `10d-winter-campaign.js`). A "phase" is a change at low health that powers up an existing move rather than adding a new one.

| Boss | Where | Health now | Attacks | What they are | Phase |
|---|---|---|---|---|---|
| The Demolisher | Yard, 5/10-raid | 620 | **2** | Slow rocket on a red line; every third volley is a 3-rocket fan | none |
| The Butcher | Yard, Riverbend | 760 | **2** | Close blade cut; lane charge that knocks people aside | Enraged under 40%: faster, cuts sooner |
| The Stormcaller | Yard, Quarry | 540 | **1** | Chain lightning on a tracking blue line (stuns, jumps to 2 more) | Fires twice under 50% |
| The Ferryman | Riverbend | 700 | **3** | Harpoon drag; boarding crews; rams a bridge down | Harpoons faster after the bridge |
| The Foreman | Quarry | 760 | **3** | Rock slab throw; burrow and burst up under a wall; rockfall lane | Rockfall only under 50% |
| The Harbinger | Blitzkrieg | 720 | **2** | 3-missile arcing barrage with landing rings; boarding crews | 4 missiles when enraged |
| The Blue Butcher | Blitzkrieg | 780 | **3** | Wall-breaking blue arc; blade cut; lane charge | Enraged: arcs more often |
| The Arsonist | Blitzkrieg | 640 | **1** | Napalm chain down a 4-ring line (burns 10 s) | none |
| The Tempest | Blitzkrieg | 560 | **1** | Twin side-by-side lightning bolts | Fires twice under 50% |
| The Bulldozer | Blitzkrieg | 800 | **1** | Fast lane charge; dazed 3 s if he hits a wall | none |
| The Rime Colossus | Frostpeak, campaign finale | 860 | **2** | Frost rupture (big ring); frost dash leaving a slowing trail | Shorter cooldowns as health drops |
| The Frostbound Butcher | Campaign ch. 1 | 880 | **4** | Blue arc, blade, charge, plus frost rupture | Enraged |
| The Icebound Ferryman | Campaign ch. 2 | 820 | **4** | Harpoon, boarding crews, bridge ram, plus frost rupture | Faster after bridge |
| The Permafrost Foreman | Campaign ch. 3 | 900 | **2** | Bulldozer charge, plus frost rupture | none |

- **Most attacks:** 4, the Frostbound Butcher and the Icebound Ferryman.
- **Fewest attacks:** 1, the Stormcaller, Arsonist, Tempest and Bulldozer.
- **In scope (Big U, D6):** the four 1-attack bosses each get two new attacks that fit what they are. See section 6.

## 2. The INDEX page (replaces the CLASSES page)

- **Nav button:** CLASSES becomes **INDEX**, with the same shield icon. The setup sheet's "ABOUT THE CLASSES" link becomes "OPEN THE INDEX" and opens the Classes tab.
- **Three tabs:**
  - **CLASSES:** today's four class cards, unchanged.
  - **RAIDERS:** the 7 raider types, each with:
    - a short line on what it does;
    - its health;
    - the raid it first shows up in;
    - a small portrait drawn with the in-game character painter.
  - **BOSSES:** one card per boss, grouped by where you meet them (Standard, Blitzkrieg, Winter). Each card shows:
    - portrait, name, health, maps and modes;
    - every attack with its telegraph ("a red lane means…");
    - its low-health phase;
    - its **weakness**.
- **Kept in sync automatically:** every number (health, speed, weakness, first raid) is read from the game's own tables (`BOSSES`, `ETYPES`, the weakness table). The page can't drift from the game. The only hand-written text is the attack descriptions, and each boss already has an intro line for those.
- **Works everywhere:** phone portrait, phone landscape, desktop and controller. The tabs and cards are focusable, and portraits are drawn once and cached, the same way the locker caches its art.
- **Bosses you haven't met:** still shown in full. There's no lock or "???" (see D5).

## 3. Boss weaknesses (ammo types)

- **The four special ammo types:** Armor Piercing, Incendiary, Explosive, Lightning. Players unlock them in the skill tree and load them per raid.
- **How a weakness works:** each boss is weak to one of them. Any bullet carrying that ammo deals **+35% bullet damage** to that boss (Big U, O1). The bonus applies to the bullet's own damage only, not to Incendiary burn ticks or Explosive splash, so it can't stack twice.
- **Standard rounds:** unchanged.
- **Display:**
  - Boss health bar: a small colored tag ("WEAK: INCENDIARY").
  - Damage numbers: a "WEAK" pop the first time a boss takes weak-point damage in a fight.
  - INDEX boss card: the weakness is listed.
- **Network:** the host does the damage math, so guests only need the weakness to draw the tag, and that comes from the shared boss table. No new snapshot fields; protocol goes to `yard-25` because boss health changes.
- **Proposed weaknesses** (themed; D1):

| Weak to | Bosses |
|---|---|
| Armor Piercing | Demolisher, Bulldozer |
| Incendiary | Rime Colossus, Frostbound Butcher, Icebound Ferryman, Permafrost Foreman |
| Explosive | Stormcaller, Foreman, Tempest |
| Lightning | Butcher, Blue Butcher, Arsonist, **Ferryman** and **Harbinger** (Big U: they fight from the water) |

Final split: Armor Piercing 2, Incendiary 4 (all ice), Explosive 3, Lightning 5.

## 4. +25% boss health

- **Change:** every boss's base health ×1.25, in one place, a `BOSS_HP = 1.25` multiplier. It is not 14 separate number edits.
  - Example: Butcher 760 → 950; Rime 860 → 1075.
- **Stacks with the current scaling:** map health (Yard 1.0, Riverbend 1.05, Quarry 1.1), XL (+10%, and each XL twin boss at 90%), crew scaling, and the gauntlet's 110%. A gauntlet boss ends up at 1.1 × 1.25 = 1.375× today's base.
- **Damage:** boss damage is unchanged unless D3 says otherwise.
- **Server:** no change needed. Reward caps are based on time played, not on boss health.

## 6. New attacks for the four 1-attack bosses (Big U, D6)

Each new attack follows the house rules:
- a clear warning shape for about a second before it lands, in the boss's color;
- host-side damage only;
- guests see the warning and the effect through the existing ring, line and particle events (no new snapshot shapes);
- a cooldown so the boss still mixes in his original attack.

Health thresholds stay as they are; the new moves join the rotation from the start of the fight.

**The Stormcaller** (lightning; keeps his distance):
- **Thunderstrike:** three blue rings appear around his target for 1.1 s, then lightning drops from the sky into each one. Each strike deals 30 damage and stuns for 0.5 s. Walls aren't hit.
- **Static Pulse:** when someone gets within 4 tiles, he crackles (a growing blue ring, 0.8 s), then blasts outward. The blast deals 22 damage and knocks everyone back 2 tiles. It punishes rushing him.

**The Tempest** (a bigger storm):
- **Cyclone:** a marked path, then a whirlwind travels down it for 4 s. It shoves players along with it and rips wood walls off their tiles. It deals light damage, 8 per second.
- **Storm Cage:** a ring of lightning posts snaps up around one player. The ring shrinks for 2.5 s; anyone still inside when it closes takes 35 damage and is stunned for 0.8 s. Step out through the gap in the posts.

**The Arsonist** (fire):
- **Flamethrower:** close range. He shows an orange wedge for 0.7 s, then sweeps flame across it for 1.5 s. It deals 12 damage per tick, sets anyone hit burning, and lights wood walls.
- **Ring of Fire:** four rings land in a circle around a target, and napalm fills the ring after 1.2 s, burning for 6 s. The middle stays safe, so you either get out or wait it out.

**The Bulldozer** (machine; charges):
- **Seismic Slam:** he stops and lifts his blade (a yellow ring around him, 0.9 s), then slams. The shockwave goes out to 3.5 tiles, dealing 28 damage, knocking players back and hitting nearby walls hard.
- **Overdrive** (replaces Rubble Spray, Big U: no debris left on the map): his engine roars and three short lanes appear one after another, a zig-zag toward his target (0.5 s warning each). He rams down all three in a row: each hit deals 24 damage and throws you aside. Walls in a lane take a heavy hit, but he doesn't stop or get dazed until the last leg. Nothing is left behind on the map.

**Open:** the damage numbers above are a starting point, tuned to match the existing attacks (the Stormcaller's bolt deals 40, the Butcher's cut 28). They'll be checked in playtests.

**Index:** these attacks appear on each boss's card, so all four go from 1 attack to 3.

**Network:** guests draw everything from existing events (rings, zap lines, fire patches, slab blocks). The one new piece is the Cyclone's position, sent the same way the Blue Butcher's arcs are. That makes it a protocol bump to `yard-25`, which this update needs anyway.

## 5. Tests and release

- New `index_page` test:
  - all three tabs render;
  - every boss in `BOSSES` and every raider in `ETYPES` has a card;
  - the numbers match the tables;
  - the page fits at three viewport sizes;
  - controller focus moves through it.
- New `boss_weakness` test:
  - a matching round deals 1.35× bullet damage and a non-matching one 1×;
  - burn and splash get no bonus;
  - the health-bar tag shows;
  - guests see the same tag.
- `boss_hp` check: every boss spawns with 1.25× health and the gauntlet multiplier still applies.
- New `boss_attacks` test: each of the 8 new attacks shows its warning, deals its damage only inside the marked area, respects its cooldown, and replays on a guest. A long fight checks the boss still uses his original attack too.
- Update the tests that assert boss health or the CLASSES page (`v090`, `blitz_bosses`, `campaign_gauntlet`, `presentation`, `taborder`, and others found by search).
- Release: full suite, screenshots at three sizes, Big U's approval, then merge.
- Release number: v0.9.6.5, protocol `yard-25`. No server migration.

## Decisions for Big U

| # | Question | Proposal |
|---|---|---|
| D1 | Weakness list | The table above. Or winter bosses keep their base boss's weakness (only Rime on Incendiary) |
| D2 | Weakness bonus | +50% bullet damage. Alternatives: +25%, or +100% (double) |
| D3 | "+25% to every boss": health only? | Health only. Damage stays the same |
| D4 | Gauntlet health | Stack the multipliers (1.1 × 1.25 = 1.375×). Or keep gauntlet bosses at today's 110% |
| D5 | Bosses you haven't met in the Index | Show everything. Alternative: silhouette and "???" until first seen |
| D6 | The four 1-attack bosses | Leave them for a later update. Alternative: give each a second attack now (makes this a bigger update) |

### Big U's answers (October 3)

- **D1:** the list is right, except **the Ferryman is weak to Lightning** (he's in the water).
- **D3:** the +25% is total boss health.
- **D4:** stack it with the gauntlet's 110%.
- **D5:** show every boss in the Index.
- **D6:** give each 1-attack boss about **two more attacks** that fit the boss (section 6).

### Still open

| # | Question | Proposal |
|---|---|---|
| O1 | Weakness bonus size | **Answered:** +35% damage from bullets that win the matchup |
| O2 | Harbinger and Icebound Ferryman | **Answered:** Harbinger weak to Lightning; Icebound Ferryman weak to Incendiary |
| O3 | The eight new attacks | **Answered:** yes, but the Bulldozer's Rubble Spray is replaced (debris on the map could cause trouble for future updates). The replacement, Overdrive, waits for Big U's OK |
