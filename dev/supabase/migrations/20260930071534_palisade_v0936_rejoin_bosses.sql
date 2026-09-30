-- v0.9.3.6: rejoin boss credit. No player-data backfill.
-- claim_match_reward capped bosses per claim starting at the previous claim's raid + 1, so a boss or in-between
-- (Boss Rush / Nightmare) boss on the first raid after a rejoin was paid to nobody. The cap now covers the player's
-- whole stay in the game minus what earlier claims for that game already paid. boss_n records bosses paid per claim;
-- older rows fall back to their bonus-case count, which can only under-count the earlier credit (safe direction).
alter table public.match_results add column if not exists boss_n integer;

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
  v_gid text := nullif(left(coalesce(p->>'game_id', ''), 40), '');
  v_to int := greatest(coalesce(private.num(p->>'raid_to'), private.num(p->>'held'), 0), 0)::int;
  v_from int := greatest(coalesce(private.num(p->>'raid_from'), 0), 0)::int;
  v_prev int; v_first int; v_join int; v_blo int; v_bhi int; v_seen boolean := false;
  v_pbn int := 0; v_psb int := 0;
  v_mods text[]; v_pct int := 0; v_credit int := 0; v_scap int;
  v_sbreq int := least(greatest(coalesce(private.num(p->>'shard_bosses'), 0), 0), 100)::int; v_sb int := 0; v_sbcap int := 0; v_sbshards int := 0;
  v_sp int := 0; v_spprog int; r int;
  v_map text := left(regexp_replace(coalesce(p->>'map', ''), '[^a-z]', '', 'g'), 12);
  v_cls text := left(regexp_replace(coalesce(p->>'cls', ''), '[^a-z]', '', 'g'), 16);
  v_bk text; cf public.case_types; v_flag int := 0;
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
  if v_gid is not null then
    select max(m.raid_to), min(m.raid_from), count(*) > 0, coalesce(sum(coalesce(m.boss_n, m.bonus)), 0), coalesce(sum(m.shard_bosses), 0)
      into v_prev, v_first, v_seen, v_pbn, v_psb from public.match_results m where m.user_id = uid and m.game_id = v_gid;
  end if;
  v_st := l.st; v_prog := l.prog; v_spprog := l.sp_prog;
  if v_kind = 'run' then
    if v_mode not in ('5', '10', 'endless') or v_diff not in ('easy', 'normal', 'hard') then raise exception 'Unknown mode' using errcode = '22023'; end if;
    waves := case v_mode when '5' then 5 when '10' then 10 else 0 end;
    if waves > 0 and v_to > waves then raise exception 'That raid count doesn''t add up' using errcode = '22023'; end if;
    v_from := least(v_from, v_to); v_join := least(v_from, coalesce(v_first, v_from));
    if v_prev is not null then v_from := greatest(v_from, least(v_prev, v_to)); end if;
    v_held := v_to - v_from;
    if v_dur + 20 < 8 * v_held + (v_held * v_held) / 4 then raise exception 'That raid count doesn''t add up' using errcode = '22023'; end if;
    if waves = 0 or v_to <> waves or v_join * 2 > waves or (v_seen and v_prev >= waves) then v_win := false; end if;
    v_st := jsonb_set(v_st, '{raids}', to_jsonb(coalesce((v_st->>'raids')::int, 0) + v_held));
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    if v_win then
      v_st := jsonb_set(v_st, '{wins}', to_jsonb(coalesce((v_st->>'wins')::int, 0) + 1));
      if v_diff = 'hard' then v_st := jsonb_set(v_st, '{hardWins}', to_jsonb(coalesce((v_st->>'hardWins')::int, 0) + 1)); end if;
    end if;
    if waves = 0 then v_st := jsonb_set(v_st, '{endless}', to_jsonb(greatest(coalesce((v_st->>'endless')::int, 0), v_to))); end if;
    if v_held > 0 and v_map in ('yard', 'river', 'quarry') then
      v_st := jsonb_set(v_st, array['map_' || v_map], to_jsonb(coalesce((v_st->>('map_' || v_map))::int, 0) + v_held));
    end if;
    if v_held > 0 and v_cls in ('soldier', 'sniper', 'grenadier', 'quartermaster') then
      v_st := jsonb_set(v_st, array['cls_' || v_cls || '_raids'], to_jsonb(coalesce((v_st->>('cls_' || v_cls || '_raids'))::int, 0) + v_held));
    end if;
    v_credit := floor(v_held * (100 + v_pct) / 100.0)::int;
    v_prog := v_prog + v_credit;
    earned := v_prog / 3 + case when v_win then (case when waves >= 10 then 2 else 1 end) else 0 end + case when waves = 0 then v_held / 5 else 0 end;
    v_prog := v_prog % 3;
    -- v0.9.3.6: bosses are capped over the whole stretch this player was in the game (first join to now), minus
    -- what earlier claims for the same game already paid. The old per-claim window started at v_prev + 1, so a
    -- boss killed after a rejoin (e.g. leave after raid 4, back for raid 5) was never paid to anyone.
    v_blo := v_join;
    v_bhi := v_to + 1; if waves > 0 then v_bhi := least(v_bhi, waves); end if;
    v_cap := greatest(0, v_bhi / 5 - v_blo / 5);
    if v_xl and v_dur >= 35 * v_held then v_cap := v_cap * 2; end if;
    v_cap := greatest(0, v_cap - v_pbn);
    if jsonb_typeof(v_keys) = 'array' then
      for v_key in select value from jsonb_array_elements_text(v_keys) limit 40 loop
        exit when v_n >= v_cap;
        v_bk := case when v_key = 'butcher_oct' then 'butcher' when v_key in ('butcher', 'ferryman', 'demolisher', 'storm', 'foreman') then v_key end;
        if v_bk is not null then v_st := jsonb_set(v_st, array['boss_' || v_bk], to_jsonb(coalesce((v_st->>('boss_' || v_bk))::int, 0) + 1)); end if;
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
    if v_sbreq > 0 and ('bossrush' = any(v_mods) or 'nightmare' = any(v_mods)) and v_dur >= 25 * greatest(v_held, 1) then
      for r in (v_blo + 1) .. v_bhi loop
        if r % 5 <> 0 and ('nightmare' = any(v_mods) or r % 2 = 0) then v_sbcap := v_sbcap + 1; end if;
      end loop;
      v_sb := least(v_sbreq, greatest(0, v_sbcap - v_psb));
      for r in 1 .. v_sb loop v_sbshards := v_sbshards + 15 + floor(random() * 16)::int; end loop;
    end if;
    v_scap := greatest(0, floor(10 * (100 + v_pct) / 100.0)::int);
    v_shards := least(v_sal / 20, 2 * v_held, v_scap) + v_sbshards;
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
      if v_seen then chance := 0; end if;
      if random() < chance then earned := 1; end if;
    end if;
  end if;
  if v_win and not (v_kind = 'match' and v_seen) then
    select * into cf from public.case_types c where c.drop ? 'win' order by c.sort limit 1;
    if found and random() < coalesce((cf.drop->>'win')::float8, 0) then v_flag := 1; end if;
  end if;
  granted := earned;
  v_before := l.owned;
  update public.lockers set st = v_st, prog = v_prog,
      cases = cases + case when v_case = 'supply' then granted else 0 end,
      bag = private.bag_add(private.bag_add(
              case when v_case is not null and v_case <> 'supply' and granted > 0 then private.bag_add(bag, v_case, granted) else bag end,
              coalesce(cb.id, 'afterglow'), v_glow), 'halloween', v_hal)
            || case when v_flag > 0 then jsonb_build_object(cf.id, coalesce((bag->>cf.id)::int, 0) + v_flag) else '{}'::jsonb end,
      shards = shards + v_shards,
      sp = sp + v_sp, sp_total = sp_total + v_sp, sp_prog = v_spprog,
      play_budget = greatest(0, v_budget - v_dur), budget_at = now(),
      rev = rev + 1, updated_at = now()
    where user_id = uid;
  insert into public.match_results (user_id, kind, mode, pvp, diff, win, held, kills, duration_s, cases_granted, case_id, bonus, shards,
      game_id, raid_from, raid_to, joined_s, left_s, left_early, upgrades, salvage, mods, map, size, shard_bosses, skill_points, cls, boss_n)
    values (uid, v_kind, case when v_kind = 'run' then v_mode end, nullif(v_pvp, ''), case when v_kind = 'run' then v_diff end,
            v_win, v_held, v_kills, v_dur, granted, v_case, v_bonus, v_shards,
            v_gid, case when v_kind = 'run' then v_from end, case when v_kind = 'run' then v_to end,
            least(greatest(private.num(p->>'joined_s'), 0), 86400)::int, least(greatest(private.num(p->>'left_s'), 0), 86400)::int,
            coalesce(p->>'left' = 'true', false), left(regexp_replace(coalesce(p->>'upgrades', ''), '[^0-9a-z:]', '', 'g'), 16), v_sal,
            v_mods, left(regexp_replace(coalesce(p->>'map', ''), '[^a-z]', '', 'g'), 12), case when v_xl then 'xl' else 'std' end, v_sb, v_sp,
            nullif(v_cls, ''), case when v_kind = 'run' then v_n end);
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
    'cases', (case when v_kind = 'run'
        then jsonb_build_object('supply', granted, coalesce(cb.id, 'afterglow'), v_glow, 'halloween', v_hal)
        else case when v_case is not null then jsonb_build_object(v_case, granted) else '{}'::jsonb end end)
      || case when v_flag > 0 then jsonb_build_object(cf.id, v_flag) else '{}'::jsonb end,
    'unlocked_ids', to_jsonb(v_new), 'to_next', 3 - l.prog, 'size', case when v_xl and v_dur >= 35 * v_held then 'xl' else 'std' end,
    'cases_granted', granted, 'case_id', v_case, 'capped', false, 'chance', chance,
    'bonus', jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), 'shards', v_shards,
    'bonuses', jsonb_build_array(jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), jsonb_build_object('case', 'halloween', 'n', v_hal)),
    'held', v_held, 'raid_from', v_from, 'mods', to_jsonb(v_mods), 'mod_pct', v_pct, 'shard_bosses', v_sb, 'boss_shards', v_sbshards,
    'skill_points', v_sp, 'sp', l.sp, 'sp_to_next', 5 - l.sp_prog, 'repeat', v_seen,
    'flag_case', v_flag,
    'unlocked', to_jsonb(got), 'locker', private.locker_out(l));
end $function$;

revoke all on function public.claim_match_reward(jsonb) from public, anon;
grant execute on function public.claim_match_reward(jsonb) to authenticated;
