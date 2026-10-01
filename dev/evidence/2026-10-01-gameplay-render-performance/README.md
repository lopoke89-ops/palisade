# Gameplay Canvas rendering performance

October 1, 2026. Base: `cfca0e59edc2d920a336ca307c21124bcf6602e2`, verified
against GitHub `main` before work. Source release v0.9.6.0, protocol `yard-21`.
Implementation branch: `codex/gameplay-render-perf`.

The viewport cache reduces measured software Canvas rendering median time by
17.5–35.9% across four moving-camera XL workloads. Total measured frame work
falls by 17.3–35.1%. Chrome's normal RTX 3060 rendering path already maintained
60 Hz; its callback timings and RAF cadence did not materially improve. The
15% result applies to the measured software path, not every browser/device.

## Architecture and project layout

The active browser project is this checkout, `winter-release-0960/`. The primary
`../repo/` checkout was six commits behind verified main; the other local
worktrees contain earlier work. Desktop Godot and historical phone versions
are separate implementations.

`dev/src/page.html`, `style.css` and lexically ordered `js/*.js` assemble into one
shared-scope script. Edit those inputs, then run `dev/build.py`. Tracked root
`index.html`, `sw.js`, fonts/audio/icons and the manifest are the Pages/PWA build.
`debug.html` and `dev/test/out/` are ignored working files. `dev/evidence/` keeps
review evidence. Backend restore/migration files are under `dev/supabase/`.

The rendering path is:

1. `22-loop-menus.js`: RAF, input, host/guest simulation, render, music and DOM HUD.
2. `02-view.js`: DPR (existing cap 2), scale, pixel-snapped camera and projection.
3. `17-scenery.js`: cached ground/forest back layer, live ground effects, depth
   queue, projectiles, particles, front fence/trees, lighting, finishers/boss
   warnings, flashes, weather/vignette, floating labels and Canvas HUD.
4. `15-render.js` and `06b-maps.js`: walls, nodes, stakes, labels and terrain;
   `06d-elevation.js` reinserts Frostpeak cliffs into the depth queue.
5. `16-characters.js`: vector actors, bounded wardrobe sprites and worker pose
   generation. Auras and Blitz art extend it in `16b-*`/`16c-*`.
6. `20a-cosmetic-art.js`/`20b-winter-effects.js`: shared cached tracers, glows,
   cosmetic particles and finishers. `11-hud-chat.js` updates DOM meters and text.

The existing scenery, wall, terrain, label, tracer, glow and character caches
were retained. Existing sorting preserves painter order; particles and gameplay
state still update every simulation tick. The live ground layer continues to
draw floods, pits, frost and telegraphs above the static background.

## Profiling and decisions

Discovery CDP CPU profiles sampled every 200 microseconds. `drawImage` accounted
for about 62–75% of sampled main-thread time; `drawCache` was its largest parent.
Those early discovery runs precede the benchmark seed correction and are used
only to locate costs. The final timing/state comparison uses corrected seeds.
See `discovery-profile-summary.json`.

Canvas defers work. Unsynchronized stage markers initially attributed much of
the background raster cost to the later foreground call. A short diagnostic
with readback barriers **between stages** found background raster cost around
4.03 ms/frame, actor/items around 2.25 ms, and foreground around 1.92 ms in the
typical XL scene. With the viewport cache, the background stage fell to about
0.83 ms and diagnostic rendering median fell from 9.7 to 6.3 ms. These
instrumented diagnostics justify the change; the table below uses ordinary
render submission followed by only one diagnostic barrier per frame.

| Opportunity | Evidence and likely benefit | Risk / decision |
|---|---|---|
| Reuse static background raster at viewport/device pixels | Background ~4 ms in stage-barrier diagnostic; largest sampled image parent | Implemented; small localized change, bounded storage, same original source sampling |
| Crop foreground strips or give each a separate small canvas | Early stage markers looked costly | Tested and discarded: total work barely changed; some submission savings moved to the barrier |
| Actor pose generation and draw queue | Items average several ms in heavy scenes; actor painter/wardrobe visible in CPU profiles | Remaining tail-cost opportunity; pose caching and synchronous shot rendering already protect muzzle/animation behavior |
| Night lighting and warnings | Several ms in night/winter stages; lighting image parent visible in profiles | Retained full-resolution holes, blending and warning order; no measured quality-preserving replacement developed |
| DOM HUD, particles, trails and ordinary API state changes | HUD ~0.1 ms median; particles/tracers small compared with raster and items | Retained; rewriting these would have low demonstrated benefit |

