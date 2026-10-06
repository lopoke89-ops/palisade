# PALISADE FALLS CASINO — expansion and result-review work order

Prepared and scope-audited October 5, 2026; revised October 6 against the day's releases. Reference checkout: `ca90257` on `main`, **v0.10.1**, protocol `yard-28`.

**Baseline as of this revision (verified, not assumed):**

- v0.10.1 is published. On October 5 at 21:18 UTC the live site showed the `v0.10.1` footer, served the casino playlist files in both formats, and its service worker listed all 22 of them. Recheck before starting; later commits may exist.
- v0.10.1 added the casino's own music: 11 ambience tracks on a true shuffle with 5-second equal-power crossfades, played only in casino mode (`CASINO`, `cas`, the `casino` route in `dev/src/js/03-audio.js`; test `casino_music`). This work order does not change that playlist.
- The October 5 shard gift (`dev/supabase/compensation/2026-10-05_gift_750.sql`) was an owner-requested change to `lockers.shards` outside the casino. Wallet changes like it are outside the casino books (see §4).
- Two suites already fail on `main` without the v0.10.1 changes: `v090` (`casino:std layout: stake off map, stake on terrain undefined`) and `controller` (`same message fields as before, trigger mode`). Treat them as baseline failures (see §11).

## Mission

Act as the lead AAA gameplay developer, senior online casino systems engineer, casino mathematician, and Canvas presentation specialist for PALISADE. Add **Craps, Plinko, playable slot machines, and Baccarat** to the existing walkable casino. Improve the ending of every casino game so players have time to see the outcome, understand what beat them, and distinguish losses from shards moved between their wallet and a table.

Deliver complete, playable, polished games with reproducible math and reliable accounting. A cabinet animation without a working game, a rules approximation, or a frontend-only payout is not completion. Keep the existing Palisade art direction, room-based multiplayer, account system, controls, and soundtrack.

This work targets the browser game in this checkout. AAA describes the quality of the controls, presentation, rules, and verification. Keep the Canvas world renderer, existing HTML/CSS table sheets, PeerJS rooms, and Supabase casino authority. A Godot port, new engine, new frontend framework, or replacement multiplayer platform is outside this work order.

Shards remain the existing play currency: no purchase, withdrawal, or conversion to cash. Preserve that project constraint throughout the new game rules and interfaces.

This document specifies an implementation candidate. It does not itself authorize production deployment, production schema changes, or player compensation. Prepare and verify the candidate before requesting any release approval required by the project. Do not perform gifts, refunds, or balance backfills as part of development.

## 1. Inspect the actual baseline

Read the relevant source, current migrations, tests, and release evidence before editing. Establish which local, GitHub, website, and backend versions agree. Preserve unrelated work and choose the release version after checking the current branch. The footer version is a hand-written string in `dev/src/page.html` (`<p class="foot">`); bump it, and add a `dev/STATUS.md` entry, as part of the release. Because the station/protocol changes are expected, this is a minor version (v0.10.3 unless the branch has moved on), not a v0.10.x patch.

Relevant source:

| Area | Existing paths |
|---|---|
| Casino geometry, furniture, seats, entry | `dev/src/js/06f-casino.js` |
| Map size and casino mode integration | `dev/src/js/06b-maps.js` |
| Tables interface, polling, history, fairness | `dev/src/js/21b-tables.js` |
| Room networking and seat propagation | `dev/src/js/21-online.js` |
| Accounts and public room directory | `dev/src/js/19-accounts.js`, `19d-friend-invites.js` |
| Page and styling | `dev/src/page.html`, `dev/src/style.css` |
| Casino music (v0.10.1 playlist; keep as is) | `dev/src/js/03-audio.js`, `dev/audio/music-manifest.json`, `dev/test/casino_music.js` |
| Server adapter, requests, game rules | `dev/supabase/functions/tables/index.ts`, `handler.js`, `engine.js` |
| Database and account transactions | `dev/supabase/migrations/` |
| Build and test selection | `dev/build.py`, `dev/src/js/ORDER.txt`, `dev/test/run_suite.js`, `dev/test/suite.txt` |

Existing constraints to address explicitly:

