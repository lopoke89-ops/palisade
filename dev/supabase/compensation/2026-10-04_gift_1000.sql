-- October 4: Big U's gift of 1,000 shards each to killkemo, kappinkirk and lopoke89. APPLIED live on October 4.
-- Idempotent: keyed by a 'system' notification (data.comp = 'gift-1000-2026-10-04'); running it again pays nothing.
with who as (
  select p.id uid, p.username::text name from public.profiles p where p.username::text in ('killkemo','kappinkirk','lopoke89')
    and not exists (select 1 from public.notifications n where n.user_id=p.id and n.kind='system' and n.data->>'comp'='gift-1000-2026-10-04')),
paid as (
  update public.lockers l set shards=l.shards+1000, rev=l.rev+1, updated_at=now() from who where l.user_id=who.uid returning l.user_id, l.shards),
noted as (
  insert into public.notifications(user_id,kind,data) select user_id,'system',jsonb_build_object('comp','gift-1000-2026-10-04','text','Gift from Big U: 1,000 shards.') from paid returning user_id)
select who.name, paid.shards from who join paid on paid.user_id=who.uid order by 1;
