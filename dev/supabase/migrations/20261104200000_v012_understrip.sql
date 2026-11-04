-- v0.12 THE UNDERSTRIP (work order 9.1-9.4). Not applied to the live database yet: it needs the director's go.
-- Safe to run twice. claim_match_reward and room_register are read with pg_get_functiondef and patched with anchored
-- replacements (each anchor must match exactly once, or the whole migration stops), as v0.9.7 did.
--
-- 1. import_local_save (the October 10 audit's open hole, and the work order's blocker for this case): a local save used to
--    bring in any item ids, up to 1000 shards, 60 cases and its stats, all trusted from the client. Now it brings in only the
--    free cosmetics in its list (src 'free', which every account may wear) and what of them was equipped. Cases, shards, the
--    case bag, stats and progress come only from the server's own claims and openings.
-- 2. The UNDERSTRIP CASE (catalog 6): weights c40 r32 e18 l8 g2, 15 shards, and its 30 items (the tiers are
--    dev/plans/understrip/tables/case_items.csv). Openings of catalog 6 go through open_cases_v012.
-- 3. UNDERSTRIP claims (mode 'understrip', cv:6). raid_to counts levels finished (10 = the run won); a region is cleared at
--    3, 6 and 9 (its boss beaten and its lift taken). Each region cleared inside this claim's levels pays one UNDERSTRIP CASE,
--    2 shards and a skill point; finishing the run pays one more case. At most 4 cases and 6 shards a run, whatever the
--    claims. A level takes at least a minute; a win under 15 minutes doesn't count. The bosses pay no other case.
--    Ladder counters: us_regions, us_wins.
-- 4. Rooms and lobbies accept the mode (length 'understrip', map 'understrip').

