# PALISADE v0.9.3.4 — presentation implementation and validation

**Implemented locally September 29, 2026. Uncommitted and unpublished.** Baseline: `2268c3560019175107a468c9db0500f820568d12`, v0.9.3.3. GitHub `main` matched that commit before implementation, and the live GitHub Pages footer still displayed v0.9.3.3 at the end of this work. Big U handles publication. This report records the executed [presentation prompt](plans/backgrounds-and-character-animation-prompt.md).

## What changed

All **32 Flag Case backgrounds fill the canvas**, including phone portrait and landscape. Stripe fields and diagonals adapt to the viewport; circular emblems, stars and central symbols use a uniform scale rather than stretching with the screen. Existing stylized designs, colours, IDs, rarities and ownership remain intact. Poles and separate skies are gone. Common/Rare/Epic remain static; Legendary/Gold use a restrained moving cloth-light treatment. The underlying field never moves away from the screen edge. Reduced motion freezes that treatment. Locker thumbnails use the same renderer.

**24 of the 25 scenic backgrounds received cached finishing layers.** The original scenic definitions are preserved, so each finishing layer can be disabled independently. Arcade deliberately retains its crisp pixel-art composition. The existing Canvas approach supports this pass without image downloads, decoding or missing-asset fallback. Animated scenes bake details into their existing layers wherever possible; static scenes bake their finish into the still image.

**Character animation follows actual displacement.** Each step has a planted interval and a lifted recovery, with two-bone knee positioning and restrained torso movement. Gait direction follows movement relative to aim, so strafing and backpedalling differ from forward walking. Stopping blends to a neutral stance; holding movement against an obstacle does not keep the feet marching. Small residual remote interpolation fades the gait instead of repeatedly starting a full step. Gold greaves/cuffs, skeleton markings, mummy wraps and straw attachments follow the articulated legs. Lobby/Locker breathing is subtle; reduced motion disables breathing, preview turning, outfit ticking and the Locker tracer demonstration.

Weapon grip, recoil and muzzle calculations still share the same painter. Combat, movement speed, collision, host enforcement, save keys, catalogue ownership, protocol and reward calculations were not changed. **No Supabase migration or configuration change is required.** Deferred reward retry/rejoin, import/identity, security-event persistence and new-mode work remain deferred.

Validation also exposed a **pre-existing minification problem in renderer workers**: stringifying individual functions lost the renamed dependencies they referenced, causing fallback to synchronous painting. The renderer now serializes a complete, self-contained factory. Both the minified debug build and shipped production build completed worker jobs without failure.

## Art inventory and rollback

The [dated backup manifest](backups/2026-09-29-v0.9.3.3-presentation/MANIFEST.md) contains original sources, SHA-256 hashes, the full ID/name inventory, before captures and exact restore steps. The four source copies match baseline Git contents after newline normalization. Scenic base definitions remain unchanged. Removing one entry from `BG_REFINEMENTS` restores that scene's old art without undoing flags, animation or ownership. A development fixture verified the Campfire rollback pixel-for-pixel at 390×844, DPR 1, t=4; see [restore evidence](evidence/v0.9.3.4/restore-check.json).

| Scenes | Treatment |
|---|---|
| Campfire Dusk, First Light | Warm layered ground, receding path/reflections, edge stones and ground light |
| Night Watch | Cool layered ground, reflective path, crescent moon and restrained halo |
| Aurora, Watchtower, Searchlight | Cool terrain planes and edge detail; existing lights and silhouettes retained |
| Ember Field | Scorched terrain and warmer near-ground light beneath the existing embers |
| Harvest Moon, Haunted Fog, Blood Moon | Layered dark ground, selective fog/path detail, preserved moon/house/bats |
| Graveyard, Witch's Brew | Low foreground terrain and material detail, retaining gravestones and cauldron |
| Sunset Fade | Additional near terrain and a receding reflective plane beneath the existing sunset |
| Lagoon | Wave-crest highlights and broken reflections following the original bands |
| Field Map | Paper fold shading, grain and a compass rose |
| Sandbag Line | Woven/seam highlights, contact shading and foreground falloff |
| Dog Tags | Restrained diagonal metal lighting and surface wear |
| Crimson Smoke | Cached secondary smoke volume and dark pockets |
| Nebula | More varied stellar depth and a dark dust lane |
| Event Horizon | Diffuse outer accretion glow while keeping the black centre clear |
| Neon Grid, Neon Pulse | Distant silhouettes/horizon light and city reflections respectively |
| Gold Rush, Gold Aurora | Edge crystal facets; stars and low terrain respectively |
| Arcade | Retained: its flat, legible pixel-art composition works better than added scenic depth |

