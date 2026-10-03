# PALISADE v0.9.6.4 work order: campaign rework and the Hybrid Theory Case

You are working on PALISADE (repo `lopoke89-ops/palisade`). It is a phone-first isometric co-op siege game:
- a single-page Canvas game;
- host-authoritative PeerJS multiplayer;
- Supabase accounts and rewards;
- a PWA on GitHub Pages.

The live release is **v0.9.6.3**, protocol `yard-23`. Ship this as **v0.9.6.4**, protocol **`yard-24`**. Big U asked for a patch number, not a minor or major bump.

This update has two parts:
- **A. Operation Whiteout rework** (sections 1-5):
  - resources stay unlocked on later maps;
  - every map before the last ends with an evacuation;
  - the finale becomes a boss gauntlet.
- **B. The Hybrid Theory Case** (section 6): Big U's cosmetics prompt, corrected to fit how this codebase actually works.

They share one protocol bump, one server migration (approved separately) and one release.

Read these first:
- `dev/STATUS.md`
- `dev/plans/blitzkrieg-rush-work-order.md`, for the evacuation rules this reuses.
- `dev/plans/winter-elevation-campaign-and-friend-invites-work-order.md`, for how the campaign was built.
- `dev/plans/winter-cosmetics-dell-and-dead-end-work-order.md`, for the most recent case and catalog work.
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
  - Run the full list with `bash dev/test/run_all.sh` before release. All tests must pass, and a test that exits non-zero fails.
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

---

# Part A: Operation Whiteout rework

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
| Network | `21-online.js` | State packets carry `fb: [t, n, max, ex, ey, r, done]` and player `out`/`ev` (slow block, since v0.9.6.3) |

### The resource bug, measured

This is what a real campaign does today when stepped chapter by chapter:

| Chapter | Map | Kilns (brick) | Scrap (metal) |
|---|---|---|---|
| 1 | Yard | opens after raid 1 | **never opens**: due "raid 4", but the map changes first |
| 2 | Riverbend | **locked all chapter** ("raid 2" already passed) | one open, **one locked all chapter** |
| 3 | Ashfall Quarry | one open, **one locked all chapter** ("raid 3") | **locked all chapter** ("raid 4") |
| 4 | Frostpeak | open | open |

## 1. Resources stay unlocked (bug fix)

**Rule.** In the campaign, the unlock schedule runs only in chapter 1, on the Yard. From chapter 2 onward every node on every map starts open.

**Chapter 1 schedule:**
- the kiln opens after raid 1, as today;
- scrap opens after raid 2, one raid early, so the Yard gets a raid with metal before the map changes.

**Implementation:**
- In `changeChapter()`, after `layMap()`: `if(game.chapter>=1)for(const n of nodes)n.locked=false`.
- Campaign-only override of the Yard's scrap unlock: wave 3 instead of 4. Don't change the Yard's normal-mode layout.
- The chapter-change toast says "Every resource is open on this map."

**Guests:** nodes already sync in `nd`, so there are no protocol fields to add here.

**Test** (`campaign_resources.js`): step a campaign through raids 1-12 and assert:
- Yard: brick from raid 2, metal from raid 3;
- every node open on chapters 2-4;
- a guest sees the same locks after each map change.

## 2. Evacuation at the end of chapters 1, 2 and 3

**When.** After the chapter boss raid (raids 3, 6 and 9) is broken, instead of loading the next map at once:

1. **"MAP EVAC" phase.**
   - A countdown of **15 seconds** starts (Big U: D2).
   - An evac site opens with `evacSpot()`: the same green 3-tile ring, the same 3-second hold on your feet, and the same off-screen arrow.
   - No build phase and no Armory during it.
2. **Raiders** (Big U: D3): **only shieldbearers and grenadiers** keep coming during the countdown (`shield` and `gren`), in small groups at the Final Blitz trickle rate. There is no boss.
3. **Getting out:** the same as the Blitz evacuation.
   - You extract after standing 3 s in the ring and then watch from above.
   - Downed players don't respawn; a teammate or Delgado has to revive them in time.
   - Delgado extracts automatically when the countdown ends, if he's alive.
