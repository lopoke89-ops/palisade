# v0.10.0 work order: THE CASINO (a walkable Tables map) and ROULETTE

| | |
|---|---|
| **Status** | Plan. Written October 5 from Big U's request. All decisions made by Big U on October 5 (C1–C12, bottom of this file). **Audited October 5** (findings A1–A14 at the bottom, all folded in). One question left: F1 |
| **Build** | v0.10.0, protocol `yard-28` (new casino room messages). Client, the `tables` edge function, and one server migration (needs Big U's approval before it's applied) |
| **Scope** | A 16×16 Vegas casino map in the game's isometric style that players walk around in; a blackjack table, a poker table and a new roulette table on it; Roulette as a third Tables game |
| **Risk** | Medium. Shards are the game's currency (play money: they can't be bought or cashed out, and must stay that way). Roulette is new shard logic: server only, logged, fingerprinted like the other two games. The map itself is rendering and room code we already have |

## Request (Big U)

> Let's make a map for the Tables mode. A 16×16 casino map with the same style, a Vegas aesthetic. A blackjack table, a poker table and a new roulette game/table.

## Tickets

| ID | Title | Area |
|---|---|---|
| PAL-0100-1 | THE CASINO: the 16×16 map, art and lighting | Rendering / maps |
| PAL-0100-2 | Walking the floor: the casino room, sitting down at a table, the table panel | Client / network |
| PAL-0100-3 | Roulette: rules, odds, payouts and the fair-spin check | Server (edge function) |
| PAL-0100-4 | Roulette table UI (phone first) and the wheel | Client |
| PAL-0100-5 | Server: Roulette in the tables, hands log and ledger | Migration (approval) |
| PAL-0100-6 | Guard rails: server checks and the economy check | Server |
| PAL-0100-7 | Entry points: the TABLES tab, invites, Open Games | Menus |
| PAL-0100-8 | Fair play at all three tables: players add randomness, the daily books check, hand history, the rules page | Server / client |
| PAL-0100-9 | Hold'em: stop revealing folded hands after the hand (a live bug, found in this audit) | Server |

---

## PAL-0100-1: THE CASINO map

**Goal:** a casino you'd recognise from the Strip, drawn the same way as every other PALISADE map:
- the same isometric 16×16 grid and renderer;
- the same chunky low-poly characters and the same lighting system (the City Black Out streetlamps and the night pass);
- no new art pipeline.

**Layout (16×16, entrance at the south-east, the corner the camera faces):**

| Area | Tiles (approx.) | What's there |
|---|---|---|
| Entrance and marquee | south-east edge | Glass doors, red carpet runner, a big marquee sign with chasing bulbs: **THE PALISADE FALLS CASINO** (C9) |
| Main floor | centre | Patterned carpet (deep red with gold diamonds, the classic casino carpet), brass pillars, a ceiling of chandeliers (drawn as glow pools on the floor) |
| Blackjack | west of centre | One half-moon table, green felt, 5 stools, a dealer spot, a chip rack, a shoe |
| Poker | north of centre | One oval table, green felt with a gold rail, 6 chairs, a dealer spot |
| Roulette | east of centre | One wheel-and-layout table, 6 stools, the wheel at the head with the croupier |
| Slot banks | along the north and west walls | Rows of slot machines with blinking screens and spinning reels (decoration only, C10) |
| Cashier cage | south-west corner | Barred window with a "CASHIER" neon sign. Walking up shows your shard balance |
| Bar | north-east corner | Bar counter, stools and a neon martini glass. Somewhere to stand around and chat |
| Velvet ropes, plants, ashtray stands | Scattered | Break up the floor and give the walls some depth |

