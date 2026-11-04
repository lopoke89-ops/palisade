# THE UNDERSTRIP · M3 (content complete) report, November 4, 2026

The brief: [`dev/plans/understrip-work-order.md`](../../plans/understrip-work-order.md), milestone M3. Browser only; not released
(`main` and the website are unchanged). The server work is a migration in the repo, **not applied to the live database**:
that needs the director's go. Builds on [M1](../2026-11-04-understrip-m1/README.md) and [M2](../2026-11-04-understrip-m2/README.md).

## The whole descent
Ten levels: two and a boss's level in each region, then the finale. Each region builds from its own room kit
(`dev/data/understrip/rooms-r1..3.json`) with the right arena for each boss.

| Region | Levels | What's new there | Boss |
|---|---|---|---|
| 1 · The Flood Tunnels | 1, 2, the count room | (M1-M2) | The Pit Boss |
| 2 · Shelter 7 | 1, 2, the main hall | Gas vents (a hiss and a growing tint for 2 s, then 6 s of cloud, 10 HP/s), radiation pockets (3 HP/s; IRON LUNG halves both); olive-and-orange walls, ration crates, fluorescents that flicker on timers; the Desert Civil Defence Authority's raiders | The Custodian |
| 3 · Area 67 | 1, 2, the loading bay, the containment hall | Acid (6 HP/s), low-gravity floors (shots and grenades fly at 60% over them), specimen tanks, containment alarms (the first raider to hunt in a room calls a drone pack 3 s later), drones (small, fast, 4 on touch, double damage in your light); white lab walls with alien growth; lab-white raiders | The Gatekeeper, then the Visitor |

- **Lives:** one more for each region cleared (the Gatekeeper's fall clears region 3: its life is for the finale).
- **The results card** shows while the lift goes down: the level's raiders, what was found, the time and the lives.
- **Music** (work order 4.3): region 1 as before (650 Hz low-pass); Shelter 7 more muffled (420 Hz) with a 2.4 s
  reverb tail; Area 67 cuts the music. Each boss has its raid track (the Custodian *attitude*, the Gatekeeper *cool*, the
  Visitor the finale's).

### The bosses (`boss-move-sheets.md` 8.3-8.5; states 63-84)
- **The Custodian** (1,800 for one player on Normal): the mop arc (a blue wedge, 24 and a slow, live water for 3 s), the
  hall's four blast doors on a rhythm (amber for 1 s, shut for 3 s every 8 s, out of step; 40 and a push to the nearer
  side). Cracked at half: red emergency light; crush lanes (two doors at once, 45), gas over a quarter of the hall (2 s
  warning, 8 s), and a ceiling turret's line on whoever is furthest. Drops an epic flare launcher.
- **The Gatekeeper** (2,400): rocket rain (landing rings), a shield wall that blocks shots from the front for 4 s (round it,
  or armor-piercing), a stomp ring up close. At half the pilot ejects as a second body (20% more health, a three-shot
  pistol with a line, a dodge roll every 4 s) while the suit ground-pounds; **bringing down either one ends the fight**.
  Drops a legendary anti-grav launcher.
- **The Visitor** (3,500): psychic rings that move out (roll through them), tank throws (a shadow in a circle, then acid).
  At half the field fails and the room's lights go out (the scripted blackout); then blinks (a white flash where it lands),
  drone swarms, a gravity well (LEAD BOOTS ignore its pull). Under 10%: desperate, every cooldown ×0.7, no telegraph
  shorter. Drops the Visitor's Eye (gold relic); its skin is in the case.
- Each has its own model (a robot with a mop arm and one lens; a walking suit with rocket pods and a cockpit; a tall grey
  figure with a glow), and an Index card.

### The merchants (work order 7.1)
| Merchant | Where | Sells |
|---|---|---|
| The Tunnel Trader | the level's merchant alcoves | consumables (stock runs out, for the squad) and now 1-2 common or rare weapons |
| The Shrine Keeper (a cleaning robot) | beside each level's breather shrine | the armory's upgrades |
| The Lift Merchant | where the lift lands, from the second level on | a consumable, a weapon, a perk, and the upgrades |
| The Collector (a stranger in a tuxedo) | one level in each region, at the end of a branch, guarded by an elite shieldbearer and a rifleman | two epic-or-better weapons (the only gold anywhere), perks and a relic |

Weapons, perks and relics are per player: each of you can buy each one once.

## The UNDERSTRIP CASE (work order 9; catalog 6)
`#7cff6b`, weights c40 r32 e18 l8 g2, 15 shards. **A case for each region cleared, one more for finishing the run** (at
most 4), **2 shards a region** (at most 6) and a skill point a region; a failed run pays for the regions it cleared.
30 items, tiers as [`case_items.csv`](../../plans/understrip/tables/case_items.csv):
- **10 skins, each its own model** on the shared figure's frame (`16i-understrip-models.js`, through four hooks in the
  wardrobe painter): The Pit Boss, Shelter Dweller, The Gunslinger (rare); High Roller, El Generalissimo, The Sheriff
  (epic); King of the Strip, The Custodian, The Card Sharp (legendary); The Visitor (gold, with its own glow).
