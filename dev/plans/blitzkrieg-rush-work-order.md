# PALISADE: Blitzkrieg Rush work order (new game mode)

You are working on PALISADE (repo `lopoke89-ops/palisade`), a phone-first isometric co-op siege game. It is a single-page Canvas game with PeerJS host-authoritative multiplayer, Supabase accounts and rewards, and a PWA on GitHub Pages.

The live release is **v0.9.3.10**, protocol `yard-18`. Ship this as **v0.9.4.0**, the first new game mode.

Read these first:
- `dev/STATUS.md`
- `dev/OPTIMIZATION_AUDIT_2026-10-01.md`
- `dev/plans/v0.9.3.9-work-order.md` (standing rules)
- `dev/src/js/ORDER.txt`

Recheck GitHub `main`, the live footer and the live Supabase migration list before starting.

## Standing rules
- Edit `dev/src/` only, and rebuild with `python3 dev/build.py`. Never hand-edit `index.html`, `sw.js` or `debug.html`. Run `git checkout -- *.png` after a build.
- Run focused tests for each change (`dev/test/run_targeted.sh <group>`), add a test for every new behavior, and run the full list (`dev/test/run_all.sh`) before release.
- Keep the `palisade.*` storage keys, stable element IDs, the PeerJS host model and Supabase reward authority.
- Server changes need:
  - A migration in `dev/supabase/migrations/`, based on the **live** function text (read it first; `schema.sql` is stale).
  - PGlite tests.
  - Big U's approval before applying.
  - A rename to the live version number after applying.
- Never change existing player balances without Big U approving the exact list.
- Save evidence under `dev/evidence/v0.9.4.0/`. Update `STATUS.md`, the READMEs and the blueprint.
- Big U approves merges.

## Where things live today
- **Match setup:** match length comes from `pick.mode` in `04-state-armory.js`, which accepts `'5'`, `'10'` or `'endless'`. Mode and length labels are in `MODE_NAME` and `LEN_NAME` (`19-accounts.js`), and the menu summary is in `22-loop-menus.js`.
- **Bosses:** `BOSSES`, `BOSS_VARIANTS`, `bossOf`, `bossPartner` and the boss spawner are in `10-phases-bosses.js`. The enemy code list `ECODE` lives there too; it's part of the network encoding.
- **Boss AI:** the `think*` functions.
- **Boss projectiles:** `rockets`, `fires`, `zaps`, `slashes`, `rings` and `chains` (`04-state-armory.js`).
- **Modifiers:** Boss Rush and the Nightmare/Boss Rush synergy are in `01b-mods-skills.js` and `10b-mods-play.js`. Their existing two-boss support is the model for several bosses at once.
- **Walls:** `makeWall`, with `MAT[mat].hp` and `.blast`. `w.fire` is regular wall burning.
- **Boss art:** `look` objects, painted by `paintWardrobeCharacter` (`16-characters.js`). Any new helper must live inside that function.
- **Rewards:**
  - The client summary is in `18-cosmetics.js`, around line 434.
  - The server authority is `claim_match_reward`, which checks the mode, length and boss counts.
  - Milestones count every boss kill for everyone in the match (v0.9.3.8).

---

## 1. The mode: Blitzkrieg Rush
- **Where it appears:** a new length choice, **BLITZKRIEG RUSH**, next to 5 / 10 / Endless. It's co-op only, solo or online, on every map.
  - Use a new `pick.mode` value `'blitz'`.
  - Update every place that assumes `'5' | '10' | 'endless'`: setup, labels, lobby listing, game-over text, records, reward summary.
- **Structure:** 15 raids, harder than 10-raid mode. Scale difficulty with `waveEff` and the difficulty setting so raids 1–14 feel intense but fair.
  - Proposed default: map bosses on raids 5 and 10, as usual.
  - These use the Blitzkrieg variants (section 2).
