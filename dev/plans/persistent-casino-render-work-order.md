# PALISADE FALLS CASINO — persistent multiplayer on Render

**Developer work order · October 8, 2026 · Casino first**

**Audited and revised October 8, 2026.** See [the audit findings and evidence](persistent-casino-render-audit.md). The revised contracts below supersede the initial draft where they differ.

Reference checkout: `76b5c90bb5402da1165f3f0c8b3175b7aafe454b`, **v0.10.4**, browser protocol `yard-29`. The checkout was clean when inspected. This is a source audit, not a fresh verification of the deployed website, Render account, or live database. Re-establish those baselines before implementation or release.

## 1. Mission and completion standard

Act as the lead multiplayer gameplay developer and backend reliability engineer for PALISADE. Deliver a permanent, shared PALISADE FALLS CASINO whose availability never depends on a player keeping a browser open. Render runs the casino floor; Supabase remains the authority for accounts, casino games, shards, receipts, and history.

The player presses **ENTER THE CASINO**, walks into a shared room, sees other players, chats, sits at a table or machine, and plays the existing games. The first arrival can leave without affecting anyone else. The last departure leaves an empty, joinable room. A service restart restores the same room identity and recovers every accepted casino obligation.

AAA quality means responsive controls, clear connection states, correct financial state, protected information, reliable recovery, and measured performance. Deliver a complete feature with evidence. A room list that survives while gameplay still needs a player host, a permanent bot browser, or a WebSocket relay with no room authority does not satisfy this order.

This document commissions the implementation candidate and its verification. The deliverable requested here is the work order; no infrastructure has been purchased and no production deployment has been performed. Prepare a concrete release candidate and cost estimate before a production release or new paid infrastructure is authorized.

## 2. Scope

### Required in the first release

- One permanent public casino, with a stable room identifier and shareable join code.
- Server-owned floor presence, movement, facing, seat presentation, chat, and admission.
- Six human occupants per room initially, preserving the current room scale. Blackjack still has five seats; other game and machine seat counts retain their current rules.
- A configurable, bounded set of persistent overflow rooms. Default entry prefers a joinable populated room, then the primary room, then an available overflow room. A full-room response offers another room; it never evicts a player.
- Existing Blackjack, Hold'em, American roulette, Baccarat, Craps, Slots, and Plinko, including every current cabinet/station identity.
- Reconnect, token refresh, duplicate-tab handling, independent table recovery, service restart, and deployment recovery.
- Casino entry through the TABLES front door, Open Games, join code, and friend invitation paths.
- Local integration tests, a staging deployment recipe, operational documentation, and a controlled production rollout plan.

### Boundaries

Combat co-op, PvP, campaigns, raids, and their PeerJS hosting stay on their current transport. Do not port the combat simulation to Render in this release. Keep the Canvas renderer, HTML/CSS table sheets, existing soundtrack, controls, cosmetics, account eligibility, casino math, paytables, buy-ins, wallet accounting, and fairness rules.

No Godot port, frontend framework migration, cash purchases, cash withdrawals, global rewards redesign, forced player compensation, or mass balance edits. No private persistent casinos in this first release. Existing private combat rooms remain supported. Render room IDs and transport types must make a later combat migration possible without implementing it now.

## 3. Findings that the implementation must address

These findings are from the reference source, not assumptions about production:

| Current behavior | Consequence for this work |
|---|---|
| `casEnter()` opens a PeerJS host room and may fall back to `casSolo()` | Replace casino entry with the Render connection flow. An unavailable shared casino must show a recoverable error, rather than silently creating a separate solo casino. |
| `casRoom()` builds `R:<code>:<incarnation>` or a time-based `SOLO:` identity | Persistent room identity must come from the server and stay stable across departures, restarts, and deploys. |
| `NET` uses `solo`, `host`, and `guest`, with host-disconnect termination | Add an explicit casino transport/session adapter. A Render session must never trigger the combat host-disconnect path. |
| Public lobbies and invite sessions are registered under a player's `host_id` | Add a casino-specific room directory and invitation target. Do not represent permanent rooms with a fake human host account. |
| `casSit()` locally snaps the player into a seat before the table request finishes | Introduce a pending seat state and reconcile presentation with the committed backend seat. A rejected buy-in cannot leave a ghost occupant. |
| Table requests identify rooms with a permissive 4–80-character string | New managed-room requests need registered room and membership checks; a syntactically valid invented room is insufficient. |
| `tables/handler.js` calls `sweep()` from authenticated `op:'lobby'` requests | Outstanding wagers and stale-table cleanup currently depend on user traffic. Add an independent recovery worker using the existing engine and commit path. |
| `tbCallOp()` keeps one pending operation in memory and may replace it after 120 seconds | Uncertain shard operations must survive reload/reconnect and remain tied to their original operation ID until resolved. |
| `E.sit()` falls back to another free seat when the requested index is unavailable | Managed reservations require the exact reserved seat; preserve fallback only for legacy room requests. |
| `replay()` calls `run()`, which can advance a table and refresh the caller's `seen` time | Managed accepted-operation replay must be read-only; a revoked tab cannot keep a seat alive through replay. |
| `netJoin()` accepts exactly four characters and loads PeerJS before joining | Managed code resolution must happen before calling the legacy join path or loading its transport. |
| Blackjack/Hold'em initially wait for the table's human coordinator to start | Public managed tables need an automatic initial start policy, preserving player-count requirements and existing game rules. |
| Casino floor animation and movement share browser game state | Extract only the casino movement/collision contract. The Render server must run without DOM, Canvas, audio, or a browser process. |

### Source map