create or replace function pg_temp.sub1(d text, a text, b text) returns text language plpgsql as $f$
begin
  if position(a in d) = 0 or (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then
    raise exception 'v0.12 migration: anchor not found exactly once: %', left(a, 80);
  end if;
  return replace(d, a, b);
end $f$;

-- ---------- 1. import_local_save ----------
CREATE OR REPLACE FUNCTION public.import_local_save(p_save jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user(); l public.lockers; v_own text[]; v_eq jsonb := '{}'; v_cat text; fresh boolean;
begin
  select * into l from public.lockers where user_id = uid for update;
  if l.imported then raise exception 'A local save was already brought into this account' using errcode = '22023'; end if;
  if jsonb_typeof(p_save->'owned') is distinct from 'array' then raise exception 'That save is missing its items' using errcode = '22023'; end if;
  fresh := l.eq = '{"skin":"std","hat":"class","trail":"std","fx":"none"}'::jsonb;
  -- only the free cosmetics: a local save can't prove anything else was earned
  select array(
    select distinct v from jsonb_array_elements_text(p_save->'owned') v
    where length(v) < 40 and v ~ '^[a-z]+:[A-Za-z0-9_]+$'
      and exists (select 1 from public.cosmetics c where c.id = v and c.src = 'free') limit 200) into v_own;
  v_own := array(select distinct u from unnest(l.owned || v_own) u);
  foreach v_cat in array array['skin','hat','trail','fx'] loop
    if fresh and (v_cat || ':' || coalesce(p_save->'eq'->>v_cat, '')) = any(v_own)
       and exists (select 1 from public.cosmetics cc where cc.id = v_cat || ':' || (p_save->'eq'->>v_cat)) then
      v_eq := v_eq || jsonb_build_object(v_cat, p_save->'eq'->>v_cat);
    else
      v_eq := v_eq || jsonb_build_object(v_cat, l.eq->>v_cat);
    end if;
  end loop;
  update public.lockers set owned = v_own, eq = v_eq, imported = true, rev = rev + 1, updated_at = now() where user_id = uid;
  update public.profiles set cos = concat_ws('|', v_eq->>'skin', v_eq->>'hat', v_eq->>'trail', v_eq->>'fx') where id = uid;
  select * into l from public.lockers where user_id = uid;
  return private.locker_out(l);
end $function$
;

-- ---------- 2. the UNDERSTRIP CASE and its 30 items (catalog 6) ----------
insert into public.case_types(id,name,weights,shard_cost,modes,drop,sort) values('understrip','UNDERSTRIP CASE','{"c":40,"r":32,"e":18,"l":8,"g":2}',15,'{}','{}',9)
on conflict(id) do update set name=excluded.name,weights=excluded.weights,shard_cost=excluded.shard_cost,sort=excluded.sort;

insert into public.cosmetics(id,cat,key,name,rarity,src,need,box,catalog_version) values
  ('skin:pitboss','skin','pitboss','The Pit Boss','r','case',null,'understrip',6),
  ('skin:shelterdweller','skin','shelterdweller','Shelter Dweller','r','case',null,'understrip',6),
  ('skin:gunslinger','skin','gunslinger','The Gunslinger','r','case',null,'understrip',6),
  ('skin:highroller','skin','highroller','High Roller','e','case',null,'understrip',6),
  ('skin:generalissimo','skin','generalissimo','El Generalissimo','e','case',null,'understrip',6),
  ('skin:sheriff','skin','sheriff','The Sheriff','e','case',null,'understrip',6),
  ('skin:stripking','skin','stripking','King of the Strip','l','case',null,'understrip',6),
  ('skin:custodian','skin','custodian','The Custodian','l','case',null,'understrip',6),
  ('skin:cardsharp','skin','cardsharp','The Card Sharp','l','case',null,'understrip',6),
  ('skin:visitor','skin','visitor','The Visitor','g','case',null,'understrip',6),
  ('hat:tinfoil','hat','tinfoil','Tinfoil Hat','c','case',null,'understrip',6),
  ('hat:eyeshade','hat','eyeshade','Dealer''s Eyeshade','c','case',null,'understrip',6),
  ('hat:antennae','hat','antennae','Antenna Headband','r','case',null,'understrip',6),
  ('hat:plumecrest','hat','plumecrest','Showgirl Plume Crest','e','case',null,'understrip',6),
  ('hat:neonhalo','hat','neonhalo','Neon Halo','l','case',null,'understrip',6),
  ('trail:chips','trail','chips','Poker Chips','c','case',null,'understrip',6),
  ('trail:neontube','trail','neontube','Neon Tube','r','case',null,'understrip',6),
  ('trail:jackpotcoins','trail','jackpotcoins','Jackpot Coins','r','case',null,'understrip',6),
  ('trail:tractorbeam','trail','tractorbeam','Tractor Beam','e','case',null,'understrip',6),
  ('trail:saucerbolt','trail','saucerbolt','Saucer Bolt','e','case',null,'understrip',6),
  ('fx:bust','fx','bust','Bust','c','case',null,'understrip',6),
  ('fx:plumes','fx','plumes','Showgirl Plumes','r','case',null,'understrip',6),
  ('fx:jackpot','fx','jackpot','Jackpot!','e','case',null,'understrip',6),
  ('fx:dissolved','fx','dissolved','Dissolved','l','case',null,'understrip',6),
  ('fx:abducted','fx','abducted','Abducted','g','case',null,'understrip',6),
  ('bg:floodtunnels','bg','floodtunnels','The Flood Tunnels','c','case',null,'understrip',6),
  ('bg:vaultdoor','bg','vaultdoor','Casino Vault Door','r','case',null,'understrip',6),
  ('bg:area67','bg','area67','Area 67 Fence at Dusk','r','case',null,'understrip',6),
  ('bg:stripnight','bg','stripnight','The Strip at Night','e','case',null,'understrip',6),
  ('bg:specimenhall','bg','specimenhall','Specimen Hall','e','case',null,'understrip',6)
on conflict(id) do update set cat=excluded.cat,key=excluded.key,name=excluded.name,rarity=excluded.rarity,src=excluded.src,need=excluded.need,box=excluded.box,catalog_version=excluded.catalog_version;

-- openings of catalog 6 (the opener itself is v0.9.6.4's, with the catalog number raised)
do $mig$
declare d text;
begin
  d := pg_get_functiondef('private.open_case_catalog(text,integer,integer)'::regprocedure);
  if position('(0,1,2,3,4,5,6)' in d) = 0 then
    d := pg_temp.sub1(d, $a$p_catalog not in (0,1,2,3,4)$a$, $b$p_catalog not in (0,1,2,3,4,5,6)$b$);
    execute d;
  end if;
  d := pg_get_functiondef('private.open_cases_v0964(text,integer,uuid)'::regprocedure);
  d := pg_temp.sub1(d, $a$private.open_cases_v0964(p_case text$a$, $b$private.open_cases_v012(p_case text$b$);
  d := pg_temp.sub1(d, $a$private.open_case_catalog(p_case,null,4)$a$, $b$private.open_case_catalog(p_case,null,6)$b$);
  execute d;
end $mig$;
revoke all on function private.open_cases_v012(text,integer,uuid) from public,anon;
grant execute on function private.open_cases_v012(text,integer,uuid) to authenticated;
create or replace function public.open_cases_v012(p_case text,p_quantity integer,p_operation uuid)
returns jsonb language sql security definer set search_path='' as $$ select private.open_cases_v012(p_case,p_quantity,p_operation) $$;
revoke all on function public.open_cases_v012(text,integer,uuid) from public,anon;
grant execute on function public.open_cases_v012(text,integer,uuid) to authenticated;

-- ---------- 3. UNDERSTRIP claims ----------
do $mig$
declare d text;
begin
  d := pg_get_functiondef('public.claim_match_reward(jsonb)'::regprocedure);
  if position('v_us boolean' in d) = 0 then
    d := pg_temp.sub1(d, $a$v_bo boolean := coalesce(p->>'mode', '') = 'blackout' and p->>'kind' = 'run'; v_pois int := 0; v_major int := 0; v_dest boolean := false;$a$,
      $b$v_bo boolean := coalesce(p->>'mode', '') = 'blackout' and p->>'kind' = 'run'; v_pois int := 0; v_major int := 0; v_dest boolean := false;
  -- v0.12 THE UNDERSTRIP (cv:6): regions cleared in this claim's levels, and the UNDERSTRIP CASES they pay
  v_us boolean := coalesce(p->>'mode', '') = 'understrip' and p->>'kind' = 'run'; v_usr int := 0; v_usc int := 0;$b$);
    d := pg_temp.sub1(d, $a$if v_mode not in ('5', '10', 'endless', 'blitz','campaign','blackout') or (v_mode = 'blackout' and v_cv < 5) or$a$,
      $b$if v_mode not in ('5', '10', 'endless', 'blitz','campaign','blackout','understrip') or (v_mode = 'blackout' and v_cv < 5) or (v_mode = 'understrip' and v_cv < 6) or$b$);
    d := pg_temp.sub1(d, $a$when 'blackout' then 9 else 0 end;$a$, $b$when 'blackout' then 9 when 'understrip' then 10 else 0 end;$b$);
    d := pg_temp.sub1(d, $a$    if v_dur + 20 < 8 * v_held + (v_held * v_held) / 4 then raise exception$a$,
      $b$    if v_us and v_dur + 20 < 60 * v_held then raise exception 'That level count doesn''t add up' using errcode = '22023'; end if;   -- v0.12: a level takes a minute
    if v_us and v_dur < 900 then v_win := false; end if;
    if v_dur + 20 < 8 * v_held + (v_held * v_held) / 4 then raise exception$b$);
    d := pg_temp.sub1(d, $a$    v_credit := floor((case when v_bo then v_pois else v_held end) * (100 + v_pct) / 100.0)::int;$a$,
      $b$    if v_us then   -- v0.12: regions cleared inside this claim's levels (at 3, 6 and 9 finished): a case, 2 shards and a skill point each
      for r in 1..3 loop if v_from < 3 * r and v_to >= 3 * r then v_usr := v_usr + 1; end if; end loop;
      v_usc := v_usr + case when v_win then 1 else 0 end;
      v_fbshards := v_fbshards + 2 * v_usr;
      v_st := jsonb_set(v_st, '{us_regions}', to_jsonb(coalesce((v_st->>'us_regions')::int, 0) + v_usr));
      if v_win then v_st := jsonb_set(v_st, '{us_wins}', to_jsonb(coalesce((v_st->>'us_wins')::int, 0) + 1)); end if;
    end if;
    v_credit := floor((case when v_bo then v_pois else v_held end) * (100 + v_pct) / 100.0)::int;$b$);
    d := pg_temp.sub1(d, $a$v_cap := greatest(0, v_cap - v_pbn); if v_bo then v_cap := 0; end if;$a$,
      $b$v_cap := greatest(0, v_cap - v_pbn); if v_bo or v_us then v_cap := 0; end if;$b$);
    d := pg_temp.sub1(d, $a$    v_sp := v_spprog / 5 + v_n + v_sb + v_fbn + case when v_dest then 1 else 0 end;$a$,
      $b$    v_sp := v_spprog / 5 + v_n + v_sb + v_fbn + case when v_dest then 1 else 0 end + v_usr;$b$);
    d := pg_temp.sub1(d, $a$            || case when v_hyb>0 then jsonb_build_object('hybrid',coalesce((bag->>'hybrid')::int,0)+v_hyb) else '{}'::jsonb end,$a$,
      $b$            || case when v_hyb>0 then jsonb_build_object('hybrid',coalesce((bag->>'hybrid')::int,0)+v_hyb) else '{}'::jsonb end
            || case when v_usc>0 then jsonb_build_object('understrip',coalesce((bag->>'understrip')::int,0)+v_usc) else '{}'::jsonb end,$b$);
    d := pg_temp.sub1(d, $a$      || case when v_hyb>0 then jsonb_build_object('hybrid',v_hyb) else '{}'::jsonb end,$a$,
      $b$      || case when v_hyb>0 then jsonb_build_object('hybrid',v_hyb) else '{}'::jsonb end
      || case when v_usc>0 then jsonb_build_object('understrip',v_usc) else '{}'::jsonb end,$b$);
    d := pg_temp.sub1(d, $a$'chapter_evacs', v_chev, 'hybrid_case', v_hyb,$a$, $b$'chapter_evacs', v_chev, 'hybrid_case', v_hyb, 'us_regions', v_usr, 'us_cases', v_usc,$b$);
    execute d;
  end if;
  -- ---------- 4. rooms ----------
  d := pg_get_functiondef('public.room_register(jsonb)'::regprocedure);
  if position($a$'casino','understrip'$a$ in d) = 0 then
    d := pg_temp.sub1(d, $a$not in ('yard','river','quarry','frost','city','casino')$a$, $b$not in ('yard','river','quarry','frost','city','casino','understrip')$b$);
    d := pg_temp.sub1(d, $a$not in ('5','10','endless','blitz','campaign','blackout','casino')$a$, $b$not in ('5','10','endless','blitz','campaign','blackout','casino','understrip')$b$);
    execute d;
  end if;
end $mig$;
alter table public.lobbies drop constraint if exists lobbies_length_check;
alter table public.lobbies add constraint lobbies_length_check check (length = any (array['5','10','endless','blitz','campaign','blackout','casino','understrip']));
