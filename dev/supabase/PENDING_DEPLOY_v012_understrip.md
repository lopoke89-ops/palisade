# Pending deploy: `20261104200000_v012_understrip.sql` (THE UNDERSTRIP, v0.12)

**Status (November 4, 2026): NOT APPLIED to the live database.** **Owner: Big U** (the director), who applies it
himself (or hands it to whoever he chooses) and decides when. Nothing in this repo touches the live database by itself.
The full list of what's still open for THE UNDERSTRIP is [`../plans/understrip/OPEN_ITEMS.md`](../plans/understrip/OPEN_ITEMS.md).

- Migration: [`migrations/20261104200000_v012_understrip.sql`](migrations/20261104200000_v012_understrip.sql)
- Its test (disposable Postgres, never live): [`../test/understrip_server.js`](../test/understrip_server.js), 61 checks
- Why it exists: the work order, section 9.4 ([`../plans/understrip-work-order.md`](../plans/understrip-work-order.md)), and the
  M3 report ([`../evidence/2026-11-04-understrip-m3/README.md`](../evidence/2026-11-04-understrip-m3/README.md))
- Live project: `puvjfhwxigxjpsvdwrwf` (as in [`../catalog/cosmetics/server-catalog.json`](../catalog/cosmetics/server-catalog.json))
- Branch with the client that uses it: `claude/nifty-lamport-jdl74i` (not merged to `main`; the website doesn't have it)

## What it changes (in file order)

| # | Object | Change | Who notices |
|---|---|---|---|
| 1 | `public.import_local_save(jsonb)` | **Replaced (security fix).** A local save now brings into an account only the cosmetics it lists whose `cosmetics.src = 'free'`, and the equipment of those. It no longer adds cases, shards, the case bag, stats or progress, and no longer calls `private.apply_unlocks`. The "only once" rule (`lockers.imported`) is unchanged. | **Every live client, at once** (see "Order and the live client" below) |
| 2 | `public.case_types` | New row `understrip`: `UNDERSTRIP CASE`, weights `{"c":40,"r":32,"e":18,"l":8,"g":2}`, `shard_cost` 15, `modes '{}'`, `drop '{}'`, `sort` 9. Upsert. | New client only |
| 3 | `public.cosmetics` | 30 new rows, `box 'understrip'`, `src 'case'`, `catalog_version 6` (ids in the file; tiers as [`../plans/understrip/tables/case_items.csv`](../plans/understrip/tables/case_items.csv)). Upsert. | New client only |
| 4 | `private.open_case_catalog(text,integer,integer)` | Patched in place: the accepted catalogs go from `(0,1,2,3,4)` to `(0,1,2,3,4,5,6)`. Nothing else changes. | Nobody (older openers still pass 4) |
| 5 | `private.open_cases_v012(text,integer,uuid)` + `public.open_cases_v012(...)` | **New**, copied from the live `private.open_cases_v0964` text with two replacements (its name, and catalog 4 → 6). Same receipts table (`private.case_openings`), same 1-or-5 rule. Grants: authenticated only (anon and public revoked). | New client only (it calls this for the UNDERSTRIP CASE and nothing else) |
| 6 | `public.claim_match_reward(jsonb)` | Patched in place with anchored replacements on the live text (see "Anchors"). Adds mode `understrip` for `cv >= 6` claims: `raid_to` = levels finished (10 = won); each region cleared inside the claim's levels (at 3, 6 and 9 finished) pays 1 `understrip` case, 2 shards (as `boss_shards`), 1 skill point and `+1 st.us_regions`; a win pays 1 more case and `+1 st.us_wins`. A level takes at least 60 s (a faster claim raises "That level count doesn't add up"); a win under 900 s isn't a win. Boss cases are 0 for this mode. Every other mode is unchanged. | New client only |
| 7 | `public.room_register(jsonb)` | Patched in place: map list and length list gain `understrip`. | New client only |
| 8 | `public.lobbies` | Constraint `lobbies_length_check` dropped and re-added with `understrip` added to the casino-era list. | New client only |

The file is **safe to run twice** (upserts, `if position(...) = 0` guards, `create or replace`, `drop constraint if exists`).
The helper `pg_temp.sub1` stops the whole `do` block if an anchor isn't found exactly once.

## Order and the live client (a decision for Big U)

- **Item 1 changes the live game the moment it's applied.** The live `main` client (v0.10.x) still merges a device's
  no-account save into an account the first time it signs in. After the fix, that merge keeps only free cosmetics; the
  device's cases, shards and case items stop coming across, **and the old client shows no message about it** (the
  explanation is in the new client, `19-accounts.js` `syncLocker`, which also keeps a copy in localStorage
  `palisade.localSave.kept`). That is the intended security behaviour (the October 10 audit's open item: any account could
  claim any cosmetics, 1000 shards and cases once), but it is a visible change for players who sign up for the first time.