The accepted change adds `drawBackView()` in `17-scenery.js`. It rasterizes the
original static layer into a viewport plus 96 CSS pixels of pan margin, then
copies visible pixels 1:1. Camera movement already snaps to device pixels, so
reuse preserves the original sample grid. Leaving the margin rebuilds the
same canvas. Map/scale/DPR changes get a fresh source cache; size changes rebuild
the view. Tree fading still updates only the existing foreground cache.

Full-resolution source caches keep their direct path. Extra view storage is
capped at **16 MiB**; larger viewports also use the direct path. In the measured
390×844/DPR 2 scenes the view uses **9,647,232 bytes (9.20 MiB)**, above the
existing 59,264,000 source-cache bytes. It is a single buffer, not a growing map
of camera positions. A debug-only getter reports bytes and rebuild counts;
the debug hook is removed from production by the existing build.

All existing resolution, art, particle density, animation/effect timing, draw
order, alpha/blending, input and simulation rules are retained. No quality
setting or gameplay tradeoff was introduced.

## Reproducible fixed-step measurements

Chrome 154.0.8037.92 on the same Windows desktop, 390×844 viewport, device DPR 2,
touch/mobile emulation, three fresh-context samples per scene. Software mode
uses `--disable-gpu --disable-accelerated-2d-canvas`. Assets/fonts and character
workers warm for 180 rendered updates with event-loop yields. Each sample then
measures 480 frames, for **1,440 frames per build per scene**. Both builds are
assembled unminified debug builds (`NOMIN=1`); production is rebuilt normally
for regression tests. No concurrent browser benchmarks were run.

The random generator is installed **before page scripts** because `rnd`
captures `Math.random` at startup. A fixed seed, fixed 1/60 simulation step,
identical moving-camera inputs and real game effects produce identical
recorded simulation states in all three samples of all four scenes.

The fixture uses the Yard for typical/dense play, Quarry for night, and
Frostpeak for winter, all XL. Typical has one player/12 raiders; heavy scenes
have six players/64 raiders/four bosses, mixed damaged/burning walls, shots
and particles. Winter adds real frost fields, winter cosmetics/finishers and
Final Blitz. This is a reproducible synthetic stress workload, not a physical
phone or an Internet multiplayer measurement.

Rendering is CPU submission plus an explicitly measured 1×1 readback barrier.
In software mode this includes deferred raster work. The barrier itself is
reported separately. It changes scheduling and is a diagnostic measurement,
not GPU execution time or physical display-present latency. Total work directly
times update + rendering + barrier + HUD, rather than adding their medians.

All values below are **median / p95 milliseconds**.

| XL workload | Render before | Render after | Median reduction | Total work before | Total work after |
|---|---:|---:|---:|---:|---:|
| Typical | 9.2 / 9.9 | 5.9 / 6.9 | 35.9% | 9.4 / 10.2 | 6.1 / 7.1 |
| Dense action | 14.4 / 29.1 | 11.3 / 26.3 | 21.5% | 15.0 / 29.9 | 12.0 / 27.0 |
| Night lighting | 17.6 / 32.7 | 14.5 / 29.7 | 17.6% | 18.3 / 33.5 | 15.2 / 30.6 |
| Winter effects | 17.7 / 33.8 | 14.6 / 30.7 | 17.5% | 18.5 / 34.6 | 15.3 / 31.5 |