- **Headgear:** Tinfoil Hat, Dealer's Eyeshade, Antenna Headband, Showgirl Plume Crest, Neon Halo.
- **Tracers:** Poker Chips, Neon Tube, Jackpot Coins, Tractor Beam, Saucer Bolt.
- **Kill effects:** Bust, Showgirl Plumes, Jackpot!, Dissolved, **Abducted** (the gold showpiece).
- **Backgrounds**, all animated: The Flood Tunnels, Casino Vault Door, Area 67 Fence at Dusk, The Strip at Night, Specimen Hall.

The four-angle catalogue sheets: [skins 1](../../catalog/cosmetics/skin-understrip-1.png),
[skins 2](../../catalog/cosmetics/skin-understrip-2.png), [headgear](../../catalog/cosmetics/hat-understrip-1.png),
[tracers](../../catalog/cosmetics/trail-understrip-1.png), [kill effects](../../catalog/cosmetics/fx-understrip-1.png),
[backgrounds](../../catalog/cosmetics/bg-understrip-1.png).

## The server (`dev/supabase/migrations/20261104200000_v012_understrip.sql`, not applied)
1. **`import_local_save` fixed first** (the October 10 audit's open hole, the work order's blocker): a local save now brings
   into an account only the free cosmetics it lists and what of them was equipped. It used to trust any item ids, up to
   1,000 shards, 60 cases, a case bag and its stats. The game tells you when items stayed behind (and keeps a copy of the
   device's save).
2. The case row, its 30 items (catalog 6) and an opener for catalog 6 (`open_cases_v012`; older openers never hand them out).
3. UNDERSTRIP claims (`cv:6`): the pay above, counted from the levels in each claim, so a rejoin can't pay twice. A level
   takes at least a minute (a faster claim is refused) and a win under 15 minutes isn't a win. The bosses pay no other case.
4. Rooms and lobbies accept the mode.

## Calls made while building
| What | Call |
|---|---|
| The finale | A fourth level in Area 67 (the containment hall), so the run is ten levels |
| Region 3's life | The Gatekeeper's fall clears the region, so the finale gets its life |
| Who sells upgrades | The Shrine Keeper and the Lift Merchant (the work order's split); the Tunnel Trader no longer does |
| The Collector's "1 in 3 levels" | Exactly one of each region's first three levels, chosen by the run's seed |
| The Shrine Keeper's "some rest points" | The breather shrine on every level (the antechamber's shrine has none) |
| Hats on the new skins | The four with an open head (Pit Boss, Shelter Dweller, High Roller, Card Sharp) wear any hat; the six with their own hat or head wear only that |
| The four-angle catalogue | Captured with the repo's capture tool, limited to the case and checked against the migration's rows: the tool's full run checks every item against a snapshot of the live catalogue that predates v0.9.7, and stops at `skin:nightshift` |

## Tests
**The full suite: 110 of 119 passed** (18.1 min). Of the nine that didn't:
- `casino_relay_tables`, `casino_relay_games`, `casino_relay_rooms` fail in under a second on untouched `main` too (as in M1
  and M2). Not this work.
- `blackout_rewards` caught a real bug: the run's pay for this mode was put between an `if` and its `else`, so a Black Out
  win paid one Supply Case too many. Fixed; it passes.
- `ultimate_cloud` (a mocked server) didn't know the new opener. Only the UNDERSTRIP CASE uses `open_cases_v012` now; every
  other case opens as before. Passes.
- `cosmetics_migration` loads the cosmetics file in a sandbox with stubs for each case's register functions; it has the
  new ones now. Passes.
- `understrip_m3` and `understrip_squad` had been changed during the run for the Gatekeeper's region-3 life; they pass on
  the final build. `back_roll` failed once (its roll direction measured 0.97 against 0.98) and passes on its own.

Run again on the final build, on their own: every `understrip_*` test, `index_page`, `v0965_bosses`, `blackout_rewards`,
`ultimate_cloud`, `cosmetics_migration`, `cosmetics`, `headgear_fit`, `locker_fit`, `back_roll`: all pass.

The new tests (tag `understrip`):
- `understrip_m3`: the ten-level plan and each level's kit and arena; the Collector in exactly one level of each region;
  radiation 3 HP/s (IRON LUNG 1.5), a vent's warning, cloud and quiet (10 HP/s), acid 6 HP/s, a shot over low gravity going
  60% as far; the music route per region (420 Hz with the reverb in Shelter 7, none in Area 67, each boss's track); an alarm
  bringing a drone pack and drones taking double damage in light; the merchants (the trader sells no upgrades, the Keeper
  and the Lift Merchant do, weapons once each, gold only from the Collector, his guards); each new boss's health, gate,
  stage-1 and stage-2 moves, the 3 s it can't be hurt, its own bar, its fall, one drop each and its signature; the red
  light and the blackout; then a solo run from the first level to OUT OF AREA 67 with a life gained for each region.
- `understrip_squad` (serial): four players (a host and three guests) down all ten levels: the same tiles on all four
  phones on every level, each boss's gate, stage and doors reaching the guests, four bosses down, the lives, and OUT OF
  AREA 67 on every phone.
- `understrip_server` (node, 61 checks): the migration on a disposable Postgres built on the live chain (see the server
  section): the import fix, the case and its items, openings and their repeats, claims (won, split by a rejoin, failed at
  level 7, too fast, a win too short, an older client), the claim function keeping every other line, other modes' pay,
  rooms and lobbies.
- `understrip_case`: the case on the client: its 30 items in their tiers, 2,000 local openings landing on its own items in
  its weights, every skin drawing its own model at all four angles, the hats, which skins wear which, the tracers, kill
  effects and backgrounds drawing, and a run's pay without an account (won, failed, rejoined, too short).

Existing tests changed: `index_page` 19 boss cards, `v0965_bosses` 19 weaknesses (the three new bosses), `understrip_gen`
covers all seven level kinds (3,000 seeds of region 1's two, 1,000 of each deeper one), `understrip_run` ends by going
down to Shelter 7, `cosmetics_migration`'s stubs.

## Screens
In [`images/`](images/), from `dev/test/understrip_capture_m3.js`: `shelter7-gas`, `area67-drones`, `custodian-stage1`,
`custodian-stage2`, `gatekeeper-stage1`, `gatekeeper-pilot`, `visitor-stage1`, `visitor-blackout`, `collector`, `lift-card`,
`the-end`.

## Not in M3
The balance pass on every table, the performance budget, first-time tips and the audio mix are M4. The live migration
waits for the director's go.
