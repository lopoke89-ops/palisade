-- v0.11.0 THE PALISADE FALLS CASINO, more games: baccarat, craps, slots and Plinko. Like v0.9.8 and v0.10.0 nothing here
-- is reachable by players directly (service role only). Safe to run twice. The v0.10.0 functions (casino_open and
-- casino_commit) are left in place so the edge function that is live before this deploy keeps working; the v0.11.0 edge
-- function calls casino_start and casino_step instead. No game record is deleted: the only rows ever removed are
-- casino_seats rows, when that player stands up.

-- 1. the games
alter table public.casino_tables drop constraint if exists casino_tables_game_check;
alter table public.casino_tables add constraint casino_tables_game_check check (game in ('bj','he','rl','ba','cr','sl','pk'));

-- 2. stations: one open session per (room, game, station). The tables keep station '' (one each per room, as before);
--    the sixteen slot cabinets are 's1'..'s16' and the Plinko board 'p1', so two cabinets never merge into one session.
alter table public.casino_tables add column if not exists station text not null default '';
create unique index if not exists casino_tables_room_game_station on public.casino_tables(room,game,station) where open and room is not null;
drop index if exists public.casino_tables_room_game;

-- 3. one activity per account, enforced in the same transaction as the move: an account is in casino_seats for exactly
--    one open table (a craps table keeps you there while bets you left behind are still working).
create table if not exists public.casino_seats(
  user_id uuid primary key,
  table_id bigint not null,
  at timestamptz not null default now());
alter table public.casino_seats enable row level security;
revoke all on public.casino_seats from anon,authenticated;
insert into public.casino_seats(user_id,table_id)
  select distinct on (u) u,id from (select unnest(humans) u,id,updated_at from public.casino_tables where open) x order by u,updated_at desc
  on conflict (user_id) do nothing;

-- 4. operation ids: a money move is saved with the id the client chose for it. The same id again is answered from here
--    (no second debit or payout); the same id with a different request is refused by the edge function.
create table if not exists public.casino_ops(
  user_id uuid not null,
  op_id text not null check (op_id ~ '^[A-Za-z0-9_-]{8,64}$'),
  req text not null,
  table_id bigint,
  res jsonb,
  created_at timestamptz not null default now(),
  primary key (user_id,op_id));
alter table public.casino_ops enable row level security;
revoke all on public.casino_ops from anon,authenticated;

