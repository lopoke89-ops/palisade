# Persistent casino execution report — October 8, 2026

**State: v0.10.5 review candidate; isolated staging database and Edge API deployed; Render runtime and production release pending.** This implements the [audited work order](../../plans/persistent-casino-render-work-order.md). The [operator and protocol instructions](../../render/README.md) describe the actual configuration and rollback contract.

Baseline was `main` at `76b5c90bb5402da1165f3f0c8b3175b7aafe454b`. The production project is `puvjfhwxigxjpsvdwrwf`; no migration, Edge deployment or casino test data was sent to it. The new SQL was generated with Supabase CLI 2.76.15 and replayed into disposable PGlite and real PostgreSQL 17 databases. The standalone restore was regenerated from migration sources and tested.

## What the local candidate proves

| Verification | Evidence and result |
|---|---|
| Six real browser contexts | [managed_browser.log](logs/managed_browser.log): same permanent room, first entrant leaves without affecting the other five, movement reaches the server, no PeerJS/TURN request. |
| Lost economic response and reload | Three slot response losses after SQL acceptance; one operation ID retained, reload resolves the original hand, wallet unchanged by replay. Storage-write failure prevents the first economic request. |
| Service replacement | Browser and WebSocket tests keep the same durable room code/ID. A last departure stops empty-floor ticks; a new process has no stale avatars. |
| Exact seats, atomic buy-in, ownership | [managed_casino.log](logs/managed_casino.log), [managed_postgres.log](logs/managed_postgres.log): bounded six-seat admission, single exact-seat reservation, four simultaneous identical buy-ins charge once, generation takeover races cannot authorize subsequent old writes. |
| Pure replay and request binding | Accepted requests replay after revocation and table closure without activity/version/wallet mutation. Changed requests and stale unaccepted decisions fail. Hash includes game keys, flags and seeds. |
| Seven managed games | [managed_games.log](logs/managed_games.log): legal actions across blackjack, Hold'em, roulette, baccarat, craps, slots and Plinko, then settlement without clients. Seven closed tables reconcile with `ok=true`, `bad_tables=[]`. |
| Worker and financial recovery | Separate lease fencing, bounded departed-craps recovery, persisted deadline repair without refreshing activity, financial controller acquisition and refusal of unrelated exposure. |
| Invitations | A managed invitation survives the sender's departure. Recipient ownership and expiry are enforced in SQL. Legacy friend and account regressions pass. |
| Runtime parity | Managed database/server tests run on the verified Node **22.17.0** executable. Deno **2.9.6** successfully checks the Edge entrypoint with SDK **2.117.3**. PostgreSQL runs real concurrent connections and row/advisory locks. |
| Server-key compatibility | [managed_rest.log](logs/managed_rest.log): the REST adapter accepts modern rotatable secret keys and legacy service-role JWTs, keeps user authentication separate, refuses forged/missing users and invalid server keys. The four managed REST/database/world/game suites pass again on Node 22.17.0; the updated Edge entrypoint passes Deno check. |
| Privacy and transport limits | [managed_world.log](logs/managed_world.log): snapshots exclude tokens, wallet/stack and hidden seeds; explicit takeover, malformed input, protocol mismatch, proximity checks, literal chat and idle behavior. Queues, payloads, auth concurrency, sync rate and send buffers are bounded in source. |
| Layout | Five [floor screenshots](screens) at 390×844, 844×390, 1280×720, 1440×900 and 2560×1440. Browser assertions check the player stays visible and the document has no horizontal overflow. These are floor captures; the full sheet/touch/reduced-motion/recording matrix remains open. |
| Existing behavior | Required casino engines/server/UI, map/music, fair-play, roulette, restore, accounts, friends, CSP, controller and combat host/join checks all pass. Individual logs are saved in `logs/`. |

## Load measurement and cost

[load.json](load.json) is a **60-second local smoke test**, sixty synthetic clients in ten rooms, with a server replacement in the middle. The database and clients share the test process with the server. It is not a Render capacity certification or the required two-hour soak.

The pinned Node 22 run recorded median acknowledgment latency about **32 ms**, p95 about **49 ms**, zero rejected messages and sixty occupants after replacement. Compact snapshots sent about **12.1 MB** across the minute, down from about 50 MB with the initial full-roster snapshots. These counters cover serialized outgoing WebSocket application payloads, not platform network overhead. At this constant full load, the payload-only extrapolation is about **1.45 GB for two hours**; actual platform usage must be measured. CPU and RSS include the local embedded database and synthetic clients and cannot be presented as service-only resource requirements.

The user chose Free staging. Supabase's connected organization is Free and its published plan is $0/month within its limits. Render Hobby's published allowance is 5 GB outbound/month; WebSocket responses count. Its current public-internet overage is $0.15/GB with a payment method, or service suspension without one. Check remaining workspace usage before live tests. Free Render can sleep after fifteen idle minutes, and the sleeping process cannot run the worker. Always-on uptime and recovery targets remain unsupported on this tier.