- The current games are Blackjack, Hold'em, and American roulette. Slots on the floor are decoration.
- Blackjack's `PAUSE_MS` is zero. `tick()` can settle, clean up, and reopen betting within one request. A cosmetic client delay cannot correct this server behavior.
- Hold'em already has a 60-second between-hand break, with readiness able to advance it. Roulette has a four-second result display.
- Game dispatch assumes a small fixed set of games. Search every dispatch, database game constraint, view, settlement, history, bookkeeping, seat, and cleanup path; do not add a game only to the visible menu.
- Seat decoding currently depends on table numbering and array position. Preserve existing seat identities and replace brittle assumptions with a verified registry where needed.
- The Tables front door lacks the public casino-room list requested by the previous casino work order. Its `lobby` request currently returns balance and existing seating, not public rooms. Track that as a separate follow-up; it is not an acceptance gate for this four-game request.
- Casino play requires a saved online account. Preserve one active casino seat/activity per account, the five-shard base buy-in, and the existing wallet/table-stack relationship. Offline availability of the site does not permit offline shard wagers.
- The database currently permits one open row per `(room, game)`. Multiple usable slot cabinets need a station identity and a narrow uniqueness/lookup migration; the existing constraint would merge them into one game session.
- Current `histRow()` and `lastView()` disclose full seeds/decks immediately for games other than Hold'em. Baccarat's active shoe needs an explicit exception and its own verifier; adding only a new game enum would leak future cards.
- The handler currently closes a table when no humans remain. For Craps, closure must also require zero pending obligations; preserve the wager owner and recovery state until those bets settle.
- Recent exit auditing found a correctly recorded cash-out. Do not claim that reported confusion proves a missing-money bug; reproduce any defect separately.

- Casino music is now its own route (`musicRoute()` returns `{k:'casino', token:'casino:'+game.gid}` whenever `game.mode==='casino'`). Anything that changes how the casino is entered, re-created, or identified (a new `gid` per table, a casino map rebuild, a mode rename) must keep that route stable: re-creating the room must not restart or reshuffle the playlist mid-visit.

Make focused additions with reusable rules, accounting, and rendering boundaries. Do not rewrite combat, broaden deferred account/reward hardening, or change existing cosmetic acquisition and reward rates. Preserve browser storage keys and stable element IDs. The new playable slots supersede the older work order's decoration-only decision; the other established casino contracts still apply.

## 2. Proposed defaults and scope

Use these defaults for the candidate unless the owner supplies replacements. Identify them as project choices, not universal casino rules. Resolve routine implementation details independently; report material departures before adopting different economics.

| Item | Default |
|---|---|
| Room population | Existing maximum of six human players |
| Casino floor | Start with the existing 16×16 floor and targeted rearrangement; enlarge only if a measured layout cannot provide reachable seats and usable paths |
| Tables | Existing Blackjack, Hold'em, roulette; one new Craps table and one new Baccarat table per casino room |
| Machines | Reuse existing slot cabinets and add one Plinko station; one occupant per physical machine |
| Slot theme | One original Palisade theme and math version; additional Winter/Black Out themes are follow-ups |
| Slot format | Three reels, one fixed payline; one spin per deliberate action |
| Plinko | Twelve rows, thirteen pockets; one published payout table for the first release |
| Baccarat | Eight-deck mini-baccarat; Player / Banker / Tie; 5% Banker commission; Tie pays 8:1 |
| Craps | Standard casino craps, Don't Pass / Don't Come bar 12; 3–4–5× Pass/Come odds |
| New shared-game betting windows | 30 seconds for Baccarat, 20 seconds between Craps rolls; readiness may shorten betting after five seconds, once everyone eligible is ready |
| Card result review | Eight seconds guaranteed; retain Hold'em's existing longer break |
| Dice and roulette result review | Six seconds guaranteed |
| Slots and Plinko result review | Three seconds guaranteed after the final reel stop / pocket landing |
| Custom machine return target | Theoretical RTP 96%, within 0.1 percentage point after exact whole-shard denomination constraints |

Required scope is the four games, the floor interaction needed to reach them, result review, and the casino accounting/history/fairness work those behaviors require. Extra machine themes, additional Plinko stations or risk settings, and public casino discovery are separate follow-ups. A casino-only map enlargement or recovery mechanism is conditional on proving it is needed for core acceptance; neither implies a wider world-map or hosting redesign.

No auto-betting, bonus purchases, progressive jackpot, new cash currency, or new casino cases in this release. These are separate extensions, not substitutes for finishing the four games. Craps buy/lay commission bets, hop bets, and combination horn bets are also later additions; the required first release bet set is specified below.

The 96% return target and the new timer values are proposed design defaults, not previously approved economy changes. Document their impact on shard circulation, keep all custom machine configurations below 100% theoretical return, and preserve existing games' payouts, limits, rake, side bets, and case prizes. Banker and Plinko denominations may exceed the five-shard buy-in: show compatible bets and a clear top-up path without raising the global buy-in or silently debiting the wallet.

## 3. Result presentation — implement this first

Extend the existing `done` phase, `last` result, and `casino_hands` history where suitable. A settled round needs a durable identity, game and rules version, outcome, visible evidence, player's total committed stake, gross return, net change, and authoritative settlement/reveal/review timestamps. Reuse these records rather than introducing a separate receipts platform. For persistent Craps bets, distinguish settled stake from wagers still active for future rolls.

