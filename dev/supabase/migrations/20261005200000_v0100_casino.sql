-- v0.10.0 THE PALISADE FALLS CASINO: Roulette joins the tables; every table belongs to a casino room (you walk up to it);
-- hand history is looked up by player; the daily books check. Like v0.9.8, nothing here is reachable by players directly:
-- service role only. Safe to run twice.

-- 1. Roulette is a game
alter table public.casino_tables drop constraint if exists casino_tables_game_check;
alter table public.casino_tables add constraint casino_tables_game_check check (game in ('bj','he','rl'));

-- 2. one table of each game per casino room: walking up to the blackjack table finds the same table for everyone
alter table public.casino_tables add column if not exists room text;
create unique index if not exists casino_tables_room_game on public.casino_tables(room,game) where open and room is not null;

create or replace function public.casino_open(p_code text,p_game text,p_st jsonb,p_humans uuid[],p_ops jsonb,p_room text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_id bigint;
begin
  insert into public.casino_tables(code,game,st,humans,room) values(p_code,p_game,p_st,p_humans,p_room) returning id into v_id;
  perform private.casino_apply(v_id,p_ops);
  return jsonb_build_object('ok',true,'id',v_id);
exception when unique_violation then return jsonb_build_object('conflict',true);   -- the code was taken, or someone opened this room's table first
end $$;

-- 3. hand history: your hands, newest first
create index if not exists casino_hands_players on public.casino_hands using gin ((result->'players') jsonb_path_ops);
create index if not exists casino_hands_table on public.casino_hands(table_id);

-- 4. the daily books check. For every table that closed that day (Eastern, the bot budget's clock), from v0.10.0 on:
--    shards brought in (buy-ins and top-ups) - shards taken home (cash-outs) must equal the house's take from that table's
--    hands (the poker cut and side-bet costs, blackjack's and roulette's net) plus what players lost to the bot.
--    A table that doesn't balance is listed in bad_tables and the day is marked not ok.
create table if not exists public.casino_books(
  day date primary key,
  tables_closed integer not null default 0,
  shards_in integer not null default 0,
  shards_out integer not null default 0,
  house_bj integer not null default 0,
  house_he integer not null default 0,
  house_rl integer not null default 0,
  bot integer not null default 0,
  bad_tables bigint[] not null default '{}',
  ok boolean not null default true,
  created_at timestamptz not null default now());
alter table public.casino_books enable row level security;
revoke all on public.casino_books from anon,authenticated;

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
  insert into public.casino_books(day,tables_closed,shards_in,shards_out,house_bj,house_he,house_rl,bot,bad_tables,ok)
  select p_day,count(*)::integer,coalesce(sum(s_in),0)::integer,coalesce(sum(s_out),0)::integer,
    coalesce(sum(house) filter (where game='bj'),0)::integer,coalesce(sum(house) filter (where game='he'),0)::integer,
    coalesce(sum(house) filter (where game='rl'),0)::integer,coalesce(sum(bot),0)::integer,
    coalesce(array_agg(id order by id) filter (where s_in-s_out<>house+bot),'{}'),
    coalesce(bool_and(s_in-s_out=house+bot),true)
  from per
  on conflict (day) do nothing;
end $$;

-- called by the edge function on a lobby request: fills in every finished day since the last row (at most 31 at a time)
create or replace function public.casino_books_run() returns integer
language plpgsql security definer set search_path='' as $$
declare v_today date:=(now() at time zone 'America/New_York')::date; v_from date; n integer:=0;
begin
  select coalesce(max(day)+1,v_today-1) into v_from from public.casino_books;
  v_from:=greatest(v_from,v_today-31);
  while v_from<v_today loop perform private.casino_books_day(v_from); v_from:=v_from+1; n:=n+1; end loop;
  return n;
end $$;

revoke all on function public.casino_open(text,text,jsonb,uuid[],jsonb,text) from public,anon,authenticated;
revoke all on function private.casino_books_day(date) from public,anon,authenticated;
revoke all on function public.casino_books_run() from public,anon,authenticated;
grant execute on function public.casino_open(text,text,jsonb,uuid[],jsonb,text) to service_role;
grant execute on function public.casino_books_run() to service_role;
grant select on public.casino_books to service_role;
