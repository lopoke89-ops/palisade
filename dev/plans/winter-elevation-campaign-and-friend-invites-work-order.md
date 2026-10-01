# PALISADE: Winter Campaign, Elevation, Cosmetics, and Friend Invitations

## Role and objective

Act as a senior gameplay engineer, Canvas 2D rendering engineer, multiplayer engineer, and game designer working in the existing PALISADE repository.

Build a polished expansion that introduces a snowy mountain map with functional elevation, connects the maps into a light story campaign, revamps campaign boss encounters, adds an original winter boss, delivers a complete winter cosmetic collection, and lets players invite accepted friends directly from the Friends list.

The result must feel native to PALISADE: readable isometric combat, distinctive procedural characters, quick preparation phases, tactical defense, reliable co-op, and a compact mobile interface.

Working names below are proposed creative direction: **Operation Whiteout** for the campaign, **Frostpeak** for the map, and **The Rime Colossus** for the boss. Refine names if needed while preserving the requested features and quantities.

## 1. Establish the implementation baseline

Before editing, inspect the authoritative checkout, current Git state, applicable project instructions, build process, and current server definitions. Preserve the existing uncommitted repository cleanup and other local work.

The inspected baseline is v0.9.5.2 with protocol `yard-20`; verify this again when implementation begins. Existing systems include:

- A Canvas 2D isometric renderer and procedural character/cosmetic painters.
- Ordered JavaScript source modules assembled into the deployed page.
- The Yard, Riverbend, and Ashfall Quarry maps, with standard and XL layouts.
- Solo and host-authoritative co-op, including six-player sessions.
- 5-raid, 10-raid, Endless, and Blitzkrieg Rush modes.
- A five-minute Final Blitz, boss scheduling, and personal evacuation outcomes.
- Special ammunition, eight-level Armory upgrades, account skills, rewards, milestones, and reconnect state.
- Supabase accounts, Friends, notifications, cosmetic ownership, and reward validation.

Extend these systems and their established visual language. Keep cosmetic IDs, existing network catalog indices, and `palisade.*` storage keys compatible. Measure performance before changing shared rendering code.

## 2. Frostpeak: a mountain defense map

Create a distinctive winter mountain battlefield with the **core and defensive base at the summit** and enemy entry points lower on the mountain.

The map should include exposed snowfields, icy rock faces, pine clusters, switchback approaches, abandoned expedition equipment, and a clearly readable summit outpost. Christmas details should support the setting without obscuring its tactical identity.

Required layout features:

- At least three readable elevation tiers: lower approach, middle terraces, and summit.
- Functional ramps, slopes, and stairs connecting these tiers.
- At least two viable uphill routes so a single choke point does not solve every encounter.
- Useful terraces, flanking routes, and defensible positions with clear tradeoffs.
- A summit large enough for the core, Armory, defensive construction, and a full co-op party.
- Safe, reachable spawn and evacuation locations.
- Standard 16×16 and XL 24×24 layouts integrated with existing map selection.
- Support for solo and co-op 5-raid, 10-raid, Endless, Blitzkrieg Rush, and the new campaign.

Account for resources, buildable cells, enemy and boss spawning, path availability, and every applicable modifier. Existing PvP maps must continue working; adding a Frostpeak PvP arena is separate scope.

### Elevation must affect gameplay

Use a bounded world-space elevation model appropriate for the current tile map. Treat elevation as simulation state, not merely a drawing offset.

Implement and document the following contracts:

1. **Traversal:** actors change altitude through valid connectors. Cliffs block walking. Ramp and stair transitions are smooth and require no additional player controls.
2. **Pathfinding:** players, ordinary enemies, bosses, and Delgado understand reachable routes and connectors. Large bosses need valid clearances. Wall placement must respect the game's existing rules for blocked paths.
3. **Combat:** define cross-height aiming, line of sight, projectile paths, cover, range measurement, grenade travel, blast reach, and area attacks. Height alone must not make the summit immune to attack. Any high-ground damage or range bonus must be an explicit balance decision.
4. **Projection:** world-to-screen and screen-to-world conversion must agree at each elevation. Mouse aiming, touch auto-lock, controller targeting, and muzzle positions must hit what players see.
5. **Rendering:** resolve depth order, cliff faces, ramp edges, actor shadows, walls, foliage, and partial occlusion. Keep actors, projectiles, hazards, and aim indicators readable around elevation changes.
6. **Networking:** the host validates connector traversal, altitude, movement, and combat. Guests cannot teleport uphill through movement packets. Snapshots and reconnect restoration must include the necessary elevation state.

