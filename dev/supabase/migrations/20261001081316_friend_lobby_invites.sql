-- v0.9.6.0 authenticated private/public room records and in-app friend invitations.
create table if not exists private.room_sessions(
 host_id uuid primary key references public.profiles(id) on delete cascade,
 incarnation uuid not null,code text not null check(code ~ '^[A-Z0-9]{4}$'),proto text not null check(length(proto)<=16),
 mode text not null check(mode in ('coop','base','ffa')),length text,map text,chapter integer not null default 0 check(chapter between 0 and 3),
 players integer not null check(players between 1 and 6),locked boolean not null,updated_at timestamptz not null default now());
create table if not exists private.lobby_invites(
 id uuid primary key default gen_random_uuid(),from_id uuid not null references public.profiles(id) on delete cascade,
 to_id uuid not null references public.profiles(id) on delete cascade,incarnation uuid not null,code text not null,
 status text not null default 'pending' check(status in ('pending','accepted','declined')),
 created_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '5 minutes');
create index if not exists lobby_invites_recipient on private.lobby_invites(to_id,expires_at desc);
create index if not exists lobby_invites_sender on private.lobby_invites(from_id,created_at desc);
alter table private.room_sessions enable row level security;
alter table private.lobby_invites enable row level security;
revoke all on private.room_sessions,private.lobby_invites from public,anon,authenticated;

