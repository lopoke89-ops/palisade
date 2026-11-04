# THE UNDERSTRIP (v0.12.0): what's still open

As of November 4, 2026. Everything below is on branch `claude/nifty-lamport-jdl74i`, which is v0.12.0 built (M0-M5 of
the [work order](../understrip-work-order.md)) and **not merged**. The reports are in
`dev/evidence/2026-11-04-understrip-m0` to `-m5`.

## 1. For Big U: the Supabase migration (owner: Big U)
**`dev/supabase/migrations/20261104200000_v012_understrip.sql` is not applied to the live database.** Big U applies it
(or hands it to someone he chooses) and decides when. Everything needed is in
[`dev/supabase/PENDING_DEPLOY_v012_understrip.md`](../../supabase/PENDING_DEPLOY_v012_understrip.md): what each part
changes, the read-only checks to run before and after (both tested against a disposable copy of the live chain), backups,
applying it in one transaction, the housekeeping afterwards, and the rollback.

- **What it is:**
  - The `import_local_save` security fix (the October 10 audit's open item).
  - The UNDERSTRIP CASE and its 30 items, plus the opener for them (catalog 6).
  - The mode's claim rules, and rooms and lobbies for the mode.
- **One decision first: when the import fix goes live.** It changes the live game the moment it's applied. A player
  signing up from the current (v0.11.1) client stops bringing a device's cases, shards and case items into the account,
  and that client shows no message about it. The note gives three options:
  - everything now;
  - the case's parts now, the fix with the v0.12.0 release;
  - everything with the release.

  The work order makes the fix a blocker for shipping the case, so it has to be live by the time v0.12.0 is.
- **Until it's applied** (even after the merge):
  - Signed-in players' UNDERSTRIP rewards wait in their claim queue (nothing is lost).
  - Accounts can't earn or open UNDERSTRIP CASES.
  - Friend invitations to an UNDERSTRIP room are refused by the server as an unknown mode.
  - Players without an account are unaffected.

## 2. For Big U: the merge to `main` (publishes the site)
The pull request from `claude/nifty-lamport-jdl74i` to `main` is open and **not merged**. Merging publishes v0.12.0 on
GitHub Pages; the built `index.html` and `sw.js` are already on the branch ("Site build v0.12.0"). `main` hasn't moved since
the branch was made, so it merges without conflicts. See section 1 for what works with the merge alone.

## 3. After the migration (housekeeping, in the deploy note)
- Refresh `dev/supabase/schema.sql` from live (it still shows the old `import_local_save`).
- Refresh `dev/catalog/cosmetics/server-catalog.json` from live and run the full catalogue capture
  (`dev/catalog/capture-cosmetics.js`). Today the full run stops at `skin:nightshift` because that snapshot is from
  October 3; the UNDERSTRIP sheets were captured on their own (`dev/catalog/cosmetics/README.md`).
- A STATUS.md entry for the deploy; mark the deploy note applied.

## 4. After the merge
- The repo README's "PUBLISHED RELEASE" line still names v0.10.5; update it to v0.12.0 once it's live.
- A live check on a phone and a desktop (solo, and a two-browser online run).

## 5. For the director (play-test and calls)
- **The fun test.** The run lengths are an estimate, not a measurement (`dev/test/understrip_runlength.js`, M4 report):
  - a whole run comes out at about 47-52 minutes against the 50-60 target;
  - regions 1 and 2 at about 13-14 minutes each, against 15-20;
  - region 3 at about 21-24 minutes, since it carries the finale's fourth level.

  The knobs: raiders per room, the finale (its own level, or the Visitor straight after the Gatekeeper), and D2 (levels
  per region).
- **Calls made while building**, any of which the director may want changed (each report's "Calls made" table has them):
  - the finale as a fourth level in Area 67;
  - the Gatekeeper's fall giving region 3's life;
  - upgrades sold only by the Shrine Keeper and the Lift Merchant, not the Tunnel Trader;
  - the Collector in exactly one of each region's first three levels;
  - which skins wear other hats (the four with an open head);
  - resting reviving players who bled out;
  - M2's readings of the Marked Deck and Comp'd Room.
- **The M0 sign-off boxes** in [`README.md`](README.md) are still unticked on paper. The user signed off every director
  approval in this session; tick them, or have the director go through them.

## 6. Engineering follow-ups
- **Stress case B on real hardware.** On this machine `stress.js` case B (six players, a boss raid) ran 7-11% slower
  than `main` in plain runs. That's over the work order's 5% rule. But the same case was faster under the profiler, and
  the identical frozen frame draws faster on this build (8.3 against 9.6 ms). The stress loop isn't deterministic (its
  scenes differ run to run even on one build). Re-run `CASES=B node stress.js` against `main` on a real phone or laptop.
- **Three hats don't animate in play.** The Antenna Headband's bob, the Plume Crest's sway and the Neon Halo's flicker are
  drawn from time, but the wardrobe painter's cache (`drawWardrobeCharacter`, its `animated` list in
  `16-characters.js`) doesn't know they move, so in play they hold one frame. Adding `o.usHat` to that list makes them
  move at the cost of repainting the figure 20 times a second (as the Floating Halo does). The Locker's large preview
  isn't affected.
- **The PLAY page's heading** ("SOLO · THE FLOOD TUNNELS") reads the mode's map name, which each level sets to its
  region's. After a run that ended in Area 67, the menu can say AREA 67 until the next run starts. Cosmetic; reset the
  name when a run ends or when the menu opens.
- **The desktop game (Godot)** has no UNDERSTRIP (work order 15: the port sweep follows the browser). It keeps working:
  a `yard-30` copy plays every other mode with a `yard-31` host and is refused only by an UNDERSTRIP room. For the port, `understrip_gen.js`
  writes a seed-to-level-hash fixture (`dev/test/out/understrip_gen_fixture.json`, not committed: regenerate it there).

## 7. Not from this work (failing or flaky on `main` too)
- `casino_relay_tables`, `casino_relay_games` and `casino_relay_rooms` fail in under a second on untouched `main` in this
  environment (every suite run, M1-M5).
- `blackout_perf` and `blackout_run` failed now and then on `main` as well as here.
