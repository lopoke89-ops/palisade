# v0.11.0 casino games: rules, paytables and math

The rules as built in `dev/supabase/functions/tables/games.js` (new games) and `engine.js` (result review, receipts). Every number below is produced or checked by `dev/test/casino_games_engine.js` (output in `dev/test/out/casino_games_engine.json`). These are this project's house rules: real casinos vary.

Shards stay play currency: never bought, never cashed out. Every payout is whole shards. A bet whose payout ratio would make a fraction is refused before it is taken; nothing is rounded afterwards.

## Rules versions

Each settled round's receipt carries `rv` (rules version) and `rid` (table id and round number).

| Game | rv | Changed in v0.11.0 |
|---|---|---|
| Blackjack | `bj-2` | 8 s review from the dealer's last card; receipt with the reason |
| Hold'em | `he-2` | 8 s minimum inside the 60 s break; pots with winners, hand name and five cards; uncontested said plainly |
| Roulette | `rl-2` | review 4 s → 6 s from the ball landing; itemized spots |
| Baccarat | `ba-1` | new |
| Craps | `cr-1` | new |
| Slots | `sl-1` | new |
| Plinko | `pk-1` | new |

## The review (every game)

| Game | Reading time, from the final reveal | Reveal |
|---|---|---|
| Blackjack | 8 s | 0.7 s a card: hole card, then each dealer draw |
| Baccarat | 8 s | 0.7 s a card, plus 0.3 s |
| Hold'em | 8 s minimum, inside the existing 60 s break | 0.7 s a run-out card, plus 0.7 s for the showdown |
| Roulette, craps | 6 s | roulette: the 6 s spin; craps: 2.2 s of dice |
| Slots, Plinko | 3 s | slots 2.6 s (reels stop at 1.4 / 2.0 / 2.6 s); Plinko 3.1 s |

- The server sets `revealAt` and `minAt` when it settles the round. Nothing moves the table on before `minAt`: no tick, no READY.
- Betting then opens. Hold'em keeps its 60-second break, and READY can deal sooner, but never before the 8 seconds are up.
- Standing up is never held back by the review: your stack goes home at once.
- Reduced motion skips the animation, but the server still holds the reading time.

## Baccarat (`ba-1`): mini-baccarat, 8 decks

