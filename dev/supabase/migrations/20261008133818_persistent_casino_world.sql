-- Persistent casino v1. Additive storage; existing legacy rooms and ledger stay intact.
create table public.casino_world_config(id boolean primary key default true check(id),revision int not null default 1,allowlist uuid[] not null default '{}',
 admissions boolean not null default false,new_wagers boolean not null default false,recovery boolean not null default true);
insert into public.casino_world_config(id) values(true);
create table public.casino_rooms(id uuid primary key default gen_random_uuid(),code text unique not null check(code ~ '^[A-Z2-9]{6}$'),
 ordinal int unique not null check(ordinal between 0 and 9),capacity int not null default 6 check(capacity between 1 and 6),enabled boolean not null default true);
insert into public.casino_rooms(code,ordinal) values('PALACE',0),('CASAAA',1),('CASAAB',2),('CASAAC',3),('CASAAD',4),('CASAAE',5),('CASAAF',6),('CASAAG',7),('CASAAH',8),('CASAAJ',9);
create table public.casino_leases(name text primary key,owner uuid,epoch bigint not null default 0,expires_at timestamptz not null default '-infinity');
insert into public.casino_leases(name) values('world'),('worker');
create table public.casino_controllers(user_id uuid primary key,session uuid not null,generation bigint not null default 1,
 room_id uuid references public.casino_rooms(id),expires_at timestamptz not null,recovery_only boolean not null default false);
create table public.casino_members(user_id uuid primary key references public.casino_controllers(user_id),room_id uuid not null references public.casino_rooms(id),
 generation bigint not null,owner_epoch bigint not null,expires_at timestamptz not null);
create index casino_members_room on public.casino_members(room_id,expires_at);
create table public.casino_reservations(id uuid primary key default gen_random_uuid(),user_id uuid not null,room_id uuid not null references public.casino_rooms(id),
 game text not null,station text not null,seat int not null,generation bigint not null,owner_epoch bigint not null,expires_at timestamptz not null,consumed boolean not null default false);
create unique index casino_reservation_tuple on public.casino_reservations(room_id,game,station,seat) where not consumed;
create index casino_reservation_user on public.casino_reservations(user_id);
create table public.casino_positions(user_id uuid primary key,room_id uuid not null references public.casino_rooms(id),x real not null,y real not null,layout int not null default 1,updated_at timestamptz not null default now());
alter table public.casino_tables add column next_due_at timestamptz;
alter table public.casino_tables add column recovery_failures int not null default 0;
alter table public.casino_tables add column recovery_error text;
create index casino_due on public.casino_tables(next_due_at,id) where open;
alter table private.lobby_invites add column managed_room uuid references public.casino_rooms(id);

-- All lease comparisons use database time, including a healthy standby and fenced writes.
create function private.casino_lease_check(p_name text,p_owner uuid,p_epoch bigint) returns void language plpgsql set search_path='' as $$
begin
 perform 1 from public.casino_leases where name=p_name and owner=p_owner and epoch=p_epoch and expires_at>clock_timestamp() for share;
 if not found then raise exception 'Casino lease expired';end if;
end $$;
create function private.casino_controller_check(p_uid uuid,p_session uuid,p_generation bigint) returns public.casino_controllers language plpgsql set search_path='' as $$
declare c public.casino_controllers;
begin
 select * into c from public.casino_controllers where user_id=p_uid for update;
 if not found or c.session is distinct from p_session or c.generation is distinct from p_generation or c.expires_at<=clock_timestamp() then raise exception 'Controller revoked. Reconnect or take over';end if;
 if exists(select 1 from public.profiles where id=p_uid and banned) then raise exception 'Account unavailable';end if;
 return c;
