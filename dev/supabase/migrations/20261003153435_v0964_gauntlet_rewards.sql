-- v0.9.6.4 (part 2 of 2): claim_match_reward rebuilt from the live text (20261001081259_winter_whiteout.sql). The Whiteout
-- Gauntlet payouts, chapter evacs and the Hybrid Theory drop apply only to cv:4 claims, so older clients are paid as before.
-- The 31-day receipt cleanup line was removed (Big U, October 3): the Supabase connector holds any statement containing a
-- delete for a confirmation this session could not answer. Old receipts now stay; prune them by hand if the table grows.
-- Applied by staging this exact text (md5 89a994bedbaa2beb423e60c1c9f85121) and executing it in one migration.
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
  -- v0.9.4.0 Blitzkrieg Rush
  v_blitz boolean := coalesce(p->>'mode', '') in ('blitz','campaign') and p->>'kind' = 'run'; v_evac text := coalesce(p->>'evac', ''); v_left boolean := false;
  v_paid_keys text[]:='{}';
  v_campaign boolean := coalesce(p->>'mode','')='campaign'; v_winter int := 0; v_receipt text; v_cached jsonb; v_response jsonb;
  v_blz int := 0; v_fbn int := 0; v_fbcap int := 0; v_pfb int := 0; v_every int := 30; v_fbshards int := 0; v_mk text;
  -- v0.9.6.4: Whiteout Gauntlet payouts, chapter evacs and the Hybrid Theory drop apply only to cv:4 claims
  v_cv int := least(greatest(coalesce(private.num(p->>'cv'), 0), 0), 99)::int; v_g4 boolean; v_gw int := 0; v_chev int := 0; v_hyb int := 0; v_ce jsonb := p->'ch_evac';
