-- v0.9.7 City Black Out: the new mode in claims, rooms and lobbies, its ladder (catalog 5), and two result columns.
-- Built from the live function text: claim_match_reward and room_register are read with pg_get_functiondef and patched
-- with anchored replacements (each anchor must match exactly once, or the whole migration stops). Safe to run twice.
--
-- Black Out claims (cv:5) count the run as 9 stages: 8 POI attacks plus the final push. raid_to is how many stages were
-- finished (9 = the run was won), so the existing join/rejoin windows and repeat checks apply unchanged.
--   pois_held   POIs held in this claim's stages (at most 8, the stages credited, and one per 30 s after the gathering)
--   pois_major  majors among them (at most 4): +1 Supply Case each
--   destroyer   the Supreme Destroyer went down (only counts on a win): +40 shards and +1 skill point
-- Supply Case progress counts POIs held (not stages). A win pays 2 Supply Cases and 25 shards and needs at least 7 minutes.
-- POI bosses pay no boss cases. Ladder counters: bo_pois, bo_wins, bo_dest, bo_perfect (a win holding all 8).

alter table public.match_results add column if not exists pois_held int, add column if not exists destroyer boolean;

alter table public.lobbies drop constraint if exists lobbies_length_check;
alter table public.lobbies add constraint lobbies_length_check check (length in ('5','10','endless','blitz','campaign','blackout'));