| XL workload | Update before → after | Submission before → after | Barrier before → after | HUD before → after |
|---|---|---|---|---|
| Typical | 0.1/0.2 → 0.1/0.2 | 9.1/9.8 → 5.8/6.7 | 0.1/0.2 → 0.1/0.2 | 0.1/0.1 → 0.1/0.1 |
| Dense | 0.5/1.1 → 0.6/1.1 | 14.0/28.7 → 11.0/25.9 | 0.3/0.5 → 0.3/0.5 | 0.1/0.2 → 0.1/0.2 |
| Night | 0.5/1.0 → 0.5/1.0 | 16.3/31.3 → 13.2/28.3 | 1.3/1.7 → 1.3/1.7 | 0.1/0.2 → 0.1/0.2 |
| Winter | 0.6/1.1 → 0.6/1.1 | 16.4/32.4 → 13.3/29.3 | 1.3/1.7 → 1.3/1.7 | 0.1/0.2 → 0.1/0.2 |

Fixed-step work exceeded 16.67 ms in 0→0, 280→248, 1423→293 and 1438→362
frames respectively. These are **budget exceedances**, not observed missed
display frames.

## Actual game-loop cadence

Separate RAF playback calls the original full game `frame()` callback. It has
no Canvas readbacks, a three-second warm-up and two 12-second measured runs
per workload. The seed/workload pattern is the same, while the live loop keeps
its real elapsed-time simulation. Thus this checks sustained callback/cadence
behavior; fixed-step measurements above provide the exact-state comparison.

| Software workload | Callback work before, med/p95 | After, med/p95 | Estimated missed 60 Hz RAF slots before → after |
|---|---:|---:|---:|
| Typical | 9.2 / 10.2 | 6.4 / 7.4 | 0 → 0 |
| Dense | 15.1 / 29.6 | 11.8 / 26.5 | 140 → 39 |
| Night | 17.0 / 31.6 | 13.9 / 28.8 | 296 → 126 |
| Winter | 17.0 / 33.2 | 14.1 / 30.1 | 320 → 173 |

RAF median interval remains 16.7 ms. Dense p95 interval improves from 33.3 to
16.8 ms; night/winter p95 remains around 33.3–33.4 ms because heavy tail frames
remain. Missed slots estimate `max(0, round(interval / (1000/60)) - 1)`, using
equal measured wall-clock windows. This is a cadence proxy, not a hardware
presentation counter.

Default Chrome reports accelerated Canvas/compositing on NVIDIA GeForce RTX
3060, ANGLE D3D11/GaneshGL. Its callback med/p95 before → after is typical
1.1/1.4 → 1.2/1.4, dense 3.4/18.2 → 3.4/18.3, night 3.4/18.2 → 3.5/18.3,
winter 3.8/19.6 → 3.8/19.8 ms. All scenes retained median/p95 RAF spacing of
16.7/16.8 ms and zero estimated missed slots. There is **no demonstrated
15% gain on that accelerated desktop path**. Differences of 0.1–0.2 ms are
small compared with tails and the timer's 0.1 ms granularity.

Forcing readbacks through the default GPU path created an unrepresentative
synchronization workload, so that exploratory run was stopped and is excluded
from results. No reliable Canvas2D GPU timer was available; GPU time is not
claimed. Physical phones, browser fallbacks and other GPUs remain unmeasured.

## Visual, behavior and memory verification

Final verification results are recorded alongside this report. Canvas-only
checks compare all four maps, both map sizes, portrait/landscape/desktop,
fractional and capped DPR, camera motion within/beyond the margin, views beyond
the source bounds and resize. Live motion sequences use equivalent seeded
gameplay states. The initial whole-page night frame also caught a toast at
different points of its CSS transition; it is not used to assess cached pixels.

**Completed checks:** all 19 selected browser tests pass (`tests.json` and
individual logs). These cover solo/multiplayer, muzzle calibration, wardrobe
and presentation, CSP, FPS/input/controller/touch, HUD/pause/settings, winter
combat/cosmetics/elevation/network/reconnect and production offline launch.
The existing multiplayer test still expected four visual coordinates; main's
`yard-21` release already sends five, including ground height. Its assertion
was corrected to require all five finite coordinates; the full test then
passed. No network/gameplay implementation was changed for that repair.

**Canvas comparison:** 365 paired captures with both builds minified using the
same Terser options; all camera coordinates match. 180 captures are exactly
identical. The worst capture changes 0.0538% of pixels, with a maximum channel
delta of 12/255 and maximum mean channel delta of 0.000471 units. The differing
pixels are sparse high-contrast interpolation edges. Inspection at 3× shows
matching outlines and details; the checks found no stale view, missing terrain,
clipping, changed layering or geometry. See `cache-pixel-comparison.json`,
`cache-check.json`, `cache-diff-detail.png` and the four before/after gameplay
capture pairs in this folder. Full motion/edge/resize PNGs remain in ignored
`dev/test/out/render-perf/` for local inspection.

