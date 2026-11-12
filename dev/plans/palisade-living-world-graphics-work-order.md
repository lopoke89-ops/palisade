# PALISADE: THE LIVING WORLD INITIATIVE

## Master prompt for art direction, environment production and graphics engineering

Prepared for Big U, November 12, 2026. This is a reusable production prompt, not a record of implemented enhancements. Give this document to the lead agent coordinating the work. Sections may be assigned to specialist agents, with one integration owner.

**Mission:** Make desktop Palisade feel inhabited, reactive and unmistakably alive. Every environment should communicate purpose, history and ongoing activity. Every player, weapon and enemy should read clearly and belong to that world. Deliver the ambition and production discipline of a major studio while respecting the hardware budget of the game we actually have.

Use Rockstar Games as a reference for the density of believable observations, environmental storytelling, coherent material wear and details that respond to the world. This is a quality benchmark, not a request to reproduce GTA assets, Rockstar branding, fictional businesses or a photorealistic art style. Palisade must become a more compelling version of itself: stylized, block-built, readable from its isometric camera, and immediately recognizable in combat.

The target reaction is: **“This place was here before I arrived, something is happening here now, and the fight changes how it feels.”**

## 1. Start from the real game

Read these before proposing architecture or producing assets:

1. [Desktop environment guide](godot-3d-environments-guide.md), especially §§1–9 and §§11–14. This is the primary orientation document created for this work.
2. [Understrip set-dressing proposal](understrip-set-dressing-plan.md). Preserve its region identities, room purpose, clearance rules and staged review.
3. [Understrip mood boards](understrip/mood-boards.md) and [generator specification](understrip-generator.md).
4. The actual source files named below. Resolve discrepancies against the checked-out code and document the correction.
5. In the separate model library: `art/3d/README.md`, `GODOT_IMPLEMENTATION_BLUEPRINT.md`, `ANIMATION_GUIDE.md`, `UNDERSTRIP.md`, the catalog, weapon profiles and animation manifest.

Workspace orientation at preparation:

- Desktop: `Documents/Palisade/godot-understrip-integration`, branch `codex/understrip-integration`, inspected at `a08ef40`.
- Library: `Documents/Palisade/model-library-github`; game art pin is recorded in `godot/palisade_art/LIBRARY.txt`.
- Test engine: `bench/godot/Godot_v4.7.2-stable_win64_console.exe`. Its reported version was verified as `4.7.2.stable.official.ed1daf0bf`.
- Current renderer: `gl_compatibility`, in `godot/project.godot`.
- Existing baseline images: `bench/env/props_*.png`. Capture fresh matched baselines for the scenes you change.

Recheck HEAD, dirty files, art pin and engine version when starting. These are dated observations, not permission to overwrite later work.

Important interpretation of the environment guide:

- Most environment geometry is built in code; detailed GLB environment dressing requires a deliberate integration path.
- Players and many enemies/bosses use library models. The ordinary weapon-library path and the nine Understrip guns are different: `us_weapons.gd` builds cached procedural meshes. The guide's description of Understrip floor guns as GLBs is inaccurate for the inspected code.
- The guide's material, scale and camera rules describe the existing pipeline. Do not apply its “visible faces” shorthand to rotating characters or freely rotated props: inspect every orientation they actually use.
- Its historic frame-time figures are context, not a fresh performance baseline or a guaranteed budget.
- A mesh surface is not a guarantee of one total GPU draw across shadows and other passes. Measure actual submissions.

## 2. Authority and non-negotiable contracts

You are the combined creative director, environment art lead, character/weapon art lead and rendering engineer. Own a coherent result, not a collection of unrelated visual experiments.

- The simulation remains authoritative. Visual geometry must not secretly change collision, sight, bullets, navigation, damage, enemy behavior, rewards or network state.
- Preserve the camera/HUD alignment. Do not solve an art problem by changing the projection without a separate approved design change.
- Visual dressing may be richer on desktop. Browser/desktop maps and gameplay remain identical. Any gameplay-affecting layout change requires coordinated changes and parity validation.
- Use a separately namespaced, deterministic visual hash or RNG. Never consume generator, combat, enemy or loot randomness for decoration.
- Keep identifiers, equipment slots, weapon sockets, animation names/events, rig contracts and cosmetic ownership stable.
- Preserve the 2D fallback for gameplay-critical information. Desktop-only decorative richness need not trigger a full browser art rewrite.
- Keep combat readable at default zoom, LOW settings, all dungeon brightness options and reduced-motion settings.
- Run tests in an isolated profile. Keep measurements and renders in `bench/`. Preserve the owner's saves and original model sources.
- Work locally in reviewable increments. Follow the owner's commit/push/release approvals; this prompt does not itself approve publishing, engine upgrades, paid dependencies or a production renderer migration.

