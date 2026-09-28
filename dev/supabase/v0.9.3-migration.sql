-- PALISADE v0.9.3: milestone cosmetics, class rewards, more Halloween, the Flag Case.
-- Run once, when v0.9.3 is published (not before). Tested first inside a rolled-back transaction on the test account.
--  * the Flag Case (drop.win: the chance for everyone after any win; 10 shards)
--  * 122 new items: 48 milestone unlocks (need: a locker counter), 10 Halloween Case items, 64 Flag Case items
--  * claim_match_reward adds to the new counters (boss_<boss>, map_<map>, cls_<class>_raids) and rolls the Flag Case;
--    older copies of the game keep working (their claims just add nothing to the new counters)
--  * match_results.cls: the class a player ended a run as, so it's on record from now on
-- Nothing here touches existing players' lockers: every counter starts at zero.

alter table public.match_results add column if not exists cls text;

insert into public.case_types (id, name, weights, shard_cost, modes, drop, sort)
values ('flags', 'FLAG CASE', '{"c":45,"r":30,"e":17,"l":7,"g":1}'::jsonb, 10, '{}', '{"win":0.25}'::jsonb, 3)
on conflict (id) do nothing;

insert into public.cosmetics (id, cat, key, name, rarity, src, need, box) values
  ('skin:sheetghost', 'skin', 'sheetghost', 'Sheet Ghost', 'c', 'case', null, 'halloween'),
  ('trail:candle', 'trail', 'candle', 'Candle Flicker', 'c', 'case', null, 'halloween'),
  ('skin:scarecrow', 'skin', 'scarecrow', 'Scarecrow', 'r', 'case', null, 'halloween'),
  ('trail:poison', 'trail', 'poison', 'Poison Apple', 'r', 'case', null, 'halloween'),
  ('skin:monster', 'skin', 'monster', 'Frankenstein''s Monster', 'e', 'case', null, 'halloween'),
  ('skin:clown', 'skin', 'clown', 'Scary Clown', 'e', 'case', null, 'halloween'),
  ('trail:blood', 'trail', 'blood', 'Blood Trail', 'e', 'case', null, 'halloween'),
  ('skin:slasher', 'skin', 'slasher', 'Hockey-Mask Slasher', 'l', 'case', null, 'halloween'),
  ('skin:dracula', 'skin', 'dracula', 'Dracula', 'l', 'case', null, 'halloween'),
  ('trail:hellfire', 'trail', 'hellfire', 'Hellfire', 'l', 'case', null, 'halloween'),
  ('skin:butcher', 'skin', 'butcher', 'Butcher', 'r', 'unlock', '{"boss_butcher":25}'::jsonb, null),
  ('skin:butcher2', 'skin', 'butcher2', 'Pale Butcher', 'e', 'unlock', '{"boss_butcher":50}'::jsonb, null),
  ('skin:butcher3', 'skin', 'butcher3', 'Bloodrage Butcher', 'l', 'unlock', '{"boss_butcher":100}'::jsonb, null),
  ('skin:butcher4', 'skin', 'butcher4', 'Gilded Butcher', 'g', 'unlock', '{"boss_butcher":250}'::jsonb, null),
  ('skin:demo', 'skin', 'demo', 'Demolisher', 'r', 'unlock', '{"boss_demolisher":25}'::jsonb, null),
  ('skin:demo2', 'skin', 'demo2', 'Desert Demolisher', 'e', 'unlock', '{"boss_demolisher":50}'::jsonb, null),
  ('skin:demo3', 'skin', 'demo3', 'Live-Fuse Demolisher', 'l', 'unlock', '{"boss_demolisher":100}'::jsonb, null),
  ('skin:demo4', 'skin', 'demo4', 'Gilded Demolisher', 'g', 'unlock', '{"boss_demolisher":250}'::jsonb, null),
  ('skin:storm', 'skin', 'storm', 'Stormcaller', 'r', 'unlock', '{"boss_storm":25}'::jsonb, null),
  ('skin:storm2', 'skin', 'storm2', 'Violet Stormcaller', 'e', 'unlock', '{"boss_storm":50}'::jsonb, null),
  ('skin:storm3', 'skin', 'storm3', 'Crackling Stormcaller', 'l', 'unlock', '{"boss_storm":100}'::jsonb, null),
  ('skin:storm4', 'skin', 'storm4', 'Gilded Stormcaller', 'g', 'unlock', '{"boss_storm":250}'::jsonb, null),
  ('skin:ferry', 'skin', 'ferry', 'Ferryman', 'r', 'unlock', '{"boss_ferryman":25}'::jsonb, null),
  ('skin:ferry2', 'skin', 'ferry2', 'Blackwater Ferryman', 'e', 'unlock', '{"boss_ferryman":50}'::jsonb, null),
  ('skin:ferry3', 'skin', 'ferry3', 'Drowned Ferryman', 'l', 'unlock', '{"boss_ferryman":100}'::jsonb, null),
  ('skin:ferry4', 'skin', 'ferry4', 'Gilded Ferryman', 'g', 'unlock', '{"boss_ferryman":250}'::jsonb, null),
  ('skin:foreman', 'skin', 'foreman', 'Foreman', 'r', 'unlock', '{"boss_foreman":25}'::jsonb, null),
  ('skin:foreman2', 'skin', 'foreman2', 'Night-Shift Foreman', 'e', 'unlock', '{"boss_foreman":50}'::jsonb, null),
  ('skin:foreman3', 'skin', 'foreman3', 'Sparking Foreman', 'l', 'unlock', '{"boss_foreman":100}'::jsonb, null),
  ('skin:foreman4', 'skin', 'foreman4', 'Gilded Foreman', 'g', 'unlock', '{"boss_foreman":250}'::jsonb, null),
  ('skin:yard', 'skin', 'yard', 'Yard Hand', 'r', 'unlock', '{"map_yard":250}'::jsonb, null),
  ('skin:yard2', 'skin', 'yard2', 'Harvest Hand', 'e', 'unlock', '{"map_yard":500}'::jsonb, null),
  ('skin:yard3', 'skin', 'yard3', 'Firefly Hand', 'l', 'unlock', '{"map_yard":1000}'::jsonb, null),
  ('skin:yard4', 'skin', 'yard4', 'Golden Yard', 'g', 'unlock', '{"map_yard":2500}'::jsonb, null),
  ('skin:river', 'skin', 'river', 'River Rat', 'r', 'unlock', '{"map_river":250}'::jsonb, null),
  ('skin:river2', 'skin', 'river2', 'Silt Rat', 'e', 'unlock', '{"map_river":500}'::jsonb, null),
  ('skin:river3', 'skin', 'river3', 'Rain Rat', 'l', 'unlock', '{"map_river":1000}'::jsonb, null),
  ('skin:river4', 'skin', 'river4', 'Golden River', 'g', 'unlock', '{"map_river":2500}'::jsonb, null),
  ('skin:quarry', 'skin', 'quarry', 'Quarry Hand', 'r', 'unlock', '{"map_quarry":250}'::jsonb, null),
  ('skin:quarry2', 'skin', 'quarry2', 'Oil-Drum Hand', 'e', 'unlock', '{"map_quarry":500}'::jsonb, null),
  ('skin:quarry3', 'skin', 'quarry3', 'Ashfall Hand', 'l', 'unlock', '{"map_quarry":1000}'::jsonb, null),
  ('skin:quarry4', 'skin', 'quarry4', 'Golden Quarry', 'g', 'unlock', '{"map_quarry":2500}'::jsonb, null),
  ('hat:officer', 'hat', 'officer', 'Officer''s Cap', 'r', 'unlock', '{"cls_soldier_raids":250}'::jsonb, null),
  ('trail:rocket', 'trail', 'rocket', 'Rocket Trail', 'e', 'unlock', '{"cls_soldier_raids":500}'::jsonb, null),
  ('fx:rocketburst', 'fx', 'rocketburst', 'Rocket Burst', 'l', 'unlock', '{"cls_soldier_raids":1000}'::jsonb, null),
  ('skin:gsoldier', 'skin', 'gsoldier', 'Gold Commander', 'g', 'unlock', '{"cls_soldier_raids":2500}'::jsonb, null),
  ('hat:ghood', 'hat', 'ghood', 'Ghillie Hood', 'r', 'unlock', '{"cls_sniper_raids":250}'::jsonb, null),
  ('trail:hairline', 'trail', 'hairline', 'Hairline', 'e', 'unlock', '{"cls_sniper_raids":500}'::jsonb, null),
  ('fx:reticle', 'fx', 'reticle', 'Reticle', 'l', 'unlock', '{"cls_sniper_raids":1000}'::jsonb, null),
  ('skin:gsniper', 'skin', 'gsniper', 'Gold Ghillie', 'g', 'unlock', '{"cls_sniper_raids":2500}'::jsonb, null),
  ('hat:bombhelm', 'hat', 'bombhelm', 'Blast Helmet', 'r', 'unlock', '{"cls_grenadier_raids":250}'::jsonb, null),
  ('trail:fuse', 'trail', 'fuse', 'Lit Fuse', 'e', 'unlock', '{"cls_grenadier_raids":500}'::jsonb, null),
  ('fx:frag', 'fx', 'frag', 'Frag Burst', 'l', 'unlock', '{"cls_grenadier_raids":1000}'::jsonb, null),
  ('skin:ggren', 'skin', 'ggren', 'Gold Demolitions', 'g', 'unlock', '{"cls_grenadier_raids":2500}'::jsonb, null),
  ('hat:qmset', 'hat', 'qmset', 'Supply Headset', 'r', 'unlock', '{"cls_quartermaster_raids":250}'::jsonb, null),
  ('trail:supply', 'trail', 'supply', 'Supply Line', 'e', 'unlock', '{"cls_quartermaster_raids":500}'::jsonb, null),
  ('fx:salvage', 'fx', 'salvage', 'Salvage Pop', 'l', 'unlock', '{"cls_quartermaster_raids":1000}'::jsonb, null),
  ('skin:gqm', 'skin', 'gqm', 'Gold Quartermaster', 'g', 'unlock', '{"cls_quartermaster_raids":2500}'::jsonb, null),
  ('trail:f_pride', 'trail', 'f_pride', 'Rainbow Pride Flag', 'g', 'case', null, 'flags'),
  ('trail:f_progress', 'trail', 'f_progress', 'Progress Pride Flag', 'g', 'case', null, 'flags'),
  ('trail:f_trans', 'trail', 'f_trans', 'Transgender Flag', 'l', 'case', null, 'flags'),
  ('trail:f_bi', 'trail', 'f_bi', 'Bisexual Flag', 'l', 'case', null, 'flags'),
  ('trail:f_lesbian', 'trail', 'f_lesbian', 'Lesbian Flag', 'l', 'case', null, 'flags'),
  ('trail:f_gay', 'trail', 'f_gay', 'Gay Men Flag', 'l', 'case', null, 'flags'),
  ('trail:f_pan', 'trail', 'f_pan', 'Pansexual Flag', 'l', 'case', null, 'flags'),
  ('trail:f_nonbinary', 'trail', 'f_nonbinary', 'Nonbinary Flag', 'l', 'case', null, 'flags'),
  ('trail:f_ace', 'trail', 'f_ace', 'Asexual Flag', 'l', 'case', null, 'flags'),
  ('trail:f_aro', 'trail', 'f_aro', 'Aromantic Flag', 'l', 'case', null, 'flags'),
  ('trail:f_fluid', 'trail', 'f_fluid', 'Genderfluid Flag', 'l', 'case', null, 'flags'),
  ('trail:f_agender', 'trail', 'f_agender', 'Agender Flag', 'l', 'case', null, 'flags'),
  ('trail:f_intersex', 'trail', 'f_intersex', 'Intersex Flag', 'l', 'case', null, 'flags'),
  ('trail:f_usa', 'trail', 'f_usa', 'United States Flag', 'e', 'case', null, 'flags'),
  ('trail:f_mexico', 'trail', 'f_mexico', 'Mexico Flag', 'e', 'case', null, 'flags'),
  ('trail:f_brazil', 'trail', 'f_brazil', 'Brazil Flag', 'e', 'case', null, 'flags'),
  ('trail:f_japan', 'trail', 'f_japan', 'Japan Flag', 'e', 'case', null, 'flags'),
  ('trail:f_skorea', 'trail', 'f_skorea', 'South Korea Flag', 'e', 'case', null, 'flags'),
  ('trail:f_puertorico', 'trail', 'f_puertorico', 'Puerto Rico Flag', 'e', 'case', null, 'flags'),
  ('trail:f_canada', 'trail', 'f_canada', 'Canada Flag', 'r', 'case', null, 'flags'),
  ('trail:f_uk', 'trail', 'f_uk', 'United Kingdom Flag', 'r', 'case', null, 'flags'),
  ('trail:f_germany', 'trail', 'f_germany', 'Germany Flag', 'r', 'case', null, 'flags'),
  ('trail:f_france', 'trail', 'f_france', 'France Flag', 'r', 'case', null, 'flags'),
  ('trail:f_italy', 'trail', 'f_italy', 'Italy Flag', 'r', 'case', null, 'flags'),
  ('trail:f_spain', 'trail', 'f_spain', 'Spain Flag', 'r', 'case', null, 'flags'),
  ('trail:f_ireland', 'trail', 'f_ireland', 'Ireland Flag', 'r', 'case', null, 'flags'),
  ('trail:f_argentina', 'trail', 'f_argentina', 'Argentina Flag', 'r', 'case', null, 'flags'),
  ('trail:f_philippines', 'trail', 'f_philippines', 'Philippines Flag', 'r', 'case', null, 'flags'),
  ('trail:f_india', 'trail', 'f_india', 'India Flag', 'c', 'case', null, 'flags'),
  ('trail:f_israel', 'trail', 'f_israel', 'Israel Flag', 'c', 'case', null, 'flags'),
  ('trail:f_russia', 'trail', 'f_russia', 'Russia Flag', 'c', 'case', null, 'flags'),
  ('trail:f_nkorea', 'trail', 'f_nkorea', 'North Korea Flag', 'c', 'case', null, 'flags'),
  ('bg:f_pride', 'bg', 'f_pride', 'Rainbow Pride Flag', 'g', 'case', null, 'flags'),
  ('bg:f_progress', 'bg', 'f_progress', 'Progress Pride Flag', 'g', 'case', null, 'flags'),
  ('bg:f_trans', 'bg', 'f_trans', 'Transgender Flag', 'l', 'case', null, 'flags'),
  ('bg:f_bi', 'bg', 'f_bi', 'Bisexual Flag', 'l', 'case', null, 'flags'),
  ('bg:f_lesbian', 'bg', 'f_lesbian', 'Lesbian Flag', 'l', 'case', null, 'flags'),
  ('bg:f_gay', 'bg', 'f_gay', 'Gay Men Flag', 'l', 'case', null, 'flags'),
  ('bg:f_pan', 'bg', 'f_pan', 'Pansexual Flag', 'l', 'case', null, 'flags'),
  ('bg:f_nonbinary', 'bg', 'f_nonbinary', 'Nonbinary Flag', 'l', 'case', null, 'flags'),
  ('bg:f_ace', 'bg', 'f_ace', 'Asexual Flag', 'l', 'case', null, 'flags'),
  ('bg:f_aro', 'bg', 'f_aro', 'Aromantic Flag', 'l', 'case', null, 'flags'),
  ('bg:f_fluid', 'bg', 'f_fluid', 'Genderfluid Flag', 'l', 'case', null, 'flags'),
  ('bg:f_agender', 'bg', 'f_agender', 'Agender Flag', 'l', 'case', null, 'flags'),
  ('bg:f_intersex', 'bg', 'f_intersex', 'Intersex Flag', 'l', 'case', null, 'flags'),
  ('bg:f_usa', 'bg', 'f_usa', 'United States Flag', 'e', 'case', null, 'flags'),
  ('bg:f_mexico', 'bg', 'f_mexico', 'Mexico Flag', 'e', 'case', null, 'flags'),
  ('bg:f_brazil', 'bg', 'f_brazil', 'Brazil Flag', 'e', 'case', null, 'flags'),
  ('bg:f_japan', 'bg', 'f_japan', 'Japan Flag', 'e', 'case', null, 'flags'),
  ('bg:f_skorea', 'bg', 'f_skorea', 'South Korea Flag', 'e', 'case', null, 'flags'),
  ('bg:f_puertorico', 'bg', 'f_puertorico', 'Puerto Rico Flag', 'e', 'case', null, 'flags'),
  ('bg:f_canada', 'bg', 'f_canada', 'Canada Flag', 'r', 'case', null, 'flags'),
  ('bg:f_uk', 'bg', 'f_uk', 'United Kingdom Flag', 'r', 'case', null, 'flags'),
  ('bg:f_germany', 'bg', 'f_germany', 'Germany Flag', 'r', 'case', null, 'flags'),
  ('bg:f_france', 'bg', 'f_france', 'France Flag', 'r', 'case', null, 'flags'),
  ('bg:f_italy', 'bg', 'f_italy', 'Italy Flag', 'r', 'case', null, 'flags'),
  ('bg:f_spain', 'bg', 'f_spain', 'Spain Flag', 'r', 'case', null, 'flags'),
  ('bg:f_ireland', 'bg', 'f_ireland', 'Ireland Flag', 'r', 'case', null, 'flags'),
  ('bg:f_argentina', 'bg', 'f_argentina', 'Argentina Flag', 'r', 'case', null, 'flags'),
  ('bg:f_philippines', 'bg', 'f_philippines', 'Philippines Flag', 'r', 'case', null, 'flags'),
  ('bg:f_india', 'bg', 'f_india', 'India Flag', 'c', 'case', null, 'flags'),
  ('bg:f_israel', 'bg', 'f_israel', 'Israel Flag', 'c', 'case', null, 'flags'),
  ('bg:f_russia', 'bg', 'f_russia', 'Russia Flag', 'c', 'case', null, 'flags'),
  ('bg:f_nkorea', 'bg', 'f_nkorea', 'North Korea Flag', 'c', 'case', null, 'flags')