**Sustained memory:** a separate 60-second winter playback, plus warm-up,
records periodic heap collections. The viewport buffer stays at 9.20 MiB and
two initial builds throughout. Intermediate post-GC JS heap readings vary from
about 6.8 to 8.7 MiB while the benchmark retains timing arrays and workers have
jobs in flight. After the run and cleanup the retained JS heap is 6.62 MiB,
compared with about 6.49 MiB after the shorter candidate winter runs. The
existing wardrobe remains capped at 96 entries (about 3.91 MiB here). No
unexpected retained cache growth appeared in this one-minute check; it is not
a multi-hour leak guarantee. See `candidate-default-playback-sustained.json`.

The comparison allows sparse edge interpolation differences: at most 16 of
255 channel units, fewer than 0.1% of pixels, and mean channel error below
0.005 units. Skia uses finite-precision resampling matrices, so integer reuse
of a previously sampled large image is not guaranteed bit-identical to a fresh
resample at every translated camera origin. Counts and peak/mean differences
are retained for review; this tolerance does not permit missing geometry,
changed sharpness, stale views, flicker or missing effects. The worst observed
edge region was also visually inspected at 3× magnification.

The remaining tail costs are actor/item drawing and night/effect compositing.
Their p95 frames still exceed a 60 Hz work budget in the software heavy scenes.
The improvement preserves the original art rather than reducing effects to
hide these costs. Further optimizations should profile these systems with
deferred raster work accounted for.

## Repeat the checks

First build the **base commit** with `NOMIN=1` in an isolated checkout and copy
its `debug.html` to this checkout's ignored
`dev/test/out/render-perf/baseline-debug.html`. Preserve baseline `index.html`
there too for build provenance. This must happen before changing source.
Use the same installed Chrome, dependencies, viewport, DPR and machine for
both versions. Tests serve locally and block account traffic in these fixtures.

```powershell
$env:NOMIN='1'
python dev/build.py
node dev/test/render_perf.js baseline software
node dev/test/render_perf.js candidate software
node dev/test/render_playback.js baseline software
node dev/test/render_playback.js candidate software
node dev/test/render_playback.js baseline default
node dev/test/render_playback.js candidate default
python dev/test/render_perf_compare.py
# Build the minified production/debug pages for the focused regression gate:
Remove-Item Env:NOMIN -ErrorAction SilentlyContinue
python dev/build.py
node dev/test/render_baseline_min.js
pwsh -NoProfile -File dev/test/run_targeted.ps1 -Tests 'render_cache solo multiplayer muzzle wardrobe3d presentation presentation_network csp fps_mode touch_lock controller hud_layout ingame_settings winter_elevation winter_combat winter_cosmetics winter_network winter_reconnect winter_offline'
python dev/test/render_perf_compare.py
```

The local bundled Python with Pillow was used because the system Python lacks
Pillow. The harnesses accept `CHROMIUM` for an explicit Chrome binary.
`SCENES`, `SAMPLES`, `FRAMES` control diagnostic subsets in `render_perf.js`;
`PROFILE=1` records CDP profiles, and `STAGE_FLUSH=1` adds per-stage barriers.
Use neither profiler nor per-stage barriers for final comparisons. Playback
accepts `SECONDS`; `MEMORY=1` adds periodic GC/heap checks, and `OUTPUT_TAG`
keeps that separate from ordinary cadence evidence. Heap checks intentionally
perturb timing and their sustained run is used for memory verification only.

`render_baseline_min.js` minifies the preserved baseline without reading
candidate source and rehashes its CSP, for the same-build visual comparison.
`build-provenance.json` records measured baseline/candidate and final build
hashes. GitHub main was checked again after verification and remained at the
base commit above. Production assets were rebuilt and checked locally before
committing. This branch includes those rebuilt assets; release deployment is
separate from publishing the implementation branch.
