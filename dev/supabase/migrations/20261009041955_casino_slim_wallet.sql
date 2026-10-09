-- SLIM's persistent casino wallet. Settled non-poker house results are signed: player wins
-- subtract from funding. Buy-ins, pending bets, case prizes and account rewards are not profit.
-- One wallet, one active poker table, no daily grant. Existing allowance bots can finish
-- but cannot return their minted principal to this wallet. Safe to apply again.
lock table public.casino_hands in share row exclusive mode;

create table if not exists private.casino_bot_wallet(
  singleton boolean primary key default true check (singleton),
  balance integer not null default 0,
  active_table bigint references public.casino_tables(id),
  fund_poker boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now());
create table if not exists private.casino_bot_funding(
  hand_id bigint primary key references public.casino_hands(id),
  shards integer not null,
  backfilled boolean not null default false,
  created_at timestamptz not null default now());
alter table private.casino_bot_wallet enable row level security;
alter table private.casino_bot_funding enable row level security;
revoke all on private.casino_bot_wallet,private.casino_bot_funding from public,anon,authenticated,service_role;
insert into private.casino_bot_wallet(singleton) values(true) on conflict do nothing;

-- Receipt per historical round: all recorded non-poker play began within the last few days.
-- Re-running this migration credits only rows that have not already funded the wallet.
with credited as (
  insert into private.casino_bot_funding(hand_id,shards,backfilled)
  select id,coalesce((result->>'house')::integer,0),true from public.casino_hands where game<>'he'
  on conflict (hand_id) do nothing returning shards)
update private.casino_bot_wallet set balance=balance+coalesce((select sum(shards) from credited),0),updated_at=now() where singleton;

create or replace function private.casino_bot_fund_round() returns trigger
language plpgsql security definer set search_path='' as $$
declare n integer; d integer;
begin
  if new.game='he' and not (select fund_poker from private.casino_bot_wallet where singleton) then return new; end if;
  d:=coalesce((new.result->>'house')::integer,0);
  insert into private.casino_bot_funding(hand_id,shards) values(new.id,d) on conflict (hand_id) do nothing;
  get diagnostics n=row_count;
  if n>0 then update private.casino_bot_wallet set balance=balance+d,updated_at=now() where singleton; end if;
  return new;
end $$;
drop trigger if exists casino_bot_fund_round on public.casino_hands;
create trigger casino_bot_fund_round after insert on public.casino_hands for each row execute function private.casino_bot_fund_round();

-- A negative balance carries the house's losses forward instead of manufacturing shards.
-- While SLIM is seated, new funding waits in the wallet until he stands up and next joins.
create or replace function public.casino_bot_balance() returns integer
language sql stable security definer set search_path='' as $$
  select case when active_table is null and not exists (
    select 1 from public.casino_tables t,jsonb_array_elements(t.st->'seats') s
    where t.open and s->>'bot'='true' and coalesce(s->>'walletBot','false')<>'true'
  ) then greatest(0,balance) else 0 end
  from private.casino_bot_wallet where singleton $$;
-- Disable allowance-based joins from old server instances during the rollout.
create or replace function public.casino_bot_left() returns integer
language sql stable security definer set search_path='' as $$ select 0 $$;

alter table public.casino_ledger drop constraint if exists casino_ledger_kind_check;
alter table public.casino_ledger add constraint casino_ledger_kind_check check (kind in ('buyin','topup','cashout','case','bot','bot_buyin','bot_cashout'));

create or replace function private.casino_apply(p_table bigint,p_ops jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare o jsonb; n integer; d integer;
begin
  for o in select * from jsonb_array_elements(coalesce(p_ops,'[]'::jsonb)) loop
    d:=coalesce((o->>'d')::integer,0);
    if o->>'k' in ('buyin','topup','cashout') then
      update public.lockers set shards=shards+d,rev=rev+1,updated_at=now() where user_id=(o->>'uid')::uuid and shards+d>=0;
      get diagnostics n=row_count;
      if n=0 then raise exception 'insufficient shards' using errcode='P0001'; end if;
    elsif o->>'k'='case' then
      if (o->>'bag') not in ('hybrid','flags') or (o->>'n')::integer not in (10,15) then raise exception 'bad prize'; end if;
      update public.lockers set bag=private.bag_add(bag,o->>'bag',(o->>'n')::integer),rev=rev+1,updated_at=now() where user_id=(o->>'uid')::uuid;
    elsif o->>'k'='bot_buyin' then
      if d > -2 or not exists (
        select 1 from public.casino_tables t,jsonb_array_elements(t.st->'seats') s
        where t.id=p_table and t.open and t.game='he' and s->>'walletBot'='true' and s->>'bot'='true' and (s->>'brought')::integer=-d
      ) then raise exception 'bad bot buyin'; end if;
      -- The equality requires the entire current balance. A racing funding/cash-out or
      -- another table's reservation makes this step retry from fresh state, all or nothing.
      update private.casino_bot_wallet set balance=balance+d,active_table=p_table,updated_at=now()
        where singleton and active_table is null and balance=-d;
      get diagnostics n=row_count;
      if n=0 then raise exception 'bot wallet changed' using errcode='P0001'; end if;
    elsif o->>'k'='bot_cashout' then
      if d<0 or exists (
        select 1 from public.casino_tables t,jsonb_array_elements(t.st->'seats') s
        where t.id=p_table and s->>'walletBot'='true' and s->>'bot'='true'
      ) then raise exception 'bad bot cashout'; end if;
      update private.casino_bot_wallet set balance=balance+d,active_table=null,updated_at=now()
        where singleton and active_table=p_table;
      get diagnostics n=row_count;
      if n=0 then raise exception 'bad bot reservation'; end if;
    elsif o->>'k'<>'bot' then raise exception 'bad op';
    end if;
    insert into public.casino_ledger(table_id,user_id,kind,shards,bag,n)
      values(p_table,case when o->>'k' in ('bot','bot_buyin','bot_cashout') then null else (o->>'uid')::uuid end,o->>'k',d,o->>'bag',(o->>'n')::integer);
  end loop;
end $$;

revoke all on function private.casino_bot_fund_round() from public,anon,authenticated,service_role;
revoke all on function private.casino_apply(bigint,jsonb) from public,anon,authenticated;
revoke all on function public.casino_bot_balance() from public,anon,authenticated;
revoke all on function public.casino_bot_left() from public,anon,authenticated;
grant execute on function public.casino_bot_balance() to service_role;
grant execute on function public.casino_bot_left() to service_role;