## Review evidence

The [review page](evidence/v0.9.3.4/review.html) places the before/after animation clips and matched desktop scenic sheets together. The clips are **controlled renderer fixtures**, not recordings of physical-phone gameplay: four weapon classes cycle through idle, walk, sprint, backpedal, strafe/turn, stopping, recoil and bolt/pump actions. Current real local host/guest gameplay is additionally documented in screenshots and the network check.

| Evidence | Before | After |
|---|---|---|
| Scenery, desktop | [1280×800 catalogue](backups/2026-09-29-v0.9.3.3-presentation/before-scenic-1280x800.png) | [1280×800 catalogue](evidence/v0.9.3.4/after-scenic-1280x800.png) |
| Scenery, portrait phone | [390×844 catalogue](backups/2026-09-29-v0.9.3.3-presentation/before-scenic-390x844.png) | [390×844 catalogue](evidence/v0.9.3.4/after-scenic-390x844.png) |
| Flags, portrait phone | [390×844 catalogue](backups/2026-09-29-v0.9.3.3-presentation/before-flags-390x844.png) | [390×844 catalogue](evidence/v0.9.3.4/after-flags-390x844.png) |
| Flags, landscape phone | [844×390 catalogue](backups/2026-09-29-v0.9.3.3-presentation/before-flags-844x390.png) | [844×390 catalogue](evidence/v0.9.3.4/after-flags-844x390.png) |
| Animation | [8-second WebM](backups/2026-09-29-v0.9.3.3-presentation/before-animation.webm) · [contact sheet](backups/2026-09-29-v0.9.3.3-presentation/before-animation.png) | [8-second WebM](evidence/v0.9.3.4/after-animation.webm) · [contact sheet](evidence/v0.9.3.4/after-animation.png) |

Also inspected: [phone Locker](evidence/v0.9.3.4/locker-phone.png), [desktop Locker](evidence/v0.9.3.4/locker-desktop.png), [54 attachment/downed poses](evidence/v0.9.3.4/pose-fit.png), [host gameplay](evidence/v0.9.3.4/game-host.png), and [phone-sized guest gameplay](evidence/v0.9.3.4/game-guest.png). Full sets of the three catalogue aspect ratios are saved alongside these files.

## Focused validation

The normal Python/Pillow/Terser build succeeded. Nine relevant checks passed; the full suite was not run:

| Check | Result |
|---|---|
| `presentation` | All 32 flags at 390×844, 844×390, 1280×800 and 768×1024 have opaque edges. Static/animated rarity rules, reduced motion, circular portrait Japan emblem and visible France side bands pass. Displacement, stopping, wall-input, backpedal, strafe, downed and simulated remote cadence checks pass. |
| `presentation_posefit` | 54 rendered samples cover skeleton/mummy/straw attachments, robes/capes, pumpkin, Gold Clown/Police/Knight, strafe and actual gun-hidden downed poses. No empty or edge-clipped samples. Contact sheet inspected. |
| `flagcase` | Existing catalogue, rarity odds, drops, duplicate conversion, purchase and equip checks pass. The obsolete “flag versus surrounding sky” check was replaced with full-field coverage/design checks. |
| `wardrobe3d` | All 98 skin/headgear items render distinctly without fallback. |
| `locker_fit` | Galaxy, Storm and Demolisher effects fit the stage and thumbnails at phone/desktop viewport sizes. |
| `muzzle` | 1,440 class/heading checks pass, including 1,020 moving and 420 settled poses. Maximum tracer-tail error approximately 2.28×10⁻¹³ pixels; maximum barrel/aim angular error 1.48°. Projectile physics and guest event replay remain intact. |
| `presentation_network` | Honest host and guest each moved approximately 1.98 world units, saw walking, and observed the other settle to gait weight 0. Production minified renderer completed 56 worker jobs with 0 failures. |
| `cosmetic_network` | Existing local host/phone-sized guest cosmetic transport and effect replay pass. |
| `csp` | Production/debug pages load their scripts, local PeerJS and renderer without CSP violations or page errors. |

