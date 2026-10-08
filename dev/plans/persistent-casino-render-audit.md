# Persistent casino work-order audit

**October 8, 2026 · Source baseline `76b5c90bb5402da1165f3f0c8b3175b7aafe454b` · v0.10.4 / yard-29**

**Verdict:** the casino-first architecture is feasible, but the initial work order had eight material contract or verification gaps. Four were high priority because a literal implementation could mis-handle seating, economic retries, controller ownership, or table recovery. The [work order](persistent-casino-render-work-order.md) has been revised to address all eight, and its acceptance matrix now contains 36 scenarios instead of 26.

The revisions make the specification suitable to begin baseline/design work. They do not establish that the new backend is implemented, deployed, or production-ready. Infrastructure capacity, full-Postgres concurrency, live platform handoff, and Node/Deno parity remain implementation verification gates.

## Findings and corrections

### A1 — High: a reserved seat could become a different committed seat

**Initial contract:** reserve a physical seat, then reuse the current engine/transaction flow to commit it.

**Evidence:** [`engine.js`](../supabase/functions/tables/engine.js), `sit()` at line 93, chooses another free seat when the requested seat is occupied or invalid. [`21b-tables.js`](../src/js/21b-tables.js), `tbSitAt()`, explicitly handles the resulting different seat. A pure-engine probe requested seat 0 for a second account after seat 0 was taken. The engine assigned seat 1 and created a second buy-in operation.

**Risk:** a reservation can authorize one seat while the game buys the player into another, causing presentation divergence or an unreserved admission.

**Correction:** managed rooms commit the exact `(room, game, station, seat, account)` tuple or reject without debit. Legacy fallback remains explicitly scoped. Availability includes bots and departed obligations. **Coverage:** P10/P11 plus new P27.

### A2 — High: a durable retry could execute in a later round

**Initial contract:** persist the operation ID and request and retry until authoritative resolution.

**Evidence:** [`handler.js`](../supabase/functions/tables/handler.js) hashes the request at line 27; the normal request bodies do not require a round/decision precondition. An accepted operation is safely recognized by its ID, but an unaccepted old bet/action can be evaluated against a future valid phase. An operation lookup that finds nothing also does not prove an earlier request cannot still commit.

**Risk:** retry after a long disconnect can create a new wager in a round the player never intended. Replacing an apparently absent operation while its first request is in flight can produce two economic actions.

**Correction:** managed actions carry immutable session/round/decision preconditions, require IDs across all shard/prize actions, and retain those preconditions on retry. Accepted replay precedes stale-round/reservation checks. An uncertain operation is not replaced without resolution or transactional cancellation. Define a versioned economic hash allowlist and journal environment/account scope; refuse submission if the durable write fails. **Coverage:** P13/P14 plus new P28/P35.

### A3 — High: WebSocket takeover did not revoke the HTTP table controller

**Initial contract:** one controlling floor presence; revoked tabs cannot issue valid seat commands.

**Evidence:** the [`tables API`](../supabase/functions/tables/handler.js) authenticates a user token independently of the floor connection. Its `state`, ready, seed, settings, and other requests can mutate or refresh activity. `replay()` at line 51 calls mutating `run()` at line 29. A handler probe replayed an already accepted action: it performed one commit and advanced the account's `seen` timestamp from 1000 to 2000.

**Risk:** an old tab can keep playing or keep a seat alive after takeover. Guarding only new seats or checking generation before the transaction leaves an in-flight takeover race. Conversely, requiring WSS for every table action can strand a legitimate player during a floor outage.

**Correction:** enforce controller generation inside all managed mutation/heartbeat transactions across both APIs. Managed operation replay is a read and cannot refresh activity or advance the table. Define a financial recovery controller independent of a floor slot, with an explicit matrix for new exposure, existing-hand decisions, departures, and reads. **Coverage:** P09 plus new P29/P36.

### A4 — High: normal dealer advancement and abandonment cleanup were underspecified

**Initial contract:** extract a shared table advance/sweep interface and run it independently.

**Evidence:** [`handler.js`](../supabase/functions/tables/handler.js), `sweep()` at line 60, deliberately zeroes phase/review deadlines and marks players absent to close stale tables. Its adapter selects stale rows by `updated_at`. Normal worker commits would keep that timestamp fresh. [`engine.js`](../supabase/functions/tables/engine.js) uses per-seat `seen` for away policy; human Blackjack/Hold'em decision turns have zero deadlines. Worker scheduling only by table update time or a nonzero phase deadline misses these cases.

**Risk:** a naive worker can accelerate live games/reviews, fail to expire absent seats, or leave abandoned turns unscheduled. A poisoned row can repeatedly occupy the first batch and block other recoveries.

**Correction:** split normal due advancement from abandonment cleanup; derive due work from phase/bot/review times, seat away times, and obligations. Persist scheduling in the same transaction as every writer, repair missing legacy records, and use fair bounded selection with alerts for quarantined liabilities. Define a shared time/drift contract and supported adapter/storage revisions. Existing live human decision timing is preserved. **Coverage:** P17–P19/P24 plus new P30/P31 and part of P34.

### A5 — Medium: the takeover timing gate contradicted Render's deployment sequence

**Initial contract:** passive standby waits for ownership; resumed admission within 30 seconds of replacement process startup.

