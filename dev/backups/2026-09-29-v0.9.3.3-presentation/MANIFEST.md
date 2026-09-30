# Presentation baseline backup — v0.9.3.3

Captured September 29, 2026 **before source edits**, from `2268c3560019175107a468c9db0500f820568d12` (GitHub `main`, verified before implementation). These are development files, excluded from the build's asset list and service-worker cache. They are not secrets or player saves.

## Contents and dependencies

- `18b-backgrounds.js`: all 25 scenic definitions, 32 procedural flags, drawing helpers and old cache/lobby integration.
- `18-cosmetics.js`: original catalogue, colour metadata, IDs, rarities and cosmetic dependencies. Keep progression/equip data independent of art rollback.
- `16-characters.js` and `19b-social-lobby.js`: original character painter, weapon table, worker/cache setup and lobby preview.
- `source-hashes.json`: SHA-256 of these exact copies. `before-inventory.json`: all 57 IDs, names, rarities, source and static/animated state.
- `before-scenic-*.png`, `before-flags-*.png`: full catalogue contact sheets at desktop, phone portrait and phone landscape canvas sizes, all at t=4 seconds.
- `before-animation.webm` and `.png`: eight-second controlled four-class pose sequence (idle, walk, sprint, backpedal, strafe/turn, stop, fire and bolt/pump). These are renderer fixtures, not physical-device gameplay recordings.
- `before-perf.json`: exploratory timing only; use the corrected same-browser comparison in `../../evidence/v0.9.3.4/performance-comparison.json` for reporting.

The scenery is generated entirely in Canvas; there are **no raster scene assets to recover**. Original functions use shared `hash`, `vgrad`, `bgLayer`, `bgTrees`, `bgFence`, `bgBlob`, `bgRound`, `star5`, and `drawFlag`; catalogue registration relies on `FLAGS`, `CASES`, `COS`, `COSBY`, `CATN` and locker normalization. The build bundles the IBM Plex Mono font used by Dog Tags and Arcade. Geometry requires no network fetch.

## Restore one scenic background without reverting flags or animation

1. Locate its ID below in current `dev/src/js/18c-background-depth.js`.
2. Remove **only that ID's property** from `BG_REFINEMENTS` (for example `campfire:['terrain',…]`). Leave neighbouring properties and commas valid. The base scene functions in current `18b-backgrounds.js` are unchanged from this backup. The integrated cache hook also checks `BG_REFINEMENTS`, so removing the property disables both finishing paths. Arcade needs no change because it was deliberately retained.
3. Rebuild with `python dev/build.py` (Python + Pillow). Reload the page to clear the old in-memory art cache. Run `presentation` and `flagcase` from the targeted runner, then compare that scene to its `before-scenic` capture at the same size and t=4.
4. This restores the original scene art while retaining the new cache limits, full-screen flags, current cosmetic ownership and character animation. Do not replace the entire old source file to undo a single scene.

The unchanged scenic definition block was compared byte-for-byte after newline normalization against the backup. All four source hashes were checked. A representative Campfire rollback was also rendered from a development fixture and compared pixel-for-pixel with the baseline at DPR 1.

## Restore the whole original presentation in a separate review checkout

Recover commit `2268c3560019175107a468c9db0500f820568d12`, then copy these four `.js` files back to their identically named `dev/src/js/` paths. Verify hashes and build. This is the clean reproduction path for original renderer dependencies and debug hooks. Do not copy old complete files over future production work blindly; the current renderer factory, debug exports, idle motion and layered scenery are coupled changes. For a current-branch art rollback, disable individual finishing IDs as above.

## Scenic inventory

| ID | Name | Source | Baseline motion |
|---|---|---|---|
| `campfire` | Campfire Dusk | free | Animated |
| `nightwatch` | Night Watch | free | Animated |
| `dawn` | First Light | unlock | Animated |
| `aurora` | Aurora | unlock | Animated |
| `emberfield` | Ember Field | unlock | Animated |
| `crimson` | Crimson Smoke | unlock | Animated |
| `neongrid` | Neon Grid | unlock | Animated |
| `goldrush` | Gold Rush | unlock | Animated |
| `harvestmoon` | Harvest Moon | case | Static |
| `hauntedfog` | Haunted Fog | case | Static |
| `fieldmap` | Field Map | case | Static |
| `sandbags` | Sandbag Line | case | Static |
| `dogtags` | Dog Tags | case | Static |
| `watchtower` | Watchtower | case | Static |
| `searchlight` | Searchlight | case | Animated |
| `sunsetfade` | Sunset Fade | case | Static |
| `lagoonwaves` | Lagoon | case | Static |
| `nebula` | Nebula | case | Static |
| `arcade` | Arcade | case | Static |
| `neonpulse` | Neon Pulse | case | Animated |
| `eventhorizon` | Event Horizon | case | Animated |
| `goldaurora` | Gold Aurora | case | Animated |
| `graveyard` | Graveyard | case | Static |
| `witchbrew` | Witch's Brew | case | Static |
| `bloodmoon` | Blood Moon | case | Animated |
