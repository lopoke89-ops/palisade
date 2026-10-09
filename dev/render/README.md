# Casino connection relay

This candidate serves **player-hosted casino lobbies**. Render routes their WSS floor messages. The player host still runs the floor; the existing Supabase table API still deals every game and owns financial state. See the [corrected work order](../plans/casino-render-relay-work-order.md).

Run Node 22.17.0 and `npm ci --omit=dev` / `npm start` in this directory. Set:

| Variable | Value |
|---|---|
| `SUPABASE_URL` | Auth/database project's public HTTPS URL |
| `SUPABASE_PUBLISHABLE_KEY` | That project's **public** publishable key |
| `ALLOWED_ORIGINS` | Exact comma-separated site origins |
| `MAX_ROOMS` | Bounded room count; default 10, six humans each |
| `PORT` | Render supplies this; local default 10000 |

The relay requires no server/service-role key, persistent disk, paid plan or unattended worker. Do not expose player bearer tokens in URLs, logs, directory responses or snapshots. Browser Auth refresh stays in the browser. The relay verifies each initial/renewed token remotely, and its expiry ends access.

`/healthz` and `/readyz` identify the deployed commit, wire, process epoch and aggregate traffic counts without player IDs. `/relay` is the authenticated WSS endpoint. Open Games uses the existing Supabase directory and each host's listing preference; the relay exposes no alternate room directory.

Casino codes are six characters starting with R. Code/incarnation/reconnect capabilities are independent: the code shares a lobby, the incarnation binds invitations, and an opaque account/session-bound resume value restores only the same peer within 20 seconds. A creator departure closes their room. A process restart ends its rooms and requires a new lobby; it must not confer old-code ownership on an arbitrary client. SQL table/wallet/history data survives separately.

Free can sleep after 15 minutes without incoming traffic; joining after sleep takes about a minute. Ordinary active-session traffic/heartbeat detects connections; do not run an idle bot or artificial traffic to force 24/7 operation. Bandwidth/free-hour limits still apply.

`client.json` enables the public relay endpoint in the v0.10.5 candidate. The builder embeds it and exact WSS/HTTPS CSP origins. `PALISADE_RELAY_CONFIG` and `PALISADE_BUILD_OUTPUT` create an isolated preview with a separate staging account-storage scope. Only public configuration belongs here.

The previous permanent-world service is preserved on `casino-persistent-render` and closed, unmerged PR #28. Its paid upgrade proposal is superseded by the user's clarified scope. Deployment and validation are recorded in [the release evidence](../evidence/casino-relay-2026-10-08/README.md).