4. **When it ends.** The countdown hits 0, everyone is out, or nobody is left standing.
   - Remaining raiders retreat.
   - The next map loads with `changeChapter()` and the normal build phase starts.
5. **Left behind** (Big U: D1). A player who didn't make it **continues to the next map**, but pays a price:
   - They lose half the Winter Cases and shards earned **in that chapter** (rounded up first, as in Blitz). The server applies this, using the per-chapter results sent in the claim.
   - They start the next map at 50% health with no salvage carried over.
   - Their result screen lists the evacs they missed.
6. **Everyone left behind** (Big U: D1b): **the campaign ends there as a loss.** "EVAC FAILED · CHAPTER n". Rewards are paid as for any lost run, including the halving for that chapter.
7. **Core and stake:** the core can't be lost during a map evac. As in the Blitz evac, the core no longer decides the result once the evac opens.
8. **HUD and audio:**
   - Phase label `CH n · EVAC` with the countdown.
   - Toast: "EVACUATE: Get to the green ring. The convoy leaves in 15 seconds."
   - The siren, as in Blitz.
   - The result card per chapter shows `EVACUATED` or `LEFT BEHIND`.

**Tuning note.** 15 seconds is tight on XL maps, where the evac site is about 11 tiles from the core (roughly 3.3 s of walking at soldier speed, plus the 3 s hold). Keep the site at `want=8` tiles on standard maps, cap it at 9 on XL for map evacs, and check it in playtest.

**Implementation sketch:**
- Generalize the Blitz evac. Keep `openEvac()`, `evacTick()` and `extract()`, but drive them from a new `game.cev = {t, ch, evac, done}` (chapter evac) alongside `game.fb`.
- `campaignAdvance()` starts the map evac instead of `changeChapter()`.
- When the map evac finishes, it calls `changeChapter(ch + 1)` and `startBuild()`.
- Reset `p.out` and `p.ev` for everyone on the new map, recording each player's result in `p.chEvac[ch]`.
- Guests:
  - `cev: [t, ex, ey, r, done]` goes in the state packet.
  - The per-player chapter results go in `PL_SLOW`, so they cost nothing until they change.
- Rejoin stash: keep `chEvac` and `out` across a same-match reconnect.

**Tests** (`campaign_map_evac.js`, plus a network test):
- the evac opens after raids 3, 6 and 9 only;
- it lasts 15 s;
- only shieldbearers and grenadiers spawn during it;
- extract and reset;
- downed with no respawn, then revived in time;
- the map loads early when everyone is out;
- penalties for one player left behind;
- the campaign ends when everyone is left behind;
- guest parity;
- a rejoin keeps the result.

## 3. The new finale: the Whiteout Gauntlet

This replaces the current wave 13 (the 5-minute single-boss Final Blitz) in the campaign only. Blitzkrieg Rush keeps its own Final Blitz unchanged.

**Timeline (3:30 total):**

| Clock | What happens |
|---|---|
| 3:30 → 0:30 | **Boss waves:** a wave of bosses at 3:30, 3:00, 2:30, 2:00, 1:30 and 1:00, so **6 waves**. No ordinary raiders ("a wave of just bosses") |
| 0:30 | **Evac opens:** no more waves. The bosses still alive keep fighting. You have **30 s** to reach the ring (3-second hold) |
| 0:00 | Remaining bosses retreat and don't count. Anyone not out is left behind (half Winter Cases and shards, as today) |

**Each wave** (Big U: D4): **2 Rime Colossi + 1 random boss**, for every crew size. Six waves is **18 bosses**.

**Random boss pool** (Big U: D5): Frostbound Butcher, Permafrost Foreman, Tempest, Bulldozer, Blue Butcher and Arsonist. Bosses that need a river (Ferryman, Icebound Ferryman, Harbinger) are left out because Frostpeak has no water. A boss isn't picked twice in a row.

