-- v0.9.6.4 (part 1 of 2): the Hybrid Theory Case, its 57 items (catalog 4) and the catalog-4 opener. Applied October 3.
insert into public.case_types(id,name,weights,shard_cost,modes,drop,sort) values('hybrid','HYBRID THEORY CASE','{"c":46,"r":30,"e":16,"l":7,"g":1}',12,'{}','{}',7)
on conflict(id) do update set name=excluded.name,weights=excluded.weights,shard_cost=excluded.shard_cost,sort=excluded.sort;

-- Exactly 57 items: 30 jerseys, 8 headgear, 11 kill effects, 8 backgrounds (catalog 4).
insert into public.cosmetics(id,cat,key,name,rarity,src,need,box,catalog_version) values
 ('skin:hb_lizards','skin','hb_lizards','Washington Lizards','c','case',null,'hybrid',4),
 ('skin:hb_placers','skin','hb_placers','Indiana Placers','c','case',null,'hybrid',4),
 ('skin:hb_vets','skin','hb_vets','Brooklyn Vets','c','case',null,'hybrid',4),
 ('skin:hb_rings','skin','hb_rings','Sacramento Rings','c','case',null,'hybrid',4),
 ('skin:hb_jabs','skin','hb_jabs','Utah Jabs','c','case',null,'hybrid',4),
 ('skin:hb_drizzlies','skin','hb_drizzlies','Memphis Drizzlies','c','case',null,'hybrid',4),
 ('skin:hb_saversicks','skin','hb_saversicks','Dallas Saversicks','r','case',null,'hybrid',4),
 ('skin:hb_relicans','skin','hb_relicans','New Orleans Relicans','r','case',null,'hybrid',4),
 ('skin:hb_pulls','skin','hb_pulls','Chicago Pulls','r','case',null,'hybrid',4),
 ('skin:hb_ducks','skin','hb_ducks','Milwaukee Ducks','r','case',null,'hybrid',4),
 ('skin:hb_worriers','skin','hb_worriers','Golden State Worriers','r','case',null,'hybrid',4),
 ('skin:hb_slippers','skin','hb_slippers','Los Angeles Slippers','r','case',null,'hybrid',4),
 ('skin:hb_sailglazers','skin','hb_sailglazers','Portland Sail Glazers','e','case',null,'hybrid',4),
 ('skin:hb_beat','skin','hb_beat','Miami Beat','e','case',null,'hybrid',4),
 ('skin:hb_cornets','skin','hb_cornets','Charlotte Cornets','e','case',null,'hybrid',4),
 ('skin:hb_fixers','skin','hb_fixers','Philadelphia Fixers','e','case',null,'hybrid',4),
 ('skin:hb_static','skin','hb_static','Orlando Static','e','case',null,'hybrid',4),
 ('skin:hb_runs','skin','hb_runs','Phoenix Runs','e','case',null,'hybrid',4),
 ('skin:hb_squawks','skin','hb_squawks','Atlanta Squawks','l','case',null,'hybrid',4),
 ('skin:hb_captors','skin','hb_captors','Toronto Captors','l','case',null,'hybrid',4),
 ('skin:hb_cinderwolves','skin','hb_cinderwolves','Minnesota Cinderwolves','l','case',null,'hybrid',4),
 ('skin:hb_lockets','skin','hb_lockets','Houston Lockets','l','case',null,'hybrid',4),
 ('skin:hb_navaliers','skin','hb_navaliers','Cleveland Navaliers','l','case',null,'hybrid',4),
 ('skin:hb_bricks','skin','hb_bricks','New York Bricks','l','case',null,'hybrid',4),
 ('skin:hb_bakers','skin','hb_bakers','Los Angeles Bakers','g','case',null,'hybrid',4),
 ('skin:hb_budgets','skin','hb_budgets','Denver Budgets','g','case',null,'hybrid',4),
 ('skin:hb_kelpies','skin','hb_kelpies','Boston Kelpies','g','case',null,'hybrid',4),
 ('skin:hb_whistlers','skin','hb_whistlers','Detroit Whistlers','g','case',null,'hybrid',4),
 ('skin:hb_burrs','skin','hb_burrs','San Antonio Burrs','g','case',null,'hybrid',4),
 ('skin:hb_hummers','skin','hb_hummers','Oklahoma City Hummers','g','case',null,'hybrid',4),
 ('hat:shades','hat','shades','Sunglasses','c','case',null,'hybrid',4),
 ('hat:yamaka','hat','yamaka','Yamaka','r','case',null,'hybrid',4),
 ('hat:ballhelm','hat','ballhelm','Ball Helm','r','case',null,'hybrid',4),
 ('hat:gridhelm','hat','gridhelm','Grid Helm','e','case',null,'hybrid',4),
 ('hat:dunce','hat','dunce','Dunce Cone','e','case',null,'hybrid',4),
 ('hat:prop','hat','prop','Prop Hat','c','case',null,'hybrid',4),
 ('hat:conductor','hat','conductor','Conductor Cap','r','case',null,'hybrid',4),
 ('hat:skullhelm','hat','skullhelm','Skull Helm','l','case',null,'hybrid',4),
 ('fx:leaf','fx','leaf','Weed Leaf','r','case',null,'hybrid',4),
 ('fx:bands','fx','bands','Money Explosion','e','case',null,'hybrid',4),
 ('fx:swish','fx','swish','Hoop Swish','l','case',null,'hybrid',4),
 ('fx:nuke','fx','nuke','Nuke Pop','g','case',null,'hybrid',4),
 ('fx:poop','fx','poop','Poop Pop','c','case',null,'hybrid',4),
 ('fx:demon','fx','demon','Purple Demon','e','case',null,'hybrid',4),
 ('fx:hundo','fx','hundo','100 Pop','r','case',null,'hybrid',4),
 ('fx:fire','fx','fire','Fire Pop','r','case',null,'hybrid',4),
 ('fx:eight','fx','eight','8=D Pop','c','case',null,'hybrid',4),
 ('fx:sixty','fx','sixty','67 Pop','c','case',null,'hybrid',4),
 ('fx:zzz','fx','zzz','Bed Nap','c','case',null,'hybrid',4),
 ('bg:yardneon','bg','yardneon','Yard Neon','g','case',null,'hybrid',4),
 ('bg:voltgrid','bg','voltgrid','Volt Grid','g','case',null,'hybrid',4),
 ('bg:viceblock','bg','viceblock','Vice Block','g','case',null,'hybrid',4),
 ('bg:crowncity','bg','crowncity','Crown City','g','case',null,'hybrid',4),
 ('bg:peachwire','bg','peachwire','Peach Wire','l','case',null,'hybrid',4),
 ('bg:lakeblocks','bg','lakeblocks','Lake Blocks','l','case',null,'hybrid',4),
 ('bg:fiestastrip','bg','fiestastrip','Fiesta Strip','l','case',null,'hybrid',4),
 ('bg:oaknight','bg','oaknight','Oak Night','l','case',null,'hybrid',4)
