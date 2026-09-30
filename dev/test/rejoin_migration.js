// v0.9.3.6 rejoin boss credit: runs the live claim_match_reward (snapshot) and the migration in disposable in-memory
// Postgres with the live table shapes. Never connects to live accounts. node rejoin_migration.js
const {PGlite}=require('@electric-sql/pglite'),fs=require('node:fs'),assert=require('node:assert/strict');
const root=__dirname+'/..',live=fs.readFileSync(root+'/supabase/snapshots/claim_match_reward_live_2026-09-30.sql','utf8');
const migration=fs.readFileSync(root+'/supabase/migrations/20260930071534_palisade_v0936_rejoin_bosses.sql','utf8');
const U='11111111-1111-4111-8111-111111111111';
const base=`create role anon;create role authenticated;create schema auth;create schema private;
create table auth.users(id uuid primary key);create table public.profiles(id uuid primary key,banned boolean default false);
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
create table public.case_types(id text primary key,name text,weights jsonb,shard_cost integer,modes text[] default '{}',drop jsonb default '{}',sort integer default 0);
create table public.cosmetics(id text primary key,cat text,key text,name text,rarity char(1),src text,need jsonb,box text,catalog_version integer default 0);
create table public.lockers(user_id uuid primary key,owned text[] default array['skin:std'],eq jsonb default '{}',cases integer default 1,shards integer default 0,prog integer default 0,
 st jsonb default '{"pvp":0,"wins":0,"drops":0,"raids":0,"endless":0,"pvpWins":0,"hardWins":0}',imported boolean default false,rev integer default 1,updated_at timestamptz default now(),
 bag jsonb default '{}',play_budget real default 22200,budget_at timestamptz default now(),sp integer default 0,sp_prog integer default 0,sp_total integer default 0,skills jsonb default '{}');
create table public.match_results(id bigint generated always as identity primary key,user_id uuid,kind text,mode text,pvp text,diff text,win boolean default false,held integer default 0,kills integer default 0,
 duration_s integer default 0,cases_granted integer default 0,created_at timestamptz default now(),case_id text,bonus integer default 0,shards integer default 0,game_id text,raid_from integer,raid_to integer,
 joined_s integer,left_s integer,left_early boolean,upgrades text,salvage integer,mods text[],map text,size text,shard_bosses integer default 0,skill_points integer default 0,cls text);
create table public.player_stats(user_id uuid primary key,raids integer default 0,wins integer default 0,drops integer default 0,best_endless integer default 0,pvp integer default 0,pvp_wins integer default 0,updated_at timestamptz default now());
insert into public.case_types(id,name,shard_cost,modes,drop,sort) values('supply','SUPPLY CASE',null,'{coop}','{}',0),('afterglow','AFTERGLOW CASE',10,'{base,ffa}','{"ffa":{"win":0.5,"loss":0.2},"base":{"win":0.45,"loss":0.2},"boss":{"each":1}}',1),
 ('halloween','HALLOWEEN CASE',12,'{}','{}',2),('flags','FLAG CASE',10,'{}','{"win":0.25}',3);
create function private.require_user() returns uuid language plpgsql stable security definer set search_path='' as $f$declare uid uuid:=auth.uid();begin if uid is null then raise exception 'Sign in first';end if;return uid;end$f$;
create function private.num(t text) returns numeric language sql immutable set search_path='' as $f$select case when t ~ '^\\s*-?\\d+(\\.\\d+)?\\s*$' then t::numeric end$f$;
create function private.bag_add(b jsonb,k text,n integer) returns jsonb language sql immutable set search_path='' as $f$select jsonb_set(coalesce(b,'{}'),array[k],to_jsonb(greatest(0,coalesce((b->>k)::int,0)+n)))$f$;
create function private.locker_out(l public.lockers) returns jsonb language sql immutable set search_path='' as $f$select to_jsonb(l)-'user_id'$f$;
create function private.mod_bonus(p_id text,p_pvp text) returns integer language sql immutable set search_path='' as $f$select case when coalesce(p_pvp,'') in ('base','ffa') then null else
 case p_id when 'nopatch' then 10 when 'alone' then 20 when 'firestorm' then 10 when 'adrenaline' then -15 when 'laststand' then 10 when 'elite' then 15 when 'bossrush' then 10 when 'weather' then 10 when 'nightmare' then 15 when 'berserk' then 10 end end$f$;
create function private.clean_mods(p jsonb,p_pvp text) returns text[] language sql immutable set search_path='' as $f$select coalesce(array_agg(distinct m order by m),'{}'::text[]) from (select value as m from jsonb_array_elements_text(case when jsonb_typeof(p)='array' then p else '[]'::jsonb end) limit 30) s where private.mod_bonus(m,p_pvp) is not null$f$;
create function private.apply_unlocks(p_uid uuid) returns text[] language sql set search_path='' as $f$select '{}'::text[]$f$;
insert into auth.users values('${U}');insert into public.profiles(id) values('${U}');`;
const fresh=async fn=>{const db=new PGlite();await db.exec(base);await db.exec(live);if(fn)await db.exec(fn);return db};
const claim=async(db,gid,c)=>{
  await db.exec(`delete from public.lockers;delete from public.player_stats;`);
  await db.exec(`insert into public.lockers(user_id) values('${U}') on conflict do nothing;insert into public.player_stats(user_id) values('${U}') on conflict do nothing;`);
  await db.exec(`set role authenticated;select set_config('request.jwt.claim.sub','${U}',false);`);
  const p={kind:'run',mode:'5',diff:'normal',kills:10,game_id:gid,size:'std',mods:[],map:'yard',cls:'soldier',salvage:0,...c};
  const r=(await db.query('select public.claim_match_reward($1::jsonb) r',[JSON.stringify(p)])).rows[0].r;
  await db.exec(`reset role;update public.match_results set created_at=created_at-interval '1 hour';`);return r;
};
const total=(a,b)=>({bosses:(a.bonuses||[]).reduce((s,x)=>s+x.n,0)+(b?(b.bonuses||[]).reduce((s,x)=>s+x.n,0):0),sb:(a.shard_bosses|0)+(b?b.shard_bosses|0:0)});
(async()=>{const report={checks:[]},ok=(name,cond,detail)=>{assert.ok(cond,name+' '+JSON.stringify(detail||''));report.checks.push(name)};
  // Scenario A: leave after raid 4, rejoin, raid-5 Butcher dies after the rejoin.
  const scenA=async db=>{const a=await claim(db,'gA',{raid_from:0,raid_to:4,held:4,left:true,boss_keys:[],duration_s:260});const b=await claim(db,'gA',{raid_from:4,raid_to:5,held:1,boss_keys:['butcher'],duration_s:90});return{a,b,t:total(a,b)}};
  // Scenario B: Boss Rush, leave after raid 3 (raid-2 in-between boss paid), rejoin; raid-4 in-between boss after the rejoin.
  const scenB=async db=>{const a=await claim(db,'gB',{raid_from:0,raid_to:3,held:3,left:true,boss_keys:[],shard_bosses:1,mods:['bossrush'],duration_s:200});
    const b=await claim(db,'gB',{raid_from:3,raid_to:5,held:2,boss_keys:['butcher'],shard_bosses:1,mods:['bossrush'],duration_s:150});return{a,b,t:total(a,b)}};
  // Scenario C: boss already paid before leaving mid raid 5; a repeated key after rejoin must not pay again.
  const scenC=async db=>{const a=await claim(db,'gC',{raid_from:0,raid_to:4,held:4,left:true,boss_keys:['butcher'],duration_s:260});const b=await claim(db,'gC',{raid_from:4,raid_to:5,held:1,boss_keys:['butcher'],duration_s:90});return{a,b,t:total(a,b)}};
  // Scenario D: one uninterrupted XL game with Boss Rush (must be unchanged by the migration).
  const scenD=async db=>{const a=await claim(db,'gD',{raid_from:0,raid_to:5,held:5,size:'xl',boss_keys:['butcher','butcher'],shard_bosses:2,mods:['bossrush'],duration_s:400});return{a,t:total(a)}};
  // Scenario E: XL rejoin, both raid-5 bosses after the rejoin.
  const scenE=async db=>{const a=await claim(db,'gE',{raid_from:0,raid_to:4,held:4,size:'xl',left:true,boss_keys:[],duration_s:300});const b=await claim(db,'gE',{raid_from:4,raid_to:5,held:1,size:'xl',boss_keys:['butcher','butcher'],duration_s:90});return{a,b,t:total(a,b)}};
  const run=async(fn,scen)=>{const db=await fresh(fn);const r=await scen(db);await db.close();return r};
  const before={},after={};for(const [k,s] of Object.entries({A:scenA,B:scenB,C:scenC,D:scenD,E:scenE})){before[k]=(await run(null,s)).t;after[k]=(await run(migration,s)).t}
  report.before=before;report.after=after;
  ok('live function reproduces the lost raid-5 boss after a rejoin',before.A.bosses===0,before.A);
  ok('migration pays the raid-5 boss after a rejoin',after.A.bosses===1,after.A);
  ok('live function reproduces the lost Boss Rush boss after a rejoin',before.B.sb===1,before.B);
  ok('migration pays both Boss Rush bosses across the rejoin',after.B.sb===2&&after.B.bosses===1,after.B);
  ok('a boss paid before leaving is not paid again',after.C.bosses===1,after.C);
  ok('uninterrupted XL Boss Rush game unchanged',JSON.stringify(after.D)===JSON.stringify(before.D)&&after.D.bosses===2&&after.D.sb===2,{before:before.D,after:after.D});
  ok('XL rejoin pays both raid-5 bosses',after.E.bosses===2&&before.E.bosses===0,{before:before.E,after:after.E});
  // v0.9.3.7 synergy: Boss Rush + Nightmare with a second in-between boss on raids 2 and 4 (4 in-between bosses in 5 raids)
  {const db=await fresh(migration);const r=await claim(db,'gG',{raid_from:0,raid_to:5,held:5,boss_keys:['butcher'],shard_bosses:4,mods:['bossrush','nightmare'],duration_s:420});
   ok('four in-between bosses in five Nightmare + Boss Rush raids are all paid',r.shard_bosses===4&&r.boss_shards>=60,r);await db.close()}
  // Fallback: the first claim written by the old function (no boss_n), the second after migrating.
  {const db=await fresh();await claim(db,'gF',{raid_from:0,raid_to:4,held:4,left:true,boss_keys:['butcher'],duration_s:260});await db.exec(migration);
   const b=await claim(db,'gF',{raid_from:4,raid_to:5,held:1,boss_keys:['butcher'],duration_s:90});ok('older rows fall back to their bonus count',total(b).bosses===0,b);
   const row=(await db.query("select boss_n from public.match_results where game_id='gF' order by id")).rows;ok('boss_n recorded for new claims only',row[0].boss_n===null&&row[1].boss_n===0,row);
   await db.exec(migration);ok('migration re-applies cleanly',true);
   const g=await db.query("select has_function_privilege('anon','public.claim_match_reward(jsonb)','execute') a");ok('anon still cannot claim',g.rows[0].a===false);await db.close()}
  fs.mkdirSync(__dirname+'/out',{recursive:true});fs.writeFileSync(__dirname+'/out/rejoin_migration.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,1));console.log('errors: none');
})().catch(e=>{console.error(e);process.exit(1)});
// Compensation script: applies each keyed grant once, even when one player has two rows; a second run grants nothing.
(async()=>{const fs2=require('node:fs'),comp=fs2.readFileSync(__dirname+'/../supabase/compensation/2026-10-01_v0936_rejoin.sql','utf8');
  const {PGlite}=require('@electric-sql/pglite'),db=new PGlite(),A='8d9722ad-313f-4ec1-b389-03bc66c10414',B='589a4a9a-d172-4038-b497-d17877cb5570';
  await db.exec(base.replace(`insert into auth.users values('${U}');insert into public.profiles(id) values('${U}');`,'')+`
   create table public.notifications(id bigint generated always as identity primary key,user_id uuid,kind text,from_id uuid,data jsonb default '{}',created_at timestamptz default now(),seen_at timestamptz);
   insert into public.lockers(user_id,cases,shards,sp,st) values('${A}',0,13,42,'{"raids":402,"boss_ferryman":5}'),('${B}',19,94,10,'{"raids":275}');
   insert into public.player_stats(user_id,raids) values('${A}',402),('${B}',275);`);
  await db.exec(comp);await db.exec(comp);
  const a=(await db.query(`select * from public.lockers where user_id='${A}'`)).rows[0],b=(await db.query(`select * from public.lockers where user_id='${B}'`)).rows[0];
  const n=(await db.query('select count(*)::int n from public.notifications')).rows[0].n,ps=(await db.query(`select raids from public.player_stats where user_id='${A}'`)).rows[0].raids;
  assert.deepEqual({cases:a.cases,hal:a.bag.halloween,shards:a.shards,sp:a.sp,raids:a.st.raids,river:a.st.map_river,cls:a.st.cls_soldier_raids,fer:a.st.boss_ferryman,but:a.st.boss_butcher,ps},
    {cases:13,hal:6,shards:220,sp:61,raids:422,river:20,cls:20,fer:9,but:2,ps:422});
  assert.deepEqual({cases:b.cases,raids:b.st.raids},{cases:19,raids:275});assert.equal(n,2);   // meezy2greezy not part of the approved grant
  await db.close();console.log('compensation script: exact grants once, repeat grants nothing');console.log('errors: none');
})().catch(e=>{console.error(e);process.exit(1)});