**Keeping it fair and playable:**
- **Alive cap** (Big U: D6): at most **8** bosses alive. Bosses from a wave that would go over the cap wait and arrive as others fall.
- **Health** (Big U: D9, H4): gauntlet bosses have **110% of their normal health** (100 → 110), with the game's usual crew scaling on top. If playtests show it's unwinnable solo, the first lever is the cap, not the health.
- **Rime ruptures:** a Rime won't start its rupture or dash while another boss is mid-tell (today's rule). Keep it, and spread the two Rimes' first tells 1.2 s apart, so they can't slam at once.
- **Spawning:** bosses in a wave spawn at different edges, at least 3 tiles apart, never on the summit core tiles. Each spawn gets a 1-second warning ring.
- **Boss bars:**
  - up to 3 alive: the existing slim rows;
  - 4 or more: one combined bar, `GAUNTLET · n BOSSES` with summed health, plus a row for the nearest boss;
  - landscape: side by side, as Blitz does today.
- **Performance budget:** measure with `stress.js` and the frame test from the October 3 audit. Eight bosses and six players on Frostpeak XL must stay within +20% of today's Final Blitz frame time. Keep frost fields and particles capped; Rime frost trails are the obvious risk.
- **Packets:** 8 bosses are 8 raider rows (about 12 numbers each). That fits the budget measured on October 3. Check it with the snapshot meter.

**HUD and audio:**
- Label `GAUNTLET · WAVE n/6` with the clock, then `EVACUATE` for the last 30 s.
- Toasts:
  - "THE WHITEOUT GAUNTLET: Six waves of bosses, one every 30 seconds. Then 30 seconds to reach the evac."
  - "WAVE n: Two Rime Colossi and the {Boss}."
- Music: the existing `final_blitz` track. The siren at 0:30.

**Implementation sketch:**
- A new `startGauntlet()` / `gauntletTick()`, reusing `spawnBoss(..., fb=true)`, `openEvac()`, `evacTick()` and `finishBlitz()` with `game.fb.gauntlet = true`.
- `fbTick()` branches to it when `campaign()`.
- Keep `BLITZ` untouched.
- New constants: `GAUNTLET = {t: 210, evac: 30, every: 30, waves: 6, rimes: 2, extra: 1, cap: 8, hp: 1.1, pool: ['whitebutcher','whiteforeman','tempest','bulldozer','bluebutcher','arsonist']}`.
- Network: `fb` gets a wave counter; boss rows already carry their type.

**Tests** (`campaign_gauntlet.js`, plus a network test):
- 6 waves at the right clock times, each 2 Rime + 1 from the pool with no repeats in a row;
- no raiders;
- the cap of 8 is respected and queued bosses arrive later;
- health is 110%;
- the evac opens at 0:30 with no waves after it;
- bosses retreat at 0:00;
- left behind / evacuated results;
- guest parity;
- a performance run saved to evidence.

## 4. Campaign rewards (server)

Approved by Big U (D7, D8). Big U also approves the exact payout table before the migration is applied.

**Payouts:**
- **Gauntlet bosses** pay **5-10 shards each**, plus +1 to their base boss's milestone.
- **Waves cleared:** +1 Winter Case for each wave whose three bosses all die before 0:00, up to 6. The server checks the count against the time played (`1 + (dur - 20) / 30`, capped at 6) and against the boss keys sent.
- **Final evac:** making it pays +2 Winter Cases and 25 shards (today +1).
- **Chapter evacs:** each one you make pays +1 Winter Case. Missing one halves that chapter's cases and shards. If everyone misses one, the run ends there as a loss (D1, D1b).

**Rime ladder (D8): no cap.** Every gauntlet Rime counts toward `boss_rime`.
- With 2 Rimes per wave (D4), a full run gives 12 gauntlet Rimes plus the chapter-4 Rime: about 13 a run, against about 3 today.
- So the 250 unlock comes about **4× faster** (about 20 runs instead of about 80), not the 6× quoted when waves had 3 Rimes.
- Big U confirmed about 4× is right (H5); each Rime counts once.

