# v0.9.8.3 work order: FROSTPEAK CLIFFS AND STAIRS

| | |
|---|---|
| **Status** | Plan. Written October 4 from Big U's bug report. Big U confirmed the dark triangle on the right of each connector is intended (a shadow); only the left side is wrong. Decided by Big U (D1 handrails yes, D2 cliff texture yes) and built as v0.9.8.3 |
| **Build** | v0.9.8.3, client only. No server or protocol change: collision and heights stay exactly as they are; this is drawing only |
| **Scope** | Frostpeak (the winter map, also the summit of Operation Whiteout), standard 16×16 and XL 24×24 |
| **Risk** | Low. Rendering only, behind `MAP===MAPS.frost` |

## Ticket

| ID | Title | Severity | Area |
|---|---|---|---|
| PAL-0983-1 | The cliff wall on the left of each staircase and ramp clips into the steps | Medium: the winter map's main landmark looks broken | Rendering / Frostpeak |

## PAL-0983-1: Cliffs clip into the stairs and ramps

**Reported (Big U):** the winter map looks ugly: the cliffs clip into the stairs.

**Repro:**
1. Start a raid on Frostpeak (any size) and walk to any of the 4 connectors.
   - a ramp and a staircase go from the bottom terrace to the middle one;
   - a ramp and a staircase go from the middle terrace to the summit.
2. Look at the left side of the connector, where it meets the upper terrace. Screenshots: `dev/evidence/v0.9.8.3/before-stairs.png` and `before-ramp.png` (top left of the steps).

**Actual:** the upper terrace's cliff wall, just left of the connector, sticks out over the connector's top-left corner. It covers the top steps with a dark slab, at every connector and both map sizes.

**Not a bug (Big U):** the dark triangle on the right side of each connector is intended; it's the shadow. It stays as it is.

**Expected:** the stairs and ramps sit cleanly in the cliff, the way stone steps cut into a terrace would. The cliff wall stops at the edge of the steps; nothing is drawn over them.

**Root cause (`dev/src/js/06d-elevation.js`):**
- Stairs and ramps (`connectors`) are painted by `paintFrostTile` into the cached ground layer, which is drawn first.
- Cliff faces are drawn later by `itemFrostCliff`, in the depth-sorted world pass with the players, so that a cliff lip can hide someone standing behind it.
- The south cliff face of the upper-terrace tile directly left of each lane covers part of the connector on screen. Because cliffs are always drawn after the ground, that face lands on top of the steps, even though the steps are in front of it.

**Fix spec:**
- **Keep cliff faces off the connectors.** When a cliff face is drawn, clip away the on-screen outline of any connector tile in front of it, so the face only paints where it really shows. The cliff then ends cleanly at the edge of the steps.
- **Unchanged:**
  - players and raiders standing behind a cliff lip are still hidden by it, exactly as now;
  - players on the stairs are never covered by a cliff;
  - the right-side shadow triangle, the steps, treads, colours and the orange route flags.
- **Performance:** the clipping applies only to the few cliff faces next to a connector (4 on the map), so there is no cost per frame worth measuring.

**Acceptance criteria:**
- [ ] On Frostpeak standard and XL, for all 4 connectors, no cliff-face pixel lands inside a connector's on-screen outline. Checked by a pixel test that draws the cliffs in a marker colour.
- [ ] The right-side shadow triangle looks exactly as before (pixel-identical to the current build).
- [ ] A player walking up and down every connector is never drawn under a cliff face. A player standing just behind a cliff lip is still partly hidden, as now.
- [ ] Heights, collision and pathing are byte-for-byte unchanged (`winter_elevation` passes untouched).
- [ ] Screenshots before and after of a staircase and a ramp, at desktop and on phones, go in `dev/evidence/v0.9.8.3/`.

**Tests (only what this touches):**
- New `frost_connectors`: the pixel checks above, at both sizes.
- Re-run `winter_elevation`, `winter_combat` and `campaign_map_evac`, since they play on Frostpeak.

## Release plan

1. The clip fix (and D1/D2 if chosen).
2. The new test plus the three Frostpeak tests. No full suite.
3. Before and after screenshots, then PR and merge.

## Decisions (Big U, October 4): D1 **yes**, D2 **yes**

### As asked

| # | Question | Proposal |
|---|---|---|
| D1 | Add handrails along the stairs and ramps? The sides already block movement but look open | Optional; say yes if you want them |
| D2 | While we're in there: give the flat slate cliff faces a little texture (a few snow ledges and cracks, drawn once into the cached layer)? | Optional |
