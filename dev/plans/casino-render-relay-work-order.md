# Player-hosted casino lobbies through Render

Scope corrected October 8, 2026 after the user's clarification. The creator is the casino lobby host. Render relays connections so browsers do not need a direct P2P route. Empty lobbies can close and the Free service can sleep. The earlier `casino-persistent-render` branch and closed, unmerged PR #28 are preserved as a superseded candidate; their permanent public rooms, independent continuous worker, paid-hosting proposal and always-on acceptance gates do not commission this release.

## Player experience and authority

1. A saved player selects ENTER THE CASINO, creates a lobby and becomes its floor host. The lobby has up to six humans including its host. Friends join by casino code, share link, Open Games or invitation.
2. Every updated casino browser connects to the same Render relay over WSS. The host receives guest input and sends the existing floor snapshots/chat. Combat keeps its existing transport.
3. Supabase continues to deal all seven games and own wallets, shards, cards, outcome verification, operation receipts and history. The relay does not run a second casino engine or carry private table responses. No production financial migration is needed.
4. The host keeps their browser running during the session. Explicit departure closes the lobby immediately. A lost host connection has a bounded 20-second grace period; if the host does not return, the lobby closes. A lost guest connection can resume the same peer within that grace. This does not promise host migration or an unattended casino.
5. An empty service can sleep normally. The first connection after sleep may take about one minute. The client shows connection progress and bounded retries rather than silently creating a solo or P2P casino.
6. A Render process replacement ends its in-memory lobbies. Clients explain that the relay restarted and ask the host to open a new lobby. Persisted table obligations remain in Supabase and use the existing table recovery/departure paths. Do not let a client recreate an arbitrary old code as if it still owned that lobby.

## Implementation contracts

- One Free Node 22.17.0 web service with pinned `ws` 8.22.0. TLS/WSS, exact allowed origins, six members per room, bounded room count, JSON payload/rate/send-buffer limits, ping/pong and exponential reconnect backoff.
- Saved account identity is checked through Supabase Auth and the account's profile using its public publishable key and the player's bearer token. The relay has no service-role key. Guest identity in the floor hello is replaced with the verified account identity.
- Host-only target routing, lock and removal. Guests can send only casino floor/lobby input to their own host; they cannot select another guest or another room. Invitations check the host's current incarnation.
- Opaque resume capability bound to verified account, browser session and role. New connection replaces the old socket; stale callbacks cannot remove the replacement. Expired/replaced/removed connections lose relay access.
- Casino codes use `R` plus five characters; existing four-character combat/legacy codes remain supported. Update both join inputs, share links, initial URL handling and invitation paths without truncation.
- The small additive migration extends existing lobby/room-session code checks and the saved-account `room_register` validator. Preserve its permissions, owner checks, expiry, locks, friendship checks and every legacy row. Do not apply the old persistent-world migration or staging restore to production.
- The browser uses the existing host/guest floor code through a relay channel adapter. It never uses PeerJS or TURN for a relay casino. Keeping an existing P2P combat crew when opening a new casino requires an explicit UI instruction to leave that crew first.
- Returning to the menu leaves the relay lobby. Clear relay state on logout/account change. Financial departure uses the existing authenticated table API and accepted operation IDs.

## Release evidence

Required for this scope:

- Real six-browser floor movement/chat and guest/host brief reconnects on the relay, with no PeerJS/TURN requests.
- Two simultaneous lobbies with isolated routing; full, locked, removed-player, stale invitation, unauthenticated, expired-token, oversized/flood and slow-send behavior.
- Explicit host departure and grace expiry close the lobby; Render restart fails clearly rather than silently changing identity or transport.
- All seven game UI/rule/ledger suites on the relay adapter, including private Hold'em cards, touch/reduced motion, accepted-request retry and exact reconciliation.
- Additive migration tests for four/six-character codes, saved-account grants and end-to-end friend invitation acceptance.
- Live isolated Render/real-Auth check on Free, actual cold-start/restart behavior and bounded session traffic measurement. The previous heavy server-owned 60-client failure does not establish relay capacity.
- Existing combat, friend, CSP and generated production asset checks. Finish a separate staging candidate before enabling the public client.

No two-hour 60-client, permanent room, no-client worker or daily always-on audit requirement is inherited merely from the superseded work order. Do not claim Free guarantees unlimited capacity, uptime or bandwidth; track actual usage and maintain the configured room cap.

## Rollout and rollback

Use the existing Free Render service for isolated verification after checking that its paused staging world has no occupants or unsettled tables. Keep its database/evidence intact. Replace its runtime with the relay; remove the unneeded privileged credential without reading its value, and set only public Auth configuration. No card or paid-plan upgrade is authorized or required by this work order.

After all relevant checks pass, apply only the lobby-code migration to production, configure the Free relay for production Auth and the exact GitHub Pages origin, deploy the verified relay commit, then publish the compatible client. Preserve ongoing casino tables and all financial data. Public-release authorization already exists; ordinary deployment within this corrected scope does not need another general permission request.

Rollback disables new relay casino entry and preserves existing table cash-out/history and ledger data. An already published relay lobby must not silently become P2P under its old code. Inform players before ending active sessions for a deployment.

Sources checked October 8: [Render WebSockets](https://render.com/docs/websocket), [Free idle behavior and limits](https://render.com/docs/free), [Supabase verified user lookup](https://supabase.com/docs/reference/javascript/auth-getuser).

## Completed release — October 8 CDT

Executed and published as v0.10.5, build `420cf3dc34`, through [PR #29](https://github.com/lopoke89-ops/palisade/pull/29), merged main commit `55da1b3`. The existing Free service runs the verified relay `08a20fd` with production public Auth and the exact Pages origin. Only `casino_relay_lobby_codes` was applied to production (remote history version `20261009032510`); the existing tables engine and financial schema remain unchanged. All relevant checks above passed within the limits recorded in [the execution evidence](../evidence/casino-relay-2026-10-08/README.md). The served public client and service worker match the tested release, and a fresh public browser loaded the updated worker/cache without exceptions or CSP violations. Six-user authenticated proof used isolated staging; production wagers were not used as tests. No paid hosting purchase or card was needed.