**Server work:**
- Rebuild `claim_match_reward` from the live text, with:
  - the gauntlet payouts and caps (18 bosses, 6 waves, time-checked);
  - per-chapter evac results (`ch_evac: [bool, bool, bool]` in the claim) and the per-chapter halving;
  - the chapter-evac loss ending;
  - campaign duration sanity checks updated for the 3 × 15 s map evacs and the shorter 3:30 finale;
  - the Hybrid Theory Case drop (Part B).
- PGlite tests: a full run; a run with one chapter missed; a run where everyone missed chapter 2 (loss); a run with the gauntlet partly cleared; retry/receipt idempotency; a forged claim with 18 Rimes and too little time gets the capped payout.

**Old clients:** claims from `yard-23` clients keep today's campaign rules. Tell them apart by a new claim field `cv: 4` that only v0.9.6.4 sends.

## 5. Things that must keep working
- Blitzkrieg Rush: its Final Blitz, its evac and the BLITZKRIEG ladder are unchanged (`blitz_mode`, `blitz_network`, `blitz_milestones`).
- Late joiners mid-campaign: chapter, map, chapter-evac state and gauntlet state arrive in `startMsg` and the first state packet.
- Same-match rejoin, and a run left on a phone with the screen locked: the run draft records chapter evac results.
- Friend invites, the Open Games listing, and the chapter shown in invites.
- Campaign modifiers: the existing exclusion list stays. Check Firestorm and Weather on the gauntlet for frame cost.

---

# Part B: The Hybrid Theory Case

This comes from Big U's prompt (`palisade_hybrid_theory_prompt.txt`, October 3). Its content (names, colors, tiers, rarities) is kept exactly as written, except where marked **[corrected]**, which means the prompt didn't match the code. The prompt says "do not touch net protocol". That still holds: cosmetics travel in the existing `cosStr`, and the `yard-24` bump belongs to Part A.

## 6.1 Checked against the code (October 3)

| Prompt says | Code reality | Result |
|---|---|---|
| Rarity keys c/r/e/l/g/u with those colors | `RAR` in `18-cosmetics.js` matches exactly | OK |
| "A new case is one CASES row plus COS items with that box" | True on the client. **Cases are rolled on the server**: a case needs a `public.case_types` row and every item needs a `public.cosmetics` row, or the case can't be opened or bought | **[corrected]** Server migration added (6.6) |
| `body:'jersey'` on the skin rows | **`body` is already the torso color on every skin** (e.g. Sahur `body:'#b77942'`). Custom bodies use their own flag (`demon`, `sahur`, `winterModel`) | **[corrected]** Use `jersey: true` plus `trim:` (see 6.3) |
| Sheet Ghost allows only Halo | Confirmed: Sheet Ghost (`sheetghost`) allows only `class` and `halo` today | OK; add Dunce Cone |
| "One case for everyone after a co-op win" | The server pays one "win drop" case only, picked by sort order and hard-wired to the Flag Case. Adding `drop: {win: ...}` would silently do nothing | **[corrected]** Explicit rule in `claim_match_reward` (6.6) |
| New ids | None of the 27 fx/bg/hat ids exist yet; 30 new skin ids to be chosen (6.3) | OK |
| "Locker tab" | The Locker already has category tabs. Case items appear as a collapsible collection inside each tab, and the case gets its own panel in the case column | No new top-level tab; one more case panel and collection |
| Four-panel catalog capture | `dev/catalog/cosmetics/` already holds a four-angle catalog (311 entries) | Extend it to 368 |

## 6.2 The case
- **Client row:** `CASES.hybrid = {name: 'HYBRID THEORY CASE', short: 'Hybrid Theory Cases', col: '#c1d32f', weights: {c:46, r:30, e:16, l:7, g:1}, cost: 12, how: 'One for everyone after any co-op win. Or 12 shards.'}`.
- **"Co-op win"** means a win in 5-raid or 10-raid mode, making the final evac in Blitzkrieg Rush, or making the final evac in Operation Whiteout. Endless (no win), PvP and losses don't count.
- **Size:** 57 items: 11 kill effects, 8 backgrounds, 8 headgear, 30 skins.
  - Rarity spread: 12 common, 12 rare, 10 epic, 12 legendary, 11 gold.
  - It's the biggest case so far; the Winter Case has 34.

