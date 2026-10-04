# v0.9.8 THE TABLES: evidence

Work order: [nameplates-and-tables-work-order.md](../../plans/nameplates-and-tables-work-order.md) (Part B). Branch `claude/lucid-curie-491na1`.

## How it's built

- **The server deals everything.** The `tables` edge function (`dev/supabase/functions/tables/`) runs the rules (`engine.js`) and the requests (`handler.js`); the browser only shows what the server says that player may see.
- **Database** (`dev/supabase/migrations/20261004200000_v098_tables.sql`): `casino_tables` (state, saved only if nobody saved in between), `casino_hands` (every hand, its deck and fingerprint), `casino_ledger` (every shard and case moved). Players can't read or call any of it directly.
- **Randomness:** Web Crypto, no modulo bias. Blackjack: 4 decks reshuffled every hand. Hold'em: one 52-card deck.
- **Fair deal:** each hand shows a SHA-256 fingerprint of its deck at the deal; after the hand, the deck and salt are shown so anyone can check it.

## Numbers (`tables_engine.json`)

| Check | Result |
|---|---|
| Hand ranking: all 2,598,960 five-card hands | exact counts per category ([1302540, 1098240, 123552, 54912, 10200, 5108, 3744, 624, 40]) |
| Shuffle uniformity (chi-squared, 100,000 shuffles, 51 d.f.) | 44 (under 90 passes) |
| Blackjack, basic strategy, 300,000 hands | player return -0.215% (house edge about 0.2–0.5%) |
| Hold'em, 3 random players, 3,000 hands | shards conserved exactly (stacks + rake + side bets); 0 hole-card leaks; 2,269 side pots |
| Side-bet hit rate (Hold'em: pocket aces or full house or better) | 3.45% of side bets (about 1 in 29) |

`tables_server` (22 checks, real migration on Postgres): buy-in and cash-out to the shard; short balances refused with nothing moved; racing requests; every logged deck matches its fingerprint; side-bet prize into the bag; the bot's daily budget; guests and players kept out; migration applies twice; no `delete`.

## Screenshots

`lobby_*`, `bj_*` (a Blackjack hand settled), `he_*` (a 3-handed Hold'em hand with the bot, desktop / portrait / landscape).