begin
  v_g4 := v_campaign and v_cv >= 4;
  if v_kind is null or v_kind not in ('run', 'match') then raise exception 'Unknown result' using errcode = '22023'; end if;
  if v_dur < 20 or v_dur > 21600 or (v_kind = 'match' and v_dur < 30) then raise exception 'That match length doesn''t add up' using errcode = '22023'; end if;
  if v_kills > v_dur then raise exception 'That kill count doesn''t add up' using errcode = '22023'; end if;
  select * into l from public.lockers where user_id = uid for update;
  v_receipt := md5(coalesce(p->>'claim_id',p::text));
  select response into v_cached from private.reward_receipts where user_id=uid and claim_key=v_receipt;
  if found then return v_cached || jsonb_build_object('locker',private.locker_out(l),'retry',true); end if;
  if exists (select 1 from public.match_results m where m.user_id = uid and m.created_at > now() - interval '20 seconds') then
    raise exception 'Rewards were claimed a moment ago' using errcode = '22023';
  end if;
  v_budget := least(22200, l.play_budget + extract(epoch from now() - l.budget_at));
  if v_dur > v_budget + 60 then
    raise exception 'More play time than real time so far; this result will be saved later' using errcode = '22023';
  end if;
  v_mk := case when v_blitz and not v_campaign then 'blitz' else v_pvp end;   -- v0.9.4.0: Blitzkrieg Rush has its own modifier list
  v_mods := private.clean_mods(p->'mods', v_mk);
  if v_campaign then v_mods:=array(select m from unnest(v_mods) m where m not in ('bossrush','nightmare','blitzclock','hotlz','lockdown','scorched','barrage','onejob')); end if;
  select coalesce(sum(private.mod_bonus(m, v_mk)), 0) into v_pct from unnest(v_mods) m;
  v_pct := least(greatest(v_pct, -15), 75);
  if v_gid is not null then
    select max(m.raid_to), min(m.raid_from), count(*) > 0, coalesce(sum(coalesce(m.boss_n, m.bonus)), 0), coalesce(sum(m.shard_bosses), 0), coalesce(sum(m.fb_n), 0)
      into v_prev, v_first, v_seen, v_pbn, v_psb, v_pfb from public.match_results m where m.user_id = uid and m.game_id = v_gid;
  end if;
  v_st := l.st; v_prog := l.prog; v_spprog := l.sp_prog;
  if v_kind = 'run' then
    if v_mode not in ('5', '10', 'endless', 'blitz','campaign') or v_diff not in ('easy', 'normal', 'hard') then raise exception 'Unknown mode' using errcode = '22023'; end if;
    waves := case v_mode when '5' then 5 when '10' then 10 when 'blitz' then 15 when 'campaign' then 13 else 0 end;
    if waves > 0 and v_to > waves then raise exception 'That raid count doesn''t add up' using errcode = '22023'; end if;
    v_from := least(v_from, v_to); v_join := least(v_from, coalesce(v_first, v_from));
    if v_prev is not null then v_from := greatest(v_from, least(v_prev, v_to)); end if;
    v_held := v_to - v_from;
    if v_dur + 20 < 8 * v_held + (v_held * v_held) / 4 then raise exception 'That raid count doesn''t add up' using errcode = '22023'; end if;
    -- v0.9.4.0: Blitzkrieg Rush. Once raid 15's evacuation is open each player reports their own result: 'evac' (made it
    -- out: the win) or 'left' (left behind: half their cases and shards, odd counts rounded up first).
    if not v_blitz or v_to < waves or v_evac not in ('evac', 'left') then v_evac := ''; end if;
    v_left := v_evac = 'left';
    if v_blitz and v_evac <> 'evac' then v_win := false; end if;
    if waves = 0 or v_to <> waves or v_join * 2 > waves or (v_seen and v_prev >= waves) then v_win := false; end if;
    v_st := jsonb_set(v_st, '{raids}', to_jsonb(coalesce((v_st->>'raids')::int, 0) + v_held));
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    if v_win then
      v_st := jsonb_set(v_st, '{wins}', to_jsonb(coalesce((v_st->>'wins')::int, 0) + 1));
      if v_diff = 'hard' then v_st := jsonb_set(v_st, '{hardWins}', to_jsonb(coalesce((v_st->>'hardWins')::int, 0) + 1)); end if;
    end if;
    if waves = 0 then v_st := jsonb_set(v_st, '{endless}', to_jsonb(greatest(coalesce((v_st->>'endless')::int, 0), v_to))); end if;
    if v_campaign and v_held>0 then
      for r in (v_from+1)..v_to loop
        v_bk:=case when r<=3 then 'yard' when r<=6 then 'river' when r<=9 then 'quarry' else 'frost' end;
        v_st:=jsonb_set(v_st,array['map_'||v_bk],to_jsonb(coalesce((v_st->>('map_'||v_bk))::int,0)+1));
      end loop;
    elsif v_held > 0 and v_map in ('yard', 'river', 'quarry','frost') then
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
    v_cap := case when v_campaign then greatest(0,least(12,v_bhi)/3-v_blo/3) else greatest(0, v_bhi / 5 - v_blo / 5) end;
    if not v_campaign and v_xl and v_dur >= 35 * v_held then v_cap := v_cap * 2; end if;
    v_cap := greatest(0, v_cap - v_pbn);
    if jsonb_typeof(v_keys) = 'array' then
      for v_key in select value from jsonb_array_elements_text(v_keys) limit 40 loop
        exit when v_n >= v_cap;
        if v_campaign then
          continue when v_key=any(v_paid_keys) or v_key not in ('whitebutcher','whiteferryman','whiteforeman','rime');
          continue when v_key='whitebutcher' and not(v_blo<3 and v_bhi>=3) or v_key='whiteferryman' and not(v_blo<6 and v_bhi>=6) or v_key='whiteforeman' and not(v_blo<9 and v_bhi>=9) or v_key='rime' and not(v_blo<12 and v_bhi>=12);
          v_paid_keys:=array_append(v_paid_keys,v_key);
        end if;
        v_bk := case when v_key = 'butcher_oct' then 'butcher' when v_key in ('butcher', 'ferryman', 'demolisher', 'storm', 'foreman') then v_key
          when v_key='rime' and v_map='frost' then 'rime' when v_campaign then private.winter_base(v_key) when v_blitz then private.blitz_base(v_key) end;
        if v_bk is not null then v_st := jsonb_set(v_st, array['boss_' || v_bk], to_jsonb(coalesce((v_st->>('boss_' || v_bk))::int, 0) + 1)); end if;
        if (v_campaign and v_key in ('whitebutcher','whiteferryman','whiteforeman','rime')) or (v_map='frost' and v_key='rime') then
          v_winter:=v_winter+case when v_key='rime' then 2 else 1 end;v_n:=v_n+1;
        elsif v_blitz and private.blitz_base(v_key) is not null then   -- a Blitzkrieg boss (raids 5 and 10): two Blitzkrieg Cases, and the mode's ladder
          v_st := jsonb_set(v_st, '{mode_blitz_bosses}', to_jsonb(coalesce((v_st->>'mode_blitz_bosses')::int, 0) + 1));
          v_blz := v_blz + 2; v_n := v_n + 1;
        elsif v_key in ('butcher', 'ferryman') then v_hal := v_hal + 1; v_n := v_n + 1;
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
    -- v0.9.4.0: the Final Blitz bosses. At most 10 (15 with Double Time) per game, one per spawn beat of the time played,
    -- less what earlier claims for this game already paid. Each: two Blitzkrieg Cases, 15-30 shards, a skill point,
    -- +1 to its base boss's milestone and +1 to the BLITZKRIEG RUSH ladder.
    -- v0.9.6.4 Whiteout Gauntlet (cv:4 campaign): six waves of 2 Rime + 1 boss, one wave per 30 s of play, so at most
    -- 18 bosses, three per wave beat. Each pays 5-10 shards, a skill point and +1 to its base boss's milestone (Rime
    -- counts toward its own ladder with no cap). Cases come from waves fully cleared: +1 Winter Case each, capped by the
    -- bosses actually paid (three per wave) and by the time played.
    if v_g4 and v_to >= waves and jsonb_typeof(p->'fb_keys') = 'array' then
      v_fbcap := least(18, 3 * greatest(0, 1 + (v_dur - 20) / 30)) - v_pfb;
      for v_key in select value from jsonb_array_elements_text(p->'fb_keys') limit 20 loop
        exit when v_fbn >= v_fbcap;
        continue when v_key not in ('rime','whitebutcher','whiteforeman','tempest','bulldozer','bluebutcher','arsonist');
        v_bk := private.winter_base(v_key);
        continue when v_bk is null;
        v_st := jsonb_set(v_st, array['boss_' || v_bk], to_jsonb(coalesce((v_st->>('boss_' || v_bk))::int, 0) + 1));
        v_fbn := v_fbn + 1; v_fbshards := v_fbshards + 5 + floor(random() * 6)::int;
      end loop;
      v_gw := least(6, greatest(0, coalesce(private.num(p->>'g_cleared'), 0))::int, v_fbn / 3, greatest(0, 1 + (v_dur - 20) / 30));
      v_winter := v_winter + v_gw;
    elsif v_blitz and v_to >= waves and jsonb_typeof(p->'fb_keys') = 'array' then
      v_every := case when 'blitzclock' = any(v_mods) then 20 else 30 end;
      v_fbcap := least(case when 'blitzclock' = any(v_mods) then 15 else 10 end, greatest(0, 1 + (v_dur - 20) / v_every)) - v_pfb;
      for v_key in select value from jsonb_array_elements_text(p->'fb_keys') limit 20 loop
        exit when v_fbn >= v_fbcap;
        if v_campaign and v_key not in ('whitebutcher','whiteforeman','rime','tempest','bulldozer') then continue;end if;
        v_bk := case when v_campaign or v_key='rime' and v_map='frost' then private.winter_base(v_key) else private.blitz_base(v_key) end;
        continue when v_bk is null;
        v_st := jsonb_set(v_st, array['boss_' || v_bk], to_jsonb(coalesce((v_st->>('boss_' || v_bk))::int, 0) + 1));
        if not v_campaign and v_key<>'rime' then v_st := jsonb_set(v_st, '{mode_blitz_bosses}', to_jsonb(coalesce((v_st->>'mode_blitz_bosses')::int, 0) + 1));end if;
        if v_key in ('whitebutcher','whiteferryman','whiteforeman','rime') then v_winter:=v_winter+case when v_key='rime' then 2 else 1 end;else v_blz:=v_blz+2;end if; v_fbn := v_fbn + 1; v_fbshards := v_fbshards + 15 + floor(random() * 16)::int;
      end loop;
    end if;
    if v_blitz then v_sbreq := 0; end if;   -- no in-between bosses in Blitzkrieg Rush
    if v_blitz and v_win then if v_g4 then v_winter:=v_winter+2;elsif v_campaign then v_winter:=v_winter+1;else v_blz := v_blz + 1;end if; v_fbshards := v_fbshards + 25; end if;   -- making the evacuation
    -- v0.9.6.4 chapter evacs (after raids 3, 6, 9): +1 Winter Case for each one made inside this claim's raids.
    -- Missing one costs that chapter's evac case; the chapter boss's single Winter Case halves to 1 (odd counts round up).
    if v_g4 and jsonb_typeof(v_ce) = 'array' then
      for r in 0..2 loop
        if v_ce->>r = 'true' and v_from < 3 * (r + 1) and v_to >= 3 * (r + 1) then v_chev := v_chev + 1; end if;
      end loop;
      v_winter := v_winter + v_chev;
    end if;
    if v_sbreq > 0 and ('bossrush' = any(v_mods) or 'nightmare' = any(v_mods)) and v_dur >= 25 * greatest(v_held, 1) then
      for r in (v_blo + 1) .. v_bhi loop
        if r % 5 <> 0 and ('nightmare' = any(v_mods) or r % 2 = 0) then v_sbcap := v_sbcap + 1; end if;
      end loop;
      v_sb := least(v_sbreq, greatest(0, v_sbcap - v_psb));
      -- v0.9.3.8: every paid in-between boss also counts toward its boss milestone (clients send which bosses they were)
      if v_sb > 0 and jsonb_typeof(p->'sb_keys') = 'array' then
        for v_key in select value from jsonb_array_elements_text(p->'sb_keys') limit v_sb loop
          v_bk := case when v_key in ('butcher', 'ferryman', 'demolisher', 'storm', 'foreman') then v_key when v_key='rime' and v_map='frost' then 'rime' end;
          if v_bk is not null then v_st := jsonb_set(v_st, array['boss_' || v_bk], to_jsonb(coalesce((v_st->>('boss_' || v_bk))::int, 0) + 1)); end if;
        end loop;
      end if;
      for r in 1 .. v_sb loop v_sbshards := v_sbshards + 15 + floor(random() * 16)::int; end loop;
    end if;
    v_scap := greatest(0, floor(10 * (100 + v_pct) / 100.0)::int);
    v_shards := least(v_sal / 20, 2 * v_held, v_scap) + v_sbshards + v_fbshards;
    v_spprog := v_spprog + v_held;
    v_sp := v_spprog / 5 + v_n + v_sb + v_fbn;
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
  if v_win and v_kind = 'run' and v_cv >= 4 then v_hyb := 1; end if;   -- v0.9.6.4: one Hybrid Theory Case for every co-op win
  if v_win and not (v_kind = 'match' and v_seen) then
    select * into cf from public.case_types c where c.drop ? 'win' order by c.sort limit 1;
    if found and random() < coalesce((cf.drop->>'win')::float8, 0) then v_flag := 1; end if;
  end if;
  granted := earned;
  if v_left then   -- left behind: half of every case and of the shards (odd counts round up first); nothing else is halved
    granted := ceil(granted / 2.0)::int; v_glow := ceil(v_glow / 2.0)::int; v_hal := ceil(v_hal / 2.0)::int; v_blz := ceil(v_blz / 2.0)::int;
    v_shards := ceil(v_shards / 2.0)::int; v_fbshards := ceil(v_fbshards / 2.0)::int; v_sbshards := ceil(v_sbshards / 2.0)::int;
  end if;
  if v_left then v_winter:=ceil(v_winter/2.0)::int;end if;
  v_bonus := v_glow + v_hal + v_blz+v_winter;
  v_before := l.owned;
  update public.lockers set st = v_st, prog = v_prog,
      cases = cases + case when v_case = 'supply' then granted else 0 end,
      bag = private.bag_add(private.bag_add(
              case when v_case is not null and v_case <> 'supply' and granted > 0 then private.bag_add(bag, v_case, granted) else bag end,
              coalesce(cb.id, 'afterglow'), v_glow), 'halloween', v_hal)
            || case when v_blz > 0 then jsonb_build_object('blitz', coalesce((bag->>'blitz')::int, 0) + v_blz) else '{}'::jsonb end
            || case when v_flag > 0 then jsonb_build_object(cf.id, coalesce((bag->>cf.id)::int, 0) + v_flag) else '{}'::jsonb end
            || case when v_winter>0 then jsonb_build_object('winter',coalesce((bag->>'winter')::int,0)+v_winter) else '{}'::jsonb end
            || case when v_hyb>0 then jsonb_build_object('hybrid',coalesce((bag->>'hybrid')::int,0)+v_hyb) else '{}'::jsonb end,
      shards = shards + v_shards,
      sp = sp + v_sp, sp_total = sp_total + v_sp, sp_prog = v_spprog,
      play_budget = greatest(0, v_budget - v_dur), budget_at = now(),
      rev = rev + 1, updated_at = now()
    where user_id = uid;
  insert into public.match_results (user_id, kind, mode, pvp, diff, win, held, kills, duration_s, cases_granted, case_id, bonus, shards,
      game_id, raid_from, raid_to, joined_s, left_s, left_early, upgrades, salvage, mods, map, size, shard_bosses, skill_points, cls, boss_n, fb_n, evac)
    values (uid, v_kind, case when v_kind = 'run' then v_mode end, nullif(v_pvp, ''), case when v_kind = 'run' then v_diff end,
            v_win, v_held, v_kills, v_dur, granted, v_case, v_bonus, v_shards,
            v_gid, case when v_kind = 'run' then v_from end, case when v_kind = 'run' then v_to end,
            least(greatest(private.num(p->>'joined_s'), 0), 86400)::int, least(greatest(private.num(p->>'left_s'), 0), 86400)::int,
            coalesce(p->>'left' = 'true', false), left(regexp_replace(coalesce(p->>'upgrades', ''), '[^0-9a-z:]', '', 'g'), 16), v_sal,
            v_mods, left(regexp_replace(coalesce(p->>'map', ''), '[^a-z]', '', 'g'), 12), case when v_xl then 'xl' else 'std' end, v_sb, v_sp,
            nullif(v_cls, ''), case when v_kind = 'run' then v_n end, v_fbn, nullif(v_evac, ''));
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
  v_response := jsonb_build_object(
    'cases', (case when v_kind = 'run'
        then jsonb_build_object('supply', granted, coalesce(cb.id, 'afterglow'), v_glow, 'halloween', v_hal) || case when v_blz > 0 then jsonb_build_object('blitz', v_blz) else '{}'::jsonb end
        else case when v_case is not null then jsonb_build_object(v_case, granted) else '{}'::jsonb end end)
      || case when v_flag > 0 then jsonb_build_object(cf.id, v_flag) else '{}'::jsonb end
      || case when v_winter>0 then jsonb_build_object('winter',v_winter) else '{}'::jsonb end
      || case when v_hyb>0 then jsonb_build_object('hybrid',v_hyb) else '{}'::jsonb end,
    'unlocked_ids', to_jsonb(v_new), 'to_next', 3 - l.prog, 'size', case when v_xl and v_dur >= 35 * v_held then 'xl' else 'std' end,
    'cases_granted', granted, 'case_id', v_case, 'capped', false, 'chance', chance,
    'bonus', jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), 'shards', v_shards,
    'bonuses', jsonb_build_array(jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), jsonb_build_object('case', 'halloween', 'n', v_hal), jsonb_build_object('case', 'blitz', 'n', v_blz)),
    'held', v_held, 'raid_from', v_from, 'mods', to_jsonb(v_mods), 'mod_pct', v_pct, 'shard_bosses', v_sb,
    'skill_points', v_sp, 'sp', l.sp, 'sp_to_next', 5 - l.sp_prog, 'repeat', v_seen,
    'flag_case', v_flag, 'left_behind', v_left, 'fb_bosses', v_fbn, 'evac', v_evac, 'boss_shards', v_sbshards + v_fbshards,
    'gauntlet_waves', v_gw, 'chapter_evacs', v_chev, 'hybrid_case', v_hyb,
    'unlocked', to_jsonb(got), 'locker', private.locker_out(l));
  insert into private.reward_receipts(user_id,claim_key,response) values(uid,v_receipt,v_response);
  return v_response;
end $function$;

revoke all on function public.claim_match_reward(jsonb) from public,anon;
grant execute on function public.claim_match_reward(jsonb) to authenticated;
