# v0.9.3.5 cosmetics implementation and resume record

Updated 2026-09-29. User authorized implementation of the revised three-track cosmetics package and requested durable checkpoints after each major step.

## Resume here

Tracer implementation and focused functional tests pass. A/B flags improve markedly; nonflag high-percentile timings are noisy, so final performance sign-off remains open. Stage 3 artwork/catalog implementation is now in progress: six pieces, Sahur and compatibility code exist but need new capture/regression checks. Next: run new cosmetics expansion checks/captures; inspect images; finish network color test, repeated A/B and server release SQL.

Workspace: `C:/Users/lopok/Documents/Palisade/repo`. Starting commit: `4033d34` (v0.9.3.4 plus documentation repair). Starting working tree was clean. No AGENTS.md was found in the workspace or ancestor directories.

Do not restart completed stages. Read this document and `git diff --stat`, inspect unfinished changes, and use the focused commands below. Big U normally commits and pushes through GitHub Desktop; leave the finished changes reviewable locally. Do not mark deployed based on a local build.

## Accepted scope and decisions

- Track A: optimize all tracer live drawing; all 32 existing Flag Case trails become solid-color shots. Per fired round, not per pellet/frame; all pellets share one color. Transgender follows the requested blue-white-pink cycle. Preserve other catalog orders, including repeated colors. Sequence index travels with live and snapshot bullets. Bump protocol for the changed packet layout.
- Track B: six compact Halloween head pieces: Gravestone Cap, Pumpkin Stem Band, Bat-Notch Circlet, Bone-Button Wrap, Cobweb Brow Pin, Crescent Skull Seal. Default block special heads; Sheet Ghost permits only Halo after pixel separation validation. Blocked combinations remain owned and are suppressed consistently in all rendering/equip paths.
- Track C: Tung Tung Tung Sahur special full-character appearance in the original Supply Case, new Ultimate rarity `u`. Working economy choice: 0.25% Ultimate, 59.75% Common, 27% Rare, 10% Epic, 3% Legendary; 80 duplicate shards. Keep collision and weapon simulation unchanged. Use the existing cached Canvas character frame architecture; verify animation, bounds and muzzle placement.
- Character reference: https://www.mementumlab.com/wiki-tung-tung (wooden character with expressive face and wooden beater). Adapt visual identity to existing art; held class weapon remains readable during play.
- No changes to deferred reward retry/rejoin, identity/import, modes or unrelated UI.
- Server project: `puvjfhwxigxjpsvdwrwf`. Read-only discovery works. Prepare and verify release SQL; do not activate unknown rarity/items for old live clients. Record migration deployment separately.

## Stages

1. [x] Audit current catalog, tracer painter, firing and network paths, build/test conventions and server access.
2. [x] Save baseline; implement tracer optimization, cycle and network transport; run focused functional checks and initial A/B measurements. Performance acceptance remains open as noted below.
3. [x] Implement six head pieces, compatibility, special character and Ultimate catalog/UI; focused validation and first captures reviewed. Final capture refresh remains in Stage 5.
4. [x] Prepare catalog/rarity migration and update restore schema; 12 local PostgreSQL checks pass. Live deployment/verification still pending.
5. [ ] Build v0.9.3.5; final relevant checks; archive evidence and update STATUS/blueprint/release notes.

## Tools and commands

- Build: `python dev/build.py` (requires Pillow; bundled Python available at `C:/Users/lopok/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`).
- Tests: `powershell -File dev/test/run_targeted.ps1 -Tests "..."`; available Chrome `C:/Program Files/Google/Chrome/Application/chrome.exe`.
- Existing relevant tests: cosmetics, wardrobe3d, cosmetic_network, flagcase, locker_fit, locker_collections, muzzle, presentation_posefit, cases, csp. Select tests based on changed paths; do not automatically run entire suite.
- Test output: ignored `dev/test/out/`. Preserve selected results under `dev/evidence/v0.9.3.5/` at completion.
- Source under `dev/src`; build emits root index.html/sw.js and ignored debug.html. Do not hand-edit generated files.

## Evidence and limitations

- Baseline debug build: ignored `dev/test/out/cosmetics-baseline.html`; original source remains at 4033d34.
- Passed: tracer_cycle, cosmetics, muzzle, flagcase, cosmetic_network. New protocol yard-18; each shot has tc index; start/join and explicit full snapshots restore live shots; duplicate events are ignored.
- First test attempt could not launch Chrome inside sandbox (spawn EPERM); test runner works with require_escalated. No user-data mutation occurs in these mock/local tests.
- Latest A/B: 300 flags median 4.0 -> 1.3 ms, p95 6.2 -> 1.9 ms; 300 nonflags median 5.5 -> 4.4 ms, p95 8.7 -> 8.5 ms. The 100 nonflag p95 regressed in a noisy sample; repeat with interleaved trials before acceptance. See ignored tracer_perf.json. Heap deltas are retained heap, not total allocation or GC proof.
- Source changes: flag cycle uses two fillRects, no flag stamp/particles; generic stamps 96x24, fewer clip/fill/stroke calls; reused tracer coordinates; offscreen culling; time-based particle shedding; in-place bullet compaction. Existing bullet allocation deliberately remains to avoid expanding simulation risk.
- Stage 3 code currently uses existing cached character Canvas frames; no new per-frame animation layer. Ultimate provisional rate/shards recorded above.
- Stage 3 passes: cosmetics_expansion (all skin/hat blocking rules, 48 Halo/Sheet Ghost angle/time combinations, Sahur classes/motion/bounds/thumbnail, rarity and actual Locker interaction), wardrobe3d, presentation_posefit, muzzle, locker_fit, locker_collections. Contact sheet at dev/test/out/cosmetics_expansion.png was inspected. Refined round Sahur eyes and web pin afterward, then expansion retest passed.
- tracer_network passes actual host-to-guest and mid-match join for nine pellets in three successive colors plus the Sahur look.
- Tracer decoration marks now bake into the smaller cached stamp; final interleaved benchmark still pending.
- Supabase read-only audit confirms live rarity check c/r/e/l/g and Supply weights 60/27/10/3. Plan versioned case RPC so old clients retain their old pool/odds while new clients can receive Ultimate; no live mutation yet.
- Migration file generated by Supabase CLI: dev/supabase/migrations/20260930045719_palisade_v0935_cosmetics.sql; same extension appended to restore schema. Client uses open_case_v0935; open_case_of preserves old Supply odds and excludes version-1 items. Authenticated public invoker wrappers call private.open_case_catalog definer (requires identity, ban check and row lock); old private helper execute grants remain denied. Catalog version defaults to 0; seven new items are version 1.
- `node dev/test/cosmetics_migration.js` passes 12 checks in an isolated PGlite PostgreSQL instance (no live account writes); migration reapplied successfully; old pool, new hats, forced Ultimate/80 shards, stale revision/empty/missing user/banned rejection, other locker preservation, anon/old-helper permissions. PGlite 0.5.8 added as pinned dev dependency with lockfile, npm audit zero findings.
- Current resume focus: finish repeated tracer performance/GC metrics, mock Ultimate cloud UI, final build+focused tests, then apply safe versioned migration and verify catalog/advisors. Save final evidence, status and blueprint; leave Git commit/push to Big U.
- Existing status docs are stale about the pushed UTF-8 repair; current local commit is 4033d34. Recheck live version before updating deployment claims.
- Physical phone performance cannot be claimed from a desktop emulation benchmark.
- Checkpoint updated before implementation so interrupted work can resume from Stage 2.
