-- October 5: Big U's gift of 750 shards to lopoke89 (lopoke89@gmail.com). APPLIED live on October 5.
-- Idempotent: keyed by a 'system' notification (data.comp = 'gift-750-2026-10-05'); running it again pays nothing.
with who as (
  select p.id uid, p.username::text name from public.profiles p join auth.users u on u.id=p.id
  where p.username::text='lopoke89' and lower(u.email)='lopoke89@gmail.com'
    and not exists (select 1 from public.notifications n where n.user_id=p.id and n.kind='system' and n.data->>'comp'='gift-750-2026-10-05')),
paid as (
  update public.lockers l set shards=l.shards+750, rev=l.rev+1, updated_at=now() from who where l.user_id=who.uid returning l.user_id, l.shards),
noted as (
  insert into public.notifications(user_id,kind,data) select user_id,'system',jsonb_build_object('comp','gift-750-2026-10-05','text','Gift from Big U: 750 shards.') from paid returning user_id)
select who.name, paid.shards from who join paid on paid.user_id=who.uid order by 1;
