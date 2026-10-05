-- v0.10.0 casino rooms: Open Games and friend invites know THE PALISADE FALLS CASINO. A casino room is listed like any
-- room, with length 'casino' and map 'casino'. room_register is the live definition with those two values added (its
-- close branch removes the room session, as before). Safe to run twice.
alter table public.lobbies drop constraint if exists lobbies_length_check;
alter table public.lobbies add constraint lobbies_length_check check (length = any (array['5','10','endless','blitz','campaign','blackout','casino']));

create or replace function public.room_register(p jsonb) returns jsonb
language plpgsql security definer set search_path to '' as $function$
declare uid uuid:=private.require_user();inc uuid:=(p->>'incarnation')::uuid;r private.room_sessions;
begin
 if coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Use a saved account for friend invitations';end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 if p->>'close'='true' then delete from private.room_sessions where host_id=uid and incarnation=inc;return '{"closed":true}'::jsonb;end if;
 if inc is null or coalesce(p->>'proto','')!~'^yard-[0-9]{1,3}$' or coalesce(p->>'code','')!~'^[A-Z0-9]{4}$' or coalesce(p->>'mode','') not in ('coop','base','ffa')
    or coalesce(p->>'map','') not in ('yard','river','quarry','frost','city','casino') or coalesce(p->>'length','') not in ('5','10','endless','blitz','campaign','blackout','casino') then raise exception 'Invalid room registration';end if;
 insert into private.room_sessions(host_id,incarnation,code,proto,mode,length,map,chapter,players,locked)
 values(uid,inc,p->>'code',p->>'proto',p->>'mode',p->>'length',p->>'map',coalesce((p->>'chapter')::int,0),(p->>'players')::int,coalesce((p->>'locked')::boolean,false))
 on conflict(host_id) do update set incarnation=excluded.incarnation,code=excluded.code,proto=excluded.proto,mode=excluded.mode,length=excluded.length,map=excluded.map,chapter=excluded.chapter,players=excluded.players,locked=excluded.locked,updated_at=now();
 return '{"registered":true}'::jsonb;
end $function$;
