# THE UNDERSTRIP — environmental dressing plan

Status: proposed scope for review, November 5, 2026. Covers all ten levels in browser and Godot.
The director approved the v0.12.5 encounter preview and requested believable set dressing across the mode.
This document is a plan; it does not authorize a commit, push or release.

## Direction

Make the descent feel like a place that existed before the squad arrived. Keep the low-poly silhouettes and
the game's readable isometric camera. Believability comes from purpose, construction, wear and human activity.

Every dressed room should answer three questions:

1. What was this room used for?
2. How did people work, move or live here?
3. What happened before the player arrived?

Use three layers: building systems (drains, pipe routes, door frames, cable trays), room equipment
(pumps, bunks, counting tables, lab benches), then evidence of use (wear, repairs, abandoned work, a few personal items).
Equipment should have plausible connections: pipes enter walls, cables reach panels, wet areas drain downhill visually,
and storage clusters beside actual work areas. Give the eye quiet floor space between clusters.

## Region identities

### Flood Tunnels — the casino's dirty underside

Wet concrete, rusted service equipment, warm maintenance lights and fragments of casino colour. Establish a working
stormwater system that casino staff have also used for storage and dumping. Waterlines and silt collect consistently;
repairs, mismatched pipes and improvised walkways show repeated flooding.

Asset families: pipe straights/elbows/valves/brackets, drain grates and outfalls, pump assemblies, electrical boxes,
maintenance barriers, pallets, storage crates, discarded slot cabinets and sign fragments. Detail with a restrained
set of stain/crack/silt overlays, service numbers and original casino markings.

Story clusters: a repair abandoned during a flood; casino equipment dumped beside a service door; an improvised
maintenance break area with a thermos and work light; a stack of sandbags that failed on one side.

Ambience: directional drips, pump vibration, occasional pipe knocks and casino sound bleeding through selected vents.
Place each sound where the player can identify its source.

### Shelter 7 — a place people tried to keep running

Painted steel, worn institutional floors, olive equipment, orange utility labels and tired fluorescent fixtures.
Show an organized civil-defence shelter that slowly became a sealed maintenance problem. Establish living quarters,
food/water storage, medical provision and power/air systems through repeated equipment and signage.

Asset families: bunk and locker modules, ration shelves, mess furniture, first-aid stations, generators and switchgear,
ventilation ducts, filter housings, wall phones, notice boards, maintenance carts and cleaning equipment.

Story clusters: a half-cleared meal; numbered beds and improvised privacy; a ration queue with empty shelves;
a repeatedly repaired generator; an office still trying to enforce routines as the shelter fails.

Ambience: fluorescent hum, ventilation, relay clicks and the heavy sound of distant doors. Red emergency fixtures
support the existing boss/hazard changes while preserving warning colours.

### Area 67 — organized research becoming incomprehensible

Cold lab finishes, controlled cable routes, specimen infrastructure and increasingly invasive alien material.
Begin with an operational-looking facility and progressively show containment failures. Keep human construction
consistent so the alien changes stand out.

Asset families: lab bench and instrument modules, specimen storage, observation glass, decontamination frames,
monitor housings, equipment carts, containment braces, cable trunks, loading equipment, broken tank variants
and a small family of alien growth meshes.

Story clusters: an experiment interrupted mid-procedure; a station stripped to keep another alive; a specimen moved
in a hurry; alien growth following warmth or power cables; instruments still focused on an empty enclosure.

Ambience: localized ventilation, instrument pulses and failing relays. The alien hum grows more apparent deeper down.
Reserve strong emissive accents and movement for a few landmarks, existing hazards and active machinery.

## All ten levels

These are dressing themes inside the existing level names and room layouts, rather than replacement layouts.

| Level | Existing location | Proposed identity and memorable feature |
|---|---|---|
| 1 | Flood Tunnels 1 | Casino storm drains and staff access. One large outfall, service signage and a credible drainage route introduce the region. |
| 2 | Flood Tunnels 2 | Pumping, overflow and abandoned maintenance. A damaged pump station and a failed sandbag line show stronger flood damage. |
| 3 | The Count Room | Casino cash handling and security. Counting cages, trays, bag storage and a shuttered service counter frame the Pit Boss arena. |
| 4 | Shelter 7 1 | Shelter intake and everyday survival. Check-in desk, numbered bunks, lockers and ration storage establish the former population. |
| 5 | Shelter 7 2 | Power, air, medical and maintenance functions. A distinctive generator/filter installation connects otherwise separate rooms. |
| 6 | The Main Hall | Shelter control and institutional order. Blast-door frames, a central status board and cleaning/service equipment support the Custodian's identity. |
| 7 | Area 67 1 | Receiving, decontamination and early research. Clean-looking workstations with localized failures introduce the facility. |
| 8 | Area 67 2 | Containment failure. Broken equipment and increasingly connected growth show what escaped and where people retreated. |
| 9 | The Loading Bay | Heavy logistics and security. Freight markings, perimeter cargo racks, lifting equipment and suit-service infrastructure frame the Gatekeeper. |
| 10 | The Containment Hall | The facility's central experiment. A restrained containment structure, observation stations and power routes focus attention on the Visitor. |