-- the seats of one table after a step: who left is removed, who sat is added. Someone already seated at another open table
-- (and still listed there) can't be added: the whole step is undone. Rows left behind by a table that no longer lists that
-- player (a step saved by the v0.10.0 function during the deploy) are cleared first.
create or replace function private.casino_seat_sync(p_table bigint,p_humans uuid[],p_open boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
  delete from public.casino_seats where table_id=p_table and (not p_open or not (user_id=any(coalesce(p_humans,'{}'))));
  if not p_open then return; end if;
  delete from public.casino_seats s using public.casino_tables t
    where s.user_id=any(p_humans) and s.table_id<>p_table and t.id=s.table_id and (not t.open or not (s.user_id=any(t.humans)));
  delete from public.casino_seats s where s.user_id=any(p_humans) and s.table_id<>p_table and not exists(select 1 from public.casino_tables t where t.id=s.table_id);
  insert into public.casino_seats(user_id,table_id) select u,p_table from unnest(p_humans) u on conflict (user_id) do nothing;
  if exists(select 1 from unnest(p_humans) u where not exists(select 1 from public.casino_seats s where s.user_id=u and s.table_id=p_table)) then
    raise exception 'seated elsewhere' using errcode='P0001'; end if;
end $$;

-- record an operation id; a second one with the same id undoes the step that tried it
create or replace function private.casino_op_record(p_table bigint,p_op jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare n integer;
begin
  if p_op is null or jsonb_typeof(p_op)<>'object' then return; end if;
  insert into public.casino_ops(user_id,op_id,req,table_id,res) values((p_op->>'uid')::uuid,p_op->>'id',p_op->>'req',p_table,p_op->'res')
    on conflict (user_id,op_id) do nothing;
  get diagnostics n=row_count;
  if n=0 then raise exception 'duplicate op' using errcode='P0001'; end if;
end $$;

-- open a table or a machine session (the first to sit), with its station and the sitter's operation id
create or replace function public.casino_start(p_code text,p_game text,p_st jsonb,p_humans uuid[],p_ops jsonb,p_room text,p_station text,p_op jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_id bigint;
begin
  begin
    insert into public.casino_tables(code,game,st,humans,room,station) values(p_code,p_game,p_st,p_humans,p_room,coalesce(p_station,'')) returning id into v_id;
  exception when unique_violation then return jsonb_build_object('conflict',true);   -- the code was taken, or someone opened this station first
  end;
  perform private.casino_seat_sync(v_id,p_humans,true);
  perform private.casino_op_record(v_id,p_op);
  perform private.casino_apply(v_id,p_ops);
  return jsonb_build_object('ok',true,'id',v_id);
end $$;

-- save a step: only if nobody else saved since this one was read (ver); then the seats, the operation id, the shard and
-- case moves and the hand log, all or nothing
create or replace function public.casino_step(p_table bigint,p_ver integer,p_st jsonb,p_humans uuid[],p_open boolean,p_ops jsonb,p_hands jsonb,p_op jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  update public.casino_tables set st=p_st,ver=ver+1,humans=p_humans,open=p_open,updated_at=now() where id=p_table and ver=p_ver;
  if not found then return jsonb_build_object('conflict',true); end if;
  perform private.casino_seat_sync(p_table,p_humans,p_open);
  perform private.casino_op_record(p_table,p_op);
  perform private.casino_apply(p_table,p_ops);
  insert into public.casino_hands(table_id,game,hand_no,hash,salt,deck,result,rake,side_hits)
    select p_table,h->>'game',(h->>'no')::integer,h->>'hash',h->>'salt',h->'deck',h->'result',coalesce((h->>'rake')::integer,0),h->'sideHits'
    from jsonb_array_elements(coalesce(p_hands,'[]'::jsonb)) h;
  return jsonb_build_object('ok',true);
end $$;

-- 5. the daily books check covers the new games (one column each); the rule is unchanged: for every table or machine
--    session closed that day, shards brought in - shards taken home = the house's take from its rounds + the bot.
alter table public.casino_books add column if not exists house_ba integer not null default 0;
alter table public.casino_books add column if not exists house_cr integer not null default 0;
alter table public.casino_books add column if not exists house_sl integer not null default 0;
alter table public.casino_books add column if not exists house_pk integer not null default 0;
create or replace function private.casino_books_day(p_day date) returns void
language plpgsql security definer set search_path='' as $$
declare t0 timestamptz:=(p_day::timestamp at time zone 'America/New_York'); t1 timestamptz:=((p_day+1)::timestamp at time zone 'America/New_York');
begin
  with tabs as (
    select t.id,t.game from public.casino_tables t
    where not t.open and t.st->>'fv'='2' and t.updated_at>=t0 and t.updated_at<t1),
  led as (
    select l.table_id,
      -sum(case when l.kind in ('buyin','topup') then l.shards else 0 end)::integer s_in,
      sum(case when l.kind='cashout' then l.shards else 0 end)::integer s_out,
      sum(case when l.kind='bot' then l.shards else 0 end)::integer bot
    from public.casino_ledger l join tabs on tabs.id=l.table_id group by l.table_id),
  hands as (
    select h.table_id,sum(coalesce((h.result->>'house')::integer,0))::integer house
    from public.casino_hands h join tabs on tabs.id=h.table_id group by h.table_id),
  per as (
    select tabs.id,tabs.game,coalesce(led.s_in,0) s_in,coalesce(led.s_out,0) s_out,coalesce(led.bot,0) bot,coalesce(hands.house,0) house
    from tabs left join led on led.table_id=tabs.id left join hands on hands.table_id=tabs.id)
  insert into public.casino_books(day,tables_closed,shards_in,shards_out,house_bj,house_he,house_rl,house_ba,house_cr,house_sl,house_pk,bot,bad_tables,ok)
  select p_day,count(*)::integer,coalesce(sum(s_in),0)::integer,coalesce(sum(s_out),0)::integer,
    coalesce(sum(house) filter (where game='bj'),0)::integer,coalesce(sum(house) filter (where game='he'),0)::integer,
    coalesce(sum(house) filter (where game='rl'),0)::integer,coalesce(sum(house) filter (where game='ba'),0)::integer,
    coalesce(sum(house) filter (where game='cr'),0)::integer,coalesce(sum(house) filter (where game='sl'),0)::integer,
    coalesce(sum(house) filter (where game='pk'),0)::integer,coalesce(sum(bot),0)::integer,
    coalesce(array_agg(id order by id) filter (where s_in-s_out<>house+bot),'{}'),
    coalesce(bool_and(s_in-s_out=house+bot),true)
  from per
  on conflict (day) do nothing;
end $$;

-- 6. hand history looks rows up by id too (the baccarat check fetches its shoe's fingerprints)
create index if not exists casino_ops_table on public.casino_ops(table_id);

revoke all on function private.casino_seat_sync(bigint,uuid[],boolean) from public,anon,authenticated;
revoke all on function private.casino_op_record(bigint,jsonb) from public,anon,authenticated;
revoke all on function public.casino_start(text,text,jsonb,uuid[],jsonb,text,text,jsonb) from public,anon,authenticated;
revoke all on function public.casino_step(bigint,integer,jsonb,uuid[],boolean,jsonb,jsonb,jsonb) from public,anon,authenticated;
revoke all on function private.casino_books_day(date) from public,anon,authenticated;
grant execute on function public.casino_start(text,text,jsonb,uuid[],jsonb,text,text,jsonb) to service_role;
grant execute on function public.casino_step(bigint,integer,jsonb,uuid[],boolean,jsonb,jsonb,jsonb) to service_role;
grant select,insert,update,delete on public.casino_seats to service_role;
grant select,insert on public.casino_ops to service_role;
