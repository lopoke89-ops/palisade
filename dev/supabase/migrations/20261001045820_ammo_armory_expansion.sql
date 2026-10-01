-- Four co-op special-ammo skill nodes. Based on the live skill_defs and skill_buy
-- function bodies read on 2026-10-01. The existing cost table and respec accounting
-- stay intact; skill_spent reads skill_defs dynamically.
create or replace function private.skill_defs()
returns jsonb language sql immutable set search_path to '' as $function$
  select '{"dmg":{"cost":[1,2,3]},"rate":{"cost":[1,2,3]},"reload":{"cost":[1,2]},"range":{"cost":[1,2]},
    "hp":{"cost":[1,2,3]},"regen":{"cost":[2,3]},"revive":{"cost":[1,2]},"speed":{"cost":[1,2,3]},"vest":{"cost":[2,3]},"haul":{"cost":[1,2]},
    "rockets":{"cost":[1,2,3]},"pouch":{"cost":[2,3]},"molotov":{"cost":[3],"req":["pouch",1]},"ghillie":{"cost":[1,2]},"stride":{"cost":[1,2]},
    "ammo_ap":{"cost":[1,2,3,4],"gate":[5,10,15,20]},"ammo_fire":{"cost":[1,2,3,4],"gate":[5,10,15,20]},
    "ammo_blast":{"cost":[1,2,3,4],"gate":[5,10,15,20]},"ammo_shock":{"cost":[1,2,3,4],"gate":[5,10,15,20]}}'::jsonb
$function$;

create or replace function public.skill_buy(p_node text, p_rev integer default null)
returns jsonb language plpgsql security definer set search_path to '' as $function$
declare uid uuid := private.require_user(); l public.lockers; d jsonb := private.skill_defs()->p_node; lv int; cost int; gate int;
begin
  if d is null then raise exception 'Unknown skill' using errcode = '22023'; end if;
  select * into l from public.lockers where user_id = uid for update;
  perform private.check_rev(l, p_rev);
  lv := coalesce((l.skills->>p_node)::int, 0);
  if lv >= jsonb_array_length(d->'cost') then raise exception 'That skill is maxed' using errcode = '22023'; end if;
  if d ? 'req' and coalesce((l.skills->>(d->'req'->>0))::int, 0) < (d->'req'->>1)::int then
    raise exception 'Unlock % first', d->'req'->>0 using errcode = '22023'; end if;
  if d ? 'gate' then
    gate := (d->'gate'->>lv)::int;
    if l.sp_total < gate then raise exception 'Earn % lifetime skill points first', gate using errcode = '22023'; end if;
  end if;
  cost := (d->'cost'->>lv)::int;
  if l.sp < cost then raise exception 'That takes % skill point%', cost, case when cost = 1 then '' else 's' end using errcode = '22023'; end if;
  update public.lockers set sp = sp - cost, skills = jsonb_set(skills, array[p_node], to_jsonb(lv + 1)), rev = rev + 1, updated_at = now()
    where user_id = uid returning * into l;
  return private.locker_out(l);
end $function$;

revoke all on function private.skill_defs() from public, anon, authenticated;
revoke all on function public.skill_buy(text, integer) from public, anon;
grant execute on function public.skill_buy(text, integer) to authenticated;
