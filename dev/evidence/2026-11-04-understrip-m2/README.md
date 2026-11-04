# THE UNDERSTRIP · M2 (weapons and loot) report, November 4, 2026

The brief: [`dev/plans/understrip-work-order.md`](../../plans/understrip-work-order.md), milestone M2. Browser only; not released
(`main` and the website are unchanged). Builds on [M1](../2026-11-04-understrip-m1/README.md).

## What's new in the tunnels
- **A second weapon,** held for the run, lost at its end; the class gun stays (infinite ammo). Keys **1** and **2**, the
  controller's d-pad left/right (its material buttons, unused in the tunnels), and the kit's weapon button on touch. The
  button shows the weapon's name (bordered in its rarity's colour) and magazine/reserve.
  - Magazines reload a round at a time (as the Grenadier's tube does) from a **reserve**; an empty reserve stops the reload.
    Shrines refill the reserve.
  - **The nine weapons** of [`tables/weapons.csv`](../../plans/understrip/tables/weapons.csv), each with its trick: the
    sawn-off's falloff, the taser's stun and jump, the nail gun's pin, the SMG, the flare launcher's burn and light, the riot
    shotgun's knockback, the lab laser's bounce off walls, the alien pistol's charge (held: up to 64 damage, a full charge
    pierces 3; it fires on release), the anti-grav launcher's lift. Region 1 drops its three (the others come from deeper
    regions, M3).
  - **Five tiers** (damage ×1.00-1.35, 0-3 mods from the 11 in `weapon_mods.csv`) and the **signatures** on legendary and
    gold: BOTH BARRELS, ARC, RIVETS, DRUM MAG, STARBURST, SLUG, PRISM, OVERCHARGE, WELL.
- **Loot on the floor,** shown before it's taken (work order 7.3): name in its rarity's colour, a line saying what it does,
  and E · TAKE under it. A weapon taken drops the one you had; so does a relic.
  - **Chests** (caches) now drop a roll from `loot_sources.csv` (consumable, salvage, weapon or perk).
  - **Elites** (one in most rooms of two or more raiders, by the seed): a shieldbearer CHARGER (a red lane, then a charge)
    or a spotter CALLER (a laser, then a mortar ring). ×2.5 health, a tag over them, +20 salvage and a loot roll; they stay
    down after a rest.
  - **The Pit Boss** drops one rare-or-better roll for each of you, and his TIE-PIN (+1 salvage a kill).
- **The 20 perks** (`perks.csv`) and **7 relics** (`relics.csv`, one at a time), as written there. Iron Lung waits for
  region 2's gas; the Visitor's Eye is region 3 loot.

## Calls made while building
| What | Call |
|---|---|
| Elites' names | A role tag (ELITE · CHARGER / CALLER) rather than a name, so every phone shows the same thing |
| The Marked Deck's "2 more items" | Read as: that merchant's stock doesn't run out for you (and prices are 25% up) |
| Comp'd Room | 25% off at one merchant until you walk away from him |
| The laser's bounce online | The host decides it; a guest sees the shot's first leg (bullets are sent once, when fired) |

## Network (yard-31)
The weapon, the hand, perks and relic ride the player info (sent when they change); the magazine is the player's ammo; loot
on the floor, elites and their trick's state ride the snapshot. A guest's swap (`uw`) and take (`ut`) go through the host.

## Tests
**The full suite on this build: 111 of 115 passed** (15.3 min). The four that didn't:
- `casino_relay_tables`, `casino_relay_games`, `casino_relay_rooms`: fail in under a second on untouched `main` too (as in M1).
  Not this work.
- `blackout_perf`: a frame-time budget check. It fails the same check on `main` in the same container (41.9 ms against a
  24.6 ms budget there); it measures Black Out, which this work doesn't touch.

Run again on the last build, on their own: `understrip_loot`, `understrip_m2`, `understrip_run`, `understrip_network`,
`understrip_roomkit`, `understrip_gen`: all pass.

The new tests (tag `understrip`):
- `understrip_loot` (node): the weapons, tiers, mods, perks, relics and loot sources in the game match the CSV tables
  (damage, mod slots, prices, signatures, weights, each region's rarities); 36,000 rolls (chests, elites and the boss in
  each region) give working guns with no mod twice and nothing from a deeper region; every weapon drops somewhere; the boss
  drops rare-or-better gear only; the same seed gives the same loot.
- `understrip_m2`: a weapon on the floor shown before it's taken, E taking it, 1 and 2 (and the touch button) swapping; the
  magazine reloading from the reserve and stopping when it's empty, a shrine refilling it; Steady Hands, Big Gulp,
  Insurance and Back Step, and the Paper Crown; a chest's loot on the floor; an elite's health, tag, drop and staying down
  past a rest; the alien pistol's charge and release, the laser's bounce, RIVETS; every class killing with every weapon; the
  Pit Boss's drops and tie-pin.
- `understrip_network` (added to): a weapon given on the host reaches the guest, and the guest's swap goes through the host.

## Screens
In [`images/`](images/), from `dev/test/understrip_capture_m2.js`: `loot-label` (a legendary nail gun, a perk and a relic on
the floor), `weapon-in-hand` (the kit's weapon button), `elite-charger` (the tag and the lane).
