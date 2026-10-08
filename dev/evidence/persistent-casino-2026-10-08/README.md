# Persistent casino execution report — October 8, 2026

**State: local v0.10.5 review candidate; staging and production release are pending.** This implements the [audited work order](../../plans/persistent-casino-render-work-order.md). The [operator and protocol instructions](../../render/README.md) describe the actual configuration and rollback contract.

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

- User selected Supabase organization **lopoke89-ops's Org** (`fybiqyiinbwplibsnaph`). The connector can inspect it but its project cost/creation workflow is unavailable. An isolated Free staging project has been requested; no secret is needed in chat.
- User linked Render to GitHub, but the Render plugin is not connected to Codex and the available browser is at Render sign-in. No service exists yet. The reviewed blueprint is prepared for branch `casino-persistent-render`, Virginia, Free, automatic deploy off.
- The managed client stays disabled. No paid compute or bandwidth, production admission, production migration, main-branch push or website publication is authorized by these local results.
- Once account access is available, continue with isolated database setup, server credentials entered securely in Render, allowlisted staging, the remaining acceptance evidence and a concrete release review. Preserve legacy financial obligations through rollout and rollback.
