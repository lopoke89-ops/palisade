-- v0.9.6.2: one atomic operation for one or five cases, with durable retry receipts.
create table private.case_openings (
 user_id uuid not null references auth.users(id) on delete cascade,
 operation_id uuid not null,
 case_id text not null references public.case_types(id),
 quantity integer not null check (quantity in (1,5)),
 results jsonb not null,
 created_at timestamptz not null default now(),
 primary key(user_id,operation_id)
);
alter table private.case_openings enable row level security;
revoke all on private.case_openings from public,anon,authenticated;

create or replace function private.open_cases_v0962(p_case text,p_quantity integer,p_operation uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=private.require_user(); l public.lockers; receipt private.case_openings;
 have integer; result jsonb; awarded jsonb:='[]'::jsonb; i integer;
begin
 if p_operation is null or p_quantity is null or p_quantity not in (1,5) then
  raise exception 'Choose one or five cases and a valid opening ID' using errcode='22023';
 end if;
 select * into l from public.lockers where user_id=uid for update;
 if not found then raise exception 'Locker not found' using errcode='22023'; end if;
 select * into receipt from private.case_openings where user_id=uid and operation_id=p_operation;
 if found then
  if receipt.case_id<>p_case or receipt.quantity<>p_quantity then
   raise exception 'Opening ID already belongs to a different request' using errcode='22023';
  end if;
  return jsonb_build_object('operation',p_operation,'case',p_case,'quantity',p_quantity,'results',receipt.results,'locker',private.locker_out(l),'retry',true);
 end if;
 if not exists(select 1 from public.case_types where id=p_case) then raise exception 'Unknown case' using errcode='22023'; end if;
 have:=case when p_case='supply' then l.cases else coalesce((l.bag->>p_case)::integer,0) end;
 if have<p_quantity then raise exception 'Not enough cases to open %',p_quantity using errcode='22023'; end if;
 -- Each roll sees the ownership updated by the preceding roll in this transaction.
 for i in 1..p_quantity loop
  result:=private.open_case_catalog(p_case,null,3);
  awarded:=awarded||jsonb_build_array(jsonb_build_object('item',result->'item','dup',result->'dup',
   'shards',case when (result->>'dup')::boolean then private.shard_value(result->'item'->>'rarity') else 0 end));
 end loop;
 insert into private.case_openings(user_id,operation_id,case_id,quantity,results) values(uid,p_operation,p_case,p_quantity,awarded);
 select * into l from public.lockers where user_id=uid;
 return jsonb_build_object('operation',p_operation,'case',p_case,'quantity',p_quantity,'results',awarded,'locker',private.locker_out(l),'retry',false);
end $$;
revoke all on function private.open_cases_v0962(text,integer,uuid) from public,anon;
grant execute on function private.open_cases_v0962(text,integer,uuid) to authenticated;
create or replace function public.open_cases_v0962(p_case text,p_quantity integer,p_operation uuid)
returns jsonb language sql security invoker set search_path='' as $$
 select private.open_cases_v0962(p_case,p_quantity,p_operation);
$$;
revoke all on function public.open_cases_v0962(text,integer,uuid) from public,anon;
grant execute on function public.open_cases_v0962(text,integer,uuid) to authenticated;
