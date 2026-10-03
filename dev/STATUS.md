# PALISADE project status

Updated October 1, 2026. This is the current status record for the clone. The older project handoff and v0.9.3 hardening prompt describe a superseded release order.

For a consolidated list of what remains from those documents, see the [current project blueprint](PROJECT_BLUEPRINT_2026-09-29.md).
Big U's latest completed local scope is recorded in the [presentation prompt](plans/backgrounds-and-character-animation-prompt.md). The earlier [cosmetic and hardening prompt](plans/next-cosmetics-and-hardening-prompt.md) remains the record of v0.9.3.2 and its deferred work.

The Claude audit URL still requires sign-in in the available browser session. Big U supplied an exported copy at `D:\downloads\Untitled.md`, which was read on September 29. Its newest Progress entry is v0.9.3, so its release claims are superseded by the verified v0.9.3.3 release below. The external artifact itself was not edited here.

## v0.9.6.3 candidate: frame rate, CPU and network efficiency (on `claude/lucid-curie-491na1`, not published)

From an October 3 audit (Big U approved items 1-4 plus the player-field change). Evidence and before/after numbers: [evidence/2026-10-03-efficiency/README.md](evidence/2026-10-03-efficiency/README.md). Protocol **`yard-23`**: the state packet layout changed, so older copies must reload.

