// v0.9.3.9: buy_case_sp (3 unspent skill points -> 1 Supply Case) in disposable in-memory Postgres with the live
// skill functions. Never connects to live accounts. node sp_cases_migration.js
const {PGlite}=require('@electric-sql/pglite'),fs=require('node:fs'),assert=require('node:assert/strict');
const mig=fs.readdirSync(__dirname+'/../supabase/migrations').find(f=>/_palisade_v0939_sp_cases\.sql$/.test(f)),sql=fs.readFileSync(__dirname+'/../supabase/migrations/'+mig,'utf8');
const U='11111111-1111-4111-8111-111111111111',B='22222222-2222-4222-8222-222222222222';
(async()=>{const db=new PGlite(),report={migration:mig,checks:[]},ok=(n,c,d)=>{assert.ok(c,n+' '+JSON.stringify(d||''));report.checks.push(n)};
await db.exec(`create role anon;create role authenticated;create schema auth;create schema private;
create table auth.users(id uuid primary key);create table public.profiles(id uuid primary key,banned boolean default false);
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
create table public.lockers(user_id uuid primary key,cases integer default 1,shards integer default 0,sp integer default 0,sp_prog integer default 0,sp_total integer default 0,skills jsonb default '{}',rev integer default 1,updated_at timestamptz default now());
create function private.require_user() returns uuid language plpgsql stable security definer set search_path='' as $f$declare uid uuid:=auth.uid();begin
 if uid is null then raise exception 'Sign in first' using errcode='28000';end if;if exists(select 1 from public.profiles where id=uid and banned) then raise exception 'This account is banned' using errcode='42501';end if;return uid;end$f$;
create function private.check_rev(l public.lockers,p_rev integer) returns void language plpgsql immutable set search_path='' as $f$begin if p_rev is not null and p_rev<>l.rev then raise exception 'Your locker changed on another device; refresh and try again' using errcode='40001';end if;end$f$;
create function private.locker_out(l public.lockers) returns jsonb language sql immutable set search_path='' as $f$select to_jsonb(l)-'user_id'$f$;
create function private.skill_defs() returns jsonb language sql immutable set search_path='' as $f$select '{"dmg":{"cost":[1,2,3]},"rate":{"cost":[1,2,3]},"hp":{"cost":[1,2,3]}}'::jsonb$f$;
create function private.respec_cost() returns integer language sql immutable set search_path='' as $f$ select 40 $f$;
create function private.skill_spent(t jsonb) returns integer language sql immutable set search_path='' as $f$
  select coalesce(sum((d.value->'cost'->>(l - 1))::int), 0)::int from jsonb_each(private.skill_defs()) d
  cross join lateral generate_series(1, least(coalesce((t->>d.key)::int, 0), jsonb_array_length(d.value->'cost'))) l$f$;
create function public.skill_buy(p_node text,p_rev integer default null) returns jsonb language plpgsql security definer set search_path='' as $f$
declare uid uuid:=private.require_user();l public.lockers;d jsonb:=private.skill_defs()->p_node;lv int;cost int;begin
 select * into l from public.lockers where user_id=uid for update;perform private.check_rev(l,p_rev);lv:=coalesce((l.skills->>p_node)::int,0);cost:=(d->'cost'->>lv)::int;
 if l.sp<cost then raise exception 'That takes % skill points',cost using errcode='22023';end if;
 update public.lockers set sp=sp-cost,skills=jsonb_set(skills,array[p_node],to_jsonb(lv+1)),rev=rev+1 where user_id=uid returning * into l;return private.locker_out(l);end$f$;
create function public.skill_respec(p_rev integer default null) returns jsonb language plpgsql security definer set search_path='' as $f$
declare uid uuid:=private.require_user();l public.lockers;back int;cost int:=private.respec_cost();begin
 select * into l from public.lockers where user_id=uid for update;perform private.check_rev(l,p_rev);back:=private.skill_spent(l.skills);
 if back=0 then raise exception 'There are no points in your tree' using errcode='22023';end if;if l.shards<cost then raise exception 'Resetting takes % shards',cost using errcode='22023';end if;
 update public.lockers set sp=sp+back,skills='{}'::jsonb,shards=shards-cost,rev=rev+1 where user_id=uid returning * into l;return private.locker_out(l);end$f$;
insert into auth.users values('${U}'),('${B}');insert into public.profiles(id) values('${U}'),('${B}');
insert into public.lockers(user_id,cases,shards,sp,sp_total) values('${U}',0,100,20,20),('${B}',0,0,9,9);`);
await db.exec(sql);await db.exec(sql);ok('migration applies and re-applies',true);
const as=async id=>db.exec(`set role authenticated;select set_config('request.jwt.claim.sub','${id}',false);`);
const call=async(q,a=[])=>(await db.query(q,a)).rows[0];
await as(U);
let r=(await call('select public.buy_case_sp() r')).r;ok('3 SP buys one Supply Case',r.sp===17&&r.cases===1&&r.sp_total===20,r);
for(let i=0;i<4;i++)r=(await call('select public.buy_case_sp() r')).r;ok('no cap: repeated purchases',r.sp===5&&r.cases===5,r);
await assert.rejects(call('select public.buy_case_sp(1)'),/changed on another device/);ok('stale revision refused',true);
r=(await call("select public.skill_buy('dmg') r")).r;r=(await call("select public.skill_buy('dmg') r")).r;ok('tree spend works alongside',r.sp===2&&r.skills.dmg===2,r);
await assert.rejects(call('select public.buy_case_sp()'),/takes 3 skill points/);ok('fewer than 3 unspent SP refused (tree points untouched)',true);
r=(await call('select public.skill_respec() r')).r;ok('reset refunds only the tree (3), never the 15 traded',r.sp===5&&r.cases===5&&JSON.stringify(r.skills)==='{}',r);
await db.exec('reset role');const b0=(await call(`select sp,cases from public.lockers where user_id='${B}'`));ok('other accounts untouched',b0.sp===9&&b0.cases===0,b0);
await db.exec(`update public.profiles set banned=true where id='${B}'`);await as(B);await assert.rejects(call('select public.buy_case_sp()'),/banned/);ok('banned account refused',true);
await db.exec("select set_config('request.jwt.claim.sub','',false)");await assert.rejects(call('select public.buy_case_sp()'),/Sign in/);ok('missing identity refused',true);
await db.exec('reset role');r=await call("select has_function_privilege('anon','public.buy_case_sp(integer)','execute') a,has_function_privilege('authenticated','public.buy_case_sp(integer)','execute') u");
ok('anon denied, signed-in allowed',r.a===false&&r.u===true,r);
await db.close();fs.mkdirSync(__dirname+'/out',{recursive:true});fs.writeFileSync(__dirname+'/out/sp_cases_migration.json',JSON.stringify(report,null,2));console.log(report);console.log('errors: none');
})().catch(e=>{console.error(e);process.exit(1)});