- Options: (a) apply everything now: the hole closes today, and new sign-ups on the old client lose non-free local items
  silently; (b) apply items 2-8 now and item 1 with the v0.12 client release; (c) apply everything with the v0.12 release.
  The work order makes item 1 a **blocker for shipping the case**, so in any order it must be live before or with the
  v0.12 client. Ask Big U which.
- Items 2-8 are invisible to the live client: nothing it sends uses them. Until they're live, the new client degrades
  safely: an UNDERSTRIP result from a signed-in player is kept in the claim queue (it retries every 30 minutes, the same
  way Black Out's were kept before its migration) instead of being dropped; accounts can't get UNDERSTRIP CASES, and the
  opener is only ever called for that case.

## Before applying

1. Get Big U's go, and the answer to the order question above.
2. Run the local test from a checkout of the branch (needs `@electric-sql/pglite`): `node dev/test/understrip_server.js`
   must print `PASS understrip_server; errors: none`.
3. **Check the live function texts still match what the anchors expect** (read-only; every column must be `true`). The
   test rebuilds these functions from the migration chain up to `20261003200000_v097_city_blackout.sql` (claims) and
   `20261008213153_casino_relay_lobby_codes.sql` (rooms). If a hotfix changed them live, the `do` block will stop; fix the
   anchor in the migration rather than forcing it.

   ```sql
   with f as (select pg_get_functiondef('public.claim_match_reward(jsonb)'::regprocedure) c,
                     pg_get_functiondef('public.room_register(jsonb)'::regprocedure) r,
                     pg_get_functiondef('private.open_case_catalog(text,integer,integer)'::regprocedure) o,
                     pg_get_functiondef('private.open_cases_v0964(text,integer,uuid)'::regprocedure) v)
   select position($$v_bo boolean := coalesce(p->>'mode', '') = 'blackout' and p->>'kind' = 'run'; v_pois int := 0; v_major int := 0; v_dest boolean := false;$$ in c) > 0 as decl,
          position($$if v_mode not in ('5', '10', 'endless', 'blitz','campaign','blackout') or (v_mode = 'blackout' and v_cv < 5) or$$ in c) > 0 as modes,
          position($$when 'blackout' then 9 else 0 end;$$ in c) > 0 as waves,
          position($$    if v_dur + 20 < 8 * v_held + (v_held * v_held) / 4 then raise exception$$ in c) > 0 as dur,
          position($$    v_credit := floor((case when v_bo then v_pois else v_held end) * (100 + v_pct) / 100.0)::int;$$ in c) > 0 as credit,
          position($$v_cap := greatest(0, v_cap - v_pbn); if v_bo then v_cap := 0; end if;$$ in c) > 0 as cap,
          position($$    v_sp := v_spprog / 5 + v_n + v_sb + v_fbn + case when v_dest then 1 else 0 end;$$ in c) > 0 as sp,
          position($$|| case when v_hyb>0 then jsonb_build_object('hybrid',coalesce((bag->>'hybrid')::int,0)+v_hyb) else '{}'::jsonb end,$$ in c) > 0 as bag,
          position($$|| case when v_hyb>0 then jsonb_build_object('hybrid',v_hyb) else '{}'::jsonb end,$$ in c) > 0 as cases,
          position($$'chapter_evacs', v_chev, 'hybrid_case', v_hyb,$$ in c) > 0 as resp,
          position('v_us boolean' in c) = 0 as not_yet_applied,
          position($$not in ('yard','river','quarry','frost','city','casino')$$ in r) > 0 as room_maps,
          position($$not in ('5','10','endless','blitz','campaign','blackout','casino')$$ in r) > 0 as room_lengths,
          position('p_catalog not in (0,1,2,3,4)' in o) > 0 as opener_catalogs,
          position('private.open_case_catalog(p_case,null,4)' in v) > 0 as v0964_catalog
   from f;
   ```
   (The anchors are matched with leading spaces where the migration has them; the query above checks the distinctive part.)
   Both this query and the one under "verify" were run against the disposable database `understrip_server.js` builds:
   every column `true` before and after the migration respectively.
4. **Snapshot what it replaces**, for a rollback: save `pg_get_functiondef` of `public.claim_match_reward(jsonb)`,
   `public.room_register(jsonb)`, `public.import_local_save(jsonb)`, `private.open_case_catalog(text,integer,integer)` to
   `dev/supabase/snapshots/` (e.g. `v012_before_<function>.sql`), and back up the data it writes:
   `create schema backup_20261104; create table backup_20261104.case_types as table public.case_types; create table backup_20261104.cosmetics as table public.cosmetics;`
   (the October 6 deploy used a `backup_` schema the same way; owner-only).

## Applying

- Run the whole file **in one transaction** (`begin;` … `commit;`), so a stopped anchor leaves nothing half-applied.
- The Supabase connector has timed out before on statements that need confirmation (`DROP`, `DELETE`): see
  [`../STATUS.md`](../STATUS.md), the v0.10.3 deploy. This file has `drop constraint if exists` (lobbies) and `revoke`s. If
  the connector stalls, run the file in the SQL editor instead (Big U did this for v0.10.0 and v0.10.3).
- Record it in the migration history under the file's name (`20261104200000_v012_understrip`).

## After applying: verify (read-only)

```sql
select (select count(*) from public.case_types where id='understrip' and shard_cost=15) = 1 as case_row,
       (select count(*) from public.cosmetics where box='understrip' and catalog_version=6 and src='case') = 30 as items,
       (select array_agg(distinct rarity order by rarity) from public.cosmetics where box='understrip') = '{c,e,g,l,r}' as tiers,
       position('v_us boolean' in pg_get_functiondef('public.claim_match_reward(jsonb)'::regprocedure)) > 0 as claims,
       position($$c.src = 'free'$$ in pg_get_functiondef('public.import_local_save(jsonb)'::regprocedure)) > 0 as import_fix,
       position('(0,1,2,3,4,5,6)' in pg_get_functiondef('private.open_case_catalog(text,integer,integer)'::regprocedure)) > 0 as opener,
       has_function_privilege('authenticated','public.open_cases_v012(text,integer,uuid)','execute') as v012_auth,
       not has_function_privilege('anon','public.open_cases_v012(text,integer,uuid)','execute') as v012_not_anon,
       position($$'understrip'$$ in pg_get_functiondef('public.room_register(jsonb)'::regprocedure)) > 0 as rooms,
       position('understrip' in pg_get_constraintdef((select oid from pg_constraint where conname='lobbies_length_check'))) > 0 as lobbies;
```

Then, with a **test account only** (never a player's): an `import_local_save` on a fresh test locker listing a case skin
and 1000 shards adds neither; a claim `{kind:'run', mode:'understrip', cv:6, raid_from:0, raid_to:10, duration_s:2700,
win:true, ...}` pays `understrip` 4 and `boss_shards` 6; `open_cases_v012('understrip',1,<new uuid>)` returns an
understrip item. A 10-raid Yard claim pays exactly as before.

## After applying: housekeeping in the repo

- Refresh [`schema.sql`](schema.sql) from live (it still shows the old `import_local_save`).
- Refresh [`../catalog/cosmetics/server-catalog.json`](../catalog/cosmetics/server-catalog.json) from live, then run the
  full catalogue capture (`dev/catalog/capture-cosmetics.js`); today it stops at `skin:nightshift` because the snapshot is
  from October 3. The UNDERSTRIP sheets were captured separately (see that folder's README).
- Add a STATUS.md entry (what was applied, when, by whom, the verification results), and change this file's status line
  to applied (or delete it and point STATUS.md at the migration).

## Rolling back

- Functions: re-run the snapshots saved in "Before applying" step 4 (`create or replace` each). `open_cases_v012` can stay
  (nothing calls it but the new client) or be dropped.
- Data: the 30 cosmetics and the case row are only safe to delete if no locker owns or holds any
  (`select count(*) from public.lockers where owned && array(select id from public.cosmetics where box='understrip') or coalesce((bag->>'understrip')::int,0) > 0`).
  Otherwise leave them; without the claim patch nobody earns more.
- The lobby constraint: re-add the casino-era list (`'5','10','endless','blitz','campaign','blackout','casino'`).
