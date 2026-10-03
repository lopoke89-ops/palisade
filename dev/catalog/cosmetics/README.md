# PALISADE cosmetic catalog

Version v0.9.6.1, protocol yard-22. 368 entries; {"skin":118,"hat":51,"trail":75,"fx":47,"bg":77}. Generated from final runtime registries and reconciled against the verified live server catalog. Inventory entries and renderer-only/default entries are identified in [catalog.json](catalog.json). Build SHA256: `584de238579616c4c1d948051cb463569e3025c1d0d481b78b4aaedab678bd1b`.

Regenerate: rebuild with the bundled Python and `dev/build.py`, then `node dev/catalog/capture-cosmetics.js`. Chrome path can be overridden with CHROMIUM.

Character yaw 0 faces the viewer; +90° turns toward screen right, 180° shows the back, 270° turns left. These are model-space headings, applied after the isometric world-to-screen aim projection. Tracer headings point screen up/right/down/left. Each flag panel uses the next stored palette color where available. Every directional item has exactly four panels. Animated backgrounds and kill effects use four time samples; static backgrounds are repeated to document their invariance. Headgear uses the standard Soldier as the fit reference; skin entries include all headwear compatibility flags. Gold skin auras use their gameplay painter around the feet.

## Contact sheets

- [skin-supply-1.png](skin-supply-1.png)
- [hat-halloween-1.png](hat-halloween-1.png)
- [hat-halloween-2.png](hat-halloween-2.png)
- [skin-base-1.png](skin-base-1.png)
- [skin-base-2.png](skin-base-2.png)
- [skin-base-3.png](skin-base-3.png)
- [skin-base-4.png](skin-base-4.png)
- [skin-base-5.png](skin-base-5.png)
- [skin-base-6.png](skin-base-6.png)
- [hat-base-1.png](hat-base-1.png)
- [hat-supply-1.png](hat-supply-1.png)
- [trail-base-1.png](trail-base-1.png)
- [trail-supply-1.png](trail-supply-1.png)
- [fx-base-1.png](fx-base-1.png)
- [fx-supply-1.png](fx-supply-1.png)
- [skin-afterglow-1.png](skin-afterglow-1.png)
- [skin-afterglow-2.png](skin-afterglow-2.png)
- [hat-afterglow-1.png](hat-afterglow-1.png)
- [hat-afterglow-2.png](hat-afterglow-2.png)
- [trail-afterglow-1.png](trail-afterglow-1.png)
- [trail-afterglow-2.png](trail-afterglow-2.png)
- [fx-afterglow-1.png](fx-afterglow-1.png)
- [fx-afterglow-2.png](fx-afterglow-2.png)
- [skin-halloween-1.png](skin-halloween-1.png)
- [skin-halloween-2.png](skin-halloween-2.png)
- [trail-halloween-1.png](trail-halloween-1.png)
- [fx-halloween-1.png](fx-halloween-1.png)
- [trail-blitz-1.png](trail-blitz-1.png)
- [fx-blitz-1.png](fx-blitz-1.png)
- [trail-flags-1.png](trail-flags-1.png)
- [trail-flags-2.png](trail-flags-2.png)
- [trail-flags-3.png](trail-flags-3.png)
- [trail-flags-4.png](trail-flags-4.png)
- [skin-winter-1.png](skin-winter-1.png)
- [skin-winter-2.png](skin-winter-2.png)
- [hat-winter-1.png](hat-winter-1.png)
- [hat-winter-2.png](hat-winter-2.png)
- [trail-winter-1.png](trail-winter-1.png)
- [fx-winter-1.png](fx-winter-1.png)
- [skin-hybrid-1.png](skin-hybrid-1.png)
- [skin-hybrid-2.png](skin-hybrid-2.png)
- [skin-hybrid-3.png](skin-hybrid-3.png)
- [skin-hybrid-4.png](skin-hybrid-4.png)
- [hat-hybrid-1.png](hat-hybrid-1.png)
- [fx-hybrid-1.png](fx-hybrid-1.png)
- [fx-hybrid-2.png](fx-hybrid-2.png)
- [bg-base-1.png](bg-base-1.png)
- [bg-halloween-1.png](bg-halloween-1.png)
- [bg-supply-1.png](bg-supply-1.png)
- [bg-afterglow-1.png](bg-afterglow-1.png)
- [bg-blitz-1.png](bg-blitz-1.png)
- [bg-flags-1.png](bg-flags-1.png)
- [bg-flags-2.png](bg-flags-2.png)
- [bg-flags-3.png](bg-flags-3.png)
- [bg-flags-4.png](bg-flags-4.png)
- [bg-winter-1.png](bg-winter-1.png)
- [bg-winter-2.png](bg-winter-2.png)
- [bg-hybrid-1.png](bg-hybrid-1.png)

## Audit findings

Each entry has four pixel visibility/boundary checks, palette, acquisition, renderer source, motion policy, cache policy, and a finding in JSON. Boundary flags are capture diagnostics rather than proven game clipping. Backgrounds intentionally fill their panels. Older kill effects use captured emitter fields and the same particle painter as combat. These captures are an art index, not substitutes for collision or networking tests.

No blank or boundary diagnostics on directional artwork.