- **Cards:** Ace 1, 2–9 face value, 10/J/Q/K 0, total mod 10. Deal order: Player, Banker, Player, Banker. An 8 or 9 in either hand is a natural, and nobody draws.
- **Third cards:** Player draws on 0–5 and stands on 6–7. If Player stands, Banker draws on 0–5. If Player drew, Banker follows this table (D = draws, by Player's third-card value 0–9):

  | Banker | 0 1 2 3 4 5 6 7 8 9 |
  |---|---|
  | 0–2 | D D D D D D D D D D |
  | 3 | D D D D D D D D – D |
  | 4 | – – D D D D D D – – |
  | 5 | – – – – D D D D – – |
  | 6 | – – – – – – D D – – |
  | 7 | stands |

- **Pays** (profit): Player 1:1, Banker 19:20, Tie 8:1. A tie returns the Player and Banker stakes.
  - Banker bets go in **20s**. Example: 20 Banker → 19 profit + 20 stake back = 39, with 1 shard of commission itemized on the receipt.
  - Player and Tie take any whole stake from 1. Limit: 1,000,000 a spot, no table limit.
- **Shoe:** 416 cards, shuffled once when the shoe starts.
  - **Seeds:** the shuffle uses the server's seed (its SHA-256 fingerprint is committed before any seed locks) plus every seated player's seed at that moment. Later seed changes apply from the next shoe.
  - **Burn:** the first card is shown, then as many cards are burned as its value (10/J/Q/K burn ten).
  - **Cut card:** 16 cards from the end (position 400). A hand that starts before the cut card always finishes (6 cards at most); the shoe changes before the next hand.
  - **Retirement:** when the cut card is reached or the table closes, the shoe is logged in full.
- **Timing:** betting is 30 s. DEAL when you're done; the cards come once everyone has bet, but never in the first 5 s.
- **Disclosure boundary:**
  - The shoe's 416 card fingerprints (salt = SHA-256(seed:card:i), fingerprint = SHA-256(salt:card)) and their root are fixed when it starts.
  - Each hand's result, last view and history row carry only that hand's cards, positions and salts, never the seed or an undealt card.
  - CHECK compares them with the fingerprints: those of the shoe in play (op `shoe`, no card values), or those rebuilt from the retired shoe.
  - A retired shoe's history row has the seed and all 416 cards, and CHECK reruns the whole shuffle.
- **Exact edges, 8 decks, six cards drawn without replacement:**

  | Bet | Edge |
  |---|---|
  | Banker | **1.0579%** |
  | Player | **1.2351%** |
  | Tie | **14.3596%** |

  Win chances: Banker 45.860%, Player 44.625%, Tie 9.516%. These match the published 8-deck figures to 0.0005 points.

## Craps (`cr-1`)

- **Line bets:**
  - Come-out 7/11 wins Pass, and 2/3/12 loses. Any other total is the point.
  - On a point, the point wins and 7 loses.
  - Don't Pass is the reverse, with 12 on the come-out barred (a tie, and the bet stays).
  - Come / Don't Come: the same rules, each bet with its own point.
  - Bets already on a number are decided before the new ones move. When a Come bet on 6 is paid and a new Come bet moves to 6 on the same roll, the new one takes its place.
- **Pays (profit; a closing bet also returns its stake):**

  | Bet | Profit | Bet in | House edge (exact) |
  |---|---|---|---|
  | Pass / Come | 1:1 | 1s | 1.4141% (7/495) |
  | Don't Pass / Don't Come | 1:1 | 1s | 1.4026% per bet decided (pushes excluded) |
  | Pass/Come odds 4/10, 5/9, 6/8 | 2:1, 3:2, 6:5 | 1s, 2s, 5s | 0 |
  | Don't odds 4/10, 5/9, 6/8 | 1:2, 2:3, 5:6 | 2s, 3s, 6s | 0 |
  | Place 4/10, 5/9, 6/8 | 9:5, 7:5, 7:6 | 5s, 5s, 6s | 6.6667%, 4.0000%, 1.5152% |
  | Field (2 and 12 pay 2:1) | 1:1 | 1s | 5.5556% |
  | Hard 4/10, Hard 6/8 | 7:1, 9:1 | 1s | 11.1111%, 9.0909% |
  | Any Seven / Any Craps | 4:1 / 7:1 | 1s | 16.6667% / 11.1111% |
  | 2 or 12 / 3 or 11 | 30:1 / 15:1 | 1s | 13.8889% / 11.1111% |

  The edges come from the rules engine itself: an absorbing chain over the 36 rolls, run until each bet's first decision.
- **Odds limits:** Pass/Come odds up to 3× the flat bet on 4/10, 4× on 5/9, 5× on 6/8. Don't odds lay up to 6× the flat bet, which wins at most 3×, 4× or 5× it.
- **Working on the come-out:** Place bets, Hardways and Come odds are off unless you turn them on (three toggles). Established Come bets and Don't Come odds always work. Come odds that are off when their bet is decided are returned.
- **What can come down:**
  - Pass can't once a point is on, and a Come bet on its number can't either.
  - Don't bets can come down (their odds come back with them), but can't go up once established.
  - Odds, Place, Hardways and the one-roll bets can come down any time betting is open.
  - No put bets.
- **Winning bets that stay up:** a winning Place or Hardway bet pays its profit and stays up. A roll that ends the point leaves every other bet where it is.
- **The dice:**
  - The shooter keeps the dice through made points and passes them after a seven-out.
  - On the come-out, the shooter must have a Pass or Don't Pass bet, or the dice move to the next player who does. With no shooter, the dealer rolls.
  - ROLL is the shooter's READY; it can't change the dice. The dice roll once everyone at the table is ready (never in the first 5 s) or after 20 s, as long as any bet is down.
  - Each roll uses its own committed seed, revealed after the roll; it can't predict the next one.
- **Leaving:**
  - Everything that may come down comes back to your stack.
  - Pass on a point and Come bets on their numbers stay; your seat is marked as left, and your account stays at that table (`casino_seats`).
  - With nobody else playing, the dealer rolls them out. The trigger is the request-triggered sweep (any casino lobby request, ≥3 min stale, up to 60 rolls a batch, resumed by the next sweep) or your own lobby request.
  - No cap on rolls changes the odds.
  - Once the bets are decided you are stood up and your shards go home in one cash-out.

## Slots (`sl-1`): PALISADE RUN, an original game

- **Reels:** 3 reels of 20 stops, one fixed line (the middle row), 1–100 shards a spin.
  - The window shows the real strip: the symbols above and below the line are the neighbouring stops.
  - No near-miss shaping, no autoplay, no jackpot.

| Reel | Strip (stops 0–19) | P | C | W | H | N | S | X |
|---|---|---|---|---|---|---|---|---|
| 1 | `SWNXHSWNSPWXNSHWCNSX` | 1 | 1 | 4 | 2 | 4 | 5 | 3 |
| 2 | `SWXNHXWNSPWXNXHWCNSX` | 1 | 1 | 4 | 2 | 4 | 3 | 5 |
| 3 | `SWXNHXWNXPWXNXHWCNSX` | 1 | 1 | 4 | 2 | 4 | 2 | 6 |

P Palisade crest, C core, W wall, H helmet, N nade, S shard, X blank. The line pays its single highest award (awards don't add up). Gross multiples, stake included:

| Line | Pays | Combinations (of 8,000) |
|---|---|---|
| P P P | 250× | 1 |
| C C C | 60× | 1 |
| W W W | 25× | 64 |
| H H H | 15× | 8 |
| N N N | 10× | 64 |
| S S S | 6× | 30 |
| any three of W / H / N (mixed) | 3× | 864 |
| S S on reels 1–2 | 2× | 270 |
| S on reel 1 (stake back) | 1× | 1,700 |

Exact return over all 8,000 combinations: 7,682 / 8,000 = **96.025%**, within 0.1 point of the 96% target. The line pays on 37.525% of spins, 16.3% pay more than the stake, and the maximum is 250× (1 in 8,000).

## Plinko (`pk-1`): an original online-casino-style game

- **Board:** 12 rows, 13 pockets. The pocket is the number of rights in 12 server-decided 50/50 bounces, so P(pocket k) = C(12,k)/4096.
- **Animation:** the board shows exactly that path; frame rate and touch timing can't change it.
- **Stakes:** in 10s, 10–500. Multipliers are in tenths, so every return is whole shards.

| Pocket | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Pays | 30× | 9× | 3× | 1.5× | 1.2× | 0.6× | 0.5× | 0.6× | 1.2× | 1.5× | 3× | 9× | 30× |
| Chance % | 0.024 | 0.293 | 1.611 | 5.371 | 12.085 | 19.336 | 22.559 | 19.336 | 12.085 | 5.371 | 1.611 | 0.293 | 0.024 |

- **Return:** exact over all 4,096 paths: **96.0059%**. Variance 1.068 (per unit staked); maximum 30×.
- **Odds of losing:** 61.23% of drops pay under 1×. That counts as a loss even though some shards come back; e.g. 20 at 0.6× returns 12, net −8.

## Shard circulation

The machines keep about 4% of what is staked over time (slots 3.98%, Plinko 3.99%); baccarat and craps keep the edges above. All of it leaves circulation, as at the existing tables, and none of it is paid to anyone. Nothing about the existing games' payouts, limits, rake, side bets or case prizes changed. The 96% target and the new review times are project choices made for this release; they were not previously approved economy settings.

## Accounting

- **Receipts:** every settled round's receipt has, per player, `bet` (stake decided this round), `back` (gross returned) and `net` = `back` − `bet`, plus itemized lines. Craps also lists the bets still `working`.
- **House take:** `result.house` is the house's take, the same convention as v0.10.0. The daily books (`casino_books`) cover every game: per closed table or machine session, shards in − shards out = Σ house + the bot.
- **Owner-requested wallet changes:** the compensation scripts and bonuses are outside the casino books.