| Area | Read and adapt |
|---|---|
| Floor layout, furniture, stations, entry, seats | `dev/src/js/06f-casino.js` |
| Local controls and movement | `dev/src/js/12-players.js`, `08-input.js`, `08b-pad.js`, collision helpers in `06-world.js` |
| Online adapter, roster, chat, snapshots | `dev/src/js/21-online.js`, `11-hud-chat.js`, `22-loop-menus.js` |
| Accounts, directory, invitations | `dev/src/js/19-accounts.js`, `19b-social-lobby.js`, `19d-friend-invites.js` |
| Table requests, operation IDs, receipts | `dev/src/js/21b-tables.js`, `21c-casino-games.js` |
| Server games and transactions | `dev/supabase/functions/tables/index.ts`, `handler.js`, `engine.js`, `games.js` |
| Seats, operation records, migrations | `dev/supabase/migrations/20261004200000_v098_tables.sql`, `20261005200000_v0100_casino.sql`, `20261005200100_v0100_casino_rooms.sql`, `20261006200000_v0103_casino_games.sql`; inspect all later migrations too |
| Presentation/build | `dev/src/page.html`, `dev/src/style.css`, `dev/build.py`, `dev/src/js/ORDER.txt` |
| Verification and release | `dev/test/suite.txt`, `dev/test/run_suite.js`, `dev/STATUS.md`, `dev/plans/v0.10.3-deploy-and-rollback.md` |

Before editing, record the actual branch, commit, dirty files, current protocol, site version, table function version, migrations, and relevant existing failures. Preserve unrelated work. Never use the older README release label as the authoritative version.

## 4. Architecture and authority

Use one paid Render Node.js Web Service initially. It can host multiple casino rooms and run a bounded recovery loop. Keep the game website on its existing static hosting. Use Supabase Postgres for durable records; Redis and a Render disk are unnecessary prerequisites for this candidate.

```text
Browser ── HTTPS/WSS ── Render casino service
   │                     │
   │                     ├─ room admission, movement, presence, chat
   │                     ├─ verified seat reservations / reconciliation
   │                     └─ recovery worker ── shared casino engine
   │                                             │
   └─ authenticated HTTPS ── Supabase tables API ──┤
                                                 ▼
                                  Supabase transactional casino storage
```

| Authority | Owns | Never accepts from a client as fact |
|---|---|---|
| Render room service | Canonical floor positions, room membership, connection ownership, chat ordering, transient seat reservations | Arbitrary position/teleport, claimed account ID, claimed ownership, committed seat, wallet or outcome |
| Existing table backend | Table seating, game phases, commitments, cards/dice/reels, accepted wagers, stacks, settlement, receipts | Client payout, new room invented by request, unverified seat reservation, unsigned worker command |
| Supabase storage | Durable rooms, admission/recovery records, leases, table state and versions, operations, ledger, histories | Direct client mutation of privileged room or casino state |
| Browser | Input, local prediction, interpolation, presentation, pending request journal | Authority over any wager or other player's state |

Do not create two casino engines. Reuse the current engine and its transaction adapter from the recovery worker after extracting shared code where necessary. Player requests can remain on the Supabase tables API. A worker must not impersonate an arbitrary player or call the public lobby endpoint with a fabricated user token.

Ordinary movement stays in Render memory; do not write every movement tick to Postgres. Durable table state remains in the existing casino tables. Persist the minimum room recovery state needed to restore identities, valid seats, and recent positions, with safe spawn fallback when a position is stale or incompatible.

## 5. Room identity, directory, and lifecycle

Introduce a managed casino namespace, such as `C:<uuid>`, compatible with the existing room-string length contract. Final names may differ, but implement the following concepts explicitly:

- Immutable room ID; unique, stable display/join code; public name; room kind/transport; capacity; map/layout revision; wire protocol revision; admission state; maintenance state.
- Server ownership lease with owner ID, expiry, and monotonically increasing fencing epoch. Keep immutable room identity separate from the changing server epoch.
- Membership/reconnect record scoped to account, room, connection generation, recent position/facing, and expiry. Financial seating is recovered from casino storage, not duplicated as an independent source of truth.
- Registered permanent primary/overflow rooms, created idempotently. Bound overflow count in configuration and keep admissions atomic at the six-person limit.
- A recovery cursor/deadline index or equivalent durable selection mechanism for outstanding table work.

`AVAILABLE`, `FULL`, `RECOVERING`, and `MAINTENANCE` are directory states, not human host states. An empty healthy room is `AVAILABLE` with `0/6`. An unreachable service is unavailable; do not report zero rooms as if availability were healthy.

Before choosing a default room, check the account's current casino activity. Offer to resume its original room or resolve its pending departure. Never send a returning account to another room and conceal chips or obligations at the previous table. If that original floor is full or unavailable, receipt lookup and permitted financial recovery still work without a floor slot.

Room definitions survive indefinitely until an explicit operator retirement. Transient presence expires; players are not shown online forever after a crash. Empty rooms stop movement ticks and create no artificial wagers, bot gambling, or table activity. Table sessions can close normally when empty without deleting the room. An unresolved wager survives a room retirement until its obligation is settled.

Open Games must support both existing PeerJS combat rows and managed casino rows. Dispatch by transport and room ID, not by guessing from a code prefix. Preserve the current combat `host_id` policies. Casino invites target a stable room ID and check its current protocol/admission state. Server epoch changes must not invalidate a still-valid friend invite solely because Render restarted.

Give managed display codes a separate six-character format and an atomic uniqueness constraint; preserve four-character legacy combat codes. The join resolver returns a typed room descriptor and then chooses its adapter, before `needPeer()`/TURN initialization. Never truncate a managed code into a legacy four-character code. Keep the game table's existing four-character internal session code distinct from the floor join code.