## 6.3 Skins: the jersey body (30)

**[corrected] Data:**
- Each skin row is a palette on one new body model: `{body: <jersey hex>, pants: <shorts hex>, trim: <trim hex>, jersey: true, ...}`.
- `body` and `pants` keep their existing meaning as colors.
- `headwear` is standard, so hats use the normal head slot.

**Model:**
- Branch in `paintWardrobeCharacter` (`16-characters.js`) on `o.jersey`, the same way `demon` and `winterModel` branch.
- The model:
  - a sleeveless jersey torso with neck trim, hem and side panels in `trim`;
  - separate shorts with a trim stripe;
  - bare arms and calves in the skin tone already used for heads;
  - sneakers: white with a `trim` accent.
- The chest wordmark is the parody short name (e.g. `BAKERS`) in pixel letters. If the full word doesn't fit at locker size, show the first 3-4 letters plus the number `00`. No crests.
- Four yaws.
- The weapon still attaches at the chest and stays readable (check the soldier rifle and the grenadier launcher against the jersey).
- Collision, network and the weapon table don't change.

**Ids:**
- `skin:hb_<shortname>`, e.g. `skin:hb_bakers` or `skin:hb_lizards`.
- The `hb_` prefix keeps them grouped and clear of existing keys.

**Gold tier** gets the existing feet aura.

**Tiers and palettes** are exactly as listed in the prompt: six each of common, rare, epic, legendary and gold. Jersey = first hex, shorts = second, trim = third. The prompt's tiering is used as given; it isn't re-derived from real standings.

## 6.4 Kill effects (11), backgrounds (8), headgear (8)

**Kill effects** use the existing particle painter: early, rise, peak, fade, ground ellipse, one reused sound key. Ids, colors and rarities are exactly as in the prompt:
- `fx:leaf` (r), `fx:bands` (e), `fx:swish` (l), `fx:nuke` (g), `fx:poop` (c), `fx:demon` (e), `fx:hundo` (r), `fx:fire` (r), `fx:eight` (c), `fx:sixty` (c), `fx:zzz` (c).
- `fx:demon` doesn't clash with `skin:demon`; ids are per category.
- Each effect gets a cached sprite set and stays inside today's particle caps. Check a 6-player fight with every player on a Hybrid effect against the frame budget.

**Backgrounds:**
- 4 gold: `bg:yardneon`, `bg:voltgrid`, `bg:viceblock`, `bg:crowncity`.
- 4 legendary: `bg:peachwire`, `bg:lakeblocks`, `bg:fiestastrip`, `bg:oaknight`.
- Advanced 8-bit block skylines with neon streaks on a slow loop, built like Hellgate:
  - the still parts are one cached layer, and only a few streak sprites move;
  - they run at the lobby background's modest rate;
  - they're a still behind the Locker (today's rule).

**Headgear:**
- `hat:shades` (c), `hat:yamaka` (r), `hat:ballhelm` (r), `hat:gridhelm` (e), `hat:dunce` (e), `hat:prop` (c), `hat:conductor` (r), `hat:skullhelm` (l).
- They fit the standard head in four yaws.
- They're blocked on special heads by default.
- **Exception:** Dunce Cone is allowed on Sheet Ghost, added next to Halo in the Sheet Ghost exception list. Test pixel separation in `headgear_fit` the same way Halo is tested.
- Jersey skins use the standard head, so every hat works on them.

## 6.5 Locker and catalog
- The case panel is added to the case column. Holding cases sorts first and an empty case folds to one line (the v0.9.5.0 rules).
- Collections "HYBRID THEORY CASE" appear in the Skins, Headgear, Kill FX and Backgrounds tabs.
- Extend `dev/catalog/cosmetics/` to all 57 items (four angles for skins and hats), and add a contact sheet in the evidence folder.

