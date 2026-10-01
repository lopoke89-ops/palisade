// Disposable Postgres checks for the special-ammo skill gates and respec accounting.
const {PGlite}=require('@electric-sql/pglite'),fs=require('node:fs'),assert=require('node:assert/strict');
const file=fs.readdirSync(__dirname+'/../supabase/migrations').find(x=>/_ammo_armory_expansion\.sql$/.test(x));
const sql=fs.readFileSync(__dirname+'/../supabase/migrations/'+file,'utf8');
const U='11111111-1111-4111-8111-111111111111';
(async()=>{const db=new PGlite(),checks=[];const ok=(name,test)=>{assert.ok(test,name);checks.push(name)};
  await db.exec(`create role anon;create role authenticated;create schema auth;create schema private;
  create table public.lockers(user_id uuid primary key,sp integer not null,sp_total integer not null,skills jsonb not null default '{}'::jsonb,shards integer not null default 100,rev integer not null default 1,updated_at timestamptz default now());
  create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
  create function private.require_user() returns uuid language plpgsql stable security definer set search_path='' as $f$declare uid uuid:=auth.uid();begin if uid is null then raise exception 'Sign in first';end if;return uid;end$f$;
  create function private.check_rev(l public.lockers,p_rev integer) returns void language plpgsql immutable set search_path='' as $f$begin if p_rev is not null and p_rev<>l.rev then raise exception 'Revision changed';end if;end$f$;
  create function private.locker_out(l public.lockers) returns jsonb language sql immutable set search_path='' as $f$select to_jsonb(l)-'user_id'$f$;
  create function private.skill_defs() returns jsonb language sql immutable set search_path='' as $f$select '{}'::jsonb$f$;
  create function private.skill_spent(t jsonb) returns integer language sql immutable set search_path='' as $f$
    select coalesce(sum((d.value->'cost'->>(l - 1))::int), 0)::int from jsonb_each(private.skill_defs()) d
    cross join lateral generate_series(1, least(coalesce((t->>d.key)::int, 0), jsonb_array_length(d.value->'cost'))) l$f$;
  create function public.skill_respec() returns jsonb language plpgsql security definer set search_path='' as $f$
  declare uid uuid:=private.require_user();l public.lockers;back int;begin select * into l from public.lockers where user_id=uid for update;
    back:=private.skill_spent(l.skills);update public.lockers set sp=sp+back,skills='{}'::jsonb,shards=shards-40,rev=rev+1 where user_id=uid returning * into l;return private.locker_out(l);end$f$;
  insert into public.lockers(user_id,sp,sp_total) values('${U}',20,4);`);
  await db.exec(sql);await db.exec(sql);checks.push('migration applies twice');
  // Exercise the deployed respec body, including its empty-tree refusal.
  const live=JSON.parse(fs.readFileSync(__dirname+'/../supabase/snapshots/20261001_before_ammo_armory.json','utf8'));
  await db.exec(`create function private.respec_cost() returns integer language sql immutable as $$select 40$$;`);
  await db.exec(live.find(x=>x.signature==='skill_respec(integer)').definition);
  await db.exec('drop function public.skill_respec()');
  await db.exec(`set role authenticated;select set_config('request.jwt.claim.sub','${U}',false);`);
  const call=async q=>(await db.query(q)).rows[0].r;
  await assert.rejects(call("select public.skill_buy('ammo_fire') r"),/Earn 5 lifetime/);checks.push('tier 1 gate');
  const earn=async n=>db.exec(`reset role;update public.lockers set sp_total=${n} where user_id='${U}';set role authenticated;`);
  await earn(5);
  let r=await call("select public.skill_buy('ammo_fire') r");ok('tier 1 costs 1 SP',r.sp===19&&r.skills.ammo_fire===1);
  await assert.rejects(call("select public.skill_buy('ammo_fire') r"),/Earn 10 lifetime/);checks.push('tier 2 gate');
  for(const [earned,rank,left] of [[10,2,17],[15,3,14],[20,4,10]]){
    await earn(earned-1);await assert.rejects(call("select public.skill_buy('ammo_fire') r"),new RegExp('Earn '+earned+' lifetime'));checks.push('tier '+rank+' refuses one point early');
    await earn(earned);
    r=await call("select public.skill_buy('ammo_fire') r");ok('tier '+rank+' costs its rank in SP',r.skills.ammo_fire===rank&&r.sp===left);
  }
  await assert.rejects(call("select public.skill_buy('ammo_fire') r"),/maxed/);checks.push('rank 5 refused');
  r=await call('select public.skill_respec() r');ok('respec refunds exactly 10 SP and preserves lifetime earned',r.sp===20&&r.sp_total===20&&Object.keys(r.skills).length===0);
  await assert.rejects(call('select public.skill_respec() r'),/There are no points/);checks.push('second respec refused');
  await assert.rejects(call("select public.skill_buy('ammo_ap',1) r"),/Revision changed/);checks.push('stale revision refused');
  await assert.rejects(call("select public.skill_buy('unknown') r"),/Unknown skill/);checks.push('unknown node refused');
  await db.exec(`reset role;update public.lockers set sp=0 where user_id='${U}';set role authenticated;`);
  await assert.rejects(call("select public.skill_buy('ammo_ap') r"),/takes 1 skill point/);checks.push('unspent SP still required');
  await db.exec('reset role');const priv=(await db.query("select has_function_privilege('anon','public.skill_buy(text,integer)','execute') a,has_function_privilege('authenticated','public.skill_buy(text,integer)','execute') u")).rows[0];
  ok('only authenticated can buy',!priv.a&&priv.u);
  await db.close();console.log(JSON.stringify({migration:file,checks}));console.log('errors: none');
})().catch(e=>{console.error(e);process.exit(1)});