Sources checked October 8: [Supabase pricing](https://supabase.com/pricing), [Render Free](https://render.com/docs/free), [Render bandwidth](https://render.com/docs/outbound-bandwidth), [Render regions](https://render.com/docs/regions).

## Acceptance gates still open

| Work-order gates | Remaining work |
|---|---|
| P01–P04, P20, P22, P32 | Repeat hostless joins/rejoins and restart against the real Render service. Measure cold-start latency, healthy standby and complete platform deploy overlap, including the old-owner lifetime. |
| P05–P12, P17–P18, P24, P27, P29–P31, P36 | Local tests cover important paths. Staging still needs actual REST/Edge/SQL integration, interrupted wager stress, all-game accepted-decision recovery, clock skew, database interruption, blocked/poisoned schedules and audit-boundary operation. |
| P13–P16, P21, P28, P35 | Local pure replay, hash conflicts, late decisions, reload and storage failure pass. Complete cancellation/in-flight ambiguity and old cached client compatibility checks in staging. |
| P19, P23 | Floor viewport captures pass. Complete every table sheet, touch/controller/reduced-motion behavior, pending-seat errors, maintenance/reconnect UI and short entry/movement/shared-table/restart recordings. |
| P25–P26 | Bounded defenses and a short target-load smoke exist. Run the actual two-hour 60-client soak with regional network shaping, slow-client/flood stress, tick/CPU/memory/egress and database-call/write metrics. |
| P33–P34 | SQL invitation lifetime/ownership/expiry and runtime checks pass locally. Verify browser invitation/code entry, rate-limit/full-room UX and the deployed Node/Deno compatibility contract. |

These are release blockers, not deferred enhancements. The work order is not complete until isolated staging and the public release checks meet its definition of done.

## Account access and rollout status

- User created **palisade-casino-staging** (`nxsqerlpqdzrjwqxhsdz`) in **lopoke89-ops's Org** (`fybiqyiinbwplibsnaph`), **us-west-2**, PostgreSQL 17.11. The empty project was initialized once with the complete standalone restore. Migration `20261008165641_initialize_palisade_casino_staging` is recorded; ten durable rooms exist. Admissions and new wagers remain disabled; the allowlist is empty.
- Staging `tables` version 2 is active, using the same six source files as the local candidate. It checks user authentication in its handler with `getUser`; gateway JWT checking is disabled consistently with that custom authentication. [staging-setup.json](staging-setup.json) preserves the initial version-1 setup, migration hash, RLS/grant checks and advisor findings. [staging-followup.json](staging-followup.json) records the version-2 bundle and later fixture state. All 24 public tables have RLS; the world, managed start/step and schedule repair RPCs are service-only.
- [staging-access.json](staging-access.json) records **34 passing live checks**, repeated against version 2: preflight, twenty-one rejected Edge requests with missing/forged/publishable credentials, world-RPC refusal, five legacy account RPCs refusing unsigned callers, and six inaccessible casino tables. The [read-only probe](../../render/probe-staging.mjs) targets only this staging project and uses a public key.
- [staging-auth.json](staging-auth.json) records **42 passing authenticated checks** across seven disposable saved accounts: password sign-in through real Supabase Auth, verified identity, the initial 5,000-shard wallet, authenticated Edge lobby read, privileged RPC refusal and raw casino-table refusal. The fixture seeded only this empty staging project's users/identities with bcrypt hashes, then verified the real Auth flow. Random passwords and access/refresh tokens stay in ignored local output and are absent from evidence and Git. [The authenticated probe](../../render/probe-staging-auth.mjs) reproduces the initial checks. Six accounts are intended for room tests and one for admission refusal. No casino tables, operations or ledger entries exist yet; admissions and wagers remain off. Authenticated casino play remains pending.
- Render management tools are unavailable, so setup continues through the dashboard. The user completed sign-in and the workspace is authenticated. The browser form is prepared for **palisade-casino-staging**, **Oregon**, branch `casino-persistent-render`, Node 22.17.0, Free ($0/month, 0.1 CPU, 512 MB), `/healthz`, exact GitHub Pages/local staging origins, and automatic deploy off. It matches the validated blueprint ([blueprint-validation.json](blueprint-validation.json)). The staging server-key field is empty; the user has been asked to enter it securely and approve service creation. Browser confirmation policy requires action-time approval for new privileged database access. No Render service has been created by this task.
- The managed client stays disabled. No paid compute or bandwidth, production admission, production migration, main-branch push or website publication is authorized by these local results.
- Continue with Render service creation, server credentials entered securely in Render, allowlisted staging, the remaining acceptance evidence and a concrete release review. Preserve legacy financial obligations through rollout and rollback.

## Staging advisor review

The advisor reports zero ERROR notices. Eighteen service-owned tables have RLS without user policies, intentionally denying direct client access. It also flags twenty-one authenticated security-definer RPCs; these are the guarded game/account API, not direct table-write permissions. Five inherited account RPCs remain callable by the unsigned `anon` role but require a valid user through `private.require_user()`; all five return HTTP 403 / SQLSTATE 28000 in the live probe. Anonymous Supabase Auth accounts use the `authenticated` database role, which is distinct from unsigned callers.

The inherited `citext` extension is in `public`; its relocation remains a compatibility follow-up ([advisor guidance](https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public)). Six foreign keys lack covering indexes: case openings, managed invitation target, controller room, saved-position room, cosmetic case and notification sender ([advisor guidance](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys)). Durable rooms are retained rather than deleted; these notices still require review alongside measured staging workload. Nineteen indexes are unused in this freshly initialized project. None of these notices substitutes for the open authenticated integration, capacity and failure-recovery gates.
