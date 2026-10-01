# Operation Whiteout: balance and simulation contracts

Candidate v0.9.6.0, October 1, 2026. These are implemented starting values. Automated encounter and transition checks verify the rules; sustained human campaign sessions are still needed to tune difficulty and total duration.

## Frostpeak and elevation

| Property | Standard | XL |
| --- | --- | --- |
| World size | 16 × 16 | 24 × 24 |
| Summit / middle boundary rows | 5 / 10 | 7 / 15 |
| Core tile | (7, 2), height 2 | (10, 2), height 2 |
| West ascent columns | 3–5, ramps | 4–6, ramps |
| East ascent columns | 10–12, stairs | 16–18, stairs |
| Enemy entries | Lower southern edge | Lower southern edge |
| Health multiplier | 1.08 | 1.08 × 1.10 |

The two three-cell-wide ascents connect all three terraces. Wood is available at several heights; brick and metal are accessible from the summit. Connector cells cannot be built on. Existing collision, actor radius, core coverage, resource and blocked-route rules still apply. Evacuation chooses a reachable flat 3 × 3 patch using a search over height links; the selected tile is authoritative.

### Resolved height rules

- A height tier draws 24 × view scale pixels higher and counts as 0.8 tile of vertical distance. Ramps and stairs interpolate continuously. Connector sides are guarded; enter through their upper or lower ends. Cliffs block walking and manual boss charges. Ordinary enemies and Delgado use the same reachable flow graph.
- Gun aiming uses chest endpoints 0.7 height units above the terrain. Intervening higher terrain and walls block shots. Direct hits require the bullet's altitude to intersect the target. Range, falloff, blast damage, melee reach and assistance range use three-dimensional distance on Frostpeak. Height adds no damage or range bonus.
- Grenades arc to the target terrace with a 6.5-tile three-dimensional throw limit. Explosive ammo uses the normal enemy-only blast contract. Rockets and ground arcs follow traversable ground and stop at cliffs. Ground fire and frost only reach actors on approximately the same ground plane (less than 0.45 height units apart).
- Lightning beams follow a chest-height ray with terrain, wall and actor checks. Mouse projection resolves the actual terrace or connector plane; touch targeting uses the same distance and line-of-sight rules. Muzzle/tracer/flash metadata carries the shooter's height explicitly so a barrel over a cliff retains its correct screen position.
- Ruptures use three-dimensional spherical distance, including nearby terraces. Cliffs do not shield an actor inside that radius. The warning is clipped to each affected terrain plane; ramp boundaries conservatively show the dangerous region. There are reachable lanes beyond the 3.4-tile radius on both layouts.
- Cliffs join the existing depth queue. Actors, shadows, walls, resources, bullets and grenades use terrain elevation independently of body animation. Fixed scenery and warning/field art are cached with bounded counts.

## Campaign pacing and continuity

| Chapter | Map | Raids | Boss |
| --- | --- | --- | --- |
| Recover the route | The Yard | 1–3 | Frostbound Butcher |
| Recover the convoy | Riverbend | 4–6 | Icebound Ferryman |
| Restore summit power | Ashfall Quarry | 7–9 | Permafrost Foreman |
| Signal evacuation | Frostpeak | 10–12 | Rime Colossus |
| Final evacuation | Frostpeak | Stage 13 | One five-minute assault |

Chapter cards and short objectives carry the story. Campaign starts at the Yard regardless of the ordinary-mode map preference. Both map sizes work. Chapter bosses appear once on their designated raid; XL does not double campaign chapter bosses. Existing ordinary-mode boss schedules remain separate.

Initial preparation is 40 seconds plus the difficulty adjustment; ordinary preparation is 24 seconds plus that adjustment. New chapter preparation is 30 seconds plus that adjustment. Difficulty adjustments are Easy +10, Normal 0, Hard −6 seconds. Actual raid durations depend on party size, combat and chosen modifiers; no fixed total completion time is claimed.

