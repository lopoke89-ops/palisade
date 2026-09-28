-- PALISADE v0.9.2 migration. APPLY WITH THE v0.9.2 PUSH (not before): run this whole file once in the Supabase SQL editor,
-- or through the migration tool. Tested in rolled-back transactions on the test account.
--
-- Part 1: match records. Every co-op/PvP result now carries the shared game id, which raids the player was there for
--   (joined at / left at, raid number and seconds), whether they left early, their armory upgrades, the salvage they
--   ended with, the modifiers and the map. Old rows keep empty values.
-- Part 2: the rejoin fix. A player is only paid for the raids they were there for, and never twice for the same raids
--   of the same game: a second claim with the same game id starts where the first one ended (bosses too).
-- Part 3: modifiers. The server keeps its own table of what each modifier does to rewards and works the bonus out
--   from the list; in-between bosses (Boss Rush, Nightmare) pay 15-30 shards each, only when the run has one of those
--   modifiers, the count fits the raids held and the play time backs it up.
-- Part 4: skill points and the skill tree. 1 point per 5 raids held, 1 per boss. Nodes are bought and reset (for
--   shards) through the functions below; the tree itself is in private.skill_defs().

-- ---------- part 1: columns
alter table public.match_results
  add column if not exists game_id text,
  add column if not exists raid_from int,
  add column if not exists raid_to int,
  add column if not exists joined_s int,
  add column if not exists left_s int,
  add column if not exists left_early boolean,
  add column if not exists upgrades text,
  add column if not exists salvage int,
  add column if not exists mods text[],
  add column if not exists map text,
  add column if not exists size text,
  add column if not exists shard_bosses int not null default 0,
  add column if not exists skill_points int not null default 0;
create index if not exists match_results_game on public.match_results (user_id, game_id) where game_id is not null;
create index if not exists match_results_game_all on public.match_results (game_id) where game_id is not null;

alter table public.lockers
  add column if not exists sp int not null default 0,          -- skill points not spent yet
  add column if not exists sp_prog int not null default 0,     -- raids held toward the next point (0-4)
  add column if not exists sp_total int not null default 0,    -- every point ever earned
  add column if not exists skills jsonb not null default '{}'::jsonb;   -- {node id: level}

-- ---------- part 3: what each modifier does to rewards (percent; the game has the same table)
CREATE OR REPLACE FUNCTION private.mod_bonus(p_id text, p_pvp text)
 RETURNS int LANGUAGE sql IMMUTABLE SET search_path TO '' AS $function$
  select case when coalesce(p_pvp, '') in ('base', 'ffa') then
      case p_id when 'adrenaline' then -15 when 'weather' then 0 when 'nightmare' then 0 when 'glass' then 0 when 'onejob' then 0
        when 'scrap' then case when p_pvp = 'base' then 0 end when 'frenzy' then 0 when 'sudden' then case when p_pvp = 'ffa' then 0 end end
    else
      case p_id when 'nopatch' then 10 when 'alone' then 20 when 'firestorm' then 10 when 'adrenaline' then -15 when 'laststand' then 10
        when 'elite' then 15 when 'bossrush' then 10 when 'weather' then 10 when 'nightmare' then 15 when 'berserk' then 10 end
    end
$function$;
-- the known modifiers in a claim for this mode (unknown ones and repeats are dropped), at most 15
CREATE OR REPLACE FUNCTION private.clean_mods(p jsonb, p_pvp text)
 RETURNS text[] LANGUAGE sql IMMUTABLE SET search_path TO '' AS $function$
  select coalesce(array_agg(distinct m order by m), '{}'::text[]) from (
    select value as m from jsonb_array_elements_text(case when jsonb_typeof(p) = 'array' then p else '[]'::jsonb end) limit 30) s
  where private.mod_bonus(m, p_pvp) is not null
$function$;

-- ---------- part 4: the tree (same order and costs as SKILLS in the game)
CREATE OR REPLACE FUNCTION private.skill_defs()
 RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path TO '' AS $function$
  select '{"dmg":{"cost":[1,2,3]},"rate":{"cost":[1,2,3]},"reload":{"cost":[1,2]},"range":{"cost":[1,2]},
    "hp":{"cost":[1,2,3]},"regen":{"cost":[2,3]},"revive":{"cost":[1,2]},"speed":{"cost":[1,2,3]},"vest":{"cost":[2,3]},"haul":{"cost":[1,2]},
    "rockets":{"cost":[1,2,3]},"pouch":{"cost":[2,3]},"molotov":{"cost":[3],"req":["pouch",1]},"ghillie":{"cost":[1,2]},"stride":{"cost":[1,2]}}'::jsonb