Boss dressing sits around the perimeter and in background space. The playable arena remains legible through both
stages, including the Gatekeeper's two bodies and the Visitor's summoned support.

## Room recipes and placement

Use authored arrangements matched to existing room roles. Corridor recipes emphasize service routes and wear;
junctions get readable direction cues; storage/work rooms get equipment clusters; breather and merchant rooms have
clear functional stations; boss antechambers foreshadow the arena. Shrines, merchants, pickups and lifts retain a
consistent recognizable silhouette.

Plan 3–4 arrangement variants for each important room family, reusing the same modular assets. Select compatible
variants with an isolated dressing seed derived from run seed, level, room identity and placement slot. Browser and
Godot receive the same arrangement IDs and positions. Dressing randomness must not consume combat or loot RNG.

Each room recipe identifies wall strips, corners, an optional focal point, interaction clearances, combat lanes and
camera-sensitive areas. Add clearance around entrances, gates, switches, stairs, shrines, merchants, loot and lifts.
Decorative props use visual-only placement. A large prop intended to block movement must replace an existing solid
cell and match its collision/shot contract in both clients. Any new cover or collision needs a separate gameplay decision.

Overhead systems and tall foreground equipment fade or cut away when they obscure a player. Small objects should
be grouped into readable clusters at the real gameplay camera distance. Decorative objects must be distinguishable
from interactable loot and from hazard telegraphs.

## Asset scope

Initial estimate: 30–40 reusable modular prop assets across the three regions, plus one landmark assembly per region
and distinct perimeter arrangements for the four boss arenas. Assemble variety through combinations, palette and
condition variants before adding more unique meshes. Final count follows the sample-room review and inventory.

Reuse and improve existing lamps, shrines, merchant stations, lift components and specimen tanks. The current model
catalog is primarily characters/cosmetics/weapons, so ordinary environment props need a deliberate new library kit.

Use a small shared material palette: concrete, painted metal, bare metal, rubber, wood and glass, with controlled
region colour accents. Give props a clear construction and modest edge detail; keep surface noise and tiny parts
subordinate to silhouette. Condition variants should show consistent water damage, repeated handling and repairs.

Author reusable Godot assets through the established model-library workflow after visual approval. Give browser
renderers equivalent silhouettes, dressing positions, condition variants and functional cues. Keep shared placement
data independent from renderer-specific geometry.

## Lighting, sound and motion

Every local light has a visible fixture. Use warm/cold contrast to guide attention through each region. Keep the
existing visibility/accessibility controls effective, and check enemies, loot and warnings under every supported
brightness setting. Compare dressed and undressed rooms at the same settings.

Limit moving details to a few readable sources per visible area: a fan, a drip, a loose cable, a monitor or slow alien
motion. Use pooled positional ambience and existing audio settings. New ambience must leave room for enemy cues.
Start with baked colour/emissive fixtures and a bounded number of active lights; benchmark before adding shadows.

## Work phases and review gates

1. **Baseline and art brief.** Inventory reusable props and room families. Capture fixed-seed views and performance
   measurements. Agree on a mood sheet for each region and the reusable material palette. Keep crash diagnosis and
   native shutdown verification explicit before another large batch of Godot captures.
2. **One complete Flood Tunnels sample.** Dress a normal room, its adjoining corridor and a merchant/shrine corner.
   Include construction, equipment, wear, lighting and localized ambience. Review at the gameplay camera in both
   clients. Get visual sign-off before producing the full kit.
3. **Region samples.** Complete one Shelter 7 room and one Area 67 room with their own character, then review them
   beside the approved tunnel sample. Establish how damage and alien intrusion progress within each region.
4. **Full descent.** Build the remaining reusable kit and room recipes; apply them across levels 1–10. Give every
   level its stated landmark and finish the four arenas and antechambers.
5. **Cohesion and validation.** Check transitions between regions, repeated rooms, all merchant types and rest areas.
   Review fixed-seed contact sheets and play the entire descent in solo and co-op. Measure performance and address
   hotspots before packaging a review build.

## Acceptance

- A player can infer each room's purpose from the gameplay camera. Each level has a memorable local feature and
  each region has a recognizable material, lighting and equipment identity.
- Pipes, cables, storage and machinery form plausible arrangements. Wear and story clusters follow the room's use.
- Doorways, routes, interactions, enemy silhouettes, floor loot and boss telegraphs remain readable and reachable.
- Shared seeds yield matching dressing placement and the same navigation/collision in browser and Godot. Existing
  generator, combat and loot results remain unchanged by cosmetic dressing.
- Reused library assets remain byte-identical unless deliberately revised; changes have an asset/hash manifest.
- Benchmark the same views and gameplay in both clients. Initial performance target: keep added frame time within
  roughly 10% of the measured baseline on the agreed test machine; tune the budget after the first sample.
- Validate repeated level changes and scene disposal. No growing prop/node counts or leaked dressing viewports.
- Deliver region contact sheets and a representative co-op build for visual and gameplay sign-off. Commit, push
  and release only on the director's instruction.

## Recommended first decision

Use **grounded industrial decay with a gradual turn toward alien intrusion** as the direction. Start with a dressed
Flood Tunnels room and casino service corridor; use that small slice to settle density, materials and wear before
building the remaining two regional kits.
