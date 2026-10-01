-- v0.9.6.1: append distinct Winter Case models. Old clients retain catalog cap 2.
insert into public.cosmetics(id,cat,key,name,rarity,src,need,box,catalog_version) values
 ('skin:yulemaw','skin','yulemaw','Yulemaw','e','case',null,'winter',3),
 ('skin:rednosedemolisher','skin','rednosedemolisher','Rednose Demolisher','l','case',null,'winter',3),
 ('skin:gildedfrostborn','skin','gildedfrostborn','Gilded Frostborn','g','case',null,'winter',3)
on conflict(id) do update set name=excluded.name,rarity=excluded.rarity,src=excluded.src,need=excluded.need,box=excluded.box,catalog_version=excluded.catalog_version;
create or replace function public.open_case_v0961(p_case text,p_rev integer default null)
returns jsonb language sql security invoker set search_path='' as $$
 select private.open_case_catalog(p_case,p_rev,3);
$$;
revoke all on function public.open_case_v0961(text,integer) from public,anon;
grant execute on function public.open_case_v0961(text,integer) to authenticated;

CREATE OR REPLACE FUNCTION private.open_case_catalog(p_case text, p_rev integer, p_catalog integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user(); l public.lockers; ct public.case_types; it public.cosmetics;
 want text; have int; dup boolean; weights jsonb;
begin
 if p_catalog is null or p_catalog not in (0,1,2,3) then raise exception 'Unknown cosmetic catalog' using errcode='22023'; end if;
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

