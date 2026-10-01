# Special ammo and eight-level Armory validation

Implemented from [the work order](../../plans/ammo-and-armory-expansion-work-order.md), prepared as **v0.9.5.2** for Big U's authorized October 1 release. Protocol is `yard-20`, room prefix `palisade-yard-20-`. The final build and Pages verification are recorded in `release-verification.json` after deployment.

**Mobile UI follow-up:** the Armory now uses Upgrades/Ammo tabs and a Sniper slot selector. Both categories fit without scrolling in 73 tested layout cases, including smaller portrait and landscape phones. See [the compact Armory report and current captures](compact-armory/README.md); it supersedes the original scrolling-layout validation below.

## Implementation and balance

Special ammo is available between raids at the stake in solo/co-op 5-raid, 10-raid, Endless and Blitzkrieg Rush. It is hidden and rejected in Base Battle and Free-for-all. First/empty-slot purchase costs 150 salvage; switching an occupied slot costs 75. Selecting the same type again costs nothing. Normal classes have one slot; Sniper has two distinct slots. Leaving Sniper keeps slot one and clears slot two; changing back does not restore it.

| Ammo | Base | Skill ranks 1 / 2 / 3 / 4 |
| --- | --- | --- |
| Armor Piercing | 50% direct damage through frontal riot shields | 60% / 70% / 85% / 100% |
| Incendiary | 10 HP/s for 3 seconds | Duration 3.5 / 4 / 4.5 / 5 seconds |
| Explosive | 8 damage within 1.25 tiles, full to 0.35 tiles then falling to zero | 10 / 12 / 14 / 16 damage |
| Lightning | 25% movement slow for 2 seconds; primary plus nearest three within 3 tiles | 30% / 35% / 40% / 45% slow |

Ammo skill ranks require 5 / 10 / 15 / 20 lifetime SP earned and cost 1 / 2 / 3 / 4 unspent SP. The account server enforces both. Hosts clamp guests' claimed ranks to the server's ranks; verified ranks are also sent in player info for correct Armory descriptions. Old 15-node skill strings retain their meanings and their Molotov toggle.

Burn and slow refresh without stacking; a weaker slow cannot replace a stronger active slow. Boss slow is capped at 20% and changes movement, including charges and rafts, while attack timers keep their normal cadence. Explosive damage affects enemies only and has a 0.4-second per-shooter/target proc limit. A shotgun round shares one round ID across all pellets. Recent IDs are bounded to 128 per shooter/target to prevent interleaved pellets from repeating effects or growing memory indefinitely. In-flight bullets retain their captured ammo and verified rank. Burn ticks use the normal damage/kill-credit path without generating hit particles each frame; status rings are drawn locally.

Existing upgrade levels 1–4 retain their prices and stats. The interpretation of the requested 25% increase is a level-8 bonus cap 25% higher than the old level-4 bonus.

| Track | Level-8 cap | Level 5 / 6 / 7 / 8 salvage |
| --- | --- | --- |
| Damage | +100% bullet damage | 175 / 225 / 290 / 370 |
| Fire Rate | 50% shorter cooldown | 175 / 225 / 290 / 370 |
| Range | +60% reach, +50% bullet speed | 140 / 185 / 240 / 310 |
| Armor | +75% base maximum HP, rounded after bonuses | 175 / 225 / 290 / 370 |
| Grenades | +5 stock, +40% power, +25% radius | 140 / 185 / 240 / 310 |
| Delgado | +75% damage, reach and fire rate, shared | 200 / 270 / 350 / 450 |

Grenade stock's fifth extra grenade arrives at level 8. Soldier bursts remain capped at nine rounds with a minimum 0.2-second burst gap. Core Repair remains repeatable. These are initial playtest balances: blast damage is capped against rapid fire, burn DPS stays fixed, and late Armory tiers cost more than the original four.

## Validation

The initial full PowerShell regression run passed all checks except `v087`, which expected the old seven-row Armory. Its row expectation was updated for the four ammo choices and its later successful run is included here. The final collection covers 62 distinct tests across the initial run and focused reruns; this is not a second complete sweep of every test on the final build.

