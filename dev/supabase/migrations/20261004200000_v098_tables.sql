-- v0.9.8 THE TABLES: Blackjack and Texas Hold'em for shards. The rules run in the `tables` edge function (service role);
-- this file stores the tables, logs every hand and every shard, and applies each step's shard and case moves atomically.
-- Nothing here is reachable by players directly: no policies, and the functions are granted to service_role only.
create table if not exists public.casino_tables(
  id bigint generated always as identity primary key,
  code text not null unique,
  game text not null check (game in ('bj','he')),
  st jsonb not null,
  ver integer not null default 0,
  humans uuid[] not null default '{}',
  open boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now());
create index if not exists casino_tables_open on public.casino_tables(open,updated_at);
create table if not exists public.casino_hands(
  id bigint generated always as identity primary key,
  table_id bigint not null,
  game text not null,
  hand_no integer not null,
  hash text,
  salt text,
  deck jsonb,
  result jsonb,
  rake integer not null default 0,
  side_hits jsonb,
  created_at timestamptz not null default now());
create table if not exists public.casino_ledger(
  id bigint generated always as identity primary key,
  table_id bigint not null,
  user_id uuid,
  kind text not null check (kind in ('buyin','topup','cashout','case','bot')),
  shards integer not null default 0,
  bag text,
  n integer,
  created_at timestamptz not null default now());
create index if not exists casino_ledger_user on public.casino_ledger(user_id,created_at);
create index if not exists casino_ledger_kind on public.casino_ledger(kind,created_at);
alter table public.casino_tables enable row level security;
alter table public.casino_hands enable row level security;
alter table public.casino_ledger enable row level security;
revoke all on public.casino_tables,public.casino_hands,public.casino_ledger from anon,authenticated;

-- one step's moves: buy-ins and top-ups take shards (refused if the balance is short, which undoes the whole step),
-- cash-outs return them, a side-bet prize adds cases to the bag, the bot's result is the house's
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
    elsif o->>'k'<>'bot' then raise exception 'bad op';
    end if;
    insert into public.casino_ledger(table_id,user_id,kind,shards,bag,n)
      values(p_table,case when o->>'k'='bot' then null else (o->>'uid')::uuid end,o->>'k',d,o->>'bag',(o->>'n')::integer);
  end loop;
end $$;

create or replace function public.casino_open(p_code text,p_game text,p_st jsonb,p_humans uuid[],p_ops jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_id bigint;
begin
  insert into public.casino_tables(code,game,st,humans) values(p_code,p_game,p_st,p_humans) returning id into v_id;
  perform private.casino_apply(v_id,p_ops);
  return jsonb_build_object('ok',true,'id',v_id);
exception when unique_violation then return jsonb_build_object('conflict',true);
end $$;

-- save a step: only if nobody else saved since this one was read (ver), then apply its moves and log its hands
create or replace function public.casino_commit(p_table bigint,p_ver integer,p_st jsonb,p_humans uuid[],p_open boolean,p_ops jsonb,p_hands jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  update public.casino_tables set st=p_st,ver=ver+1,humans=p_humans,open=p_open,updated_at=now() where id=p_table and ver=p_ver;
  if not found then return jsonb_build_object('conflict',true); end if;
  perform private.casino_apply(p_table,p_ops);
  insert into public.casino_hands(table_id,game,hand_no,hash,salt,deck,result,rake,side_hits)
    select p_table,h->>'game',(h->>'no')::integer,h->>'hash',h->>'salt',h->'deck',h->'result',coalesce((h->>'rake')::integer,0),h->'sideHits'
    from jsonb_array_elements(coalesce(p_hands,'[]'::jsonb)) h;
  return jsonb_build_object('ok',true);
end $$;

-- what the bot may still lose today (Eastern): 25 shards a day across every table
create or replace function public.casino_bot_left() returns integer
language sql stable security definer set search_path='' as $$
  select greatest(0,25+coalesce(sum(shards),0))::integer from public.casino_ledger
  where kind='bot' and created_at>=(date_trunc('day',now() at time zone 'America/New_York') at time zone 'America/New_York') $$;

revoke all on function private.casino_apply(bigint,jsonb) from public,anon,authenticated;
revoke all on function public.casino_open(text,text,jsonb,uuid[],jsonb) from public,anon,authenticated;
revoke all on function public.casino_commit(bigint,integer,jsonb,uuid[],boolean,jsonb,jsonb) from public,anon,authenticated;
revoke all on function public.casino_bot_left() from public,anon,authenticated;
grant execute on function public.casino_open(text,text,jsonb,uuid[],jsonb) to service_role;
grant execute on function public.casino_commit(bigint,integer,jsonb,uuid[],boolean,jsonb,jsonb) to service_role;
grant execute on function public.casino_bot_left() to service_role;
grant select,insert,update on public.casino_tables,public.casino_hands,public.casino_ledger to service_role;