**Settlement and presentation are separate:** credit the correct result exactly once to the appropriate table/machine stack when the server settles it; return that stack to the wallet under the game's exit rules. Keep its receipt and visible evidence available during review. Preserve existing games' departure rules and never delay an otherwise permitted cash-out solely because an animation or review timer is running.

The server must preserve review across requests. The update loop must not pass through settlement and erase the result in the same request. Readiness cannot bypass the minimum review time. Measure the minimum from the scheduled final reveal, not the start of dealing or animation: an eight-second result timer cannot be mostly consumed while cards are still turning over. Afterwards, Blackjack and Baccarat open their normal betting windows; roulette opens its next window; Craps opens betting for the next roll. Hold'em retains its 60-second break, but cannot deal early until the eight-second minimum has elapsed.

At machines, SPIN / DROP remains disabled until the animation and three-second review are complete. Requests still need server validation; hiding a panel or opening a second browser tab must not bypass accounting or accepted-operation limits.

During review, show:

- A prominent WIN, LOSS, PUSH, or PARTIAL RESULT label, using words as well as color.
- `BET`, `RETURNED`, and signed `NET`, with commission and side bets itemized where applicable. Returned stake is not profit: a push has zero net.
- Wallet balance, uncommitted chips at the table, and committed wagers as separate values. Never subtract one loss twice in the presentation.
- A stable LAST RESULT / VIEW RESULT control that works after the next betting window opens, after standing up, and after rejoining.
- A clear countdown and a control hint. HIDE closes the sheet while preserving the seat; STAND UP requests a cash-out. Do not overload a generic Back button with both behaviors.

Game evidence:

| Game | Required result evidence |
|---|---|
| Blackjack | Every player split hand, final total, dealer's dealt cards and final total, soft/hard interpretation where useful, insurance result, and a plain explanation such as `Your 19 lost to dealer 21` or `You busted at 24`; preserve the existing rule that the dealer stops drawing when no live hand requires comparison |
| Hold'em | Community cards, player's own cards, legitimate showdown cards, winning five-card combination, hand name, and per-player side-pot awards; explain uncontested pots without revealing folded hands |
| Baccarat | Complete Player/Banker hands and point totals, winning side, Tie handling, and commission |
| Roulette | Number, color, 0/00, and each wager's outcome |
| Craps | Both die faces, total, prior and resulting point, each settled wager, and wagers that remain working |
| Slots | Final symbols, winning payline, winning combination, stake and payout |
| Plinko | Landed pocket, multiplier, stake, gross return, and net |

Preserve Hold'em's current privacy contract. Do not expose folded hole cards, hidden burn cards, or the full deck through result views, network snapshots, fairness payloads, world art, or immediate history. Preserve the existing delayed disclosure policy. When a player wins because everyone folded, say that; there are no winning opponent cards to reveal.

Timers use authoritative server time and survive tab suspension and reconnect. Late snapshots must not erase the saved receipt; provide result review without hiding controls for a currently active turn. Reduced motion shortens visual movement, not the guaranteed reading period. Closing the game still follows the existing away policy; hiding only the table sheet keeps its normal polling. Do not add constant background-tab polling to hold a seat.

## 4. Shared accounting, persistence, and fair outcomes

Extend the existing server-authoritative system. The PeerJS host controls room movement, not bets, dice, cards, machine outcomes, or shards.

Retain `casino_open` / `casino_commit`, their version checks, the ledger, and the existing books check unless a focused test proves an extension is needed. Apply duplicate protection to casino stake, settlement, top-up, and cash-out paths; do not use this task to redesign raid rewards, account identity, the Locker, or all account transactions. Casino tables and privileged payout functions remain service-role-only, with RLS and restricted grants. The authenticated player identity comes from the server's token verification, never a submitted user ID or a host message.

For every money-affecting action:

1. Authenticate the player and validate the account's eligibility, game, session, requested action, amount, denomination, balance, phase, and physical-machine reservation where applicable.
2. The client creates and retains a durable operation ID before its first submission, and reuses it after a timeout/reconnect. Scope it to the authenticated account and casino action/session; persist the ID and accepted payload with the server transaction. Repeating the same operation returns its original result. Reusing an ID with a changed payload is rejected. A fresh ID generated on every retry is not duplicate protection.
3. Atomically persist the accepted stake, round state, settlement, account change, and receipt/ledger records as appropriate. Use the existing concurrency controls plus explicit duplicate protection.
4. Return authoritative amounts. The client displays and animates them; it does not choose or calculate the credited amount.

Reject malformed values, numeric strings when the casino action contract requires numbers, negative/zero stakes, NaN/infinity, excessive integers, unknown bet IDs, late edits, and unauthorized actions. Check safe arithmetic and database range before any debit. Reject excessive proposed stake before acceptance; never accept a stake and later cap its legitimate win. Preserve valid existing client requests and old histories through the compatibility plan.