**Evidence:** [Render's deployment sequence](https://render.com/docs/deploys) cuts traffic over to the healthy new process, then waits 60 seconds before sending the old process `SIGTERM`. If the old owner keeps its lease until that signal, the new process cannot meet the draft's 30-second admission gate. [Render also documents](https://render.com/docs/websocket) that reconnects may reach another instance.

**Risk:** a developer can create a readiness deadlock or claim a recovery target that excludes the actual admission outage.

**Correction:** the deployed health check distinguishes a healthy standby from admission ownership. The takeover gate starts only when the new process is healthy and old ownership is released/expired; complete platform overlap and user-visible interruption are separately recorded. Test the actual cutover sequence, not just a local kill/restart. **Coverage:** P06 plus new P32.

### A6 — Medium: join codes and invitations still contained legacy host assumptions

**Initial contract:** route casino entry/code/invites by transport and stable room ID.

**Evidence:** [`21-online.js`](../src/js/21-online.js), `netJoin()`, loads PeerJS and accepts only four characters. [`19d-friend-invites.js`](../src/js/19d-friend-invites.js) gates send by `NET.mode==='host'` and accepts through `netJoin()`. The [invitation migration](../supabase/migrations/20261001081316_friend_lobby_invites.sql) resolves the inviter's host/incarnation record and uses a 45-second live-room freshness check.

**Risk:** persistent invites can fail when the inviter leaves; bare codes can route into the wrong transport; extending only the displayed UI can leave send/accept/social-state paths broken.

**Correction:** managed six-character floor codes resolve to typed descriptors before PeerJS initialization; legacy combat codes/internal table codes remain distinct. Casino invites have an explicit room-ID target variant, eligibility/friendship/expiry/rate checks, and acceptance independent of the inviter's continued presence. A full target does not silently redirect the invitee. **Coverage:** P21/P22 plus new P33.

### A7 — Medium: shared-module packaging and website delivery were not concrete enough

**Initial contract:** put a Node server package under `dev/server/casino/`, share pure modules, and preserve Deno/runtime parity.

**Evidence:** audited local Node is 20.10.0. A direct ESM import of `engine.js` fails with `Unexpected token 'export'` because its directory has no ESM package boundary; an unrelated child server package does not change the imported file's classification. [`_config.yml`](../../_config.yml) excludes `dev/` from GitHub Pages. Existing ignore rules cover test dependencies, not the proposed new server dependency directory.

**Risk:** a seemingly reusable engine cannot start normally in Node; browser shared-module URLs under `dev/` fail on the published website; new dependencies/local secrets can enter the repository.

**Correction:** pin runtime and define supported ESM/build boundaries, run the actual production start command, verify both adapters, assemble/copy shared browser assets into published output, and extend appropriate ignore rules. **Coverage:** P34 and production build/CSP checks.

### A8 — Medium: verification could pass without exercising the risky platform contracts

**Initial contract:** broad test matrix and capacity gates, with permission to reduce advertised capacity if targets were missed.

**Evidence:** [`suite.txt`](../test/suite.txt) includes `fair_play`, `roulette_engine`, and `restore_schema`; the restore test has an `extra` tag and can be missed by ordinary group selection. Fast PGlite checks alone cannot prove full Postgres transaction locking/lease behavior. The draft's 60-player envelope was not measured against any selected Render instance.

**Risk:** claims of financial concurrency/recovery or target capacity can be made from mocks, partial selection, or silently weakened gates.

**Correction:** add exact named fairness/roulette/restore coverage where affected, disposable full-Postgres concurrency tests, real-adapter fault injection, sample counts/maxima, and an explicit failed-capacity-gate/release-review path. Performance and monthly availability remain separate claims. Add ten missing scenarios, P27–P36. **Coverage:** revised §§13/15/16.

## Audit method and observed results

Read the work order, floor entry and seating, table client/polling, host/join/invite paths, engine/handler/transaction adapter, current migration functions, schema, test catalog, build CSP, publishing exclusions, and dependency ignore rules. Rechecked official Render deployment/WebSocket guidance and Supabase session-validation guidance. The checkout commit remained unchanged.

Two in-memory source probes passed and confirmed the behaviors above. They used fictitious accounts and no network/database/player data:

```json
{"requestedSeat":0,"actualSeat":1,"spectatorStack":5,"buyinOperations":2}
{"replay":true,"writes":1,"seenBefore":1000,"seenAfter":2000}
```

The spectator stack in the first probe is an existing public table-view field, not a newly discovered privacy leak; the work order must deliberately select public floor fields rather than rebroadcast a full table response. The second probe demonstrates a write/activity refresh on replay, not a duplicate monetary debit.

The initial direct Node import failed as described in A7. For the audit probes only, `--experimental-default-type=module --input-type=module` allowed importing the current ESM sources. This does not validate a production packaging choice or pinned Render runtime.

No implemented Render backend exists to run the 36 acceptance scenarios against. No production request, migration, infrastructure purchase, or wallet modification was part of this audit. Changes are limited to this report and the work-order requirements.

## Remaining decisions for the implementation baseline

The implementer still needs to verify the live site/backend versions, select the supported Node packaging/runtime, specify actual lease/heartbeat/scheduler constants and database write interfaces, benchmark the proposed instance/region, and agree the supported release capacity from evidence. These are explicit Phase A and release gates, not unexplained blockers or permission to omit the corrected contracts.
