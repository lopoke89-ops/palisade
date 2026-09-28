-- PALISADE v0.9.0: the Halloween Case, lobby backgrounds (cat 'bg'), and boss-by-boss case drops.
-- APPLY WITH THE v0.9.0 PUSH (not before): run this whole file once in the Supabase SQL editor, or through the migration tool.
-- Safe for older clients: they send no boss_keys, so their bosses still pay Afterglow Cases.
-- Halloween Case: 19 items (14 wearables + 5 backgrounds), 12 shards, dropped by the Butcher and the Ferryman.
-- lobby backgrounds are a fifth cosmetic category
alter table public.cosmetics drop constraint if exists cosmetics_cat_check;
alter table public.cosmetics add constraint cosmetics_cat_check check (cat = any (array['skin','hat','trail','fx','bg']));
insert into public.case_types (id, name, weights, shard_cost, modes, drop, sort)
values ('halloween', 'HALLOWEEN CASE', '{"c":45,"r":32,"e":16,"l":6,"g":1}', 12, '{}', '{}', 2)
on conflict (id) do update set name = excluded.name, weights = excluded.weights, shard_cost = excluded.shard_cost, sort = excluded.sort;
insert into public.cosmetics select * from json_populate_recordset(null::public.cosmetics, '[{"id": "skin:pumpkin", "cat": "skin", "key": "pumpkin", "name": "Pumpkin Patch", "rarity": "c", "src": "case", "need": null, "box": "halloween"}, {"id": "trail:candycorn", "cat": "trail", "key": "candycorn", "name": "Candy Corn", "rarity": "c", "src": "case", "need": null, "box": "halloween"}, {"id": "hat:jackolantern", "cat": "hat", "key": "jackolantern", "name": "Jack-o''-Lantern", "rarity": "r", "src": "case", "need": null, "box": "halloween"}, {"id": "skin:cobweb", "cat": "skin", "key": "cobweb", "name": "Cobweb", "rarity": "r", "src": "case", "need": null, "box": "halloween"}, {"id": "fx:bats", "cat": "fx", "key": "bats", "name": "Bat Swarm", "rarity": "r", "src": "case", "need": null, "box": "halloween"}, {"id": "skin:skeleton", "cat": "skin", "key": "skeleton", "name": "Skeleton", "rarity": "e", "src": "case", "need": null, "box": "halloween"}, {"id": "skin:mummy", "cat": "skin", "key": "mummy", "name": "Mummy", "rarity": "e", "src": "case", "need": null, "box": "halloween"}, {"id": "hat:witch", "cat": "hat", "key": "witch", "name": "Witch Hat", "rarity": "e", "src": "case", "need": null, "box": "halloween"}, {"id": "trail:ghostfire", "cat": "trail", "key": "ghostfire", "name": "Ghostfire", "rarity": "e", "src": "case", "need": null, "box": "halloween"}, {"id": "fx:spider", "cat": "fx", "key": "spider", "name": "Spider Drop", "rarity": "e", "src": "case", "need": null, "box": "halloween"}, {"id": "skin:reaper", "cat": "skin", "key": "reaper", "name": "Grim Reaper", "rarity": "l", "src": "case", "need": null, "box": "halloween"}, {"id": "hat:pumpkinking", "cat": "hat", "key": "pumpkinking", "name": "Pumpkin King", "rarity": "l", "src": "case", "need": null, "box": "halloween"}, {"id": "fx:souls", "cat": "fx", "key": "souls", "name": "Soul Harvest", "rarity": "l", "src": "case", "need": null, "box": "halloween"}, {"id": "skin:phantom", "cat": "skin", "key": "phantom", "name": "Phantom", "rarity": "g", "src": "case", "need": null, "box": "halloween"}, {"id": "bg:campfire", "cat": "bg", "key": "campfire", "name": "Campfire Dusk", "rarity": "c", "src": "free", "need": null, "box": null}, {"id": "bg:nightwatch", "cat": "bg", "key": "nightwatch", "name": "Night Watch", "rarity": "c", "src": "free", "need": null, "box": null}, {"id": "bg:dawn", "cat": "bg", "key": "dawn", "name": "First Light", "rarity": "r", "src": "unlock", "need": {"wins": 1}, "box": null}, {"id": "bg:aurora", "cat": "bg", "key": "aurora", "name": "Aurora", "rarity": "e", "src": "unlock", "need": {"wins": 10}, "box": null}, {"id": "bg:emberfield", "cat": "bg", "key": "emberfield", "name": "Ember Field", "rarity": "r", "src": "unlock", "need": {"drops": 100}, "box": null}, {"id": "bg:crimson", "cat": "bg", "key": "crimson", "name": "Crimson Smoke", "rarity": "e", "src": "unlock", "need": {"drops": 500}, "box": null}, {"id": "bg:neongrid", "cat": "bg", "key": "neongrid", "name": "Neon Grid", "rarity": "l", "src": "unlock", "need": {"drops": 1000}, "box": null}, {"id": "bg:goldrush", "cat": "bg", "key": "goldrush", "name": "Gold Rush", "rarity": "l", "src": "unlock", "need": {"hardWins": 3}, "box": null}, {"id": "bg:harvestmoon", "cat": "bg", "key": "harvestmoon", "name": "Harvest Moon", "rarity": "r", "src": "case", "need": null, "box": "halloween"}, {"id": "bg:hauntedfog", "cat": "bg", "key": "hauntedfog", "name": "Haunted Fog", "rarity": "e", "src": "case", "need": null, "box": "halloween"}, {"id": "bg:fieldmap", "cat": "bg", "key": "fieldmap", "name": "Field Map", "rarity": "r", "src": "case", "need": null, "box": "supply"}, {"id": "bg:sandbags", "cat": "bg", "key": "sandbags", "name": "Sandbag Line", "rarity": "r", "src": "case", "need": null, "box": "supply"}, {"id": "bg:dogtags", "cat": "bg", "key": "dogtags", "name": "Dog Tags", "rarity": "e", "src": "case", "need": null, "box": "supply"}, {"id": "bg:watchtower", "cat": "bg", "key": "watchtower", "name": "Watchtower", "rarity": "e", "src": "case", "need": null, "box": "supply"}, {"id": "bg:searchlight", "cat": "bg", "key": "searchlight", "name": "Searchlight", "rarity": "l", "src": "case", "need": null, "box": "supply"}, {"id": "bg:sunsetfade", "cat": "bg", "key": "sunsetfade", "name": "Sunset Fade", "rarity": "r", "src": "case", "need": null, "box": "afterglow"}, {"id": "bg:lagoonwaves", "cat": "bg", "key": "lagoonwaves", "name": "Lagoon", "rarity": "r", "src": "case", "need": null, "box": "afterglow"}, {"id": "bg:nebula", "cat": "bg", "key": "nebula", "name": "Nebula", "rarity": "e", "src": "case", "need": null, "box": "afterglow"}, {"id": "bg:arcade", "cat": "bg", "key": "arcade", "name": "Arcade", "rarity": "e", "src": "case", "need": null, "box": "afterglow"}, {"id": "bg:neonpulse", "cat": "bg", "key": "neonpulse", "name": "Neon Pulse", "rarity": "l", "src": "case", "need": null, "box": "afterglow"}, {"id": "bg:eventhorizon", "cat": "bg", "key": "eventhorizon", "name": "Event Horizon", "rarity": "l", "src": "case", "need": null, "box": "afterglow"}, {"id": "bg:goldaurora", "cat": "bg", "key": "goldaurora", "name": "Gold Aurora", "rarity": "g", "src": "case", "need": null, "box": "afterglow"}, {"id": "bg:graveyard", "cat": "bg", "key": "graveyard", "name": "Graveyard", "rarity": "r", "src": "case", "need": null, "box": "halloween"}, {"id": "bg:witchbrew", "cat": "bg", "key": "witchbrew", "name": "Witch''s Brew", "rarity": "e", "src": "case", "need": null, "box": "halloween"}, {"id": "bg:bloodmoon", "cat": "bg", "key": "bloodmoon", "name": "Blood Moon", "rarity": "l", "src": "case", "need": null, "box": "halloween"}]')
on conflict (id) do update set cat = excluded.cat, key = excluded.key, name = excluded.name, rarity = excluded.rarity, src = excluded.src, need = excluded.need, box = excluded.box;
-- the two free backgrounds: in every new locker, and added to every existing one
alter table public.lockers alter column owned set default ARRAY['skin:std','hat:class','hat:cap','trail:std','fx:none','bg:campfire','bg:nightwatch']::text[];
update public.lockers l set owned = array(select distinct u from unnest(l.owned || ARRAY['bg:campfire','bg:nightwatch']::text[]) u), updated_at = now()
  where not (ARRAY['bg:campfire','bg:nightwatch']::text[] <@ l.owned);