## 6.6 Server: the case, the catalog and the drop (same migration as section 4)
- `public.case_types`: insert `hybrid` with name `HYBRID THEORY CASE`, `shard_cost` 12, weights `{c:46,r:30,e:16,l:7,g:1}`, sort 7, `drop: {}`. `buy_case` already reads `shard_cost`, so buying needs no function change.
- `public.cosmetics`: insert the 57 rows with `box: 'hybrid'` and **`catalog_version: 4`**. Live versions today are 0-3, and `open_cases_v0962` rolls catalog ≤ 3.
  - Add `open_cases_v0964` (the same function, rolling catalog ≤ 4) and point the v0.9.6.4 client at it.
  - Old clients keep calling the old function and never draw items they can't render.
- **Drop:** in `claim_match_reward`, +1 `hybrid` for a co-op win as defined in 6.2, only on claims with `cv: 4`. An old client is never paid a case it can't show.
- **PGlite tests:**
  - buy with 12 shards;
  - open 1 and 5;
  - every rarity reachable;
  - old function never returns a `hybrid` item;
  - the drop paid exactly once per co-op win (5, 10, Blitz evac, campaign evac);
  - not paid for Endless, PvP, a loss, or `cv`-less claims;
  - retry idempotency.

## 6.7 Tests (client)
- `hybrid_case.js`:
  - catalog counts (57; 11/8/8/30 by slot; rarity spread);
  - every item renders without errors in four yaws;
  - jersey skins paint the new body (no vest pixels);
  - the gold aura on the six gold skins;
  - every kill effect runs a full cycle under the particle cap;
  - backgrounds draw a still and an animated frame;
  - the Dunce Cone on Sheet Ghost is allowed and separated, and other Hybrid hats are blocked on special heads.
- Update `cosmetics_expansion`, `locker_collections`, `headgear_fit`, `cosmetic_network` and `wardrobe3d` for the new items.

---

## 7. Release v0.9.6.4
- Protocol `yard-24` and footer `v0.9.6.4`.
- `dev/STATUS.md` section, plus evidence in `dev/evidence/v0.9.6.4/`:
  - screenshots at desktop, phone portrait and phone landscape of a map evac, a gauntlet wave with 8 bosses, the combined boss bar, the result card, the Hybrid case opening and a jersey skin on the stage;
  - the catalog contact sheet;
  - before/after frame and packet numbers.
- Full suite green.
- Big U approves the screenshots before the merge, and the migration (payout table and catalog) separately.

## Decisions

**Made by Big U (October 3):**

| # | Decision |
|---|---|
| D1 | Left behind at a map evac: continue to the next map, lose half of that chapter's cases and shards, start at 50% health with no salvage |
| D1b | Everyone left behind at a map evac: **the campaign ends** as a loss |
| D2 | Map evac countdown: **15 seconds** |
| D3 | Raiders during a map evac: **only shieldbearers and grenadiers** |
| D4 | Gauntlet waves: **2 Rime + 1 random** for every crew size (18 bosses) |
| D5 | Random pool: Frostbound Butcher, Permafrost Foreman, Tempest, Bulldozer, Blue Butcher, Arsonist |
| D6 | At most **8** bosses alive |
| D7 | Rewards as in section 4 |
| D8 | **No cap** on gauntlet Rimes for the Rime ladder |
| D9 | Gauntlet boss health **+10%** over normal |

**Also decided by Big U (October 3):**

| # | Decision |
|---|---|
| H1 | Keep `hat:yamaka` for now; change it later if it becomes an issue |
| H2 | Tone is fine (`fx:eight`, `fx:leaf`). The game is played with friends; a T/M-style rating is acceptable |
| H3 | Parody team names, cities and colors kept as written (no logos, no crests) |
| H4 | Gauntlet boss health is **110% of normal** (normal 100 → 110), with the usual crew scaling. No reduction |
| H5 | Gauntlet Rimes count once: the Rime ladder runs about **4×** faster |

All decisions are made. Nothing is open.
