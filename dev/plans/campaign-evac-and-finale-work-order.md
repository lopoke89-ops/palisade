# PALISADE: Operation Whiteout campaign rework (work order)

You are working on PALISADE (repo `lopoke89-ops/palisade`). It is a phone-first isometric co-op siege game:
- a single-page Canvas game;
- host-authoritative PeerJS multiplayer;
- Supabase accounts and rewards;
- a PWA on GitHub Pages.

The live release is **v0.9.6.3**, protocol `yard-23`. Ship this as **v0.9.7.0**, protocol **`yard-24`**.

Big U asked for three changes to the Operation Whiteout campaign:
1. Resources stay unlocked when you move to the next map.
2. Every map before the last ends with an evacuation.
3. The finale is replaced with a boss gauntlet: waves of 3-4 bosses (ideally three Rime Colossi and one random boss) every 30 seconds for 3 minutes, then 30 more seconds to reach the evac.

Read these first:
- `dev/STATUS.md`
- `dev/plans/blitzkrieg-rush-work-order.md`, for the evacuation rules this reuses.
- `dev/plans/winter-elevation-campaign-and-friend-invites-work-order.md`, for how the campaign was built.
- `dev/evidence/2026-10-03-efficiency/README.md`, for the packet and frame budgets.

Recheck GitHub `main`, the live footer and the live Supabase migration list before starting.

## Standing rules
- **Source and build:**
  - Edit `dev/src/` only, and rebuild with `python3 dev/build.py`.
  - Never hand-edit `index.html`, `sw.js` or `debug.html`.
  - Run `git checkout -- '*.png'` after each build.
- **Comments:** put comments on their own line or at the very end of a line. A `//` in the middle of one of the long source lines swallows the code after it; this has broken builds three times.
- **Tests:**
  - Add a test for every new behavior.
  - Run the full list with `bash dev/test/run_all.sh` before release; the file isn't executable. All tests must pass, and a test that exits non-zero fails.
- **Keep unchanged:**
  - the `palisade.*` storage keys;
  - stable element IDs;
  - the host-authoritative model;
  - Supabase as the reward authority.
- **Server changes need:**
  - A migration built from the **live** function text. Read it with `pg_get_functiondef`; `schema.sql` is stale.
  - PGlite tests.
  - Big U's approval before applying.
  - A rename of the file to the version Supabase records once applied.
- **Big U approves** every merge to `main` and every live migration. Show screenshots at desktop, phone portrait and phone landscape before merging.

## Where things live today (checked October 3 on `d3c21b4`)

| What | Where | Today |
|---|---|---|
| Campaign constants | `dev/src/js/10d-winter-campaign.js`: `CAMPAIGN` | 13 "waves": 4 chapters × 3 raids (Yard, Riverbend, Ashfall Quarry, Frostpeak), then wave 13, the finale |
| Chapter boss | `bossOf()` in `10-phases-bosses.js` | Raids 3, 6, 9 and 12: Frostbound Butcher, Icebound Ferryman, Permafrost Foreman, Rime Colossus |
| Map change | `campaignAdvance()` and `changeChapter()` | After raids 3, 6 and 9 the next map loads at once, followed by a build phase. Walls are wiped; core health, upgrades and supplies carry over |
| Resource locks | `kiln()` and `scrap()` in `06b-maps.js` | `unlock` is an **absolute** raid number; `startBuild()` opens a node only when `unlock === wave + 1` |
| Finale | `startFinalBlitz()`, `fbTick()`, `openEvac()`, `evacTick()`, `finishBlitz()` in `10c-blitz.js` | 5:00. One boss every 30 s, up to 10, at most 4 alive, from Frostbound Butcher, Permafrost Foreman, Rime, Tempest, Bulldozer. Raiders trickle in. Evac opens at 1:00 left |
| Evacuation | same file | 3-tile ring (r 1.5), stand 3 s on your feet to get out. Downed players don't respawn. Anyone still on the field at 0:00 is left behind: they lose and keep half their cases and shards (odd counts round up). Squadmates who made it still win |
| Rewards | live `claim_match_reward`, last rebuilt in `20261001081259_winter_whiteout.sql` | Map ladders credited per raid. Finale bosses capped at `least(10, 1 + (dur - 20) / 30)`. Rime pays 2 Winter Cases, white bosses 1, Tempest and Bulldozer 2 Blitzkrieg Cases, plus 15-30 shards and +1 base-boss milestone each. The evac pays +1 Winter Case and 25 shards |
| Rime ladder | `18a-winter-catalog.js` | `boss_rime` at 25 / 50 / 100 / 250 |
| Network | `21-online.js` | State packets carry `fb: [t, n, max, ex, ey, r, done]` and player `out`/`ev` (slow block) |

