# PALISADE optimization audit (October 1, 2026)

This covers the whole project after v0.9.3.7. Every finding was measured or read directly this session; nothing here has been implemented without approval. Rankings weigh player impact against effort and risk.

- **Runtime numbers** come from `dev/test/stress.js`: desktop Chromium, software canvas, a 390×844 phone viewport at 3×. They show relative cost, not physical-phone heat.
- **Server numbers** are read-only queries and Supabase advisors on the live project.

## Summary

| # | Finding | Impact | Effort | Risk | Recommendation |
|---|---|---|---|---|---|
| 1 | World-object drawing ("items") is still 45–50% of frame time | High on phones | Medium | Low | Profile the per-character draw path next |
| 2 | ✅ Done (Oct 1): 9.4 MB `palisade inbetween raid music.wav` was published at the site root; also the whole `dev/` folder was public | Medium: deploy size, anyone can download it | Trivial | None | Move it to `dev/audio/` (masters) |
| 3 | ✅ Done (Oct 1): `dev/src/palisade-outdated.html` (314 KB) was dead | Low: repo clarity | Trivial | None | Delete (it's in git history) |
| 4 | `schema.sql` is out of date (e.g. its `claim_match_reward` predates the live one) | High for disaster recovery | Medium | Low | Regenerate a full schema dump from the live project |
| 5 | ✅ Done (Oct 1): test runner and Playwright version mismatch | Medium: every fresh setup fails at first | Trivial | None | Pin Playwright to the installed browser, or document `CHROMIUM=` |
| 6 | 15 SECURITY DEFINER RPCs exposed to `authenticated` (advisor WARN) | Low: intended API design | Medium | Medium | Keep; add a test that each checks `require_user` and bounds its inputs |
| 7 | Leaked-password protection is off in Supabase Auth | Low–medium | Trivial | None | Turn it on in the dashboard |
| 8 | Two unindexed foreign keys and one unused index | Negligible at 43 players | Trivial | Low | Revisit at thousands of rows |
| 9 | Debug hook object (5 KB, one 4.9 KB line) ships in the production build | Low | Low | Low | Build it only into `debug.html` |
| 10 | The deferred reward-retry and import/identity work | High for trust | High | High | Next correctness project (blueprint step 3–4) |

## Runtime (client)

**Frame cost.** Median render per frame, in ms:

| Scene | v0.9.3.5 | v0.9.3.6+ |
|---|---|---|
| Endless raid 20, solo | 5.9 | 5.7 |
| Six players, boss raid | 7.4 | 7.0 |
| Six players, Endless raid 20 | 10.8 | 8.7 |

- v0.9.3.6 cached outlined labels, removing `strokeText` from the hot list.
- The frame cap (Auto/30/60) is the biggest lever. Drawing CPU per second falls about 60% at 30 FPS, and about 60% on 120 Hz phones at the 60 cap.

**What's left in the frame.**
- "Items" (walls, characters, raiders, all depth-sorted) is 4.0 of 8.7 ms in the six-player scene.
- The top CPU entries are `drawImage` (~33%, the cached sprites) and the character painter.
- Next steps, measured one at a time with `stress.js`:
  - Skip depth-sorting items that haven't moved.
  - Cull off-screen walls and raiders before sorting (walls are pushed for all N×N tiles today).
  - Batch wall sprites per row.
  - Check how often `paintWardrobeCharacter` runs outside the worker cache.

**Memory.** Heap stays flat at 4–5 MB over 30 simulated minutes of Endless, and particle and bullet lists stay bounded. No leak was found.

**Startup and size.**
- `index.html` is 545 KB (187 KB gzipped) and loads in one request.
- `peerjs.min.js` (87 KB) loads only when online play is opened.
- Music is cached separately and survives game updates.
- The only obvious waste is item 2. Splitting the script would add requests for little gain at this size.

**Service worker.** It correctly caches the page, fonts, icons and PeerJS, and bumps the cache name on every build. Offline solo was verified in earlier releases; recheck it on a physical iPhone PWA.

## Network

- **Rates:** host snapshots go out 15 times a second on an unreliable channel; one-off events use the reliable channel.
- **Late joiners:** since v0.9.3.5 they also receive live bullets (`start.shots`, and `bu` in full snapshots), capped at 300 bullets.
- **v0.9.3.6** added a stash of up to 12 dropped players per game, which costs nothing on the wire.
- **To measure next:** snapshot bytes per second with six players in an XL Endless raid 20+ (`dev/test/netbench.js`, `netxl.js`), on a real cellular link.

## Server (Supabase, read-only)

- **Scale:** 43 accounts, 158 match results, and every table under 250 KB. No query is slow; the largest recent statements are migrations.
- **Polling:** social state every 15 s in the menus, the lobby list every 6 s on the Multiplayer page, and lobby publishing every 15 s while hosting. That explains the 40k scans of `profiles` and about 13.5k social reads. It's fine now, but cost grows linearly with concurrent players. Consider pausing polls when the tab is hidden and backing off after a few idle minutes.
- **Security advisor:** besides item 6, anonymous sign-ins are enabled by design (guest accounts), so those RLS "anon" warnings are expected.
- **Restore path:** the pre-v0.9.3.6 `claim_match_reward` is saved in `supabase/snapshots/`. A complete, current schema dump is still missing (item 4).

## Code health

- **Layout:** 33 source files, about 613 KB of JavaScript. The style is dense by design (short names, long lines), which keeps the build small but makes review harder.
- **Longest lines:** the debug hook list and several cosmetic-art painters are over 500 characters.
- **Dead code:** `palisade-outdated.html` and the `MOD_PRESETS.nightmare` placeholder, which the future Nightmare game mode will use.
- **Line endings:** the Windows checkout used CRLF while the repo is LF, and GitHub Desktop can produce noisy diffs. Adding `.gitattributes` with `* text=auto eol=lf` is recommended. It needs a one-time renormalize commit, coordinated with Big U.
- **Release discipline:** v0.9.3.5 was briefly pushed from a stale local folder. "Fetch and pull `main` first" is now in the work order.

## Tests

- **Size:** 47 browser and PGlite tests in the full list. The v0.9.3.6 full run passed 44/44 once `lobby` was fixed; its expectation predated collapsed Locker collections.
- **Gaps:**
  - No physical-device run.
  - No test of the installed-PWA offline launch in a real browser.
  - No live-service smoke with a test account; `accounts` and `rewards` use a fake Supabase.
  - SQL tests cover case opening and claims, but not imports, skills or friends.
- **Environment:** the Playwright version in `dev/test` wants a newer browser than the container ships. Tests run with `CHROMIUM=/opt/pw-browsers/chromium-1194/chrome-linux/chrome` (item 5).

## Proposed next-work order (feeds the blueprint)

1. **Physical-phone pass:** heat at 30/60/Auto, touch auto-lock feel, the in-game settings panel, Delgado text fit. Log it in `dev/PLAYTEST.md`.
2. **Quick hygiene (items 2, 3, 5, 7):** one small PR plus one dashboard toggle.
3. **Current schema dump and SQL tests** for imports, skills and friends (item 4).
4. **Reward retry and rejoin idempotency** (stable claim IDs), then the import/identity decisions.
5. **Next frame-cost pass** (item 1), measured with `stress.js`.
6. **Game-mode planning:** define the two new modes.
