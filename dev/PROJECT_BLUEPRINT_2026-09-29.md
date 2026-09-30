# PALISADE: current summary and next-work blueprint

Updated September 29, 2026. This is the working summary for the next release planning pass. The three original handoff/prompt files are historical inputs, not an accurate description of today's release. For exact release and test evidence, use [STATUS.md](STATUS.md) and [case performance validation](CASE_PERFORMANCE_2026-09-29.md). Recheck GitHub and the live service before any future implementation or migration.

**Latest scope decision:** Big U reports that case-opening lag feels fixed on desktop and mobile. Cosmetic facial clipping and independent hardening shipped in v0.9.3.2; reward retry/rejoin and import/account-identity changes remain deferred, and new modes wait. The actionable scope is in [the next-work prompt](plans/next-cosmetics-and-hardening-prompt.md). The earlier priority order below is retained as an inventory, not an instruction to implement deferred items now.

Big U supplied an exported copy of the Claude audit at `D:\downloads\Untitled.md`. Its Progress section reaches v0.9.3, not v0.9.3.1; its older v0.9.0 audit and build-order sections are historical. The current release evidence and Big U's latest scope decision above take precedence over that older plan.

**September 30 update:** v0.9.3.4 is live. The v0.9.3.5 cosmetics candidate is complete and awaits merge; its migration (`20260930050715`) is applied live and verified. The Supabase row below and the release order are otherwise unchanged. See [STATUS.md](STATUS.md).

**October 1 update:** v0.9.3.6 is live: run progress survives drops and rejoins, the Auto/30/60 frame rate, Delgado, and the rejoin boss-credit migration `20260930071534` plus approved compensation. v0.9.3.7 adds touch auto-lock, in-game settings and the Nightmare + Boss Rush synergy. The current next-work order is at the end of [the optimization audit](OPTIMIZATION_AUDIT_2026-10-01.md): physical-phone pass, quick hygiene, a current schema dump with SQL tests, reward retry idempotency and import/identity, a frame-cost pass, then game-mode planning.

## Verified position

**Current local work:** v0.9.3.4 is implemented, tested, and pushed as `854265d`. Its Pages build failed on invalid UTF-8 in this document; that encoding is repaired locally and needs a follow-up push. It adds full-screen flags, cached scenic depth and natural character motion. The [presentation report](PRESENTATION_2026-09-29.md) includes evidence and [backup/restore instructions](backups/2026-09-29-v0.9.3.3-presentation/MANIFEST.md). The live release is v0.9.3.3 at `2268c35`, with Milestones-only browsing and collapsible Locker collections. Reward retry/rejoin, import/identity and new modes remain deferred.

| Area | Position | Evidence or limit |
|---|---|---|
| Game | **v0.9.3.3 is published** on GitHub Pages; GitHub `main` is at `854265d` (v0.9.3.4 deployment failed) | GitHub commit history and live page footer checked September 29. |
| Networking | Live `yard-17`, room prefix `palisade-yard-17-` | Host kick/lock shipped with the coordinated protocol bump. |
| Supabase | Last confirmed applied migration: `20260928224258_palisade_v093_milestones_flags_halloween` | v0.9.3.2–v0.9.3.4 contain no migration or server change. Live schema was not re-audited after this release. |
| Testing | Targeted test runner and 35-test full suite are available | v0.9.3.4 passed nine focused presentation/UI/muzzle/network/CSP checks; `presentation` selects this group. v0.9.3.3 passed eight focused Locker checks. No full-suite run. v0.9.3.2 live host/guest join, audio/manifest fetch, and offline reload passed previously. |
| Performance | Case reel uses fewer CPU milliseconds in corrected phone-sized PC runs and avoids repeated style reads | Intro results are less decisive; the Locker scene was higher in the available comparison. A physical-phone comparison is still open. |

Controller support shipped in v0.9.2.1. The milestone, class, Halloween, and Flag Case expansion shipped in v0.9.3. The v0.9.3.1 release added cosmetic and Locker fit changes, main-menu and raid music, targeted test selection, and basic host-side rejection of malformed guest inputs. The two proposed new game modes have **not** shipped. The existing Nightmare modifier and `MOD_PRESETS.nightmare` constant are not a standalone mode.

## What remains from the original documents

| Original request | Status now | Next action |
|---|---|---|
| Milestone skins, class rewards, Halloween items, Flag Case, progress and unlock screens | Shipped in v0.9.3 with its migration | Do not rebuild this release. Check the boss-counter interpretation below before changing rewards. |
| Cosmetic clipping, Galaxy Locker framing, menu/raid music, targeted test workflow | v0.9.3.1 shipped; facial occlusion and one-ball Clown Hair shipped in v0.9.3.2 | Obtain real-device visual/audio feedback, especially phone Locker framing and performance. |
| Basic malformed guest input checks | v0.9.3.1 shipped basic checks; v0.9.3.2 covers accepted guest messages and elapsed-time movement | Calibrate the cap on honest Wi-Fi/cellular phone play across classes, sprint, perks, water, storms, and lag. |
| Independent network and web hardening | v0.9.3.2 adds host kick/lock, `yard-17`, script-hash CSP, and a dependency review | Live host/guest join, audio fetch, and offline reload passed; check account sign-in, installed-PWA behavior, PvP, and longer sessions. Security-event persistence awaits a reward/import RPC design change; no server migration was in this release. |
| Two new game modes, starting with Nightmare preset | Not started | Plan after stabilization; define the second mode before implementation. |
| Phone landscape and keyboard focus pass | Automated `taborder.js` exists; a real-device usability pass is unverified | Test on actual phones and controller/keyboard setups, then fix observed issues only. |
| `dev/PLAYTEST.md` | Missing | Add a short, reusable playtest log when real-device testing begins. |
| Claude audit artifact and phone notification | External audit artifact remained inaccessible; notification status is not verified here | Treat this repository document as the working record. Reconcile the artifact if access returns; do not claim a notification was sent without evidence. |

