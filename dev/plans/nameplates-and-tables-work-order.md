# v0.9.8 / v0.9.9 work order: THE TABLES + NAMEPLATE HEALTH

| | |
|---|---|
| **Status** | Plan. Written October 4 from Big U's request. **All decisions made by Big U on October 4 (H1–H5, T1–T9, R1–R5).** Part B (the Tables) built as v0.9.8; Part A (nameplates) next as v0.9.9 |
| **Build** | **v0.9.8 = the Tables first** (Part B; server migration, Big U approves before it's applied). **v0.9.9 = nameplates** (Part A, client only) |
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
  - **You (H1):** the bar shows above your own head too, without a name, **plus the number (115). Only you get a number**; everyone else's plate is a bar. Yours is the largest: about 40 px.
  - **Teammates:** name in their slot colour, bar in their slot colour. Always shown, not only when hurt.
  - **Delgado:** "DELGADO" with his bar.
  - **Low health** (under 30%): the bar pulses red; for you, the screen edge also gets a faint red vignette, so you notice without looking at your feet.
  - **Downed:** the bar is replaced by the revive ring and "DOWN · 12" (the existing downed label), in red.
  - **Ready stage (Black Out):** the ✓ moves next to the name on the plate.
- **Teammates off screen (H4):** a small arrow on the screen edge in their slot colour **with their name**; a downed teammate's arrow **blinks red**. No health sliver.
- **Enemies and bosses:** unchanged (their red hurt bar, the boss bars at the top).
- **PvP:** the opposing team's plates show their names but **no health bar** (as in most shooters); your own team as above.
- **Draw order:** plates are drawn after the scenery's front layer, so a building never hides a teammate's health (today's tag is drawn with the figure and can be covered).
- **Size check:** with 6 players stacked in a doorway, plates may overlap; they nudge apart vertically (up to 2 rows) rather than overprint.

## PAL-098-2: What else lived in that panel

Removing the panel removes four things that aren't player health. Each needs a home **before** the panel goes:

| Item | Proposal | Decision |
|---|---|---|
| **Core health** (CORE, COMMAND in Black Out) | **A slim bar under the timer** in the phase box ("COMMAND 500") (H2) | decided |
| **Enemy core** (base PvP) | Second slim bar under yours in the phase box, in red | decided (with H2) |
| **DELGADO · FOLLOW** button | **A small button, shown only to the host** (H3); key and controller hint on desktop as today | decided |
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
- [ ] An off-screen teammate shows an edge arrow with their name; a downed one blinks red.
- [ ] Core health (and the enemy core in PvP) is visible at all times, and is the same number the old bar showed.
- [ ] Delgado's follow/hold button shows only for the host and works by touch, mouse, key and controller.
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
| A case costs | 10–14 shards (Hybrid Theory 12, Flag 10); a respec 40 |
| A City Black Out win pays | about 75 shards |

The economy is tiny, so every number below is checked against it.

**Shards are not real money and must stay that way.** They can't be bought or cashed out, so this is simulated gambling, not gambling. Hard rule for every future build: never sell shards (or anything that converts to them) for money, and never let them leave the game. If PALISADE ever ships on an app store, the Tables raise the age rating ("simulated gambling").

## PAL-098-3: The TABLES tab and table lobbies

- **Menu:** a new main-nav tab, **TABLES**. Signed-in players only (T8); guests see "Sign in to play at the tables".
- **Tables are lobbies, like matches:** a host opens a table, picks the game and the settings, and others join by code, by invite, or from a browse list. Max seats: Blackjack 5, Hold'em 6.
- **Table settings (host, before the first hand; T5):**
  - **Game:** Blackjack or Hold'em.
  - **Limit:** **100**, **250** or **No limit**: the biggest single bet, **in shards** (R1). No chips: you play with straight shards.
  - **Buy-in: 5 shards** to sit down. That's your starting table stack, and you can add more shards to it at any time between hands (unlimited, R4). Bets come out of your table stack.
  - **Side bet** on or off (T2, R2).
- **Cards are dealt automatically (T1):** no deal button. After a hand settles there's a 5-second pause, then the next hand deals to everyone seated.
  - Blackjack: a 12-second betting window; anyone who hasn't bet sits that hand out.
  - Your turn has a 20-second timer; on timeout Blackjack stands, Hold'em checks if it can, otherwise folds.
  - Sitting out 3 hands in a row stands you up and cashes you out.
- **Leaving:** you can stand up between hands and your table stack goes back to your balance. Leaving mid-hand folds (Hold'em) or stands (Blackjack), and the hand settles normally.
- **Rebuy / top up:** unlimited (R4): add shards to your table stack between hands, as many times as you like.
- **Screens:** felt table, seats round it with names and stacks, your cards large at the bottom, the action buttons, the pot, a hand-history strip, and a results card when you stand up (brought / left with / net). Same style as the rest of the game: stencil type, cards drawn on canvas, a chip rack in shard colours. Touch, mouse, keyboard and controller.
- **Chat:** the existing lobby chat, at the table.

## PAL-098-4: Blackjack (traditional rules, 4-deck shoe)

**Rules (T2: traditional):**
- 4 decks (208 cards), **reshuffled before every hand** (so card counting is worthless; see below);
- dealer stands on soft 17 and **peeks** for blackjack when showing an ace or a ten;
- blackjack pays **3:2**;
- double on any first two cards; double after split allowed;
- split up to 3 times (4 hands); one card to split aces;
- **insurance and even money offered** (traditional; insurance pays 2:1);
- no surrender (traditional table).
- Everyone at the table plays against the dealer, not against each other. Up to 5 players.

**House edge:** with perfect basic strategy, about **0.4–0.5%** (1 shard in every 200–250 bet). Insurance on its own is a poor bet (about 7% to the house); it's offered because it's traditional. The exact figure is set by the simulation in the tests.

**Why nobody gets an advantage:** card counters beat 4-deck shoes in real casinos because the shoe is dealt deep and the cards left become rich in tens and aces. Reshuffling every hand removes that; perfect basic strategy is the best anyone can do, and it still loses slowly. No bots are needed at Blackjack.

## PAL-098-5: Texas Hold'em (one deck, real players)

- **One 52-card deck,** shuffled fresh every hand (T3).
- **Players (T1):**
  - **2 real players:** a bot takes a third seat.
  - **3 or more:** real players only. When a third person sits down, the bot finishes the hand it's in and leaves.
  - **1 player alone:** see R3.
- **Standard no-frills Hold'em:**
  - **Blinds:** 1 / 2 shards; you need at least the 5-shard buy-in at the table to be dealt in;
  - **Button:** the dealer button moves each hand;
  - **Betting:** pre-flop, flop, turn, river; check, bet, call, raise, fold, all-in;
  - **Bet sizes:** up to the table's limit, in shards (100, 250, or your whole table stack at No limit);
  - **Pots:** side pots for all-ins;
  - **Showdown:** split pots on ties, cards shown in the standard order, and a loser may muck.
- **House cut (T4: 1.8):** players play against each other, so the house's share is a **1.8% rake** on each pot that sees a flop (R5), capped at 6 shards per pot, rounded down to whole shards (a pot under 56 shards pays no rake). It's a slow shard sink and the only house edge at this table.
- **The bot:**
  - **Bankroll:** it buys in with house chips. Shards it wins disappear (a sink); shards it loses are paid by the house.
  - **Strength:** it plays a solid, standard strategy: a starting-hand chart by seat, and bets after the flop from its hand's real winning chances against two random hands (simulated), with some randomness so it can't be read by a pattern.
  - **Not farmable on purpose:** a strong player can beat any bot over time. Two guard rails stop that from printing shards:
    - the bot sits with the 5-shard buy-in and tops up like a player; across all tables it can lose at most 25 shards a day;
    - after that, two-player tables wait for a third human.
- **Hand rankings:** checked by an evaluator that's tested against every one of the 2,598,960 five-card hands (exact counts per rank).

## PAL-098-5b: The side bet (T2)

**What Big U asked for:** if someone gets **double aces**, or someone has a **full house**, they get **10 Hybrid Theory Cases or 15 Flag Cases**.

**The numbers that decide how it works.** 10 Hybrid Theory Cases are worth 120 shards; 15 Flag Cases are worth 150. All the shards in the game add up to 513.

| Hit | How often | Value per hand if it pays 10 Hybrid (120) | If it pays 15 Flag (150) |
|---|---|---|---|
| Blackjack: first two cards both aces | 1 in 179 | 0.67 shards | 0.84 shards |
| Hold'em: dealt pocket aces | 1 in 221 | 0.54 shards | 0.68 shards |
| Hold'em: finish with a full house or better (7 cards) | **1 in 36** | **3.35 shards** | **4.19 shards** |

- **Free (just for playing):** a 3-player Hold'em table deals about 60 hands an hour. Each player would hit a full house about 1.7 times an hour, which is about **17 Hybrid Theory Cases an hour per player**, and players could farm it with the minimum bet. That's the "printing easy money" Big U ruled out.
- **As a paid side bet** (each hand you choose to pay 1 shard into it; recommended):
  - **Double aces (either game) → 10 Hybrid or 15 Flag:** the house keeps 16–46% of side-bet money. That's normal for casino side bets, and it's a big shard sink.
  - **Full house → 10 Hybrid / 15 Flag:** every shard put in returns 3.35–4.19 shards, so it prints cases. Recommended: **full house or better pays 3 Hybrid or 3 Flag** instead. 3 Hybrid is almost exactly even (the player is 0.6% ahead); 3 Flag gives the house 16%.
  - The winner picks Hybrid or Flag when it hits.
- **Decided (R2: "I want fun"): Big U's amounts as asked.** A 1-shard side bet each hand (on or off per table). Double aces (either game) **or** a full house or better pays **10 Hybrid Theory or 15 Flag Cases**; the winner picks. Over time a full-house side bet pays out about 3 to 4 shards' worth of cases for every shard put in, so the Tables will hand out a lot of cases; Big U accepted that. The weekly report watches cases granted.

## PAL-098-6: Fairness, anti-exploit and economy guard rails

**The server runs the tables.** Not a player's browser, and not the host. The match netcode lets the host simulate the game; for shards that would let a host deal themselves aces.
- **Tables:**
  - `casino_tables`: settings, seats, stacks, the current hand's state, turn deadline;
  - `casino_hands`: one row per hand: deck commitment, the revealed deck after, actions, pots, rake, results;
  - `casino_ledger`: every shard in and out: buy-ins, cash-outs, side bets, case grants.
- **RPCs** (security definer, like `buy_case`): `table_open`, `table_join`, `table_leave`, `table_settings`, `table_act` (bet, hit, stand, double, split, insurance, check, call, raise, fold), `table_state`. Each:
  - checks the caller, the seat, whose turn it is and the limit;
  - runs in one transaction with the locker row locked (`for update`), so double taps and two tabs can't spend the same shards twice.
- **Sync:** clients poll `table_state` about once a second (as the friends list polls today); the reply holds only what that player is allowed to see. Turn timeouts and the auto-deal are applied by the server on the next request after the deadline passes, so a table never stalls and no background job is needed.
- **Shuffling:** `pgcrypto` `gen_random_bytes` (cryptographic), Fisher–Yates with rejection sampling (no modulo bias). Never `random()`.
- **Hidden cards stay hidden:** other players' hole cards, the dealer's hole card and the rest of the deck are never sent until revealed.
- **Provably fair (T7):** at the deal, the table shows a hash of the shuffled deck; after the hand, the deck itself. Anyone can check the hand came from the deck it committed to.
- **Chip dumping** (losing on purpose to move shards from an alt account to a main one): with no daily cap (T6) and unlimited top-ups (R4), nothing in the rules bounds it. Every transfer is in the ledger, and Big U's report flags any pair of accounts that keeps sitting together with one-sided results.
- **No `delete`** anywhere in the migration (project rule); old hands are the audit log.
- **Report for Big U** (`dev/supabase/reports/tables.sql`): shards bought in, cashed out, raked, side-bet in/out and cases granted, per day and per account.

## Acceptance criteria (B)

- [ ] **Odds check** (quick, against the server's own SQL): 1 million Blackjack hands with basic strategy land near the documented edge; side-bet hit rates match the table above ±10%.
- [ ] **Hand evaluator:** exact counts for all 2,598,960 five-card hands; best-of-seven agrees with a brute-force check on 100,000 random deals.
- [ ] **Deck integrity:** every hand's cards match its committed deck; 100,000 shuffles pass a chi-squared test on card positions.
- [ ] **Counting is useless:** Blackjack edge after ten-rich and ten-poor hands is the same within noise.
- [ ] **No double spends:** 50 parallel buy-ins or bets from one account place exactly what the balance allows.
- [ ] **No peeking:** over 10,000 hands, no reply to any player holds a card that player shouldn't see.
- [ ] **Turns and timeouts:** acting out of turn is refused; a timed-out player is checked, folded or stood by the next request; leaving mid-hand settles correctly.
- [ ] **Bot:** joins at 2 real players, leaves when a third sits down, stops after its daily 25-shard loss limit.
- [ ] **Ledger:** for every table, shards brought = shards taken away + rake + shards still on the table, to the shard; side-bet case grants are logged. Shards are never created.
- [ ] Screens work at the three sizes, by touch, mouse, keyboard and controller.

**Tests (kept to what this update touches; no full suite, per Big U):**
- `tables_migration` (PGlite: the RPCs, refusals, a parallel-bet race, timeouts, bot rules, ledger, side bet, no `delete`);
- `tables_odds` (quick: evaluator, shuffle, 1M Blackjack hands);
- `tables_ui` (3 browsers at one table at the three sizes: auto-deal, turns, hidden cards, a player leaving);
- plus the existing tests for anything the update edits (the main menu nav: `taborder`, `index_page`).

---

## Release plan (T9: the Tables first)

1. **v0.9.8: the Tables.**
   1. Migration and tests locally; the simulation confirms the edge and side-bet figures.
   2. Big U approves the migration.
   3. Apply it live.
   4. Ship the client.
2. **v0.9.9: nameplate health** (Part A, client only).
3. **Testing (Big U, October 4): only the tests for what changed, not the full suite.** Screenshots at three sizes in `dev/evidence/v0.9.8/` and `v0.9.9/`.

## Decisions (Big U, October 4)

| # | Question | Decision |
|---|---|---|
| H1 | Your own number above your head? | **Number for you only**; bars for everyone (no numbers on others) |
| H2 | Core health | **Under the timer** in the phase box |
| H3 | Delgado's FOLLOW/HOLD button | **Small button, shown only to the host** |
| H4 | Off-screen teammates | **Edge arrow with their name**, blinking red when downed (no health sliver) |
| H5 | PvP enemy health bars | **Hidden** |
| T1 | Hold'em against whom | **Real players; with only 2 players, 1 bot joins; 3 or more, players only.** Cards deal automatically |
| T2 | Blackjack rules | **Traditional**, plus a **side bet**: double aces or a full house pays 10 Hybrid Theory or 15 Flag Cases (amounts: R2) |
| T3 | Hold'em decks | **One** |
| T4 | Target house edge | **1.8** (as the Hold'em rake: R5) |
| T5 | Limits | **Host picks 100, 250 or No limit** for either game before the first hand; **buy-in 5 shards** |
| T6 | Daily cap | **No** |
| T7 | Provably fair | **Yes** |
| T8 | Signed-in only | **Yes** |
| T9 | Nameplates first? | **No: the Tables first** |

## Round 2 decisions (Big U, October 4)

| # | Question | Decision |
|---|---|---|
| R1 | Chips or shards? | **Straight shards.** The limit (100 / 250 / No limit) is the biggest single bet in shards; the 5-shard buy-in is your starting table stack |
| R2 | Side bet amounts | **"I want fun":** as asked: 1-shard side bet, double aces or a full house or better pays 10 Hybrid Theory or 15 Flag Cases |
| R3 | One player alone at Hold'em | **Waits for a second player** |
| R4 | Rebuys / top-ups | **Unlimited** |
| R5 | 1.8% Hold'em rake, Blackjack traditional edge | **Yes** |