### The resource bug, measured

This is what a real campaign does today when stepped chapter by chapter:

| Chapter | Map | Kilns (brick) | Scrap (metal) |
|---|---|---|---|
| 1 | Yard | opens after raid 1 | **never opens**: due "raid 4", but the map changes first |
| 2 | Riverbend | **locked all chapter** ("raid 2" already passed) | one open, **one locked all chapter** |
| 3 | Ashfall Quarry | one open, **one locked all chapter** ("raid 3") | **locked all chapter** ("raid 4") |
| 4 | Frostpeak | open | open |

So players never get metal on the Yard, get no brick on Riverbend, and get no metal on the Quarry.

## 1. Resources stay unlocked (bug fix; no decision needed)

**Rule.** In the campaign, the unlock schedule runs only in chapter 1, on the Yard. From chapter 2 onward every node on every map starts open.

**Chapter 1 schedule:**
- the kiln opens after raid 1, as today;
- scrap opens after raid 2, one raid early, so the Yard gets a raid with metal before the map changes.

**Implementation:**
- In `changeChapter()`, after `layMap()`: `if(game.chapter>=1)for(const n of nodes)n.locked=false`.
- Campaign-only override of the Yard's scrap unlock: wave 3 instead of 4. Don't change the Yard's normal-mode layout.
- No resource toast on later maps.
- The chapter-change toast becomes "Every resource is open on this map."

**Guests:** nodes already sync in `nd`, so there are no protocol fields to add here.

**Test** (`campaign_resources.js`): step a campaign through raids 1-12 and assert the table above becomes:
- Yard: brick from raid 2, metal from raid 3;
- every node open on chapters 2-4;
- a guest sees the same locks after each map change.

## 2. Evacuation at the end of chapters 1, 2 and 3

**When.** After the chapter boss raid (raids 3, 6 and 9) is broken, instead of loading the next map at once:

1. **"MAP EVAC" phase.**
   - A countdown starts, **45 s** by default (decision D2).
   - An evac site opens with `evacSpot()`: the same green 3-tile ring, the same 3-second hold on your feet, and the same off-screen arrow.
   - No build phase and no Armory during it.
2. **Pressure** (decision D3): by default, small raider groups keep coming during the countdown, using the Final Blitz trickle at half rate. There is no new boss.
3. **Getting out:** the same as the Blitz evacuation.
   - You extract after standing 3 s in the ring and then watch from above.
   - Downed players don't respawn; a teammate or Delgado has to revive them in time.
   - Delgado extracts automatically when the countdown ends, if he's alive.
4. **When it ends.** The countdown hits 0, everyone is out, or nobody is left standing.
   - Remaining raiders retreat.
   - The next map loads with `changeChapter()` and the normal build phase starts.
5. **Left behind** (decision D1, which changes the rewards and the server). By default, a player who didn't make it **still continues to the next map**, so nobody is knocked out of a co-op run mid-campaign. They pay a price:
   - They lose half the Winter Cases and shards earned **in that chapter** (rounded up first, as in Blitz). The server applies this, using the per-chapter evac results sent in the claim.
   - They start the next map at 50% health with no salvage carried over.
   - Their result screen lists the evacs they missed.
6. **Everyone left behind** (decision D1b): by default the run continues with the same penalties. The alternative is that the campaign ends there as a loss.
7. **Core and stake:** the core can't be lost during a map evac. As in the Blitz evac, the core no longer decides the result once the evac opens.
8. **HUD and audio:**
   - Phase label `CH n · EVAC` with the countdown.
   - Toast: "EVACUATE: Get to the green ring. The convoy leaves in 45 seconds."
   - The siren, as in Blitz.
   - The result card per chapter shows `EVACUATED` or `LEFT BEHIND`.

**Implementation sketch:**
- Generalize the Blitz evac. Keep `openEvac()`, `evacTick()` and `extract()`, but drive them from a new `game.cev = {t, ch, evac, done}` (chapter evac) alongside `game.fb`.
- `campaignAdvance()` starts the map evac instead of `changeChapter()`.
- When the map evac finishes, it calls `changeChapter(ch + 1)` and `startBuild()`.
- Reset `p.out` and `p.ev` for everyone on the new map, recording each player's result in `p.chEvac[ch]`.
- Guests:
  - `cev: [t, ex, ey, r, done]` goes in the state packet.
  - The per-player chapter results go in the slow player block (`PL_SLOW`), so they cost nothing until they change.
  - Bump the protocol to `yard-24`.
