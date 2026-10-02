# Winter upgrade completion report

Implemented October 1, 2026 as local source/build **v0.9.6.1**, protocol **yard-22**, against baseline `07eb5e54d53525277f6f8839e6d7b0e4a5617680`. The game changes are ready for review in this checkout. The additive Supabase catalog migration is live; the game build was subsequently pushed as [`526831b`](https://github.com/lopoke89-ops/palisade/commit/526831bad0c4369a5058f9a5812e20413a1e9367) at the user's request, and its live HTML exactly matches the committed bytes.

## Delivered behavior

- **Winter models:** Yulemaw (Epic), Rednose Demolisher (Legendary), and Gilded Frostborn (Gold) use separate head, body, limb, and accessory geometry. Rednose has modeled hip grenades. Frostborn carries gold trim, seasonal snow, stars, and a ground ring. Custom heads retain their own headwear and reject incompatible hats. Full models are used even in compact case/Locker previews. Winter now contains **45 items, including 13 skins**: 37 case items and eight milestone skins.
- **Tracers:** Aurora Lance sheds short-lived snow dust; Solstice Comet sheds four seasonal bulb colors. Flag bullets use the shared tapered stamp while preserving stored shot colors and shared pellet colors. Legendary/Gold flags shed particles colored from the emitting bullet's `tc`. Cosmetic shedding runs at 80 ms intervals, or 160 ms under the existing 30 FPS/low-power mode, stops under reduced motion, and respects the particle cap. Glitch Line's measured shared body area ranges **86.98–96.77%**, with a median **92.31%**, at widths 2/4/7 and five sampled animation times. Chromatic layers remain distinct.
- **Delgado:** the host/solo player selects Follow or Defend from the HUD, pause menu, `H`, or a configurable controller action. Guests see the command and cannot change it. Follow keeps him near the host and permits reachable urgent revives. Defend prefers a perimeter anchored one tile northwest of the core, spanning 4×4, with a 3×3 terrain fallback. Doors preserve access; an additional path check rejects new solid walls that would remove an actor's existing core or escape route. Normal construction costs apply. Earned material tier is derived from completed raids: wood initially, brick after five, metal after ten, then the existing cap. Existing wall material serves as the completed-work record, so switching commands cannot pay for the same upgrade twice. The schedule is separate from Armory weapon level and survives campaign transitions and client reconnects.
- **Dead End:** an unrecoverable crew receives a 1.5-second message and 0.6-second fade before normal results. The host commits the reason once and replicates remaining transition time. Recoverable timed respawns, reachable Delgado revives, living teammates, and already-earned preparation/raid completion continue. Finite projectiles settling after the last enemy do not cancel that preparation recovery. Extracted players keep their personal evacuation outcome. The core remains intact in the reported loss; result claims and retry receipts use the normal reward contract.
- **Shields:** the named `RIOT_SHIELD_HITS` limit is **20 physical bullet contacts**. Damage does not affect wear. Each contacting pellet costs one hit; misses and rear hits do not. AP costs one hit and retains penetration. Blasts and other nonbullet damage leave the count unchanged. The final ordinary bullet is blocked, then the shield breaks; later bullets pass. Worn artwork, bounded sparks, a sound, and the break label reflect state. The carrier remains alive and uses pistol behavior after breaking. Remaining/max hits and break state are appended to enemy snapshots.

The implementation is concentrated in [commands and recovery](../../src/js/13b-commands-recovery.js), [Delgado simulation](../../src/js/13-dell.js), [shield collision](../../src/js/14-raiders.js), [model renderer](../../src/js/16-characters.js), [tracer painter](../../src/js/20a-cosmetic-art.js), and [network state](../../src/js/21-online.js). The shared particle painter is also used by the catalog exporter. Source changes were rebuilt into `index.html` and `sw.js`.

## Catalog and visual evidence

The [complete catalog](../../catalog/cosmetics/README.md) contains **311 inventory entries**: 88 skins, 43 hats, 75 tracers, 36 kill effects, and 69 backgrounds, across **50 PNG sheets**. Every directional entry has exactly **front/right/back/left** panels. Animated effects/backgrounds use four time samples. [Catalog JSON](../../catalog/cosmetics/catalog.json) includes capture seed/time, build hash, palette inputs and rendered swatches, acquisition, renderer sources, compatibility, motion/cache policy, and per-item findings. All 311 acquisition records match the [verified server catalog](../../catalog/cosmetics/server-catalog.json); no renderer-only entries or duplicate IDs were found. After measured framing, no blank or boundary diagnostics remain. Pixel diagnostics establish capture coverage; they are not a claim of exhaustive aesthetic judgment or absence of clipping in every possible pose.

- [New model views](new_winter_models.png) and [winter catalog sheet](../../catalog/cosmetics/skin-winter-2.png).
- Matched tracer previews: [before](tracers_before.png), [after](tracers_after.png); [particle/color/overlap measurements](winter_tracers.json).
- Guest screenshots: [DEAD END](dead_end_guest.png), [results](dead_end_results.png).

Regenerate with `node dev/catalog/capture-cosmetics.js` after rebuilding. The exporter starts its own local server, uses installed Chrome (override with `CHROMIUM`), and verifies against the checked-in server snapshot. Refresh that snapshot when the authoritative catalog changes.

## Validation and backend

**36 affected suites passed**, with logs listed in [verification.json](verification.json) and stored beside this report. Coverage includes actual shield collision, exact 20-hit breaks for damage 1 and 1000, partial pellet hits, AP, blasts, contact deduplication, build costs/upgrades, Follow distance, terrain fallback, unreachable recovery, compact model previews, all classes/downed poses, controller/touch presentation, modifiers, bosses, rewards, ammunition, multiplayer, late joining, and winter reconnects. The focused model test renders **96 class/angle/downed combinations**. See [gameplay checks](winter_upgrade.json) and [real co-op checks](winter_upgrade_network.json), including an actual Last Stand + On Your Own restart with the entire crew down.

The baseline reproduction stayed in `raid` with an intact 500-HP core, absent Delgado, and a respawn timer near one million. The candidate resolves that state through Dead End. Recoverable controls and mixed evacuation outcomes pass. The isolated fresh-database restore test accepts a completed-raid crew loss and returns the retry receipt without a second reward.

Migration [20261001214620_winter_models.sql](../../supabase/migrations/20261001214620_winter_models.sql) was applied to project `puvjfhwxigxjpsvdwrwf`. It appends only the three skins at catalog version 3 and exposes `open_case_v0961`. The isolated authoritative picker obtained each skin at its required rarity; thirty old-client rolls remained inside catalog version 2. Winter price remains 14 shards and weights remain 45/32/16/6/1. The new RPC grants authenticated execution and denies the anonymous database role. [schema.sql](../../supabase/schema.sql) now replays the missing historical extensions and all checked-in migrations; [refresh-restore.py](../../supabase/refresh-restore.py) regenerates those extensions. A fresh isolated restore passes.

The post-migration security advisor returned existing privileged-RPC, anonymous-auth-policy, and password-protection notices. The new public wrapper uses invoker security. Existing private RPC-only tables intentionally retain RLS without client policies. Advisor explanations are available in the [database linter documentation](https://supabase.com/docs/guides/database/database-linter) and [password-protection documentation](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection); unrelated account policies were outside this work order.

Re-run focused checks using:

```powershell
powershell -NoProfile -File dev/test/run_targeted.ps1 -Tests "winter_upgrade winter_upgrade_network winter_tracers winter_cosmetics cosmetics controller winter_models_migration restore_schema"
```

## Performance and remaining verification limits

Measured in desktop Chrome 154 software Canvas at a 390×844 viewport and DPR 2, with fixed seeds, two samples of 120 frames per scene. Total work includes simulation, rendering, a diagnostic raster readback, and HUD. These are CPU/software-raster measurements, not physical-phone or GPU timing.

| Scene | Baseline median / p95 | Candidate median / p95 | Median change |
| --- | --- | --- | --- |
| Typical solo | 8.1 / 10.6 ms | 8.5 / 13.0 ms | +4.9% |
| Dense six-player scene | 15.3 / 32.7 ms | 17.2 / 35.1 ms | +12.4% |
| Six-player Frostpeak/Final Blitz | 18.1 / 35.7 ms | 20.5 / 40.3 ms | +13.3% |
| All three new models, upgraded tracers, six players | — | 18.8 / 34.9 ms | Candidate-only feature stress |

The new-model stress scene peaks at 243 particles and approximately 4.3 MB of wardrobe cache, below the existing 600-particle and 24-MB cache limits. Dense software-rendered scenes exceed a 16.7-ms frame budget in both builds, and the added presentation has a measurable cost. Physical-phone heat/battery, Safari, and real wide-area networking remain unverified. Mobile viewport, touch, low-power emission behavior, and local WebRTC host/guest tests pass. Raw measurements: [baseline](baseline-software.json), [candidate](candidate-software.json), [new-model stress](holiday-software.json). Benchmark command: `node dev/test/render_perf.js baseline|candidate|holiday software`, with `CHROMIUM`, `SCENES`, `SAMPLES`, and `FRAMES` overrides.

The winter build is published as commit `526831b`. This performance caveat still applies; clients need to reload for protocol yard-22. The subsequent published music/case release is recorded in its [completion report](../2026-10-01-music-case-batches/README.md).
