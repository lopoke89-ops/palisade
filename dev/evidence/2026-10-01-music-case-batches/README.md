# Music and five-case completion report

Implemented October 1, 2026 as local **v0.9.6.2**, protocol **yard-22**, on top of winter-upgrade commit [`526831b`](https://github.com/lopoke89-ops/palisade/commit/526831bad0c4369a5058f9a5812e20413a1e9367). The winter upgrade was pushed first as requested; live GitHub Pages HTML exactly matches that commit (SHA256 `ecfcfa50ab243fa02e9b3d817b454d8fa11d02be359cb1513ce1649f643a870e`). The new music/case build is a local release candidate. Its additive account RPC migration is live.

## Soundtrack

All seven supplied tracks are encoded in AAC 160 kbps and Opus 128 kbps. Original H: files remain intact. [The audio manifest](../../audio/music-manifest.json) records source hashes, exact decoded frame counts, trimmed cue, release hashes, and measured loop boundaries; [audio preparation](../../audio/README.md) lists each assignment and duration.

- Heartbeat continues across every menu page and the Locker, including either case-opening flow.
- Cold plays in preparation and between raids.
- Attitude, Cool, Express repeat one track per raid, derived from the authoritative raid number. A new match begins with Attitude. Settings, pause, visibility, and repeated snapshots do not advance the rotation.
- Everything She Wants takes priority in **Blitzkrieg Rush** Final Blitz and evacuation. Shared Whiteout finale code retains ordinary raid routing.
- Sacrifices takes highest priority when an actual player results screen becomes visible, including wins/losses, PvP, evacuation, and Dead End results. It begins at the original **164-second cue**. The release file is accurately trimmed at that point, so playback and looping use zero through the measured 143.617979-second remainder. Results updates do not restart it. Menu demos do not trigger it; rematches select new-match music.

Both encoded results openings match the original six-second segment at 164 seconds with **zero measured offset**: correlation 0.997845 for AAC and 0.996929 for Opus. See [cue measurements](results-cue.json). Encoder padding is excluded from loop ends. Browser tests decode and play all seven routes in both formats, including forced AAC failure/Opus fallback. Real local WebRTC tests verify host/guest raid music, repeated snapshots, same-finale late joining, and results.

Music remains lazy, with one track in the steady decoded cache and one outgoing source during a short fade. Obsolete loads are aborted and ended sources released. Mute/visibility restore the current track position without advancing the raid rotation. The longest track needs **149,539,840 decoded bytes (142.6 MiB)** at a 48-kHz stereo browser context. Physical-phone memory and Safari playback remain unverified; the existing one-track policy is retained, rather than an asserted byte cap.

`dev/build.py` packages all 14 content-hashed release assets. Old Locker/raid compressed files are removed from source and release output. `palisade-media-2` evicts the obsolete soundtrack cache and retains lazy caching for subsequent updates. The installed-cache test verifies all 14 hashes, old-cache removal, four obsolete-asset 404s, and cached offline audio fetches.

## One and five cases

Every case type has OPEN and OPEN 5. OPEN 5 requires five owned cases. A session uses one intro and **five horizontal CSS reels stacked vertically**, sharing art, motion timing, a center column, and one tick/reveal audio scheduler. Batch reels use 13 tiles each; single reels retain 34. Static 64-pixel art is cached with a 64-entry cap. The intro uses its displayed resolution on small phones. Reels, timers, callbacks, temporary elements, and result elements are released on close.

Rewards commit before animation. Local inventory and its opening receipt share one atomic storage write; local Web Locks serialize supported same-origin operations. Account openings use a persisted UUID and one database transaction. The server locks the locker, checks all five cases, rolls in order through the existing catalog, and stores a durable receipt. Retries return the same results and current inventory. Items first acquired earlier in a batch become duplicates on later rolls. Existing odds, pools, and duplicate values apply.

The summary shows every item, rarity, new/duplicate status, and duplicate shards. Eligible new items offer EQUIP; no automatic equip occurs. Single-case equip preserves collection expansion and focus. One DONE action closes the session. Skip, Escape/controller back, reload, and uncertain responses preserve committed rewards; a saved opening must be reconciled before another can start. Pending journals are separated by account/local owner.

See [batch behavior evidence](case-batches.json), [phone/desktop layouts](case-layout.json), [five-reel preview](case-five-spin.png), and [results preview](case-five-results.png). The layout test covers 320×568, 390×844, 430×932, and 1280×800. All five actual winning-item centers match the marker exactly. Reduced motion and local/cloud reload recovery pass.

## Validation and backend

**17 affected suites passed:** caseperf, case_batches, case_memory, case_layout, cases, locker_collections, reel_music, music_routing, music_network, music_assets, case_batch_migration, restore_schema, controller, csp, rewards_screen, blitz_network, and winter_upgrade. Logs and [verification.json](verification.json) are stored here.

Migration [20261001225643_music_case_batches.sql](../../supabase/migrations/20261001225643_music_case_batches.sql) is applied to `puvjfhwxigxjpsvdwrwf`. Its public wrapper uses invoker security; the private function requires the authenticated user and locks that user's locker. The private receipt table has RLS and no direct client grants. Live read-only permission checks confirm authenticated RPC execution, anonymous database-role denial, and no authenticated direct receipt access.

Fresh isolated Postgres tests verify five results, four duplicate conversions after a forced first acquisition, eight identical retries, insufficient-inventory rejection, request-ID mismatch rejection, rollback after an injected receipt-insertion failure, current inventory on replay, and one-case operation. The refreshed full restore schema also passes. The transport test loses a committed response, reloads, and resumes with the same UUID; database correctness is checked separately against the actual SQL function.

The security advisor reports the existing privileged-function/auth-policy/password notices and informational RLS-without-policy notices for private RPC tables. The new public RPC is invoker-based and the private receipt table denies direct access. Explanations: [database advisor](https://supabase.com/docs/guides/database/database-linter) and [password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection). Unrelated account policy changes were outside this order.

## Case-opening performance

Matched desktop Chrome 154 software Canvas, 390×844 at DPR 3, fixed random seed, music/combat volume zero. Three baseline single-case runs, three candidate single-case runs, and ten sequential candidate five-case runs use the same browser/device settings. The frame collector is installed once per page so repeated runs do not accumulate benchmark callbacks. [Raw baseline](caseperf-baseline-1.json), [single candidate](caseperf-candidate-1.json), [batch candidate](caseperf-candidate-5.json), and [twenty-batch memory evidence](case-memory.json) are included.

The generated [performance summary](performance-summary.json) records median intro/reel CPU, frame distribution, style/layout counts, input-to-next-frame response, peak sampled JS heap, and retained memory. Both quantities preserve the baseline 95th-percentile frame time and respond within one frame while reducing median CPU. Reel measurement reports **zero layout recalculations and zero computed-style reads**; five-row style recalculation counts remain close to single-case counts.

| Measurement | Baseline single (3 runs) | Candidate single (3 runs) | Candidate five (10 runs) |
| --- | ---: | ---: | ---: |
| Median intro CPU, ms/s | 122.7 | 119.8 | 102.0 |
| Median reel CPU, ms/s | 96.4 | 91.2 | 85.7 |
| Highest run frame p95, ms | 16.8 | 16.8 | 16.8 |
| Longest Done-to-next-frame response, ms | 8.4 | 16.6 | 13.6 |
| Maximum residual intro + reel setup CPU, ms | 121.6 | 91.1 | 72.4 |
| Reel style recalculations | 398 | 397–399 | 396–402 |

Isolated 33.3–33.4-ms frames occur in the baseline/candidate intros and some batch reel runs, despite unchanged p95. These desktop software-rendered results do not establish physical-phone frame pacing. The setup window measures the intro remainder after the 2.6-second sample through reel readiness, rather than an isolated tile-construction duration.

After warming the art cache, twenty further batches retain 29 cached art entries and 2,007 DOM nodes. Retained JS heap at batches 10/15/20 is 4,596,340 / 4,610,476 / 4,633,520 bytes: about **37 KB variation**. No reel/result nodes or active case session remain after close. Sampled JS heap excludes decoded audio and some browser-native graphics allocations; it is not total process memory.

Re-run focused checks:

```powershell
powershell -NoProfile -File dev/test/run_targeted.ps1 -Tests "case_batches case_layout case_memory case_batch_migration restore_schema music_routing music_network music_assets cases locker_collections reel_music controller csp"
$env:CHROMIUM='C:/Program Files/Google/Chrome/Application/chrome.exe'
$env:QTY='5'; $env:SAMPLES='10'; $env:REPEAT='1'
powershell -NoProfile -File dev/test/run_targeted.ps1 -Tests "caseperf"
```

For a historical comparison, build commit `526831b` in a separate temporary checkout, preserve its generated `debug.html`, and select that page with `PAGE` and `LABEL=baseline` (QTY 1). Current candidate measurements use QTY 1 or 5 and no PAGE override. The checked-in source importer/cue verifier regenerate music from the original H: files using an installed FFmpeg binary and NumPy for cue comparison.

The candidate is rebuilt and reviewable. Physical-phone heat/battery/audio memory, Safari, and real Internet conditions remain separate release verification. Publishing v0.9.6.2 was not included in the attached implementation work order.
