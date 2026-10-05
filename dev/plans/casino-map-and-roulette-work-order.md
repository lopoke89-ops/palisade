# v0.10.0 work order: THE CASINO (a walkable Tables map) and ROULETTE

| | |
|---|---|
| **Status** | Plan. Written October 5 from Big U's request. **Waiting on decisions C1–C12** (bottom of this file) |
| **Build** | v0.10.0. Client, the `tables` edge function, and one server migration (needs Big U's approval before it's applied) |
| **Scope** | A 16×16 Vegas casino map in the game's isometric style that players walk around in; a blackjack table, a poker table and a new roulette table on it; Roulette as a third Tables game |
| **Risk** | Medium. Shards are real currency: Roulette is new money logic (server only, logged, hash-checked like the other two games). The map itself is rendering and room code we already have |

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
| PAL-0100-6 | Guard rails: limits, payout caps, economy check | Server |
| PAL-0100-7 | Entry points: the TABLES tab, invites, Open Games | Menus |

---

## PAL-0100-1: THE CASINO map

**Goal:** a casino you'd recognise from the Strip, drawn the same way as every other PALISADE map:
- the same isometric 16×16 grid and renderer;
- the same chunky low-poly characters and the same lighting system (the City Black Out streetlamps and the night pass);
- no new art pipeline.

**Layout (16×16, entrance at the south-east, the corner the camera faces):**

| Area | Tiles (approx.) | What's there |
|---|---|---|
| Entrance and marquee | south-east edge | Glass doors, red carpet runner, a big marquee sign with chasing bulbs and the casino's name (C9) |
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
- **Characters:** players appear with their equipped skins, hats and trails, as in every mode. In the casino their weapons are holstered (C11).
- **Dealers (C8):** an NPC at each table, so a table never looks empty.

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

**Table settings:** before the table's first hand the person who opened it sets the limit (100, 250 or no limit) and the side bet. These are the same host-starts rules as v0.8.1.

**Code:** a room mode in `21-online.js` that carries positions and seats only, plus a casino layer in the new file that draws the seated players and the table state from `TB.v`.

**Acceptance:**
- [ ] Two players in one room see each other walk, sit and stand at all three tables.
- [ ] Sitting at a table opens the right game. Two players sitting at the same table land at the same server table.
- [ ] The table panel works from phone portrait, landscape, desktop and controller.
- [ ] Leaving the room, closing the tab or losing the connection stands you up within the existing 60-second away rule, and your shards go home.

## PAL-0100-3: Roulette (rules and odds)

**The wheel (C3):** proposed European, single zero, 37 pockets (0–36), with **la partage**: an even-money bet that loses to zero gets half back.

| Bet | Covers | Pays | House edge |
|---|---|---|---|
| Straight | 1 number | 35:1 | 2.70% |
| Split | 2 | 17:1 | 2.70% |
| Street | 3 | 11:1 | 2.70% |
| Corner | 4 | 8:1 | 2.70% |
| Six line | 6 | 5:1 | 2.70% |
| Dozen / Column | 12 | 2:1 | 2.70% |
| Red/Black, Odd/Even, 1–18/19–36 | 18 | 1:1 | **1.35%** (la partage) |

**Why this wheel:**
- It's the fairest real wheel there is.
- The house still keeps a small edge, so nobody can print shards (your rule from v0.8).
- American (00) would be 5.26%, twice as harsh.
- With la partage the even-money bets sit near Blackjack's edge, and the long shots stay at 2.7%.

**A round:**
1. **Betting** (60 s, C7): place chips on the layout. **SPIN** marks you ready. The ball goes when everyone seated is ready, or when the timer runs out (with at least one bet down).
2. **No more bets:** the wheel spins for about 5 seconds, the same length on every phone.
3. **Result:** the number and colour are shown, winning bets are paid, losing chips are swept, and the round is logged.
4. Back to betting. Your last bets can be repeated with **REBET**.