For casino invites, add an explicit room-ID argument/target variant and update the send, answer, social-state, notification, and rendering paths. Any current eligible casino member may invite an accepted friend; it does not require `NET.mode==='host'`. Verify sender membership and account status, recipient friendship/eligibility, five-minute expiry, and the existing 10/minute and 30/hour sender limits. Acceptance rechecks the recipient and the target room without requiring the inviter to remain connected. An invite does not reserve capacity or force the recipient into another overflow room; if its target is full, say so and offer a separate choice. Preserve combat invite/incarnation behavior.

## 6. Authentication and connection contract

Keep the existing requirement for a saved online account. Anonymous accounts cannot enter the playable managed casino in this release. Verify account identity server-side through Supabase Auth. Do not trust `uid`, names, eligibility, or privileges submitted in messages. Load the permitted public profile/cosmetic fields and bind them to the verified account.

Use a bounded HTTPS bootstrap or an initial WSS authentication message; browser WebSockets cannot set an arbitrary Authorization header. Do not place bearer or refresh tokens in URLs, join codes, chat, telemetry, or public snapshots. An unauthenticated socket has a short authentication deadline and no room access. The browser retains refresh-token handling; refresh the access token and reauthenticate the socket before expiry. Revoke its ability to act if validation fails. Account switching clears the old connection and journals only within their original account scope.

Treat explicit in-app logout as a server disconnect/revocation of the controlling generation as well as browser cleanup. An issued access token may remain valid until expiry after sign-out; document the remaining validity window and use a checked connection/session record where immediate controller revocation is required. Do not claim that client-side sign-out instantly invalidates every bearer token.

One account has one controlling floor presence across managed casino rooms. A second tab receives a clear **OPEN IN ANOTHER TAB** state with an explicit takeover action. Takeover atomically increments connection generation and revokes the previous controller. The old tab cannot submit valid seat commands after takeover. Existing table activity remains bound to that account; takeover never performs a second buy-in or a cash-out.

Apply that generation to authenticated table HTTP requests too, including `state` heartbeats and non-monetary mutations such as ready, seed, side, start, and settings. Reject a superseded controller's mutation/heartbeat before it can refresh `seen` or change table state. A still-valid Supabase bearer token alone is insufficient evidence of controller ownership. Keep historical reads and accepted-operation lookup/replay available to the verified account without acquiring a floor slot; these reads must not extend seat activity.

Check the expected controller generation in the same privileged transaction as every managed table mutation, including heartbeat writes. Validation only at request arrival leaves a takeover race in which an old in-flight request can commit after revocation. A previously committed operation remains readable after takeover; an uncommitted old-controller mutation does not become authorized merely by retaining its operation ID.

Version a compact message contract, for example `casino-1`, independently of the combat transport. Required families:

| Family | Required behavior |
|---|---|
| Bootstrap/auth/resume | Verified identity, authoritative room, generation, server epoch/time, reconnect eligibility |
| Input | Monotonic sequence, bounded directional/facing values; server measures elapsed time |
| Snapshot/roster | Room sequence/epoch, canonical public avatar state and public seat occupancy |
| Seat reserve/confirm/release | Account-bound request, seat/station identity, reservation expiry, backend result reconciliation |
| Chat | Server sanitization, rate limit, room membership check, authoritative message ID |
| Status/error | Stable machine-readable reason plus clear copy: full, auth required, incompatible, recovering, maintenance |
| Ping/pong/time | Detect dead peers and give presentation a server-time reference |

Specify payload and frame-size limits, message frequency limits, authentication timeout, heartbeat cadence, queue limits, and reservation lifetime in one documented configuration. Reject malformed JSON, unexpected fields/types, NaN/infinity, out-of-range sequences, oversized text, and unknown commands without taking down a room.

## 7. Movement, visual quality, and chat

Extract a shared casino layout/station registry and collision/movement module usable in the browser and Node. Preserve seat codes, cabinet IDs `s1`–`s16`, Plinko `p1`, table positions, obstacles, spawn points, and current visual layout. Avoid manually maintained duplicate maps. A layout hash/revision must detect mismatched builds before admission.

Use a fixed-step room simulation with server-owned time. Initial tuning: 30 simulation ticks/second and 15 public snapshots/second, adjusted only with recorded profiling. Clients send bounded inputs; server applies the permitted casino speed and collision rules. Cosmetic selection cannot confer movement privileges. Seated players cannot walk until the committed seat state allows it.

Provide local prediction and reconciliation without camera jumps, with interpolated remote movement and a short bounded extrapolation limit. Coalesce old movement snapshots when a socket is slow; never build an unbounded reliable queue. Keep chat and seat responses reliable. WebSocket transport has ordered delivery, so explicitly test slow links and head-of-line delays.

Reconnect shows a restrained status banner while retaining the last view. Freeze actionable controls until the session is confirmed, then reconcile with the server. Do not show false wallet zeroes, duplicate avatars, a HOST label on the first arrival, or repeated entry announcements on every reconnect.

Initial floor reconnect grace is 30 seconds, distinct from the existing 60-second table away policy. Refresh and rejoin reconcile those clocks rather than resetting away time blindly. After a longer outage, a rightful player may recover a receipt/cash-out or a pending obligation instead of their former seat. Show the actual result; do not promise an indefinitely held seat or refund an accepted wager because reconnect took too long.

Preserve keyboard, touch, and controller behavior, reduced motion, table-sheet camera framing, mobile safe areas, player names, and casino music. No idle-room soundtrack or decorative animation should force the Render simulation to run. Chat retains current sanitization and length limits, with per-account and room flood protection. Room chat history may be a small bounded in-memory buffer; it is not a required permanent archive.

## 8. Seat admission: one committed truth

Render owns whether an avatar is physically allowed to attempt a seat. Supabase owns whether that account has actually bought in and occupies the game seat. Bridge those authorities with a durable, short-lived reservation checked during the casino transaction.

