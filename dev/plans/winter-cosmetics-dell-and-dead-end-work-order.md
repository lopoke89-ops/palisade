# PALISADE: Winter Cosmetics, Delgado Commands, Dead End, Riot Shield Durability, and Four-Angle Catalog

**Work order date:** October 1, 2026  
**Repository:** [lopoke89-ops/palisade](https://github.com/lopoke89-ops/palisade)  
**Status:** Implemented locally as v0.9.6.1 / yard-22. The additive backend catalog migration is live. See the [completion report](../evidence/2026-10-01-winter-upgrade/README.md), [36-suite verification](../evidence/2026-10-01-winter-upgrade/verification.json), and [311-entry four-angle catalog](../catalog/cosmetics/README.md). The game build awaits release; dense software-rendering cost and unverified physical-phone/Safari/WAN behavior are documented in the report.

## Role and objective

Act as a senior computer engineer with responsibility for Canvas 2D character art, rendering performance, gameplay AI, multiplayer state, UI, and regression testing in the existing PALISADE project.

Improve the winter cosmetics, make Delgado useful through two player-controlled command modes, resolve modifier combinations that leave a match unable to progress, and give riot shields durability measured by bullet impacts. After the changes are complete, analyze and catalog every cosmetic using four visual angles wherever an item has a meaningful orientation.

Use the existing procedural Canvas 2D character and tracer systems. Deliver distinct model geometry and readable effects at actual gameplay scale. The three new skins must look like different characters, with distinct silhouettes and anatomy.

## 1. Establish the baseline

Inspect the current default branch, applicable project instructions, working tree, source order, build process, and current cosmetic and result contracts before editing. Preserve unrelated work.

This order was grounded in `main` at commit `07eb5e54d53525277f6f8839e6d7b0e4a5617680`. The developer README reports v0.9.6.0 and protocol `yard-21`; verify these again at implementation time.

The inspected systems include:

- Procedural isometric character rendering, wardrobe previews, and shared tracer painters.
- A Winter Case, currently priced at 14 shards, with rarity weights Common 45%, Rare 32%, Epic 16%, Legendary 6%, and Gold 1%.
- A documented winter collection of 42 cosmetics: 10 skins, 10 hats, 10 backgrounds, six tracers, and six kill effects.
- Host-authoritative solo/co-op simulation, reconnect state, campaign progression, and Final Blitz evacuation.
- Delgado repair, revive, gathering, supply, and combat behavior. His current idle job holds near the core; he currently has no requested command selector or perimeter-construction job.
- Flag tracers with one palette color per shot, shared by the pellets of that shot.
- Shieldbearers whose riot shields currently block frontal bullets indefinitely across roughly a 130-degree arc; armor-piercing ammunition can pass damage through, and blasts bypass the shield.
- `LAST STAND` (`laststand`), which suppresses timed raid respawns while permitting assisted revives, and `ON YOUR OWN` (`alone`), which removes Delgado.

Interpret the user's “Christmas case” as the existing **Winter Case**, and “aura lance” as **Aurora Lance** (`trail:auroralance`). Do not introduce a second seasonal case for this work.

Keep cosmetic IDs, existing numeric catalog indices, saved equipment, and `palisade.*` storage keys compatible. Edit source modules and rebuild generated files with the established build process. Review protocol/version requirements for any network contract changes.

## 2. Create three distinct winter model skins

Working names and the first two rarity assignments below are proposed design defaults. The user requires the third skin to be Gold tier.

| Skin | Proposed rarity | Required model and visual direction |
| --- | --- | --- |
| Yulemaw | Epic | An original green Christmas monster with a broad, hunched silhouette, shaggy green shapes, expressive face, oversized hands, and red winter clothing or pale fur trim. Seasonal details must read clearly without depending on a plain green recolor of an existing soldier. |
| Rednose Demolisher | Legendary | A clearly bipedal reindeer with antlers, a muzzle, a visibly red nose, hoof-like feet, and a combat harness. Model grenades attached at the hip so they remain recognizable in side and rear views. Keep enough nose glow to communicate the identity without washing out the face. |
| Gilded Frostborn | **Gold, required** | An original Jack Frost-like winter character with a slender icy silhouette, frost-shaped hair or crown, sculpted ice clothing, pale blue/white materials, and restrained gold trim. Add Christmas-themed cosmetic FX such as drifting snowflakes, small holiday sparkles, or ornament-like motes. Gold denotes rarity; preserve the icy character identity. |

### Art and animation requirements

- Build unique head, torso, limb, and accessory geometry appropriate to each character. A palette swap, added hat, or isolated face replacement does not satisfy a unique model skin.
- Support the game's existing classes, weapons, idle and walking poses, aim/facing changes, firing, and downed poses. Keep weapon grips, muzzle placement, shadows, and depth ordering aligned with the model.
- Treat the reindeer's hip grenades as visible cosmetic equipment. Preserve existing grenade inventory and combat behavior.
- Treat Frostborn's Christmas FX as part of the skin presentation. Keep these separate from equipped kill effects and tracers; do not create extra inventory items unless the scope is deliberately expanded.
- Define headwear compatibility for custom heads, antlers, and ice crowns. Incompatible hats should use the existing restriction/fallback behavior rather than clipping through the model.
- Verify full-model readability in the Locker, case reveal, actual combat, mobile viewports, and standard/XL maps, including elevated Frostpeak terrain.
- Respect reduced motion and existing effects-quality settings. Cap effect counts and lifetimes, reuse established caches/pools, and avoid per-frame or per-shot canvas allocation.

### Add all three to the Winter Case

Register three new stable skin IDs, names, descriptions, rarities, and winter collection membership. All three must be obtainable from the existing Winter Case; milestone-only acquisition does not satisfy this request.

Update the local catalog and picker, Locker, case preview/reel/reveal, equip/load/save paths, multiplayer look replication, and the authoritative account-backed case catalog. Keep the current case price, rarity weights, duplicate handling, and existing acquisition contracts unless a separate balance change is explicitly approved.

Use the established Supabase migration workflow for required catalog updates, maintain the restore schema, and verify client/server catalog parity and a real or appropriately isolated authoritative case roll. Do not count a local preview as proof of server-backed acquisition.

If the baseline remains unchanged and only these three skins are added, the winter collection becomes **45 items with 13 skins**. Reconcile tests and documentation that currently assert 42 items or 10 skins. Existing winter rewards must remain obtainable.

**Acceptance:** All three skins are distinct in silhouette, display and animate correctly, can be acquired and equipped through the Winter Case, persist through reload/reconnect, and appear correctly to other players. Frostborn is Gold and has visible Christmas FX.

## 3. Refine the requested tracers

Make changes in the shared rendering path so gameplay, Locker previews, case previews, and multiplayer agree. Preserve projectile damage, speed, range, hitboxes, fire cadence, sound identity, and the existing color sequence.

### Aurora Lance: snow-dust wake

Add a fine snow-dust trail **behind** the projectile along its actual travel path. Preserve the mint/violet aurora identity and icy core. Use small, short-lived white/icy motes with a soft fade; the wake should read as snow dust and stay subordinate to the bullet.

The dust must follow changes in aim, motion, and elevation. Keep emission bounded under rapid fire and multiple simultaneous players, and respect effects-quality settings.

### Solstice Comet: Christmas-light trail

Add small, recognizable Christmas light bulbs trailing behind the comet. Use a restrained seasonal sequence, such as red, green, warm yellow, and icy blue. Keep the warm Gold comet head and established winter identity.

Space bulbs along the travelled trail so they read as lights instead of unrelated confetti. Use brief fade-outs and restrained glow. Any twinkle must respect reduced motion and avoid rapid full-screen flashing.

### Every flag tracer: consistent bullet shape

Replace the special rectangular flag-bullet shape with the same streamlined body, head, and taper used by the game's other comparable tracers. Calibrate visible length and thickness against those tracers at the same scale.

Preserve the existing contract: **each shot selects the next flag-palette color, each bullet keeps its assigned color for its lifetime, and all pellets from one shotgun shot share that selected color.** Preserve palette order, including existing special palette handling. The sequence must remain deterministic for host, guests, and reconnects.

Keep dark and white palette entries readable through a restrained outline or contrast treatment. Preserve their assigned fill colors. Flag backgrounds keep their existing palettes and artwork.

### Legendary and Gold flag tracers: matching particles

Add particle FX to every Legendary and Gold flag tracer. Resolve particle color from the emitting bullet's stored color selection, so red bullets shed red particles, blue bullets shed blue particles, and so on.

Do not read an actor's next-cycle color when spawning particles from an older bullet. Keep white and dark particles readable with contrast treatment while retaining the selected color. Differentiate Legendary and Gold through restrained density, shape, or finish; both must use matching colors. Lower-rarity flag tracers retain the requested shape/cycle update without automatically receiving this premium FX addition.

### Glitch Line: approximately 90% layer overlap

Bring the chromatic layers closer together while keeping the layered glitch identity. Interpret “90/10 overlapping” as an initial target of **about 90% shared visible body area with about 10% exposed color fringe**, rather than a layer-opacity ratio.

Measure the visible body at representative scales and animation times. Reduce transverse separation and longitudinal drift relative to the rendered body. Keep the white core readable, retain restrained glitch motion, and bound tear-frame displacement so the tracer does not become widely split again during its animation. Layers must remain distinguishable rather than completely coincident.

**Acceptance:** Capture matched before/after gameplay and preview examples. Aurora Lance has a snow-dust wake; Solstice Comet has a Christmas-light wake; every flag bullet matches comparable tracer geometry and retains its shot-color cycle; Legendary/Gold flag particles match their source bullet; Glitch Line reads as a compact layered projectile with approximately 90% overlap.

## 4. Delgado command modes: Follow Host and Defend Base

Add a clear selector with two states: **FOLLOW HOST** and **DEFEND BASE**. Use the existing HUD/pause/interaction design, expose the active state, and support mouse, touch, and controller input. Keep the control reachable during normal play.

The solo player controls the mode in solo. The host controls the shared Delgado in co-op. Validate commands on the host and replicate the active mode to guests. Persist the command and required job/schedule state through supported reconnects.

Use Follow Host as the proposed initial mode. Hide or disable the command when Delgado is absent, including `ON YOUR OWN` and PvP.

### Follow Host

- Follow the host at a useful trailing distance. Avoid body-blocking, maintain a firing position when possible, and use existing collision, elevation connectors, and pathfinding.
- Fight nearby threats and provide nearby support. A legal urgent revive can temporarily interrupt following; resume the commanded mode afterward.
- Bound repair/gather/supply detours so he does not repeatedly abandon the host for distant work.
- If the host is downed, attempt a legal reachable revive. If no valid host target exists, use a safe base-defense/hold fallback and resume following when the target is available. Prevent repeated failed-path loops.

### Defend Base

Build and maintain a compact defense **around the core**. Proposed layout rule: prefer a **4×4 tile footprint**, with a **3×3 fallback** where terrain or occupied cells make 4×4 impractical. These dimensions describe the outer footprint, not a radius or a solid filled block.

- Construct the perimeter using the existing wall/build system. Keep the core and necessary interior space clear, and preserve legal access to the core, Armory, ramps, player spawn, and evacuation routes.
- Use map coordinates and elevations to choose a deterministic placement anchored around the core; document the anchoring for the even-sized 4×4 footprint.
- Reuse player-built walls where suitable. Do not destroy or downgrade existing defenses to force the template.
- Use existing material costs, legal placement checks, path constraints, wall health, and supported material progression. Delgado should gather needed materials through existing behavior. Avoid unlimited free defenses.
- Build and upgrade during legal preparation windows. Fight, defend, and repair during raids where existing rules permit it. Urgent legal revives can interrupt work.
- If neither footprint is fully feasible, build the legal reachable perimeter portions and expose a useful blocked/resource status. Never trap an actor or stall the simulation while waiting for an impossible layout.

### Upgrade every five completed raids

Queue one construction-upgrade milestone after completed raids **5, 10, 15, 20, and so on**. Apply the next supported upgrade to eligible perimeter structures during the next legal preparation window, subject to materials and normal caps.

Track this schedule separately from Delgado's Armory weapon level (`game.dellLv`). Base it on completed raids across campaign transitions; exclude Final Blitz boss-spawn events from the raid count.

Record which structures received each milestone so repeated ticks, mode switching, and reconnects cannot apply an upgrade twice. Queue unfinished work when materials or reachability are insufficient. Switching back to Defend resumes the current layout and pending milestone; it must not grant catch-up upgrades repeatedly. Repairs/replacements should target the earned construction tier using legal costs.

Honor modifier restrictions, particularly `LOCKDOWN`, and existing raid/Final Blitz construction rules. If a match ends immediately after raid 5 or 10, the pending milestone must not reopen the match or create an extra build phase.

**Acceptance:** The host can switch modes repeatedly; guests see the selected mode; Follow keeps Delgado near the host; Defend produces a legal 4×4 or 3×3 perimeter; milestones occur exactly once every five completed raids; blocked layouts and insufficient materials remain safe; reconnect and modifiers preserve correct behavior.

## 5. Resolve unrecoverable matches with Dead End

First reproduce the reported soft lock, including `LAST STAND` plus `ON YOUR OWN` in solo and co-op. Capture the actual player, Delgado, phase, respawn, and progression state. The current implementation uses a very large respawn timer for Last Stand; do not treat that sentinel as a meaningful pending respawn.

Create one host/solo-authoritative check for an **unrecoverable crew state**. The primary trigger is all participating players down/out, no valid timed respawn, no living eligible reachable rescuer, and no already-resolving legal transition that would restore play or finish the match.

Derive this from the actual recovery rules. Check after death/disconnection changes and relevant simulation/phase transitions. Resolve simultaneous revives, last-enemy deaths, raid completion, campaign changes, extraction, and core destruction in a documented order.

- Do not end a match merely because the local player or host is down while a teammate can still act.
- Do not trigger while a permitted timed respawn or an active legal revive can recover the crew.
- Do not rely on the core eventually being destroyed to end an already unrecoverable match.
- Preserve a legitimate already-committed raid-completion/build revival or evacuation outcome. Escaped players retain their earned personal outcome even if the remaining crew reaches a dead end.
- Exclude menu demos, lobbies, inactive/disconnected placeholders, and PvP's normal respawn flow.
- An alive Delgado must have a legal recovery path; repeatedly failing an unreachable revive must not keep the match alive forever.

### Required screen sequence

**Unrecoverable crew → DEAD END → fade → existing end-match/results screen.**

Show the exact title **DEAD END** and a short explanation such as “No one left can get the crew back up.” Proposed timing is a 1.5-second readable hold followed by a 0.6-second fade; tune this to the existing UI. Reduced motion should retain the message and use a minimal transition.

Once committed, freeze gameplay input/simulation as appropriate, close conflicting overlays, cancel progression timers, and finalize the outcome exactly once. Persist/broadcast an end reason and enough transition state that guests and reconnecting players see the correct screen without restarting rewards or resurrecting gameplay.

Reuse the established loss/results/reward pipeline. Add an explicit crew-wipe/dead-end reason so the results screen does not claim the core was destroyed when it remains intact. Verify that authoritative result validation accepts the actual loss state and does not require falsifying core health. Preserve eligible completed-raid rewards, loss rules, statistics, and existing finalization guards.

**Acceptance:** Every verified unrecoverable state reaches results without waiting for enemy AI or core damage. DEAD END appears once before the fade. Recoverable control cases continue normally. Solo, host, guests, and reconnects agree, and rewards finalize once.

## 6. Riot shields: durability based on bullet count

Give every functional riot shield a finite **bullet-impact budget**, separate from its carrier's health. Each qualifying bullet impact removes exactly one unit of shield durability, regardless of the bullet's damage. A weak rifle bullet and a high-damage sniper bullet must consume the same one unit when each contacts the shield.

Apply this to the existing shieldbearer's working riot shield and any other functional riot-shield variant found during inspection. Decorative shield details on cosmetic outfits do not become gameplay equipment through this change.

### Impact-count contract

Use an explicit integer maximum and remaining count, such as `shieldHitsMax` and `shieldHitsLeft`, plus a durable broken state. **Proposed starting balance: 20 qualifying bullet impacts per standard riot shield.** This is an initial tuning target; keep the limit in a named configuration value and record the chosen final value in the balance evidence.

- Count an impact only when a live hostile bullet contacts an intact shield within the existing frontal blocking arc, with valid collision, line-of-sight, and height conditions. Shots that miss, expire, hit cover first, or strike the carrier from an unprotected side do not consume shield durability.
- Each physical bullet counts once. Each shotgun pellet is a separate bullet: five pellets hitting the shield consume five units; a volley with only two shield contacts consumes two. Do not collapse the count to trigger pulls or volleys.
- Count Delgado's qualifying bullets by the same rule. Preserve existing team/friendly-fire eligibility; harmless friendly contacts do not wear the shield down.
- Damage upgrades, critical hits, distance falloff, weapon damage, difficulty damage multipliers, and cosmetic tracer selection never change the number of durability units consumed by a bullet.
- Deduplicate a bullet's contact with the same shield across collision substeps, repeated frames, penetration handling, and network replay. Clamp the remaining count at zero.
- Shield durability does not regenerate with time. Medic healing restores eligible carrier health without restoring shield hits. A newly spawned carrier receives a new shield; snapshot/reconnect reconstruction must retain the existing shield's count.

### Blocking, armor piercing, and nonbullet attacks

While the shield remains intact, preserve the existing front/side/rear protection geometry and normal blocking behavior.

An armor-piercing bullet that contacts the frontal shield consumes **one** durability unit and still applies the existing rank-based penetration damage to the carrier. Preserve its established compatible ammunition effects. AP rank and damage do not grant extra shield wear.

Grenade blasts, rockets, fire/burn ticks, blast or chain secondary effects, melee, and other nonbullet effects do not consume this bullet-impact budget. Preserve their existing effects on carrier health. A bullet carrying a secondary effect still consumes only one unit for its direct shield contact, and existing rules determine whether the secondary effect applies.

Define the final-hit order explicitly: an ordinary bullet that consumes the last durability unit is still blocked, then breaks the shield. It does not also deal unrequested overflow damage to the carrier. AP retains its normal penetration damage on that hit. Later bullets, including later pellets processed in the same tick, encounter the broken shield and can damage the carrier through the formerly protected front.

### Break behavior and readable Canvas 2D feedback

At zero durability, stop frontal bullet blocking immediately and permanently for that shield's lifetime. The carrier remains a living enemy with normal health, movement, pistol attacks, rewards, and death handling; breaking equipment alone does not kill the carrier or grant kill rewards.

Show distinct intact, worn, and nearly broken shield states using restrained bullet marks, cracks, or damaged panels. Add a brief hit reaction and one clear break cue with bounded fragments/sparks and an appropriate sound. Remove, lower, or visibly disable the broken shield so its artwork agrees with its collision state from front, side, and rear views.

Replace or disable shield-specific bashing/defensive poses after breakage while retaining sensible existing combat behavior. Any durability indicator must communicate remaining bullet hits, not an HP or damage percentage. Keep the cue readable at gameplay/mobile scale and honor reduced-motion and effects-quality settings.

### Multiplayer state and persistence

Only the host/solo simulation validates contacts, decrements durability, and commits breakage. Replicate remaining/max hits and broken state through the existing enemy snapshots, supported reconnect/start state, and any replay/event paths needed for consistent presentation.

Guests may show local hit feedback using authoritative events, but must not independently spend shield durability. Concurrent shooters and shotgun pellets must not cause lost decrements, double decrements, or repeated break FX. Review the protocol version when extending enemy state, and preserve existing enemy type indices.

**Acceptance:** A standard shield breaks after exactly its configured number of eligible bullet contacts for both low- and high-damage weapons. Partial misses and side/rear hits do not consume durability; every contacting pellet counts individually; AP consumes one hit while retaining penetration; nonbullet effects leave the hit budget unchanged; the breaking ordinary bullet is blocked and subsequent frontal bullets hurt the carrier; host, guests, and reconnects agree on wear/break state and show the break cue once.

## 7. Analyze and catalog every cosmetic after implementation

Generate the catalog from the final runtime registries so it covers the entire cosmetic library, including base/default looks, shop/case items, milestone rewards, seasonal collections, special models, headgear, tracers, kill FX, and backgrounds. Reconcile any renderer entries that are not represented as inventory items and label their status.

Deliver:

- `dev/catalog/cosmetics/README.md`: a browsable index and capture conventions.
- `dev/catalog/cosmetics/catalog.json`: a machine-readable inventory keyed by stable cosmetic ID, with schema/version metadata.
- Labeled PNG contact sheets grouped by cosmetic category and collection, with links from the index.
- Brief findings for every cosmetic and a consolidated list of visual, fit, readability, duplication, acquisition, or performance issues discovered during the audit.
- A repeatable capture/export command or script that regenerates the index, data, and sheets from the current build.

### Exactly four angle captures

Use **front, right, back, and left**, separated by 90 degrees around the model/tracer. Document the mapping to the game's isometric world/view convention and keep it consistent. Produce exactly four orientation panels per directional item; do not generate the usual eight-angle catalog sheets.

For skins and hats, hold camera, scale, lighting, pose, and animation time constant across the four views. Show enough margin for antlers, crowns, and accessories. Capture headgear on a documented neutral reference model and record compatibility with other models/classes.

For tracers, use four firing directions with the same speed and sample age. Include the complete flag-color cycle as labeled swatches or samples within those four direction panels. Include particles/wakes in the preview and document their timing.

For nondirectional kill FX and backgrounds, do not invent rotations: use four labeled representative phase/time samples for animated items, or one representative panel for a static item. Clearly identify sample type so readers do not mistake time samples for angles. This four-angle rule applies to the reference catalog; preserve any broader automated pose-coverage tests needed for gameplay correctness.

### Required per-item record

Record ID/key, name, category, collection/case, rarity, acquisition/price or milestone requirement, description, palette/color-cycle data, model or renderer entry point, source file, motion/particle behavior, capture angles or times, preview paths, supported classes, headwear/model compatibility, quality/reduced-motion behavior, and audit findings. Use “not applicable” where a field does not apply.

Record the source commit/build version and capture seed/time. Verify total counts against final registries, detect missing/duplicate IDs, and flag local/server acquisition mismatches. The new skins and modified tracers must be represented in their final state.

**Acceptance:** Every final cosmetic has a searchable record and linked visual reference; every directional item has exactly four labeled views; counts reconcile; future contributors can regenerate the same catalog without manually assembling lists.

## 8. Implementation map and validation

Start with these existing modules; verify their responsibilities before changing shared code:

| Area | Likely integration points |
| --- | --- |
| Winter models and registration | `dev/src/js/16-characters.js`, `16d-winter-data.js`, `18-cosmetics.js`, `18a-winter-catalog.js` |
| Tracer art, previews, and emission | `dev/src/js/20a-cosmetic-art.js`, `20-locker-ui.js`, `07-effects.js`, `09-actions.js`, winter FX helpers |
| Delgado mode, jobs, and construction | `dev/src/js/13-dell.js`, `04-state-armory.js`, `06-world.js`, `09-actions.js`, `10-phases-bosses.js` |
| Dead End and recovery rules | `dev/src/js/01b-mods-skills.js`, `06-world.js`, `12-players.js`, `10-phases-bosses.js`, `10c-blitz.js`, `10d-winter-campaign.js` |
| Riot shield durability, ammo, and break presentation | `dev/src/js/10-phases-bosses.js`, `14-raiders.js`, `09-actions.js`, `04-state-armory.js`, `16-characters.js`, `15-render.js`, `07-effects.js`, `03-audio.js`, enemy state in `21-online.js` |
| UI and input | `dev/src/page.html`, `dev/src/style.css`, `11-hud-chat.js`, input/controller modules, `22-loop-menus.js` |
| Multiplayer and reconnect | `dev/src/js/05-net-record.js`, `21-online.js`, existing cosmetic/network state |
| Account-backed catalog and outcomes | Existing Supabase catalog/result contracts, migrations, and `dev/supabase/schema.sql` |
| Catalog export | Existing debug registry/painters and presentation/gallery capture utilities; new export under `dev/catalog/cosmetics/` |

Add focused behavior regressions for the requested changes rather than tests that only mirror constants. Extend appropriate existing coverage: `winter_cosmetics`, `cosmetics`, `wardrobe3d`, `headgear_fit`, `flagcase`, `tracer_cycle`, `tracer_network`, `cosmetic_network`, `delgado`, `modifiers`, `mod_synergy`, `multiplayer`, `rejoin`, `winter_reconnect`, `blitz_mode`, `rewards_screen`, `v090`, `v090_net`, `ammo_armory`, and `ammo_network`. Add a focused shield-durability regression that exercises actual collision and post-break behavior.

Required scenario coverage:

| Scenario | Expected result |
| --- | --- |
| Solo, Last Stand + On Your Own, last player down, active raid cannot finish | DEAD END, fade, loss/results once |
| Co-op, same modifiers, entire crew down | All clients reach the same terminal outcome |
| One player down; another remains alive | Match continues; permitted rescue works |
| Crew down; legal timed respawn pending | Match continues to the respawn |
| Crew down; Delgado alive with a legal reachable revive | Match continues to the revive |
| Crew down; Delgado down/absent or unable to legally recover anyone | Unrecoverable check terminates the match |
| Last enemy dies while crew falls; valid build/raid-completion transition exists | Deterministic legitimate progression/result; no false dead end |
| Final Blitz with some players extracted and others stranded | Preserve extracted outcomes and finalize remaining losses once |
| Disconnect/reconnect during Dell milestone or Dead End fade | No duplicate upgrade, payout, or transition |
| Flag shots and shotgun volleys observed by host/guest | Same shape, sequence, and per-bullet particle color |
| Equal frontal impact counts from low- and high-damage bullets | Same remaining durability and exact configured break count |
| Shotgun pellets, partial misses, flank/rear hits, and repeated collision substeps | One unit per eligible pellet/bullet; no wear for misses/flanks; no duplicate contacts |
| AP ranks and bullet secondary effects versus an intact shield | One unit per direct contact; existing penetration/effect rules preserved |
| Grenades, rockets, burn ticks, secondary effects, and medic healing | Existing carrier-health behavior; no shield-budget decrement or restoration |
| Final ordinary shield hit followed by later same-tick bullets/pellets | Final hit blocked; one break; later frontal contacts damage the carrier |
| Concurrent co-op fire and reconnect to a worn/broken shield | Matching authoritative counts/visuals; no duplicate break FX or reset |
| Six-player sustained firing on mobile-sized/software-rendered view | Bounded effects, stable memory, measured acceptable frame time |
| Full catalog export | Complete inventory; exactly four orientations for directional items |

Use `python dev/build.py` and the established Windows test runner, for example `powershell -File .\dev\test\run_targeted.ps1 -Tests "winter_cosmetics flagcase tracer_cycle tracer_network delgado modifiers mod_synergy multiplayer rejoin rewards_screen v090 v090_net ammo_armory ammo_network"`, adding focused new checks to the runner as needed. Run additional relevant coverage when shared changes or failures warrant it.

Record before/after frame-time and particle/memory evidence for tracer-heavy scenes on the same device/browser/settings. Visually inspect the three models and all changed tracers at desktop and mobile sizes. Store logs, captures, timings, and catalog validation under a dated development evidence directory.

## 9. Delivery sequence and definition of done

1. Verify baseline, capture existing visuals/performance, and reproduce the modifier soft lock.
2. Build the three distinct skins and integrate all three into the Winter Case.
3. Complete the snow-dust, Christmas-light, flag-shape/particle, and Glitch Line changes.
4. Implement and validate Delgado's two modes, legal perimeter construction, and five-raid upgrades.
5. Implement and validate the unrecoverable-state check and DEAD END-to-results transition.
6. Implement and validate bullet-count riot-shield durability, wear/break presentation, and multiplayer state.
7. Analyze the complete final cosmetic library and generate the four-angle catalog.
8. Rebuild, run relevant checks, inspect visual evidence, and deliver reviewable changes with remaining limitations explicitly documented.

- [x] Three unique model skins are obtainable from the Winter Case; Frostborn is Gold with Christmas FX.
- [x] Aurora Lance, Solstice Comet, every flag tracer, and Glitch Line meet their visual contracts.
- [x] Legendary/Gold flag FX match each emitting bullet's color.
- [x] Follow Host and Defend Base work across verified solo, local co-op, terrain, input methods, and reconnect scenarios.
- [x] Delgado builds legal compact defenses and upgrades them once per five completed raids, up to the existing material cap.
- [x] Unrecoverable modifier states show DEAD END and fade into correct results without duplicate rewards.
- [x] Riot shields wear and break by eligible bullet count, preserve AP/nonbullet rules, and stay consistent across verified multiplayer/reconnect scenarios.
- [x] The complete final cosmetic catalog is searchable, reproducible, and uses four orientation views per directional item.
- [x] Build, 36 relevant gameplay/network/account suites, and visual review pass; measured performance evidence and remaining device/network verification limits are recorded.

The completion report must link the implementation changes, final four-angle catalog, test results, and visual/performance evidence. Distinguish verified behavior from any remaining unverified behavior.