The handoff's 22-test count, v0.9.2 live claim, future-controller item, and instruction to build v0.9.3 hardening are superseded. Its standing protection of player data, secrets, browser storage keys, and server-checked rewards remains relevant. Its full-suite-after-every-change rule was replaced by the user's later instruction to run only tests relevant to the changed behavior, expanding checks for shared systems or a concrete release risk.

## Next work, in a practical order

1. **Close release verification.** On a physical phone, review the v0.9.3.4 presentation candidate against the saved v0.9.3.3 baseline and record full-screen flags, background readability, movement/stop feel, frame feel, battery/heat if noticeable, cosmetic fit, and audio transitions. Case-opening lag is considered fixed based on Big U’s report; reopen it only on a reproduced regression. Run a live-site smoke of solo, a host/guest co-op session, one PvP session, account sign-in, queued/offline claim behavior, and home-screen/offline launch where available. Use test accounts and avoid irreversible player-data changes. Investigate the measured Locker CPU increase before declaring the phone budget met. Record findings in `dev/PLAYTEST.md`.
2. **Prepare repeatable server tests before server fixes.** Add rolled-back SQL tests for reward claims, duplicates, malformed JSON numbers, rejoin boundaries, imports, and skill purchases/resets. Confirm the current live function definitions and migration chain first. The `schema.sql` snapshot alone is not a complete current restore path. Do not infer that the SQL paths are safe from browser mocks alone.
3. **Fix reward retry and rejoin correctness.** Give queued claims stable IDs and store the original response per player so a retry returns the same result without changing kills, drops, counters, records, cases, shards, or play budget. Validate original JSON number types before coercion. Reproduce or rule out the raid-4/rejoin/raid-5 boss under-credit with a rolled-back integration test, including XL, duplicate boss keys, seasonal Butcher, extra modifier bosses, and losses. Keep old cached clients compatible.
4. **Set the import and identity contracts.** Decide which historical local saves may become account-owned; preserve legitimate recovery and existing player property. Then harden `import_local_save` against arbitrary earned item IDs and edited balances. Bind a guest's skill claim to an account it controls without passing a Supabase access token to the host. These need product decisions and server design before migration, not a quick client-only filter.
5. **Verify the published network/web release.** Complete physical-phone movement and cosmetic checks. A direct host/guest join, audio fetches, and offline reload passed on the published site. Check Open Games, account sign-in, audio playback, installation, PvP, and longer sessions. The current host kick deters the same browser session but is not a server-enforced ban. A security-event log with retention needs a separate RPC design because current SQL exceptions roll back event writes; do that alongside the deferred reward/import work.
6. **Resume feature planning.** Define the two new modes and their reward, UI, matchmaking, and test expectations after the correctness work is under control. The Nightmare preset is only a starting ingredient, not an implemented mode.

For each implementation slice, choose focused browser tests (cosmetics for visual items, combat for weapons, host/multiplayer for network behavior, account and SQL tests for progression), then broaden only when common code or results justify it. Server changes require a reviewable migration, rolled-back test-account evidence, and explicit release approval before application. Do not backfill milestone counters or change existing player balances as part of a routine fix.

## Decisions and claims to settle

- **Local-save import:** what historical items and balances may be credited to an account without server evidence? This affects legitimate offline recovery; decide before changing `import_local_save`.
- **Boss milestone wording:** the original cosmetics prompt says bosses defeated in runs the player was in. Current code increments `sbN` for Boss Rush/Nightmare extra bosses and puts only regular bosses in `bossLog`, which supplies typed milestone counters. Decide whether extra boss defeats should advance the boss-specific ladders. Do not silently change reward rates.
- **Offline claim retention:** `saveClaims()` persists only the last eight queued claims. Define how many offline results must survive reload before changing that limit.
- **Phone movement allowance:** use observed honest movement with class, perk, modifier, sprint, water, storms, and lag before enforcing a speed cap.
- **Turnstile:** remains off until Big U explicitly requests it and supplies the Cloudflare configuration. The September 27 case compensation is closed unless Big U reopens it.

## Release boundaries

Keep the existing PeerJS host simulation, Supabase account/reward authority, Canvas renderer, `palisade.*` storage keys, and stable element IDs. Do not put secrets in the repository or send a guest's access token to a host. A client validation check improves room behavior but cannot make a modified host trustworthy; server progression checks are the authority. Choose the next version number when the actual next scope is settled; do not reuse **v0.9.3.1** for unfinished hardening.