Final focused runs passed `ammo_armory`, `ammo_migration`, `ammo_network`, `ammo_stress`, `skilltree`, `v087`, `blitz_mode`, `blitz_bosses`, `blitz_network`, `blitz_milestones`, `blitz_reward_migration`, `bosses`, `rejoin`, `delgado`, `hud_layout`, `controller`, and `csp`. No page errors were reported. The build and `git diff --check` passed.

- **Combat/purchases:** correct 150/75/zero charges; unaffordable, remote, dead, raid-phase and Lockdown rejection; normal/Sniper caps; class pruning; frontal shield penetration; dual Sniper effects; shotgun round deduplication; blast cooldown; exact 10 HP/s burn; burn kill credit; interleaved-round suppression; three-neighbor chain cap; burrow exclusion; boss slow cap; Base Battle/FFA exclusion.
- **Online:** real local PeerJS host/guest purchases in all four eligible modes; repeated purchase and forged slot/type rejection; synchronized salvage and slots; burn/slow snapshots; level-8 upgrades and ammo preserved through a real same-match disconnect/rejoin; host rejection of ammo in both PvP modes.
- **Account/server:** disposable Postgres tests apply the migration twice, exercise each threshold one point early and at the threshold, require unspent SP, reject stale revisions and unknown nodes, and verify grants. Tests use the deployed respec function body: exactly 10 SP returned for one maxed ammo node, lifetime SP unchanged, second reset refused. The browser account fixture verifies claimed rank 4 becomes server ranks 1/0/2/3.
- **Presentation:** the original stacked layout required scrolling. The subsequent [compact UI follow-up](compact-armory/README.md) replaces it with tabs and a slot selector, verified without scrolling at ten viewport sizes. Ammo labels include effect values, skill rank, price and slot. Controller regression passes.

## Six-player stress scene

Twenty simulated seconds per condition, six shooters, 48 durable raiders plus a Butcher, software-rendered Chrome at 390×844. Ordinary projectiles are fired by all six guns; the special condition includes explosive bullets and repeatedly applies burning/lightning across the crowd. This measures a PC viewport, not physical phone performance.

| Measurement | Ordinary | Special ammo |
| --- | --- | --- |
| Update median / p90 | 0.2 / 0.4 ms | 0.2 / 0.4 ms |
| Render median / p90 | 3.9 / 6.5 ms | 4.2 / 6.1 ms |
| Peak particles | 116 | 419 |
| Peak queued events sampled per tick | 41 | 284 |
| Peak bullets | 31 | 31 |
| Peak affected enemies | 0 | 49 |
| Maximum remembered round IDs | 0 | 62 (cap 128) |

The stress test completes without errors. Physical-device performance and longer player balance sessions remain useful follow-up checks; these measurements do not establish phone battery use or production network latency.

## Backend and release state

Migration `20261001045820_ammo_armory_expansion` is applied to `puvjfhwxigxjpsvdwrwf`. The local migration filename matches its live version. Read-only verification confirms all four cost/gate arrays, the lifetime gate in `skill_buy`, 40 SP spent for four maxed nodes, authenticated purchase access, anon denial and no exposed private definitions. Security advisors are unchanged from the pre-migration baseline. Their existing categories are documented by Supabase's [database linter](https://supabase.com/docs/guides/database/database-linter) and [password security guide](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

The pre-change skill definitions, purchase, respec and spent functions are saved in [the server snapshot](../../supabase/snapshots/20261001_before_ammo_armory.json). No player balances or saved skill rows were modified by the migration. Existing clients remain compatible with its account functions. The release rebuilds `index.html` and `sw.js` with footer v0.9.5.2; `yard-19` peers cannot join a `yard-20` room.

Saved evidence: the logs and screenshots in this directory, `ammo_network.json`, `ammo_stress.json`, and `server-verification.json`. The full ignored test output remains in `dev/test/out/`.