CREATE OR REPLACE FUNCTION public.claim_match_reward(p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user(); l public.lockers; ct public.case_types; cb public.case_types;
  v_kind text := p->>'kind'; v_mode text := coalesce(p->>'mode', '5'); v_pvp text := coalesce(p->>'pvp', '');
  v_diff text := coalesce(p->>'diff', 'normal'); v_win boolean := coalesce(p->>'win' = 'true', false);
  v_held int := greatest(coalesce(private.num(p->>'held'), 0), 0)::int; v_kills int := greatest(coalesce(private.num(p->>'kills'), 0), 0)::int;
  v_dur int := coalesce(private.num(p->>'duration_s'), 0)::int; v_boss int := least(greatest(coalesce(private.num(p->>'bosses'), 0), 0), 100)::int;
  waves int := 0; v_st jsonb; v_prog int; earned int := 0; granted int; got text[]; v_case text := 'supply'; chance float8; v_bonus int := 0;
  v_budget float8;
  -- salvage left at the end of a co-op / Endless run: 20 to 1, at most 2 shards per raid held and 10 a run (same as the game)
  v_sal int := least(greatest(coalesce(private.num(p->>'salvage'), 0), 0), 1000000)::int; v_shards int := 0;
  -- v0.9.0: which bosses went down (each boss drops its own case; the October Butcher drops two Halloween Cases)
  v_keys jsonb := p->'boss_keys'; v_key text; v_cap int; v_n int := 0; v_hal int := 0; v_glow int := 0;
  v_oct boolean := (now() at time zone 'UTC') >= make_timestamp(extract(year from now())::int, 9, 30, 10, 0, 0)
               and (now() at time zone 'UTC') <  make_timestamp(extract(year from now())::int, 11, 1, 14, 0, 0);
begin
  if v_kind is null or v_kind not in ('run', 'match') then raise exception 'Unknown result' using errcode = '22023'; end if;
  if v_dur < 20 or v_dur > 21600 or (v_kind = 'match' and v_dur < 30) then raise exception 'That match length doesn''t add up' using errcode = '22023'; end if;
  -- real players land well under 0.3 drops a second; 1 a second leaves lots of room
  if v_kills > v_dur then raise exception 'That kill count doesn''t add up' using errcode = '22023'; end if;
  select * into l from public.lockers where user_id = uid for update;
  if exists (select 1 from public.match_results m where m.user_id = uid and m.created_at > now() - interval '20 seconds') then
    raise exception 'Rewards were claimed a moment ago' using errcode = '22023';
  end if;
  v_budget := least(22200, l.play_budget + extract(epoch from now() - l.budget_at));
  if v_dur > v_budget + 60 then
    raise exception 'More play time than real time so far; this result will be saved later' using errcode = '22023';
  end if;
  v_st := l.st; v_prog := l.prog;
  if v_kind = 'run' then
    if v_mode not in ('5', '10', 'endless') or v_diff not in ('easy', 'normal', 'hard') then raise exception 'Unknown mode' using errcode = '22023'; end if;
    waves := case v_mode when '5' then 5 when '10' then 10 else 0 end;
    -- each raid has to spawn its whole wave, and waves grow: at least ~8 s a raid plus more for later ones
    if (waves > 0 and v_held > waves) or v_dur + 20 < 8 * v_held + (v_held * v_held) / 4 then raise exception 'That raid count doesn''t add up' using errcode = '22023'; end if;
    if waves = 0 or v_held <> waves then v_win := false; end if;
    v_st := jsonb_set(v_st, '{raids}', to_jsonb(coalesce((v_st->>'raids')::int, 0) + v_held));
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    if v_win then
      v_st := jsonb_set(v_st, '{wins}', to_jsonb(coalesce((v_st->>'wins')::int, 0) + 1));
      if v_diff = 'hard' then v_st := jsonb_set(v_st, '{hardWins}', to_jsonb(coalesce((v_st->>'hardWins')::int, 0) + 1)); end if;
    end if;
    if waves = 0 then v_st := jsonb_set(v_st, '{endless}', to_jsonb(greatest(coalesce((v_st->>'endless')::int, 0), v_held))); end if;
    v_prog := v_prog + v_held;
    earned := v_prog / 3 + case when v_win then (case when waves >= 10 then 2 else 1 end) else 0 end + case when waves = 0 then v_held / 5 else 0 end;
    v_prog := v_prog % 3;
    -- a boss every fifth raid: no more bosses than raids held allow
    v_cap := (v_held + 1) / 5;
    if waves > 0 then v_cap := least(v_cap, waves / 5); end if;
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
      -- older clients only send a count: those bosses pay Afterglow Cases as before
      v_boss := least(v_boss, v_cap); v_glow := v_boss;
    end if;
    select * into cb from public.case_types c where c.drop ? 'boss' order by c.sort limit 1;
    if found then v_glow := v_glow * coalesce((cb.drop->'boss'->>'each')::int, 1); end if;
    v_bonus := v_glow + v_hal;
    v_shards := least(v_sal / 20, 2 * v_held, 10);
  else
    if v_pvp not in ('base', 'ffa') then raise exception 'Unknown match type' using errcode = '22023'; end if;
    v_st := jsonb_set(v_st, '{drops}', to_jsonb(coalesce((v_st->>'drops')::int, 0) + v_kills));
    v_st := jsonb_set(v_st, '{pvp}', to_jsonb(coalesce((v_st->>'pvp')::int, 0) + 1));
    if v_win then v_st := jsonb_set(v_st, '{pvpWins}', to_jsonb(coalesce((v_st->>'pvpWins')::int, 0) + 1)); end if;
    v_case := null;
    select * into ct from public.case_types c where v_pvp = any(c.modes) order by c.sort limit 1;
    if found then
      v_case := ct.id;
      chance := coalesce((ct.drop->v_pvp->>(case when v_win then 'win' else 'loss' end))::float8, 0);
      if random() < chance then earned := 1; end if;
    end if;
  end if;
  granted := earned;
  update public.lockers set st = v_st, prog = v_prog,
      cases = cases + case when v_case = 'supply' then granted else 0 end,
      bag = private.bag_add(private.bag_add(
              case when v_case is not null and v_case <> 'supply' and granted > 0 then private.bag_add(bag, v_case, granted) else bag end,
              coalesce(cb.id, 'afterglow'), v_glow), 'halloween', v_hal),
      shards = shards + v_shards,
      play_budget = greatest(0, v_budget - v_dur), budget_at = now(),
      rev = rev + 1, updated_at = now()
    where user_id = uid;
  insert into public.match_results (user_id, kind, mode, pvp, diff, win, held, kills, duration_s, cases_granted, case_id, bonus, shards)
    values (uid, v_kind, case when v_kind = 'run' then v_mode end, nullif(v_pvp, ''), case when v_kind = 'run' then v_diff end,
            v_win, v_held, v_kills, v_dur, granted, v_case, v_bonus, v_shards);
  update public.player_stats s set
      raids = s.raids + case when v_kind = 'run' then v_held else 0 end,
      wins = s.wins + case when v_kind = 'run' and v_win then 1 else 0 end,
      drops = s.drops + v_kills,
      best_endless = greatest(s.best_endless, case when v_kind = 'run' and waves = 0 then v_held else 0 end),
      pvp = s.pvp + case when v_kind = 'match' then 1 else 0 end,
      pvp_wins = s.pvp_wins + case when v_kind = 'match' and v_win then 1 else 0 end,
      updated_at = now()
    where s.user_id = uid;
  got := private.apply_unlocks(uid);
  select * into l from public.lockers where user_id = uid;
  return jsonb_build_object('cases_granted', granted, 'case_id', v_case, 'capped', false, 'chance', chance,
    'bonus', jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), 'shards', v_shards,
    'bonuses', jsonb_build_array(jsonb_build_object('case', coalesce(cb.id, 'afterglow'), 'n', v_glow), jsonb_build_object('case', 'halloween', 'n', v_hal)),
    'unlocked', to_jsonb(got), 'locker', private.locker_out(l));
end $function$;

