# PALISADE project status

Updated September 30, 2026. This is the current status record for the clone. The older project handoff and v0.9.3 hardening prompt describe a superseded release order.

For a consolidated list of what remains from those documents, see the [current project blueprint](PROJECT_BLUEPRINT_2026-09-29.md).
Big U's latest completed local scope is recorded in the [presentation prompt](plans/backgrounds-and-character-animation-prompt.md). The earlier [cosmetic and hardening prompt](plans/next-cosmetics-and-hardening-prompt.md) remains the record of v0.9.3.2 and its deferred work.

The Claude audit URL still requires sign-in in the available browser session. Big U supplied an exported copy at `D:\downloads\Untitled.md`, which was read on September 29. Its newest Progress entry is v0.9.3, so its release claims are superseded by the verified v0.9.3.3 release below. The external artifact itself was not edited here.

## Live and local

| Item | Current state |
|---|---|
| Live release | **v0.9.3.5** (v0.9.3.6 in this change) |
| Live protocol | `yard-17` / `palisade-yard-17-` (v0.9.3.5 candidate uses `yard-18`) |
| Applied server migration | `palisade_v0935_cosmetics` (`20260930050715`), additive and backward compatible; see below |
| GitHub branch | `main` at `4033d34` (v0.9.3.4 plus the UTF-8 repair); v0.9.3.5 candidate on `claude/lucid-curie-491na1` |
| Published build | GitHub Pages displays **v0.9.3.4** (service worker `palisade-0e4e6153b7`), checked September 30 |

Controller support shipped in v0.9.2.1. The v0.9.3 cosmetics migration is applied and the live case catalog includes Flags. The two proposed new game modes have not shipped; the Nightmare modifier and a future preset definition do not constitute a separate game mode.

Four commits after the v0.9.3 release changed the case intro and reel source (`98bb522`, `4c8dd3d`, `a49df08`, `566e30e`). The v0.9.3.1 release includes those fixes. Their source was compared with the v0.9.3 release on September 29; see [case animation validation](CASE_PERFORMANCE_2026-09-29.md). The reel avoids repeated style reads and its measured CPU use was lower, but intro readings overlapped and Locker readings were higher in the comparison runs. Further profiling and a real-phone comparison are still required before performance sign-off.

## v0.9.3.6: rejoin progress, frame rate, Delgado

**1. Disconnect and rejoin (audit of the 15 most recent games, September 30).**
- *What already worked:* a clean leave or disconnect sends an early-leave claim, and the v0.9.2 server rule pays only raids the player was present for, never twice.
- *Loss 1, client:* a reload, crash or killed app sent nothing, so the raids before the drop were lost. The client now saves a run draft every 3 s and on backgrounding, and sends it as an early-leave claim on the next start. Accounts use the normal claim queue; no-account players are paid into the browser locker. Test: `rejoin_drop`.
- *Loss 2, host:* a returning player started with a fresh armory. The host now keeps a dropped player's armory, salvage and kills for the game, keyed by the tab's room session, and restores them on rejoin ("IS BACK"). Test: `rejoin_drop`.
- *Loss 3, server:* `claim_match_reward` capped bosses per claim from the previous claim's raid + 1, so a boss (or Boss Rush/Nightmare in-between boss) on the first raid after a rejoin was paid to nobody. Migration `20261001000000_palisade_v0936_rejoin_bosses.sql` caps bosses over the player's whole stay minus earlier claims, and records `boss_n`. The pre-change live function is saved in `supabase/snapshots/`. Test: `rejoin_migration` runs the same claims through the live function (bug reproduced) and the migration (fixed; uninterrupted games unchanged; no double pay; old-row fallback; re-apply). **Not applied live: awaiting Big U's approval.**
- *Affected players found:* the table below. The kappinkirk cases match a hard drop: the claim starts mid-game with no earlier claim, and in `mulw1qg2` their previous FFA with the same partner ended three minutes before the run started. Please confirm with the player if possible. Supply case counts can differ by ±1 because teammates' case progress carries over differently.