| State | Transition policy |
| --- | --- |
| Identity | Same run ID; global stage, chapter and real map are synchronized |
| Player kit | Carry class, upgrades, verified skills, ammo slots, salvage and materials |
| Shared kit | Carry Delgado upgrade level |
| Recovery | Normal build recovery once: refill health, grenades, magazines and abilities; recover downed players and Delgado |
| Build income | Once per preparation: 8 + completed global raid salvage per connected player |
| Core | Carry current and maximum HP; no automatic core repair |
| Repair | Existing Armory repair price and No Patch-Ups restriction |
| Structures | Previous-map walls disappear without refunds; next map's authored ruins are rebuilt |
| Hazards | Reset map-specific combat objects, frost and path/scenery caches |
| Reconnect | Preserve kit, supplies, position/height, HP ratio and extracted state; apply recovery only if a real preparation epoch elapsed |
| Late join | Spawn in the current chapter; participation starts at the actual completed raid count |

Supported modifiers: **No Patch-Ups, On Your Own, Firestorm, Adrenaline, Last Stand, Elite Raid, Weather and Berserk**. They retain their existing reward values and interactions. Boss Rush and Nightmare are excluded to preserve chapter encounter accounting. Double Time, Hot LZ, Artillery Barrage, Lockdown and Scorched Earth are excluded from campaign; its finale always uses the stated five-minute/60-second schedule. PvP-only modifiers are excluded by the existing co-op filter.

### Finale

- 300 seconds, core survival required until the final 60 seconds.
- One boss at elapsed 0 seconds, then every 30 seconds through 270 seconds. Maximum ten queued spawns and four concurrent bosses; blocked spawns wait for capacity.
- Roster repeats twice: Frostbound Butcher, Permafrost Foreman, Rime Colossus, Tempest, Bulldozer. Finale bosses have 85% of their normal scaled health.
- Evacuation opens with 60 seconds remaining. Each living player must stand in the reachable 1.5-tile-radius ring for three uninterrupted seconds. Leaving resets the timer. Downed players require revival; a notification or teammate's evacuation does not extract them.
- Extracted players win individually. Players left behind receive half their cases and shards, rounding odd amounts up. Completed raids, boss progress, skill points and milestones are retained. Living bosses at the end retreat without kill credit.
- Only one winter rupture/dash warning begins at a time; other winter bosses defer their warning. Existing Tempest/Bulldozer tells remain active. Frost fields expire and remain bounded so long-term hazard accumulation cannot fill the map.

## Boss tuning

Boss HP = listed base × difficulty HP × (1 + 0.35 × extra players) × map/XL multiplier × the existing late-wave boss factor × applicable ordinary XL share × finale factor. Difficulty HP: Easy 0.8 / Normal 1 / Hard 1.2. Six players give 2.75× party HP. Ordinary XL paired bosses each use 0.9× share; campaign chapter bosses use a full share. Existing late-wave factor is +25% per 15 raids after raid 5. Ordinary raider growth is separate (+8.5% per effective raid after the first).

| Boss | Base HP | Movement | Encounter change |
| --- | --- | --- | --- |
| Frostbound Butcher | 880 | 2.05 tiles/s | Ice arc/charge sequence plus a marked 2.3-tile rupture |
| Icebound Ferryman | 820 | 1.45 tiles/s | Harpoons and landing crews plus a marked rupture on Riverbend |
| Permafrost Foreman | 900 | 1.35 tiles/s | Bulldozer-style charge, wall collision and daze plus a marked rupture |
| Rime Colossus | 860 | 1.2 tiles/s | New armor/reservoir silhouette, ice maul, rupture and poisoned-frost dash |

Rime at raid 12 on Normal, standard Frostpeak: **928.8 HP solo / 2,554.2 HP with six players**. These values exclude optional modifiers. Ordinary Frostpeak uses Rime at raid 5, Stormcaller at raid 10 and Rime at raid 15; existing Blitz conversion/finale rules still apply.

| Rime action | Implemented value |
| --- | --- |
| Glacial Rupture | 3.4-tile 3D radius, full 1.5-second warning |
| Rupture damage | 30 × difficulty damage to allies; 18 × difficulty damage to core; 35 × material blast multiplier to walls |
| Venom Rush warning | 0.85 seconds |
| Dash | Up to 6 tiles; 7.2 tiles/s for up to 1.05 seconds, affected by terrain/status slows |
| Dash hit | 26 × difficulty damage once per actor per dash |
| Poisoned frost | 30% slow, 10 seconds, 0.72-tile radius, no poison damage |
| Field generation | Actual dash movement, nominal 0.32-tile spacing; refresh one field per occupied cell; maximum 64 |
| Phases | 70% and 35% HP |
| Rupture cooldown after recovery | 6 / 5 / 4 seconds by phase |
| Dash cooldown after recovery | 5.5 / 4.5 / 3.5 seconds by phase |
| Recovery | Rupture 1.2 seconds; dash 1.3 seconds |
| Sequence | Alternate rupture/dash initially; below 35%, rupture/dash/dash when traversal permits |