1. The authenticated player requests a seat or machine. Render validates room membership/generation, canonical proximity, station/game mapping, eligibility, and availability.
2. Reserve the target briefly against the verified account. Return a reservation identifier bound to room, seat/station, generation, and expiry. A bearer string alone is insufficient if it can be replayed after ownership changes.
3. The tables API validates and consumes/replays that reservation inside the same transaction that establishes the seat and buy-in. Concurrent applicants cannot both commit. A failed transaction produces no debit and leaves a releasable reservation.
4. Render confirms presentation from the committed casino seat record. If a reply is lost, inspect/replay the original operation; do not issue a second buy-in. A committed seat outlives reservation expiry and process loss.
5. Reconcile stale reservations, committed seats, bots, standing players, and disconnected avatars after every relevant transaction/reconnect and during worker recovery.

For managed rooms, commit **exactly** the reservation's `(room, game, station, seat index, account)` or reject without debit. The current engine's next-free-seat fallback is incompatible with that rule. Include committed bot occupants and departed-player obligations when checking availability. A loss in the race cannot teleport a player to a different seat, create an unreserved buy-in, or retarget an unresolved request; a new seat choice is a new explicit action after the prior attempt is resolved.

Prevent bypass through direct HTTP requests to a managed room, fake positions, another account's reservation, stale generation/epoch, or invented station IDs. A reservation signature is not a substitute for transactional uniqueness and account ownership.

Recovery and cash-out remain available to the rightful account even when the room service is down. Gate new managed-room sit/bet/spin actions on the current admission policy; do not gate historical receipt lookup, accepted-operation replay, or a valid departure on floor presence. Existing legacy rooms keep their compatibility path, but cannot use it to address the managed namespace.

Document and implement an action authorization matrix. New sit, top-up, round wagers, spin, and drop require the current controller and allowed admissions; table settings are server-fixed for managed rooms. Existing-hand decisions require the current controller, correct table/round/turn, and unchanged game legality. During a floor outage, a verified account may acquire a financial recovery controller through the tables backend without WSS to finish or leave its existing activity, including legal insurance/double/split decisions; this cannot admit it to a new table or start unrelated new exposure. Takeover revokes the old generation atomically across both APIs. Receipts/history and pure replay are reads; departure is an account-owned mutation. Maintenance must explicitly distinguish blocking new exposure from handling an already accepted hand.

HIDE closes a sheet and preserves the seat. STAND UP requests the existing financial departure. LEAVE CASINO requests departure, shows its confirmed/pending result, and removes floor presence. Unresolved craps obligations can keep the account financially associated with the table after its avatar leaves. Public occupancy must distinguish an active seated player from an obligation that is still resolving; never turn an absent account into a controllable ghost.

## 9. Preserve casino rules, accounting, and information boundaries

Keep every existing rule version, payout, commitment/disclosure rule, receipt, history, and casino books invariant. Use `casino_start`/`casino_step` and existing optimistic version checks, ledger, `casino_ops`, and one-active-seat constraint. Extend transactions narrowly for room admission, reservations, and worker fencing; do not fork payout code into Render.

For permanent public tables, use the current default limit/side-bet configuration, record it explicitly, and automatically start Blackjack when a valid player is seated and Hold'em when its existing minimum human requirement is met. Preserve existing Hold'em bot eligibility/budget and ordinary ready/review timing. A first sitter is never responsible for keeping the service alive. Apply this start policy only to new managed sessions; preserve legacy table setup behavior.

Persist uncertain shard operations before their first send. Store original operation ID, canonical request, account, room/table, and resolution status in an account-scoped durable browser journal. Transport reservations/tokens are excluded from the economic request identity so refreshing authorization cannot mutate the underlying operation. Resolve/replay the original action before accepting a conflicting next action. Never age out an unknown debit into a fresh operation ID after 120 seconds.

Scope the journal to environment/project, account, and stable game-session identity. Require operation IDs on every managed action that can affect shards or prize inventory, while preserving legacy request compatibility. Journal storage must confirm the write before sending; if it is unavailable, explain the recovery requirement and disable new economic submission rather than silently using volatile memory.

Idempotency prevents applying an accepted request twice; it does not stop an unaccepted stale request from executing in a later round. Bind each new managed economic action to the expected table session, rules/storage revision, round or next-round sequence, and applicable decision step. The transaction checks those immutable preconditions when accepting the action. Automatic retries retain them and the original payload/ID; never refresh the round/turn to make an old request succeed. An expired/rejected attempt becomes a definitive rejection with no debit. Replay an already accepted operation before checking its now-stale round or expired reservation, but after verifying the requesting account. Resolve an operation that is not yet recorded without assuming no in-flight commit exists; keep the old ID and preconditions, or use a transactional cancellation/tombstone before replacement.

Use an explicit versioned economic-field allowlist for the managed request hash, rather than removing a few token fields from an otherwise arbitrary request object. Keep existing legacy hashes/replays compatible. Managed replay returns the recorded outcome and a separately loaded redacted current view; it cannot call the mutating `run()` path, refresh `seen`, consume a reservation again, or advance a hand.

Test crashes before send, after commit but before response, during reload, and after table closure. A timeout is **CHECKING YOUR LAST ACTION**, not an assumed loss or refund. Clear an entry only after a definitive response or authoritative operation lookup. Never replay one account's journal after signing into another account.

Public floor state must contain only deliberately allowed information: avatar appearance/pose, names, and public occupancy. Do not broadcast balances, private stacks where not public under current rules, hole cards, folded cards, hidden deck/shoe state, unrevealed seeds, per-user receipts, access tokens, or recovery credentials. Continue using per-user `view()`/history redaction. Spectator art cannot bypass it. Verify bot seat presentation from public backend state rather than assuming every occupied seat is a human avatar.

Shards remain existing play currency. This task changes hosting and reliability, not casino economics.

## 10. Independent dealer and obligation recovery