on conflict(id) do update set cat=excluded.cat,key=excluded.key,name=excluded.name,rarity=excluded.rarity,src=excluded.src,need=excluded.need,box=excluded.box,catalog_version=excluded.catalog_version;
update public.cosmetics c set description=d.description from (values
 ('skin:hb_lizards','Washington Lizards: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_placers','Indiana Placers: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_vets','Brooklyn Vets: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_rings','Sacramento Rings: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_jabs','Utah Jabs: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_drizzlies','Memphis Drizzlies: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_saversicks','Dallas Saversicks: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_relicans','New Orleans Relicans: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_pulls','Chicago Pulls: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_ducks','Milwaukee Ducks: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_worriers','Golden State Worriers: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_slippers','Los Angeles Slippers: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_sailglazers','Portland Sail Glazers: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_beat','Miami Beat: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_cornets','Charlotte Cornets: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_fixers','Philadelphia Fixers: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_static','Orlando Static: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_runs','Phoenix Runs: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_squawks','Atlanta Squawks: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_captors','Toronto Captors: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_cinderwolves','Minnesota Cinderwolves: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_lockets','Houston Lockets: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_navaliers','Cleveland Navaliers: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_bricks','New York Bricks: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_bakers','Los Angeles Bakers: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_budgets','Denver Budgets: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_kelpies','Boston Kelpies: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_whistlers','Detroit Whistlers: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_burrs','San Antonio Burrs: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('skin:hb_hummers','Oklahoma City Hummers: a sleeveless jersey and shorts in their colors, trim on the neck, hem and sides.'),
 ('hat:shades','Square black shades with a white glint.'),
 ('hat:yamaka','A small plain black cap on the crown.'),
 ('hat:ballhelm','An orange ball-pattern helmet with black seams.'),
 ('hat:gridhelm','A navy grid helmet with a gray facemask.'),
 ('hat:dunce','A tall cream dunce cone with a red band.'),
 ('hat:prop','A beanie with a little propeller on top.'),
 ('hat:conductor','A navy conductor cap with a gold band and brim.'),
 ('hat:skullhelm','A bone-white skull helmet with dark sockets.'),
 ('fx:leaf','Green and lime leaves burst, drift and fade.'),
 ('fx:bands','Bills and coins pop and flutter down.'),
 ('fx:swish','An orange rim and white net; the ball drops through.'),
 ('fx:nuke','A white flash, an orange mushroom and a gray ring.'),
 ('fx:poop','A brown swirl and stink puffs.'),
 ('fx:demon','Purple horns and eyes over a small flame ring.'),
 ('fx:hundo','White 100 stamps scale up and scatter.'),
 ('fx:fire','Orange-yellow flame tongues, then embers.'),
 ('fx:eight','A flat peach comic shape, then a white flash.'),
 ('fx:sixty','Block numerals 6 and 7 in white and volt, then they crack.'),
 ('fx:zzz','A flat bed, three Zs rise, a soft blue fade.'),
 ('bg:yardneon','Block towers on navy with slow gold neon streaks.'),
 ('bg:voltgrid','A black skyline with volt and red grid streaks.'),
 ('bg:viceblock','Black blocks under pink and cyan neon.'),
 ('bg:crowncity','Purple towers crowned in gold light.'),
 ('bg:peachwire','Peach wires strung between cream-lit blocks.'),
 ('bg:lakeblocks','Midnight blocks under a green aurora.'),
 ('bg:fiestastrip','A pink and teal neon strip at night.'),
 ('bg:oaknight','Cream and brown towers with gold windows.')
) d(id,description) where c.id=d.id;

CREATE OR REPLACE FUNCTION private.open_case_catalog(p_case text, p_rev integer, p_catalog integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := private.require_user(); l public.lockers; ct public.case_types; it public.cosmetics;
 want text; have int; dup boolean; weights jsonb;
begin
 if p_catalog is null or p_catalog not in (0,1,2,3,4) then raise exception 'Unknown cosmetic catalog' using errcode='22023'; end if;
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

create or replace function private.open_cases_v0964(p_case text,p_quantity integer,p_operation uuid)
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
  result:=private.open_case_catalog(p_case,null,4);
  awarded:=awarded||jsonb_build_array(jsonb_build_object('item',result->'item','dup',result->'dup',
   'shards',case when (result->>'dup')::boolean then private.shard_value(result->'item'->>'rarity') else 0 end));
 end loop;
 insert into private.case_openings(user_id,operation_id,case_id,quantity,results) values(uid,p_operation,p_case,p_quantity,awarded);
 select * into l from public.lockers where user_id=uid;
 return jsonb_build_object('operation',p_operation,'case',p_case,'quantity',p_quantity,'results',awarded,'locker',private.locker_out(l),'retry',false);
end $$;
revoke all on function private.open_cases_v0964(text,integer,uuid) from public,anon;
grant execute on function private.open_cases_v0964(text,integer,uuid) to authenticated;
create or replace function public.open_cases_v0964(p_case text,p_quantity integer,p_operation uuid)
returns jsonb language sql security invoker set search_path='' as $$
 select private.open_cases_v0964(p_case,p_quantity,p_operation);
$$;
revoke all on function public.open_cases_v0964(text,integer,uuid) from public,anon;
grant execute on function public.open_cases_v0964(text,integer,uuid) to authenticated;