on conflict (id) do nothing;

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
  -- v0.9.3: milestone counters (map, class) and the Flag Case
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
    -- v0.9.3 milestones: raids held on each map and as each class (the class the player ended the run as)
    if v_held > 0 and v_map in ('yard', 'river', 'quarry') then
      v_st := jsonb_set(v_st, array['map_' || v_map], to_jsonb(coalesce((v_st->>('map_' || v_map))::int, 0) + v_held));
    end if;
    if v_held > 0 and v_cls in ('soldier', 'sniper', 'grenadier', 'quartermaster') then
      v_st := jsonb_set(v_st, array['cls_' || v_cls || '_raids'], to_jsonb(coalesce((v_st->>('cls_' || v_cls || '_raids'))::int, 0) + v_held));
    end if;
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
        -- v0.9.3 milestones: every boss that counts toward the reward also counts toward that boss's outfits
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
  -- v0.9.3: the Flag Case, a chance for everyone after any win (a win already counts once per game)
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
      game_id, raid_from, raid_to, joined_s, left_s, left_early, upgrades, salvage, mods, map, size, shard_bosses, skill_points, cls)
    values (uid, v_kind, case when v_kind = 'run' then v_mode end, nullif(v_pvp, ''), case when v_kind = 'run' then v_diff end,
            v_win, v_held, v_kills, v_dur, granted, v_case, v_bonus, v_shards,
            v_gid, case when v_kind = 'run' then v_from end, case when v_kind = 'run' then v_to end,
            least(greatest(private.num(p->>'joined_s'), 0), 86400)::int, least(greatest(private.num(p->>'left_s'), 0), 86400)::int,
            coalesce(p->>'left' = 'true', false), left(regexp_replace(coalesce(p->>'upgrades', ''), '[^0-9a-z:]', '', 'g'), 16), v_sal,
            v_mods, left(regexp_replace(coalesce(p->>'map', ''), '[^a-z]', '', 'g'), 12), case when v_xl then 'xl' else 'std' end, v_sb, v_sp,
            nullif(v_cls, ''));
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
    -- v0.9.2
    'held', v_held, 'raid_from', v_from, 'mods', to_jsonb(v_mods), 'mod_pct', v_pct, 'shard_bosses', v_sb, 'boss_shards', v_sbshards,
    'skill_points', v_sp, 'sp', l.sp, 'sp_to_next', 5 - l.sp_prog, 'repeat', v_seen,
    'flag_case', v_flag,
    'unlocked', to_jsonb(got), 'locker', private.locker_out(l));
end $function$;