- Rejoin stash: keep `chEvac` and `out` across a same-match reconnect. The `blitz_network` test already covers `out`.

**Tests** (`campaign_map_evac.js`, plus a network test):
- the evac opens after raids 3, 6 and 9 only, not after 12;
- extract and reset;
- downed with no respawn, then revived in time;
- the map loads after 45 s, or early when everyone is out;
- penalties for a player left behind;
- guest parity (phase, ring, results);
- a rejoin keeps the result.

## 3. The new finale: the Whiteout Gauntlet

This replaces the current wave 13 (the 5-minute single-boss Final Blitz) in the campaign only. Blitzkrieg Rush keeps its own Final Blitz unchanged.

**Timeline (3:30 total):**

| Clock | What happens |
|---|---|
| 3:30 → 0:30 | **Boss waves:** a wave of bosses at 3:30, 3:00, 2:30, 2:00, 1:30 and 1:00, so **6 waves**. No ordinary raiders (Big U: "a wave of just bosses") |
| 0:30 | **Evac opens:** no more waves. The bosses still alive keep fighting. You have **30 s** to reach the ring (3-second hold) |
| 0:00 | Remaining bosses retreat and don't count. Anyone not out is left behind (half Winter Cases and shards, as today) |

**Each wave** (decision D4): by default, **3 Rime Colossi + 1 random boss**, as Big U asked. Six waves is 24 bosses.

**Random boss pool** (decision D5): by default the Frostbound Butcher, Permafrost Foreman, Tempest, Bulldozer, Blue Butcher and Arsonist. Bosses that need a river (Ferryman, Icebound Ferryman, Harbinger) are left out because Frostpeak has no water. A boss isn't picked twice in a row.

**Keeping it playable:**

- **Alive cap** (decision D6): by default at most **8** bosses alive. Bosses from a wave that would go over the cap wait and arrive as others fall. Today's cap of 4 would turn 24 bosses into a trickle.
- **Health:** gauntlet bosses have **35% of normal health with one player**, plus 12% per extra player (35 / 47 / 59 / 71 / 83 / 95%). These are starting numbers, to be tuned in playtests.
- **Rime ruptures:** today a Rime won't start its rupture or dash while another boss is mid-tell. Keep that rule, so three Rimes can't all slam at once. Spread their first tells: 0, 1.2 and 2.4 s after the wave spawns.
- **Spawning:** bosses in a wave spawn at different edges, at least 3 tiles apart, never on the summit core tiles. Each spawn gets a 1-second warning ring.
- **Boss bars:**
  - up to 3 alive: the existing slim rows;
  - 4 or more: one combined bar, `GAUNTLET · n BOSSES` with summed health, plus a row for the nearest boss;
  - landscape: side by side, as Blitz does today.
- **Performance budget:** measure with `stress.js` and the frame test from the October 3 audit (`dev/evidence/2026-10-03-efficiency/`). Eight bosses and six players on Frostpeak XL must stay within +20% of today's Final Blitz frame time. Keep particle and frost-field caps (`frostFields` max) bounded. Rime frost trails from three Rimes are the obvious risk.
- **Packets:** 8 bosses are 8 raider rows (about 12 numbers each). That fits the budget measured on October 3. Check it with `out/snap.js`.

**HUD and audio:**
- Label `GAUNTLET · WAVE n/6` with the clock, then `EVACUATE` for the last 30 s.
- Toasts:
  - "THE WHITEOUT GAUNTLET: Six waves of bosses, one every 30 seconds. Then 30 seconds to reach the evac."
  - "WAVE n: Three Rime Colossi and the {Boss}."
- Music: the existing `final_blitz` track.
- The siren at 0:30.

**Implementation sketch:**
- A new `startGauntlet()` / `gauntletTick()`, reusing `spawnBoss(..., fb=true)`, `openEvac()`, `evacTick()` and `finishBlitz()` with `game.fb.gauntlet = true`.
- `fbTick()` branches to it when `campaign()`.
- Keep `BLITZ` untouched for Blitzkrieg Rush.
- New constants: `GAUNTLET = {t: 210, evac: 30, every: 30, waves: 6, size: 4, rimes: 3, cap: 8, hp1: .35, hpPer: .12, pool: [...]}`.
- Network: `fb` gets a wave counter; boss rows already carry their type.