- **Desktop Auto holds 60 FPS.** Auto left desktops uncapped, so 144 and 240 Hz monitors ran the whole game 2.4-4x as often. Touch devices are unchanged (60, or 30 when struggling or on low battery).
- **No per-frame page changes.** The frame loop and HUD re-set 5-7 `hidden` flags every frame even when unchanged; each counted as a page change and forced a style pass. A `hid()` guard (next to `cls()`) removes all of them: style passes on menus drop from 117 to 60 a second (the rest is the stage character's CSS bob).
- **Friends polling only while the menus are in use.** Every 15 s while active; never in a hidden tab; once a minute during a match or after 5 idle minutes (the open Friends panel keeps 15 s); coming back to the tab checks at once. The Open Games list no longer refreshes in a hidden tab. Host room publishing is unchanged (the server expires a silent room after 45 s).
- **Slimmer state packets.** Height is no longer sent (every screen works it out from the same map); player rows put usually-zero fields last and drop trailing zeros; materials, grenades, salvage, kills, deaths, spawn protection and "evacuated" go in a separate block only when they change (repeated for 8 packets because the state channel doesn't resend, every player every 30 packets as a safety net, and all of them after a join). Busy six-player scenes: 9-12% smaller on flat maps, 27-29% on Frostpeak.
- **Server fix found during the audit (migration written, not applied):** live `room_register` still accepted only `yard-21`, so rooms hosted from v0.9.6.1 on (`yard-22`) could not register and friend room invitations failed. `20261003120000_room_register_any_yard_proto.sql` accepts any `yard-N` (the invite answer still refuses mismatched versions). Tested in PGlite (`winter_migration`); **apply only with Big U's approval.**
- **Measured and rejected:** culling off-screen walls and raiders before drawing (skipped 36-57% of tiles, no measurable frame-time change).
- **Tests:** new `poll_backoff`; `fps_mode` expects 60 for desktop Auto; `winter_migration` covers the proto fix.

## v0.9.6.1 published winter upgrade

The [winter upgrade work order](plans/winter-cosmetics-dell-and-dead-end-work-order.md) is implemented in the checkout, with 36 affected suites passing and a complete 311-entry four-angle catalog. Source/build protocol is yard-22. The `20261001214620_winter_models` migration is live; the game changes were pushed as `526831b` and the live HTML was verified against that commit. See [completion and performance evidence](evidence/2026-10-01-winter-upgrade/README.md) and [catalog index](catalog/cosmetics/README.md). The following section records the subsequent published music/case release.

## v0.9.6.2 published music/case release

Seven replacement tracks, stable raid/finale/results routing, and atomic one/five-case openings are implemented. `20261001225643_music_case_batches` is live. Focused gameplay/network/database/asset checks and phone-sized case benchmarks are documented in the [completion report](evidence/2026-10-01-music-case-batches/README.md). Publication was authorized October 1. Commit `358696b` is pushed and GitHub Pages deployed successfully. Live HTML/service-worker hashes, all 14 audio hashes, the production five-case flow, shared menu playback and offline game/audio fetches pass without page errors or CSP violations. [Release verification](evidence/2026-10-01-music-case-batches/release-verification.json) records the checks and deployment.

## Live and local

| Item | Current state |
|---|---|
| Source release | Published **v0.9.6.2**, protocol `yard-22` |
| Release deployment | Music/case release pushed October 1; GitHub Pages run `36941843154` succeeded; live files match commit `358696b` |
| Live protocol | `yard-22` / `palisade-yard-22-`; clients from yard-21 must reload |
| Applied server migrations | Winter models (`20261001214620`) and music/case batches (`20261001225643`) are live; earlier migrations retained |
| GitHub branch | `main` contains [358696b](https://github.com/lopoke89-ops/palisade/commit/358696b543f7aad4147f7f007e222423dfafe6d3) and publication evidence |
| Published build | GitHub Pages **v0.9.6.2**, protocol `yard-22`; committed/live HTML SHA256 `11729dcb28f63f807cf2def31076ad2ec310ee35288a0ecc80dc91a8cbd93a03` |

Controller support shipped in v0.9.2.1. The v0.9.3 cosmetics migration is applied and the live case catalog includes Flags. The two proposed new game modes have not shipped; the Nightmare modifier and a future preset definition do not constitute a separate game mode.

Four commits after the v0.9.3 release changed the case intro and reel source (`98bb522`, `4c8dd3d`, `a49df08`, `566e30e`). The v0.9.3.1 release includes those fixes. Their source was compared with the v0.9.3 release on September 29; see [case animation validation](CASE_PERFORMANCE_2026-09-29.md). The reel avoids repeated style reads and its measured CPU use was lower, but intro readings overlapped and Locker readings were higher in the comparison runs. Further profiling and a real-phone comparison are still required before performance sign-off.

## v0.9.6.0: winter expansion

The [winter/elevation/campaign/invitations work order](plans/winter-elevation-campaign-and-friend-invites-work-order.md) is implemented; publication was authorized October 1. The [release report](evidence/2026-10-01-winter-whiteout/README.md) includes architecture, measured verification, backend grants/advisors and limitations; [BALANCE.md](evidence/2026-10-01-winter-whiteout/BALANCE.md) defines the height, continuity, boss and reward contracts; [CATALOG.md](evidence/2026-10-01-winter-whiteout/CATALOG.md) lists all 42 items.

Frostpeak has standard/XL layouts with summit core, three traversable heights, ramp/stair approaches and terrain-aware combat. Whiteout visits Yard, Riverbend, Quarry and Frostpeak, three raids per chapter, revamped chapter bosses and one five-minute personal evacuation finale. Rime has its own ice armor/reservoir/maul rig, telegraphed rupture and slowing frost dash. New milestones and a 34-item Winter Case provide acquisition paths for the complete 42-item winter collection.

Authenticated Friends invitations support public/private rooms and deliberate leave confirmation, including from an active game's pause menu. The two migrations are live; read-only checks and disposable Postgres tests verify catalog, reward retries and invitation authority. Six real local PeerJS clients, chapter/ramp/finale reconnect, production offline launch, all 73 compact Armory layouts and affected input/combat/network regressions pass. Final desktop software-Canvas stress sample at 390×844: six simulated players, 52 enemies/four bosses, 64 frost fields, 19.1% added median update+render cost. Physical phones and real Internet finale performance remain separate validation.

Production files use protocol `yard-21`, footer v0.9.6.0 and service worker `palisade-dc87756470`. **The isolated release passed 11 publication checks, is pushed as `92d3c16`, and deployed successfully.** Live campaign/Frostpeak starts, eight mobile Armory layouts, exact committed file hashes and the active service-worker cache are verified with no page errors or CSP violations. [Release verification](evidence/2026-10-01-winter-whiteout/release-verification.json) records the actual release hashes and gate results. Preexisting uncommitted cleanup is preserved and excluded.

## v0.9.5.2: special ammo and eight-level Armory

The [ammo and Armory work order](plans/ammo-and-armory-expansion-work-order.md) is implemented. [Validation, balance tables and evidence](evidence/2026-10-01-ammo-armory/README.md) record the finished build and live account migration. Big U authorized publication October 1. Commit `ac0e049` is pushed to `main`, Pages deployed successfully, and the live v0.9.5.2 footer, protocol and service worker are verified.

Release verification also opened the production page in Chrome, confirmed debug hooks are absent, started a Sniper solo game through the actual controls, and checked both Armory tabs at 320×480, 568×320, 390×844 and 844×390. All eight live layouts fit without scrolling and reported no page errors or CSP violations. This UI smoke test blocked account requests to avoid creating test accounts; account/server and local online tests are recorded separately. See `evidence/2026-10-01-ammo-armory/release-verification.json` and the live captures beside it.

Armor Piercing, Incendiary, Explosive and Lightning are offered only in solo/co-op 5-raid, 10-raid, Endless and Blitzkrieg Rush. They cost 150 salvage for an empty slot and 75 to switch; repeated selection is free. Classes have one slot, Sniper has two distinct slots, and leaving Sniper clears slot two. Host validation enforces these rules, phase/distance/life/Lockdown checks and salvage. Ammo, verified ranks, burn and slow are synchronized; a same-match reconnect retains slots and level-8 upgrades. Protocol is `yard-20` because these packet fields are new.

Four account nodes are appended after the original 15, gated by 5/10/15/20 lifetime SP and priced at 1/2/3/4 unspent SP. The applied migration extends the live definitions and purchase gate. Tests use the exact deployed respec body and verify accurate refunds, no repeat refund and preserved lifetime SP. No player rows were rewritten. Read-only live checks and the unchanged security-advisor baseline are saved in the evidence directory.

Levels 5–8 extend Damage, Fire Rate, Range, Armor, Grenades and Delgado. Their final bonus caps are 25% above the previous level-4 bonus caps; the original four tiers retain their values and prices. The Armory shows level out of eight, current-to-next benefit, and each ammo's effect, rank, slot and price.

**October 1 mobile UI follow-up:** Upgrades and Ammo are separate tabs, and Sniper chooses a slot above one four-choice ammo list. The introduction is removed, salvage sits in the header, landscape uses columns, and all action buttons remain at least 44×44 pixels. Both tabs fit without scrolling across 73 layout cases at ten viewport sizes, including 320×480 portrait and 568×320 landscape, equipped slots and maxed upgrades. Purchases, real guest UI buying, controller navigation and CSP pass. See [current captures and measurements](evidence/2026-10-01-ammo-armory/compact-armory/README.md).

The initial full regression run plus focused reruns cover 62 distinct passing tests. The old `v087` row-count expectation was updated and passes. New focused tests cover purchases, combat, real local host/guest runs in all four eligible modes, real reconnect, forged packets, PvP rejection, server gates/refunds and a six-player/49-enemy stress scene. In the PC phone-sized software-rendered sample, simulation median/p90 remained 0.2/0.4 ms and rendering median changed from 3.9 to 4.2 ms. Physical-device performance and longer player balance sessions are follow-up validation; the local tests do not measure production network latency.

## v0.9.5.1: Sahur hats and Open Games visibility

The work order is [plans/ttts-hats-and-open-games-prompt.md](plans/ttts-hats-and-open-games-prompt.md); measurements, contact sheets and focused test results are in [evidence/2026-09-30-sahur-open-games/](evidence/2026-09-30-sahur-open-games/). No protocol or server change was needed.

Sahur accepts Crown, Top Hat, Cyber Visor, Neon Headband, Police Cap, Halo, Witch Hat and Devil Horns. Its face previously occupied an exclusive painter branch, so simply allowing the hats would still hide them. The painter now keeps the face and renders permitted headgear in its existing cached frame, with a Sahur-only lift to the log crown, a brow-level visor/headband and extra thumbnail margin. Class Issue and other special-skin restrictions remain as before. The network cosmetic string and protocol are unchanged.

The Open Games list was present and refreshing, but a mocked valid row began below the clipped control column at all four audit sizes (zero visible pixels until scrolling). The existing list now precedes the host form; on a portrait phone the controls precede the character stage. A server-unavailable message no longer describes the list as empty. The existing publish, protocol filter and join-disable rules are unchanged.

## v0.9.5.0: Menu overhaul

Big U asked for a full look at every menu page on desktop and phones (portrait and landscape) before changes, then: keep the character centrepiece, one PLAY button with the setup behind it, and a light touch on the Locker. Evidence: `evidence/v0.9.5.0/` (contact sheets at desktop, phone portrait and phone landscape). Review tool: `test/menu_audit.js` (every page at 1440×900, 1280×720, 390×844 and 844×390, with layout measurements). No protocol change (`yard-19`), no server migration.

**PLAY.** The Solo page is now PLAY: the match as four tappable lines (MAP, LENGTH, JOB, MODIFIERS) and one PLAY button. Each line opens the **setup sheet** on its tab (map, rules, job, modifiers). The same sheet serves hosting a room and the room itself (host only), so there is one place to change a match. On desktop the right column shows the new mode (TRY IT), cases ready to open, the next unlock with its progress bar, and skill points (`19c-home.js`).

**MULTIPLAYER and the room.** MULTIPLAYER is two cards: JOIN A CREW (code, JOIN) and HOST A ROOM (co-op, Base Battle, Free-for-all, the same four lines, HOST), then open games. The room puts the code, share link and START first, then the host's lines (read-only for guests), job, crew and chat.

**Nav.** PLAY, MULTIPLAYER, LOCKER, SKILLS, CLASSES, SETTINGS with icons; waiting cases and skill points are badges (the labels no longer change). Phones in portrait get a bottom tab bar with PLAY pinned above it; landscape phones get a slim top bar and a compact 2×2 of lines with PLAY under it.

**Locker (light touch).** Cases you hold come first; empty cases fold to one line with BUY. Milestones are one strip per ladder with an "n / 5 unlocked" count (swipe on a phone), about half the length.

**Settings.** Cards flow into columns without gaps; bigger slider thumbs.

**Tests.** Tests that clicked the moved controls go through the setup sheet. `run_all.sh` now also fails a test that exits non-zero: `v087` had been passing on its printed output since v0.9.1 while one check failed (the end-screen wording changed then; the check now matches it). `blitz_mode` keeps Delgado away while checking the downed evacuation (he could revive you at random); `blitz_network` waits for the guest HUD label to redraw.

## v0.9.4.0: Blitzkrieg Rush

Work order: [plans/blitzkrieg-rush-work-order.md](plans/blitzkrieg-rush-work-order.md). Evidence: `evidence/v0.9.4.0/`. Protocol **`yard-19`** (new bosses, shots, the Final Blitz clock and the evacuation are in the packets; older copies can't join).

**The mode.** A new length, BLITZKRIEG, on the Solo and Multiplayer pages (co-op, every map and size).
- 15 raids, each a notch harder than 10-raid mode (`waveEff`, raider health +8.5% a raid).
- Raids 5 and 10 bring the map's bosses as their Blitzkrieg variants (XL: two).
- **Raid 15 is the Final Blitz:** a 5:00 clock with a Blitzkrieg boss every 30 s, cycling through all five (10 in all), at most **4 alive** (the rest wait their turn). Final Blitz bosses have 85% of a normal boss's health. Raiders keep coming in small groups. The boss bars switch to slim rows when 3 or 4 are up (portrait), side by side in landscape.
- **The evacuation (the last 60 s):** a green 3-tile ring opens a good run from the core, clear of rock, water and nodes (`evacSpot`, the same on every screen). An off-screen arrow points to it.
  - Stand in it for **3 s**, on your feet, to get out. Leaving resets the count. You then watch your crew from above.
  - Downed players don't respawn during the evacuation: a teammate (or Delgado) has to pick them up in time.
  - The core no longer decides the result once the evacuation starts. A core loss before it is a normal squad loss.
  - At 0:00, anyone still on the field is **left behind**: they lose and keep half their cases and shards (odd counts round up first, `ceil(n/2)`). Raids, boss kills, skill points and milestones are never halved. Squadmates who made it still win.
  - Bosses still alive at 0:00 retreat and don't count. If everyone is out, or nobody is left standing to revive the rest, it ends early.
  - The game-over screen is personal (EVACUATED · VICTORY or LEFT BEHIND · HALF REWARDS) with who made it out.
- **The five Blitzkrieg bosses** (their own names, the base boss's rig, 2 Blitzkrieg Cases each):
  - **The Harbinger** (Ferryman): 3 missiles in a high arc (4 below half health), each showing its landing ring for its whole ~1.6 s flight. On maps without a river he fires from a fixed spot at the edge. Still puts boarding crews ashore.
  - **The Blue Butcher**: a teal lane, then a glowing arc that **breaks every wood and brick wall** it passes, hurts everyone it crosses once, and stops at metal after a heavy hit. Its blue dust is gone in about 0.5 s. The charge still happens, at half the rate.
  - **The Arsonist** (Demolisher): an aim line with four rings, then a chain of four napalm bottles. Each patch burns **10 s**; napalm burns brick at regular fire's rate and **metal at twice it** (regular fire doesn't burn metal at all).
  - **The Tempest** (Stormcaller): **the Stormcaller's shot, exactly, twice**, side by side. Both on you is double.
  - **The Bulldozer** (Foreman): no digging. A lane, then a charge faster than the Butcher's. Anything solid stops him; a wall takes a heavy hit (wood and brick break) and he is **dazed 3 s**.
- **Modifiers:** Blitzkrieg Rush has its own list. Kept: No Patch-Ups, On Your Own, Firestorm, Adrenaline, Last Stand, Elite Raid, Weather, Nightmare (no surprise bosses here), Berserk. Removed: Boss Rush. New: Hot LZ (+15%: opens at 0:45, ring a third smaller), Double Time (+15%: every 20 s, 15 bosses), Artillery Barrage (+10%: marked shells during the evacuation), Lockdown (+10%: the armory is shut for the build before raid 15 — the armory only opens between raids, so it can't close "during" the Final Blitz — and Delgado stops fixing walls in it), Scorched Earth (+10%: napalm 15 s, the arc's dust burns, twin beams scorch the ground).

**Rewards.**
- Every Blitzkrieg boss (raids 5/10 and the Final Blitz) pays everyone **2 Blitzkrieg Cases**. Final Blitz bosses also pay 15-30 shards and a skill point each. Making the evacuation pays 1 more Blitzkrieg Case and 25 shards (approved by Big U). A 15-raid win's 2 Supply Cases apply to evacuees.
- **BLITZKRIEG RUSH ladder** (Locker → Milestones): Blitzkrieg bosses killed in the mode, credited to everyone in the match: 10 Devil Horns (Rare), 25 Blue Arc tracer (Epic), 50 Blue Butcher skin (Epic), 75 Hell Portal kill effect (Legendary), 100 Demon skin (Gold: its own body with horns, folded wings, tail, claws, ember cracks, burning eyes and an ember aura; it takes no other headgear). Each Blitzkrieg boss also counts for its base boss's ladder.
- **Blitzkrieg Case** (14 shards): tracers Brimstone, Teal Wake, Hellfire Chain, Infernal Sigil; kill effects Cinder Burst, Teal Slash, Brand of Ash, Demon Claw; backgrounds Scorched Front (Epic, still) and **Hellgate** (Gold, animated: a gate with a turning hellfire vortex; every 6 s the Blue Butcher's arc cuts a teal rift across the sky that seals again; a boss shows in the fire). Hellgate's still parts are one cached layer; each frame draws three rotated vortex sprites, one glow, the arc and about 40 embers.
- **Server:** migration `20260930141401_palisade_v0940_blitz` (**applied September 30 with Big U's approval**; verified: function bodies, catalog 2 has 15 items, the case costs 14, `open_case_v094` signed-in only, anon denied everywhere; advisors show only the known warnings, no new ones). It adds `match_results.fb_n`/`evac`, `private.blitz_base`, the Blitzkrieg modifier prices, the case and its 15 items (catalog 2, opened by the new `open_case_v094`), and mode `blitz` in `claim_match_reward` (built from the live v0.9.3.8 text). Older clients and other modes are unchanged. The new client opens cases through `open_case_v094`, so **the migration must be live before this build is**.

**Tests:** the full list passes (58/58, including 4 older tests updated for the new ladder and case call, and a fix for a swallowed line that broke Boss Rush and Nightmare surprise bosses). New ones: `blitz_mode` (setup, the 30 s beat, the cap of 4, evac timing and ring, extract/reset, left behind, core rules, downed + revive, Double Time and Hot LZ, the evac spot on every map and size, the menu), `blitz_bosses` (one check per attack), `blitz_network` (host/guest parity, per-player results, the rejoin stash keeps "out", guest rewards), `blitz_milestones` (ladder, half rewards and rounding, caps, shared credit, modifier list, Lockdown, horns on the Demon), `blitz_reward_migration` (PGlite: evac, left behind, rounding, caps, repeat claims, other modes unchanged, modifier prices, catalog, grants). Contact sheets: `blitz_sheet.js` (art approved by Big U).

**Not done / to check on a phone:** raiders don't re-target the evac site during the evacuation (bosses already go for players); performance of a six-player Final Blitz still needs a `stress.js` run and a phone heat check.

## Quick cleanup (October 1, no game change)

- **Site exposure:** GitHub Pages was publishing the whole repository, so `dev/` (source, tests, status notes, backups, compensation scripts) and a 9.4 MB `.wav` master were downloadable from the live site. The new `_config.yml` excludes `dev/` and `README.md` from Pages; the game at the root is unchanged. This also stops Pages rendering the dev notes, which is what broke the v0.9.3.4 deploy.
- **Music master:** `palisade inbetween raid music.wav` moved to `dev/audio/masters/` (kept in the repo, no longer published).
- **Dead code:** deleted `dev/src/palisade-outdated.html` (314 KB; still in git history).
- **Test runner:** `run_all.sh`, which `run_targeted.sh` also uses, falls back to an installed Chromium when Playwright's own browser build is missing, so tests run without setting `CHROMIUM`.
- **Still for Big U:** turn on leaked-password protection in the Supabase dashboard (Authentication → Passwords).

## v0.9.3.10: hat fixes (Big U's review)

- **Boonie and Witch hat gap.** Painting the head cyan showed the "gap" was the face showing through the front of the brim. The canvas painter orders each flat face by its average depth, and a wide brim's average is the head's centre, so the face was painted over the brim's front. Both brims are now the outlined disk plus 12 unoutlined ring slices, starting at the crown or cone edge, that sort by their own position (`brim()` in the character painter).
  - The Witch band and buckle were raised to rest on the brim (they sat inside it).
  - The Boonie crown and band are slightly wider to cover the head's corners.
  - Evidence: `gap_check_before.png` and `gap_check_after.png`.
- **Bone-Button Wrap.** The three small bone buttons read as blobs. There is now one large flat cartoon bone (straight shaft, two round knobs at each end, outlined) across the front of the wrap. Evidence: `bone_wrap_final.png` and `bone_wrap_final_gamesize.png`.
- **Crescent Skull Seal.** The skull is about 25% larger (bigger eye sockets, nose and jaw), and the gold crescent is enlarged to frame it.
- **Checks:** `headgear_fit`, `cosmetics_expansion`, `wardrobe3d`, `locker_fit`, `presentation_posefit`, `cosmetic_network`, `cosmetics`, `flagcase` and `csp` all pass. No server or protocol change.

## v0.9.3.9: skill points for cases, landscape HUD, tips toggle, headgear polish

Work order: [plans/v0.9.3.9-work-order.md](plans/v0.9.3.9-work-order.md). Evidence: `evidence/v0.9.3.9/`.

**1. 3 skill points → 1 Supply Case** (no cap, per Big U).
- *Where:* a new button in the Locker's Supply Case panel shows your points. It works on two taps: the first arms it for 3 s, the second spends.
- *When it's off:* it is disabled with a reason below 3 points; offline, the points stay and a message explains.
- *Accounts:* use the new RPC `buy_case_sp` (migration `20260930084544_palisade_v0939_sp_cases`, **applied September 30 with Big U's approval**; signed-in players only, anon denied). It spends only unspent `sp`, and `sp_total` is unchanged. The live `skill_respec` refunds `skill_spent(skills)`, the tree's own costs, so points traded for cases can never come back through a reset.
- *No-account players:* they get the same trade (Big U). They previously earned no skill points at all, so their runs now earn them by the server's rule: 1 per 5 raids held, 1 per boss, including in-between bosses. The skill tree itself stays account-only.
- *Tests:* `sp_cases_migration` (PGlite: success, no cap, stale rev, fewer than 3 refused while tree points are untouched, respec refunds only the tree, other accounts, banned, signed out, anon denied) and `sp_cases` (account two-tap, repeat, disabled, offline; no-account earning, trade, reload).

**2. Landscape HUD** (phones in landscape only; portrait and desktop unchanged).
- *Boss bars:* health is one thin strip across the top centre, with two XL bosses side by side, instead of stacked 32 px cards.
- *Team bars:* YOU, crewmates, DELGADO and CORE sit compact in the bottom-left corner and ignore touches. The raid panel stays top-right, and the top-left is clear.
- *Test:* `hud_layout` at 844×390, 932×430, 390×844 and 1280×800 with 6 players and two bosses checks placement and no overlap with the kit or raid panel.
- *Phone check still needed:* the bars now share the bottom-left with the floating move stick, which draws underneath them.

**3. Show tips during games.** A Settings → Screen toggle (also in the in-game settings panel), on by default, saved and included in export/import. Off hides the how-to tips immediately and in later games. Toasts (boss arrivals, IS BACK, rewards) always show. Test: `tips_toggle`.

**4. Headgear.**
- *Rebuilt:* the six Halloween Case pieces are now full headwear in the style of the Top Hat, Witch and Pumpkin King, with volume, trim, shading steps and a clear front motif:
  - Gravestone Cap: a slate cap with a stitched band and visor, and a headstone crest with cross and moss.
  - Pumpkin Stem Band: a ribbed rind band with a curled stem, leaves and a tendril.
  - Bat-Notch Circlet: a pewter circlet with a notched-wing bat (glowing eyes) and violet studs.
  - Bone-Button Wrap: two folded crimson layers, a back knot with trailing ends, and three bone buttons.
  - Cobweb Brow Pin: a tilted lace pillbox, a cobweb veil over the brow, and a spider brooch.
  - Crescent Skull Seal: a black-violet diadem with an ivory skull before a glowing gold crescent, and temple gems.
- *Fit pass on all hats:* the Neon Helmet stripe now follows the helmet's curve (it stuck out at side angles), and the Arcade Cap badge is seated on the crown (it floated).
- *Tests:* `headgear_fit` checks every hat's pixels stay inside a head window at 8 angles × 3 walk phases. It passes for all hats, and records per-hat area for review. `cosmetics_expansion` now caps the Halloween pieces at the height of our tallest existing hats, replacing the old "compact" limit.
- *Evidence:* before/after sheets are `headgear_before_*.png` and `headgear_after_*.png`.

Version footer v0.9.3.9; protocol unchanged.

## v0.9.3.8: every boss kill counts toward milestones

Big U's rule: every boss kill counts toward boss milestones, for everyone in the match, not just whoever landed the last hit.
- **Regular bosses** (raids 5, 10, 15…, and XL partners) already credited everyone in the match through the shared boss log. That is unchanged.
- **In-between bosses** (Boss Rush, Nightmare surprise, the Nightmare + Boss Rush second boss) paid shards and a skill point but no milestone credit, because the game only kept a count. The host now records which boss each one was (`sbLog`) and sends it to guests in snapshots (`sl`). Each player's claim names the in-between bosses killed while they were in the game (`sb_keys`), whoever shot them.
- **Server:** migration `20260930075446_palisade_v0938_all_boss_milestones` (applied September 30) adds +1 to the matching `boss_*` counter for each *paid* in-between boss. It follows the existing paid cap, not the claimed list. Older clients send no `sb_keys` and are unchanged. The live function matches the file (md5 `a98b0562…`) and grants are unchanged.
- **No-account players** get the same rule in the browser locker.
- **Earlier kills: estimated backfill, approved by Big U and applied on September 30** (`supabase/compensation/2026-10-01_v0938_milestone_backfill.sql`, keyed so it can't re-apply). It credits 154 past in-between kills, each pre-migration claim's paid count: Boss Rush raids matched to the map's fixed rotation, and Nightmare surprises spread over the map's three bosses. Verified on the live lockers:

  | Player | Before (Butcher / Demolisher / Ferryman / Foreman / Stormcaller) | After |
  |---|---|---|
  | lopoke89 | 17/9/13/3/13 | 38/22/26/6/36 |
  | kappinkirk | 13/6/13/3/12 | 26/10/22/3/25 |
  | meezy2greezy | 7/2/5/0/6 | 14/4/10/0/12 |
  | ethn | 2/2/1/0/1 | 6/8/2/3/7 |
  | af519126 | 2/1/0/0/0 | 2/2/0/0/1 |

  Unlocked by the backfill: lopoke89 gained the Butcher, Ferryman and Stormcaller skins; kappinkirk gained Butcher and Stormcaller. Each player got one mailbox note.
- **Tests:** `boss_milestones` (a guest who never fired gets both a regular and a Boss Rush boss in the claim; solo local counter +1) and `rejoin_migration` (milestones for regular and in-between bosses; older client unchanged; milestones follow the paid count; re-apply).
- **Test fix:** `modifiers` measured Adrenaline speed against wall-clock time and was flaky (a slow first frame shortened the walk). It now measures against game time and gives an exact 1.20×.

Version footer v0.9.3.8. Protocol unchanged: `sl` is an extra snapshot field that older clients ignore.

## v0.9.3.7: touch auto-lock, in-game settings, Nightmare + Boss Rush

**1. Touch auto-lock.** On a touch screen (not mouse or controller, not PvP), a grenade or rocket locks onto the nearest raider at least 6 tiles away with nothing solid in between. That rules out walls (including your own adjacent wall), the stake, rock and closed nodes. Grenades lock within 8 tiles (6.5 throw plus blast), rockets within 12. With no valid target, aim is manual as before. Gold corner brackets mark the target. A guest's locked throw reaches the host as an ordinary target point, so host validation is unchanged. Test: `touch_lock` (ignores a raider at 3 tiles and one behind a wall; grenade and rocket both head at the clear raider; mouse is never assisted; guest path).

**2. In-game settings.** SETTINGS from the pause menu now opens an overlay over the game instead of the main menu. The main menu had let a player start a match or host a lobby mid-run. The same setting cards move into the overlay and back, so each control keeps one id and handler. Save Backup stays on the menu page. Pause/Escape or BACK returns to the pause menu; solo stays paused; online, the raid keeps going. As defense in depth, start, host and join are refused during a live run. Test: `ingame_settings` (phone and desktop, keyboard and button paths, deep-link start refused, online host time advances).

**3. Nightmare + Boss Rush synergy.** With both on, each Boss Rush boss raid also rolls 1 in 12 for a second in-between boss. It is a different boss where the map has more than one, announced as "NIGHTMARE · SECOND BOSS". Odd raids keep Nightmare's normal surprise roll; regular boss raids and either modifier alone are unchanged.
- *Rewards:* it pays like any in-between boss (15-30 shards) and, like them, stays out of boss milestones. The live server cap already counts every non-5th raid when Nightmare is on, so no migration was needed (checked in `rejoin_migration`: four in-between bosses in five raids are all paid). **Big U: say if the second boss should pay differently or count toward milestones.**
- Test: `mod_synergy` (8.3% over 24,000 rolls, always a different boss, never with one modifier, odd or regular raids; a forced roll spawns both, announces, and pays 2).

Version footer v0.9.3.7; protocol unchanged (`yard-18`).

The whole-project audit is in [OPTIMIZATION_AUDIT_2026-10-01.md](OPTIMIZATION_AUDIT_2026-10-01.md).

## v0.9.3.6: rejoin progress, frame rate, Delgado

**1. Disconnect and rejoin (audit of the 15 most recent games, September 30).**
- *What already worked:* a clean leave or disconnect sends an early-leave claim, and the v0.9.2 server rule pays only raids the player was present for, never twice.
- *Loss 1, client:* a reload, crash or killed app sent nothing, so the raids before the drop were lost. The client now saves a run draft every 3 s and on backgrounding, and sends it as an early-leave claim on the next start. Accounts use the normal claim queue; no-account players are paid into the browser locker. Test: `rejoin_drop`.
- *Loss 2, host:* a returning player started with a fresh armory. The host now keeps a dropped player's armory, salvage and kills for the game, keyed by the tab's room session, and restores them on rejoin ("IS BACK"). Test: `rejoin_drop`.
- *Loss 3, server:* `claim_match_reward` capped bosses per claim from the previous claim's raid + 1, so a boss (or Boss Rush/Nightmare in-between boss) on the first raid after a rejoin was paid to nobody. Migration `20260930071534_palisade_v0936_rejoin_bosses.sql` caps bosses over the player's whole stay minus earlier claims, and records `boss_n`. The pre-change live function is saved in `supabase/snapshots/`. Test: `rejoin_migration` runs the same claims through the live function (bug reproduced) and the migration (fixed; uninterrupted games unchanged; no double pay; old-row fallback; re-apply). **Applied live on September 30 with Big U's approval** as `20260930071534`. The function contains the fix, the `boss_n` column exists, grants are unchanged (authenticated, postgres, service_role), and the security advisor shows no new finding.
- *Affected players found:* the table below. The kappinkirk cases match a hard drop: the claim starts mid-game with no earlier claim, and in `mulw1qg2` their previous FFA with the same partner ended three minutes before the run started. Please confirm with the player if possible. Supply case counts can differ by ±1 because teammates' case progress carries over differently.

| Player | Game | What was lost | Proposed grant |
|---|---|---|---|
| kappinkirk | `munif0e3` Endless XL, Riverbend, 30 raids | raids 1-14: 4 bosses (2 Ferryman, 2 Butcher), 6 Boss Rush bosses | 10 Supply, 4 Halloween, 138 shards, 13 skill points; raids/map/class +14; boss_ferryman +2, boss_butcher +2 |
| kappinkirk | `mulw1qg2` 10-raid XL, Riverbend | raids 1-6: 2 Ferryman, 3 in-between bosses | 3 Supply, 2 Halloween, 69 shards, 6 skill points; raids/map/class +6; boss_ferryman +2 |
| meezy2greezy | `mulv3e8h` 10-raid XL, The Yard | raid 7 (21 s disconnect); armory reset | 1 Supply; raids/map/class +1 |

**Big U approved kappinkirk's two grants only; meezy2greezy was not compensated.** The script `supabase/compensation/2026-10-01_v0936_rejoin.sql` was applied on September 30. Verified before and after on the live locker: Supply 0 → 13, Halloween 0 → 6, shards 6 → 213, skill points 58 → 77 (total 124 → 143); raids 430 → 450; Riverbend and soldier raids +20; Ferryman 9 → 13; Butcher 11 → 13; player_stats raids 416 → 436. Two mailbox notes were sent. The grant is keyed, so re-running it pays nothing.

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
