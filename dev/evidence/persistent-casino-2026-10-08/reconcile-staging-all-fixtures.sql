-- Read-only rolling reconciliation for isolated nxsqerlpqdzrjwqxhsdz staging.
-- This does not create a premature current-day casino_books row or change balances.
with led as (
 select table_id,
  -sum(shards) filter(where kind in('buyin','topup')) shards_in,
  sum(shards) filter(where kind='cashout') shards_out,
  sum(shards) filter(where kind='bot') bot,
  count(*) filter(where kind='buyin') buyins
 from public.casino_ledger group by table_id
), hands as (
 select table_id,sum(coalesce((result->>'house')::integer,0)) house,count(*) hands
 from public.casino_hands group by table_id
), per as (
 select t.id,t.game,t.open,t.recovery_failures,t.recovery_error,
  coalesce(l.shards_in,0) shards_in,coalesce(l.shards_out,0) shards_out,
  coalesce(l.bot,0) bot,coalesce(h.house,0) house,coalesce(h.hands,0) hands,l.buyins
 from public.casino_tables t left join led l on l.table_id=t.id left join hands h on h.table_id=t.id
), wallets as (
 select p.username,l.shards balance,coalesce(n.net,0) ledger_net,l.shards=5000+coalesce(n.net,0) matches_initial
 from public.profiles p join public.lockers l on l.user_id=p.id
 join auth.users u on u.id=p.id
 left join (select user_id,sum(shards) net from public.casino_ledger where user_id is not null group by user_id) n on n.user_id=p.id
 where u.raw_app_meta_data ? 'casino_staging_fixture'
)
select json_build_object(
 'time',clock_timestamp(),
 'scope','Rolling staging reconciliation; scheduled daily books cover completed previous days',
 'tables',(select json_agg(to_jsonb(p)||jsonb_build_object('ok',shards_in-shards_out=house+bot) order by id) from per p),
 'all_closed',(select bool_and(not open) from per),
 'all_reconcile',(select bool_and(shards_in-shards_out=house+bot) from per),
 'seats',(select count(*) from public.casino_seats),
 'wallets',(select json_agg(to_jsonb(w) order by username) from wallets w),
 'wallets_match',(select bool_and(matches_initial) from wallets),
 'operation_count',(select count(*) from public.casino_ops),
 'ledger_count',(select count(*) from public.casino_ledger),
 'daily_books',(select json_agg(to_jsonb(b) order by day) from public.casino_books b),
 'leases',(select json_agg(json_build_object('name',name,'epoch',epoch,'valid',expires_at>clock_timestamp())) from public.casino_leases)
) as reconciliation;