**Tests** (`campaign_gauntlet.js`, plus a network test):
- 6 waves at the right clock times, each 3 Rime + 1 from the pool;
- no raiders;
- the cap of 8 is respected and queued bosses arrive later;
- health scales with the player count;
- the evac opens at 0:30 with no waves after it;
- bosses retreat at 0:00;
- left behind / evacuated results;
- guest parity;
- a performance run saved to evidence.

## 4. Rewards and server (decisions D7-D9; migration needs approval)

The server caps finale bosses at 10 per run (by time) and pays 2 Winter Cases per Rime. Under the gauntlet that would be up to 24 bosses paying up to about 40 cases a run, so the rules have to change.

**Proposed defaults (decision D7):**
- **Gauntlet bosses** pay **shards only**: 5-10 each. They also count toward their base boss's milestone, with the ladder cap under D8.
- **Waves cleared:** +1 Winter Case for each wave whose four bosses all die before 0:00, up to 6. The server checks a wave count against the time played (`1 + (dur - 20) / 30`, capped at 6) and the boss keys sent.
- **Evac:** making the final evac pays +2 Winter Cases and 25 shards (today +1).
- **Chapter evacs:** each one you make pays +1 Winter Case. Missing one halves that chapter's cases and shards (D1).

**Rime ladder (decision D8):**
- By default, gauntlet Rimes count toward `boss_rime` **at most 6 per run**. Without a cap, the 250 step comes in about 14 runs instead of about 80.
- The chapter-4 Rime and the Frostpeak Rime in other modes still count in full.

**Server work:**
- Rebuild `claim_match_reward` from the live text:
  - campaign finale: new caps and payouts;
  - per-chapter evac results (`ch_evac: [bool, bool, bool]` in the claim) and the per-chapter halving;
  - update the campaign duration sanity checks for the extra 3 × 45 s of evacs and the shorter 3:30 finale.
- PGlite tests: a full run; a run with chapters missed; a run with the gauntlet partly cleared; retry/receipt idempotency; a forged claim with 24 Rimes gets the capped payout.
- **Approval:** Big U approves the exact payout table before the migration is applied.

**Old clients:** campaign claims from `yard-23` clients keep the current rules (no `ch_evac`, the 10-boss cap).

## 5. Things that must keep working
- Blitzkrieg Rush: its Final Blitz, its evac and the BLITZKRIEG ladder are unchanged (`blitz_mode`, `blitz_network`, `blitz_milestones`).
- Late joiners mid-campaign: chapter, map, chapter-evac state and gauntlet state arrive in `startMsg` and the first state packet.
- Same-match rejoin and a run left on a phone with the screen locked: the run draft records chapter evac results.
- Friend invites (`room_register` accepts any `yard-N` since v0.9.6.3), Open Games listing, and the `chapter` shown in invites.
- Campaign modifiers: the existing exclusion list stays. Check Firestorm and Weather on the gauntlet for frame cost.

## 6. Release v0.9.7.0
- Protocol `yard-24` and footer `v0.9.7.0`.
- `dev/STATUS.md` section, plus evidence in `dev/evidence/v0.9.7.0/`:
  - screenshots at desktop, phone portrait and phone landscape of a map evac, a gauntlet wave with 8 bosses, the combined boss bar, and the result card;
  - the before/after frame and packet numbers.
- Full suite green.
- Big U approves the screenshots before the merge, and the migration separately.

## Open decisions for Big U (defaults are used if you don't change them)

| # | Question | Default |
|---|---|---|
| D1 | Left behind at a map evac (chapters 1-3)? | Continue to the next map, lose half of that chapter's cases and shards, start at 50% health with no salvage |
| D1b | Everyone left behind at a map evac? | The run continues with the same penalties (alternative: the campaign ends as a loss) |
| D2 | Map evac countdown? | 45 seconds |
| D3 | Raiders during a map evac? | Small groups keep coming, no boss |
| D4 | Gauntlet wave size? | Always 3 Rime + 1 random (alternative: 2 Rime + 1 random with one player) |
| D5 | Random boss pool? | Frostbound Butcher, Permafrost Foreman, Tempest, Bulldozer, Blue Butcher, Arsonist (no boat bosses) |
| D6 | Most bosses alive at once? | 8 (later bosses wait their turn) |
| D7 | Gauntlet rewards? | Shards per boss; +1 Winter Case per wave fully cleared (max 6); final evac +2 Winter Cases; +1 per chapter evac made |
| D8 | Gauntlet Rimes on the Rime ladder? | At most 6 per run |
| D9 | Boss health in the gauntlet? | 35% with one player, +12% per extra player (tuned in playtest) |