Difficulty damage: Easy 0.55 / Normal 0.85 / Hard 1.15. Normal rupture deals **25.5 HP before vest/perks**; Normal dash deals 22.1. Winter variant ruptures keep their 1.5-second tell and use 9-second cooldowns, falling to six below 35% HP. Terrain and status slows multiply, with a 50% movement floor. Boss status slow is capped at 20%; Rime is affected by its own frost. Attack timers retain existing modifier behavior and full warnings.

## Armory and ammo

All existing eight-level tracks, account gates and prices carry through the campaign. New ammo is enabled for solo/co-op campaign, 5, 10, Endless and Blitz; PvP remains excluded. An empty ammo slot costs 150 salvage, a replacement costs 75, and reselecting the current type is free. Ordinary classes have one slot, Sniper two distinct types. Class changes retain slot one and clear slot two when leaving Sniper.

| Ammo | Base | Ranks 1 / 2 / 3 / 4 |
| --- | --- | --- |
| Armor Piercing | 50% frontal shield penetration | 60 / 70 / 85 / 100% |
| Incendiary | 10 HP/s, three seconds | Duration 3.5 / 4 / 4.5 / 5 seconds |
| Explosive | 8 damage, 1.25-tile radius | 10 / 12 / 14 / 16 damage |
| Lightning | 25% slow for two seconds; target plus nearest three within three tiles | 30 / 35 / 40 / 45% slow; bosses capped at 20% |

Skill ranks still require 5 / 10 / 15 / 20 lifetime SP and cost 1 / 2 / 3 / 4 unspent SP. Terrain and three-dimensional combat rules apply to ammo; cosmetic winter effects cannot apply frost, damage or slows. See the [existing full Armory prices](../2026-10-01-ammo-armory/README.md).

## Rewards and milestones

- A completed campaign credits Yard 3, Riverbend 3, Quarry 3 and Frostpeak 4 (the finale is stage 13). Late join/early leave credits only the completed participation interval to each real map.
- Chapter kills pay Winter Cases: one per winter variant, two for Rime. Actual eligible defeats increment their base boss ladder; Rime has its own ladder.
- Finale winter variants pay one Winter Case, Rime two; Tempest/Bulldozer pay two Blitzkrieg Cases. Each actual finale kill pays 15–30 shards and one SP. Campaign kills do not increment the Blitzkrieg mode ladder.
- Eligible extraction pays one Winter Case and 25 shards. Existing raid-based Supply Cases, win bonus, SP progress and salvage conversion remain in effect; ordinary reward modifier cap is −15% to +75%.
- Server progress derives from the participation interval and constrained encounter keys. Duplicate claim retries return a stored receipt and current locker. Client result guards and reconnect participation preserve once-only progression. Receipts are retained for 31 days.
- Frostpeak ladder: 250 / 500 / 1,000 / 2,500 held stages → Snowline Scout / Summit Ranger / Glacier Engineer / Aurora Sovereign.
- Rime ladder: 25 / 50 / 100 / 250 actual defeats → Polar Rescue / Evergreen Sentinel / Nutcracker Vanguard / Rimebound Warden.
- Keep these established thresholds for this candidate. A campaign awards at most four Frostpeak stages and potentially three Rime defeats when both finale Rimes are defeated. The map Gold threshold therefore requires at least 625 complete campaigns if played exclusively in campaign; Rime Gold at least 84 with all three defeats. They are lifetime goals across eligible modes. Revisit thresholds after measuring actual human completion time.

The Winter Case contains the other **34 items**, costs **14 shards**, and uses Common/Rare/Epic/Legendary/Gold rarity weights **45 / 32 / 16 / 6 / 1**. Matching hats are case rewards; eight milestone skins are excluded from that pool. The [full catalog](CATALOG.md) specifies every item.
