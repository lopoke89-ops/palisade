# SLIM's persistent casino wallet

Deployed October 8, 2026 CDT (October 9 UTC) to production project `puvjfhwxigxjpsvdwrwf`.
The `tables` Edge Function is version 13, bundle `bbc52b9fab91b3de32f3debe03b7c77e3fba5cdf4650d28ff4f13e57733b58b8`.
Live read-back matches all four local function files. Migration history is `20261009041955_casino_slim_wallet`;
the migration was generated with CLI 2.120.0 and its filename aligned with the applied history version.

SLIM no longer receives a 25-shard daily allowance or buys in for five shards. With two eligible
human players he brings his entire available wallet, provided it covers the two-shard big blind.
The database reserves the full amount for one poker table, and a stale balance or competing
reservation rolls the request back and retries. His remaining stack returns on departure; his
net result remains separately recorded for the existing casino books. New non-poker revenue
waits in his wallet while he plays and joins his stack at his next buy-in. Existing allowance bots
finish with their current stacks; their original minted chips do not enter the new wallet.

Funding is the signed house result of settled blackjack, roulette, baccarat, craps, slots and Plinko
rounds. Player wins subtract from it. Negative funding carries forward, with no fresh shards
granted at midnight. Pending wagers, deposits, cash-outs, account rewards and case prizes do
not fund it. Poker was explicitly excluded from the historical backfill and remains excluded
from ongoing house-result funding, using the default stated during the task. SLIM's own poker
profit or loss naturally changes the chips returned to his wallet.

The one-time backfill covered all 395 recorded non-poker rounds, October 4–8 CDT:

| Game | Rounds | Net funding (shards) |
| --- | ---: | ---: |
| Blackjack | 113 | 3,995 |
| Baccarat | 104 | 1,722 |
| Craps | 37 | -774 |
| Plinko | 56 | 312 |
| Roulette | 40 | 90 |
| Slots | 45 | 130 |
| Total | 395 | 5,475 |

Each funded round has a unique receipt tied to its historical hand id. Reapplying the migration
or rolling back a casino operation cannot credit it twice. A trigger funds future settlements
inside the same database transaction. Production verification confirmed a 5,475-shard balance,
5,475 available to join, 395 backfill receipts, and exact reconciliation with funding plus wallet
transfers. This observation does not spend real player money to exercise a production hand.
Subsequent read-only verification observed natural live play at table 116: SLIM joined with
`walletBot: true`, brought 5,475 shards, and the ledger reserved exactly -5,475. His current
stack was 5,475 at that observation and the unseated balance was zero. See `live-join.json`.

Validation passed: `casino_bot_wallet` (25 checks), `tables_server` (48 checks), `casino_server`
(34 checks), `tables_engine` (all 2,598,960 five-card hands, 300,000 blackjack hands, 3,000 poker
hands), `casino_games_engine`, `fair_play` (400 poker hands), and `restore_schema`. The wallet
test forces both tables to read the same balance before reserving it, then confirms one winner,
complete rollback of the losing bot seat, full buy-in/cash-out, signed funding and deficits,
legacy bot compatibility, permission denial and unchanged casino book reconciliation.
The fair-play fixture now handles a dealer ace's insurance window before verifying the revealed shoe.

Both new private tables use RLS and deny direct access, including service-role table grants.
Only the server's wallet RPC is granted to service role; anonymous and authenticated users
cannot call it. Security advisors list the two intentional private RLS-without-policy information
notices; existing unrelated RPC and account-policy warnings remain. Their category is documented
in the [Supabase database linter](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy).
Read-back and before/after advisor evidence are saved in `verification.json`.

No browser assets changed; the published v0.10.5 client already displays SLIM's server-provided
stack. Existing accounts and live tables are preserved.
