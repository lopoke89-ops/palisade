# Work order: THE UNDERSTRIP, a dungeon-crawler mode

| | |
|---|---|
| **Work order** | A new co-op game mode, a new case and its cosmetics (number to assign) |
| **Working title** | THE UNDERSTRIP (placeholder; final name is decision D1) |
| **Platform** | **Browser build only** (`dev/src/`). The Godot port (`godot/`) is a later, separate sweep; section 15 says how to keep that sweep mechanical. |
| **Starts from** | v0.11.1 (`main`), network protocol `yard-30` |
| **Director** | Big U (lopoke89-ops) |
| **Status** | M0 signed off (November 4, 2026). **M1 (the region 1 vertical slice) built**, report in `dev/evidence/2026-11-04-understrip-m1/`; the director's fun test is next |

---

## 0. How to use this work order

This is the brief for whoever builds the mode, whether a person or an AI agent. Read it top to bottom once. Then work milestone by milestone (section 13): each milestone ends with acceptance checks and a build the director plays before the next one starts.

Standing rules for the implementer:
- Edit only `dev/src/` (and `dev/supabase/`, `dev/test/` where stated). Never edit the built `index.html` at the repo root. Rebuild with `python dev/build.py`.
- New script files slot into the numbered order (`dev/src/js/ORDER.txt`) and get a line there.
- Every new test gets a line in `dev/test/suite.txt` with the tag `understrip`.
- Existing modes must play exactly as before. The full suite (`./run_all.sh --build`) passes at the end of every milestone.
- Anything marked **DECISION** is the director's call. Don't guess: ask, and record the answer in section 16.
- Anything marked **LEGAL** needs the director's sign-off before its art is made.

---

## 1. The pitch

> Under the Las Vegas Strip runs a maze of flood tunnels nobody maps. Your squad goes down to find what the casinos buried, and keeps going down: through the tunnels, into a sealed Cold War shelter, and finally into Area 67, where whatever the government hid is still awake.

A slow, tense, co-op dungeon crawl. It takes its spirit from Souls-like games (hard, fair, readable fights; bosses that change halfway; rest points that bring the dead back; what you carry is at risk when you die) and from dungeon crawlers (procedural rooms, random merchants, loot that changes a run). It's set in Palisade's world and uses its existing classes, raiders and gunplay.

### Design pillars (every feature must serve at least one)
1. **Claustrophobia.** Tight spaces, little light, enemies you hear before you see. The player should feel short on room, light, ammo and time to think.
2. **Earned victory.** Every boss attack is telegraphed, and every death is the player's lesson, never a cheap shot. Hard, but fair.
3. **The descent.** Each region feels deeper, stranger and less human than the last: Vegas grime, then Cold War steel, then alien.
4. **The find.** Merchants and loot make every run different, and a lucky find can make a run.

### What this mode is not
- Not a base-builder. The stake, walls and build phases of the other modes are switched off here (barricades come back as consumables, section 6.6).
- Not open world: one level at a time, then an exit to the next.
- Not a copy of any existing game. Mechanics inspired by Souls-like games are fine; their names, terms, UI and art are not (section 3).

---

## 2. Scope