| Player | Game | What was lost | Proposed grant |
|---|---|---|---|
| kappinkirk | `munif0e3` Endless XL, Riverbend, 30 raids | raids 1-14: 4 bosses (2 Ferryman, 2 Butcher), 6 Boss Rush bosses | 10 Supply, 4 Halloween, 138 shards, 13 skill points; raids/map/class +14; boss_ferryman +2, boss_butcher +2 |
| kappinkirk | `mulw1qg2` 10-raid XL, Riverbend | raids 1-6: 2 Ferryman, 3 in-between bosses | 3 Supply, 2 Halloween, 69 shards, 6 skill points; raids/map/class +6; boss_ferryman +2 |
| meezy2greezy | `mulv3e8h` 10-raid XL, The Yard | raid 7 (21 s disconnect); armory reset | 1 Supply; raids/map/class +1 |

The script `supabase/compensation/2026-10-01_v0936_rejoin.sql` applies exactly this. It sends each player a mailbox note, and it is keyed so a second run grants nothing (tested in PGlite). **Not applied.**

**2. Frame rate and performance.**
- *Setting:* Settings → Screen → Frame rate: Auto, 30 FPS or 60 FPS. Auto runs at 60 on phones and drops to 30 for the rest of the run when frames average over 12 ms or the battery is at or below 30% and not charging. On desktops Auto is uncapped.
- *Why 60 matters too:* 60 now also caps 90/120 Hz phones, which previously drew up to 120 frames a second.
- *Cap correctness:* the cap is exact (measured 30/60), game time runs at real speed either way, and a host and guest at 30 FPS move with no host rejections (`fps_mode`).
- *Label cache:* outlined labels (name tags, damage numbers) are now cached images. In the six-player Endless raid-20 stress scene, median render dropped 10.8 → 8.7 ms and world-object drawing 4.8 → 4.0 ms.
- *Estimated CPU:* drawing CPU per second drops about 60% at 30 FPS versus 60 before, and about 60% on 120 Hz phones at the 60 cap. Heap is flat over 30 simulated minutes (5 MB).
- These are desktop-software-canvas measurements; the heat improvement needs a physical-phone check.

**3. Delgado.** Every player-facing "Dell" now reads "Delgado", with the Solo page nod "(as in 'Dell got you')". Internal ids (`dell`, `qm`, `13-dell.js`, network and save fields) are unchanged. HUD and armory fit at 390×844 and 844×390 (`delgado`).

Protocol stays `yard-18` (no packet change).

## v0.9.3.5 candidate: cosmetics package (not published)

The implementation record is [COSMETICS_V0935_CHECKPOINT.md](COSMETICS_V0935_CHECKPOINT.md). Flag Case tracers become solid one-color rounds that cycle per trigger pull (Transgender cycles blue-white-pink), with all pellets sharing a color; the index travels with live, start and full-snapshot bullets under protocol `yard-18`. Tracer drawing uses smaller cached stamps, offscreen culling, time-based particle shedding and in-place bullet compaction. Six compact Halloween head pieces are added to the Halloween Case. Special heads block added headwear (Sheet Ghost accepts only Halo); blocked hats stay owned, render as Class Issue, and the Locker shows Class Issue as equipped. Tung Tung Tung Sahur is a full-character Supply Case skin in the new Ultimate rarity (0.25%, 80 duplicate shards, provisional economy).

**Server:** migration `20260930050715_palisade_v0935_cosmetics` is already applied to the live project (the local file was renamed from `20260930045719` to match the live record). Live verification on September 30: the seven items exist at `catalog_version` 1, Supply weights are 59.75/27/10/3/0.25, the rarity check accepts `u`, no player owns a new item yet, `open_case_of` pins old clients to catalog 0 with the old 60/27/10/3 odds, `open_case_v0935` serves catalog 1, anon has no execute grant, and the legacy `open_case` no longer exists. The client never reads `case_types`, so published v0.9.3.4 clients are unaffected. The security advisor reports no new finding from this migration.