For each major recommendation explain: **what the player gains, where it appears, what it costs, how it scales down, and how we prove it works.**

## 3. Art direction: life has structure

Do not equate “alive” with covering every floor tile. Build a hierarchy:

1. **Place:** architecture, terrain, routes and a recognizable landmark.
2. **Purpose:** machinery, workstations, storage, signage and infrastructure that explain the location.
3. **History:** repair, wear, abandonment, flood damage, improvised use and evidence of interrupted activity.
4. **Present tense:** subtle motion, localized sound, working fixtures and responses to existing game state.
5. **Player focus:** readable combat space, objectives and interaction points.

Compose dense edges, purposeful clusters and quiet playable space. Pipes must connect to plausible equipment. Wear belongs at contact points. Water stains follow drainage. A service area needs access. Repetition should suggest manufactured systems, while variation suggests use.

Give each region a material vocabulary, dominant/secondary/accent palette, silhouette vocabulary, motion language and sound palette. Maintain a consistent treatment of edge wear, grime, metal, cloth, concrete and emission across characters and surroundings.

Favor silhouette, broad value separation, contact, purposeful motion and recognizable materials over invisible microdetail. Evaluate every asset at actual gameplay size before approving a close-up.

## 4. Dress every map, with a distinct identity

Inventory every playable map and variant from the current source, including both co-op sizes, PvP layouts, special finales and all ten Understrip levels. The following matrix is the minimum coverage; add omitted maps discovered in the audit.

| Environment | Dressing and story | Low-cost life | Protect |
|---|---|---|---|
| The Yard | Repair benches, supply organization, tool racks, perimeter maintenance, wheel marks and worn routes; one recognizable camp landmark | Restrained tarp/flag motion, occasional dust, a few working equipment indicators | Stake, build cells, resource collection and spawn routes |
| Riverbend | Flood-control equipment, bridge repairs, reeds along appropriate edges, abandoned loads, waterlines and drainage | Water movement, reeds, sparse ripples and localized water sounds | Bridges, banks, flood state, water readability and movement rules |
| Ashfall Quarry | Extraction equipment silhouettes, winches, hoses, ore staging, warning boards, damaged service structures | Local dust, exhaust/heat cues, isolated machinery movement | Pits, cracks, burning drums and terrain destruction |
| Frostpeak / Whiteout settings | Expedition logistics, marked routes, shelter supplies, antenna fittings, rope hardware and snow accumulation | Sparse snow drift, wind-driven flags, occasional equipment vibration | Terrace edges, ramps, stairs, handrails and evacuation readability |
| City Black Out | Distinct commercial/service blocks, original storefronts, rooftop plant, delivery clutter, civic infrastructure, repair history and landmarks | Selective neon, failing tubes, vents, controlled window activity and power-state response | POIs, power logic, streets, large enemy counts and rooftop/building occlusion |
| Casino | Hospitality and operations: service stations, cage fittings, organized table accessories, staff-only edges and original signage | Existing staff/bot presentation, small sign cycles and localized machinery activity | Seats, table interactions, cards, bets and critical UI |
| Flood Tunnels | Pumps, valves, pipe runs, silt, drainage, maintenance debris and discarded original casino equipment | Drips, pump vibration, restrained neon spill, intermittent steam | Narrow paths, flood cues, shrines, traders, lift and Pit Boss space |
| Shelter 7 | Civil-defence logistics, bunks in suitable rooms, ration storage, air handling, medical/administrative equipment | Fans, relays, tired fluorescent fixtures and emergency-state cues | Gas, shutters, warning colors and Custodian telegraphs |
| Area 67 | Lab benches, observation systems, specimen equipment, containment fittings and progressively invasive alien material | Instrument pulses, controlled biological motion, alarm responses and containment strain | Acid, gravity surfaces, drones, Gatekeeper and Visitor stages |
| PvP and special arenas | Reuse the appropriate regional kit with deliberate symmetry or equivalent visibility | Cosmetic activity outside contested sightlines | Fair visibility, spawns, cover, objectives and equal quality-setting readability |

Create a coverage sheet listing every map/size/level, its landmark, three story clusters, motion/audio elements, required assets, clearance masks and validation scene.