**The fair-spin check** (the same idea as the deck fingerprint in Blackjack and Hold'em):
- **Fixed before betting:** when betting opens, the server draws the number with the same unbiased crypto RNG (`rng()` in `handler.js`) and publishes `sha256(salt + ':' + number)`.
- **Checkable after the spin:** the salt and number are shown, so anyone can check the result wasn't picked after the bets went down. The table panel shows the fingerprint, as it does for the deck.

**Players (C4):** Roulette is you against the house, so it can run with one player. Your earlier rule for Blackjack and Hold'em is to wait for a second player; C4 asks whether Roulette follows that rule or can be played alone.

**Code:** `engine.js` gets `rlNewRound`, `rlBet`, `rlClear`, `rlReady`, `rlSpin` and `rlSettle`, plus a pure `rlPay(bets, n)` that the tests check bet by bet. Like the other games, it runs through the tick loop and the `run()` commit in `handler.js`.

## PAL-0100-4: Roulette UI and the wheel

**The table panel (phone first):**
- **Layout:** the full betting layout as a grid you can pinch or zoom: 0, 1–36 in three columns, then the dozens, columns and the even-money boxes below.
- **Betting:**
  - tap a spot to drop the chosen chip (1 / 5 / 25 / 100);
  - tap between numbers for splits and corners, as on a real felt;
  - long-press a spot to remove a chip from it.
- **Buttons:** CLEAR, REBET, DOUBLE and **SPIN**, which marks you ready.
- **Information:**
  - your stack, your total bet this spin and the timer;
  - the last 12 numbers (a history strip, red, black or green);
  - the fingerprint for this spin.
- **Others' bets:** shown as their colour on the layout, so you can see what the table is backing.

**The wheel:** drawn in the casino and in the panel; a real European wheel order, ball and deceleration. It always stops on the server's number (the animation is chosen to land there). It's the same length on every screen and plays a tick sound as the ball bounces.

**Acceptance:**
- [ ] Every bet type can be placed and removed by touch, mouse and controller at the three sizes.
- [ ] The wheel always lands on the number the server sent. All players see the same result at the same moment, give or take one poll.

## PAL-0100-5: Server (migration, needs Big U's approval)

- `casino_tables.game` accepts `'rl'` as well as `'bj'` and `'he'`.
- `casino_hands` logs each spin. It reuses the hand row: `hash`, `salt`, the number in `deck`, each player's bets and payouts in `result`.
- The ledger is unchanged: buy-in, top-up and cash-out work as today. Roulette moves shards only within the table stack, as the other two games do.
- A new optional column on `casino_tables`, `room text`, ties a server table to a casino room code and seat group, so walking up to a table finds the same server table for everyone in the room.
- **Tested:** in PGlite first, like every migration. Applied live only after Big U says yes.

## PAL-0100-6: Guard rails

- **Buy-in:** 5 shards to sit, as at the other tables. Top up between spins.
- **Limits per spin** (the table's limit is the most you can have on the layout in one spin):
  - 100 / 250 / no limit, as today;
  - **C6 on the no-limit table:** at most 50 on any single number, so a straight-up win pays at most 1,750. A single hit stays a great story without wrecking the economy.
- **Server checks:**
  - no bets after "no more bets";
  - no bet bigger than your stack;
  - bets only on real spots (the client's grid is never trusted).
- **Economy check:**
  - a 1,000,000-spin simulation in the tests has to land within the expected edge (2.70% / 1.35%) to within 0.1%;
  - the payout table is checked bet type by bet type against the table above.
- **Watching it:** a short query in the STATUS file sums shards in and out per day at the roulette table, so we can see it isn't leaking.

## PAL-0100-7: Entry points

- **The TABLES tab:**
  - **ENTER THE CASINO:** hosts a casino room and drops you at the doors;
  - **JOIN BY CODE;**
  - the existing quick list (C2).
- **Open Games:** casino rooms show as "CASINO · n/6".
- **Friends:** invites to a casino room work like raid invites.
- **Music:** a new loop for the casino (lounge jazz) is optional. Until one is picked, the menu track plays.

---

## Tests (only what this touches)

| Test | Checks |
|---|---|
| `roulette_engine` (no browser) | Every bet type pays right on every number. La partage. Edge over 1,000,000 spins. The hash matches the revealed number. Bets refused after the close and over the stack or limit. The single-number cap |
| `roulette_server` (no browser) | The handler with a fake database: two players bet, spin, settle. Conflict retries. Standing up mid-round returns your stack |
| `casino_map` | The map renders at three sizes. Collision: every seat can be reached and no wall can be crossed. The SIT/STAND prompts. Screenshots in `out/casino_*.png` |
| `casino_network` | Host and guest walk, sit at the same table and land at the same server table; the panel opens on both. Leaving stands you up |
| `roulette_ui` | Place each bet type by touch and mouse. SPIN with two players. The wheel lands on the server's number. The history strip |
| Re-run | `tables_engine`, `tables_server`, `tables_ui` (the shared code moved), `cases` and `accounts` (shards) |

## Release plan

1. Roulette engine and server tests, then the migration. **Stop: Big U approves the migration**, then it's applied and the edge function is deployed.
2. The casino map: art, collision, lighting.
3. The room and sitting down. Blackjack and poker on the map first, then roulette.
4. The roulette UI and wheel.
5. Tests above. Screenshots in `dev/evidence/v0.10.0/`. STATUS entry. PR and merge.

---

## Decisions for Big U (reply with the numbers)

| # | Question | Proposal |
|---|---|---|
| C1 | Is the casino shared (other players walking around with you, a room of up to 6 like co-op), or does everyone walk it alone and just meet at the tables? | Shared room |
| C2 | Keep the current quick TABLES list (sit down from the menu without walking), alongside the casino? | Yes, keep both |
| C3 | Which wheel: European with la partage (2.7%, 1.35% on even-money bets), plain European (2.7%), or American (5.26%)? | European with la partage |
| C4 | Can Roulette be played alone (it's you against the house), or wait for a second player like Blackjack and Hold'em? | Allow alone |
| C5 | Full betting board (straight, split, street, corner, six line, dozens, columns, even-money), or a simple one (numbers, red/black, odd/even, high/low, dozens)? | Full board |
| C6 | Cap on a single number at the no-limit table (proposed 50, so the biggest win is 1,750)? | Yes, 50 |
| C7 | Betting window: 60 s, ending early when everyone has pressed SPIN? | Yes |
| C8 | Dealers at each table (NPCs in vests)? Delgado could deal blackjack | Yes; Delgado deals blackjack |
| C9 | Casino name on the marquee: THE GOLDEN STAKE, PALISADE PALACE, LUCKY FENCE, or your own? | Your call |
| C10 | Slot machines: decoration only for now, or a playable slots game later? | Decoration now |
| C11 | Weapons holstered and no damage anywhere in the casino? | Yes |
| C12 | A roulette side bet like the Blackjack and Hold'em one (cases instead of shards)? | No; roulette already has long shots |
