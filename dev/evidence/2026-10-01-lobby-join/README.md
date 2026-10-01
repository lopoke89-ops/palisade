# Blitz Open Games fix

Live reproduction: room `4SJA`, hosted by `lopoke89`, was reachable by code but
absent from Open Games. It was running co-op Blitzkrieg Rush on Riverbend XL.
The database's `lobbies_length_check` accepted only `5`, `10`, and `endless`,
so the client's `length='blitz'` publish heartbeat was rejected.

Applied Supabase migration `20261001053822_blitz_open_lobbies` to project
`puvjfhwxigxjpsvdwrwf`. It adds `blitz` to the allowed lengths. Updated the
saved schema to match. Existing lobby ownership policies and RLS stay intact.
No frontend build or room protocol change is needed; existing hosts retry
publication every 15 seconds and browsers refresh the list every 6 seconds.

Verification:

- `node dev/test/blitz_lobby_migration.js` passes nine checks: reproduces the
  previous rejection, applies the migration twice, accepts all four lengths
  and null for PvP, rejects unknown lengths, and tests the fresh schema.
- Live database reports the four-value constraint and RLS enabled.
- The live host's heartbeat published room `4SJA`, length `blitz`, protocol
  `yard-20`, with two players and an age of about four seconds.
- The guest left and saw `lopoke89's game` in Open Games with Blitzkrieg Rush.
- Clicking that listing joined room `4SJA` as `Codex test`, with both players
  visible in the crew and the host's map and modifiers received.

Screenshots: `joined-4SJA.jpg` (original direct join),
`open-games-fixed.jpg` (repaired public listing), and
`joined-from-open-games.jpg` (successful join through the listing).