**Checks:** build reproduces; 19 focused checks pass in Linux Chromium: `tracer_cycle`, `tracer_network`, `ultimate_cloud`, `cosmetics_expansion`, `cosmetics_migration` (12 PGlite checks), `cosmetics`, `wardrobe3d`, `cosmetic_network`, `flagcase`, `muzzle`, `presentation_posefit`, `locker_fit`, `locker_collections`, `cases`, `accounts`, `csp`, `multiplayer`, `hostcheck`, `room_controls`. The new tests are in the `cosmetics` group. Interleaved three-trial tracer A/B (desktop Chrome, phone viewport): flags 300 median 9.8 → 1.6 ms, p95 16.6 → 2.8 ms; non-flag 300 median 11.1 → 7.5 ms, p95 17.2 → 10.9 ms; GC total 33 → 24 ms. The earlier non-flag p95 regression did not reproduce. Evidence is in `evidence/v0.9.3.5/`. This is not a full-suite or physical-phone result.

**To publish:** merge to `main`; the server side is already in place. Because the protocol changes to `yard-18`, v0.9.3.4 and v0.9.3.5 players cannot share rooms until both reload. Physical-phone review of tracer feel, Sahur and the head pieces remains open.

## v0.9.3.4 published (originally blocked)

The UTF-8 repair was pushed as `4033d34`; Pages now serves v0.9.3.4. The paragraph below is the original September 29 record.

