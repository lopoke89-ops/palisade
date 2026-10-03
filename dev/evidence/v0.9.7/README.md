# v0.9.7 City Black Out: evidence

Branch `claude/lucid-curie-491na1`, protocol `yard-26`. Work order: [city-blackout-work-order.md](../../plans/city-blackout-work-order.md). Defaults D1–D10 were taken as written, per Big U ("execute the work order as is, assume the defaults").

## Phase 0 gate (big-map engine)

Measured in headless Chromium on the build container, which has **no GPU** (software rendering). Absolute frame times are pessimistic, so the gate compares the city with Quarry XL, the biggest existing map, on the same machine.

| Run | Average frame | Chunk memory | Chunks held / keep budget |
|---|---|---|---|
| Desktop 1366×820 · Quarry XL, 60 raiders | 16.0 ms | 74 MB (single picture) | n/a |
| Desktop 1366×820 · City 64×64, 60 raiders | 23.0 ms | 49 MB | 68 / 2×34 |
| Phone 844×390 @3x · Quarry XL | 19.8 ms | 57 MB | n/a |
| Phone 844×390 @3x · City 64×64 | 26.6 ms | 41 MB | 48 / 2×34 |

- The city costs about 1.35–1.45× Quarry XL per frame and uses **less** scenery memory, since chunks replace the one big picture. That is under the 120 MB budget.
- Most of the frame is drawing 60 characters (~10 ms here). That cost is the same on every map.
- The p95 numbers in `blackout_perf.json` (63–79 ms) are software-GPU flush stalls. With per-section timing, which syncs each frame, only 2 of 240 frames ran over 30 ms, and no slow frame lined up with a chunk paint.
- Pathfinding is now a heap Dijkstra (XL Yard: 15.8 ms → 0.3 ms per rebuild). It matched the old algorithm exactly on all 8 map/size combinations.
- **Decision: 64×64 kept.** The 48×48 fallback still builds and passes `blackout_map`.
- **Still needed: a real mid-range phone.** Big U should play a run and report whether the frame rate holds. If it doesn't, switching `CITY_N` to 48 is one line in `06e-city.js`.

## Tests added

| Test | What it proves |
|---|---|
| `blackout_map` | 64 and 48: Main Command centred, all 8 POIs reachable by road, raiders path from every edge to every POI, roads 1.35× / rubble 0.8× speed, lights follow held / lost / power |
| `blackout_run` | 45 s gathering, minors then majors, 30 s gaps, 60 s cap, held / lost / pulled back, repairs in the quiet, perks on and off, final-push penalties (+1 squad per lost major, +5% boss health per lost minor), boss cap 4, the Destroyer at 3:00 with shield and grenadier squads only, his death ends the run, Main Command falling loses |
| `blackout_destroyer` | Each attack's warning state, damage only inside its area (dodges take 0), Orbital Cannon only below 40%, mines arm / trip / shot safely, gas hurts inside only, warnings draw, 1.25× health, weak to AP |
| `blackout_network` | Guest gets yard-26, mode, city, attack target and stage, near raiders only (far ones not sent, bosses always), POIs lost, dark city, summary restored after a wipe (rejoin path), final push and the Destroyer |
| `blackout_rewards` | The claim (cv:5, 9 stages, 8 POIs, 4 majors, Destroyer), the no-account locker paid by the server's rules, ladder counters and unlocks, Locker milestone strip with 6 items |
| `blackout_migration` | PGlite, 22 checks: payouts, every limit, repeat claims, pre-cv:5 clients rejected, other modes unchanged, rooms and lobbies accept the mode, migration applies twice, no `delete` in the file |
| `blackout_perf` | The gate above, run on every suite pass |

## Server

`dev/supabase/migrations/20261003200000_v097_city_blackout.sql`: **not applied yet; waiting for Big U's approval.**

- **How it's built:** the local migration chain rebuilds `claim_match_reward` byte-for-byte as it is live (md5 `b1edbe70ad20e5ab66294d30ea5bcfe6`, 22,470 chars). The migration patches the live text in the database, and every anchor must match exactly once or it stops. It never contains the word `delete`.
- **What it changes:**
  - adds `blackout` / `city` to `room_register` and the lobby length rule;
  - adds `pois_held` and `destroyer` columns to `match_results`;
  - adds 6 catalog-5 unlock rows.