For each Understrip level, define one recognizable focal feature and at least one room arrangement tied to its actual role. Fit recipes to `sim.lay.us.rooms`, not arbitrary random coordinates. Respect the existing content rules: no tunnel encampments, real casino names, real agency insignia or borrowed game mascots.

## 5. Implement a dressing system that can scale

Prefer a hybrid: preserve efficient procedural foundations; add authored reusable meshes where silhouette or storytelling justifies them. Prove the hybrid with one sample before building an entire asset bank.

Separate three responsibilities:

- **Recipe:** region/room role, asset families, eligible wall strips/corners, density, variation and exclusion rules.
- **Placement:** stable identifiers, transforms, footprint, height, seed, quality tier and optional existing-state binding.
- **Presentation:** cached geometry, materials, culling, animation and disposal.

Propose a compact schema before implementing it. Include asset ID, placement ID, seed namespace, room/map association, transform, visual footprint, camera obstruction class, quality tier, motion class and power-state binding. Store no gameplay authority in this record.

Choose candidates from valid placement masks. Reserve doors, shortcuts, boss gates, interaction approaches, lift rings, spawn cells, loot space and telegraph areas. Check clearance against the actual player radius, camera and encounters. Large solid-looking dressing belongs on existing blocked footprints or outside play; never create an invisible obstacle or a visibly solid object players walk through.

Build static geometry at map/terrain creation, divided into sensible spatial chunks. Use shared resources and MultiMesh where suitable, accounting for per-surface materials and the group's shared culling bounds. Preserve imported child transforms when extracting meshes. Wall-mounted objects must lower or hide with their supporting walls. Rebuild only what changed.

Placement order and quality settings must not change gameplay or randomly relocate landmarks. LOW removes secondary detail, not navigation cues. Put any unsupported placement in a diagnostic report rather than silently forcing an invalid fallback.

## 6. Player, enemy and weapon refinement

Audit the entire asset catalog first. Rank problems by screen visibility, usage frequency, silhouette confusion, material cost and animation defects. Do not mass-reexport approved assets to improve one model.

### Players and cosmetics

Refine proportions, readable equipment, shoulders/hands/face, material separation and strong silhouettes. Preserve the stylized construction and existing cosmetic identity. Fix floating equipment, attachment gaps, poor weapon grip and intersections during motion.

Inspect the four classes, representative light/dark/emissive skins, replacement heads, headgear and large silhouettes. Preserve skeletons, named slots and attachment profiles unless a migration is explicitly scoped. Test idle, movement, strafe, aim, fire, reload, roll, revive, downed and death. Any added breathing or secondary motion remains visual and respects reduced motion; it must not move hitboxes or desynchronize action timing.

Treat skins as art with intentional identity. Do not “upgrade” everything through a universal metallic material or extra glow. Keep cosmetic visibility slots independently controllable where the game requires them.

### Weapons

Audit both the library weapons and the procedural Understrip set. Preserve grip origin, muzzle direction, socket alignment, handedness, class identity and animation timing. Improve receiver/barrel/magazine/stock proportions, negative space, material contrast and readable muzzle openings.

Show each gun in the player's hands, as floor loot, in the shop/Locker presentation where applicable, and during its actual reload/fire action. Detail must survive the gameplay camera. Recoil, pump/bolt motion, muzzle flash and casing effects must follow authoritative events, never imply an extra shot or a different fire cadence.

Choose the production method per family: improve the procedural builder where that is sufficient; use authored GLBs for shapes that justify the extra pipeline. Document the tradeoff. Preserve IDs and all weapon mechanics.

### Enemies and bosses

Make roles readable in silhouette and motion before color. Preserve tell timing, attack reach, weak-point visibility and danger hierarchy. Keep heavy enemies visibly heavy without enlarging a model until it misrepresents its gameplay footprint.

Investigate region-specific raider uniforms identified as missing in the environment guide. Use controlled variants or supported material/slot treatment; do not recolor a merged material blindly and unintentionally tint weapons, skin or equipment.

Review ordinary raiders at crowd density, elites amid effects, and bosses at both stages. Include the Visitor plus support boss and Gatekeeper/pilot transitions. Prioritize the most common enemies before spending the budget on a single showcase boss.

For every revised asset deliver source files, exported resources, stable IDs, bounds, mesh/surface/material counts, texture sizes, rig/clip notes and before/after images. Show a neutral-light turntable and an in-game capture. Preserve unrelated asset hashes.