end $$;
create function public.casino_world(p jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare a text:=p->>'action';uid uuid:=(p->>'uid')::uuid;sess uuid:=(p->>'session')::uuid;own uuid:=(p->>'owner')::uuid;
 ep bigint:=(p->>'epoch')::bigint;gen bigint:=(p->>'generation')::bigint;r public.casino_rooms;c public.casino_controllers;l public.casino_leases;
 res public.casino_reservations;n int;t jsonb;now0 timestamptz:=clock_timestamp();
begin
 if a='lease' then
  select * into l from public.casino_leases where name=p->>'name' for update;
  if not found then raise exception 'Unknown lease';end if;
  if l.expires_at>now0 and l.owner is distinct from own then return jsonb_build_object('standby',true);end if;
  update public.casino_leases set owner=own,epoch=case when owner is distinct from own or expires_at<=now0 then epoch+1 else epoch end,
   expires_at=now0+interval '15 seconds' where name=l.name returning * into l;
  return jsonb_build_object('epoch',l.epoch,'until',l.expires_at,'now',extract(epoch from now0)*1000);
 elsif a='release' then
  update public.casino_leases set expires_at=now0 where name=p->>'name' and owner=own and epoch=ep;return '{"ok":true}';
 elsif a='config' then return (select to_jsonb(x) from public.casino_world_config x where id);
 elsif a='directory' then
  return jsonb_build_object('rooms',(select jsonb_agg(jsonb_build_object('id','C:'||x.id,'code',x.code,'players',(select count(*) from public.casino_members m where m.room_id=x.id and m.expires_at>now0),'capacity',x.capacity) order by x.ordinal) from public.casino_rooms x where enabled));
 elsif a='controller' then
  c:=private.casino_controller_check(uid,sess,gen);
  update public.casino_controllers set expires_at=now0+interval '65 seconds' where user_id=uid;
  return jsonb_build_object('now',extract(epoch from now0)*1000);
 elsif a='revoke' then
  c:=private.casino_controller_check(uid,sess,gen);
  update public.casino_controllers set expires_at=now0 where user_id=uid;
  delete from public.casino_members where user_id=uid;delete from public.casino_reservations where user_id=uid and not consumed;
  return '{"ok":true}';
 elsif a='recover' then
  if uid is null or sess is null or not exists(select 1 from public.profiles where id=uid and not banned) then raise exception 'Account unavailable';end if;
  perform pg_advisory_xact_lock(hashtextextended(uid::text,941));
  select * into c from public.casino_controllers where user_id=uid for update;
  if found and c.session<>sess and c.expires_at>now0 and exists(select 1 from public.casino_leases where name='world' and expires_at>now0) then raise exception 'Casino is online. Reconnect there to take over';end if;
  if found and c.session<>sess and c.expires_at>now0 and coalesce((p->>'takeover')::boolean,false)=false then raise exception 'Casino active in another tab. Use TAKE OVER';end if;
  insert into public.casino_controllers(user_id,session,generation,expires_at) values(uid,sess,1,now0+interval '65 seconds')
   on conflict(user_id) do update set session=sess,generation=casino_controllers.generation+1,expires_at=now0+interval '65 seconds' returning * into c;
  update public.casino_controllers set recovery_only=true where user_id=uid;
  delete from public.casino_members where user_id=uid;delete from public.casino_reservations where user_id=uid and not consumed;
  return jsonb_build_object('generation',c.generation,'now',extract(epoch from now0)*1000);
 end if;
 perform private.casino_lease_check('world',own,ep);
 if a='admit' then
  if not (select admissions from public.casino_world_config where id) then raise exception 'Casino admissions are paused';end if;
  if not (select cardinality(allowlist)=0 or uid=any(allowlist) from public.casino_world_config where id) then raise exception 'Casino staging is limited to test accounts';end if;
  if uid is null or sess is null or not exists(select 1 from public.profiles where id=uid and not banned) then raise exception 'Account unavailable';end if;
  if exists(select 1 from public.casino_tables z where z.open and uid=any(z.humans) and z.room not like 'C:%') then raise exception 'Stand up at your previous table before entering the persistent casino';end if;
  perform pg_advisory_xact_lock(942);
  delete from public.casino_members where expires_at<=now0;
  select * into c from public.casino_controllers where user_id=uid for update;
  if found and c.session<>sess and c.expires_at>now0 and coalesce((p->>'takeover')::boolean,false)=false then raise exception 'Casino active in another tab. Use TAKE OVER';end if;
  select * into r from public.casino_rooms x where x.enabled and
   (coalesce(p->>'code','')='' or x.code=upper(p->>'code') or 'C:'||x.id= p->>'code') and
   (select count(*) from public.casino_members m where m.room_id=x.id and m.user_id<>uid)<x.capacity
   order by case when exists(select 1 from public.casino_tables z where z.open and uid=any(z.humans) and z.room='C:'||x.id) then -1
    when exists(select 1 from public.casino_members m where m.room_id=x.id and m.user_id<>uid) then 0 else 1 end,x.ordinal limit 1;
  if not found then raise exception 'That room is full or unavailable. Enter another casino room';end if;
  if exists(select 1 from public.casino_tables z where z.open and uid=any(z.humans) and z.room like 'C:%' and z.room<>'C:'||r.id) then raise exception 'Recover your previous table before changing rooms';end if;
  insert into public.casino_controllers(user_id,session,generation,room_id,expires_at) values(uid,sess,1,r.id,now0+interval '65 seconds')
   on conflict(user_id) do update set session=sess,generation=casino_controllers.generation+1,room_id=r.id,expires_at=now0+interval '65 seconds' returning * into c;
  insert into public.casino_members(user_id,room_id,generation,owner_epoch,expires_at) values(uid,r.id,c.generation,ep,now0+interval '30 seconds')
   on conflict(user_id) do update set room_id=r.id,generation=c.generation,owner_epoch=ep,expires_at=now0+interval '30 seconds';
  delete from public.casino_reservations where user_id=uid and not consumed;
  update public.casino_controllers set recovery_only=false where user_id=uid;
  return jsonb_build_object('room','C:'||r.id,'code',r.code,'generation',c.generation,'now',extract(epoch from now0)*1000,'position',(select jsonb_build_array(x,y) from public.casino_positions where user_id=uid and room_id=r.id and layout=1 and updated_at>now0-interval '30 minutes'));
 end if;
 c:=private.casino_controller_check(uid,sess,gen);
 if a='depart' then
  delete from public.casino_members where user_id=uid and generation=gen;delete from public.casino_reservations where user_id=uid and not consumed;
  update public.casino_controllers set expires_at=now0 where user_id=uid;return '{"ok":true}';
 end if;
 perform 1 from public.casino_members where user_id=uid and generation=gen and owner_epoch=ep and expires_at>now0;
 if not found then raise exception 'Room membership expired';end if;
 if a='heartbeat' then
  update public.casino_controllers set expires_at=now0+interval '65 seconds' where user_id=uid;
  update public.casino_members set expires_at=now0+interval '30 seconds' where user_id=uid;
  if (p->>'x')::real between .27 and 15.73 and (p->>'y')::real between .27 and 15.73 then
   insert into public.casino_positions(user_id,room_id,x,y) values(uid,c.room_id,(p->>'x')::real,(p->>'y')::real) on conflict(user_id) do update set room_id=excluded.room_id,x=excluded.x,y=excluded.y,layout=1,updated_at=now0;
  end if;
  select jsonb_build_object('id',z.id,'game',z.game,'station',z.station,'seats',z.st->'seats') into t from public.casino_tables z where z.open and z.room='C:'||c.room_id and uid=any(z.humans) limit 1;
  return jsonb_build_object('ok',true,'seat',t,'now',extract(epoch from now0)*1000);
 elsif a='reserve' then
  perform pg_advisory_xact_lock(943);
  delete from public.casino_reservations where not consumed and expires_at<=now0;
  if exists(select 1 from public.casino_tables z where z.open and z.room='C:'||c.room_id and z.game=p->>'game' and z.station=coalesce(p->>'station','') and z.st->'seats'->(p->>'seat')::int <> 'null'::jsonb) then raise exception 'That seat is occupied';end if;
  if exists(select 1 from public.casino_reservations where user_id=uid and not consumed) then raise exception 'A seat request is already pending';end if;
  insert into public.casino_reservations(user_id,room_id,game,station,seat,generation,owner_epoch,expires_at)
   values(uid,c.room_id,p->>'game',coalesce(p->>'station',''),(p->>'seat')::int,gen,ep,now0+interval '10 seconds') returning * into res;
  return jsonb_build_object('reservation',res.id);
 else raise exception 'Unknown casino request';end if;
end $$;

create function public.casino_invite_send(p_to uuid,p_room text,p_session uuid,p_generation bigint) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=private.require_user();r public.casino_rooms;i private.lobby_invites;c public.casino_controllers;
begin
 if coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Use a saved account';end if;
 c:=private.casino_controller_check(uid,p_session,p_generation);
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 if not exists(select 1 from public.friendships where user_a=least(uid,p_to) and user_b=greatest(uid,p_to)) or exists(select 1 from public.profiles where id=p_to and banned) then raise exception 'Invite an accepted friend';end if;
 select x.* into r from public.casino_rooms x join public.casino_members m on m.room_id=x.id where 'C:'||x.id=p_room and m.user_id=uid and m.generation=c.generation and m.expires_at>clock_timestamp() and x.enabled;
 if not found then raise exception 'Enter the casino first';end if;
 select * into i from private.lobby_invites where from_id=uid and to_id=p_to and managed_room=r.id and status='pending' and expires_at>clock_timestamp() limit 1;
 if found then return jsonb_build_object('id',i.id,'duplicate',true,'expires_at',i.expires_at);end if;
 if (select count(*) from private.lobby_invites where from_id=uid and created_at>now()-interval '1 minute')>=10 or (select count(*) from private.lobby_invites where from_id=uid and created_at>now()-interval '1 hour')>=30 then raise exception 'Invitation limit reached. Try later';end if;
 delete from private.lobby_invites where from_id=uid and created_at<now()-interval '31 days';
 insert into private.lobby_invites(from_id,to_id,incarnation,code,managed_room) values(uid,p_to,r.id,r.code,r.id) returning * into i;
 insert into public.notifications(user_id,from_id,kind,data) values(p_to,uid,'system',jsonb_build_object('text','Casino invitation','invite_id',i.id));
 return jsonb_build_object('id',i.id,'expires_at',i.expires_at);
end $$;
create function public.casino_invite_answer(p_id uuid,p_accept boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=private.require_user();i private.lobby_invites;r public.casino_rooms;
begin
 if coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Use a saved account';end if;
 select * into i from private.lobby_invites where id=p_id and to_id=uid and managed_room is not null for update;
 if not found then raise exception 'Invitation not found';end if;
 if not p_accept then update private.lobby_invites set status='declined' where id=p_id and status<>'accepted';return '{"status":"declined"}';end if;
 if i.status='declined' or i.expires_at<=clock_timestamp() then raise exception 'Invitation expired or declined';end if;
 if not exists(select 1 from public.friendships where user_a=least(uid,i.from_id) and user_b=greatest(uid,i.from_id)) or exists(select 1 from public.profiles where id=i.from_id and banned) then raise exception 'Friendship unavailable';end if;
 select * into r from public.casino_rooms where id=i.managed_room and enabled;
 if not found or not(select admissions from public.casino_world_config where id) then raise exception 'Casino admissions paused';end if;
 update private.lobby_invites set status='accepted' where id=p_id;
 return jsonb_build_object('status','accepted','transport','casino','code',r.code,'room','C:'||r.id);
end $$;
alter function public.social_state() rename to social_state_before_casino;
revoke all on function public.social_state_before_casino() from public,anon,authenticated;
create function public.social_state() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare uid uuid:=private.require_user();s jsonb;invs jsonb;
begin
 s:=public.social_state_before_casino();
 select coalesce(jsonb_agg(x),'[]') into invs from jsonb_array_elements(s->'invites') x where not exists(select 1 from private.lobby_invites i where i.id=(x->>'id')::uuid and i.managed_room is not null);
 return jsonb_set(s,'{invites}',invs||coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'transport','casino','created_at',i.created_at,'expires_at',i.expires_at,'user',jsonb_build_object('id',p.id,'username',p.username,'cos',p.cos),'room',jsonb_build_object('code',r.code,'id','C:'||r.id,'length','casino','mode','coop','map','casino','players',(select count(*) from public.casino_members m where m.room_id=r.id and m.expires_at>now()),'locked',not r.enabled)) order by i.created_at desc) from private.lobby_invites i join public.profiles p on p.id=i.from_id join public.casino_rooms r on r.id=i.managed_room where i.to_id=uid and i.status='pending' and i.expires_at>now() and not p.banned),'[]'));