Big U pushed commit `854265d7f529eb14837fcd7e9b8a7e3ba0e25d9b`. [Pages run 36648248102](https://github.com/lopoke89-ops/palisade/actions/runs/36648248102) failed during Jekyll rendering of `dev/PROJECT_BLUEPRINT_2026-09-29.md`: invalid UTF-8 punctuation bytes. Deployment was skipped, and fresh live page/service-worker fetches still return v0.9.3.3. The document encoding is repaired locally; the tracked text files pass strict UTF-8 validation. Commit and push this documentation-only repair, then verify a successful Pages run and the v0.9.3.4 live footer. The game build does not need to be rebuilt for this repair.

All 32 Flag Case backgrounds now fill their canvases with responsive fields and proportional emblems. 24 scenic backgrounds receive cached, theme-specific finishing layers; Arcade retains its original pixel-art composition. The old sources and matched before captures are preserved in the [backup manifest](backups/2026-09-29-v0.9.3.3-presentation/MANIFEST.md), with a per-background restore path. No image downloads were introduced.

Character rendering now uses displacement-driven presentation gait, planted/lifted steps, bent knees, directional strafing/backpedalling and a settling transition. Tiny residual remote interpolation does not keep a walking pose alive. Lower-leg cosmetic details follow the articulated legs. Lobby/Locker idle breathing is subtle and disabled with reduced motion. Weapon and muzzle measurements share the same pose; gameplay values and the network protocol are unchanged. A self-contained renderer factory fixes worker serialization under minification, which previously fell back to synchronous painting.

Build and nine focused checks passed: `presentation`, `presentation_posefit`, `flagcase`, `wardrobe3d`, `locker_fit`, `muzzle`, `presentation_network`, `cosmetic_network`, and `csp`. The capture and A/B performance utilities also completed. This is not a full-suite run. See [the presentation report](PRESENTATION_2026-09-29.md) for saved images/clips, measurements, worker verification and physical-phone limits. No Supabase change is required. Big U still handles publication.

## v0.9.3.3 Locker release

Milestone cosmetics now appear only in MILESTONES. Ordinary categories show STANDARD & UNLOCKS followed by independent case-collection disclosures with owned/total counts. Collections begin collapsed, remember their state for the page session, and allocate tiles only when opened. Equip/cloud refresh updates mounted tiles in place, preserving focus and scroll. A case result's EQUIP action opens the relevant collection and focuses the item. Case OPEN/BUY controls remain in their separate panel. No protocol, server, or save-format change is included.

Build and eight focused checks passed: `locker_collections`, `milestones`, `flagcase`, `accounts`, `locker_fit`, `cosmetics`, `csp`, and `taborder`. Screenshots were inspected at 390×844, 844×390, and 1280×900. On the phone-sized PC benchmark, initial Skins canvases dropped from 72 to 4 and grid height from 7,827 to 660 CSS pixels; measured CPU work was lower in this small PC sample. See [Locker validation](LOCKER_UI_2026-09-29.md). Big U committed and pushed this release; GitHub `main` and the live v0.9.3.3 footer were verified. Physical-device testing and the older movement/account/PWA verification limits remain open.

## v0.9.3.2 release and remaining verification

The next-work prompt was implemented in v0.9.3.2 where it is independent of reward and identity changes. Opaque masks and headpieces now hide the base facial features in both character painters, and Clown Hair is one rounded afro shape. The Locker captures include Galaxy, Clown Hair, and covered faces. Matching v0.9.3.1 before and v0.9.3.2 after images for Clown Hair and the Scary Clown skin are in `dev/test/out/`. Case-opening performance was left alone because Big U reports the lag fixed on desktop and mobile.

The host now validates the accepted guest message fields and meters movement by elapsed time, with a burst cap, class/perk/modifier/terrain speed allowance, and debug rejection counts. Host kick and room lock work for lobby and direct joins, with a single coordinated bump to `yard-17`. A kicked browser session is refused on rejoin to the same room. These are host controls, not a server-enforced ban against a modified client or fresh browser session.

The build emits a script-hash CSP as a page meta policy for normal and debug pages. Vendored PeerJS remains at 1.5.5 after upstream review; the test dependencies have no npm audit findings, and their package lock is included for reproducible installs. No package upgrade was justified. No server migration or live Supabase change was part of this release. Suspicious-operation logging was not added: the useful refusal events arise inside reward/import/skill RPC transactions, where an exception rolls back any event insert. Persisting those events would require changing those deferred RPC response contracts, so the log remains coupled to the later server-design work.

Focused cosmetic, Locker, host, multiplayer, CSP, account, music, solo, and lobby checks passed locally. A physical-phone check is still needed for cosmetic fit and movement tolerance under Wi-Fi/cellular lag, sprint, water, and storms. The published site displays v0.9.3.2. A fresh Chrome live smoke passed host/guest room join, menu and raid audio asset fetches, manifest fetch, and an offline reload under the service worker. Account sign-in with a test account, installed-PWA behavior, PvP, and longer live play remain unchecked. No full-suite run was needed for this scoped change. Do not call the phone movement cap fully calibrated until physical-phone checks pass.

## v0.9.3.1 release scope

The [v0.9.3.1 implementation prompt](plans/v0.9.3.1-polish-music-safe-hardening.md) scoped this patch to targeted test selection, cosmetic fit and Locker framing, new menu and co-op raid music, and safe host-side guest input validation. The [broader hardening plan](plans/v0.9.3.1-hardening.md) remains a backlog reference. Account identity, import trust, reward-claim retry/rejoin behavior, room kick/lock, and any Supabase migration are **not** fixed by this release.

The release rejects malformed/non-finite guest movement, aim, build, grenade, and ability values at the host boundary. It leaves the `yard-16` protocol, valid guest messages, rewards, accounts, and live server unchanged. Database changes remain subject to the project's release rules. Do not backfill milestone counters or alter existing live player data without Big U's approval.

## Verification

The v0.9.3.1 build passed with the bundled Python/Pillow runtime and local Terser. Focused Chrome checks passed for cosmetic art, wardrobe variants, cosmetic network replay, Locker fit at phone and desktop viewport sizes, music routing/decoding, malformed host input, and an honest host/guest multiplayer run. The prior reel/music check also passed. These are selected checks, not the full 29-test suite. Screenshots in `dev/test/out/` show Galaxy, Pumpkin, Top Hat, and other brimmed hats in the Locker. The [corrected mobile performance rerun](CASE_PERFORMANCE_2026-09-29.md#corrected-mobile-rerun-for-the-v0931-candidate) supports the reel optimization but still shows higher Locker CPU; a physical-phone check remains open. GitHub Pages serves the v0.9.3.1 page; post-release multiplayer, audio, and account behavior have not been validated against live services.

See the broader [September 29 project review](../../PALISADE_project_review_2026-09-29.md) for evidence, risks, and limitations.