## 7. Give the world a pulse

Make stillness and activity intentional. Use a small shared ambient controller, spatial activation and stable per-instance phases rather than hundreds of independent scripts updating every frame.

- Continuous, quiet motion: a few fans, signs, reeds, flags, water flows or instruments.
- Infrequent events: a drip sequence, an electrical sputter, a dust fall or a distant machinery cue. Stagger them; do not synchronize every object.
- Existing-state responses: city power, flooding, opened shortcuts, active shrines, alarms and boss transitions.
- Local sound: a restrained number of audible sources with distance limits, pooled playback and cooldowns. Assess repetition over several minutes, not just a screenshot.

Create a sound-and-motion schedule per region with maximum active emitters, update rates, culling rules and reduced-motion behavior. Prefer shader animation or shared clocks where appropriate. Avoid adding NPC AI, physical debris or networked destruction merely to make the background move; those are separate gameplay projects.

The world must remain alive on LOW through composition, simple motion and sound. HIGH may add richness but cannot be the only setting with atmosphere.

## 8. City neon: a first-class system with a hard ceiling

Build a city that has districts and memorable signs, not a uniform carpet of glowing rectangles. Author original businesses, service signs, route accents and occasional damaged fixtures. Use darkness as negative space. Reserve the strongest contrast for objectives and combat information.

Separate the effect into layers with independent cost:

1. **Fixture:** low-poly frame, support, wiring and readable emissive face. Share materials and atlas signage where useful.
2. **Halo:** restrained native glow if validated, or small pooled/batched soft cards. Keep transparent screen coverage bounded.
3. **Surface spill:** inexpensive tinted geometry or material treatment on suitable nearby surfaces. This is an artistic approximation, not real illumination.
4. **Darkness overlay:** the current shader cuts holes in a dark screen layer. A hole reveals the scene; it does not automatically cast colored light onto geometry.
5. **Optional real lights:** only a measured, capped hero treatment if the cheaper layers cannot achieve the target. No decorative shadow-casting light per sign.

The current overlay has capacity for 96 holes shared with gameplay lighting. Do not increase it casually or let decorative fixtures starve player, objective, hazard or combat lights. Allocate by explicit priority; cull off-screen sources and use stable selection/hysteresis to prevent popping. Treat a light count cap and transparent pixel coverage as separate budgets.

Power-state design must match city mechanics. Identify fixtures on the main grid, failed fixtures and any deliberately battery-backed signs. Derive visual state from existing power state. Blackout must look and play like a blackout; signs must not reveal enemies the normal visibility system would hide.

Use shared time plus stable phases for restrained flicker. Avoid rapid flashes, excessive pulsing and permanent full-screen bloom. Reduced motion should produce a stable, legible sign state.

Initial experiment caps, **provisional rather than measured guarantees**:

| Tier | Decorative overlay holes at once | Additional decorative real lights | Presentation |
|---|---:|---:|---|
| LOW | 0–4 | 0 | Clear emissive fixtures, minimal halos, simplified motion |
| MEDIUM | Up to 8 | 0 | Selective spill and restrained glow if it fits measured cost |
| HIGH | Up to 12 | At most 2, shadows off, only after profiling | Hero signs and richer local spill |

These are ceilings within available capacity, not reservations from gameplay lighting. Count active signs, surfaces, real lights, overlay sources and halo screen coverage separately. Tighten or replace the caps using actual measurements.

Test power on/off, restored power, panning, crowds, gunfire, fire, flood/wet surfaces and all quality tiers. Compare existing city, emissive-only city, neon with halo/spill, and any optional real-light version. Accept the cheapest convincing version.

## 9. Rendering methods and plugins: investigate before adopting

Godot's built-in rendering methods are the first candidates. A physics engine, scatter editor, material shader and renderer are different tools; do not sell them as interchangeable graphics upgrades. No plugin can substitute for art direction or eliminate its own GPU cost.

Evaluate these paths on the pinned engine:

| Candidate | Purpose | Required proof / likely decision |
|---|---|---|
| Existing Compatibility + native features | Lowest-disruption route for refined assets, instancing, restrained glow and contact shading | Prototype first; verify visual response and cost with Palisade's custom shaders and overlay |
| Mobile rendering method | An alternative rendering pipeline for a measured comparison, including on desktop | Test actual driver support, shader behavior, shadows and frame time; its name does not imply it is automatically cheaper |
| Forward+ | Optional access to more advanced lighting/post-processing | Measure one representative scene and a heavy fight; justify migration and retain a tested baseline path |
| Native fullscreen shaders / CompositorEffect | Specific post effects that solve a demonstrated need | Prefer native capability; CompositorEffect needs Mobile or Forward+, and execution/export behavior must be checked |
| ProtonScatter | Potential editor aid for prop arrangements | Compare with native recipe placement; export deterministic transforms, validate clearances and version/license; avoid a dependency where a small native system suffices |
| Terrain3D | Candidate only for a separately justified terrain-authoring need | Existing gameplay is tile-authoritative; do not replace it to solve set dressing. Verify current release requirements and native binaries before a trial |
| Jolt Physics | Physics, not rendering | Exclude from this graphical enhancement scope unless a separate physical-interaction requirement is approved |

Official 4.7 documentation currently lists glow and simplified SSAO for Compatibility. Do not repeat the older blanket claim that Compatibility cannot do bloom or ambient occlusion. Documentation support is not proof that the feature is enabled, affordable or visually correct in this project.

Investigate native glow before adding a bloom plugin. Inspect small-scale contact shading before heavy global illumination. Screen-space effects must survive the orthographic view, thin geometry, transparency, dithering and the UI layering. Lightmaps may fit fixed scenery, but runtime procedural geometry is not automatically bake-ready.

A renderer switch also means auditing color-space assumptions in `world.gdshader` and `wall.gdshader`, vertex palettes, emission, shadow response, water, see-through rules and the 2D darkness/HUD composition. A successful launch alone is not migration validation.

For each external candidate record the exact release/commit, source URL, license and bundled-asset terms, supported Godot versions, renderer/backend requirements, Windows export support, native dependencies, maintenance evidence, measurable benefit, cost and removal path. Label findings **documented**, **tested locally**, or **unverified**. “Supports Godot 4” is not evidence of tested 4.7.2 compatibility.

Run experiments in an isolated branch/project copy; do not install or enable a speculative collection of plugins in production. Produce a short adopt/defer/reject decision with evidence. Purchasing, upgrading the engine or migrating production rendering requires the owner's decision.

## 10. Performance is part of the art brief

Establish a fresh baseline before editing. Record hardware, OS/driver, engine, renderer/backend, resolution, quality, brightness, seed, camera, enemy count and build revision. The guide's historic ~68 FPS Black Out result is not a universal floor.

Use fixed scenes and repeatable live sequences. Report median, p95 and p99 frame time, CPU and GPU timing where available, render submissions, visible geometry, material changes, texture/VRAM estimate with method, node/resource counts, load time and shader-compilation stutter. Separate warm steady-state measurements from first-use hitches. Report unsupported counters as unavailable.

Provisional acceptance: keep the combined visual pass within roughly 10% of matched total frame time and view-update cost, while meeting the agreed target frame budget. At 60 FPS the whole frame has 16.67 ms; a 10% allowance is not permission to cross that limit. If the original scene is already too slow, create headroom or reduce scope before adding effects. Do not add another 10% for every workstream.

Break down cost by dressing, actors/weapons, ambient motion, neon and post-processing. Include an extreme but playable fight. Where representative LOW hardware is unavailable, report validation as incomplete; lowering resolution on an RTX 3060 is not proof of integrated-GPU performance.

Favor spatial batching, shared materials/textures, cached meshes, event-driven updates, distance-based animation and controlled transparency. Avoid a node/script/material per small prop, full-city updates every frame, map-wide batches that defeat culling, oversized textures, needless skeleton tracks and unbounded particles.

Optimization-only changes should preserve the image under a controlled capture. Art changes should demonstrate an intentional visual difference. Do not claim pixel identity for deliberately animated or revised art.

## 11. Production sequence and review gates

**Stage 0 — Audit and baseline.** Produce the full map/asset coverage sheet, current images, measured bottlenecks, guide corrections and ranked opportunities. Read source before proposing a replacement system. Identify one owner for shared integration files.

**Stage 1 — Visual target and technical samples.** Create a palette/material sheet, silhouettes and one city composition target. Mark concept art as a target, never as a game capture. Prototype Compatibility glow/contact shading and the neon layers in an isolated scene. Define the asset and placement contracts.

**Stage 2 — First playable slice.** Deliver one representative city block with a POI approach, clutter clusters, original neon, a power transition, subtle ambient motion and sound; integrate one refined player, one common enemy and one weapon. Show daytime/night or the supported equivalent, LOW/HIGH, normal combat and a heavy crowd. Include an on/off comparison of the new systems.