Run a bounded, authenticated recovery loop in the Render service, independent of player requests and socket count. Extract an internal table-advance/sweep interface from the current handler. It must use the same engine, time rules, state versions, transaction path, fairness records, and books accounting as player requests.

Separate ordinary due advancement from abandonment cleanup. Existing `sweep()` forcibly zeroes deadlines/review gates and marks players absent; it is not the normal live-table dealer loop. Its `updated_at`-based stale query is also insufficient once a worker writes regularly. Compute due work from phase/bot/review deadlines, each human's `seen + AWAY_MS`, and departed obligations. Blackjack/Hold'em human turns have `deadline=0`; zero cannot mean that away checks are unnecessary. Preserve the existing active-player choice timing and do not introduce a human turn timer in this task.

Persist the next due time or equivalent index in the same successful transaction as every table change, including player requests, worker steps, heartbeat changes, and session creation/closure. A startup repair scan covers legacy/missing scheduling records. Fair keyset selection and bounded retries prevent one malformed/unsupported table from starving the backlog; quarantine its automatic writes, alert with its outstanding liability, and keep supported tables progressing. Do not silently close or refund a quarantined table.

The loop must:

- Select due active tables, timed phase transitions, genuinely away seats, pending departures, stale legacy sessions, and unresolved obligations with bounded queries and fair pagination.
- Advance only due work. Do not poll/write every table at movement rate. Use due-time scheduling, bounded batches, backoff, and an observable oldest-work age.
- Avoid refreshing a player's `seen` timestamp merely because the worker inspected their table. Socket connection alone does not mean active table play; preserve the current away policy and normal active-sheet polling.
- Preserve minimum result-review periods and game-specific rules. Do not fast-forward live players' hands to clear a backlog.
- Apply automatic absence actions using existing game rules. Disconnected Blackjack/Hold'em participants cannot strand everyone; active human decision turns retain their existing rules unless a separately documented scope change is required.
- Finish accepted machine rounds and other unresolved outcomes after departure, and preserve their receipts.
- Roll out non-cancellable departed-player craps obligations in bounded batches, persist each committed transition, and resume until resolved. No arbitrary maximum-roll refund, distribution-changing shortcut, or repeated new seed after restart.
- Recover stale legacy casino obligations too, without migrating old room identity or corrupting still-active legacy sessions.
- Schedule the existing casino books check independently of the next user lobby request, preserving its current day boundary and audit scope.

Persist recovery progress through table state and a queryable due-work mechanism. An in-memory timer is a wakeup mechanism, not the only record that work exists. When Render was unavailable, restart discovers outstanding work without a browser visiting the casino.

The worker is not authorized to open new wagers, fabricate players, extend departed seats forever, mint refunds, or run unbounded catch-up. Separate worker authorization from public user operations. Reusing modules under Node must preserve Web Crypto and runtime behavior; prove parity against the existing Deno request adapter.

Use one shared server-time contract for Node and Deno, including drift detection against database time. Worker delay and clock skew cannot shorten a live review, change a seed/disclosure boundary, or select an alternative result. Register which storage/rules revisions each adapter can read and write; an older owner must not act on an unsupported row created by a newer API merely because it still holds a lease. Test mixed-version rollout and require a compatible recovery adapter before admitting those sessions.

## 11. Ownership, crash recovery, and deployments

Even one configured Render instance can overlap with its replacement during a deploy. Implement database leases and fencing for room mutations and worker commits. A fencing epoch is checked within the privileged write/transaction, not just read once before a long operation. After takeover, the old process cannot renew presence/reservations or advance tables with its stale worker epoch. Existing table version checks still handle concurrent player operations.

For this release, prefer one world owner and one recovery-worker owner with documented lease intervals over a distributed room-routing platform. Use database time for lease expiry. During replacement, a standby instance must report its role accurately and give connecting clients a retry/recovering response until ownership is acquired. Separate process health/readiness from lease ownership so the deployment cannot deadlock waiting for the old owner to disappear before Render will replace it.

