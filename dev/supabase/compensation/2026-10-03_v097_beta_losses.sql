-- v0.9.7 beta: today's (2026-10-03, Eastern) lost runs paid as full wins. APPLIED to the live project on 2026-10-03 with Big U's approval;
-- including the Destroyer and the ladder", all of today's losses, run once.
-- Idempotent: each grant is keyed by a 'system' notification (data.comp); running this again pays nothing extra.
-- Amounts per game = a full win minus what that player's claims for that game already paid (never negative):
--   City Black Out full win: 8 Supply Cases (2 progress + 4 majors + 2 win), 75 shards (10 salvage + 25 win + 40 Destroyer),
--     2 skill points, 1 Hybrid Theory Case; ladder: points up to 8, +1 win, +1 perfect, +1 Destroyer; raids up to 9.
--   Operation Whiteout full win (lopoke89, lost at raid 6 of 13): 6 Supply, 16 Winter (5 chapter bosses, 6 gauntlet waves,
--     2 final evac, 3 chapter evacs), 170 shards (10 salvage + 18 gauntlet bosses at 7.5 + 25 evac), 24 skill points,
--     1 Hybrid Theory Case; raids 7-13 (Quarry 3, Frostpeak 4).
-- Per player (all games summed):
--   lopoke89      3 Black Out + 1 campaign: 16 Supply, 13 Winter, 4 Hybrid, 362 shards, 24 SP
--   rab           2 Black Out: 9 Supply, 2 Hybrid, 136 shards, 2 SP
--   meezy2greezy  1 Black Out: 3 Supply, 1 Hybrid, 65 shards
begin;
create temporary table comp(key text primary key, uid uuid, supply int, winter int, hybrid int, shards int, sp int, wins int, raids int,
  st jsonb, note text) on commit drop;
insert into comp values
 ('v097-beta-losses-3dfe90a6', '3dfe90a6-0e93-4991-9342-8804f19ad60a', 16, 13, 4, 362, 24, 4, 17,
  '{"cls_soldier_raids":9,"cls_sniper_raids":8,"map_quarry":3,"map_frost":4,"bo_pois":9,"bo_wins":3,"bo_perfect":3,"bo_dest":3}',
  'Beta thank-you: today''s lost runs are paid as full wins. 3 City Black Out runs and your campaign run: 16 Supply Cases, 13 Winter Cases, 4 Hybrid Theory Cases, 362 shards, 24 skill points, and the BLACK OUT ladder progress for a perfect win with the Destroyer down.'),
 ('v097-beta-losses-79bab67e', '79bab67e-3404-4321-b01b-7d9146d104c9', 9, 0, 2, 136, 2, 2, 9,
  '{"cls_soldier_raids":9,"bo_pois":7,"bo_wins":2,"bo_perfect":2,"bo_dest":2}',
  'Beta thank-you: today''s lost runs are paid as full wins. 2 City Black Out runs: 9 Supply Cases, 2 Hybrid Theory Cases, 136 shards, 2 skill points, and the BLACK OUT ladder progress for a perfect win with the Destroyer down.'),
 ('v097-beta-losses-589a4a9a', '589a4a9a-d172-4038-b497-d17877cb5570', 3, 0, 1, 65, 0, 1, 1,
  '{"cls_quartermaster_raids":1,"bo_pois":2,"bo_wins":1,"bo_perfect":1,"bo_dest":1}',
  'Beta thank-you: today''s lost run is paid as a full win. Your City Black Out run: 3 Supply Cases, 1 Hybrid Theory Case, 65 shards, and the BLACK OUT ladder progress for a perfect win with the Destroyer down.');
do $$ declare c record; begin
  for c in select * from pg_temp.comp x where not exists (select 1 from public.notifications n where n.user_id = x.uid and n.kind = 'system' and n.data->>'comp' = x.key) order by key loop
    update public.lockers l set
      cases = l.cases + c.supply,
      bag = private.bag_add(private.bag_add(l.bag, 'winter', c.winter), 'hybrid', c.hybrid),
      shards = l.shards + c.shards,
      sp = l.sp + c.sp, sp_total = l.sp_total + c.sp,
      st = jsonb_set(jsonb_set(l.st, '{raids}', to_jsonb(coalesce((l.st->>'raids')::int, 0) + c.raids)), '{wins}', to_jsonb(coalesce((l.st->>'wins')::int, 0) + c.wins))
           || (select jsonb_object_agg(s.key, coalesce((l.st->>s.key)::int, 0) + s.value::int) from jsonb_each_text(c.st) s),
      rev = l.rev + 1, updated_at = now()
    where l.user_id = c.uid;
    update public.player_stats s set raids = s.raids + c.raids, wins = s.wins + c.wins, updated_at = now() where s.user_id = c.uid;
    insert into public.notifications(user_id, kind, data) values (c.uid, 'system', jsonb_build_object('comp', c.key, 'text', c.note));
    perform private.apply_unlocks(c.uid);
  end loop;
end $$;
commit;