Keep terrain height distinct from cosmetic body offsets and animation. Establish these rules in a playable vertical slice before producing the complete map.

## 3. Original boss: The Rime Colossus

Design an original mountain boss with a memorable silhouette: fractured ice armor, a heavy expedition-like frame, a toxic frost reservoir, and a visible attack stance. Give it procedural art, animation, sound cues, and attack effects consistent with the current Canvas renderer.

Its identity must come from mechanics and movement as well as appearance.

### Required attacks

**Glacial Rupture — huge area attack**

- A large, clearly telegraphed attack using cracking ice, a visible boundary, and a distinct audio cue.
- Give players approximately 1.5 seconds of warning as an initial tuning target.
- Preserve reachable safe spaces or escape lanes; never cover every reachable tile without counterplay.
- Define how the attack crosses terraces and whether cliffs block it. The warning must accurately show the resulting danger on every affected height.

**Venom Rush — dash with poisoned frost**

- Telegraph the dash direction before committing.
- Respect cliffs and connector geometry; any special traversal must be deliberately authored and visibly communicated.
- Leave poisoned snow or ice along the actual dash path.
- The field slows anything walking through it: players, raiders, Delgado, and the boss itself.
- Initial balance target: 30% movement reduction and an 8–12 second field lifetime.
- Differentiate the active hazard from ordinary snow and cosmetic frost.
- The requested baseline effect is slowing. Additional poison damage requires an explicit balance proposal.

Add coordinated phases at approximately 70% and 35% health. Later phases should change attack combinations, direction choices, and pressure while retaining readable warnings and recovery windows.

Provide tuning for health, damage, cooldowns, dash speed, field density, and party scaling. Respect existing ammo rules, including Armor Piercing, Incendiary, Explosive, Lightning, and boss slow caps. Define terrain/status slow stacking and a movement-speed floor to prevent accidental permanent immobilization.

Prevent overlapping boss hazards from removing every escape route during the finale. Bound field count and lifetime, and send authoritative attack and hazard state to guests and reconnecting players.

## 4. Operation Whiteout campaign

Add a selectable **solo/co-op campaign** that connects the existing maps and Frostpeak into one continuous run.

Recommended initial structure:

| Chapter | Map | Narrative purpose | Encounter direction |
| --- | --- | --- | --- |
| 1 | The Yard | Defend the outpost and recover the evacuation route. | Introduce a revamped existing boss with a new attack combination. |
| 2 | Riverbend | Cross the frozen supply corridor. | Use river routes and environmental pressure in the boss encounter. |
| 3 | Ashfall Quarry | Secure power and supplies for the summit. | Combine quarry terrain with a stronger, readable boss encounter. |
| 4 | Frostpeak | Hold the summit and confront the source of the poisoned frost. | Defeat The Rime Colossus, then survive the final evacuation rush. |

Use three raids per chapter as the starting proposal, with a chapter boss on the third raid. Tune total run duration and preparation time through playtesting.

Convey the story through short chapter cards, environmental details, and concise objective messages. Allow players to proceed quickly through these transitions.

### Stronger, revamped campaign bosses

Each boss used in the campaign needs a meaningful encounter upgrade: a new move, a changed sequence, terrain-aware positioning, or a coordinated phase. Increase health and damage only as part of a broader encounter design.

Campaign variants should have clear tells, exploitable recovery windows, fair party scaling, and documented interactions with modifiers. Preserve the established balance of their ordinary-mode versions.

### Continuity between chapters

Define and implement a complete carryover contract:

- Carry class, match upgrades, equipped ammo, verified skill effects, salvage, materials, and shared Delgado upgrades through the run.
- Explicitly define health recovery, downed-player recovery, grenades, core health, and transition repair costs. Prevent free healing or salvage exploits caused by reconnects or repeated transitions.
- Reset map-specific walls and terrain deliberately; document any refund or retained-building policy.
- Provide a short preparation opportunity at each new map using the existing Armory.
- Make transitions host-authoritative and safe for slow guests, late joins, disconnections, and reconnects.
- Identify the run, chapter, local raid, completed encounters, and each player's participation consistently across clients and rewards.

Enable the existing special ammo system in the new solo/co-op campaign. Preserve its slot limits, prices, skill gates, and PvP exclusions. Declare supported campaign modifiers and their interactions; do not silently inherit incompatible Blitz-only rules.