create or replace function public.room_register(p jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=private.require_user();inc uuid:=(p->>'incarnation')::uuid;r private.room_sessions;
begin
 if coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Use a saved account for friend invitations';end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 if p->>'close'='true' then delete from private.room_sessions where host_id=uid and incarnation=inc;return '{"closed":true}'::jsonb;end if;
 if inc is null or coalesce(p->>'proto','')<>'yard-21' or coalesce(p->>'code','')!~'^[A-Z0-9]{4}$' or coalesce(p->>'mode','') not in ('coop','base','ffa')
    or coalesce(p->>'map','') not in ('yard','river','quarry','frost') or coalesce(p->>'length','') not in ('5','10','endless','blitz','campaign') then raise exception 'Invalid room registration';end if;
 insert into private.room_sessions(host_id,incarnation,code,proto,mode,length,map,chapter,players,locked)
 values(uid,inc,p->>'code',p->>'proto',p->>'mode',p->>'length',p->>'map',coalesce((p->>'chapter')::int,0),(p->>'players')::int,coalesce((p->>'locked')::boolean,false))
 on conflict(host_id) do update set incarnation=excluded.incarnation,code=excluded.code,proto=excluded.proto,mode=excluded.mode,length=excluded.length,map=excluded.map,chapter=excluded.chapter,players=excluded.players,locked=excluded.locked,updated_at=now();
 return '{"registered":true}'::jsonb;
end $$;

create or replace function public.lobby_invite_send(p_to uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=private.require_user();r private.room_sessions;i private.lobby_invites;
begin
 if coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Use a saved account for friend invitations';end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 delete from private.lobby_invites where from_id=uid and created_at<now()-interval '31 days';
 if not exists(select 1 from public.friendships where user_a=least(uid,p_to) and user_b=greatest(uid,p_to))
    or exists(select 1 from public.profiles where id=p_to and banned) then raise exception 'Invite an accepted friend';end if;
 select * into r from private.room_sessions where host_id=uid and updated_at>now()-interval '45 seconds';
 if not found then raise exception 'Create or refresh your room first';end if;
 if r.locked then raise exception 'Unlock your room before inviting';end if;
 if r.players>=6 then raise exception 'Your room is full';end if;
 select * into i from private.lobby_invites where from_id=uid and to_id=p_to and incarnation=r.incarnation and status='pending' and expires_at>now() order by created_at desc limit 1;
 if found then return jsonb_build_object('id',i.id,'duplicate',true,'expires_at',i.expires_at);end if;
 if (select count(*) from private.lobby_invites where from_id=uid and created_at>now()-interval '1 minute')>=10
    or (select count(*) from private.lobby_invites where from_id=uid and created_at>now()-interval '1 hour')>=30 then raise exception 'Invitation limit reached. Try later';end if;
 insert into private.lobby_invites(from_id,to_id,incarnation,code) values(uid,p_to,r.incarnation,r.code) returning * into i;
 insert into public.notifications(user_id,from_id,kind,data) values(p_to,uid,'system',jsonb_build_object('text','Lobby invitation','invite_id',i.id));
 return jsonb_build_object('id',i.id,'expires_at',i.expires_at);
end $$;

create or replace function public.lobby_invite_answer(p_id uuid,p_accept boolean,p_proto text) returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=private.require_user();i private.lobby_invites;r private.room_sessions;
begin
 if coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Use a saved account for friend invitations';end if;
 select * into i from private.lobby_invites where id=p_id and to_id=uid for update;
 if not found then raise exception 'Invitation not found';end if;
 if not p_accept then
   if i.status<>'accepted' then update private.lobby_invites set status='declined' where id=p_id;end if;
   return jsonb_build_object('status',case when i.status='accepted' then 'accepted' else 'declined' end);
 end if;
 if i.status='declined' then raise exception 'Invitation was declined';end if;
 if i.expires_at<=now() then raise exception 'Invitation expired';end if;
 if not exists(select 1 from public.friendships where user_a=least(uid,i.from_id) and user_b=greatest(uid,i.from_id)) then raise exception 'Friendship no longer active';end if;
 select * into r from private.room_sessions where host_id=i.from_id and incarnation=i.incarnation and code=i.code and updated_at>now()-interval '45 seconds';
 if not found then raise exception 'That room has closed or changed';end if;
 if r.proto<>p_proto then raise exception 'Different game version. Reload before joining';end if;
 if r.locked then raise exception 'Room is locked';end if;
 if r.players>=6 then raise exception 'Room is full';end if;
 if exists(select 1 from public.profiles where id=i.from_id and banned) then raise exception 'Host unavailable';end if;
 update private.lobby_invites set status='accepted' where id=p_id;
 return jsonb_build_object('status','accepted','code',r.code,'incarnation',r.incarnation,'mode',r.mode,'length',r.length,'map',r.map,'chapter',r.chapter,'slots',6-r.players);
end $$;

revoke all on function public.room_register(jsonb),public.lobby_invite_send(uuid),public.lobby_invite_answer(uuid,boolean,text) from public,anon;
grant execute on function public.room_register(jsonb),public.lobby_invite_send(uuid),public.lobby_invite_answer(uuid,boolean,text) to authenticated;
CREATE OR REPLACE FUNCTION public.social_state()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user();
begin
  return jsonb_build_object(
    'friends', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'username', p.username, 'cos', p.cos, 'since', f.created_at) order by lower(p.username::text))
        from public.friendships f join public.profiles p on p.id = case when f.user_a = uid then f.user_b else f.user_a end
        where uid in (f.user_a, f.user_b) and not p.banned), '[]'::jsonb),
    'incoming', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'user', jsonb_build_object('id', p.id, 'username', p.username, 'cos', p.cos), 'at', r.created_at) order by r.created_at desc)
        from public.friend_requests r join public.profiles p on p.id = r.from_id
        where r.to_id = uid and r.status = 'pending' and not p.banned), '[]'::jsonb),
    'outgoing', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'user', jsonb_build_object('id', p.id, 'username', p.username, 'cos', p.cos), 'at', r.created_at) order by r.created_at desc)
        from public.friend_requests r join public.profiles p on p.id = r.to_id
        where r.from_id = uid and r.status = 'pending'), '[]'::jsonb),
    'notes', coalesce((select jsonb_agg(x order by x.created_at desc) from (
        select n.id, n.kind, n.data, n.created_at, n.seen_at, jsonb_build_object('id', p.id, 'username', p.username) as "user"
        from public.notifications n left join public.profiles p on p.id = n.from_id
        where n.user_id = uid order by n.created_at desc limit 40) x), '[]'::jsonb),
    'unseen', (select count(*) from public.notifications n where n.user_id = uid and n.seen_at is null),
    'invites',coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'created_at',i.created_at,'expires_at',i.expires_at,'user',jsonb_build_object('id',p.id,'username',p.username,'cos',p.cos),'room',jsonb_build_object('code',i.code,'length',r.length,'mode',r.mode,'map',r.map,'chapter',r.chapter,'players',r.players,'locked',r.locked)) order by i.created_at desc) from private.lobby_invites i join public.profiles p on p.id=i.from_id left join private.room_sessions r on r.host_id=i.from_id and r.incarnation=i.incarnation where i.to_id=uid and i.status='pending' and i.expires_at>now() and not p.banned),'[]'::jsonb),
    'is_anonymous', coalesce((auth.jwt()->>'is_anonymous')::boolean, false));
end $function$
;
revoke all on function public.social_state() from public,anon;
grant execute on function public.social_state() to authenticated;
