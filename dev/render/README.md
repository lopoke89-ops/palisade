# Persistent casino staging candidate

This service owns the casino floor. Supabase owns seats, controller generations, wallets, table state, operation receipts, history, leases and recovery schedules. A player's browser has no host role. Combat keeps its existing PeerJS adapter.

The candidate is v0.10.5. The published client configuration in `client.json` is disabled until isolated staging and the release gates pass. No production database or function was modified during implementation.

## Runtime and authority

- Render: Node **22.17.0**, `ws` **8.22.0**, one Free web service planned in **Oregon**, near the staging database. Build/start/health are in the root `render.yaml`; automatic deployments are off.
- Supabase staging: the separate Free project **palisade-casino-staging** (`nxsqerlpqdzrjwqxhsdz`) in **lopoke89-ops's Org**, **us-west-2**. The user created it in US West, so Render uses Oregon. Never point this staging service or its load tests at production.
- API: the existing `tables` function and shared `handler.js`, `engine.js`, `games.js`, `managed.js`, `storage.js`; SDK **2.117.3**. Node and Deno use the same economic rules and transaction adapter.
- Versions: wire `casino-1`, layout `1`, storage/managed adapter `1`, fair-play `2`, rules `bj-2`, `he-2`, `rl-2`, `ba-1`, `cr-1`, `sl-1`, `pk-1`. An incompatible managed write is refused.
- Ten durable rooms, six humans each. UUID identity `C:<uuid>` and permanent six-character code survive process replacement. The primary code is `PALACE`. Admission fills the existing populated room before opening bounded overflow.

The service role key is a server secret. Set it through Render's environment controls. `client.json` may contain only the public service URL, staging Supabase URL and publishable key. `.env.example` lists names; `.env` is ignored. No runtime source under `dev/` is fetched by the published browser: the shared layout is embedded during assembly.

## Stage and verify

1. The user created the isolated Free Supabase project; it is healthy on PostgreSQL 17.11. Do not upgrade plans to bypass limits.
2. **Completed October 8:** the empty staging project was initialized with `dev/supabase/schema.sql`, including the new migration in the standalone restore. Recorded migration: `20261008165641_initialize_palisade_casino_staging`. Do not initialize it again. For an existing database with the previous migrations, apply only `20261008133818_persistent_casino_world.sql`; never apply both forms to one database.
3. **Completed October 8:** staging `tables` version 1 is active with its five relative JS dependencies, SDK 2.117.3 and custom `getUser` authentication (`verify_jwt=false`). Twenty-one live requests with missing, forged or publishable credentials were refused. Authenticated game success is still pending. All 24 public tables have RLS; managed world/start/step/repair RPCs are service-only. See the saved staging evidence for advisor findings.
4. Create `palisade-casino-staging` from GitHub branch `casino-persistent-render`, using `render.yaml`. Supply `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` and an exact `ALLOWED_ORIGINS` list. Render provides `PORT`; the process binds `0.0.0.0`.
5. Confirm `/healthz` is 200 and reports the expected commit, protocol, layout and revision. `/readyz` must be 200 for the active lease owner. A healthy standby can pass `/healthz` without owning the world, preventing a deployment readiness deadlock.
6. Create disposable saved test accounts **in staging**, supply an account UUID allowlist, and enable admissions/new wagers there. Verify every game and the daily books with disposable balances. No production users or wallets belong in this test.
7. Build a separate staging site. A public config JSON needs `enabled`, `url`, `supabaseUrl`, `publishableKey`. Set `PALISADE_CASINO_CONFIG` to that JSON path and `PALISADE_BUILD_OUTPUT` to `dev/test/out/casino-staging`, then run `python dev/build.py` with Pillow. Host the output on an allowed origin. Auth and pending-operation storage are scoped to the Supabase environment.
8. Complete the outstanding staging gates listed in the execution report. Public production admission remains disabled until the evidence supports the release.

Local development uses `npm ci` in `dev/render`, environment variables from the staging project, then `npm start`. Add `http://localhost:8080` to staging `ALLOWED_ORIGINS` for local browser verification. Keep each deployment's credentials and database separate.

`node dev/render/probe-staging.mjs` repeats the read-only public-access checks. Set `SUPABASE_URL=https://nxsqerlpqdzrjwqxhsdz.supabase.co`, `SUPABASE_PUBLISHABLE_KEY` to that project's public key, and optionally `STAGING_PROBE_OUTPUT` to the report path. It refuses any other project and needs no server secret. These negative checks do not certify authenticated game behavior.

## Messages and lifecycle

`GET /rooms` returns durable IDs, codes, live occupancy and capacity. Directory data contains no table secrets. WebSockets connect at `/casino`, accept allowed origins only, and require a saved account and matching protocol.

| Client message | Fields and behavior |
|---|---|
| `hello` | `protocol`, access `token`, UUID `session`, optional `code`, `cls`, explicit `takeover`. User ID/name/appearance are derived or checked by the backend. |
| `input` | Increasing integer `seq`, two finite normalized `move` and `face` values. Server consumes at most one command per fixed 30 Hz tick. Queue is bounded at twelve; coordinates and speed claims are never accepted. |
| `reserve` | Registered `seat` code. Server verifies proximity within 0.75 tile and asks SQL for an exact ten-second reservation. |
| `sync` | Reconcile the avatar with the committed economic seat. No client seat claim is accepted. |
| `chat` | Sanitized text, maximum 120 characters, five lines per six seconds. Browser renders text through text nodes. |
| `token` / `ping` | Refresh verified authentication / liveness. Membership and controller checks repeat in SQL. |
| `depart` | Release floor membership/controller and close the socket. Table obligations follow the existing departure rules. |