### In scope for v1
- The mode, playable solo and in online co-op (up to the game's existing player limit).
- Three regions, each made of levels built from hand-made rooms joined at random (section 5).
- Four bosses, each with two stages: one per region plus the finale (section 8).
- Random merchants, a new in-run loot layer, rest points, and healing charges (sections 6–7).
- One new case with its cosmetics: 10 skins with their own models, plus 5 each of hats, tracers, kill effects and lobby backgrounds (section 9).
- Placeholder music: the existing casino ambience tracks (section 4.3).
- Tests, balance pass, a performance budget, and accessibility (sections 11–12).

### Out of scope for v1 (backlog)
- PvP in the mode.
- New player classes.
- Original music (placeholder only; a music work order follows).
- Seamless streaming between levels (section 5.1 explains why).
- Leaderboards and daily seeds (designed for later: generation is seeded from the start).
- The Godot port.

---

## 3. References and IP guardrails (LEGAL)

Inspiration is welcome. Copying is not. Each reference below has a clear line, and the art team works to the "do" column.

| Reference | Do | Don't |
|---|---|---|
| Souls-like games | Telegraphed boss moves, two-stage bosses, rest points that respawn enemies, dropped currency you can recover, shortcuts, boss gates | Use the names or terms ("Estus", "bonfire", "souls", "YOU DIED" in that styling), their UI layouts, or any of their characters or areas |
| *Fallout: New Vegas* (the vault) | An original Cold War fallout shelter with **our own** brand and colours | Use "Vault-Tec", "Vault Boy", the gear logo, the blue-and-yellow numbered jumpsuit, "Vault 21"-style naming, or the Pip-Boy |
| Elvis | A generic "King of the Strip" lounge-singer impersonator: pompadour, rhinestone jumpsuit, gold shades, sideburns | Use the name "Elvis", his face or likeness, his song titles or lyrics, or "TCB" lightning bolts. Elvis's name and likeness are actively protected; this is the **highest-risk item** on the list |
| Area 51 | "Area 67", fictional and ours. Generic grey aliens, saucers and lab tropes are fine | Use real military unit insignia, real agency seals, or US government logos |
| General / dictator skin | A fictional generalissimo: invented medals, invented flag, and a sash | Resemble any real dictator; use real-world regime symbols (any fascist or totalitarian insignia), real flags or real military rank badges |
| Western skins | Gunslinger, sheriff and gambler archetypes | Use Native American headdresses or other sacred dress as costume |
| The real Las Vegas tunnels | Atmosphere: graffiti, flood debris, dripping concrete | Present unhoused people as enemies or as a joke. The tunnels' real residents are not monsters; our enemies are the game's raiders and what the casinos buried |
| Casino brands | Our own Palisade Falls Casino | Use real casino names, logos, or the "Welcome to Fabulous Las Vegas" sign as-is (a generic retro neon sign is fine) |

**Acceptance:** before any skin or region art is made, the director signs off a one-page mood board per item against this table.

---

## 4. World, lore and audio

### 4.1 The story in one paragraph
The Palisade Falls Casino didn't just launder money; it sat on top of something. Its flood tunnels connect to a 1950s civil-defence shelter the casino owners bought and sealed, and the shelter's deepest door opens onto Area 67. The squad follows the casino's own security forces (the raiders) down, fighting what the casino left behind and finally what the government left in the dark.

### 4.2 Regions

| # | Region | Feel | Light | Hazards | Boss |
|---|---|---|---|---|---|
| 1 | **The Flood Tunnels** | Wet concrete, graffiti, dumped slot machines, casino overflow pipes | Flashlights, sparse work lamps, neon leaking through grates | Flash floods (reuse Riverbend's flood logic), slippery debris, collapsing tunnels | The Pit Boss (8.2) |
| 2 | **Shelter 7** (placeholder name, original brand; DECISION D4) | Cold War steel, bunk rooms, ration stores, propaganda posters for our own fictional agency | Flickering fluorescents on timers, red emergency lighting | Blast doors that seal behind you, gas leaks, radiation pockets | The Custodian (8.3) |
| 3 | **Area 67** | White labs, specimen tanks, alien growth over the concrete | Cold lab light that fails as alien growth spreads; bioluminescence | Low gravity rooms (slower bullets and grenades), containment alarms that call reinforcements, acid pools | The Gatekeeper (8.4), then the finale, The Visitor (8.5) |

Each region runs about **15–20 minutes** for a competent squad: about 50–60 minutes for a full run.

### 4.3 Music (placeholder)
- Use the existing casino ambience tracks (`CASINO` in `03-audio.js`: `casino_1` to `casino_11`). The story explains them: you hear the casino's own piped muzak bleeding down through the vents.
- **Treatment, so the reuse feels intended:**
  - **Region 1:** the tracks play muffled, through a low-pass filter, as if heard through concrete.
  - **Region 2:** more muffled again, with a reverb tail.
  - **Region 3:** the music cuts out; only ambience plays until the finale.
  - **Boss fights:** the existing boss and raid tracks.
- **Acceptance:** the volume and music settings and the existing music tests (`casino_music`, `reel_music`) are unaffected.

---

## 5. Run structure

### 5.1 Decision: levels joined by exits, rooms spliced inside each level
The two options from the brief, with the recommendation:

| | Seamless splicing between regions | **Exit between levels (recommended)** |
|---|---|---|
| How | One continuous world, loading map chunks as you walk | Each level is its own map; reaching its exit loads the next |
| Engine fit | The game's maps are fixed N×N tile grids (`layMap`). Streaming would mean rewriting pathing, lighting, collision and networking for chunks, in the browser **and** again in Godot | Reuses what exists: Operation Whiteout already moves the squad between maps with continuity (`startMapEvac` / `finishMapEvac` in `10d-winter-campaign.js`), and Blitz has a timed evacuation (`openEvac` / `evacTick` in `10c-blitz.js`) |
| Feel | Very immersive | A short, staged transition: the lift going down, the blast door opening. It also gives natural pause and save points |
| Risk | High: the schedule's biggest technical risk | Low |

**The best of both:** inside a level, hand-made **rooms are spliced together at random** from a seed (5.2). So every level feels new, but the engine still sees one ordinary map.

### 5.2 How a level is built
- **A seed** picks a layout, so the host and guests build the same level from the same number. The same seed also makes daily seeds possible later.
- **Room kit:** each region has a library of hand-made rooms of a few sizes, with marked doorways:
  - corridors, at most 1–2 tiles wide, the claustrophobic default;
  - junctions;
  - small rooms;
  - one "breather" room per level, the rest point (6.2);
  - one merchant alcove or more (7.1);
  - one boss arena per region (on the last level).
- **Layout rules:**
  - The critical path from entrance to exit is 8–12 rooms.
  - 30–40% of rooms sit on side branches: loot, merchants, risk.
  - At least one **shortcut** per level, a door that opens from one side only, so a squad that dies near the end doesn't redo it all.
- **Size:** a level's map is 48×48 to 64×64 tiles, no bigger than the City Black Out map (64×64), so performance stays within known limits.
- **Levels per region:** 2 normal levels plus a boss level (DECISION D2: 2 or 3).

### 5.3 The exit
- Each level ends at an exit: a freight lift, a blast door, a lab airlock.
- **The squad gathers at it:** everyone alive stands in the exit ring for 3 seconds (reuse the Blitz evac ring logic), then the next level loads.
- **Downed players** come along at 25% health. **Dead players** come back at the next level's start, without their dropped currency (6.4).
- **Between levels:** a short results card (kills, loot found, time) and a chance to spend at a "lift merchant" (7.1).

### 5.4 Death and failure
- **Solo:** death sends you back to the last rest point (6.2), with the level's enemies respawned and your currency left where you died.
- **Co-op:** a downed player can be revived (the existing downed and revive rules). If **everyone** is down at once, the whole squad goes back to the last rest point.
- **A run fails** when the squad's **shared lives**, a pool shown on the HUD, run out:
  - Start with 3, and +1 for each region cleared.
  - Each time the whole squad goes back to a rest point, one is lost.
  - A failed run still pays out (section 9.4), so a failed attempt is never worthless.

---

## 6. Core mechanics

### 6.1 Claustrophobia: light, sound, space
- **Light:** every player carries a light cone of about 5 tiles, aimed where they're aiming, plus a dim 1.5-tile glow around them. Reuse the night lighting already in `15-render.js` (the light "holes" the City uses).
  - Region lamps and neon are fixed lights.
  - Muzzle flashes light the area for a moment, so firing gives your position away and also shows you the room.
- **Sound before sight:** raider footsteps and voice barks play positionally before they come into view. Give each enemy type a distinct sound so experienced players can tell what's coming.
- **Space:** corridors 1–2 tiles wide, so grenades and the Grenadier's spread matter. Raiders flank through side passages instead of coming straight down the main one.
- **Camera:** about 15% tighter zoom than the other modes (within the settings' zoom limits), so less is on screen.
- **Accessibility floor:** a "Dungeon brightness" setting raises the minimum light (section 12). Claustrophobia must never mean "can't see the telegraph".

### 6.2 Rest points (our own term: **Neon Shrines**, DECISION D3 for the name)
- **What it is:** an old casino sign half-buried in the wall, which flickers on when you touch it.
- **Resting at one:**
  - refills healing charges (6.3) and ammo;
  - sets the respawn point;
  - **respawns the level's regular enemies** (not bosses or elites already killed);
  - opens the "shrine merchant", if this shrine has one.
- **Count:** one per level, in its breather room, plus one before each boss arena.

### 6.3 Healing charges (our own term: **Flasks of Lucky Juice**, D3)
- **Count:** 3 charges at the start, refilled at shrines. Merchants sell +1 capacity (max 6) and stronger heals.
- **Using one:** a heal takes 0.8 s, during which you walk slowly. It's a commitment, not an instant button: the Souls-like rule.
- **No passive healing (D9):** the other modes heal you out of a fight; that's off here. Healing comes only from charges, the Quartermaster's existing revive (D11), and some loot.

### 6.4 Dropped currency
- **The currency:** the in-run currency is **salvage**, which the game already uses for armory upgrades (`UPG` in `04-state-armory.js`).
- **On death:** you drop all your unspent salvage where you died. Get back to it, alive, to pick it up. Die again first and it's gone.
- **In co-op:** each player's drop is their own, but a teammate can stand on it to "hold" it from despawning until the owner arrives.
- **Never shards.** Shards (bought, or won in the casino) are never dropped, spent at merchants, or at risk in this mode. This keeps the real-money economy out of the death rules.

### 6.5 Dodge, stamina and pace
- **Dodge:** every class already has a roll (v0.11.0, and v0.11.1 rolls the way you're moving): `ROLL` in `09-actions.js`, 2 tiles in 0.55 s, a 3 s cooldown, invulnerable from 0.1 s to 0.4 s (`rollSafe`). It's the mode's core defensive move. DECISION D5: keep its numbers, or give this mode a shorter cooldown so dodging carries the fights.
- **Stamina:** no stamina bar in v1. It's a big change to every class's feel; test it in M1, and add it only if fights feel too spammable.

### 6.6 Building
- **Walls and the stake:** off. There's no build phase and no stake to defend.
- **Barricades** come back as a consumable, bought or found. A one-tile barricade placed in a doorway, with low HP, buys a few seconds in a corridor fight. It reuses the wall code with a new item type.

---

## 7. Merchants and loot

### 7.1 Merchants

| Merchant | Where | Sells | Character |
|---|---|---|---|
| **The Tunnel Trader** | Random side rooms, 1–2 per level | Ammo, healing charges, consumables, common and rare weapons | A casino cashier who never came back up |
| **The Shrine Keeper** | At some rest points | Upgrades: the existing `UPG` lines, carried over | A cleaning robot that kept working after everyone left |
| **The Collector** | Rarely: 1 in 3 levels, always on a side branch, guarded | Epic and legendary weapons, perks, a single "relic" | A stranger in a tuxedo who doesn't age (lore hook for the finale) |
| **The Lift Merchant** | Between levels (5.3) | A small random pick of everything | Rides the freight lift with you |

- **Placement:** set by the level seed, so every player in a co-op game sees the same merchants with the same stock.
- **Stock:**
  - Each merchant rolls 4–6 items from its region's loot table (7.3), weighted by rarity, using the rarity tiers that already exist (`RAR` in `18-cosmetics.js`: common, rare, epic, legendary, gold).
  - Gold items are only ever sold by the Collector.
- **Opening one:** the existing armory screen, with a merchant variant. `canShop` in `04-state-armory.js` already allows buying away from the stake (Black Out uses `boNearHeld`), and gains "near a merchant".
- **In co-op:** stock is per player (everyone can buy the same thing) unless an item is marked unique.

### 7.2 Weapons (the biggest new system; DECISION D6)
- **Today:** each class has one gun (`CLASSES` in `01-setup.js`).
- **v1 adds a second weapon slot,** held for the run and lost at the end. Merchants and loot fill it with region-themed weapons:
  - **Region 1:** a sawn-off double barrel, a casino security taser, a nail gun.
  - **Region 2:** a Cold War submachine gun, a flare launcher that lights a room for 10 s (it ties straight into the claustrophobia pillar), a riot shotgun.
  - **Region 3:** a lab laser that bounces, an alien pistol that charges, an anti-gravity grenade launcher.
- **Rarity:** each weapon has the 5 tiers; higher tiers add one or two modifiers (more damage, more pierce, faster reload, lifesteal...).
- **Scope warning:** a second weapon slot touches input (keyboard, mouse, touch and controller in `08-input.js` and `08b-pad.js`), the HUD, networking and every class's balance. It needs its own milestone, M2. If the schedule slips, the fallback is "weapon mods" that change the class gun instead of a second gun.

### 7.3 Loot
- **Where it comes from:** chests in side rooms, elite drops, boss drops (always one guaranteed rare-or-better per player).
- **What it can be:**
  - weapons (7.2);
  - **perks**: run-long passive bonuses. Reuse the skill tree's perk format (`SKILLS` in `01b-mods-skills.js`, which already supports a `modes:[...]` filter), with understrip-only perks;
  - consumables: barricades, flares, grenades, a heal;
  - **relics**: one per player, a big trade-off, for example "+30% damage, healing charges heal half".
- **Every pickup is shown before taking:** name, rarity colour and a one-line effect. No pickup should be a mystery.

### 7.4 Perks: the starting set (20)
Write each with a name, a one-line effect, a rarity and its numbers. Examples of the kind wanted:
- *Loaded Dice:* 10% chance a shot deals double damage.
- *House Edge:* +1 healing charge capacity.
- *Night Owl:* light cone +40%.
- *Lucky Break:* the first time you're downed each level, stand back up at 20% HP (D10: SECOND WIND is a skill-tree node).
- *Comp'd Room:* the next merchant visit is 25% off.

Balance them in M4 with the numbers in a single table, so the Godot port can copy it.

---

## 8. Enemies and bosses

### 8.1 Regular enemies
- **The raider types:** the existing ones appear throughout (rifle, grenadier, fire, breacher, shield, medic, spotter), dressed as casino security in region 1 and as the agency in regions 2–3. The colours change through `look`; the behaviour stays.
- **New behaviour in corridors:**
  - an **ambush** state (wait in a dark side room until a player passes);
  - a **retreat-to-group** state for low-HP raiders;
  - no wall-breaching AI, since there are no walls.
- **Elites:** one per room cluster, with a name tag, +150% HP and one extra trick:
  - a shield raider who charges;
  - a spotter whose laser calls a mortar.
- **Region 3 only:** alien "drones" (small, fast, in packs, weak to light). It's the one genuinely new enemy type, to sell the finale.

### 8.2–8.5 Bosses: the two-stage framework
- **Today:** some bosses already behave differently below half health (the Stormcaller's double strike at `e.hp<e.max*.5`, in `10-phases-bosses.js`).
- **This mode turns that into a framework every boss here uses:**
  - **Stage 1 → stage 2 at 50% HP:**
    - the boss becomes invulnerable for a 3-second transition;
    - its health bar refills as a second, differently coloured bar;
    - it gains moves and speed, and the arena changes.
  - **Telegraphs:** every attack has one at least 0.6 s long, readable by shape as well as colour (colour-blind safe).
  - **Boss gate:** a glowing doorway into the arena. Once a player steps through, it seals until the boss dies or the squad wipes.
  - **Defeat:** a guaranteed drop per player, a shrine appears, and the exit opens.

**HP:** set in the boss table and scaled by player count and difficulty, as existing bosses are. Starting values: region 1 about 1,200, region 2 about 1,800, region 3 about 2,400, the finale about 3,500 (balance in M4).

| Boss | Region | Stage 1 | Transition | Stage 2 | Signature drop |
|---|---|---|---|---|---|
| **8.2 The Pit Boss** | Flood Tunnels | A casino floor boss in a torn suit. Tosses chip-grenades (red circles), and calls two security raiders each 25% of HP | Tears off his jacket, and the arena floods ankle-deep | Faster. Throws card sprays (cone telegraph), charges through the water (lane telegraph), and the water slows players | His tie-pin perk: "+salvage from kills" |
| **8.3 The Custodian** | Shelter 7 | A towering shelter caretaker robot. Sweeps a mop-arc of electrified water, and blast doors in the arena open and close on a rhythm | Its casing cracks; the shelter goes to red emergency light | Uses the doors as weapons (crush lanes), floods sections with gas you must leave, and fires a ceiling turret at the furthest player | A flare-launcher weapon (epic) |
| **8.4 The Gatekeeper** | Area 67 | A security mech-suit pilot guarding the lab door. Rockets with landing circles, and a shield wall that blocks shots from the front | The pilot ejects; the suit keeps fighting, empty | Two targets: the empty suit (slow, heavy) and the pilot (fast, weak, a pistol). Kill either to end the stage | Anti-grav launcher (legendary) |
| **8.5 The Visitor** (finale) | Area 67 core | A tall grey alien in a containment field. Psychic pulses (expanding rings to roll through), and floats specimen tanks at players | The containment fails; the lights go out, and only its glow and your flashlights remain | Teleports between dark spots (a flash marks the next one), spawns drone packs, and a "gravity well" drags players toward it. The final 10% is a desperate stage with every move faster | Its own skin from the case (9.2, guaranteed on first kill) and a gold-tier relic |

**Writing each boss:** follow the existing `BOSSES` entries (a name, HP, speed, `think` function, `look`, and an `intro` line explaining the telegraph in one sentence). Add `stage2:{...}` overrides for the second stage. The finale's darkness transition is a scripted event, not a light setting.

---

## 9. The new case and cosmetics

### 9.1 The case
- **Name:** **UNDERSTRIP CASE** (placeholder, D1).
- **Rule:** every item in it is new and exclusive to this case. Skins have their **own models** (not recolours of the standard soldier).
- **How cases are set up today** (`CASES` in `18-cosmetics.js`): each one has a name, a colour, rarity weights, a shard cost, drop rules and a "how to get it" line. The server rolls cases atomically, with durable receipts (`20b-case-openings.js`, and the `case_types` table in `dev/supabase/schema.sql`).
- **Proposed entry:**
  - colour `#7cff6b`, alien green;
  - weights `{c:40, r:32, e:18, l:8, g:2}`. That's richer than Winter's because there are no commons among the skins (9.2). Final numbers in M4 (DECISION D7);
  - cost: 15 shards;
  - drops: one case per player per region boss killed, and a guaranteed one for finishing the run.
- **How to get it (shown in the case's info):** "Dropped by the bosses beneath the Strip. Finish the descent for a bonus case. Or 15 shards."

### 9.2 Skins: 10, each with its own model
- **Precedent:** the game already draws a fully custom-model skin: Tung Tung Tung Sahur, ULTIMATE, with its own branch in `16-characters.js`. Each new skin follows that pattern: its own drawing code, its own idle/walk/shoot poses, and its own see-through and fade behaviour, since outfits must still work with stealth fades and the Locker previews.
- **Every skin, when done, ships with:**
  - all four Locker angles, in the existing four-angle catalogue (`dev/catalog/cosmetics/`);
  - a lobby-stage pose;
  - checks with every hat.

| # | Skin | Tier | Brief (all LEGAL-checked against section 3) |
|---|---|---|---|
| 1 | **High Roller** | Epic | A black-and-white checkerboard suit and tie, a red pocket square, two-tone shoes |
| 2 | **The Visitor** | Gold | The finale boss as a skin: tall grey alien, big black eyes, a faint psychic glow (aura, like `16b-auras.js` effects) |
| 3 | **King of the Strip** | Legendary | A lounge-singer impersonator: pompadour, white rhinestone jumpsuit with a cape, gold shades. **Not Elvis**, by name or face |
| 4 | **El Generalissimo** | Epic | An invented generalissimo: peaked cap, sash, a chest of invented medals, epaulettes. No real person, rank or regime |
| 5 | **The Pit Boss** | Rare | The region 1 boss: torn casino-floor suit, earpiece, a pocketful of chips |
| 6 | **The Custodian** | Legendary | The region 2 boss as a wearable robot shell: boxy, mop-arm holstered, one cracked lens |
| 7 | **Shelter Dweller** | Rare | An original fallout-shelter jumpsuit in **our own** colours (DECISION D4), with a shelter patch and a ration-pack belt |
| 8 | **The Gunslinger** | Rare | A long dust coat, a flat-brim hat as part of the model, a bandolier |
| 9 | **The Sheriff** | Epic | A waistcoat, a star badge, a moustache, a tall hat |
| 10 | **The Card Sharp** | Legendary | A riverboat gambler: brocade vest, sleeve garters, a card fan in the off hand |

Rarity spread: 3 rare (Pit Boss, Shelter Dweller, Gunslinger), 3 epic (High Roller, Generalissimo, Sheriff), 3 legendary (King of the Strip, Custodian, Card Sharp) and 1 gold (The Visitor). There are no common skins, which is why the case's weights (9.1) lean higher than Winter's. A Gatekeeper skin is a stretch goal (an 11th) if time allows.

### 9.3 Every other category: 5 each, Vegas and alien
The categories are the game's own: hats (`hat`), tracers (`trail`), kill effects (`fx`) and lobby backgrounds (`bg`, in `18b-backgrounds.js`). The brief asks for 5 high-quality designs in every category except skins. Each category gets 3 Vegas themes and 2 alien ones, with one gold-tier showpiece across the four.

| Category | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| **Hats** (common → legendary; D13) | Dealer's visor (green eyeshade) | Showgirl feather crest | Neon halo (a flickering casino-sign ring) | Tinfoil hat | Antenna headband (bobbing alien antennae) |
| **Tracers** | Poker-chip trail (chips tumble behind the shot) | Neon strip (pink-and-blue neon tube) | Jackpot sparks (gold coins) | Tractor beam (a pale green beam that wobbles) | Plasma bolt (a fat green bolt with a ring) |
| **Kill effects** | Jackpot! (a slot machine pays out three 7s and coins burst) | Bust (cards scatter and flip face down) | Showgirl confetti (feathers and sequins) | Abducted (a beam lifts the body up and out) | Dissolved (green goo melts it to a puddle) |
| **Lobby backgrounds** (each animated within the existing animation budget, like the four animated winter scenes) | The Strip at night (retro neon skyline) | The flood tunnels (dripping concrete, a lit grate above) | Casino vault door (gold light through a huge round door) | Area 67 fence at dusk (searchlights and a hovering light) | Specimen hall (tanks glowing in a dark lab) |

- **Showpiece:** **Abducted** (kill effect) is the gold-tier item of the four categories.
- **Art bar:** each item matches the best existing items in its category (compare against the Legendary and Gold winter items). The kill effects and tracers use the shared painters in `20a-cosmetic-art.js`.
- **Cost:** each stays within the existing per-effect drawing budget, since the case-opening reel is measured on phones (`caseperf.js`).

### 9.4 Rewards and the shard economy
- **Shards stay outside the run.** They're never dropped, never spent at merchants, never at risk.
- **Every run pays out by depth:** cases (9.1) and a small shard bonus scaled by depth reached, about 2 per region cleared (DECISION D7), so a failed run still pays something.
- **Server work:**
  - A new `case_types` row and a migration in `dev/supabase/`.
  - The case's roll table on the server, never on the client.
  - Grants of the new case go through the existing atomic case flow and receipts.
- **Security dependency (blocker for M3):** STATUS.md's October 10 audit left open that `import_local_save` trusts the client's item list (any account can claim any cosmetics, 1000 shards and cases once). A case of exclusive, unique-model skins makes that hole much more valuable. **Fix it before this case ships.**

---

## 10. Technical plan (browser)

### 10.1 New files (slot into `ORDER.txt`)

| File | Holds |
|---|---|
| `06g-understrip.js` | Region room kits, the seeded level generator, shortcut doors, the exit, light sources, region hazards |
| `10h-understrip.js` | The mode: run state, levels, shrines, shared lives, death and recovery, dropped salvage, the exit flow (reusing the Blitz/Whiteout evac pieces), results cards |
| `10i-understrip-bosses.js` | The two-stage boss framework and the four bosses' `think` functions and moves |
| `10j-understrip-loot.js` | Merchants, stock rolls, weapons, perks, relics, consumables and their numbers (one data table each) |
| `16i-understrip-figures.js` | The 10 new skin models and the region's enemy looks |
| `18g-understrip-catalog.js` (D12) | The case, the catalogue rows, and the tracer/effect/background registration (like `18a-winter-catalog.js`) |
| `18h-understrip-scenes.js` (D12) | The five lobby background painters (like `18d-winter-scenes.js`) |
| `20d-understrip-effects.js` (D12) | The five kill effects and five tracers (like `20b-winter-effects.js`) |

### 10.2 Existing files touched

| File | Change |
|---|---|
| `04-state-armory.js` | Add `understrip` to the mode lists (`ammoMode`, the new-game mode list, waves); map and phase setup; `canShop` "near a merchant" |
| `19c-home.js` | The mode's card and summary rows on the PLAY screen |
| `22-loop-menus.js` | The mode's name in menus and the results screen |
| `03-audio.js` | The muffled playlist treatment (4.3) |
| `11-hud-chat.js` | HUD: healing charges, shared lives, salvage, the two-stage boss bar, the merchant prompt |
| `15-render.js` | Light cones and fixed region lights (extending the City's light holes) |
| `08-input.js`, `08b-pad.js` | The second weapon slot and heal button: keyboard, mouse, touch and controller |
| `21-online.js` | Send the level seed, merchant purchases, pickups, dropped salvage, shrine rests and boss stages. **Bump `PROTO`** (`yard-30` → `yard-31`) so old clients can't join a new-mode room |
| `18-cosmetics.js` | Register the new case in `CASES` |
| `dev/supabase/schema.sql` + a migration | The case type, its roll table, its grants |

### 10.3 Engineering rules
- **Deterministic generation:** everything a level contains comes from the seeded RNG, never `Math.random()`. Guests get the seed from the host, so the host and guests build the same level. Test this in a two-client test.
- **Data in tables:** loot, perks, weapons, merchants and bosses' numbers each live in one plain table, with no logic mixed in. That keeps balance changes one-line and makes the Godot port a copy-and-translate job (section 15).
- **No changes to other modes' numbers:** shared code paths take mode-specific parameters instead.
- **Save safety:** nothing from a run is written to the save except rewards, and only through the existing reward paths.

---

## 11. Performance budget
- **Targets:** a mid-range laptop at 60 FPS with 4 players, and a phone at a steady 30 FPS with 2 players. The heaviest moment is the finale's stage 2, with drones out.
- **Hard caps:**
  - at most 40 raiders alive in a level at once;
  - at most 12 in view;
  - lighting draws as a single mask pass, with no per-light canvas.
- **Measure with the existing tools:**
  - `bench.js` (frame time);
  - `stress.js` (add an "understrip finale, 4 players" case);
  - `caseperf.js` (the new case's reel on the phone-sized page).
- **Rule:** a milestone isn't done if it makes any existing `stress.js` case slower by more than 5%.

---

## 12. Accessibility and UX
- **Dungeon brightness** setting: raises the darkest light level. On its highest step, every telegraph and enemy is visible without a flashlight.
- **Telegraphs:** shape-coded (line = lane, circle = landing, ring = pulse) as well as colour-coded, readable in the colour-blind checks.
- **Reduce motion** (`reduceMotion`): softens the stage-transition shakes and the finale's blackout flicker.
- **Controls:** all new actions work on keyboard and mouse, touch sticks and controller (`08b-pad.js`), with prompts shown for whichever is in use.
- **First-time help:** a one-line, skippable tip the first time each of these appears: a shrine, a merchant, a boss gate, dropped salvage.
- **Pausing:** solo can pause anywhere; co-op pauses only in merchant screens (the game keeps running for the others, as it does today).

---

## 13. Milestones and acceptance

| Milestone | Delivers | Done when |
|---|---|---|
| **M0 Pre-production** (paper) | The mood boards (section 3), room-kit sketches for region 1, the boss move sheets, the loot table in a spreadsheet, and answers to every DECISION | The director signs off all of them |
| **M1 Vertical slice** | Region 1 only: the level generator, 2 levels and a boss level, the light and sound, one shrine per level, the Tunnel Trader with consumables and upgrades, The Pit Boss with both stages, solo and 2-player co-op | Fun test: the director plays 3 runs and wants a fourth. All existing tests pass; a new two-client seed test passes |
| **M2 Weapons and loot** | The second weapon slot (7.2) on all inputs, 9 region weapons, the 20 perks, relics, chests, elites | Every class can finish region 1 with any weapon; the controller and touch tests pass |
| **M3 Content complete** | Regions 2 and 3, The Custodian, The Gatekeeper, The Visitor, all merchants, shared lives, the results flow, music treatment. The case and all 30 cosmetics, with server work, **after the `import_local_save` fix** | A full run is finishable solo and with 4 players; every cosmetic passes the four-angle catalogue; the server suites pass |
| **M4 Balance and polish** | Numbers pass on all tables, difficulty scaling, the performance budget met, accessibility, first-time tips, an audio mix pass | Run lengths are within section 4.2's targets; the budgets in section 11 are met; no crash or desync in 10 four-player runs |
| **M5 Release** | Version bump, STATUS.md entry, an evidence folder (captures, test results, bench numbers), build | The director's go |

Each milestone ends with a short report in `dev/evidence/<date>-understrip-mN/`, in the style of the existing evidence folders: what changed, what was tested, and the numbers.

---

## 14. Risks

| Risk | Odds | Hit | Plan |
|---|---|---|---|
| The second weapon slot ripples through input, HUD, netcode and balance | High | High | Its own milestone (M2); fallback to weapon mods (7.2) |
| Darkness makes fights unfair or unreadable | Medium | High | The brightness floor (12), shape-coded telegraphs, and the director's fun test in M1 |
| Unique-model skins take longer than expected (10 of them) | High | Medium | Ship 6 in the case first if needed (one per tier plus The Visitor), and the rest in an update |
| IP trouble with the King, Shelter or Generalissimo skins | Medium | High | Section 3's guardrails and the director's sign-off before any art |
| Co-op desyncs from procedural levels | Medium | High | Seeded generation only; a two-client test from M1 on |
| The new case makes the `import_local_save` hole worse | Certain if unfixed | High | It blocks M3 |
| Run length too long for a session | Medium | Medium | Shrines give pause points; DECISION D2 (levels per region) is the length dial |
| The browser can't hold the finale on phones | Medium | Medium | The caps in section 11; drones are cheap shapes, not full figures |

---

## 15. Notes for the later Godot port sweep
The browser version is the reference; the Godot port copies it. To keep that sweep mechanical:
- Keep every table (bosses, loot, perks, weapons, merchants, room kits, case) as plain data with nothing but numbers and strings. The Godot side mirrors such tables in `godot/scripts/pal_tables.gd`-style files.
- Keep the mode's rules in the sim-side files (`10h`, `10i`, `10j`) and the drawing in the figure/effect files. Godot splits the same way (`sim.gd` against the `view3d/` scripts).
- Room kits should be data (tile grids plus doorway markers), not code, so both versions read the same files.
- The generator must give the same level from the same seed in both versions. Write the generator's algorithm up in a short spec (`dev/plans/understrip-generator.md`) as part of M1 (drafted at M0).
- Godot's 3D view has no per-pixel darkness yet: the night light holes (`main._update_light`) are the closest thing. Plan a lighting task for the port sweep.
- Skins with unique models will need 3D models in Godot (the browser's are drawn in 2D). That's real art work, so budget it in the port sweep, not as conversion.

---

## 16. Decisions for the director

**Answered November 4, 2026:** the director took every recommendation.

| # | Decision | Recommendation | Answer |
|---|---|---|---|
| D1 | The mode's and case's final names | THE UNDERSTRIP / UNDERSTRIP CASE | As recommended |
| D2 | Levels per region: 2 or 3 normal levels before the boss | 2 for v1 (a ~50-minute run) | As recommended |
| D3 | Names for the rest points and healing charges | Neon Shrines and Lucky Juice | As recommended |
| D4 | The shelter's brand, name and colours (must be original) | "Shelter 7", run by the fictional "Desert Civil Defence Authority", olive and orange | As recommended |
| D5 | The roll's numbers in this mode (today: 3 s cooldown, 0.3 s invulnerable) | A 2 s cooldown in this mode only; invulnerability unchanged | As recommended |
| D6 | A second weapon slot, or weapon mods only | The second slot, with mods as the fallback | As recommended |
| D7 | The case's weights, shard cost and the run's shard payout | `{c:40,r:32,e:18,l:8,g:2}`, 15 shards, about 2 shards per region cleared | As recommended: 2 per region, at most 6 a run |
| D8 | Whether the mode is unlocked from the start or after a milestone (for example, finishing a Black Out) | Open from the start; it's the headline feature | As recommended |

### 16.1 Settled at M0 (found while checking this brief against the code)

| # | What | Settled |
|---|---|---|
| D9 | **Passive healing.** The other modes heal you out of a fight (4 HP/s after 4 s, more with the SECOND WIND skill: `perkMods` in `01b-mods-skills.js`, applied in `12-players.js`). There are no heal pickups to switch off, which 6.3 assumed. | **Off in this mode** (the director). The SECOND WIND skill does nothing here, and the PLAY card says so. |
| D10 | **"Second Wind" is a skill-tree node already** (7.4's example perk). | The perk is **LUCKY BREAK**. |
| D11 | **There's no Medic class.** 6.3's "Medic ability" is the Quartermaster's revive (`medic:true`: a downed teammate up at 60%). | Read 6.3 as the Quartermaster's revive, which is unchanged. |
| D12 | **File names.** `18e-`, `18f-` and `20c-` are taken by the Hybrid Theory files (10.1). | `18g-understrip-catalog.js`, `18h-understrip-scenes.js`, `20d-understrip-effects.js`. |
| D13 | **An empty rarity tier breaks the case's odds.** When a case rolls a tier it has no items in, the server hands out a random item of any tier (`private.open_case_catalog`). 9.1 says there are no common skins, and 9.3 makes hats rare-to-legendary, so D7's 40% common weight would have nothing to land on. | Five commons across the other categories (two hats, a tracer, a kill effect, a background). The 30 items' tiers are in `understrip/tables/case_items.csv`; `build_tables.py` fails if any weighted tier is empty. |
| D14 | **Names and ids already taken.** `hat:visor` (Cyber Visor), `hat:halo`, `trail:plasma`, `fx:confetti`, and a trail named "Neon". | Dealer's Eyeshade, Neon Halo (`hat:neonhalo`), Saucer Bolt, Showgirl Plumes, Neon Tube. `build_tables.py` checks every id and name against the catalogue. |
| D15 | **Boss health figures** (8.2–8.5). | Read as effective health for one player on Normal, both stages together: base `hp` = figure ÷ 1.25 (`BOSS_HP`). |
| D16 | **Boss state numbers.** The Supreme Destroyer uses 40–47 and the winter bosses 101–103. | This mode's boss states use 60–89. |
| D17 | **Walls in front of the player** hide them in narrow tunnels (the iso view draws nearer walls over people, as `cityOccluders` does for the city on purpose). | M1 risk: near-side walls draw low (a cut-away), display only. In the generator spec. |

---

*Brief from the director, summarised: a dungeon-crawler mode built around claustrophobia, inspired by Souls-like games; levels joined seamlessly or by exits; random merchants with rare weapons, upgrades and perks; casino ambience as placeholder music, explained as being under the Vegas casinos; regions from the Vegas tunnels to a vault to Area 67 with alien bosses; regular enemies throughout plus two-stage region bosses; a new case of unique-model skins (checkerboard suit, alien, Elvis-style, general/dictator, boss skins, vault suit, three westerns) and five Vegas- and alien-themed designs in every other category; built in the browser version first, ported later.*