Capture, corrected A/B performance and individual-restore utilities also completed. Selected logs and JSON results are retained under `evidence/v0.9.3.4/`. `run_targeted.ps1 -Group presentation` (or `run_targeted.sh presentation`) selects these nine checks; the explicit full suite now lists 35 regression tests. Capture/performance/restore utilities remain opt-in. Windows failure handling now writes native assertion errors to the selected test's log and continues the selection instead of aborting before saving the failure.

## Performance and footprint

The [corrected A/B benchmark](evidence/v0.9.3.4/performance-comparison.json) used one desktop Chrome session, an emulated 390×844 DPR-2 touch context, fresh software-backed canvases, 20 warmups and 140 timed draw/readback iterations per scene/size. **These are renderer microbenchmarks, not phone frame times or end-to-end FPS.** Earlier `before-perf.json` / `after-perf.json` captures used implicit readback strategies and are exploratory only; do not compare those as the final result.

| Scene / canvas | Before median / p95, ms | After median / p95, ms |
|---|---:|---:|
| Campfire, 390×844 | 0.3 / 0.4 | 0.4 / 0.9 |
| Haunted Fog, 390×844 | 0.2 / 0.3 | 0.6 / 0.7 |
| Event Horizon, 390×844 | 0.7 / 0.9 | 1.6 / 2.4 |
| Progress Flag, 390×844 | 0.7 / 0.8 | 0.4 / 0.5 |
| Japan Flag, 390×844 | 0.2 / 0.3 | 0.3 / 0.4 |
| Campfire, 1280×800 | 0.3 / 0.4 | 0.3 / 0.4 |
| Event Horizon, 1280×800 | 1.5 / 1.9 | 1.7 / 2.1 |
| Progress Flag, 1280×800 | 1.0 / 1.3 | 0.4 / 0.5 |

Scenic detail is not free: Event Horizon has the largest measured warm increase in this sample. Static pictures redraw only on changes; lobby animation remains capped at 15 fps on touch and 30 fps on desktop. Cold samples are noisy and include raster allocation: the highest candidate sample was 52.1 ms for the first portrait Progress Flag. This does not establish real-phone first-equip smoothness; inspect it on device.

The initial extra-overlay implementation was refined so animated scenes generally reuse an existing baked layer. Background raster retention is now an LRU bounded by **48 MiB and 24 entries**, with per-layer resolution capped near 16 MiB; the benchmark ended at 46,080,000 bytes. This is cached raster accounting, not total browser memory. The separate sprite cache remains bounded by **24 MiB and 96 entries**. The targeted varying-pose soak ended with 42 entries / 954,472 bytes, 40 worker completions and no pending jobs. An uncached Gold Knight paint remained comparable: median 3.8 → 3.9 ms, p95 4.7 → 4.5 ms. The baseline worker workload completed no jobs and fell back; the corrected candidate completed 36 in the equivalent benchmark.

The [build-size record](evidence/v0.9.3.4/build-size.json) shows index.html changing from 524,015 to 533,184 bytes; gzip comparison is 178,369 → 181,664 bytes (**+3,295 bytes**). No scene image assets or downloads were added. Development backup/evidence files are not included in the build asset list or service-worker cache. The generated cache version is `palisade-0e4e6153b7`.

## Remaining release checks

Big U should review the art and motion before publishing v0.9.3.4, then check the live update on a physical phone: portrait/landscape flags, first equip, Locker readability, movement/stop feel, large cosmetics and heat/frame consistency. Viewport emulation does not validate Safari, mobile GPU performance, battery use or installed-PWA behavior. No account/player data or live backend was changed during this work. Existing live account/PWA/PvP and movement-under-lag checks remain in the project blueprint.
