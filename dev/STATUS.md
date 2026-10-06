# PALISADE project status

Updated October 6, 2026. This is the current status record for the clone. The older project handoff and v0.9.3 hardening prompt describe a superseded release order.

For a consolidated list of what remains from those documents, see the [current project blueprint](PROJECT_BLUEPRINT_2026-09-29.md).
Big U's latest completed local scope is recorded in the [presentation prompt](plans/backgrounds-and-character-animation-prompt.md). The earlier [cosmetic and hardening prompt](plans/next-cosmetics-and-hardening-prompt.md) remains the record of v0.9.3.2 and its deferred work.

The Claude audit URL still requires sign-in in the available browser session. Big U supplied an exported copy at `D:\downloads\Untitled.md`, which was read on September 29. Its newest Progress entry is v0.9.3, so its release claims are superseded by the verified v0.9.3.3 release below. The external artifact itself was not edited here.

## v0.10.3: craps, baccarat, slots, Plinko, and a result review for every game (deployed October 6)

Built from [the casino expansion work order](plans/casino-expansion-and-result-review-work-order.md). Rules, paytables and exact math are in [casino-games-v0103-rules-and-math.md](plans/casino-games-v0103-rules-and-math.md); the order of the live steps, compatibility and rollback are in [v0.10.3-deploy-and-rollback.md](plans/v0.10.3-deploy-and-rollback.md).

- **Deployed October 6, with Big U's go-ahead** (record in the deploy plan):
  - Database (03:00 UTC): the migration went in two parts. The MCP tool times out on statements needing confirmation (DROP, DELETE), so Big U ran those in the SQL editor.
  - Backup: schema `backup_20261006` holds lockers, profiles and the casino tables as they were before the migration. Owner-only.
  - Function `tables` version 9 (03:17 UTC), byte-identical to the repo.
  - Site: `main` at `29ad4c3` (pushed 03:20 UTC); live at 03:22 UTC (Pages run 84).
- **Relabelled v0.10.3 the same day, at Big U's request.** It first went out labelled v0.11.0; the commits up to `f97149f` still say so.
  - Renamed to match: the footer, the comments, the migration file (`20261006200000_v0103_casino_games.sql`, with its history row renamed), the plans, and `evidence/v0.10.3/`.
  - Nothing about the games changed.
- **Fixed after the deploy: the Plinko ball froze mid-drop.**
  - The board's animation was tied to the view that drew it. The table's once-a-second poll brings a new view, and the board's HTML doesn't change mid-drop, so the canvas wasn't redrawn. The ball stopped within a second, then jumped to its pocket when the result showed.
  - It now draws from the latest view.
  - `casino_games_ui` tracks the ball on the canvas through the drop. It reproduced the freeze before the fix (stuck at the same height from 0.9 s to 2.9 s) and passes after it.

- **New games (server-run, whole shards, provably fair):**
  - **Baccarat:** 8-deck mini-baccarat from a persistent shoe. Banker bets go in 20s (pays 19:20), Tie 8:1. Each hand's cards check against fingerprints fixed when the shoe starts; the seed and the whole shoe come out when it retires.
  - **Craps:** the full first-release bet set, with persistent bets and working toggles, 3-4-5x odds, a shooter and the dealer. Bets that must stay when you leave are rolled out by the dealer.
  - **16 playable slot cabinets:** PALISADE RUN, returning 96.025% exactly.
  - **One Plinko board:** returns 96.006% exactly.