Keep whole shards for this candidate. Store payout ratios as integers/rational values. Where a ratio would create fractional shards, require a compatible bet denomination before accepting the wager and explain it in the UI. No silent rounding, wallet-type migration, or global rescaling.

Use cryptographic server randomness and unbiased mapping. Preserve and extend the existing commitment/client-seed/nonce verification model with versioned rules. Log sufficient data to independently reproduce each settled result. Do not expose a seed that can predict still-open outcomes; persistent shoes and roll sequences need a deliberate disclosure boundary.

Describe exactly what the fairness check verifies. It is an auditable outcome mechanism, not proof that every server behavior is trustworthy. Maintain a separate settlement audit.

Bookkeeping must cover all new game identifiers and machines. Its scope is casino sessions: shards moving between wallets and tables, and the house result. Owner-requested wallet changes outside the casino (the scripts in `dev/supabase/compensation/`, account bonuses, raid rewards) don't go through casino tables and are not casino discrepancies; don't route them through the casino ledger. Extend the game's existing `casino_books` check and `result.house` convention. For each closed session, reconcile deposits, cash-outs, stake outcomes, commissions, and house result; a losing session for the house is valid if it balances. Account for existing poker bot activity separately. A player's pending wager or table stack is a liability, not house profit. Keep the current request-triggered daily books schedule and Eastern day boundary.

Disconnect/exit requirements:

- Hiding a sheet does not cash out or make a player absent. Normal polling and explicit departure are distinct.
- Cash out uncommitted funds once. Accepted in-progress bets resolve under the game's rules and credit the original account, even if the player leaves the room.
- An unaccepted operation must produce no debit; recover an interrupted accepted operation using its persisted ID. Return cancellable pre-start bets. Never refund a settled losing wager automatically.
- Craps Pass/Come wagers with established points remain obligations. Cancellable wagers may be removed under documented rules. If everyone leaves, a server recovery process continues outstanding rolls without accepting new wagers until all obligations settle. Process bounded batches and resume durably; do not impose a roll cap that changes the payout distribution.
- A closed browser or departed host cannot strand a bet waiting for that client's next request. First test and extend the existing server sweep/close path. If it cannot safely finish pending bets with bounded work, specify the smallest casino-only durable recovery mechanism and its operational cost as an implementation prerequisite. `pg_cron` was not enabled in the previous casino plan; do not assume a scheduler exists or prescribe a new hosting stack. Any recovery mechanism must be idempotent and cost-bounded.
- Keep one active seat/activity per account. While departure still has unresolved wagers, show that pending state and prevent moving the same account to another game until the existing activity closes. Enforce this across concurrent requests in the transaction path; a client check or pre-transaction `seatOf` lookup alone is insufficient.
- Show `RETURNED TO WALLET`, `BET STILL RESOLVING`, or a specific recoverable error. A dismissed panel is never evidence that the transaction completed.

## 5. Craps — real rules with approachable controls

Build a shared table supporting six players. The shooter keeps the dice through made points and passes them after seven-out; skip absent shooters safely and use a server dealer when no eligible player is present. A human shooter must have a Pass or Don't Pass wager for the come-out. Dice rolls are server-generated; the throw control triggers presentation and cannot influence the dice. Solo play must work. No participant can freeze betting or settlement indefinitely.

Required bets: **Pass Line, Don't Pass, Come, Don't Come, their odds, Place 4/5/6/8/9/10, Field, Hard 4/6/8/10, Any Seven, Any Craps, individual 2/3/11/12.** Provide a simple view centered on line bets, Field, and Place 6/8, with the complete supported layout in an advanced view. Both operate on the same real rules.

Base rules: come-out 7/11 wins Pass; 2/3/12 loses Pass; other totals establish the point. Afterwards, point before 7 wins Pass, and 7 before point loses. Don't Pass reverses these outcomes, with come-out 12 a push. New line bets are accepted during come-out; new Come/Don't Come bets are accepted while the table point is on. Come and Don't Come have their own traveling points, independent of the table point. Correctly settle traveling bets and newly placed Come bets on the same roll.

Payout defaults below are **profit**. Return principal separately when a winning wager closes. Winning Place and Hardways wagers stay up by default: credit the profit and keep their principal committed, without debiting it again.

| Bet | Profit payout |
|---|---|
| Pass / Don't Pass / Come / Don't Come | 1:1 |
| Pass/Come odds on 4/10, 5/9, 6/8 | 2:1, 3:2, 6:5 |
| Don't odds against 4/10, 5/9, 6/8 | 1:2, 2:3, 5:6 |
| Place 4/10, 5/9, 6/8 | 9:5, 7:5, 7:6 |
| Field 3/4/9/10/11; Field 2/12 | 1:1; 2:1 |
| Hard 4/10; Hard 6/8 | 7:1; 9:1 |
| Any Seven; Any Craps | 4:1; 7:1 |
| Individual 2/12; individual 3/11 | 30:1; 15:1 |