**Stage 3 — Understrip proof.** Dress one Flood Tunnels room, its corridor and a shrine/merchant corner; then one Shelter 7 and one Area 67 sample. Verify wall lowering, repeated room reuse, narrow-route clearance and reduced motion. Review before multiplying the kit across ten levels.

**Stage 4 — All-map production.** Extend approved kit families to every inventory entry. Cover both sizes and PvP variants. Add one distinctive landmark per map/level and finish prioritized player/gun/enemy revisions. Update the coverage sheet as each item is completed.

**Stage 5 — Cohesion and release candidate.** Normalize material response, color hierarchy, wear, motion and sound. Run gameplay/parity checks, repeated map transitions, save isolation, native shutdown and exported-build checks. Deliver the final performance ledger and known limitations.

Each gate presents concrete captures and measurements for Big U's review. Continue research and reversible preparation while awaiting an art decision; do not treat an unanswered review as approval to roll out a new visual direction everywhere.

## 12. Specialist assignments

| Workstream | Owns | Required handoff |
|---|---|---|
| Art direction / world design | Map identity, composition, landmarks, density and readable play space | Map coverage sheet, visual targets, approved palettes and exclusions |
| Environment modeling | Modular props and hero landmarks | Editable sources, transforms/footprints, shared materials, asset manifest and gameplay-scale previews |
| Character / weapon art | Player, enemy, boss and gun refinement | Rig/socket/animation compatibility evidence and before/after in-game comparisons |
| Technical art / dressing | Recipes, placement, batching, culling and wall attachment | Deterministic placements, diagnostics, lifecycle behavior and renderer integration |
| Rendering engineering | Neon, lighting/post-processing investigation and profiling | Feature matrix, reproducible timings, quality fallbacks and adoption decision |
| Integration / QA | Cross-client rules, regression checks, export and review package | Verified build, clear status per map, performance ledger and remaining risks |

Agents must agree on IDs, transforms, materials and ownership before parallel edits. Do not let several agents independently redesign `main.gd`, `v3_scenery.gd`, `us_view3d.gd` or the art sync pipeline.

## 13. Deliverables and definition of done

Deliver a reviewable production package, not only a mood board or list of plugins:

1. An audit with verified current facts and ranked improvements.
2. A coverage matrix for every playable environment and asset family.
3. A style guide and first-slice target with clear scale, color and readability rules.
4. Working prototypes, deterministic dressing recipes and the asset manifest.
5. Before/after matched gameplay captures; short motion/power-state clips; model turntables plus in-game views.
6. Performance results per tier with hardware/settings and reproduction instructions.
7. Rendering/plugin research with exact sources, tested status and a recommended choice.
8. Gameplay and generator checks appropriate to changed files; equipment/animation checks for changed models; scene cleanup and export checks.
9. An updated environment guide describing implemented systems and correcting outdated assumptions.
10. A handoff separating implemented, reviewed, measured, deferred and blocked items.

Completion means the maps have distinct purpose and restrained activity, players and enemies remain immediately readable, weapons look convincing in use, city neon fits the measured frame budget, repeated transitions do not grow resources, and the exported game behaves correctly. A beautiful still image cannot hide a slower, noisier or less readable game.

**First instruction to the receiving agent:** Read the environment guide and current source. Return a brief verified audit, an all-map coverage matrix and a ranked first-slice plan. Then carry out the authorized local baseline and prototype work. Recommend the smallest coherent change that makes the game visibly feel alive, prove it in motion and under load, and expand only after that direction is reviewed.

## Research references checked November 12, 2026

These informed the investigation scope. No renderer migration, plugin installation or plugin compatibility test was performed while writing this prompt.

- Godot 4.7 renderer feature matrix: https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html
- Godot 4.7 environment/post-processing behavior, including Compatibility glow and simplified SSAO: https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html
- Godot compositor documentation (rolling stable page; verify against pinned engine): https://docs.godotengine.org/en/stable/tutorials/rendering/compositor.html
- ProtonScatter upstream mirror, which points to its active Codeberg repository: https://github.com/HungryProton/scatter
- Terrain3D upstream: https://github.com/TokisanGames/Terrain3D
- Jolt upstream explanation of its physics role and built-in integration: https://github.com/godot-jolt/godot-jolt/blob/master/README.md

The existence of these projects is not an endorsement or evidence of successful use in Palisade. Keep exact version checks and local measurements in the resulting implementation report.