end $$;
revoke all on function public.casino_invite_send(uuid,text,uuid,bigint),public.casino_invite_answer(uuid,boolean),public.social_state() from public,anon;
grant execute on function public.casino_invite_send(uuid,text,uuid,bigint),public.casino_invite_answer(uuid,boolean),public.social_state() to authenticated;

-- A commit locks the controller for the whole ledger transaction. An auth preflight alone is insufficient.
create function private.casino_guard(p jsonb,p_room text,p_st jsonb) returns void language plpgsql set search_path='' as $$
declare c public.casino_controllers;res public.casino_reservations;cfg public.casino_world_config;
begin
 if p->>'worker'='true' then
  perform private.casino_lease_check('worker',(p->>'owner')::uuid,(p->>'epoch')::bigint);
  if not (select recovery from public.casino_world_config where id) then raise exception 'Recovery paused';end if;
 else
  c:=private.casino_controller_check((p->>'uid')::uuid,(p->>'session')::uuid,(p->>'generation')::bigint);
  if c.recovery_only and coalesce(p->>'op','') not in ('state','leave','pick','move','insure','rlready') then raise exception 'Recovery can finish your existing hand or cash out. Reconnect to place new wagers';end if;
  if coalesce((p->>'wager')::boolean,false) and not(select new_wagers from public.casino_world_config where id) then raise exception 'New wagers are paused';end if;
  if p->>'reservation' is not null then
   perform private.casino_lease_check('world',(p->>'owner')::uuid,(p->>'epoch')::bigint);
   select * into res from public.casino_reservations where id=(p->>'reservation')::uuid for update;
   if not found or res.consumed or res.user_id<>c.user_id or res.generation<>c.generation or res.owner_epoch<>(p->>'epoch')::bigint or res.expires_at<=clock_timestamp()
     or p_room<>'C:'||res.room_id or p_st->>'game'<>res.game or coalesce(p_st->>'station','')<>res.station
     or p_st->'seats'->res.seat->>'uid' is distinct from c.user_id::text then raise exception 'Seat reservation expired or mismatched';end if;
   perform 1 from public.casino_members where user_id=c.user_id and room_id=res.room_id and generation=c.generation and owner_epoch=res.owner_epoch and expires_at>clock_timestamp();
   if not found then raise exception 'Room membership expired';end if;
  elsif p->>'sit'='true' then raise exception 'A seat reservation is required';end if;
 end if;
 if p_room like 'C:%' and coalesce(p_st->>'managedRevision','')<>'1' then raise exception 'Unsupported managed casino revision';end if;
 perform set_config('palisade.managed_write','1',true);
