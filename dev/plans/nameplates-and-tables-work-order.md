# v0.9.8 work order: NAMEPLATE HEALTH + THE TABLES

| | |
|---|---|
| **Status** | Plan. Written October 4 from Big U's request. **Open decisions at the bottom (H1–H5, T1–T9)**; nothing is built yet |
| **Build** | v0.9.8. Part A (nameplates) is client only. Part B (the Tables) adds a server migration (Big U approves before it's applied) |
| **Protocol** | Part A: `yard-27` → `yard-28` only if nameplate data needs new fields (it shouldn't: hp, max, alive and downed already sync). Part B never touches the match protocol; it's menu only |
| **Scope** | The in-match HUD in **every mode**; a new main-menu tab with Blackjack and Texas Hold'em played for shards |
| **Risk** | A: medium (every mode's HUD, and every layout measured from it). B: **high**, because it moves the main currency. Treated as an economy feature with server authority, an audit trail and simulation-proven odds, not as a minigame |

## Tickets

| ID | Title | Severity | Area |
|---|---|---|---|
| PAL-098-1 | Health moves from the top-left panel to bars above each player's name | Feature | HUD / rendering |
| PAL-098-2 | What else lived in that panel: core health, Delgado's command button, the ready ticks | Feature (blocker for 1) | HUD |
| PAL-098-3 | TABLES tab: lobby, shard wallet, limits | Feature | Menu / UI |
| PAL-098-4 | Blackjack (4-deck shoe) | Feature | Server + client |
| PAL-098-5 | Texas Hold'em | Feature | Server + client |
| PAL-098-6 | Fairness, anti-exploit and economy guard rails | **Blocker for 3–5** | Server |

---

# PART A: NAMEPLATE HEALTH

## PAL-098-1: Health above the name, not in the corner

**Request (Big U):** remove the whole health section in the top left during matches. Show your health and your team's health above each player's name.

**Today (`page.html` `#top .vitals`, `11-hud-chat.js` `mateRows()`):** the panel holds
- **YOU**: your bar and number;
- **one row per teammate** (`#mates`): name, a bar in their slot colour, the number or DOWN, and the ✓ during Black Out's ready stage;
- **DELGADO**: his bar, plus the **DELGADO · FOLLOW** command button (`#qmCommand`);
- **CORE / COMMAND**: the core's bar (Main Command in Black Out), and **ENEMY** (the enemy core in base PvP).

In the world, teammates already carry a name tag (`17-scenery.js`: `tag = o.name`, hidden for yourself and in solo), and Delgado carries "DELGADO". A small red bar appears over a figure only once it's hurt (`hp < 1`, drawn at −41 px); enemies use the same bar.

**Measured cost of the panel:**
- desktop 1366×820: 300×122 px top left;
- portrait 390×844: 187×123 px, half the top row;
- landscape 844×390: 190×205 px, half the left edge, bottom left.

**Fix spec:**
- **Nameplate:** each player figure gets a plate above the head: name on top (as now), a health bar under it, about 34 px wide at 100% zoom, scaling with zoom between 26 and 44 px so it stays readable on phones and doesn't balloon on desktop zoom-in.
  - **You:** the bar shows above your own head too, without a name (you know who you are), plus the number (115). It's the one bar you read under pressure, so it's the largest: about 40 px.
  - **Teammates:** name in their slot colour, bar in their slot colour. Always shown, not only when hurt.
  - **Delgado:** "DELGADO" with his bar.
  - **Low health** (under 30%): the bar pulses red; for you, the screen edge also gets a faint red vignette, so you notice without looking at your feet.
  - **Downed:** the bar is replaced by the revive ring and "DOWN · 12" (the existing downed label), in red.
  - **Ready stage (Black Out):** the ✓ moves next to the name on the plate.
- **Teammates off screen:** a small arrow on the screen edge in their slot colour with a 3 px health sliver, so you still see a teammate dying across the map. A downed teammate's arrow blinks red. (This replaces the panel's one real advantage: seeing everyone's health at a glance.)
- **Enemies and bosses:** unchanged (their red hurt bar, the boss bars at the top).
- **PvP:** the opposing team's plates show their names but **no health bar** (as in most shooters); your own team as above.
- **Draw order:** plates are drawn after the scenery's front layer, so a building never hides a teammate's health (today's tag is drawn with the figure and can be covered).
- **Size check:** with 6 players stacked in a doorway, plates may overlap; they nudge apart vertically (up to 2 rows) rather than overprint.

## PAL-098-2: What else lived in that panel

Removing the panel removes four things that aren't player health. Each needs a home **before** the panel goes:

| Item | Proposal | Decision |
|---|---|---|
| **Core health** (CORE, COMMAND in Black Out) | A slim bar under the timer in the phase box ("COMMAND 500"), and the core's own bar in the world (as POIs already have) | H2 |
| **Enemy core** (base PvP) | Second slim bar under yours in the phase box, in red | H2 |
| **DELGADO · FOLLOW** button | A small round button at the edge of the build kit (phones) / `F`-key hint on desktop, as it works today | H3 |
| **Ready ✓ list** (Black Out) | On each plate, plus "READY 2/4" already in the phase box | none |

**Layout knock-on (done in the same ticket):** everything measured from `#top .vitals` must be re-measured without it:
- the v0.9.7.3 banner placement (`toastPlace`, desktop "deskRow" uses the vitals' right edge → the banner can centre on the screen instead);
- the tip box (`hud.topB`);
- the boss bars (`drawBossBars`, from `hud.topB`);
- the portrait mini-map;
- the landscape bottom-left, which becomes free (joystick room).

**Acceptance criteria (A):**
- [ ] In every mode (Raid, Blitz, Whiteout, Black Out, PvP base and arena), at 1366×820, 390×844 and 844×390, no health panel shows during a match; it still shows nowhere else either (the panel only ever existed in matches).
- [ ] Your health, every teammate's and Delgado's are readable above their heads at 70%, 100% and 140% zoom; numbers match the old panel's exactly (same source values).
- [ ] An off-screen teammate shows an edge arrow with health; a downed one blinks.
- [ ] Core health (and the enemy core in PvP) is visible at all times, and is the same number the old bar showed.
- [ ] Delgado's follow/hold command works from its new place by touch, mouse, key and controller.
- [ ] Banner, tip, boss bars and mini-map overlap nothing at the three sizes (the v0.9.7.3 checks re-run).
- [ ] `blackout_perf` stays within its gate with 6 plates and 60 raiders.

**Tests:** new `nameplates` (draw hooks report each plate's position, value and colour; edge arrows; downed; PvP enemy plates without health; zoom sizes). Update `hud_layout`, `toast_queue`, `blackout_hud`, `tips_toggle`, and any test reading `#hpN` / `#mates`.

---

# PART B: THE TABLES

## Ground truth (live database, October 4)

| | |
|---|---|
| Accounts with a locker | 59 |
| Median shard balance | **0** |
| Average | 9 |
| Richest | 207 |
| All shards in the game | **513** |
| A case costs | 10–14 shards; a respec 40 |
| A City Black Out win pays | about 75 shards |

The economy is tiny. One player winning 200 shards at the tables would hold more than a third of all shards in existence. **Stakes must be small, and the guard rails in PAL-098-6 aren't optional.**

**Shards are not real money and must stay that way.** They can't be bought or cashed out, so this is simulated gambling, not gambling. Hard rule for every future build: never sell shards (or anything that converts to them) for money, and never let them leave the game. If PALISADE ever ships on an app store, the Tables raise the age rating ("simulated gambling").

## PAL-098-3: The TABLES tab

- **Menu:** a new tab in the main nav, **TABLES**, next to Locker. Signed-in players only (guests see the tab with "Sign in to play at the tables", because shards live on the server).
- **Lobby screen:** your shard balance; two tables, **BLACKJACK** and **HOLD'EM**, each showing its limits and the house edge in plain words ("The house keeps about 0.3 of every 100 shards bet over time"); your session result (+/−) and today's.
- **Look:** the game's own style: dark felt, stencil type, bone-white cards drawn on canvas (no card images to download), a chip rack in shard colours. Works by touch, mouse, keyboard and controller (Tab order and Big Shoulders labels as the rest of the menu).
- **Music:** the menu track keeps playing; card and chip sounds from the existing sound set.
- **Limits** (all server-enforced; proposal, T5):
  - minimum bet 2 shards, maximum 20 per hand;
  - net result capped at **±100 shards per day** per account: once you're up 100 or down 100 today, the tables close for you until midnight Eastern.

## PAL-098-4: Blackjack

**Rules (proposal, T2):** the standard "good" casino table, with nothing exotic:
- **4 decks** (208 cards), as Big U asked;
- dealer **stands on soft 17**;
- blackjack pays **3:2**;
- double on any first two cards, **double after split** allowed;
- split up to 3 times (4 hands), one card to split aces, no resplitting aces;
- **late surrender** allowed;
- **insurance not offered** (it's a 7%-edge side bet that only exists to take money from players who don't know better);
- no side bets.

**House edge:** with perfect basic strategy, these rules give the house **about 0.2–0.3%**: about 1 shard in every 300–500 bet. A player who doesn't know basic strategy loses more (typically 1–2%), which is the right shape: skill helps, nobody beats it. The exact figure comes from the simulation in the tests, not from this document.

**Why nobody gets an advantage (the shuffle):**
- In a real casino, card counters beat 4-deck games because the shoe is dealt down to a cut card and the remaining cards become rich in tens and aces.
- **Here the 4-deck shoe is reshuffled before every hand.** That makes counting worthless; the odds of every hand are the same as the first hand of a fresh shoe. (This is what online casinos do.)
- With no counting, perfect basic strategy is the best any player can do, and it still loses 0.2–0.3% over time. **No player has a long-run edge.**

**Bets in steps of 2 shards,** so 3:2 always pays a whole number (a 2-shard blackjack pays 3).

**Flow:** bet → server deals (your two cards, the dealer's up card; the hole card stays on the server until the dealer plays) → hit / stand / double / split / surrender → dealer plays → settle. Your balance changes on the server at the deal (stake taken) and at settlement (winnings paid). Leaving mid-hand: the hand stays open for 10 minutes, then the server stands for you and settles it.

## PAL-098-5: Texas Hold'em

**One deck, not four.** Hold'em has to use a single 52-card deck. With 4 decks you could hold the same card twice, five of a kind would exist, and a flush would get much easier than a full house; every hand ranking and every odd players know would be wrong. 4 decks is right for Blackjack and wrong for poker. Hold'em is dealt from a fresh, shuffled 52-card deck every hand.

**Against whom? (T1, the big decision.)** With 59 accounts and rarely more than a few online, real-player tables would mostly be empty. Three ways to do it:

| Option | How it plays | Edge | Can anyone farm it? | Build |
|---|---|---|---|---|
| **A. Hold'em vs the dealer** (recommended) | You and the dealer each get two cards; you bet before the flop, after the flop and on the river, or fold; best five of seven wins. These are the rules of the casino game *Ultimate Texas Hold'em*. Pay table on the blind bet for big hands | Standard pay table: about 2.2% of the ante. **We tune the pay table** by simulation to about **0.5–1%** (the "as even as possible" ask) | No: fixed odds, like Blackjack | Medium |
| **B. Real-player tables** | 2–6 signed-in players at a table, dealt by the server, blinds, turn timer | 0% house edge between players; a 2.5% rake (capped) as a shard sink | **Yes, via chip dumping:** an alt account loses on purpose to move shards to a main account. Needs detection and caps | Large: live seats, turn timers, disconnects, realtime |
| **C. Vs bots** | You against 1–5 computer players | Depends on the bots: weak bots get farmed by good players; strong bots are hard to build | **Yes:** whoever finds the bots' leaks prints shards, the thing Big U ruled out | Large |

Recommendation: **A now**, and B later if the player count grows. It meets "nobody gets an advantage" exactly, it works solo at 3 a.m., and its odds can be measured and tuned like Blackjack's.

**Option A rules (proposal):**
- **Ante and blind** (equal, each 2–10 shards).
- **Before the flop:** check, or **play** 3× or 4× the ante.
- **After the flop:** if you checked, check or play 2×.
- **On the river:** if you still checked, play 1× or fold (folding loses the ante and blind).
- **Dealer qualifies** with a pair or better; if not, the ante pushes.
- **Blind pays** on a winning straight or better per the tuned table (the standard table, as a starting point: royal 500:1, straight flush 50:1, four of a kind 10:1, full house 3:1, flush 3:2, straight 1:1).
- **No Trips side bet** (high edge, same reason as insurance).
- **Whole shards:** the 3:2 flush payout needs the blind to be even, so blinds are in steps of 2.

## PAL-098-6: Fairness, anti-exploit and economy guard rails

**The server deals everything.** The browser never sees an unrevealed card and never decides an outcome.
- New tables: `casino_hands` (one row per hand: game, stakes, the shuffled deck, revealed cards, actions, result, timestamps) and `casino_daily` (per account, per Eastern day: hands, wagered, net).
- **RPCs** (security definer, like `buy_case`): `bj_deal`, `bj_act`, `uth_deal`, `uth_act`, `tables_state`. Each checks the caller, the hand's state machine (no acting twice, out of turn or on a settled hand), the limits and the balance, in one transaction with the locker row locked (`for update`), so a double tap or two tabs can't bet the same shards twice.
- **Shuffling:** `pgcrypto`'s `gen_random_bytes` (a cryptographic random source), Fisher–Yates with rejection sampling (no modulo bias). Never `random()`.
- **Hidden cards stay hidden:** RPC replies contain only cards that are face up. The dealer's hole card and the rest of the deck are never sent until revealed.
- **Provably fair (proposal, T7):** at the deal, the server shows a hash of the shuffled deck; after the hand, it shows the deck. Anyone can check the hand was dealt from the deck it committed to. Cheap to add, and it answers "the house is rigged" for good.
- **Rate limit:** at most one hand every 2 seconds per account (stops scripted grinding and hammering).
- **Abandoned hands:** settled by the server after 10 minutes with the default action (Blackjack: stand; Hold'em: fold if a decision is pending). Refreshing never undoes a dealt hand.
- **No `delete` anywhere** in the migration (project rule); old hands are kept as the audit log.
- **Economy:** the house edge is a slow shard sink (good for a currency that only inflates). The daily ±100 cap keeps one lucky night from swallowing the economy. Every hand is in `casino_hands`, so a runaway balance can be checked.
- **Watch list for Big U:** a short SQL report (in `dev/supabase/reports/`) showing total wagered, house result, and the top winners/losers for any day.

## Acceptance criteria (B)

- [ ] **Simulated odds:** a 50-million-hand simulation (perfect basic strategy) puts Blackjack's house edge at the documented figure ±0.02%; Hold'em vs the dealer's tuned table at the documented figure ±0.05%, using optimal play. The figures are printed on the tables screen.
- [ ] **Deck integrity:** every dealt hand's cards come from its committed deck, in order; 1 million shuffles pass a chi-squared uniformity test on card positions.
- [ ] **Counting is useless:** blackjack edge measured separately for hands dealt after high-card-heavy hands and low-card-heavy hands is the same within noise.
- [ ] **No double spends:** 50 parallel bets from one account with a 20-shard balance place exactly one.
- [ ] **No peeking:** no RPC reply contains an unrevealed card (checked over 100,000 hands).
- [ ] **Limits:** min/max bet, step, rate limit and the daily cap are refused server-side with a clear message, whatever the client sends.
- [ ] **Abandon:** a hand left open 10 minutes is settled with the default action, and the balance is right.
- [ ] Every hand's balance change equals its recorded result (ledger check over the whole test run).
- [ ] The tab works at the three sizes, by touch, mouse, keyboard and controller.

**Tests:** `tables_migration` (PGlite, like `blackout_migration`: every RPC, every refusal, the parallel-bet race, the abandon sweep, migration applies twice, no `delete`); `tables_sim` (the odds and shuffle statistics, run against the same SQL so the numbers are the server's, not a JS copy's); `tables_ui` (screens, flows, sizes, inputs).

---

## Release plan

1. **Part A** first (client only): PAL-098-2 homes, then PAL-098-1 nameplates; layout tests re-run. Ships on its own as v0.9.8.0.
2. **Part B:**
   1. migration and tests locally; the simulation sets the final pay table and edge figures;
   2. Big U approves the migration;
   3. apply live;
   4. client tab ships as v0.9.8.1.
3. Full suite each time; screenshots at three sizes in `dev/evidence/v0.9.8/`.

## Decisions for Big U

| # | Question | Proposal |
|---|---|---|
| H1 | Show your **own** health number above your head, or the bar only? | Bar plus number for you; bar only for others |
| H2 | Core health (and PvP's enemy core): where? | A slim bar under the timer in the phase box, plus a bar over the core in the world |
| H3 | Delgado's FOLLOW/HOLD button: where? | A small button at the top of the build kit on phones; key/controller hint on desktop as now |
| H4 | Off-screen teammates: edge arrows with a health sliver? | Yes |
| H5 | PvP: hide the enemy team's health bars (names only)? | Yes, hide them |
| T1 | Hold'em against whom: the dealer (A), real players (B), or bots (C)? | **A**, dealer; B later if players grow |
| T2 | Blackjack rules as listed (S17, 3:2, DAS, late surrender, no insurance, reshuffle every hand)? | Yes |
| T3 | Hold'em with one deck, not four (four breaks poker's hand rankings)? | One deck |
| T4 | Hold'em's target house edge after tuning the pay table? | About 0.5–1% (standard is 2.2%) |
| T5 | Bet limits: 2–20 per Blackjack hand, 2–10 ante/blind in Hold'em, steps of 2? | Yes |
| T6 | Daily net cap ±100 shards per account? | Yes |
| T7 | Provably fair (deck hash shown before, deck revealed after)? | Yes |
| T8 | Signed-in only (guests can't play)? | Yes; guest shards are local and can't be trusted |
| T9 | Ship Part A first, on its own? | Yes |