$function$;
CREATE OR REPLACE FUNCTION private.respec_cost() RETURNS int LANGUAGE sql IMMUTABLE SET search_path TO '' AS $function$ select 40 $function$;
CREATE OR REPLACE FUNCTION private.skill_spent(t jsonb)
 RETURNS int LANGUAGE sql IMMUTABLE SET search_path TO '' AS $function$
  select coalesce(sum((d.value->'cost'->>(l - 1))::int), 0)::int
  from jsonb_each(private.skill_defs()) d
  cross join lateral generate_series(1, least(coalesce((t->>d.key)::int, 0), jsonb_array_length(d.value->'cost'))) l
$function$;
revoke all on function private.mod_bonus(text, text), private.clean_mods(jsonb, text), private.skill_defs(), private.respec_cost(), private.skill_spent(jsonb)
  from public, anon, authenticated;

-- buy the next level of a node with skill points
CREATE OR REPLACE FUNCTION public.skill_buy(p_node text, p_rev integer DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
declare uid uuid := private.require_user(); l public.lockers; d jsonb := private.skill_defs()->p_node; lv int; cost int;
begin
  if d is null then raise exception 'Unknown skill' using errcode = '22023'; end if;
  select * into l from public.lockers where user_id = uid for update;
  perform private.check_rev(l, p_rev);
  lv := coalesce((l.skills->>p_node)::int, 0);
  if lv >= jsonb_array_length(d->'cost') then raise exception 'That skill is maxed' using errcode = '22023'; end if;
  if d ? 'req' and coalesce((l.skills->>(d->'req'->>0))::int, 0) < (d->'req'->>1)::int then
    raise exception 'Unlock % first', d->'req'->>0 using errcode = '22023'; end if;
  cost := (d->'cost'->>lv)::int;
  if l.sp < cost then raise exception 'That takes % skill point%', cost, case when cost = 1 then '' else 's' end using errcode = '22023'; end if;
  update public.lockers set sp = sp - cost, skills = jsonb_set(skills, array[p_node], to_jsonb(lv + 1)), rev = rev + 1, updated_at = now()
    where user_id = uid returning * into l;
  return private.locker_out(l);
end $function$;
-- take every point back out of the tree, for shards
CREATE OR REPLACE FUNCTION public.skill_respec(p_rev integer DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
declare uid uuid := private.require_user(); l public.lockers; back int; cost int := private.respec_cost();
begin
  select * into l from public.lockers where user_id = uid for update;
  perform private.check_rev(l, p_rev);
  back := private.skill_spent(l.skills);
  if back = 0 then raise exception 'There are no points in your tree' using errcode = '22023'; end if;
  if l.shards < cost then raise exception 'Resetting takes % shards', cost using errcode = '22023'; end if;
  update public.lockers set sp = sp + back, skills = '{}'::jsonb, shards = shards - cost, rev = rev + 1, updated_at = now()
    where user_id = uid returning * into l;
  return private.locker_out(l);
end $function$;
-- another player's tree, so the host can check what a guest says they have (levels only)
CREATE OR REPLACE FUNCTION public.skills_of(p_uid uuid)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO '' AS $function$
declare uid uuid := private.require_user();
begin
  return coalesce((select l.skills from public.lockers l where l.user_id = p_uid), '{}'::jsonb);
end $function$;
revoke all on function public.skill_buy(text, integer), public.skill_respec(integer), public.skills_of(uuid) from public, anon;
grant execute on function public.skill_buy(text, integer), public.skill_respec(integer), public.skills_of(uuid) to authenticated;

-- ---------- parts 1-4: the claim
CREATE OR REPLACE FUNCTION public.claim_match_reward(p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user(); l public.lockers; ct public.case_types; cb public.case_types;
  v_kind text := p->>'kind'; v_mode text := coalesce(p->>'mode', '5'); v_pvp text := coalesce(p->>'pvp', '');
  v_diff text := coalesce(p->>'diff', 'normal'); v_win boolean := coalesce(p->>'win' = 'true', false);
  v_held int; v_kills int := greatest(coalesce(private.num(p->>'kills'), 0), 0)::int;
  v_dur int := coalesce(private.num(p->>'duration_s'), 0)::int; v_boss int := least(greatest(coalesce(private.num(p->>'bosses'), 0), 0), 100)::int;
  waves int := 0; v_st jsonb; v_prog int; earned int := 0; granted int; got text[]; v_case text := 'supply'; chance float8; v_bonus int := 0;
  v_budget float8;
  v_sal int := least(greatest(coalesce(private.num(p->>'salvage'), 0), 0), 1000000)::int; v_shards int := 0;
  v_keys jsonb := p->'boss_keys'; v_key text; v_cap int; v_n int := 0; v_hal int := 0; v_glow int := 0;
  v_xl boolean := coalesce(p->>'size', 'std') = 'xl'; v_before text[]; v_new text[];
  v_oct boolean := (now() at time zone 'UTC') >= make_timestamp(extract(year from now())::int, 9, 30, 10, 0, 0)
               and (now() at time zone 'UTC') <  make_timestamp(extract(year from now())::int, 11, 1, 14, 0, 0);
  -- v0.9.2
  v_gid text := nullif(left(coalesce(p->>'game_id', ''), 40), '');
  v_to int := greatest(coalesce(private.num(p->>'raid_to'), private.num(p->>'held'), 0), 0)::int;
  v_from int := greatest(coalesce(private.num(p->>'raid_from'), 0), 0)::int;
  v_prev int; v_first int; v_join int; v_blo int; v_bhi int; v_seen boolean := false;
  v_mods text[]; v_pct int := 0; v_credit int := 0; v_scap int;
  v_sbreq int := least(greatest(coalesce(private.num(p->>'shard_bosses'), 0), 0), 100)::int; v_sb int := 0; v_sbcap int := 0; v_sbshards int := 0;
  v_sp int := 0; v_spprog int; r int;
begin
  if v_kind is null or v_kind not in ('run', 'match') then raise exception 'Unknown result' using errcode = '22023'; end if;
  if v_dur < 20 or v_dur > 21600 or (v_kind = 'match' and v_dur < 30) then raise exception 'That match length doesn''t add up' using errcode = '22023'; end if;
  if v_kills > v_dur then raise exception 'That kill count doesn''t add up' using errcode = '22023'; end if;
  select * into l from public.lockers where user_id = uid for update;
  if exists (select 1 from public.match_results m where m.user_id = uid and m.created_at > now() - interval '20 seconds') then
    raise exception 'Rewards were claimed a moment ago' using errcode = '22023';
  end if;
  v_budget := least(22200, l.play_budget + extract(epoch from now() - l.budget_at));
  if v_dur > v_budget + 60 then
    raise exception 'More play time than real time so far; this result will be saved later' using errcode = '22023';
  end if;
  v_mods := private.clean_mods(p->'mods', v_pvp);
  select coalesce(sum(private.mod_bonus(m, v_pvp)), 0) into v_pct from unnest(v_mods) m;
  v_pct := least(greatest(v_pct, -15), 75);
  -- the same game claimed before (the player left and came back): this claim starts where that one ended
  if v_gid is not null then
    select max(m.raid_to), min(m.raid_from), count(*) > 0 into v_prev, v_first, v_seen from public.match_results m where m.user_id = uid and m.game_id = v_gid;
  end if;
  v_st := l.st; v_prog := l.prog; v_spprog := l.sp_prog;
  if v_kind = 'run' then
    if v_mode not in ('5', '10', 'endless') or v_diff not in ('easy', 'normal', 'hard') then raise exception 'Unknown mode' using errcode = '22023'; end if;
    waves := case v_mode when '5' then 5 when '10' then 10 else 0 end;
    if waves > 0 and v_to > waves then raise exception 'That raid count doesn''t add up' using errcode = '22023'; end if;
    v_from := least(v_from, v_to); v_join := least(v_from, coalesce(v_first, v_from));
    if v_prev is not null then v_from := greatest(v_from, least(v_prev, v_to)); end if;
    v_held := v_to - v_from;
    -- each raid has to spawn its whole wave, and waves grow: at least ~8 s a raid plus more for later ones
    if v_dur + 20 < 8 * v_held + (v_held * v_held) / 4 then raise exception 'That raid count doesn''t add up' using errcode = '22023'; end if;
    -- a win counts for players who were there for at least half the run, once per game
    if waves = 0 or v_to <> waves or v_join * 2 > waves or (v_seen and v_prev >= waves) then v_win := false; end if;
    v_st := jsonb_set(v_st, '{raids}', to_jsonb(coalesce((v_st->>'raids')::int, 0) + v_held));
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    if v_win then
      v_st := jsonb_set(v_st, '{wins}', to_jsonb(coalesce((v_st->>'wins')::int, 0) + 1));
      if v_diff = 'hard' then v_st := jsonb_set(v_st, '{hardWins}', to_jsonb(coalesce((v_st->>'hardWins')::int, 0) + 1)); end if;
    end if;
    if waves = 0 then v_st := jsonb_set(v_st, '{endless}', to_jsonb(greatest(coalesce((v_st->>'endless')::int, 0), v_to))); end if;
    -- modifiers move the raid credit toward Supply Cases (harder: more, Adrenaline: less)
    v_credit := floor(v_held * (100 + v_pct) / 100.0)::int;
    v_prog := v_prog + v_credit;
    earned := v_prog / 3 + case when v_win then (case when waves >= 10 then 2 else 1 end) else 0 end + case when waves = 0 then v_held / 5 else 0 end;
    v_prog := v_prog % 3;
    -- bosses: the raids this claim covers are v_from+1 .. v_to+1 (a boss can fall in the raid that was lost or left),
    -- minus any raid an earlier claim for the same game already covered
    v_blo := v_from; if v_prev is not null then v_blo := greatest(v_from, v_prev + 1); end if;
    v_bhi := v_to + 1; if waves > 0 then v_bhi := least(v_bhi, waves); end if;
    v_cap := greatest(0, v_bhi / 5 - v_blo / 5);
    -- XL: two bosses per boss raid, but only if the run took at least 35 s a raid (a false "xl" earns nothing extra)
    if v_xl and v_dur >= 35 * v_held then v_cap := v_cap * 2; end if;
    if jsonb_typeof(v_keys) = 'array' then
      for v_key in select value from jsonb_array_elements_text(v_keys) limit 40 loop
        exit when v_n >= v_cap;
        if v_key in ('butcher', 'ferryman') then v_hal := v_hal + 1; v_n := v_n + 1;
        elsif v_key = 'butcher_oct' then v_hal := v_hal + case when v_oct then 2 else 1 end; v_n := v_n + 1;
        elsif v_key in ('demolisher', 'storm', 'foreman') then v_glow := v_glow + 1; v_n := v_n + 1;
        end if;
      end loop;
      v_boss := v_n;
    else
      v_boss := least(v_boss, v_cap); v_glow := v_boss; v_n := v_boss;
    end if;
    select * into cb from public.case_types c where c.drop ? 'boss' order by c.sort limit 1;
    if found then v_glow := v_glow * coalesce((cb.drop->'boss'->>'each')::int, 1); end if;
    v_bonus := v_glow + v_hal;
    -- in-between bosses (Boss Rush: the even raids; Nightmare: any raid without a boss), 15-30 shards each
    if v_sbreq > 0 and ('bossrush' = any(v_mods) or 'nightmare' = any(v_mods)) and v_dur >= 25 * greatest(v_held, 1) then
      for r in (v_blo + 1) .. v_bhi loop
        if r % 5 <> 0 and ('nightmare' = any(v_mods) or r % 2 = 0) then v_sbcap := v_sbcap + 1; end if;
      end loop;
      v_sb := least(v_sbreq, v_sbcap);
      for r in 1 .. v_sb loop v_sbshards := v_sbshards + 15 + floor(random() * 16)::int; end loop;
    end if;
    -- leftover salvage: 20 to 1, at most 2 a raid held and 10 a run (modifiers move the cap too)
    v_scap := greatest(0, floor(10 * (100 + v_pct) / 100.0)::int);
    v_shards := least(v_sal / 20, 2 * v_held, v_scap) + v_sbshards;
    -- skill points: 1 per 5 raids held, 1 per boss
    v_spprog := v_spprog + v_held;
    v_sp := v_spprog / 5 + v_n + v_sb;
    v_spprog := v_spprog % 5;
  else
    if v_pvp not in ('base', 'ffa') then raise exception 'Unknown match type' using errcode = '22023'; end if;
    v_held := 0;
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    if not v_seen then
      v_st := jsonb_set(v_st, '{pvp}', to_jsonb(coalesce((v_st->>'pvp')::int, 0) + 1));
      if v_win then v_st := jsonb_set(v_st, '{pvpWins}', to_jsonb(coalesce((v_st->>'pvpWins')::int, 0) + 1)); end if;
    end if;
    v_case := null;
    select * into ct from public.case_types c where v_pvp = any(c.modes) order by c.sort limit 1;
    if found then
      v_case := ct.id;
      chance := coalesce((ct.drop->v_pvp->>(case when v_win then 'win' else 'loss' end))::float8, 0) * (100 + v_pct) / 100.0;
      if v_seen then chance := 0; end if;   -- one roll per match
      if random() < chance then earned := 1; end if;
    end if;
  end if;
  granted := earned;
  v_before := l.owned;
  update public.lockers set st = v_st, prog = v_prog,
      cases = cases + case when v_case = 'supply' then granted else 0 end,
      bag = private.bag_add(private.bag_add(
              case when v_case is not null and v_case <> 'supply' and granted > 0 then private.bag_add(bag, v_case, granted) else bag end,
              coalesce(cb.id, 'afterglow'), v_glow), 'halloween', v_hal),
      shards = shards + v_shards,
      sp = sp + v_sp, sp_total = sp_total + v_sp, sp_prog = v_spprog,
      play_budget = greatest(0, v_budget - v_dur), budget_at = now(),
      rev = rev + 1, updated_at = now()
    where user_id = uid;
  insert into public.match_results (user_id, kind, mode, pvp, diff, win, held, kills, duration_s, cases_granted, case_id, bonus, shards,
      game_id, raid_from, raid_to, joined_s, left_s, left_early, upgrades, salvage, mods, map, size, shard_bosses, skill_points)
    values (uid, v_kind, case when v_kind = 'run' then v_mode end, nullif(v_pvp, ''), case when v_kind = 'run' then v_diff end,
            v_win, v_held, v_kills, v_dur, granted, v_case, v_bonus, v_shards,
            v_gid, case when v_kind = 'run' then v_from end, case when v_kind = 'run' then v_to end,
            least(greatest(private.num(p->>'joined_s'), 0), 86400)::int, least(greatest(private.num(p->>'left_s'), 0), 86400)::int,
            coalesce(p->>'left' = 'true', false), left(regexp_replace(coalesce(p->>'upgrades', ''), '[^0-9a-z:]', '', 'g'), 16), v_sal,
            v_mods, left(regexp_replace(coalesce(p->>'map', ''), '[^a-z]', '', 'g'), 12), case when v_xl then 'xl' else 'std' end, v_sb, v_sp);
  update public.player_stats s set
      raids = s.raids + case when v_kind = 'run' then v_held else 0 end,
      wins = s.wins + case when v_kind = 'run' and v_win then 1 else 0 end,
      drops = s.drops + v_kills,
      best_endless = greatest(s.best_endless, case when v_kind = 'run' and waves = 0 then v_to else 0 end),
      pvp = s.pvp + case when v_kind = 'match' and not v_seen then 1 else 0 end,
      pvp_wins = s.pvp_wins + case when v_kind = 'match' and v_win and not v_seen then 1 else 0 end,
      updated_at = now()
    where s.user_id = uid;
  got := private.apply_unlocks(uid);
  select * into l from public.lockers where user_id = uid;
  v_new := array(select u from unnest(l.owned) u where not (u = any(v_before)));
  return jsonb_build_object(
    'cases', case when v_kind = 'run'
        then jsonb_build_object('supply', granted, coalesce(cb.id, 'afterglow'), v_glow, 'halloween', v_hal)
        else case when v_case is not null then jsonb_build_object(v_case, granted) else '{}'::jsonb end end,
    'unlocked_ids', to_jsonb(v_new), 'to_next', 3 - l.prog, 'size', case when v_xl and v_dur >= 35 * v_held then 'xl' else 'std' end,
    'cases_granted', granted, 'case_id', v_case, 'capped', false, 'chance', chance,
    'bonus', jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), 'shards', v_shards,
    'bonuses', jsonb_build_array(jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), jsonb_build_object('case', 'halloween', 'n', v_hal)),
    -- v0.9.2
    'held', v_held, 'raid_from', v_from, 'mods', to_jsonb(v_mods), 'mod_pct', v_pct, 'shard_bosses', v_sb, 'boss_shards', v_sbshards,
    'skill_points', v_sp, 'sp', l.sp, 'sp_to_next', 5 - l.sp_prog, 'repeat', v_seen,
    'unlocked', to_jsonb(got), 'locker', private.locker_out(l));
end $function$;