end $$;
create function public.casino_managed_step(p_table bigint,p_ver int,p_st jsonb,p_humans uuid[],p_open boolean,p_ops jsonb,p_hands jsonb,p_op jsonb,p_guard jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare r text;x jsonb;
begin
 select room into r from public.casino_tables where id=p_table;
 perform private.casino_guard(p_guard,r,p_st);
 x:=public.casino_step(p_table,p_ver,p_st,p_humans,p_open,p_ops,p_hands,p_op);
 if x->>'ok'='true' and p_guard->>'reservation' is not null then update public.casino_reservations set consumed=true where id=(p_guard->>'reservation')::uuid;end if;
 return x;
end $$;
create function public.casino_managed_start(p_code text,p_game text,p_st jsonb,p_humans uuid[],p_ops jsonb,p_room text,p_station text,p_op jsonb,p_guard jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare x jsonb;
begin
 perform private.casino_guard(p_guard,p_room,p_st);
 x:=public.casino_start(p_code,p_game,p_st,p_humans,p_ops,p_room,p_station,p_op);
 if x->>'ok'='true' and p_guard->>'reservation' is not null then update public.casino_reservations set consumed=true where id=(p_guard->>'reservation')::uuid;end if;
 return x;
end $$;

create function private.casino_due(p_st jsonb,p_game text) returns timestamptz language plpgsql set search_path='' as $$
declare d double precision;s jsonb;x double precision;
begin
 for s in select value from jsonb_array_elements(p_st->'seats') loop
  if s<>'null'::jsonb and not coalesce((s->>'bot')::boolean,false) and not coalesce((s->>'gone')::boolean,false) and not coalesce((s->>'leaving')::boolean,false) then
   x:=(s->>'seen')::double precision+60001;d:=least(d,x);
  end if;
 end loop;
 x:=(p_st->>'deadline')::double precision;
 if x>0 then if p_st->>'phase'='done' then x:=greatest(x,coalesce((p_st->>'minAt')::double precision,0));end if;d:=least(d,x);end if;
 if p_game='he' and p_st->>'phase'='play' and p_st->'hand'->'players'->((p_st->'hand'->>'cur')::int)->>'bot'='true' then d:=least(d,(p_st->'hand'->>'botAt')::double precision);end if;
 if p_game='cr' and exists(select 1 from jsonb_array_elements(p_st->'seats') z where z->>'gone'='true') and not exists(select 1 from jsonb_array_elements(p_st->'seats') z where z<>'null'::jsonb and coalesce(z->>'bot','false')<>'true' and coalesce(z->>'gone','false')<>'true') then d:=least(d,extract(epoch from clock_timestamp())*1000+100);end if;
 return case when d is null then null else to_timestamp(d/1000) end;
end $$;
create function private.casino_schedule() returns trigger language plpgsql set search_path='' as $$
begin
 if new.room like 'C:%' and coalesce(current_setting('palisade.managed_write',true),'')<>'1' then raise exception 'Managed casino requires a fenced writer';end if;
 new.next_due_at:=case when new.open then private.casino_due(new.st,new.game) else null end;
 new.recovery_failures:=0;new.recovery_error:=null;return new;
end $$;
create function public.casino_recovery_repair(p_owner uuid,p_epoch bigint) returns int language plpgsql security definer set search_path='' as $$
declare repaired int;
begin
 perform private.casino_lease_check('worker',p_owner,p_epoch);
 -- Repair only missing schedules, in bounded batches, without moving money or resetting backoff.
 with missing as (select id,private.casino_due(st,game) due from public.casino_tables
  where open and next_due_at is null and private.casino_due(st,game) is not null order by id limit 100)
 update public.casino_tables t set next_due_at=m.due from missing m where t.id=m.id;
 get diagnostics repaired=row_count;
 delete from public.casino_reservations where expires_at<clock_timestamp()-interval '1 minute';
 return repaired;
end $$;
create trigger casino_schedule before insert or update of st,open on public.casino_tables for each row execute function private.casino_schedule();
-- Existing managed rows cannot exist before this migration; repair legacy schedules once.
update public.casino_tables set st=st where open;

create function public.casino_recovery_backoff(p_table bigint,p_owner uuid,p_epoch bigint,p_error text) returns void language plpgsql security definer set search_path='' as $$
begin
 perform private.casino_lease_check('worker',p_owner,p_epoch);
 update public.casino_tables set recovery_failures=recovery_failures+1,recovery_error=left(p_error,240),
  next_due_at=clock_timestamp()+make_interval(secs=>least(300,power(2,least(8,recovery_failures+1))::int)) where id=p_table and open;
end $$;
create function public.casino_recovery_idle(p_table bigint,p_owner uuid,p_epoch bigint) returns void language plpgsql security definer set search_path='' as $$
begin
 perform private.casino_lease_check('worker',p_owner,p_epoch);
 -- A clock edge that did not change state must not monopolize the queue.
 update public.casino_tables set next_due_at=clock_timestamp()+interval '1 second' where id=p_table and open and next_due_at<=clock_timestamp();
end $$;

-- Only the backend can use privileged world/ledger RPCs; no anonymous or authenticated table grants.
do $$declare n text;f record;begin
 foreach n in array array['casino_world_config','casino_rooms','casino_leases','casino_controllers','casino_members','casino_reservations','casino_positions'] loop
  execute format('alter table public.%I enable row level security',n);
  execute format('revoke all on public.%I from public,anon,authenticated',n);
  execute format('grant select,insert,update,delete on public.%I to service_role',n);
 end loop;
 for f in select oid::regprocedure sig from pg_proc where pronamespace in ('public'::regnamespace,'private'::regnamespace) and proname in ('casino_world','casino_guard','casino_lease_check','casino_controller_check','casino_managed_start','casino_managed_step','casino_due','casino_schedule','casino_recovery_backoff','casino_recovery_idle','casino_recovery_repair') loop
  execute format('revoke all on function %s from public,anon,authenticated',f.sig);
  execute format('grant execute on function %s to service_role',f.sig);
 end loop;
end $$;