### One five-minute finale

After the final chapter boss, start **one five-minute rush at Frostpeak** using the existing Final Blitz and evacuation framework.

- The core must survive the first four minutes.
- Evacuation opens for the final 60 seconds under the standard rule.
- Each player must reach the evacuation zone personally.
- Apply existing extracted/missed-player reward semantics consistently and explain them in the results screen.
- Preserve the limit of four concurrent bosses. Queue additional spawns while that limit is reached.
- Define the campaign finale's boss roster and spawn cadence explicitly.
- Keep the evacuation route reachable across elevations and clearly indicate its location and remaining time.

If a supported modifier changes the evacuation window, display the actual rule. Award each encounter and final result once, including when a player reconnects or a claim is retried.

## 5. Winter cosmetics: exactly 42 new items

Produce these exact quantities:

- **10 skins and 10 matching headgear items.**
- **10 backgrounds, exactly four animated.**
- **Six tracers, exactly two Gold tier.**
- **Six kill effects, exactly two Gold tier.**

Each skin/headgear pair needs its own silhouette, material treatment, construction details, and winter identity. Keep the existing tactical character proportions, weapon readability, class poses, and procedural rendering style. Headgear must also work on other supported skins, including Tung Tung Tung Sahur.

The following catalog is proposed art direction. Preserve the counts and tier requirements if names or concepts are refined.

### Ten skin and headgear pairs

| Skin | Matching headgear | Distinctive visual direction |
| --- | --- | --- |
| Snowline Scout | Snowline Goggles | Compact white field jacket, wrapped boots, climbing straps, and amber snow goggles. |
| Summit Ranger | Ranger Ushanka | Deep green mountain kit, reinforced shoulders, rope harness, and fur-lined winter cap. |
| Glacier Engineer | Surveyor Helmet | Blue-gray insulated utility suit, repair tools, frost-marked plates, and a survey lamp. |
| Polar Rescue | Rescue Hood | Rescue-orange parka, reflective trim, medical packs, and a structured storm hood. |
| Evergreen Sentinel | Evergreen Crown | Layered evergreen armor, restrained pine details, bark-toned straps, and branch-shaped headgear. |
| Yuletide Quartermaster | Quartermaster Cap | Burgundy winter coat, brass hardware, supply pouches, and a fitted seasonal cap. |
| Gingerbread Grenadier | Icing Helmet | Biscuit-toned tactical armor, inset icing seams, candy accents, and a shaped combat helmet. |
| Nutcracker Vanguard | Parade Shako | Structured red and navy uniform, sculpted armor, brass fasteners, and a tall military hat. |
| Rimebound Warden | Rime Crest | Ice-plated expedition armor with an angular silhouette, fractured frost edges, and an icy crest. |
| Aurora Sovereign | Aurora Halo | Premium polar armor with bounded aurora accents, luminous trim, and a restrained animated halo. |

### Ten backgrounds

| Background | Motion |
| --- | --- |
| Summit Command | Static |
| Frozen River Crossing | Static |
| Snowed-In Quarry | Static |
| Abandoned Ski Station | Static |
| Winter Supply Depot | Static |
| Lanternlit Outpost | Static |
| Aurora Over Frostpeak | Animated aurora ribbons and sparse drifting snow |
| Whiteout Watchtower | Animated wind-driven snow and slow beacon sweep |
| Yuletide Hangar | Animated warm lights and gentle steam |
| Midnight Evacuation | Animated searchlights and restrained distant rotor/snow effects |

Animated backgrounds must use the existing background system, scale to phone layouts, retain readable UI contrast, and respect motion/performance settings.

### Six tracers

| Tracer | Tier | Visual direction |
| --- | --- | --- |
| Snowstreak | Rare | Fine white trail with sparse snow motes. |
| Glacier Shard | Rare | Short translucent ice fragments. |
| Candyline | Epic | Restrained red and white spiral accents. |
| Polar Spark | Legendary | Cool sparks with a brief crystalline tail. |
| Aurora Lance | Gold | Layered aurora ribbon, icy core, and bounded prismatic particles. |
| Solstice Comet | Gold | Warm gold core, winter star accents, and a crisp frost wake. |

### Six kill effects