- **Result review, every game:**
  - The server holds the result from the final reveal: 8 s for cards, 6 s for dice and roulette, 3 s for slots and Plinko. Nothing (READY included) skips it. Blackjack no longer clears in the same request (`PAUSE_MS` was 0).
  - The receipt shows WIN / LOSS / PUSH / PARTIAL RESULT in words, BET / RETURNED / NET, the itemized bets (commission, side bet, insurance), what decided it ("Your 13 lost to the dealer's 17", Hold'em pots with the five cards, uncontested said plainly), and balance / table stack / on the felt separately.
  - LAST RESULT shows the receipt again after the next round opens, after you stand up, and after you come back.
- **Money safety:**
  - Every money move carries an operation id, saved in the same transaction (`casino_ops`). A repeat or a retry after a lost answer returns the first result; the same id with a changed request is refused.
  - One seat per account is enforced inside the transaction (`casino_seats`).
  - Stations (`room, game, station`) keep sixteen cabinets apart.
  - The books cover the new games.
- **Floor:**
  - Craps by the cashier and baccarat mid-floor (dealers Duke and Lena); Plinko on the east side; every slot cabinet playable.
  - Seat codes come from one registry: v0.10.0 codes unchanged, craps 41-46, baccarat 51-56, machines 101-117.
  - Protocol `yard-29`.
  - Fixed on the way: the host's input check capped seat codes at 99, which would have dropped every message from a guest at a machine.
- **Tests:**
  - New: `casino_games_engine`, `casino_server`, `casino_games_ui`.
  - Extended: `tables_ui` (review receipts), `casino_map` (every seat and machine reachable; registry codes; a guest claiming a machine), `restore_schema` (the v0.10.3 casino restores).
  - `schema.sql` regenerated through v0.10.3 with `refresh-restore.py` (it had stopped at October 1).
  - Regression, all passing: `@tables @casino @music @net csp restore_schema @smoke` (40/40), plus `accounts friends menu_audit index_page`.
  - The two baseline failures from `ca90257` were stale test expectations, now fixed: `v090` looped over the casino map (no stake by design since v0.10.0), and `controller` expected the guest input fields from before the v0.10.0 `st` field.
  - The full default suite was not run.
- **Performance:** same machine (Xeon 2.1 GHz x4, headless Chromium, software rendering), `casino_perf.js`.

  | Scene | v0.10.1 | v0.10.3 |
  |---|---|---|
  | Frame time, median / p95 | 16.7 / 16.7-16.8 ms in every scene (the 60 fps cap) | the same |
  | JS heap | 8.4-9.5 MB | 8.3-10.2 MB |
  | Requests, standing | 0/min | 0/min |
  | Requests, seated at a table | 60/min | 60/min |
  | Requests, slots or Plinko played non-stop | — | about 72/min |

  This container can't show differences under the 60 fps cap; a physical phone check is still to do before claiming phone performance.
- **Evidence:** `evidence/v0.10.3/` (screenshots at 1366x820, 390x844 and 844x390; perf runs; test outputs).
- **Known limits:**
  - The unattended craps roll-out runs on the existing request-triggered sweep (any casino lobby request; up to 60 rolls a batch), not a scheduler.
  - Other players' slot cabinets show a busy glow, not their reels.
  - Tested with three players across stations (host and two phones), not six.
  - Gamepad navigation of the new sheets relies on the existing button navigation (no new gamepad test).
  - The PUBLIC CASINOS list, more machine themes and Plinko risk settings remain follow-ups.

## v0.10.1: the casino's own music

- **The casino playlist:** Big U's 11 ambience tracks (the `casino music` folder) play only in the casino, which no longer borrows the menu track.
  - True shuffle: every track once in a random order, then a fresh shuffle; never the same track twice in a row.
  - After the first track, each one crossfades into the next over the last 5 seconds (equal power).
  - At most two tracks decoded (the next one loads in the current one's last minute); mute and a hidden tab resume the same track; leaving and coming back moves on.
- **Assets:** AAC 160k + Opus 128k like the rest of the soundtrack (55 MB + 41 MB); the 320 kbps masters stay in `casino music/`, not published. See [audio/README.md](audio/README.md).
- **Test:** `casino_music` (tags music, casino), both formats.

## v0.10.0: THE PALISADE FALLS CASINO

The work order is [casino-map-and-roulette-work-order.md](plans/casino-map-and-roulette-work-order.md) (decisions C1-C12).
- **The casino:**
  - a 16x16 map in the yard's style: blackjack, poker and roulette tables, slot banks (decoration), a bar, a cashier cage, chandeliers, neon and a marquee;
  - dealers Vinnie, Rosa and Marco, plus a barkeep, built as looks so they can become a case collection later;
  - no raiders, no building, no weapons; names over heads (no health bars).
- **Walk-only (C2):**
  - TABLES is now the front door: your balance, ENTER THE CASINO, JOIN BY CODE, HAND HISTORY and HOUSE RULES;
  - you sit by walking up to a free seat and pressing E (SIT on touch);
  - the server refuses the old open/join requests;
  - one table of each game per casino room, for up to 6 players (C1); the host's room is the casino, and alone you get a room of your own;
  - the seat travels on the network (yard-28); the host only gives a guest a free seat right next to them, and puts them on it.
- **Roulette:**
  - American double zero (C3), always no limit (C6), 60 s betting (C7), playable alone (C4);
  - the full board (C5): every one of the 161 spots, with chips, CLEAR, REBET, DOUBLE, SPIN and the last spins;
  - the wheel on the table spins and lands on the number.
- **Fair play:**
  - the server commits to its seed before players' seeds lock, and players can set their own seed;
  - every Blackjack shoe and roulette spin reruns from what's revealed;
  - Hold'em has a fingerprint per card, so you can check the cards you saw without anyone seeing a folded hand (the seed and the whole deck show after 24 hours);
  - HAND HISTORY's CHECK reruns it all in the browser;
  - the daily books check: for every closed table, shards in - shards out = what the house kept + bot.
- **Server:**
  - the `tables` edge function: ops sit, peek, history, seed, rlbets and rlready;
  - migrations `20261005200000_v0100_casino.sql` (roulette, rooms, history indexes, `casino_books`) and `20261005200100_v0100_casino_rooms.sql` (`casino` in the lobby length check and `room_register`);
  - both were tested twice-applied in PGlite;
  - the second contains a `delete` (the live room_register's close branch), so Big U runs it in the SQL editor.
- **Tests:**
  - new: `roulette_engine`, `fair_play`, `casino_map`;
  - rewritten: `tables_ui` (the casino flow at three sizes, with the history check for all three games);
  - updated: `tables_server`, `blackout_network` and `campaign_network` (yard-28);
  - `campaign_network` timed out once and passed unchanged on the re-run.
- **Evidence:** `dev/evidence/v0.10.0/`.
- **Fixed before release:**
  - roulette taps could be lost or wiped when a poll answered mid-tap; bets now go down on release and the board only rebuilds when it changed;
  - a full table now refuses a seat (the check had slipped into a comment, so it would have taken a buy-in for a seat that doesn't exist).
- **Deployed October 5:**
  - the first migration was applied through the connector, except the roulette game check;
  - Big U ran the game check and the rooms migration in the SQL editor;
  - the `tables` edge function is version 7, checked byte for byte against the repo;
  - then the site.

## v0.9.9.1: Hold'em no longer reveals folded hands (hotfix)

Found in the October 5 audit of the casino work order (PAL-0100-9).
- **The bug:**
  - after each Hold'em hand, every player was sent the whole deck so the deck fingerprint could be checked, and the panel printed it as numbers;
  - cards are dealt in order, so the deck showed what folded players held (and the cards that would have come);
  - Blackjack wasn't affected: a fresh shoe every hand, all cards face up.
- **The fix:**
  - Hold'em no longer sends the deck after a hand; it stays in the server's hand log (`casino_hands`) for checks like the hand #23 audit;
  - the panel says so;
  - per-card fingerprints, so players can check the deal themselves without seeing folded hands, come with v0.10.0.
- **Deployed:** the `tables` edge function (version 5), then the site.
- **Tests:** `tables_engine` gained an after-the-hand check (no deck and no folded hand reaches any player over 3,000 random hands); `tables_engine`, `tables_server` and `tables_ui` pass.

## Test suite speed-up (October 5, no game change)

- **New runner** (`dev/test/run_suite.js`, wrapped by `run_all.sh` / `run_targeted.sh` / `run_targeted.ps1`):
  - tests run in parallel, longest first; no-browser tests go first, and timing-sensitive or six-player tests run alone at the end;
  - one list with area tags (`suite.txt`), so `./run_all.sh @hud` runs one area;
  - `--build` does the single build tests need, and a stale build is refused;
  - `--failed` and `--changed` re-runs; it starts and stops its own servers.
- **Tests wait for conditions, not fixed pauses:**
  - `dev/test/lib.js` has the helpers;
  - the debug build has `__pal.ready` (frames running, fonts in, account boot done);
  - 36 tests changed.
  - Three tests that failed under load (`v090_net`, `ingame_settings`, `winter_network`) now check game state instead of wall time.
- **Result:**
  - the full suite (95 tests) passes in **9.6 min**;
  - on the 45 slowest tests, total test time dropped from 17.4 to 12.2 min;
  - `menu_bg_motion` went from 145 to 44 s, `rewards_lobby_shotgun` 64 to 18 s, `poll_backoff` 17 to 2 s.

## v0.9.9: health above heads

From Part A of the [work order](plans/nameplates-and-tables-work-order.md) (Big U, October 4: H1–H5).
- **The top-left health panel is gone during matches.** Health is drawn above heads instead, after the lighting so it reads at night:
  - **you (H1):** a bar and your number, the only number shown;
  - **teammates and Delgado:** their name and a bar;
  - **PvP (H5):** the other side shows names only, no bar.
- **Core health (H2)** sits in the phase box under the timer.
- **Delgado's FOLLOW / DEFEND (H3)** is a small button in the phase box, shown to the host only. On landscape phones it reads just FOLLOW or DEFEND, to the left of the title.
- **Off-screen teammates (H4):** an arrow on the screen edge with their name, blinking red with "· DOWN" while they're downed.
- **Also:**
  - low health pulses your bar and adds a faint red edge to the screen;
  - downed players keep the revive ring;
  - the Black Out ready ✓ moves onto the nameplate.
- **Layout:**
  - desktop and landscape phones put core health and Delgado's button beside the timer, so the phase box stays short and the mini-map and build kit keep their room;
  - the message banner uses the old panel's space on desktop;
  - the landscape boss strip stays left of the phase box.
- **Tests:**
  - New `nameplates`.
  - `hud_layout` was rewritten for the removed panel.
  - `blackout_hud`, `toast_queue`, `delgado`, `ammo_armory`, `tips_toggle`, `solo` and `blackout_run` pass.
  - Screenshots in [evidence/v0.9.9](evidence/v0.9.9/).

## v0.9.8.3: Frostpeak cliffs stop clipping into the stairs

From the [work order](plans/frostpeak-stairs-work-order.md) (Big U, October 4).
- **The bug:** the upper cliff wall just left of each staircase and ramp painted over the top steps. Stairs are drawn into the ground layer first; cliff faces come later in the depth-sorted pass (so they can hide players behind a lip), so they always landed on top.
- **The fix:** each cliff face now skips the on-screen outline of any staircase or ramp in front of it (rails included). Players behind a lip are still hidden as before.
- **Handrails (D1):** posts and a rail down both sides of every staircase and ramp. The sides already blocked movement.
- **Cliff texture (D2):** a snow lip, a small snow ledge and a crack or two on each face, placed by tile so they're the same every frame.
- **Unchanged:** the dark triangle on the right of each connector is intended (a shadow, Big U). Heights, collision and pathing are unchanged.
- **Tests:**
  - New `frost_connectors` (cliffs drawn in magenta: 0 magenta pixels on every connector at both sizes; the old build had 360 on each).
  - `winter_elevation`, `winter_combat` and `campaign_map_evac` pass.
  - Before and after screenshots in [evidence/v0.9.8.3](evidence/v0.9.8.3/).

## v0.9.8.2: animated menu backgrounds move on every page

From the [work order](plans/menu-backgrounds-work-order.md) (Big U, October 4: full speed everywhere, Account too, keep reduce motion).
- Animated backgrounds now move behind the Locker, Tables, Skills, Settings and Account pages, at the same rate as PLAY. They used to freeze there: a v0.9.1 speed choice that every later page inherited.
- Still only for still backgrounds, or when the system asks for reduced motion.
- **Speed work so the Locker keeps up** (it has three stage-sized character layers on top of the background):
  - phones paint the soft background at 3/4 resolution;
  - your figure repaints only a box around itself instead of wiping the whole layer each turn step. New `stage_box_fit` checks every skin and headwear × class × 6 angles (4,128 combinations) fits the box with room to spare;
  - the Locker's demo tracer shot clears only where it was.
- **Locker frame rate, phone viewport, Hellgate equipped:**

| CPU | still background (before) | animated, first try | animated, final |
|---|---|---|---|
| normal | 60 | 60 | 60 |
| 2× slower | 57 | 57 | 57 |
| 4× slower | 47.6 | 33.8 | 47 |

The test machine has no graphics chip (everything is composited in software), so the slow-CPU numbers are worse than a real phone's.
- Test: new `menu_bg_motion` (8 pages × 3 sizes, animated and reduced motion). Evidence in [evidence/v0.9.8.2](evidence/v0.9.8.2/).

## v0.9.8.1: Tables fixes (Big U's feedback)

- **The host starts the table:** nothing is dealt until the host presses START (Hold'em needs 2 players). Table rules can be changed until then.
- **No clock during a hand:** nobody is auto-folded or auto-stood. (A player who closes the game is still stood up after a minute and gets their shards back.)
- **60 seconds between hands:** Blackjack's betting window is 60 s and deals as soon as everyone has bet; Hold'em has a 60 s break that deals as soon as everyone taps READY (busted players aren't waited on).
- **Clearer screens:**
  - **Lobby:** game cards that explain each game, numbered steps.
  - **Table code:** shown big at the top so it's easy to share.
  - **Status line:** always says what's happening and what to do ("YOUR TURN · You have 15 · the dealer shows 10").
  - **Buttons:** each has a short hint underneath. Bets use a −/+ stepper and quick chips; Hold'em raises use a slider.
  - **Last hand:** stays on the felt while you bet.
  - **How to play:** a panel for each game.
- Tables opened before this update keep running. Edge function redeployed (version 3); no database change.
- Tests: `tables_engine`, `tables_server` (25 checks), `tables_ui`, `csp`, `taborder`.

## October 4: 250-shard account bonus (server only)

- Every account (not guests) got 250 shards, with a notification: 7 accounts at the time.
- Anyone who makes an account later (a new sign-up, or a guest adding an email) gets it automatically, once.
- Migration `20261004230000_account_bonus_250.sql`, applied live at Big U's request. The grant can never block a sign-up (errors are swallowed).

## v0.9.8: THE TABLES (Blackjack and Texas Hold'em for shards)

From the [work order](plans/nameplates-and-tables-work-order.md), Part B (all decisions by Big U, October 4). Evidence in [evidence/v0.9.8](evidence/v0.9.8/README.md). Match protocol unchanged (`yard-27`).

- **New TABLES tab** (signed-in accounts only; guests are told to make an account). Host opens a table (game, limit 100 / 250 / No limit, side bet on or off); others join by code or from the list.
- **Straight shards:** 5-shard buy-in is your table stack; top up any time between hands (unlimited); standing up sends your stack back to your balance. Disconnected players are stood up after a minute; tables nobody touches for 3 minutes close and pay everyone out.
- **Blackjack:** traditional rules, 4 decks reshuffled every hand (no card counting), dealer stands on soft 17 and checks for blackjack, 3:2 (rounded down on odd bets), double, double after split, split to 4 hands, insurance. Up to 5 players. Cards deal automatically once everyone has bet (12 s window).
- **Hold'em:** one deck, blinds 1/2 shards, side pots, a 1.8% rake (max 6) on pots that see a flop. 2 people: a bot sits in (it may lose at most 25 shards a day); 3 or more: people only; 1: waits. 20-second turns.
- **Side bet (1 shard a hand):** double aces (Blackjack), pocket aces or a full house or better (Hold'em) pays 10 Hybrid Theory or 15 Flag Cases, winner's pick (Hybrid if they leave first).
- **Fair deal:** every deck is fingerprinted (SHA-256) at the deal and revealed after; every hand and every shard is logged.
- **Server:** new edge function `tables` and migration `20261004200000_v098_tables.sql`.
- **Phones:** the bottom tab bar now has 7 tabs.
- **Tests (only what changed, per Big U):** new `tables_engine`, `tables_server`, `tables_ui`; `taborder`, `index_page`, `accounts` and `csp` pass.

## v0.9.7.3: City Black Out polish (banners, streetlamps, mini-map)

From the [work order](plans/blackout-polish-work-order.md) (all decisions by Big U, October 4). Client only; protocol stays **`yard-27`**. Evidence is in [evidence/v0.9.7.3](evidence/v0.9.7.3/README.md).

- **Banners (every mode):**
  - smaller, same style: title 18-28 px, detail 13 px (14 on desktop) and at most two lines, 3 px bands; at most 86 px tall on desktop;
  - at the top of the screen: desktop in the gap between the vitals and the phase box; landscape phones top-left up to the mini-map or phase box; portrait phones right under the top bar (and tip);
  - placed from the live HUD each frame; they drop below the boss bars when they'd overlap (the bars keep their place), and on portrait phones they narrow to the room left of the build kit if pushed that far;
  - **off-centre text fixed.** The banner's `phase` class also matched the HUD phase box's rule (a right-aligned grid), so titles sat to the right. Text is now centred on the panel (checked within 2 px);
  - times: phase messages 6 → 4.5 s, minor 3.5 → 3 s (Message time still multiplies them).
- **Streetlamps:** every 4 tiles instead of 6 (50 → 60 lamps on the 64×64 city), pools 1.9 → 3.5 tiles at 60 → 85%, a faint warm glow on each pool and a halo on each bulb. Still dark when the Power Station falls.
  - **Changed from the work order:** the radius is 3.5 tiles, not 3.2. Two lamps 4 tiles apart only meet the order's own bar (the darkness at their midpoint at most half the night's) from 3.4 up; at 3.5 the worst pair is at 48%.
- **Mini-map:** top right under the phase box (desktop and portrait), beside it on its left on landscape phones.
  - Room is kept for the phase note, so the first message doesn't move it; it stays put when the tip hides (B6).
  - While boss bars are up it steps below them (on portrait phones, to the left edge if the build kit is in the way).
  - On portrait phones it fades out under a banner and comes back after (B3).
  - **Changed from the work order:** the kill feed sits beside the mini-map on its left, not under it. Under it, the feed ran into the build kit at all three sizes.
- **Caught in testing:** a banner shown while the page was still starting (after a reload) ran the new placement before the game state existed and stopped the page loading. Guarded; `tips_toggle` covers it.
- **Tests:** new `blackout_hud`; `toast_queue` (new times, placement, centring and overlaps at three sizes, in a normal raid and Black Out, with 0/1/2/4 bosses) and `blackout_map` (lamp spacing, pool size, midpoint brightness) extended.

## v0.9.7.2: new main menu music, music starts on the first click

- **Main menu track:** Big U's Pali Mix (7:38) replaces Heartbeat. It's encoded like the rest (AAC 160 kbps and Opus 128 kbps, 48 kHz stereo) and loops at 458.352 s. Decoded, it takes about 168 MiB, now the largest track (Everything She Wants was 142.6 MiB). Watch for memory trouble on older phones.
- **Music start fix:** sound used to wake only from the game screen or a menu tab, so the menu stayed silent until you changed pages. It now wakes on the first tap, click or key anywhere. Browsers allow no sound before that first touch.
- **Offline cache:** the service worker drops cached music that is no longer current (the old menu track) and keeps the other six tracks.
- **Test:** new `menu_music_start`. `music_assets`, `music_routing`, `reel_music` and `music_network` pass.

## v0.9.7.1: beta feedback pass

From the [work order](plans/beta-feedback-work-order.md) (all decisions by Big U, October 3). Protocol **`yard-27`**. No server change. Evidence is in [evidence/v0.9.7.1](evidence/v0.9.7.1/README.md).

- **City Black Out salvage:**
  - each attack's end pays everyone 20 + 5 × attack number (half if the point fell);
  - +40 when the gathering starts, +60 when the final push's ready stage starts;
  - kill bounties ×1.25;
  - the armory opens at any held point during quiet gaps, which are now 35 s;
  - patching the core stays at Main Command.
- **READY UP before the final push:**
  - up to 90 s;
  - it starts when everyone alive is ready, or when the time runs out; nobody can force it;
  - READY button in the phase box, Enter, or a controller's Start;
  - the ready count shows on every phone and check marks in the crew list;
  - points repair at double speed meanwhile.
- **Round messages:**
  - queued instead of overwriting each other;
  - phase messages stay 6 s on a coloured band (orange threat, green held, red lost), minor ones 3.5 s;
  - darker panel and bigger detail text;
  - the latest phase message stays under the phase box;
  - tap to dismiss;
  - Settings → Message time (×1, ×1.5, ×2).
  - Applies to every mode.
- **Phantom:** can wear any headwear again. Hats are drawn solid over the see-through figure, and every hat passes the fit check on him.
- **Lobby ready up:**
  - guests press READY, and rows and a "1 / 2 READY" count show it;
  - the host's START stays locked until every guest is ready;
  - any change to the settings clears everyone's ready.
- **Zoom (desktop only):**
  - Settings → ZOOM 70%–140% and the mouse wheel, saved per device;
  - one scenery rebuild per change;
  - phones keep their screen-sized view.
- **Tests:**
  - new: `toast_queue`, `zoom_setting`;
  - extended: `blackout_run` (round pay, purse, armory reach, the ready stage), `blackout_network` (ready 1/2 on both phones), `blackout_perf` (desktop at 70%), `lobby` (the real ready flow), `headgear_fit` (the Phantom).
  - The other online tests ready up through a debug hook before START.

## v0.9.7 on the branch: CITY BLACK OUT

From the [work order](plans/city-blackout-work-order.md). Big U said to build it with the defaults (D1–D10). Protocol **`yard-26`**. Evidence and the Phase 0 gate are in [evidence/v0.9.7](evidence/v0.9.7/README.md).

- **Big-map engine:**
  - chunked scenery (only on-screen chunks are painted; far ones are evicted);
  - on-screen-only culling on maps larger than 24×24;
  - heap pathing, about 50× faster;
  - per-POI flow fields.
  - Existing maps keep their single picture.
- **The city (64×64; 48×48 fallback):**
  - Main Command in the centre;
  - ring roads and avenues (1.35× speed), rubble (0.8×), and solid ruined blocks that block bullets;
  - parks, sidewalks and streetlamps.
  - The 8 POIs are stakes, each with its own structure. Held POIs are lit, lost ones flicker out, and the streetlamps run on the Power Station.
- **The run:**
  - 45 s gathering;
  - attacks on minors first, then majors, 30 s apart, each a random boss with his own troops from the nearest edge;
  - an attack ends held, lost, or pulled back after 60 s;
  - the quiet windows repair POIs and open the armory;
  - all 8 perks are in;
  - the final push lasts 5 minutes, with a boss every 30 s (at most 4 up), plus 1 squad per lost major and +5% boss health per lost minor;
  - the Supreme Destroyer arrives at 3:00 with shield and grenadier squads only;
  - the run is won at 0:00 or when the Destroyer dies.
- **THE SUPREME DESTROYER:**
  - back rockets, a fire/lightning gun, poison gas, a minefield, and an Orbital Cannon below 40%;
  - 7× a boss's health, weak to Armor Piercing;
  - has an Index card.
- **HUD, menu and online:**
  - GATHER / POI ATTACK / QUIET / FINAL PUSH phase box, mini-map, off-screen attack arrow, COMMAND bar;
  - BLACK OUT fills the sixth mode slot;
  - an Index section on the eight points;
  - music routing;
  - guests get a POI summary, plus full detail only for raiders within 22 tiles of them (bosses always).
- **Rewards (cv:5 claims):**
  - POIs held fill the Supply Case bar;
  - +1 Supply Case per held major;
  - a win pays 2 Supply Cases and 25 shards;
  - the Destroyer pays +40 shards and +1 skill point.
- **The BLACK OUT ladder** (a counter per step): Night Shift, Blackout Helmet, Streetlight, Orbital Strike, Lit Skyline, Gold Night Shift.
- **Server:** migration `20261003200000_v097_city_blackout.sql`, tested in PGlite, **applied live October 3 with Big U's approval** and verified (claim logic, rooms, lobby length, 6 catalog-5 rows, 2 new columns). Black Out claims queued on a device before that pay on their next retry.
- **Tests:** `blackout_map`, `blackout_run`, `blackout_destroyer`, `blackout_network`, `blackout_rewards`, `blackout_migration`, `blackout_perf`.

## v0.9.6.5: the Index, boss weaknesses, +25% boss health, new boss moves

From the [work order](plans/index-and-boss-weakness-work-order.md) (all decisions by Big U, October 3). Protocol **`yard-25`**. No server change.

- **INDEX replaces CLASSES:** three tabs.
  - Classes: unchanged.
  - Raiders: 7 cards with health, speed, first raid and a portrait.
  - Bosses: 14 cards with base health, where you meet them, every attack and its warning, the low-health phase, and the weakness.
  - Numbers come from the game's tables.
- **Weaknesses:** a bullet carrying the boss's weak ammo deals +35% bullet damage. Burn ticks and splash get no bonus. A "WEAK: …" tag shows on the boss bar.
  - Armor Piercing: Demolisher, Bulldozer.
  - Incendiary: the four winter bosses.
  - Explosive: Stormcaller, Foreman, Tempest.
  - Lightning: Butcher, Blue Butcher, Arsonist, Ferryman, Harbinger.
- **+25% boss health:** one `BOSS_HP` multiplier, stacking with map, XL, crew and gauntlet scaling.
- **New moves (boss states 20-30, no new snapshot fields; the Permafrost Foreman is unchanged):**
  - Stormcaller: Thunderstrike, Static Pulse.
  - Tempest: Cyclone, Storm Cage.
  - Arsonist: Flamethrower, Ring of Fire.
  - Bulldozer: Seismic Slam, Overdrive (replaces Rubble Spray, so nothing is left on the map).
- **Tests:** new `v0965_bosses` and `index_page`.

## v0.9.6.4 on the branch: campaign evacs, the Whiteout Gauntlet and the Hybrid Theory Case

Built from the [work order](plans/campaign-evac-and-finale-work-order.md) (all decisions D1-D9 and H1-H5 made by Big U). Branch `claude/lucid-curie-491na1`, protocol **`yard-24`**. Big U approved the payout table and catalog on October 3. **Server applied October 3:** `20261003080938_v0964_hybrid_catalog` (case row, 57 items at catalog 4, `open_cases_v0964`) and `20261003153435_v0964_gauntlet_rewards` (`claim_match_reward`; verified live, grants unchanged, advisor shows only the known warnings). The reward function no longer prunes `private.reward_receipts` older than 31 days (Big U's call: the Supabase connector held the `delete` for a confirmation it could not show); prune by hand if that table grows. The temporary `private.v0964_stage` table used to apply it is still there and should be dropped from the SQL editor (`drop table private.v0964_stage;`).

- **Resources stay open** on later campaign maps (fixes Yard scrap never opening, no brick on Riverbend, no metal on the Quarry).
- **Map evacs after raids 3, 6 and 9:** 15 s, shieldbearers and grenadiers only. A player left behind goes on to the next map at 50% health with no salvage and loses that chapter's evac case; if nobody gets out, the run ends ("EVAC FAILED · CHAPTER n").
- **The Whiteout Gauntlet** replaces the old finale: 6 waves every 30 s (2 Rime + 1 random from whitebutcher, whiteforeman, tempest, bulldozer, bluebutcher, arsonist), at most 8 alive, 110% boss health, evac opens for the last 30 s.
- **Rewards (cv:4 claims only; older clients are paid as before):** each gauntlet boss 5-10 shards, +1 SP and +1 base milestone (Rime ladder uncapped, about 4x faster); +1 Winter Case per fully cleared wave (6 max); final evac +2 Winter Cases and 25 shards; +1 Winter Case per chapter evac made. The no-account locker mirrors these rules.
- **Hybrid Theory Case:** 57 items (30 jerseys on a new sleeveless body, 8 headgear including a Dunce Cone that fits the Sheet Ghost, 11 kill effects, 8 animated block-city backgrounds); 12 shards, c46/r30/e16/l7/g1; one for everyone after any co-op win. Cases open through `open_cases_v0964` (catalog 4), falling back to `open_cases_v0962` until the server has it.
- **Tests:** new `campaign_resources`, `campaign_map_evac`, `campaign_gauntlet`, `campaign_network`, `hybrid_case`, `v0964_migration` (32 database checks); winter and case tests updated. The cosmetic catalog capture was rebuilt against the live catalog (368 items, no review findings).

## v0.9.6.3 published: frame rate, CPU and network efficiency

From an October 3 audit (Big U approved items 1-4 plus the player-field change). **Published October 3** as [#11](https://github.com/lopoke89-ops/palisade/pull/11) (`674f33e`); GitHub Pages serves footer v0.9.6.3, protocol `yard-23`, service worker `palisade-44a8936c2e`; a live desktop and phone start had no page errors or CSP violations and no debug hooks. Evidence and before/after numbers: [evidence/2026-10-03-efficiency/README.md](evidence/2026-10-03-efficiency/README.md). Protocol **`yard-23`**: the state packet layout changed, so older copies must reload.

- **Desktop Auto holds 60 FPS.** Auto left desktops uncapped, so 144 and 240 Hz monitors ran the whole game 2.4-4x as often. Touch devices are unchanged (60, or 30 when struggling or on low battery).
- **No per-frame page changes.** The frame loop and HUD re-set 5-7 `hidden` flags every frame even when unchanged; each counted as a page change and forced a style pass. A `hid()` guard (next to `cls()`) removes all of them: style passes on menus drop from 117 to 60 a second (the rest is the stage character's CSS bob).
- **Friends polling only while the menus are in use.** Every 15 s while active; never in a hidden tab; once a minute during a match or after 5 idle minutes (the open Friends panel keeps 15 s); coming back to the tab checks at once. The Open Games list no longer refreshes in a hidden tab. Host room publishing is unchanged (the server expires a silent room after 45 s).
- **Slimmer state packets.** Height is no longer sent (every screen works it out from the same map); player rows put usually-zero fields last and drop trailing zeros; materials, grenades, salvage, kills, deaths, spawn protection and "evacuated" go in a separate block only when they change (repeated for 8 packets because the state channel doesn't resend, every player every 30 packets as a safety net, and all of them after a join). Busy six-player scenes: about 10% smaller on flat maps, about 20-25% on Frostpeak.
- **Server fix found during the audit (applied October 3 with Big U's approval):** live `room_register` still accepted only `yard-21`, so rooms hosted from v0.9.6.1 on (`yard-22`) could not register and friend room invitations failed. `20261003040401_room_register_any_yard_proto` accepts any `yard-N` (the invite answer still refuses mismatched versions). Tested in PGlite (`winter_migration`); verified live: new check in place, grants unchanged (authenticated, postgres, service_role), security advisor shows only the known warnings.
- **Measured and rejected:** culling off-screen walls and raiders before drawing (skipped 36-57% of tiles, no measurable frame-time change).
- **Tests:** new `poll_backoff`; `fps_mode` expects 60 for desktop Auto; `winter_migration` covers the proto fix. Nine tests left stale by v0.9.5.1-v0.9.6.2 were brought up to date (Frostpeak, 15 ladders, winter Sahur hats, the October pumpkin Butcher, batch case openings; `v087` now times class speeds in game time and `v090` keeps the Ferryman healthy until its ram check).

## v0.9.6.1 published winter upgrade

The [winter upgrade work order](plans/winter-cosmetics-dell-and-dead-end-work-order.md) is implemented in the checkout, with 36 affected suites passing and a complete 311-entry four-angle catalog. Source/build protocol is yard-22. The `20261001214620_winter_models` migration is live; the game changes were pushed as `526831b` and the live HTML was verified against that commit. See [completion and performance evidence](evidence/2026-10-01-winter-upgrade/README.md) and [catalog index](catalog/cosmetics/README.md). The following section records the subsequent published music/case release.

## v0.9.6.2 published music/case release

Seven replacement tracks, stable raid/finale/results routing, and atomic one/five-case openings are implemented. `20261001225643_music_case_batches` is live. Focused gameplay/network/database/asset checks and phone-sized case benchmarks are documented in the [completion report](evidence/2026-10-01-music-case-batches/README.md). Publication was authorized October 1. Commit `358696b` is pushed and GitHub Pages deployed successfully. Live HTML/service-worker hashes, all 14 audio hashes, the production five-case flow, shared menu playback and offline game/audio fetches pass without page errors or CSP violations. [Release verification](evidence/2026-10-01-music-case-batches/release-verification.json) records the checks and deployment.

## Live and local

| Item | Current state |
|---|---|
| Source release | Published **v0.9.6.3**, protocol `yard-23` |
| Release deployment | v0.9.6.3 merged October 3 as #11 (`674f33e`); GitHub Pages serves it (service worker `palisade-44a8936c2e`) |
| Live protocol | `yard-23` / `palisade-yard-23-`; clients from yard-22 must reload |
| Applied server migrations | `room_register` accepts any `yard-N` (`20261003040401`, October 3); winter models (`20261001214620`) and music/case batches (`20261001225643`); earlier migrations retained |
| GitHub branch | `main` contains `674f33e` (v0.9.6.3) |
| Published build | GitHub Pages **v0.9.6.3**, protocol `yard-23`; live HTML SHA256 `fa537d3af50c892c55d4b45827c02d24ef45b2f2b5260103991d5248ea495b7f` (matches the committed build) |

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
