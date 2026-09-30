-- v0.9.3.5: additive cosmetics and a versioned case pool. No player-data backfill.
-- Old clients retain their original Supply odds and cannot roll catalog_version 1.
alter table public.cosmetics add column if not exists catalog_version integer not null default 0;
alter table public.cosmetics drop constraint cosmetics_rarity_check;
alter table public.cosmetics add constraint cosmetics_rarity_check check (rarity in ('c','r','e','l','g','u'));

insert into public.cosmetics(id,cat,key,name,rarity,src,need,box,catalog_version) values
 ('skin:sahur','skin','sahur','Tung Tung Tung Sahur','u','case',null,'supply',1),
 ('hat:gravecap','hat','gravecap','Gravestone Cap','c','case',null,'halloween',1),
 ('hat:stemband','hat','stemband','Pumpkin Stem Band','c','case',null,'halloween',1),
 ('hat:batcirclet','hat','batcirclet','Bat-Notch Circlet','r','case',null,'halloween',1),
 ('hat:bonewrap','hat','bonewrap','Bone-Button Wrap','r','case',null,'halloween',1),
 ('hat:webpin','hat','webpin','Cobweb Brow Pin','e','case',null,'halloween',1),
 ('hat:skullseal','hat','skullseal','Crescent Skull Seal','l','case',null,'halloween',1)
on conflict(id) do update set name=excluded.name,rarity=excluded.rarity,box=excluded.box,catalog_version=excluded.catalog_version;
update public.case_types set weights='{"c":59.75,"r":27,"e":10,"l":3,"u":0.25}'::jsonb where id='supply';

create or replace function private.shard_value(r text) returns integer
language sql immutable set search_path='' as $function$
 select case r when 'c' then 1 when 'r' then 3 when 'e' then 8 when 'l' then 20 when 'g' then 40 when 'u' then 80 else 1 end;
$function$;

-- Definer logic is private. The public entrypoints below are invokers with fixed catalog versions.
create or replace function private.open_case_catalog(p_case text,p_rev integer,p_catalog integer)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare uid uuid := private.require_user(); l public.lockers; ct public.case_types; it public.cosmetics;
 want text; have int; dup boolean; weights jsonb;
begin
 if p_catalog is null or p_catalog not in (0,1) then raise exception 'Unknown cosmetic catalog' using errcode='22023'; end if;
 select * into ct from public.case_types where id=p_case;
 if not found then raise exception 'Unknown case' using errcode='22023'; end if;
 select * into l from public.lockers where user_id=uid for update;
 if not found then raise exception 'Locker not found' using errcode='22023'; end if;
 perform private.check_rev(l,p_rev);
 have := case when p_case='supply' then l.cases else coalesce((l.bag->>p_case)::int,0) end;
 if have<1 then raise exception 'No % to open',lower(ct.name)||'s' using errcode='22023'; end if;
 weights := case when p_catalog=0 and p_case='supply' then '{"c":60,"r":27,"e":10,"l":3}'::jsonb else ct.weights end;
 want := private.roll_rarity(weights);
 select * into it from public.cosmetics c where c.box=p_case and c.rarity=want and c.catalog_version<=p_catalog order by random() limit 1;
 if not found then select * into it from public.cosmetics c where c.box=p_case and c.catalog_version<=p_catalog order by c.rarity='c' desc,random() limit 1; end if;
 if not found then raise exception 'Case catalog is empty' using errcode='22023'; end if;
 dup := it.id=any(l.owned);
 update public.lockers set
  cases=case when p_case='supply' then cases-1 else cases end,
  bag=case when p_case='supply' then bag else private.bag_add(bag,p_case,-1) end,
  shards=shards+case when dup then private.shard_value(it.rarity) else 0 end,
  owned=case when dup then owned else owned||it.id end,
  rev=rev+1,updated_at=now()
 where user_id=uid returning * into l;
 return jsonb_build_object('case',p_case,'item',jsonb_build_object('id',it.id,'cat',it.cat,'key',it.key,'name',it.name,'rarity',it.rarity),
  'dup',dup,'locker',private.locker_out(l));
end $function$;
revoke all on function private.open_case_catalog(text,integer,integer) from public,anon;
grant usage on schema private to authenticated;
grant execute on function private.open_case_catalog(text,integer,integer) to authenticated;

create or replace function public.open_case_of(p_case text,p_rev integer default null)
returns jsonb language sql security invoker set search_path='' as $function$
 select private.open_case_catalog(p_case,p_rev,0);
$function$;
create or replace function public.open_case_v0935(p_case text,p_rev integer default null)
returns jsonb language sql security invoker set search_path='' as $function$
 select private.open_case_catalog(p_case,p_rev,1);
$function$;
revoke all on function public.open_case_of(text,integer) from public,anon;
revoke all on function public.open_case_v0935(text,integer) from public,anon;
grant execute on function public.open_case_of(text,integer) to authenticated;
grant execute on function public.open_case_v0935(text,integer) to authenticated;