| Kill effect | Tier | Visual direction |
| --- | --- | --- |
| Snow Puff | Rare | Compact snow burst and quick fade. |
| Frost Fracture | Rare | Readable crystal break with small ice pieces. |
| Ornament Pop | Epic | Brief seasonal ornament burst with restrained fragments. |
| Winter Bloom | Legendary | Expanding snowflake pattern and frost petals. |
| Borealis Collapse | Gold | Layered aurora implosion followed by a crystalline ring. |
| Solstice Supernova | Gold | Gold-white winter starburst, ice halo, and controlled trailing sparks. |

Gold effects should have the strongest visual craft while preserving combat readability. Cosmetic effects must not change damage, hitboxes, collision, status effects, targeting, or visibility rules.

### Cosmetic integration requirements

- Register stable IDs, tiers, categories, acquisition sources, descriptions, and previews in every required client/server catalog.
- Use the existing self-contained wardrobe renderer factory, worker-compatible helpers, and bounded caches.
- Ensure equipped characters, thumbnails, Locker previews, lobby stages, remote players, aiming poses, downed poses, and all supported viewing angles agree.
- Bound particles, animation work, and temporary allocations. Reuse shared painters for previews and gameplay.
- Give all 42 items a real acquisition path. Milestone rewards must come from this collection rather than increasing its count.
- Propose case contents and costs for the remaining items using the existing case economy. Supply a complete acquisition table before final tuning.

## 6. Frostpeak and boss milestones

Add dedicated Frostpeak map and Rime Colossus boss ladders through the existing milestone system.

Use the current four-stage thresholds as the starting recommendation:

- Frostpeak raids held: **250 / 500 / 1,000 / 2,500**.
- Rime Colossus defeats: **25 / 50 / 100 / 250**.
- Reward rarities: **Rare / Epic / Legendary / Gold**.

Suggested map ladder rewards: Snowline Scout, Summit Ranger, Glacier Engineer, and Aurora Sovereign.

Suggested boss ladder rewards: Polar Rescue, Evergreen Sentinel, Nutcracker Vanguard, and Rimebound Warden.

Their matching headgear and the other collection items still need explicitly assigned acquisition sources. Recommend alternative thresholds if measured campaign pacing makes these ladders unreasonable.

Count actual Frostpeak raids and actual boss defeats in eligible modes. In a campaign, credit each chapter to its real map. Preserve current participation rules for ordinary, extra, and finale boss kills. A transition, reconnect, or retry must not duplicate milestone progress or rewards.

Implement server-side counters, unlock validation, profile synchronization, progress labels, notifications, and results presentation. Preserve existing ownership and progression.

## 7. Invite friends directly from the Friends list

Add a real **Invite to Lobby** action for accepted friends when the sender has an active room they are allowed to invite into.

### Player flow

1. The sender selects Invite beside an accepted friend.
2. The recipient receives an in-app invitation identifying the sender, room, mode, map or campaign chapter, and available slots.
3. The recipient can Accept or Decline.
4. Accept uses the existing room join flow and reports a clear outcome.

Support public and private/unlisted rooms. Keep the existing room-code and share-link flows available. Clarify behavior for locked rooms, full rooms, departed hosts, expired invitations, incompatible clients, duplicate invitations, and invitations received during another match.

Require a deliberate confirmation before accepting an invitation that would leave the recipient's current room or active run. A notification must not silently move the player.

### Backend and reliability

- Extend the existing Friends and notification systems with authenticated invitation operations.
- Validate the accepted friendship and sender's current room authority. Public lobby discovery alone cannot validate invitations to private rooms; use an appropriate authenticated room registration or equivalent current room record.
- Bind invitations to the room session/incarnation as well as its code so an old invitation cannot join a different room that later reuses that code.
- Use expiry, duplicate suppression, and reasonable rate limits.
- Revalidate availability and compatibility when accepting.
- Make accept/decline operations safe to retry and preserve the existing account-switch race guards.
- Keep the UI compact, usable with touch and controller, and consistent with current Friends polling and notifications.

This feature uses in-app notifications. OS push notifications and external messaging are separate scope.

## 8. Integration and performance requirements

Trace every affected shared system rather than updating only the visible menu:

- Map/mode selectors, labels, records, lobby publication, discovery, and friend presence.
- Host action validation, state snapshots, late join, reconnect, and protocol compatibility.
- Armory, ammo, skills, modifiers, boss scheduling, pathfinding, and damage attribution.
- Account reward claims, queued claims, map/boss milestones, cosmetic acquisition, and result screens.
- Source assembly order, generated deployment files, service worker, CSP, and offline behavior.