create or replace function pg_temp.sub1(d text, a text, b text) returns text language plpgsql as $f$
begin
  if position(a in d) = 0 or (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then
    raise exception 'v0.9.7 migration: anchor not found exactly once: %', left(a, 80);
  end if;
  return replace(d, a, b);
end $f$;

do $mig$
declare d text;
begin
  d := pg_get_functiondef('public.claim_match_reward(jsonb)'::regprocedure);
  if position('v_bo boolean' in d) = 0 then
    d := pg_temp.sub1(d, $a$v_ce jsonb := p->'ch_evac';$a$,
      $b$v_ce jsonb := p->'ch_evac';
  -- v0.9.7 City Black Out (cv:5)
  v_bo boolean := coalesce(p->>'mode', '') = 'blackout' and p->>'kind' = 'run'; v_pois int := 0; v_major int := 0; v_dest boolean := false;$b$);
    d := pg_temp.sub1(d, $a$if v_mode not in ('5', '10', 'endless', 'blitz','campaign') or$a$,
      $b$if v_mode not in ('5', '10', 'endless', 'blitz','campaign','blackout') or (v_mode = 'blackout' and v_cv < 5) or$b$);
    d := pg_temp.sub1(d, $a$when 'campaign' then 13 else 0 end;$a$, $b$when 'campaign' then 13 when 'blackout' then 9 else 0 end;$b$);
    d := pg_temp.sub1(d, $a$    v_held := v_to - v_from;
$a$, $b$    v_held := v_to - v_from;
    if v_bo then   -- v0.9.7: POIs held can't pass 8, the stages credited, or one per 30 s after the 45 s gathering
      v_pois := least(greatest(coalesce(private.num(p->>'pois_held'), 0), 0)::int, 8, v_held, greatest(0, 1 + (v_dur - 45) / 30));
      v_major := least(greatest(coalesce(private.num(p->>'pois_major'), 0), 0)::int, 4, v_pois);
      if v_dur < 420 then v_win := false; end if;
    end if;
$b$);
    d := pg_temp.sub1(d, $a$    v_credit := floor(v_held * (100 + v_pct) / 100.0)::int;$a$,
      $b$    if v_bo then   -- v0.9.7: the BLACK OUT ladder's counters, the win's shards and the Destroyer's
      v_dest := coalesce(p->>'destroyer', '') = 'true' and v_win;
      v_st := jsonb_set(v_st, '{bo_pois}', to_jsonb(coalesce((v_st->>'bo_pois')::int, 0) + v_pois));
      if v_win then
        v_st := jsonb_set(v_st, '{bo_wins}', to_jsonb(coalesce((v_st->>'bo_wins')::int, 0) + 1));
        if v_pois >= 8 then v_st := jsonb_set(v_st, '{bo_perfect}', to_jsonb(coalesce((v_st->>'bo_perfect')::int, 0) + 1)); end if;
        v_fbshards := v_fbshards + 25;
      end if;
      if v_dest then v_st := jsonb_set(v_st, '{bo_dest}', to_jsonb(coalesce((v_st->>'bo_dest')::int, 0) + 1)); v_fbshards := v_fbshards + 40; end if;
    end if;
    v_credit := floor((case when v_bo then v_pois else v_held end) * (100 + v_pct) / 100.0)::int;$b$);
    d := pg_temp.sub1(d, $a$earned := v_prog / 3 + case when v_win then (case when waves >= 10 then 2 else 1 end) else 0 end + case when waves = 0 then v_held / 5 else 0 end;$a$,
      $b$earned := v_prog / 3 + case when v_win then (case when waves >= 10 or v_bo then 2 else 1 end) else 0 end + case when waves = 0 then v_held / 5 else 0 end + v_major;$b$);
    d := pg_temp.sub1(d, $a$v_cap := greatest(0, v_cap - v_pbn);$a$, $b$v_cap := greatest(0, v_cap - v_pbn); if v_bo then v_cap := 0; end if;   -- v0.9.7: POI bosses pay no boss cases$b$);
    d := pg_temp.sub1(d, $a$    v_sp := v_spprog / 5 + v_n + v_sb + v_fbn;$a$, $b$    v_sp := v_spprog / 5 + v_n + v_sb + v_fbn + case when v_dest then 1 else 0 end;$b$);
    d := pg_temp.sub1(d, $a$boss_n, fb_n, evac)$a$, $b$boss_n, fb_n, evac, pois_held, destroyer)$b$);
    d := pg_temp.sub1(d, $a$v_fbn, nullif(v_evac, ''));$a$, $b$v_fbn, nullif(v_evac, ''), case when v_bo then v_pois end, case when v_bo then v_dest end);$b$);
    d := pg_temp.sub1(d, $a$'gauntlet_waves', v_gw,$a$, $b$'gauntlet_waves', v_gw, 'pois_held', v_pois, 'pois_major', v_major, 'destroyer', v_dest,$b$);
    execute d;
  end if;
  d := pg_get_functiondef('public.room_register(jsonb)'::regprocedure);
  if position($a$'campaign','blackout'$a$ in d) = 0 then
    d := pg_temp.sub1(d, $a$not in ('yard','river','quarry','frost')$a$, $b$not in ('yard','river','quarry','frost','city')$b$);
    d := pg_temp.sub1(d, $a$not in ('5','10','endless','blitz','campaign')$a$, $b$not in ('5','10','endless','blitz','campaign','blackout')$b$);
    execute d;
  end if;
end $mig$;

-- the BLACK OUT ladder (catalog 5): each step has its own counter
insert into public.cosmetics (id, cat, key, name, rarity, src, need, box, catalog_version) values
  ('skin:nightshift', 'skin', 'nightshift', 'Night Shift', 'r', 'unlock', '{"bo_pois":10}', null, 5),
  ('hat:blackout', 'hat', 'blackout', 'Blackout Helmet', 'e', 'unlock', '{"bo_wins":1}', null, 5),
  ('trail:streetlight', 'trail', 'streetlight', 'Streetlight', 'e', 'unlock', '{"bo_pois":50}', null, 5),
  ('fx:orbital', 'fx', 'orbital', 'Orbital Strike', 'l', 'unlock', '{"bo_dest":1}', null, 5),
  ('bg:skyline', 'bg', 'skyline', 'Lit Skyline', 'l', 'unlock', '{"bo_perfect":1}', null, 5),
  ('skin:gnightshift', 'skin', 'gnightshift', 'Gold Night Shift', 'g', 'unlock', '{"bo_dest":10}', null, 5)
on conflict (id) do update set cat = excluded.cat, key = excluded.key, name = excluded.name, rarity = excluded.rarity, src = excluded.src,
  need = excluded.need, box = excluded.box, catalog_version = excluded.catalog_version;