**Look (the Vegas aesthetic):**
- **Palette:** deep red and black, gold and brass trim, green felt, neon pink, cyan and amber. Night outside the doors.
- **Neon:** signs over each table ("BLACKJACK", "POKER", "ROULETTE"), the marquee, and the bar sign. They glow, light the floor around them, and flicker now and then.
- **Motion:** the marquee bulbs chase, the slot screens blink, the roulette wheel turns slowly when idle, and dealers idle. All of it is cheap, drawn into the cached layer where possible.
- **Characters:** players appear with their equipped skins, hats and trails, as in every mode. **No weapons in the casino (C11):** guns aren't drawn or usable on this map only. Every other mode is unchanged.
- **Dealers (C8):** a 3D dealer at each of the three tables, built like our player models (the same drawn-in-code low-poly bodies, poses and lighting).
  - the outfit: white shirt, black vest, bow tie, sleeve garters, a name badge;
  - they deal, shuffle, spin the wheel, sweep chips and idle between hands;
  - SLIM, the poker bot, is a player, not a dealer: when he sits in he's drawn in a poker chair with his own look and the BOT tag;
  - they're built as a proper skin set (body, hat/hair and accessories in the cosmetics format), so they can become a **Dealer collection** in a later case without new art work. That case is not part of this release.

**Rules of the map:**
- No raiders, no building, no damage, no weapons, no resources, no core.
- Solid: walls, tables, slot banks, the bar, the cage and pillars. Players walk around them, as with City Black Out buildings.
- The camera follows your character as usual. Zoom works as in raids, and desktop zoom keeps working.

**Code:**
- **Map data:** a new entry in `MAPS` (`06b-maps.js`) with its own `lay()`. Terrain uses `T_BLDG` for solid pieces, so collision and pathing work with no new code.
- **Art:** new file `06f-casino.js` for the scenery (tables, slots, bar, cage, carpet pattern, neon) and the casino's own lighting preset (based on the City Black Out night).
- **Mode flag:** `game.mode = 'casino'`. Raid phases, timers, waves and the build kit are off. The HUD shows only your shard balance and the room code; health is hidden.

