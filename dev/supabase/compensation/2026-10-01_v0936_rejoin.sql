-- v0.9.3.6 rejoin compensation. NOT APPLIED. Run only after Big U approves the table in dev/STATUS.md.
-- Idempotent: each grant is keyed by a 'system' notification (data.comp); running this twice pays nothing extra.
-- Basis: read-only audit of the 15 most recent games (2026-09-30). Amounts are "what a teammate who stayed the
-- whole game was paid, minus what this player was paid", with in-between bosses at 23 shards (the 15-30 midpoint).
begin;
create temporary table comp(key text primary key, uid uuid, supply int, halloween int, shards int, sp int,
  raids int, map text, map_n int, cls text, bosses jsonb, note text) on commit drop;
insert into comp values
 ('v0936-rejoin-munif0e3', '8d9722ad-313f-4ec1-b389-03bc66c10414', 10, 4, 138, 13, 14, 'river', 14, 'soldier',
  '{"ferryman":2,"butcher":2}', 'Compensation for your Endless run on Riverbend (raids 1-14 were lost when you dropped and rejoined): 10 Supply Cases, 4 Halloween Cases, 138 shards, 13 skill points.'),
 ('v0936-rejoin-mulw1qg2', '8d9722ad-313f-4ec1-b389-03bc66c10414', 3, 2, 69, 6, 6, 'river', 6, 'soldier',
  '{"ferryman":2}', 'Compensation for your 10-raid run on Riverbend (raids 1-6 were lost when you dropped and rejoined): 3 Supply Cases, 2 Halloween Cases, 69 shards, 6 skill points.'),
 ('v0936-rejoin-mulv3e8h', '589a4a9a-d172-4038-b497-d17877cb5570', 1, 0, 0, 0, 1, 'yard', 1, 'quartermaster',
  '{}', 'Compensation for the raid you missed while reconnecting on The Yard: 1 Supply Case and 1 raid.');
-- skip anything already granted
delete from comp c using public.notifications n where n.user_id = c.uid and n.kind = 'system' and n.data->>'comp' = c.key;
do $$ declare c record; begin
  for c in select * from pg_temp.comp order by key loop
    update public.lockers l set
      cases = l.cases + c.supply,
      bag = private.bag_add(l.bag, 'halloween', c.halloween),
      shards = l.shards + c.shards,
      sp = l.sp + c.sp, sp_total = l.sp_total + c.sp,
      st = jsonb_set(jsonb_set(jsonb_set(l.st, '{raids}', to_jsonb(coalesce((l.st->>'raids')::int,0) + c.raids)),
             array['map_'||c.map], to_jsonb(coalesce((l.st->>('map_'||c.map))::int,0) + c.map_n)),
             array['cls_'||c.cls||'_raids'], to_jsonb(coalesce((l.st->>('cls_'||c.cls||'_raids'))::int,0) + c.raids))
           || coalesce((select jsonb_object_agg('boss_'||b.key, coalesce((l.st->>('boss_'||b.key))::int,0) + b.value::int) from jsonb_each_text(c.bosses) b), '{}'::jsonb),
      rev = l.rev + 1, updated_at = now()
    where l.user_id = c.uid;
    update public.player_stats s set raids = s.raids + c.raids, updated_at = now() where s.user_id = c.uid;
  end loop;
end $$;
insert into public.notifications(user_id, kind, data) select uid, 'system', jsonb_build_object('comp', key, 'text', note) from comp;
select private.apply_unlocks(uid) from (select distinct uid from comp) u;
select key, uid from comp;   -- what this run granted (empty on a repeat)
commit;
