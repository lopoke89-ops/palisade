-- v0.9.6.3: room_register accepted only proto 'yard-21', so every room hosted from v0.9.6.1 on (yard-22) failed to
-- register and friends couldn't be invited to it. Accept any 'yard-N' instead; lobby_invite_answer still refuses a
-- guest whose version differs from the room's ("Different game version"), so mismatched copies still can't meet.
-- Built from the live function text (October 3); only the proto check changed. Privileges are kept by CREATE OR REPLACE.
CREATE OR REPLACE FUNCTION public.room_register(p jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid:=private.require_user();inc uuid:=(p->>'incarnation')::uuid;r private.room_sessions;
begin
 if coalesce((auth.jwt()->>'is_anonymous')::boolean,false) then raise exception 'Use a saved account for friend invitations';end if;
 perform pg_advisory_xact_lock(hashtextextended(uid::text,0));
 if p->>'close'='true' then delete from private.room_sessions where host_id=uid and incarnation=inc;return '{"closed":true}'::jsonb;end if;
 if inc is null or coalesce(p->>'proto','')!~'^yard-[0-9]{1,3}$' or coalesce(p->>'code','')!~'^[A-Z0-9]{4}$' or coalesce(p->>'mode','') not in ('coop','base','ffa')
    or coalesce(p->>'map','') not in ('yard','river','quarry','frost') or coalesce(p->>'length','') not in ('5','10','endless','blitz','campaign') then raise exception 'Invalid room registration';end if;
 insert into private.room_sessions(host_id,incarnation,code,proto,mode,length,map,chapter,players,locked)
 values(uid,inc,p->>'code',p->>'proto',p->>'mode',p->>'length',p->>'map',coalesce((p->>'chapter')::int,0),(p->>'players')::int,coalesce((p->>'locked')::boolean,false))
 on conflict(host_id) do update set incarnation=excluded.incarnation,code=excluded.code,proto=excluded.proto,mode=excluded.mode,length=excluded.length,map=excluded.map,chapter=excluded.chapter,players=excluded.players,locked=excluded.locked,updated_at=now();
 return '{"registered":true}'::jsonb;
end $function$;
