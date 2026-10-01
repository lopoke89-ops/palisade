// Disposable Postgres fixture matching the live reward table shapes.
const fs=require('node:fs'),dir=__dirname+'/../supabase/migrations';
const U='11111111-1111-4111-8111-111111111111';
const base=`create role anon;create role authenticated;create schema auth;create schema private;
create table auth.users(id uuid primary key);create table public.profiles(id uuid primary key,banned boolean default false);
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
create table public.case_types(id text primary key,name text,weights jsonb,shard_cost integer,modes text[] default '{}',drop jsonb default '{}',sort integer default 0);
create table public.cosmetics(id text primary key,cat text,key text,name text,rarity char(1),src text,need jsonb,box text references public.case_types(id),catalog_version integer default 0);
create table public.lockers(user_id uuid primary key,owned text[] default array['skin:std'],eq jsonb default '{}',cases integer default 1,shards integer default 0,prog integer default 0,
 st jsonb default '{"pvp":0,"wins":0,"drops":0,"raids":0,"endless":0,"pvpWins":0,"hardWins":0}',imported boolean default false,rev integer default 1,updated_at timestamptz default now(),
 bag jsonb default '{}',play_budget real default 22200,budget_at timestamptz default now(),sp integer default 0,sp_prog integer default 0,sp_total integer default 0,skills jsonb default '{}');
create table public.match_results(id bigint generated always as identity primary key,user_id uuid,kind text,mode text,pvp text,diff text,win boolean default false,held integer default 0,kills integer default 0,
 duration_s integer default 0,cases_granted integer default 0,created_at timestamptz default now(),case_id text,bonus integer default 0,shards integer default 0,game_id text,raid_from integer,raid_to integer,
 joined_s integer,left_s integer,left_early boolean,upgrades text,salvage integer,mods text[],map text,size text,shard_bosses integer default 0,skill_points integer default 0,cls text,boss_n integer);
create table public.player_stats(user_id uuid primary key,raids integer default 0,wins integer default 0,drops integer default 0,best_endless integer default 0,pvp integer default 0,pvp_wins integer default 0,updated_at timestamptz default now());
insert into public.case_types(id,name,weights,shard_cost,modes,drop,sort) values('supply','SUPPLY CASE','{"c":60,"r":27,"e":10,"l":3}',null,'{coop}','{}',0),('afterglow','AFTERGLOW CASE','{"c":53,"r":30,"e":12,"l":4,"g":1}',10,'{base,ffa}','{"ffa":{"win":0.5,"loss":0.2},"base":{"win":0.45,"loss":0.2},"boss":{"each":1}}',1),
 ('halloween','HALLOWEEN CASE','{"c":45}',12,'{}','{}',2),('flags','FLAG CASE','{"c":45}',10,'{}','{"win":0}',3);
insert into public.cosmetics values('skin:std','skin','std','Standard','c','free',null,null,0),('skin:arcade','skin','arcade','Arcade','c','case',null,'afterglow',0);
create function private.require_user() returns uuid language plpgsql stable security definer set search_path='' as $f$declare uid uuid:=auth.uid();begin if uid is null then raise exception 'Sign in first' using errcode='28000';end if;if exists(select 1 from public.profiles where id=uid and banned) then raise exception 'This account is banned' using errcode='42501';end if;return uid;end$f$;
create function private.num(t text) returns numeric language sql immutable set search_path='' as $f$select case when t ~ '^\\s*-?\\d+(\\.\\d+)?\\s*$' then t::numeric end$f$;
create function private.bag_add(b jsonb,k text,n integer) returns jsonb language sql immutable set search_path='' as $f$select jsonb_set(coalesce(b,'{}'),array[k],to_jsonb(greatest(0,coalesce((b->>k)::int,0)+n)))$f$;
create function private.locker_out(l public.lockers) returns jsonb language sql immutable set search_path='' as $f$select to_jsonb(l)-'user_id'$f$;
create function private.check_rev(l public.lockers,p_rev integer) returns void language plpgsql immutable set search_path='' as $f$begin if p_rev is not null and p_rev<>l.rev then raise exception 'stale';end if;end$f$;
create function private.shard_value(r text) returns integer language sql immutable set search_path='' as $f$select case r when 'c' then 1 when 'r' then 3 when 'e' then 8 when 'l' then 20 when 'g' then 40 else 1 end$f$;
create function private.roll_rarity(w jsonb) returns text language plpgsql set search_path='' as $f$declare tot numeric;x numeric;acc numeric:=0;k record;begin select sum(value::numeric) into tot from jsonb_each_text(w);x:=random()*tot;
 for k in select key,value::numeric v from jsonb_each_text(w) order by value::numeric asc loop acc:=acc+k.v;if x<acc then return k.key;end if;end loop;return 'c';end$f$;
create function private.mod_bonus(p_id text,p_pvp text) returns integer language sql immutable set search_path='' as $f$select case when coalesce(p_pvp,'') in ('base','ffa') then null else
 case p_id when 'nopatch' then 10 when 'alone' then 20 when 'firestorm' then 10 when 'adrenaline' then -15 when 'laststand' then 10 when 'elite' then 15 when 'bossrush' then 10 when 'weather' then 10 when 'nightmare' then 15 when 'berserk' then 10 end end$f$;
create function private.clean_mods(p jsonb,p_pvp text) returns text[] language sql immutable set search_path='' as $f$select coalesce(array_agg(distinct m order by m),'{}'::text[]) from (select value as m from jsonb_array_elements_text(case when jsonb_typeof(p)='array' then p else '[]'::jsonb end) limit 30) s where private.mod_bonus(m,p_pvp) is not null$f$;
create function private.apply_unlocks(p_uid uuid) returns text[] language plpgsql security definer set search_path='' as $f$
declare l public.lockers; c record; got text[] := '{}'; ok boolean; k text;
begin select * into l from public.lockers where user_id = p_uid for update;
  for c in select * from public.cosmetics where src = 'unlock' and not (id = any(l.owned)) loop ok := true;
    for k in select jsonb_object_keys(c.need) loop if coalesce((l.st->>k)::int, 0) < (c.need->>k)::int then ok := false; end if; end loop;
    if ok then l.owned := l.owned || c.id; got := got || c.name; end if; end loop;
  if coalesce(array_length(got, 1), 0) > 0 then update public.lockers set owned = l.owned, rev = rev + 1 where user_id = p_uid; end if; return got; end $f$;
create function private.open_case_catalog(p_case text,p_rev integer,p_catalog integer) returns jsonb language plpgsql security definer set search_path='' as $f$begin return null;end$f$;
create function public.open_case_v0935(p_case text,p_rev integer default null) returns jsonb language sql set search_path='' as $f$select private.open_case_catalog(p_case,p_rev,1)$f$;
insert into auth.users values('${U}');insert into public.profiles(id) values('${U}');`;

module.exports={base,U};