Audit database constraints for the new campaign mode, including the lobby length/mode constraint that previously prevented Blitz rooms from being published. Inspect current migrations and live definitions; treat the historical `schema.sql` as incomplete until verified.

Prepare focused migrations and server tests for changed account/social/reward behavior. Follow current session authorization when applying migrations or releasing. Never trust client-supplied unlocks or balances, or expose account access tokens to peer hosts.

Measure the existing build and candidate using the same device, browser, resolution, player count, and workload. Include a six-player Frostpeak finale with multiple bosses, terrain hazards, winter cosmetics, and ammo effects. Record frame cost, frame-time spikes, particle/hazard counts, cache growth, snapshot size, and bandwidth.

Use an initial target of no more than 20% added frame cost over a comparable measured baseline, then state the actual achieved result. Desktop tests at phone viewport sizes must be identified accurately; report physical-phone evidence separately when available.

Keep the Armory usable without page scrolling in supported phone portrait and landscape layouts. New campaign and Friends controls must fit the existing compact interface and input model.

## 9. Implementation sequence

Complete the expansion through reviewable slices:

1. **Baseline and contracts:** confirm architecture, capture performance, define height/combat rules, campaign continuity, reward accounting, and the 42-item acquisition table.
2. **Elevation vertical slice:** one lower lane, one connector, one summit area, host/guest traversal, aiming, bullets, enemies, Delgado, and reconnect.
3. **Frostpeak and boss:** complete both map sizes, pathing, construction, original boss phases, hazards, and ordinary-mode integration.
4. **Campaign:** transitions, carryover, revamped encounters, one final rush, personal evacuation, and server-validated progression.
5. **Cosmetics and milestones:** produce and integrate the full collection, previews, ownership, counters, and acquisition paths.
6. **Friend invitations:** implement the complete sender/recipient flow and server validation, including private rooms.
7. **Verification and release preparation:** assemble production output, inspect the diff, run relevant checks, document balance and limitations, and prepare the release under the current authorization.

Advance only when the shared behavior needed by the next slice works. Deliver playable implementation when executing this work order; screenshots and mockups alone do not satisfy it.

## 10. Required verification and deliverables

Provide:

1. A concise architecture summary and record of resolved design decisions.
2. The complete implementation and reviewable migrations.
3. A balance sheet for campaign pacing, bosses, hazards, party scaling, Armory carryover, rewards, and milestone thresholds.
4. A catalog of all 42 cosmetics with rarity, acquisition, animation status, and preview evidence.
5. Verification results covering:
   - Elevation traversal, cliffs, connectors, blocked routes, construction, projection, aiming, and combat across heights.
   - Solo and host/guest co-op, six-player stress, late join, reconnect during ramps/chapters/finale, and incompatible protocol handling.
   - Campaign carryover, losses, mixed evacuation outcomes, map/boss credit, and repeated reward claims.
   - All new cosmetics, Sahur headgear fit, remote visibility, and effect budgets.
   - Friend invitations: accept, decline, expiry, duplicates, private/full/locked/stale rooms, and account switching.
   - Mobile portrait/landscape, keyboard, controller, the compact Armory, production build, offline launch, and affected existing modes.
6. Measured performance and network results, with test-device details.
7. Release notes and an honest list of remaining limitations.

Use focused automated checks and manual playtests for the systems changed. Broaden testing when a shared-system change or observed failure creates a concrete regression risk.

## Acceptance criteria

- Frostpeak is a complete standard/XL map with an elevated summit core and functioning uphill routes.
- Height affects movement and combat consistently on host and guest clients.
- The Rime Colossus has its own visual identity, huge readable area attack, and dash-generated poisoned frost that slows every walking actor crossing it.
- One continuous campaign visits all four maps, includes meaningfully revamped boss encounters, and ends with one five-minute rush and personal evacuation.
- The collection contains exactly 10 skins, 10 matching headgear, 10 backgrounds with four animated, six tracers with two Gold, and six kill effects with two Gold.
- Frostpeak and boss milestones award the intended items without duplicate credit or invalid unlocks.
- Accepted friends can exchange and accept actual in-app lobby invitations, including invitations to private rooms.
- Existing modes, progression, offline behavior, multiplayer, and the compact mobile Armory remain functional.
- Performance, balance, and verification are supported by recorded evidence.