- **Raid 15, the Final Blitz:**
  - A 5-minute survival battle with a big on-screen countdown.
  - A new boss spawns every 30 seconds (10 bosses in total, the first at 0:00), cycling through the Blitzkrieg variants of all 5 bosses.
  - Normal raiders keep coming alongside the bosses. Tune the numbers so it doesn't flood.
  - **Win:** the core survives the 5 minutes.
  - **Loss:** normal loss rules.
  - Bosses still alive when the timer ends: proposed default is that they retreat, you win, and those bosses don't count as kills.
  - Show a distinct toast for each spawn (e.g. `BLITZ · 3/10 · THE BLUE BUTCHER`).
- **Performance:** many bosses at once is new. Cap how many can be alive at once (proposed: 4; extra spawns wait until one dies).
  - Measure frame cost with `dev/test/stress.js` for a 6-player Final Blitz at 390×844.
  - Keep six-player Final Blitz frame cost within about 20% of today's six-player Endless raid 20 (8.7 ms median render).
- **HUD:** the compact landscape boss bar from v0.9.3.9 must handle several bosses. Show the soonest-to-die boss plus a `+N` count, or stack tightly. It must not overlap the sticks, kit or team bars; extend `hud_layout`.

## 2. Blitzkrieg boss variants (exclusive to this mode)
Each variant is its own boss key (e.g. `blitz_ferryman`) with its own name, color, look, `intro` text and `think` function.
- Reuse the base boss's model and animation rig, then recolor or retrim it.
- They appear **only** in Blitzkrieg Rush.
- Every attack needs a clear telegraph, like the existing bosses (a red line, blue line or chain line).
- Every effect must be host-authoritative and replicate to clients.
- Proposed names below; Big U can rename.

1. **The Ferryman: missile barge.**
   - Stays on his raft.
   - Launches missiles in a high, visible arc.
   - Each missile shows a landing marker (a growing circle) for long enough that a moving, alert player can always step out.
   - Readable, dodgeable, punishing when ignored. Tune the flight time so the dodge is fair even on phones.
   - Raftless maps: the current code turns the Ferryman into the Butcher when there's no river. Here he fires from a fixed spot at the map edge instead.
2. **The Blue Butcher: magic arc attack.**
   - The whole Butcher palette turns blue/teal.
   - New attack: he swipes his sword and launches a glowing blue/teal crescent arc.
     - It travels in a straight line and **passes through brick walls** (and weaker materials) without stopping.
     - It still damages players it crosses.
     - Decide with Big U whether it also damages the walls it passes through. Proposed default: light damage.
   - The arc leaves a trail of blue dust that fades in about **0.5 s**. It's purely visual: particles only, no lingering hitbox.
   - Telegraph: a short wind-up with a teal lane flash before the swipe.
   - Keep his charge attack, but at a lower rate so the arc is his signature move.
3. **The Demolisher: napalm.**
   - Aims (show the aim line), then fires a **chain of Molotovs** that land in a line, each leaving burning ground.
   - Each fire lasts **10 seconds**.
   - Burns through **metal walls faster than regular fire does**. Metal normally resists fire, so napalm is the counter to metal forts. Suggested: 2× regular fire damage on metal, normal on other materials; tune and document.
   - Burning ground hurts players standing in it. Use the existing `fires` list if it fits; otherwise add a napalm type.
   - Mind the fire count: cap simultaneous napalm patches and measure.
4. **The Stormcaller: twin beam.**
   - Fires **two parallel beams** at once, each with its own blue telegraph line.
   - Being hit by both deals **double** the normal Stormcaller shot damage; one beam alone deals the normal amount.
   - Keep the chain-jump behavior, or replace it with the twin beam. Proposed: replace, so one attack stays readable.