Use 3–4–5× Pass/Come odds limits by point. For Don't odds, limit the potential win to the corresponding 3/4/5× flat bet. Enforce exact denominations, such as Place 6/8 in multiples of six. Offer correctly sized chip presets.

Publish working rules: established Come/Don't Come flat bets work on come-out. Come odds are off on come-out by default; Don't Come odds remain working by default. Allow explicit odds working changes, and return inactive odds when their associated flat wager resolves. Place bets and Hardways are off on come-out by default, with an explicit working toggle. Clearly show ON/OFF.

Established Pass/Come flat wagers cannot be removed or reduced. Don't Pass/Don't Come wagers may be reduced or removed, but their established flat wager cannot be increased or reinstated. Odds may be removed or reduced during unlocked betting. Do not allow put bets in this release. Never apply CLEAR indiscriminately to established Pass/Come wagers. The rules panel must show these restrictions before a player commits.

Show the point puck, shooter, betting lock, roll history, and result breakdown. Place bets and Hardways remain on the layout after a win until removed or lost, as applicable. A roll ending the point must not silently remove unrelated unresolved Come wagers.

Reference: [MGM craps guide](https://www.mgmresorts.com/en/gamesense/guide-to-craps.html), [Rivers working-bet rules](https://www.riverscasino.com/desplaines/casino/table-games/craps), [Cannery bet restrictions and odds](https://cannery.boydgaming.com/play/table-games/craps-gaming-guide), [published MBS craps rules](https://www.gra.gov.sg/docs/default-source/game-rules/mbs/dice-games/craps_mbs_version-2.pdf?sfvrsn=89144289_1), and [RWS payout reference](https://www.gra.gov.sg/docs/default-source/game-rules/rws/dice-games/rws-game-rules---craps-v2.pdf). These sources illustrate real variants; this work order fixes the selected house rules above.

## 6. Baccarat — automatic dealing, exact payouts

Build an eight-deck mini-baccarat table with six betting seats. All seated players bet on the same Player/Banker deal; those names identify hands, not who is hosting or dealing.

Card values: Ace 1, 2–9 face value, 10/J/Q/K zero; total modulo ten. Deal Player, Banker, Player, Banker. Either initial total 8/9 is a natural and ends drawing. Otherwise Player draws on 0–5 and stands on 6/7. If Player stands, Banker draws on 0–5 and stands on 6/7.

When Player draws, Banker drawing is:

| Banker initial total | Draw when Player's third-card value is |
|---|---|
| 0–2 | Any value |
| 3 | Any except 8 |
| 4 | 2–7 |
| 5 | 4–7 |
| 6 | 6–7 |
| 7 | Never |

Profit payouts: Player 1:1; Banker 19:20 after 5% commission; Tie 8:1. A tie returns Player and Banker stakes. Show Banker commission separately. Banker bets must be multiples of 20 shards to preserve exact whole-shard payouts; Player and Tie use whole-shard bets from one. Explain this before the bet is placed, including `20 Banker → 19 profit + 20 stake returned`.

Use a persistent finite shoe, standard burn procedure, and a documented cut-card procedure. Specify their exact selected variant in the rules manifest; finish a hand already started before reshuffling. Do not reshuffle silently after every hand or reveal undealt shoe cards. Lock the contributing player seeds when the shoe is created; later changes and new players' seeds apply to the next shoe. Each hand identifies its shoe and card positions rather than pretending it starts a new shuffle. Verification of the complete shoe can occur after retirement, while per-card commitments preserve immediate checkability without revealing future cards. Update history, last-result, fairness text, and CHECK specifically for this disclosure boundary; do not reuse Blackjack's immediate full-seed reveal.

Animate each dealt card and highlight final totals. Maintain a simple outcome road/history that reports prior results without presenting them as a prediction. Side bets are not required for this release.

References: [MGM baccarat overview](https://www.mgmresorts.com/en/gamesense/guide-to-baccarat.html), [drawing-rule reference](https://static.mgmresorts.com/content/dam/MGM/mgm-national-harbor/casino/table-games/gaming-guides/mgm-national-harbor-casino-table-games-baccarat-royal-9.pdf), and [standard payout reference](https://help.betmgm.co.uk/hc/en-gb/articles/12186035197586-Live-Baccarat).

## 7. Slots — playable cabinets with proven math

Convert the existing decorative cabinets into usable machines. Walk up, press USE, select a bet, and press SPIN. Start with one original Palisade theme and a clearly labeled math version, reused across the cabinets. Each physical cabinet has a server-enforced reservation; separate machines can run independent sessions. Do not serialize the entire casino through one machine's animation. Additional themes are outside first-release acceptance.

Use three reels and one fixed payline. Define versioned reel strips, stop probabilities, winning combinations, and a paytable before implementing payouts. Prefer modest reel lengths so all stop combinations can be enumerated exactly. Include a legible mix of frequent small returns and rare larger returns; publish the maximum payout and calculated hit frequency.

Target 96% theoretical RTP within 0.1 percentage point. This is a project target, not a claimed real-casino standard. Derive and document the final strips/paytable and exact return; do not invent weights until a simulation happens to look close. Use integer gross-return multipliers and whole-shard bets from one. State whether overlapping combinations award the highest match or add; default is highest applicable single-payline award.

Every spin is independent. Neither wallet size, past losses, account identity, room host, nor theme changes its probabilities. Reels stop at the actual sampled stops. Adjacent displayed symbols must match the real strip; do not fabricate near misses after deciding whether a player won.

Provide a short staggered reel stop, winning-line highlight, payout sound, visible paytable, and result receipt. Keep effects restrained on small wins and bounded on the largest award. No autoplay or progressive jackpot in this version.

Reference: [MGM slot mechanics](https://www.mgmresorts.com/en/gamesense/guide-to-slots.html). Palisade themes and mathematical configurations must be original.

## 8. Plinko — visible paths, published multipliers

Add one floor station with a twelve-row board and thirteen pockets. Inspect the multiplier row, select a stake, and DROP. Start with one original, balanced payout table; Low/Medium/High selectors and additional stations are follow-ups. Label it an original online casino-style game; there is no universal traditional Plinko paytable.

Generate twelve independent unbiased left/right decisions on the server. The destination is the number of right decisions. Animate exactly that recorded path; browser physics, frame rate, touch timing, and ball collisions cannot choose or alter the award. Start with one active ball per session.

Version and publish a symmetric payout table. Calculate its return exactly using `P(pocket k) = C(12,k) / 4096`; record variance and maximum return alongside RTP. Enumerate all 4,096 paths in tests. If additional risk settings are later added, verify each separately and retain the same approximate RTP target while varying payout distribution.

Use multipliers in tenths and stakes in multiples of ten shards so every gross return is a whole shard. Display this denomination clearly. `1×` returns the stake, `0.5×` returns half, and a multiplier below one is a net loss even though chips return. Define multiplier values before acceptance and bind them to the receipt's rules version.

Maintain the three-second result window after landing, with pocket highlight and signed net. Reduced motion uses a brief path reveal and landing highlight. Repeat requests, leaving mid-drop, and reconnects recover the same paid result.

Reference: [an established operator's path-based Plinko method](https://stake.com/provably-fair/game-events). Use it as a mechanics reference, not a copied interface, paytable, or claim of identical odds.

## 9. Casino floor and controls

Produce a coherent floor plan before committing geometry. Start inside the existing 16×16 casino, keeping clear routes to all five tables, usable slot cabinets, the Plinko station, bar, cashier, and entrance. Rearrange low-value decoration if needed. If reachable seating and readable presentation cannot fit, document that layout evidence and choose a casino-specific size with the smallest required map/network changes; 24×24 is an option, not a deliverable. Do not change combat map sizes, the shared XL selector, or other modes. Preserve existing room/table IDs and migrate seat representation safely if required.

Keep the red/black/gold palette, brass trim, felt, neon, isometric figures, and the v0.10.1 casino playlist. Game sounds (reel stops, dice, chips, payout cues, the Plinko ball) are Web Audio effects through the existing `sfx()` path, like the current table and case sounds. They play over the playlist without stopping, ducking, or re-routing it; add no new music tracks or large audio files. The playlist already holds up to two decoded tracks (about 290 MiB at peak during a crossfade on a 48 kHz context), so new casino assets must not add decoded-audio memory. Cache static geometry and use bounded animated layers. Reuse readable card and chip components. Distinct signs and dealer presentation should make the new tables identifiable from the floor.

Players enter games by approaching a table or machine; preserve the walk-up interaction and existing bottom sheet. Keep room-code joins, friend invites, and existing Open Games working. The missing **PUBLIC CASINOS** list is a known earlier-plan follow-up, not required here. If separately commissioned, it should reuse public room registration and compatible-protocol filtering, including private/locked-room protection.

Do not repurpose a working seat or cabinet while occupied. Competing sit/use requests have one server winner. Reuse `casRoom()`'s room incarnation and assign stable station IDs. Extend the existing `(room, game)` lookup and uniqueness contract to distinguish physical machines while retaining one shared table per room for each table game. Existing tables receive a compatible default station identity without changing their IDs or historical records. One machine session has one human seat and uses the same accounting/recovery boundaries as the tables; create it lazily when used.

Carry station identity through sit/use, peek, the world view, client preview caches, server lookups, and result/history records. Existing helpers such as `casTable(game)` and `TB.peek[game]` assume one location per game; game-only keys cannot distinguish two slot cabinets. Keep standing-player peeks limited to nearby activity at the existing polling cadence.

The host validates world proximity and relays occupancy; the casino server validates session ownership, station identity, balance, and actions. Do not describe the current server as independently proving a player's physical position. Server reservations still govern competing requests and repeated actions from another tab.

Support desktop keyboard/mouse, touch portrait/landscape, and the existing controller navigation. Betting controls need chip presets, exact increments, readable totals, and deliberate actions to commit bets and start a round. For Craps, ROLL locks only wagers accepted by the server; the shooter cannot approve or edit another player's bets. Do not require dragging chips or hovering. Keep focus stable across polls; never rebuild a touched betting surface unnecessarily. Preserve the no-weapons/no-combat casino mode and existing equipped character appearance.

Provide concise HOW TO PLAY panels and complete HOUSE RULES/paytables. Standard rules may be complex; the controls should explain the currently available action. No implementation terminology or server IDs in ordinary player screens.

## 10. Implementation sequence

1. Capture baseline accounting, result timing, visual layout, and performance. Produce the floor plan and versioned rules/math manifests; resolve any necessary casino-only map/recovery extension before coding it.
2. Fix result review for existing games, including minimum times, receipt persistence, poker privacy, and exits. Verify this independently before adding games.
3. Extend casino operation IDs, station/session ownership, exact payout helpers, settlement/recovery, histories, and accounting coverage within the existing backend.
4. Implement Baccarat and slots, then Plinko, then Craps. Each slice needs rules and transaction evidence before presentation is called complete.
5. Integrate floor/network interaction; finish mobile/controller presentation. Keep the separate discovery/theme/risk-setting follow-ups out of the completion gate.
6. Build the candidate, run required focused suites, perform the shared-system regression pass, and prepare a concrete deployment/rollback packet.

Source lives in `dev/src/`; use the existing builder for generated website assets. Build requirements learned on v0.10.1: `python3 dev/build.py` needs Pillow, and minifies the published `index.html` only when terser is installed (`npm ci` in `dev/test`). Without terser it prints `terser not found` and ships an unminified page; never commit that build. A different Pillow version rewrites the icon PNGs byte-for-byte. Don't commit icon changes unless the icons were meant to change. Add source files at deliberate positions in the shared-scope assembly and update `dev/src/js/ORDER.txt`. Keep rules, dispatch, and UI modules understandable; avoid growing one giant conditional for seven games.

Extend the current database through reviewable migrations, and keep `dev/supabase/schema.sql` able to restore the resulting casino schema into an empty test project. Pin any added dependency and keep lockfiles. Prefer the existing runtime and Canvas over new heavyweight libraries. Coordinate backend/client/protocol versions. The reference checkout uses `PROTO='yard-28'` with `ROOM_PREFIX='palisade-yard-27-'`; follow the project's compatibility rule when new station identities or message semantics require a bump, coordinate both deliberately, and verify incompatible clients are refused. A new displayed footer does not establish backend or network compatibility. Old database rows and history remain readable; resolve outstanding sessions before removing support for their rules version.

## 11. Required verification

Run tests against fresh builds. Register new suites in `suite.txt`; use the current runner and condition-based waits, not fixed sleep chains. Use isolated accounts, fixtures, and disposable/local database tests; do not run wager tests against real players.

**Rule/math tests:** Baccarat naturals and every Banker third-card decision, ties, commission, finite-shoe boundaries; all 36 Craps dice outcomes for each supported wager and phase, traveling Come interactions, working toggles, locked-bet cancellation, odds limits, and payouts; exact enumeration of slots and Plinko plus independent verification of return calculations.

**Money/concurrency tests:** repeated and changed-payload operation IDs, simultaneous top-ups/bets/cash-outs, stale snapshots, two tabs racing for different games, two accounts racing for the same station, multiple cabinets of the same game, insufficient balance, rejected denomination, request timeout after commit, server restart, duplicate settlement, leaving before/after outcome, hidden tab, host departure, and unattended recovery. Verify the one-activity invariant, machine uniqueness, service-only payout access, existing-row compatibility, and no offline wagers. Prove the settlement equations, not merely matching client labels.

**Result tests:** Blackjack remains in review across repeated ticks; no zero-time cleanup; all-ready cannot bypass minimum reading time; the full reading period remains after the final animation/reveal; split/insurance/side-pot evidence is accurate; gross versus net is correct; late/reconnecting players can review receipts; hidden poker cards remain absent from all unauthorized payloads.

**UI/network tests:** 1366×820 desktop, 390×844 portrait, 844×390 landscape; readable rules and cards, no clipped actions, stable focus, keyboard/controller navigation, touch targets, reduced motion, six-player activity across different stations, concurrent seat races, existing Open Games, code join, and invitation compatibility. Walk from the entrance to every playable seat/station and back; test entry/exit does not change the selected combat mode or its map sizes.

**Regression:** existing `tables_engine`, `tables_server`, `roulette_engine`, `fair_play`, `tables_ui`, `casino_map`, accounts, history, `casino_music` (plus `music_routing` if casino entry or `game.gid` handling changes), `csp`, tab order, and relevant networking tests. Include focused migration and empty-schema restore coverage because schema/transaction changes are expected. Follow the project's current targeted-test rule: expand testing for touched shared code or a concrete regression risk; run the full default suite only when that evidence justifies it. Record exactly which suites ran and keep unrelated pre-existing failures distinct. Baseline failures on `ca90257`: `v090` and `controller` (see the header). `v090` fails inside the casino's standard-layout check. If the floor-plan work touches `layCasino()` or the casino's stake handling, fix it or report how the failure changed; don't count it as a new regression or as passing.

**Performance:** compare against the captured casino baseline on the same machine/browser, with music on so the baseline includes the v0.10.1 playlist (one decoded track, two during a crossfade). Report median and p95 frame time, memory, network volume, and request rates. Target 60 FPS desktop / 30 FPS phone; document the hardware. No unbounded particles, receipts in client memory, retries, or per-frame account polling. Recheck on a physical phone before claiming phone certification.

## 12. Deliverables and acceptance

Deliver:

- All four fully playable games, existing-game result review, and reachable floor interactions in the existing casino or a justified casino-only layout adjustment.
- Versioned rules/paytables/math report with exact payout examples, RTP evidence for custom machines, supported bets, limits, cancellation rules, and fairness disclosure boundaries.
- Reviewable schema/function changes, operation and session contracts, durable result history, and accounting/recovery tests.
- Desktop/portrait/landscape screenshots, short clips showing final evidence held on screen, measured performance, and the selected verification results with their coverage stated accurately.
- Updated STATUS, the footer version, developer/user documentation, source order, and a deployment order, compatibility plan, and rollback plan that preserves outstanding wagers and original receipts.
- Deployment check: GitHub Pages builds can wait in a queue for 10+ minutes, and one earlier build was cancelled without logs. The client is live only once the published page shows the new footer and the service worker lists the expected asset URLs. Deploy and verify the backend functions and migrations before the client that depends on them.

Completion means a player can walk up, understand the stake, play by authentic selected rules, see why the result occurred, and leave with every shard accounted for. Each game must survive a duplicate request, network interruption, and room exit without duplicate awards or stranded funds. Report remaining limitations plainly; do not call the release complete while one of the four games is a mockup or its economics are unverified.

## Scope audit record — October 5, 2026 (revised October 6)

Reviewed against the local casino code at `ca90257`, [current casino status](../STATUS.md), [the original casino decisions](casino-map-and-roulette-work-order.md), [build/save/network rules](../README.md), and [project release boundaries](../PROJECT_BLUEPRINT_2026-09-29.md). Older release claims in general documentation were treated as historical context.

Corrections incorporated: removed mandatory map enlargement, extra themes/stations, public discovery, extra Plinko risk settings, and automatic full-suite testing; made the existing browser architecture, saved-account requirement, one-activity rule, five-shard buy-in, station database identity, service-only authority, and schema restore contract explicit. Result timing now begins after the final reveal, and new game payouts go through the existing table-stack accounting. Background recovery is a bounded casino dependency to prove, not an assumed new infrastructure project.

Scope verdict: fits the project after these corrections. Craps persistence/exit recovery and Baccarat shoe disclosure remain the main implementation design risks. This was a document/code-contract audit; no gameplay implementation, live database queries, live changes, or gameplay test runs were part of it.

October 6 revision: re-checked against `ca90257` (v0.10.1, published). Added the casino playlist as a fixed contract (routing, sound effects through `sfx()`, decoded-audio memory, `casino_music` regression); the baseline `v090`/`controller` failures; the casino-only scope of the books check, given the out-of-band compensation scripts; build and Pages-deploy lessons from the v0.10.1 release; and an explicit footer/STATUS version step. Spot-checked code claims still hold: `PAUSE_MS=0`, immediate full reveal for non-Hold'em games in `lastView()`/`histRow()`, the one-open-row `(room, game)` index, `lobby` returning only balance and existing seat, close-on-no-humans in `handler.js`, and `PROTO='yard-28'` / `ROOM_PREFIX='palisade-yard-27-'`. No gameplay was implemented and nothing live was changed.