The deployment health-check path must report a bootstrapped standby healthy when it can participate in a takeover, without falsely reporting that it currently admits players. Report admission/ownership separately. Test the real sequence: new process healthy, traffic cutover, old process still holding the lease, then old `SIGTERM` and handoff. Render currently waits 60 seconds after cutover before signaling the old process, so a passive takeover cannot promise admission within 30 seconds of new process startup. Show recovering during that wait and measure the complete user-visible interruption. [Render deployment sequence](https://render.com/docs/deploys).

On `SIGTERM`: stop admissions and new reservations, notify connected clients, stop acquiring recovery work, finish or safely abandon bounded in-flight work, checkpoint recoverable floor state, release ownership only after quiescing, close sockets, and exit within the configured shutdown window. New service acquisition restores room definitions and table-backed seats, increments epoch, and admits resumed clients.

On hard process kill: no final checkpoint is assumed. Use the latest compatible position or safe spawn, rebuild occupancy from committed seats, expire uncommitted reservations, reacquire leases, and resume outstanding table work. Never roll back committed financial state to a floor checkpoint.

If Supabase is unreachable, prevent new admissions/seat commitments and financial actions that cannot be confirmed. A current room may display its last snapshot and status, but must stop claiming healthy authority when its lease cannot be renewed. Never present an expired owner as a working casino.

A brief reconnect during deploy is acceptable. Losing room identity, a wager, a receipt, or duplicating a debit is not. Zero-downtime HTTP deployment does not mean an existing WebSocket survives replacement. [Render documents socket interruption and reconnection](https://render.com/docs/websocket).

## 12. Render configuration, security, and operations

Deliver a reviewed `render.yaml`, a dedicated server package with pinned dependencies/lockfile, reproducible start/build commands, an `.env.example` containing names only, and local startup documentation. Proposed location: `dev/server/casino/`; shared pure modules may live under `dev/shared/casino/` if compatible with the existing assembler.

Pin the deployed Node runtime and define ESM package/module boundaries for all imported shared files. A child server package's `type:module` does not govern `engine.js` imported from another directory. The audited local Node 20.10.0 rejects that direct import without an explicit module-loading arrangement. Use a supported packaging/build solution and prove normal production startup plus Deno/test parity; an experimental audit flag is not the deployment recipe. Extend ignore rules for new server dependencies and local secret files. Verify shared browser modules are assembled/copied into published assets: GitHub Pages excludes `dev/`, so the website cannot import a runtime URL under `dev/shared/`.

Bind HTTP and WebSocket upgrade handling to `0.0.0.0` and `process.env.PORT`. Use WSS publicly. Expose `/healthz`, `/readyz`, and a safe version endpoint reporting build/protocol/layout revision. Health responses contain no secrets, private account data, or hidden game state. [Render web-service configuration](https://render.com/docs/web-services).

Start on a paid instance; a Free web service sleeps after 15 minutes without inbound traffic. Empty permanent rooms cannot depend on artificial user traffic to stay available. [Render free-service limits](https://render.com/docs/free).

Store durable state in Supabase rather than the Render filesystem. Render's default filesystem is ephemeral; attaching a disk changes deployment behavior and is not required by this design. [Render deployment and storage behavior](https://render.com/docs/deploys).

Required configuration concepts: environment, endpoint, Supabase project URL, backend credentials, allowed web origins, enabled protocol/layout, room capacity/count, input/frame/rate limits, admission flags, lease/recovery timing, and graceful shutdown timing. Confirm the actual region based on player latency and Supabase location; benchmark both rather than assuming co-location is available.

Use separate staging data and credentials. Privileged keys are server-only. Prefer restricted RPC access for privileged operations; enable RLS on exposed tables, restrict grants and policies, and check authorization inside privileged functions. Validate user eligibility separately from `authenticated` role membership because anonymous sign-ins also use that role. Never authorize from editable `user_metadata`. [Supabase API-key guidance](https://supabase.com/docs/guides/getting-started/api-keys).

Origin checking and rate limiting supplement token validation; they do not replace it. Bound account/IP connection attempts, unknown-room lookups, pending reservations, chat, and malformed-message work. Allow explicit development origins only in development. Never log bearer tokens, private cards, seeds, or database credentials. Rotation/revalidation must be documented; verification of a signature alone is not proof of current session status. [Supabase session-validation guidance](https://supabase.com/docs/guides/auth/server-side/advanced-guide).

Record structured, redacted telemetry: build, room ID, epoch, pseudonymous correlation IDs, admission/reconnect outcomes, disconnect reason, tick/event-loop delay, socket backlog, recovery backlog/age, lease loss, transaction conflicts/replays, unresolved operations, and books failures. Include an operator playbook for service down, database down, stalled obligation, queue overload, expired key, maintenance, and rollback. Any manual wallet correction requires a separate owner-approved accounting action.

## 13. Performance and reliability gates

Treat these as acceptance targets to measure, not claims about a $7 instance. Initial load envelope: **10 rooms × 6 connected players**, with a realistic mix of walking, chat, table play, and cabinet activity. Test room admission beyond the configured maximum safely. Publish the supported capacity for the measured instance rather than advertising an untested player count.

| Metric/scenario | Candidate gate |
|---|---|
| Healthy join in the chosen test region | p95 ≤ 3 seconds from authenticated entry to confirmed playable floor; report authentication/network timing separately |
| Movement | 30 Hz simulation / 15 Hz snapshots at target load; p95 simulation work below one tick interval; no growing socket queues |
| Service takeover | p95 ≤ 30 seconds after the replacement is healthy and the old ownership lease is released/expired; separately report process startup, traffic cutover, platform overlap, and the full user-visible interruption |
| CPU/memory | Two-hour target-load soak; at least 25% measured headroom in each, no sustained memory growth after warmup |
| Degraded networks | 150 ms RTT, 30 ms jitter, and 1% loss; remain usable without divergent positions, duplicate avatars, or duplicate financial actions |
| Slow receiver | Bounded buffers; latest movement state coalesces; critical commands remain ordered or receive a clear disconnect/retry response |
| Due table work | First recovery attempt within 10 seconds of becoming due on a healthy backend; observe retries and backlog |
| Empty-room operation | No world tick for an empty floor, no phantom presence or wagers, no per-room movement writes; publish idle call rate/cost |
| Financial correctness | Zero duplicate debits/credits, lost accepted obligations, private-card leaks, or unexplained casino books discrepancies |

Craps obligation completion has no fixed roll-count/time guarantee. The requirement is prompt attempts, durable progress, fair scheduling, and eventual settlement under the original rules. Use deterministic injected roll sequences in recovery tests rather than flaky assertions about random completion time.

Provide monthly cost projections for idle, expected, and target load: Render compute, WebSocket egress, Supabase requests/database writes, auth verification, and recovery activity. Render outbound WebSocket traffic is billable usage. Quote current prices at release and state assumptions. Upgrade the instance or reduce the advertised capacity if measurements miss the gate; do not hide failure with reduced correctness.

The 60-player envelope is an engineering target, not an unverified release claim. A candidate that misses it records the failed gate and proposes an instance upgrade or explicit revised capacity for release review; it cannot silently redefine a pass. Performance evidence includes actual run count/sample size and maximum values. A two-hour soak does not establish monthly availability. Claims about replay/recovery require fault injection against the real adapters; schema concurrency/locking tests require a disposable full Postgres instance in addition to fast PGlite checks. Never use production shards for soak or chaos tests.

## 14. Implementation phases and exit criteria

Complete phases in dependency order. A phase is finished when its exit evidence exists, not when its files have been created.

| Phase | Deliverable | Exit criteria |
|---|---|---|
| A — Baseline and contracts | Audit, authority map, schema/transport plan, legacy compatibility matrix | Exact entry/join/invite/seat/recovery paths enumerated; measured baseline and costs recorded |
| B — Durable rooms and shared layout | Migrations, room registration, directory, layout/collision module | Idempotent room seeding, atomic capacity/lease tests, permission checks, browser/Node layout parity |
| C — Render floor | Authenticated WSS, movement, chat, snapshot/reconnect adapter | Creator departure and last departure tests pass without PeerJS; six-client movement/collision verified |
| D — Transactional seats and operation recovery | Reservation validation, table reconciliation, durable action journal | Seat races, insufficient balance, lost-response/reload, duplicate tabs, direct-HTTP bypass tests pass |
| E — Independent recovery | Shared advance API, bounded dealer loop, due work, books schedule | No-user recovery across hard kill; stale-worker fencing and deterministic craps continuity verified |
| F — Product integration | Entry, directory, invitations, error states, controller/touch, persistent table start | Every casino route uses managed transport; screenshots and recordings verified at required viewports |
| G — Release candidate | Targeted regression, soak/chaos/privacy checks, infrastructure recipe, rollback | Acceptance matrix complete; costs and supported capacity measured; no unresolved correctness failures |

Do not migrate all of `NET` or all casino math while building the floor. Keep interfaces narrow and reviewable. If source findings invalidate a contract, update this work order and the compatibility plan before implementing a materially broader change.

## 15. Required verification matrix

Add meaningful tests to the existing runner and tag them by casino/server/net area. Use disposable databases and test accounts. Tests must inspect authoritative state and ledger/operation records where relevant, not only DOM messages.

| ID | Scenario | Required evidence |
|---|---|---|
| P01 | Two independent browsers enter normally | Same registered room; neither invokes casino `netHost`, PeerJS, or TURN |
| P02 | First entrant closes while others walk/play | Others continue in the same room with no host-loss path |
| P03 | Everyone leaves; return after 30+ minutes | Same room ID/join code; zero stale avatars; room remains available |
| P04 | Seven simultaneous joins to a six-person room | Exactly six admitted; seventh gets full/overflow; no partial membership |
| P05 | Restart and hard kill during presence/table play | Room stable; seats recovered; positions safe; latest committed financial state retained |
| P06 | Old/new service overlap, stale owner writes | One authoritative owner; stale epochs cannot mutate room/reservation/worker state |
| P07 | Temporary database failure and lease expiry | Clear recovery state; no unconfirmed economic action or expired-owner admission |
| P08 | Token expiry, logout, account switch | Refresh works; invalid sessions stop acting; no cross-account avatar/journal reuse |
| P09 | Second tab and explicit takeover | One controller; old generation rejected; table stack and buy-in unchanged |
| P10 | Two applicants race for the same seat/cabinet | One committed occupant; loser not charged; transient reservation resolves |
| P11 | Seat confirmation lost / reservation expires after commit | Exactly one buy-in; committed seat recovered; no ghost standing player |
| P12 | Forged managed room/reservation, direct HTTP, teleport | Rejected server-side without debit or other-player mutation |
| P13 | Each shard action retried/reloaded after lost response | Original operation ID resolves once; ledger and receipt agree, including closed-table replay |
| P14 | Same operation ID with altered economic payload | Rejected; refreshing authorization does not alter request identity |
| P15 | First sitter leaves a new public Blackjack/Hold'em table | Managed start policy works at legal player counts; legacy setup remains compatible |
| P16 | Last departure during every game phase | Accepted rounds finish; uncommitted funds return under existing rules; receipts survive |
| P17 | Departed craps with Pass/Come obligations, no clients | Worker finishes injected roll sequence across multiple batches/restarts without a new user request |
| P18 | Worker and player request race / worker takeover | Optimistic conflict resolves; one settlement and one history row; stale worker cannot commit |
| P19 | Worker touches table with absent player | No false `seen` refresh; away policy applies; live review intervals are preserved |
| P20 | Public snapshots, chat, spectator views, history | No private cards/seed/shoe/token leaks; existing Hold'em/Baccarat disclosure rules pass |
| P21 | Old cached site, old room, mismatched layout/protocol | Clear compatibility response; old obligations remain recoverable; no namespace collision |
| P22 | Front door/Open Games/code/friend invite after restart | All enter the same managed room; epoch change preserves valid invite target |
| P23 | HIDE/STAND UP/LEAVE, pending departure, service outage | Distinct outcomes; recoverable cash-out/history; no automatic refund or second debit |
| P24 | No traffic across audit boundary | Recovery continues and books check runs on its documented schedule |
| P25 | Malformed floods and slow clients | Limits enforced; other rooms stay usable; buffers bounded |
| P26 | Target-load soak and network shaping | Recorded latency, CPU/memory, tick timing, egress, database call/write rate, recovery age |
| P27 | Requested managed seat occupied, another seat free | Exact-seat refusal, no buy-in or snap to another index; legacy fallback remains scoped |
| P28 | Unaccepted request arrives after round/turn changed | Original preconditions reject without debit; accepted old-round replay still returns its original result |
| P29 | Superseded tab sends HTTP state/ready/bet/replay | No mutation or `seen` refresh; pure account-owned reads remain possible |
| P30 | Due worker writes keep `updated_at` fresh; human turn has no deadline | Away cleanup still runs from seat activity time; active human choices and review gates are preserved |
| P31 | Dealer delayed, clocks skew, scheduling row missing/poisoned | Correct recovery deadlines/results; startup repair and fair selection prevent starvation |
| P32 | Live Render cutover with healthy standby and old owner | No readiness deadlock or split authority; full outage measured across the platform overlap |
| P33 | Managed six-character code / inviter departs / invalid invitation | Typed join before PeerJS; target survives inviter departure; friendship/expiry/limits/full-room behavior enforced |
| P34 | Node/Deno mixed revisions and published shared modules | Normal pinned-runtime startup; compatible writes only; website has no imports under excluded `dev/` |
| P35 | Journal write fails, attempt absent but request still in flight | No send before durable write; no replacement until authoritative resolution/cancellation; environment/account isolation |
| P36 | Floor down during accepted Blackjack/Hold'em decision | Verified recovery controller can complete legal existing activity; no duplicate controller/new unrelated wager |

Use existing `tables_engine`, `tables_server`, `casino_games_engine`, `casino_server`, `tables_ui`, `casino_games_ui`, `casino_map`, `casino_music`, `friends`, `accounts`, `csp`, and controller/menu checks where they exist in the current runner. Select by actual suite contents, not remembered names. Add a small combat host/join smoke check because entry/NET/invite code is shared. Broaden only when shared changes justify it.

Also include existing `fair_play`, `roulette_engine`, and `restore_schema` for changes to shared game adapters, disclosure, or migrations. Execute a required suite by its exact name even if it carries an `extra` tag and is not in the ordinary group selection. Add the new dealer, full-Postgres concurrency, seat admission, and controller-generation checks with explicit runner coverage.

Visually verify at least 390×844 and 844×390 touch, 1280×720 and 1440×900 desktop, and 2560×1440. Check six avatars, every table sheet, seat pending/error states, full room, reconnect, maintenance, pending wager, reduced motion, and controller focus. Provide screenshots and short recordings for entry, movement, a shared table, and a live service restart. Ensure the player remains visible beside/above the sheet and controls remain reachable without horizontal overflow.

Classify any existing failure with a reproduced baseline, exact test, and evidence. Financial, privacy, seat-authority, and recovery failures block this feature's release even if an older implementation also failed them.

## 16. Migration, compatibility, and rollout

Create additive migrations through the project's supported Supabase workflow. Keep a clean migration history and a verified restore schema. Record required RLS/grants, function signatures, new namespace handling, and versioned worker/reservation contracts. Do not drop legacy functions or rewrite existing ledger/history data to introduce rooms.

Keep client economic request compatibility explicit. Managed room requests must not slip through the legacy unaudited admission path. Preserve legacy table servicing until those sessions drain. Independently version casino wire protocol, layout, server adapter, and rules; choose the release version after inspecting the actual branch. Update source footer/build cache, `dev/STATUS.md`, endpoint/CSP configuration, and documentation together. Inspect every `NET.mode`, host check, room-code assumption, and session reset touched by casino integration.

Rollout sequence:

1. Run the full required matrix locally and in isolated staging, including live Node ↔ database ↔ browser integration and runtime parity.
2. Produce the candidate, current cost estimate, measured capacity, migration review, and rollback checklist for release review.
3. After release authorization, apply backward-compatible storage/functions first; verify permissions and legacy requests.
4. Deploy compatible tables API/reservation checks and the paid Render service with managed admission disabled. Verify secrets, build IDs, leases, recovery, directory, and health.
5. Enable a test-account allowlist for the managed casino. Confirm all seven games, a no-clients obligation recovery, a service replacement, and books reconciliation.
6. Publish the compatible website, then enable public admission in a controlled step. Preserve old cached clients and ongoing legacy casino obligations.
7. Monitor joins, retries, conflicts, old-owner rejection, recovery age, debit/receipt consistency, and cost. Verify the next scheduled books result and repeat a representative production reconnect with test accounts.

Do not label a release complete just because Render says the deploy succeeded. Confirm the served site/assets, server build/protocol/layout, migration state, API version, public-room join, and recovery behavior actually agree.

## 17. Maintenance and rollback

Provide independent controls for new admissions, new seating/wagers, floor connections, and ongoing obligation recovery. Operators can stop new exposure without disabling payout/recovery paths.

Rollback must preserve committed state:

1. Disable new managed admissions and new wagers; show maintenance. Keep accepted-operation replay, valid departures, receipts/history, and the recovery worker available.
2. Keep a compatible engine running until all accepted hands/spins/rolls and non-cancellable obligations settle. Do not refund a settled losing wager or cut short a craps point to simplify rollback.
3. Roll back the floor/client adapter only to a compatible build, or leave the casino in maintenance if the older client cannot understand managed rooms. Never silently switch the same managed ID to a P2P/solo room.
4. Retain room records, casino tables, operation IDs, ledger, history, and additive schema. Do not restore wallet/table data from an old snapshot over live accepted transactions.
5. Reconcile books and verify no account is stranded before retiring a worker/API version. Keep the oldest required rules version supported until its open obligations reach zero.

Document the maximum understood recovery gap and oldest outstanding obligation at rollback. If the current Render service must be rolled back, the replacement must be able to keep running the shared recovery interface and honor the same fencing contract.

## 18. Required handoff

Deliver these artifacts with the implementation:

- Baseline audit and concise architecture/authority decision record.
- Source changes, server package/lockfile, shared layout, additive migrations, current restore schema, and reviewed Render blueprint.
- Local/staging setup and names-only environment examples; exact region/instance choices and current costs.
- Message schemas, room lifecycle, seat/reservation transaction contract, reconnect policy, worker scheduling/fencing, and compatibility matrix.
- Test result matrix with links to logs, financial queries, privacy assertions, performance data, screenshots, and recordings under a dated `dev/evidence/` directory.
- Operator runbook, maintenance switches, deployment order, rollback, credential rotation, and capacity limits.
- A final release report stating what shipped, where it runs, what was verified, measured capacity/cost, and any remaining limitation. Never call unfinished recovery work a future enhancement after claiming persistent casino completion.

**Definition of done:** the first player can leave; the last player can leave; the casino remains joinable with the same identity; Render can restart; every accepted casino action remains correct and recoverable; no hidden game information leaks; combat multiplayer still works; and the evidence demonstrates each claim.