**Performance:**
- the static floor and furniture go into the cached ground layer (as Frostpeak's terraces do);
- only the moving bits redraw each frame: neon pulse, bulbs, wheel, characters;
- target: 60 fps on desktop and 30 fps on phones, the same as the menus.

**Acceptance:**
- [ ] A 16×16 casino with the three tables, slot banks, cashier, bar and entrance, at desktop 1366×820, phone portrait 390×844 and landscape 844×390.
- [ ] Players can't walk through walls, tables or slot banks. Every seat can be reached.
- [ ] Frame time on the casino is no worse than the Yard at the same size (measured with the existing `bench.js`).

## PAL-0100-2: Walking the floor

**The casino is a room, like a raid lobby (C1):**
- **Hosting:** one player hosts it and gets a 4-letter code; up to 6 players walk the floor together.
- **Joining:** by code, Open Games, or a friend invite, using the same PeerJS room code as co-op.
- **What the host does and doesn't control:** the host only relays where people are standing and sitting. All shard logic stays on the server (the `tables` edge function), so a host can't touch anyone's shards.

**Sitting down:**
- **The only way to play is to walk to a table (C2):** the TABLES tab's quick list goes away.
- Walk up to a free seat. A prompt shows: **SIT** (tap or Enter on desktop, A on a controller).
- **Taking the seat:** you take that seat. If nobody is playing at that table yet, sitting opens a server table for it with the room's settings. Otherwise you join the one already running: each physical table is one server table, found by the room code.
- **The table panel:** the existing table panel (Blackjack and Hold'em today, plus Roulette) opens as a sheet over the bottom of the screen. The casino stays visible and alive above it.
- **Standing up:** STAND (or walking away) stands you up and sends your stack home, exactly as today.

**On the felt:**
- seated players sit on their stool or chair, facing the table;
- cards are drawn face down for everyone except you; your cards are only in your panel;
- chip stacks grow and shrink with each player's stack;
- the dealer deals with a small animation, and the roulette ball spins.
- Nothing secret is ever drawn on the table: other players' hole cards stay face down until a showdown, the same as in the panel.

**Table settings:**
- **Blackjack and Hold'em:** before the first hand, the first person to sit sets the limit (100, 250 or no limit) and the side bet, then starts the table. Same as v0.8.1.
- **Roulette:** no settings; it's always no limit and has no side bet.

**Who can play:**
- Guests (no account) can enter and walk around. At a seat, the prompt says "Make an account to play" instead of SIT, as the tables say today.

**Seated, on a phone:**
- Moving is off while you're seated, so the table sheet can cover the joystick.
- On landscape the sheet sits on the right half, so you can still see the table.

**When the room ends** (the host leaves or closes the tab; there is no host hand-over, same as raids):
- every seated player is stood up straight away, their stack goes home, and they land on the TABLES tab;
- if a phone vanishes without saying goodbye, the existing 60-second away rule stands them up.

**The server enforces walk-only:** opening or joining a table needs a casino room code and a table, so an old client can't open a menu table after the update.

**Code:** a room mode in `21-online.js` that carries positions and seats only (protocol `yard-28`; the live `room_register` already accepts any `yard-N`, and the lobby row's existing `mode` column says `casino`, so no lobby migration is needed), plus a casino layer in the new file that draws the seated players and the table state from `TB.v`.

**Acceptance:**
- [ ] Two players in one room see each other walk, sit and stand at all three tables.
- [ ] Sitting at a table opens the right game. Two players sitting at the same table land at the same server table.
- [ ] The table panel works from phone portrait, landscape, desktop and controller.
- [ ] Leaving the room, closing the tab or losing the connection stands you up within the existing 60-second away rule, and your shards go home.

## PAL-0100-3: Roulette (rules and odds)

**The wheel (C3, Big U: American):** double zero, 38 pockets (0, 00, 1–36), the classic Las Vegas wheel. No la partage (it isn't played on American wheels).

| Bet | Covers | Pays | House edge |
|---|---|---|---|
| Straight (any number, 0 and 00 too) | 1 | 35:1 | 5.26% |
| Split (0–00 included) | 2 | 17:1 | 5.26% |
| Street (and 0-1-2, 00-2-3) | 3 | 11:1 | 5.26% |
| Corner | 4 | 8:1 | 5.26% |
| Top line (0, 00, 1, 2, 3) | 5 | 6:1 | **7.89%**: the one worse bet on an American table. It's on the real board, so it's kept (C5) and the panel marks it |
| Six line | 6 | 5:1 | 5.26% |
| Dozen / Column | 12 | 2:1 | 5.26% (0 and 00 lose) |
| Red/Black, Odd/Even, 1–18/19–36 | 18 | 1:1 | 5.26% (0 and 00 lose) |

**Why it fits (Big U chose the double-zero wheel):**
- It's the real Vegas wheel.
- The house keeps 5.26% on every bet except the top line. That's harsher than Blackjack or the Hold'em cut, so roulette is the game where the house wins over time; your v0.8 rule (nobody prints shards) holds by a wide margin.

**A round:**
1. **Betting** (60 s, C7, Big U: yes): place chips on the layout. **SPIN** marks you ready. The ball goes when everyone seated is ready, or when the timer runs out (with at least one bet down).
2. **No more bets:** the wheel spins for about 5 seconds, the same length on every phone.
3. **Result:** the number and colour are shown, winning bets are paid, losing chips are swept, and the round is logged.
4. Back to betting. Your last bets can be repeated with **REBET**.

**The fair-spin check** (the same idea as the deck fingerprint in Blackjack and Hold'em):
- **Fixed before betting:** when betting opens, the server fixes the number (with the players' randomness, PAL-0100-8) and publishes its fingerprint.
- **Never sent early:** the number lives only in the server's table state. `view()` never sends it before the ball stops, and a test checks every view during betting and the spin for it.
- **Checkable after the spin:** the salt and number are shown, so anyone can check the result wasn't picked after the bets went down. The table panel shows the fingerprint, as it does for the deck.

**Players (C4, Big U: yes):** Roulette can be played alone (you against the house). Blackjack and Hold'em keep their rule: wait for a second real player (Hold'em still adds the bot as a third).

**Code:** `engine.js` gets `rlNewRound`, `rlBet`, `rlClear`, `rlReady`, `rlSpin` and `rlSettle`, plus a pure `rlPay(bets, n)` that the tests check bet by bet. Like the other games, it runs through the tick loop and the `run()` commit in `handler.js`.

## PAL-0100-4: Roulette UI and the wheel

**The table panel (phone first):**
- **Layout:** the full betting layout as a grid you can pinch or zoom: 0, 1–36 in three columns, then the dozens, columns and the even-money boxes below.
- **Betting:**
  - tap a spot to drop the chosen chip (1 / 5 / 25 / 100 / 500 / 1K, since roulette is always no limit);
  - tap between numbers for splits and corners, as on a real felt;
  - long-press a spot to remove a chip from it.
- **Buttons:** CLEAR, REBET, DOUBLE and **SPIN**, which marks you ready.
- **Information:**
  - your stack, your total bet this spin and the timer;
  - the last 12 numbers (a history strip, red, black or green);
  - the fingerprint for this spin.
- **Others' bets:** shown as their colour on the layout, so you can see what the table is backing.

**The wheel:** drawn in the casino and in the panel; the real American wheel order (0 and 00 opposite each other), ball and deceleration. It always stops on the server's number (the animation is chosen to land there). It's the same length on every screen and plays a tick sound as the ball bounces.

**Acceptance:**
- [ ] Every bet type can be placed and removed by touch, mouse and controller at the three sizes.
- [ ] The wheel always lands on the number the server sent. All players see the same result at the same moment, give or take one poll.

## PAL-0100-5: Server (migration, needs Big U's approval)

- `casino_tables.game` accepts `'rl'` as well as `'bj'` and `'he'`.
- `casino_hands` logs each spin. It reuses the hand row: `hash`, `salt`, the number in `deck`, each player's bets and payouts in `result`.
- The ledger is unchanged: buy-in, top-up and cash-out work as today. Roulette moves shards only within the table stack, as the other two games do.
- A new optional column on `casino_tables`, `room text`, ties a server table to a casino room code and seat group, so walking up to a table finds the same server table for everyone in the room.
- A new table `casino_books` holds the daily books check (PAL-0100-8); service role only, like the others.
- The players' randomness and the per-card fingerprints (PAL-0100-8, -9) live in the existing `st` and `result` JSON, so no other columns are needed.
- **The edge function** (`tables`) is deployed after the migration, and the deployed files are compared with the repo, as in v0.9.8.
- **Tested:** in PGlite first, like every migration. Applied live only after Big U says yes.

## PAL-0100-6: Guard rails

- **Buy-in:** 5 shards to sit, as at the other tables. Top up between spins.
- **Roulette is always no limit (C6, Big U):**
  - there's no limit setting and no per-number cap;
  - you can bet anything up to your stack (top up between spins), so a straight-up hit pays 35× whatever was on it;
  - the 5.26% edge does the economy's work over time, and the daily in/out query below shows if a few big hits ever swing it.
- Blackjack and Hold'em keep their 100 / 250 / no-limit settings.
- **Server checks:**
  - no bets after "no more bets";
  - no bet bigger than your stack;
  - bets only on real spots (the client's grid is never trusted).
- **Economy check:**
  - a 1,000,000-spin simulation in the tests has to land within the expected edge (5.26%, and 7.89% on the top line) to within 0.4 percentage points on red (the measured edge over a million spins has a standard error of about 0.1 points, so a tighter bound fails by chance); the exact edge of every one of the 161 spots is checked by enumerating all 38 pockets;
  - the payout table is checked bet type by bet type against the table above.
- **Watching it:** a short query in the STATUS file sums shards in and out per day at the roulette table, so we can see it isn't leaking.

## PAL-0100-7: Entry points

- **The TABLES tab becomes the casino's front door (C2):**
  - **ENTER THE CASINO:** hosts a casino room and drops you at the doors;
  - **JOIN BY CODE** and a list of open casino rooms;
  - your balance and the fair-play note.
- The old quick list and sitting down from the menu are removed; anyone mid-hand at a menu table when the update lands is stood up and their stack goes home (the existing stale-table sweep).
- **Open Games:** casino rooms show as "CASINO · n/6".
- **Friends:** invites to a casino room work like raid invites.
- **Music:** a new loop for the casino (lounge jazz) is optional. Until one is picked, the menu track plays.

## PAL-0100-8: Fair play at all three tables

Built with roulette and applied to Blackjack and Hold'em at the same time. Big U kept items 1, 3, 4 and 5 from the October 5 review and skipped the chip-dumping check.

**1. Players add their own randomness** (so not even the server can choose a deal or a spin):
- **Your seed:** each seated player has a seed, a random string made on their phone when they sit; they can change it in the panel.
- **The server commits first:** before each hand or spin, the server publishes the fingerprint of its own secret seed for that round.
- **Seeds lock at the deal:** players' seeds lock when the cards are dealt or betting closes.
- **The result:** the deck (or the roulette number) comes from the server seed, every seated player's seed and the hand number. It's mixed with SHA-256 and turned into an unbiased shuffle (no modulo bias, the same rule as today's `rng()`).
- **The reveal:** after the round the server seed is revealed, so anyone can recompute the result.
- **Why the server can't cheat:** it committed to its seed before the last player seed locked, so it couldn't pick a seed that produces a result it wanted.

**2. The daily books check:**
- Once a day (the first table request after midnight Eastern, the same clock as the bot's daily budget), the server writes a row to `casino_books`.
- **What it checks:** shards brought in, taken out and still on the tables; the house's take broken down into rake, blackjack and roulette; and whether those match the hand logs.
- A row that doesn't balance is marked **BAD** and shows in the next STATUS check. No `pg_cron` is needed (it isn't enabled on the project).

**3. Hand history:**
- **HISTORY** in the table panel lists your last 50 hands or spins: your cards, the board or number, what you put in and won, and the house cut.
- **CHECK** on any hand recomputes it on your phone from the revealed seeds and shows ✓, or exactly what didn't match.
- You only see what you'd have seen at the table (PAL-0100-9).

**4. The rules page:** a HOUSE RULES card at each table (and on the TABLES tab):
- **Payouts and house edge per game:** Blackjack's rules and edge with basic strategy; the Hold'em cut (1.8%, capped at 6); and roulette's 5.26%, with 7.89% on the top line.
- **Table rules:** the side bets, the 60-second timers, what happens if you disconnect, and that SLIM is a bot who never sees anyone's cards.

## PAL-0100-9: Hold'em reveals folded hands (live bug, found in this audit)

**Problem:**
- After a Hold'em hand, the server sends the whole deck to every player, so the deck fingerprint can be checked (`st.last.deck` in `view()`).
- The table panel also prints that deck as numbers in its fair-deal line (`21b-tables.js`).
- The cards are dealt in order, so anyone who opens the browser's developer tools can work out every folded player's hole cards, plus the cards that would have come if the hand ended early.
- Real poker rooms never show mucked hands, and players can learn each other's bluffs this way.
- Blackjack is not affected: it uses a fresh shoe every hand, and every card dealt there is face up anyway.

**Fix (PAL-0100-8 makes it clean):**
- **Per-card fingerprints:** each card position gets its own fingerprint, and the hand's fingerprint is built from those.
- **What players get after a hand:** the cards that were shown (the board, hands shown at showdown, and their own), plus only the fingerprints of the rest.
- **What they can check:** that the hand's fingerprint is right and that every card they saw is genuine, without learning a folded hand.
- **Full record:** the whole deck stays in `casino_hands` on the server, so the full check still works for us (like the hand #23 audit).

**When:** F1 below.

---

## Tests (only what this touches)

| Test | Checks |
|---|---|
| `roulette_engine` (no browser) | Every bet type pays right on all 38 pockets (0 and 00 included). Edge over 1,000,000 spins. The hash matches the revealed number. Bets refused after the close and over the stack. No cap on a bet within your stack |
| `roulette_server` (no browser) | The handler with a fake database: two players bet, spin, settle. Conflict retries. Standing up mid-round returns your stack |
| `casino_map` | The map renders at three sizes. Collision: every seat can be reached and no wall can be crossed. The SIT/STAND prompts. Screenshots in `out/casino_*.png` |
| `casino_network` | Host and guest walk, sit at the same table and land at the same server table; the panel opens on both. Leaving stands you up |
| `roulette_ui` | Place each bet type by touch and mouse. SPIN with two players. The wheel lands on the server's number. The history strip |
| `fair_play` (no browser) | Players' randomness changes the deal. The server can't pick a result after seeing it. Fingerprints check out for all three games. The books check balances on a simulated day and flags a planted error. Hold'em never sends a folded hand's cards to the other players |
| **Rewrite** `tables_ui` | It sits down from the menu list, which is removed: it now walks to the blackjack and poker tables in a casino room |
| Re-run | `tables_engine`, `tables_server`, `taborder` (the TABLES tab changes), `menu_bg_motion`, `cases` and `accounts` (shards) |

## Release plan

1. Roulette engine, fair play (PAL-0100-8, -9) and server tests, then the migration. **Stop: Big U approves the migration**, then it's applied and the edge function is deployed.
2. The casino map: art, collision, lighting.
3. The room and sitting down. Blackjack and poker on the map first, then roulette.
4. The roulette UI and wheel.
5. Tests above. Screenshots in `dev/evidence/v0.10.0/`. Footer `v0.10.0`. STATUS entry. PR and merge.

---

## Decisions (Big U, October 5)

| # | Question | Proposal | **Big U** |
|---|---|---|---|
| C1 | Shared casino (a room of up to 6) or everyone alone? | Shared | **Shared** |
| C2 | Keep the quick TABLES list alongside the casino? | Keep both | **No: it has to feel real, you walk to a table to play** |
| C3 | Which wheel? | European with la partage | **American, double zero** |
| C4 | Roulette alone? | Allow alone | **Yes, alone if they want** |
| C5 | Full or simple board? | Full | **Full board** (the top line included) |
| C6 | Single-number cap at no limit? | 50 | **Roulette is always no limit** (no cap) |
| C7 | 60 s betting window, early when all press SPIN? | Yes | **Yes, 60 s** |
| C8 | Dealers? | NPCs, Delgado at blackjack | **Yes, 3D dealer models, built so they can be a case skin later** |
| C9 | Casino name? | Your call | **THE PALISADE FALLS CASINO** |
| C10 | Slots? | Decoration | **Decoration only** (cases already scratch that itch) |
| C11 | Weapons in the casino? | Holstered | **No weapons, on the casino map only** |
| C12 | Roulette side bet? | No | **No; keep the Blackjack and Hold'em side bets as they are** |

## Audit (October 5)

Checked against Big U's decisions, the live database and the code. Everything below is folded into the tickets above.

| # | Finding | Fixed in |
|---|---|---|
| A1 | The wheel animation said "European wheel order"; Big U chose American | PAL-0100-4 |
| A2 | "Shards are real currency" was misleading: they're play money, and must stay that way (never sold or cashed out) | Header |
| A3 | Ticket 6 still said "payout caps"; roulette is always no limit | PAL-0100-6 |
| A4 | The roulette number must never reach a phone before the ball stops; now stated, and tested | PAL-0100-3, tests |
| A5 | `tables_ui` sits down from the menu list that C2 removes, so it has to be rewritten, not re-run; `taborder` also touches the TABLES tab | Tests |
| A6 | The new room messages need a protocol bump (`yard-27` to `yard-28`). The live `room_register` accepts any `yard-N`. **Corrected during the build:** the lobby row's `length` check and `room_register`'s own `length`/`map` lists reject `casino`, so a second migration (`20261005200100_v0100_casino_rooms.sql`) adds `casino` to both | PAL-0100-2, header |
| A7 | Guests (no account) weren't covered: they can walk, but can't sit | PAL-0100-2 |
| A8 | What happens to seated players when the host leaves wasn't covered: they're stood up straight away, and their shards go home | PAL-0100-2 |
| A9 | Walk-only has to be enforced by the server too, or an old client could still open a menu table | PAL-0100-2 |
| A10 | Roulette has no table settings (no limit, no side bet); only Blackjack and Hold'em do | PAL-0100-2 |
| A11 | SLIM needs a chair and a look on the map | PAL-0100-1 |
| A12 | 1/5/25/100 chips are too small for an always-no-limit table: added 500 and 1K | PAL-0100-4 |
| A13 | The fair-play items Big U kept (1, 3, 4, 5) weren't in the work order; and `pg_cron` isn't enabled, so the daily books check runs from the edge function | PAL-0100-8 |
| A14 | **Live bug:** after a Hold'em hand, every player is sent the whole deck, which reveals folded hands to anyone with developer tools | PAL-0100-9 |

## Still open

| # | Question | Proposal |
|---|---|---|
| F1 | PAL-0100-9 is live today. Fix it now as a small hotfix (stop sending the Hold'em deck to players; we can still check any hand from the server's log), with the per-card fingerprints coming in v0.10.0? Or wait for v0.10.0? | Hotfix now: a few lines in `engine.js` (no Hold'em deck in `view()`), one line in the panel's fair-deal text, the edge function redeployed and the site rebuilt, `tables_engine`, `tables_server` and `tables_ui` re-run. No migration |
