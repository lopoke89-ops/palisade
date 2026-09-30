-- v0.9.3.8 estimated backfill: in-between boss kills (Boss Rush, Nightmare surprise) before migration 20260930075446
-- earned no boss milestone credit. Approved by Big U on 2026-09-30 and applied then.
-- Estimate: each pre-migration claim's paid in-between bosses; Boss Rush raids in the claim's window matched to the
-- map's fixed rotation L[(raid/2)%3]; the remainder (Nightmare surprises) spread over the map's three bosses in turn.
-- Idempotent: keyed by a 'system' notification with data.comp = 'v0938-milestone-backfill' per player.
begin;
create temporary table bf(uid uuid, boss text, n int) on commit drop;
insert into bf values
 ('af519126-d11d-4649-9b1f-a1c571f5ff4e','demolisher',1),('af519126-d11d-4649-9b1f-a1c571f5ff4e','storm',1),
 ('6b32a70d-41dc-4fa8-83ae-e13da2b37643','butcher',4),('6b32a70d-41dc-4fa8-83ae-e13da2b37643','demolisher',6),('6b32a70d-41dc-4fa8-83ae-e13da2b37643','ferryman',1),
 ('6b32a70d-41dc-4fa8-83ae-e13da2b37643','foreman',3),('6b32a70d-41dc-4fa8-83ae-e13da2b37643','storm',6),
 ('8d9722ad-313f-4ec1-b389-03bc66c10414','butcher',13),('8d9722ad-313f-4ec1-b389-03bc66c10414','demolisher',4),('8d9722ad-313f-4ec1-b389-03bc66c10414','ferryman',9),
 ('8d9722ad-313f-4ec1-b389-03bc66c10414','storm',13),
 ('3dfe90a6-0e93-4991-9342-8804f19ad60a','butcher',21),('3dfe90a6-0e93-4991-9342-8804f19ad60a','demolisher',13),('3dfe90a6-0e93-4991-9342-8804f19ad60a','ferryman',13),
 ('3dfe90a6-0e93-4991-9342-8804f19ad60a','foreman',3),('3dfe90a6-0e93-4991-9342-8804f19ad60a','storm',23),
 ('589a4a9a-d172-4038-b497-d17877cb5570','butcher',7),('589a4a9a-d172-4038-b497-d17877cb5570','demolisher',2),('589a4a9a-d172-4038-b497-d17877cb5570','ferryman',5),
 ('589a4a9a-d172-4038-b497-d17877cb5570','storm',6);
delete from bf b using public.notifications n where n.user_id = b.uid and n.kind = 'system' and n.data->>'comp' = 'v0938-milestone-backfill';
do $$ declare r record; begin
  for r in select * from pg_temp.bf order by uid, boss loop
    update public.lockers l set st = jsonb_set(l.st, array['boss_'||r.boss], to_jsonb(coalesce((l.st->>('boss_'||r.boss))::int,0) + r.n)),
      rev = l.rev + 1, updated_at = now() where l.user_id = r.uid;
  end loop;
end $$;
insert into public.notifications(user_id, kind, data)
 select uid, 'system', jsonb_build_object('comp','v0938-milestone-backfill','text',
   'Boss Rush and Nightmare boss kills now count toward boss milestones. Your past ones were added: '||string_agg(n||' '||initcap(case boss when 'storm' then 'stormcaller' else boss end), ', ' order by boss)||'.')
 from bf group by uid;
select uid, private.apply_unlocks(uid) from (select distinct uid from bf) u;
commit;