5. **The Foreman: rampage.**
   - **No more digging.** He stays above ground and charges players quickly (faster than the Butcher's charge).
   - When he runs into a **wall**, he's **dazed for about 3 seconds**: stars or spin particles, stopped, open to damage.
   - The wall takes heavy impact damage. That's the trade-off: walls stop him but get hurt.
   - Telegraph: a short dust-kick wind-up and a charge lane before each run.
   - He sets up again after the daze.

Art: each variant needs a distinct look that still reads as the same character. The Blue Butcher is fully blue/teal; the others get a Blitzkrieg trim, for example hazard stripes, a glowing accent, or a darker palette. Add all five to the boss contact sheet and save before/after images.

## 3. Network
- The new boss keys, the napalm and missile projectiles, the arc, the twin beam and the daze state all change what packets carry. This means a protocol bump to **`yard-19`**.
  - Append to `ECODE`; never reorder it.
  - Add new projectile lists to the full snapshot so late joiners and rejoiners see them. Follow the `start.shots` pattern from v0.9.3.5.
- The Final Blitz timer is host-owned and sent to clients. Clients never run their own clock.
- The v0.9.3.6 rejoin stash must work mid-Final Blitz.
- Tests: an extended `cosmetic_network` / `netbench`-style check that a client sees the same boss keys, projectiles and timer as the host. Also a rejoin during raid 15.

## 4. Rewards and server (**Big U decides; migration needs approval**)
- `claim_match_reward` must accept the new mode `blitz` with 15 raids. It must also allow up to 2 map bosses plus 10 Final Blitz bosses, scaled by how long the player stayed (the v0.9.3.6 rule).
  - Write the migration from the live function text.
  - PGlite tests: a clean win, a loss at raid 15, too many bosses rejected, rejoin caps, anon denied.
- **Proposed default rewards (to confirm):**
  - Each boss kill pays its case, like other bosses (`bossBox`).
  - Final Blitz bosses pay shards like Boss Rush's in-between bosses (15–30).
  - A win pays a **Blitzkrieg bonus**: one extra case and a shards bonus.
  - All boss kills count toward milestones for everyone in the match.
- New stats/milestones (optional; Big U to decide): Blitzkrieg wins and Final Blitz bosses killed. Possibly an exclusive cosmetic unlock (e.g. "Win Blitzkrieg Rush").
- Local (no-account) lockers follow the same rules in `18-cosmetics.js`.

## 5. Modifiers
- Decide which modifiers are allowed in Blitzkrieg Rush.
- Proposed:
  - Nightmare and Firestorm allowed.
  - Boss Rush disabled, because it's redundant and would break the boss math.
  - Nightmare's 1-in-12 surprise boss off, for the same reason.
- Grey out disallowed modifiers with a reason.

## Tests (add all to the full list)
- **`blitz_mode`:**
  - 15 raids.
  - Raid 15 is a 5:00 timer with a boss at 0:00, 0:30 … 4:30.
  - The live-boss cap is respected.
  - Win when the timer ends with the core alive; loss on core loss.
  - Menu, labels and game-over text are correct.
- **`blitz_bosses`**, one case per variant:
  - Ferryman missiles land on the telegraphed marker, and a player who moves away takes no damage.
  - The Blue Butcher's arc passes through brick and damages a player behind it; its dust clears within about 0.5 s.
  - Napalm lasts 10 s and damages metal faster than regular fire.
  - Twin beam deals double damage on a double hit and single damage on one.
  - The Foreman never goes underground and is dazed about 3 s after hitting a wall.
- **`blitz_network`:** host/client parity and rejoin mid-Final Blitz.
- **`blitz_reward_migration`:** PGlite server tests.
- **Visual:** a boss contact sheet with all five variants, plus Final Blitz screenshots at 390×844 and 844×390.
- **Performance:** a `stress.js` Final Blitz run, numbers recorded in the evidence folder.

## Release v0.9.4.0
1. Bump the footer and protocol (`yard-19`), then rebuild.
2. Run the focused tests, then the full list.
3. Get Big U's approval, then apply the migration and verify it: function body, grants, advisors.
4. Commit, push and open a PR.
5. After Big U approves the merge, verify the live footer, the service worker, and that old `yard-18` lobbies no longer list.
6. Record everything in `STATUS.md`, and ask Big U for a phone playtest of the Final Blitz, including heat at 30/60 FPS.

## Open decisions for Big U (ask before building these parts)
1. Rewards for a win and for each Final Blitz boss (section 4 defaults).
2. Does the Blue Butcher's arc damage the walls it passes through?
3. Stormcaller: twin beam replaces the chain jump, or is added to it?
4. The live-boss cap for the Final Blitz (default 4), and what happens to bosses alive at 0:00.
5. Which modifiers are allowed.
6. The variant names, and whether Blitzkrieg gets its own cosmetic unlock.
