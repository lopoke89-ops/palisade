# Player-hosted casino relay — execution evidence

October 8 scope correction: player-owned lobbies over a Render relay. The previous permanent-world work and its paid proposal are superseded and retained on `casino-persistent-render`/PR #28.

This candidate starts at production source `76b5c90bb5402da1165f3f0c8b3175b7aafe454b`, v0.10.4. Current local candidate v0.10.5 build `fbee990702` has relay entry disabled until isolated live verification.

Passed locally using Node 22.17.0 and installed Chrome:

- Three real-socket server contracts: six-player limit, verified guest identity, no guest-to-guest/cross-room routing, account/session-bound resume, host grace/departure, locks, removal/ban, stale invitations, token-account changes and flood isolation.
- Six real browser contexts: movement through the player host, brief host/guest socket interruption and resume, full/locked errors, host departure cleanup, zero PeerJS/TURN requests and zero browser exceptions.
- All seven games through the relay adapter: existing table/request-engine UI tests, shared/private Hold'em information, accepted spin retry and balanced books. These use fixture Auth and the real request handler with in-memory financial storage; they do not certify a live Render game round.
- Additive code migration in disposable Postgres: legacy four-character codes, restricted six-character relay casino codes, existing saved-account/anonymous grants, and actual friend invitation send/accept. Repeated application retains compatibility.
- Existing combat multiplayer, room controls, friends, casino map and CSP. Account-scope/build changes repeated the room/friend/CSP checks successfully.

Logs and a local mobile floor screenshot are included. The photograph is from the local test, after one player has departed; it is not live Render proof.

Isolated Supabase staging was checked before replacing the old service: zero open tables/seats, admissions/new wagers off. Applied only `casino_relay_lobby_codes` there, preserving all financial records. A real saved staging account successfully passed the relay Auth/profile lookup with the public key. Production is unchanged.

Still required before public enablement: deploy the relay on Free, test real staging Auth/browsers/traffic and process restart/cold-start behavior, then verify production rollout and served assets. No paid purchase or card is required by this candidate.