`welcome` contains a full public roster and the account's controller session/generation. Roster updates carry IDs, names and cosmetics when membership changes. The 15 Hz `snapshot` contains compact arrays `[slot,x1000,y1000,faceX1000,faceY1000,seat,appliedSeq]`; identity is mapped from the roster. Position quantization is 0.001 tile. No wallet, stack, hole cards, unrevealed seed or private table state is in a floor message.

The browser predicts its own fixed steps and replays unacknowledged input on authoritative updates. Other avatars interpolate over 100 ms. A reconnect uses capped exponential backoff and jitter, retains the durable room code, and never changes a managed room into P2P or solo. An explicit takeover increments the account controller generation and revokes the previous socket. SQL also checks that generation **inside** each ledger transaction, including state requests that could refresh activity.

An account has one unresolved operation journal per project. The client writes the operation ID, request and expected table/round/decision before sending; storage failure prevents submission. Accepted replay is authenticated, account-owned and pure, even after revocation or table closure. The canonical hash binds all game fields, including craps keys/flags and player seed, while excluding controller and reservation credentials. A changed request under an accepted ID is refused. Unaccepted late actions fail their original decision precondition. Reload retries the same request; it never invents a replacement debit.

Exact seat reservation, five-shard buy-in, ledger entry, table update and operation receipt commit in one SQL transaction. Failed optimistic commits do not consume reservations. The existing one-account seat index also spans legacy and managed tables. Blackjack starts with one human; Hold'em starts with two humans. Public card tables use limit 100 and side bets off; their host controls are hidden/refused.

## Recovery, maintenance and rollback

SQL uses database time for world/worker leases, membership, reservations and controller validity. World and worker leases last fifteen seconds and fenced commits lock the matching lease row. World renewal runs every four seconds. The server stops floor authority when its lease cannot be verified. A healthy replacement can wait in standby; it cannot concurrently own the world.

The recovery worker polls persisted deadlines independently of players. Natural deadlines include human activity expiry, review/reveal gates and bot turns. Entirely departed craps obligations use bounded batches of sixty rolls; the next cycle continues until settlement, without a cap-based refund. Rows are selected by `(next_due_at,id)` with a ten-table batch, idle rescheduling and exponential failure backoff up to five minutes. Startup and minute repair restore missing schedules in batches of 100 without changing financial state or activity time. Expired reservations are pruned. Books checks run once a minute independently of room traffic.

When the floor is unavailable, `RECOVER TABLE` obtains a financial controller through the Edge API. It can finish an existing decision or cash out, but cannot start unrelated wagers. A financial takeover is explicit and the previous HTTP controller loses mutation authority. Sign-out revokes the controller over HTTP as well as disconnecting the floor. If the database is unreachable, expired leases/controllers bound the remaining authority.

Operator switches are service-only SQL:

```sql
-- Stop new exposure; preserve existing-hand recovery and cashout.
update public.casino_world_config set admissions=false,new_wagers=false where id;
-- Staging allowlist and enablement, after validation.
update public.casino_world_config
set allowlist=array['<test-account-uuid>']::uuid[],admissions=true,new_wagers=true
where id;
```

Keep `recovery=true` during ordinary maintenance. Use `recovery=false` only for an investigated recovery fault. Inspect `/healthz`, `casino_leases`, controller errors, oldest `next_due_at`, `recovery_failures/recovery_error`, open table obligations and `casino_books.ok`. Health contains no player/account identifiers.

For rollback, pause admissions/wagers first. Keep a compatible API and worker until accepted obligations settle, verify books, then roll back the floor/client to a compatible version. Retain the additive schema, durable room IDs, ledger, operation receipts and histories. Do not restore old wallet snapshots over accepted transactions or redirect an existing managed ID to a legacy room. Rotate a leaked service role key in Supabase and Render, redeploy, verify reads/writes/recovery, and never place the replacement in client assets.

## Free-tier limits and remaining evidence

The user's Free-tier choice changes the initial rollout to staging. Render can spin down after fifteen minutes without inbound traffic and a cold start can take about a minute. A sleeping process does not run the recovery worker. SQL state persists, but the empty-world recovery delay and always-on availability target cannot be guaranteed on Free. A paid always-on instance requires separate cost authorization.

As checked October 8, 2026: Supabase Free is $0/month, at most two active projects, 500 MB database and 5 GB egress, and can pause after inactivity. Render Hobby includes 5 GB outbound bandwidth; public WebSocket responses count toward it. Extra bandwidth is $0.15/GB if a payment method is linked; without one, exceeding the allowance can suspend services for the rest of the month. Check remaining account quotas before a live soak. A free compute plan does not authorize paid bandwidth or a plan upgrade.

Sources: [Render Free](https://render.com/docs/free), [Render outbound bandwidth](https://render.com/docs/outbound-bandwidth), [Render regions](https://render.com/docs/regions), [Supabase pricing](https://supabase.com/pricing).

Local logs prove the exercised behavior, not production capacity. Run the load harness with `SOAK_SECONDS=7200` for a full **local** two-hour test; its default is two hours and it is tagged `extra`. The live staging soak must use the deployed service and real staging auth, with network shaping and measured database calls/egress. Record live cold starts and the full Render deployment overlap: the platform can retain the old process before SIGTERM, so a thirty-second full-cutover claim requires measurement.
