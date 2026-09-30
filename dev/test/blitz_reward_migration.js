// v0.9.4.0 Blitzkrieg Rush rewards on the server: the live claim_match_reward (v0.9.3.8) plus the v0.9.4.0 migration in
// disposable in-memory Postgres with the live table shapes. Never connects to live accounts. node blitz_reward_migration.js
const {PGlite}=require('@electric-sql/pglite'),fs=require('node:fs'),assert=require('node:assert/strict');
const dir=__dirname+'/../supabase/migrations',v0938=fs.readFileSync(dir+'/20260930075446_palisade_v0938_all_boss_milestones.sql','utf8');
const mig=fs.readdirSync(dir).find(f=>/_palisade_v0940_blitz\.sql$/.test(f)),sql=fs.readFileSync(dir+'/'+mig,'utf8');
const U='11111111-1111-4111-8111-111111111111';
const base=`create role anon;create role authenticated;create schema auth;create schema private;
create table auth.users(id uuid primary key);create table public.profiles(id uuid primary key,banned boolean default false);
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
create table public.case_types(id text primary key,name text,weights jsonb,shard_cost integer,modes text[] default '{}',drop jsonb default '{}',sort integer default 0);
create table public.cosmetics(id text primary key,cat text,key text,name text,rarity char(1),src text,need jsonb,box text references public.case_types(id),catalog_version integer default 0);
create table public.lockers(user_id uuid primary key,owned text[] default array['skin:std'],eq jsonb default '{}',cases integer default 1,shards integer default 0,prog integer default 0,
 st jsonb default '{"pvp":0,"wins":0,"drops":0,"raids":0,"endless":0,"pvpWins":0,"hardWins":0}',imported boolean default false,rev integer default 1,updated_at timestamptz default now(),
 bag jsonb default '{}',play_budget real default 22200,budget_at timestamptz default now(),sp integer default 0,sp_prog integer default 0,sp_total integer default 0,skills jsonb default '{}');
create table public.match_results(id bigint generated always as identity primary key,user_id uuid,kind text,mode text,pvp text,diff text,win boolean default false,held integer default 0,kills integer default 0,
 duration_s integer default 0,cases_granted integer default 0,created_at timestamptz default now(),case_id text,bonus integer default 0,shards integer default 0,game_id text,raid_from integer,raid_to integer,
 joined_s integer,left_s integer,left_early boolean,upgrades text,salvage integer,mods text[],map text,size text,shard_bosses integer default 0,skill_points integer default 0,cls text,boss_n integer);
create table public.player_stats(user_id uuid primary key,raids integer default 0,wins integer default 0,drops integer default 0,best_endless integer default 0,pvp integer default 0,pvp_wins integer default 0,updated_at timestamptz default now());
insert into public.case_types(id,name,weights,shard_cost,modes,drop,sort) values('supply','SUPPLY CASE','{"c":60,"r":27,"e":10,"l":3}',null,'{coop}','{}',0),('afterglow','AFTERGLOW CASE','{"c":53,"r":30,"e":12,"l":4,"g":1}',10,'{base,ffa}','{"ffa":{"win":0.5,"loss":0.2},"base":{"win":0.45,"loss":0.2},"boss":{"each":1}}',1),
 ('halloween','HALLOWEEN CASE','{"c":45}',12,'{}','{}',2),('flags','FLAG CASE','{"c":45}',10,'{}','{"win":0}',3);
insert into public.cosmetics values('skin:std','skin','std','Standard','c','free',null,null,0),('skin:arcade','skin','arcade','Arcade','c','case',null,'afterglow',0);
create function private.require_user() returns uuid language plpgsql stable security definer set search_path='' as $f$declare uid uuid:=auth.uid();begin if uid is null then raise exception 'Sign in first';end if;return uid;end$f$;
create function private.num(t text) returns numeric language sql immutable set search_path='' as $f$select case when t ~ '^\\s*-?\\d+(\\.\\d+)?\\s*$' then t::numeric end$f$;
create function private.bag_add(b jsonb,k text,n integer) returns jsonb language sql immutable set search_path='' as $f$select jsonb_set(coalesce(b,'{}'),array[k],to_jsonb(greatest(0,coalesce((b->>k)::int,0)+n)))$f$;
create function private.locker_out(l public.lockers) returns jsonb language sql immutable set search_path='' as $f$select to_jsonb(l)-'user_id'$f$;
create function private.check_rev(l public.lockers,p_rev integer) returns void language plpgsql immutable set search_path='' as $f$begin if p_rev is not null and p_rev<>l.rev then raise exception 'stale';end if;end$f$;
create function private.shard_value(r text) returns integer language sql immutable set search_path='' as $f$select case r when 'c' then 1 when 'r' then 3 when 'e' then 8 when 'l' then 20 when 'g' then 40 else 1 end$f$;
create function private.roll_rarity(w jsonb) returns text language plpgsql set search_path='' as $f$declare tot numeric;x numeric;acc numeric:=0;k record;begin select sum(value::numeric) into tot from jsonb_each_text(w);x:=random()*tot;
 for k in select key,value::numeric v from jsonb_each_text(w) order by value::numeric asc loop acc:=acc+k.v;if x<acc then return k.key;end if;end loop;return 'c';end$f$;
create function private.mod_bonus(p_id text,p_pvp text) returns integer language sql immutable set search_path='' as $f$select case when coalesce(p_pvp,'') in ('base','ffa') then null else
 case p_id when 'nopatch' then 10 when 'alone' then 20 when 'firestorm' then 10 when 'adrenaline' then -15 when 'laststand' then 10 when 'elite' then 15 when 'bossrush' then 10 when 'weather' then 10 when 'nightmare' then 15 when 'berserk' then 10 end end$f$;
create function private.clean_mods(p jsonb,p_pvp text) returns text[] language sql immutable set search_path='' as $f$select coalesce(array_agg(distinct m order by m),'{}'::text[]) from (select value as m from jsonb_array_elements_text(case when jsonb_typeof(p)='array' then p else '[]'::jsonb end) limit 30) s where private.mod_bonus(m,p_pvp) is not null$f$;
create function private.apply_unlocks(p_uid uuid) returns text[] language plpgsql security definer set search_path='' as $f$
declare l public.lockers; c record; got text[] := '{}'; ok boolean; k text;
begin select * into l from public.lockers where user_id = p_uid for update;
  for c in select * from public.cosmetics where src = 'unlock' and not (id = any(l.owned)) loop ok := true;
    for k in select jsonb_object_keys(c.need) loop if coalesce((l.st->>k)::int, 0) < (c.need->>k)::int then ok := false; end if; end loop;
    if ok then l.owned := l.owned || c.id; got := got || c.name; end if; end loop;
  if coalesce(array_length(got, 1), 0) > 0 then update public.lockers set owned = l.owned, rev = rev + 1 where user_id = p_uid; end if; return got; end $f$;
create function private.open_case_catalog(p_case text,p_rev integer,p_catalog integer) returns jsonb language plpgsql security definer set search_path='' as $f$begin return null;end$f$;
create function public.open_case_v0935(p_case text,p_rev integer default null) returns jsonb language sql set search_path='' as $f$select private.open_case_catalog(p_case,p_rev,1)$f$;
insert into auth.users values('${U}');insert into public.profiles(id) values('${U}');`;
const V=['bluebutcher','arsonist','tempest','harbinger','bulldozer'];
(async()=>{const db=new PGlite(),report={migration:mig,checks:[]},ok=(n,c,d)=>{assert.ok(c,n+' '+JSON.stringify(d||''));report.checks.push(n)};
  await db.exec(base);await db.exec(v0938);await db.exec(sql);await db.exec(sql);ok('migration applies on the live v0.9.3.8 function and re-applies',true);
  const reset=async(st)=>{await db.exec(`reset role;delete from public.lockers;delete from public.player_stats;delete from public.match_results;insert into public.lockers(user_id${st?',st':''}) values('${U}'${st?`,'${JSON.stringify(st)}'`:''});insert into public.player_stats(user_id) values('${U}');`)};
  const claim=async c=>{await db.exec(`set role authenticated;select set_config('request.jwt.claim.sub','${U}',false);`);
    const p={kind:'run',mode:'blitz',diff:'normal',kills:40,game_id:'g1',size:'std',mods:[],map:'yard',cls:'soldier',salvage:400,raid_from:0,raid_to:15,held:15,duration_s:1800,win:true,boss_keys:[],fb_keys:[],...c};
    const r=(await db.query('select public.claim_match_reward($1::jsonb) r',[JSON.stringify(p)])).rows[0].r;
    await db.exec(`reset role;update public.match_results set created_at=created_at-interval '1 hour';`);return r};
  const locker=async()=>(await db.query(`select * from public.lockers where user_id='${U}'`)).rows[0];
  const fb10=[...V,...V];
  // 1. made it out: 2 Blitzkrieg Cases per boss (2 on raids 5/10 + 10 in the Final Blitz), +1 for the evac
  await reset();let r=await claim({boss_keys:['bluebutcher','arsonist'],fb_keys:fb10,evac:'evac'});let l=await locker();
  ok('evac: 25 Blitzkrieg Cases (12 bosses x2 + 1)',r.cases.blitz===25&&l.bag.blitz===25,r.cases);
  ok('evac: supply = 15 raids (5) + the 15-raid win (2)',r.cases.supply===7,r.cases);
  ok('evac: skill points = 15/5 + 12 bosses',r.skill_points===15,r.skill_points);
  ok('evac: shards = salvage (10) + 10 x 15-30 + 25',r.shards>=10+150+25&&r.shards<=10+300+25,r.shards);
  ok('evac: a win',l.st.wins===1&&r.left_behind===false,l.st);
  ok('milestones: mode_blitz_bosses 12, base bosses counted',l.st.mode_blitz_bosses===12&&l.st.boss_butcher===3&&l.st.boss_demolisher===3&&l.st.boss_storm===2&&l.st.boss_ferryman===2&&l.st.boss_foreman===2,l.st);
  ok('ladder unlocks at 10 (Devil Horns) and not yet 25',l.owned.includes('hat:devilhorns')&&!l.owned.includes('trail:bluearc'),l.owned);
  // 2. left behind: half of every case and the shards, odd rounded up; raids, bosses, SP, milestones in full
  await reset();r=await claim({boss_keys:['bluebutcher','arsonist'],fb_keys:fb10,evac:'left',win:false});l=await locker();
  ok('left: 24 Blitzkrieg Cases -> 12 (no evac bonus)',r.cases.blitz===12&&l.bag.blitz===12,r.cases);
  ok('left: 5 supply -> 3 (odd rounds up)',r.cases.supply===3&&l.cases===1+3,r.cases);
  ok('left: shards halved, rounded up',r.shards>=Math.ceil((10+150)/2)&&r.shards<=Math.ceil((10+300)/2),r.shards);
  ok('left: skill points never halved',r.skill_points===15,r.skill_points);
  ok('left: raids and boss milestones in full, no win',l.st.raids===15&&l.st.mode_blitz_bosses===12&&l.st.boss_butcher===3&&l.st.wins===0&&r.left_behind===true,l.st);
  const mr=(await db.query(`select mode,fb_n,evac,win from public.match_results`)).rows[0];ok('match record keeps the mode, Final Blitz bosses and evac',mr.mode==='blitz'&&mr.fb_n===10&&mr.evac==='left'&&mr.win===false,mr);
  // 3. rounding: even counts halve exactly (6 -> 3, 8 -> 4); the odd case (5 -> 3) is checked above
  await reset();r=await claim({boss_keys:[],fb_keys:['tempest','harbinger','bulldozer'],evac:'left',win:false,raid_from:14,held:1,duration_s:400});
  ok('left: 6 Blitzkrieg -> 3, 0 supply -> 0',r.cases.blitz===3&&r.cases.supply===0,r.cases);
  await reset();r=await claim({boss_keys:[],fb_keys:['tempest','harbinger','bulldozer','tempest'],evac:'left',win:false,raid_from:14,held:1,duration_s:400,salvage:0});
  ok('left: 8 -> 4',r.cases.blitz===4,r.cases);
  // 4. caps: at most 10 Final Blitz bosses (15 with Double Time), one per 30 s (20 s) of play, no double pay on a second claim
  await reset();r=await claim({fb_keys:[...fb10,...V],evac:'evac'});ok('cap 10',r.fb_bosses===10,r.fb_bosses);
  await reset();r=await claim({fb_keys:[...fb10,...V,'tempest'],evac:'evac',mods:['blitzclock']});ok('Double Time: cap 15',r.fb_bosses===15,r.fb_bosses);
  await reset();r=await claim({fb_keys:fb10,evac:'evac',raid_from:14,held:1,duration_s:110});ok('time: 110 s of play pays at most 4',r.fb_bosses===4,r.fb_bosses);
  await reset();await claim({fb_keys:fb10.slice(0,4),evac:'',raid_to:15,left:true,win:false,duration_s:1500});r=await claim({fb_keys:fb10,evac:'evac',duration_s:1800});
  ok('same game, second claim: only the rest of the cap',r.fb_bosses===6,r.fb_bosses);
  ok('unknown Final Blitz keys are skipped',(await (async()=>{await reset();return (await claim({fb_keys:['butcher','ghost','bluebutcher'],evac:'evac'})).fb_bosses})())===1);
  // 5. evac only counts at raid 15 in Blitzkrieg Rush; other modes ignore it and fb_keys
  await reset();r=await claim({raid_to:10,held:10,evac:'left',win:false,duration_s:1200});ok('evac before raid 15 ignored: nothing halved',r.left_behind===false&&r.cases.supply===3,r.cases);
  await reset();r=await claim({mode:'5',raid_to:5,held:5,win:true,evac:'left',fb_keys:fb10,boss_keys:['butcher'],duration_s:900});
  ok('5 raids: unchanged (fb_keys and evac ignored)',r.left_behind===false&&r.fb_bosses===0&&!r.cases.blitz&&r.cases.halloween===1&&r.cases.supply===2,r.cases);
  // 6. modifiers: Boss Rush isn't on the Blitzkrieg list; the new ones pay their bonus
  await reset();r=await claim({mods:['bossrush','hotlz','scorched','nightmare'],evac:'evac'});ok('blitz mods cleaned and priced',JSON.stringify(r.mods)==='["hotlz","nightmare","scorched"]'&&r.mod_pct===40,r);
  await reset();r=await claim({mode:'10',raid_to:10,held:10,mods:['bossrush','hotlz'],duration_s:1200});ok('co-op mods unchanged (Hot LZ not in co-op)',JSON.stringify(r.mods)==='["bossrush"]'&&r.mod_pct===10,r);
  // 7. the case and the catalog
  const ct=(await db.query(`select * from public.case_types where id='blitz'`)).rows[0];ok('Blitzkrieg Case: 14 shards',ct&&ct.shard_cost===14,ct);
  const cos=(await db.query(`select count(*)::int n,min(catalog_version) v from public.cosmetics where box='blitz'`)).rows[0];ok('10 Blitzkrieg items, catalog 2',cos.n===10&&cos.v===2,cos);
  const lad=(await db.query(`select id,need from public.cosmetics where need ? 'mode_blitz_bosses' order by (need->>'mode_blitz_bosses')::int`)).rows.map(x=>x.id+':'+x.need.mode_blitz_bosses).join();
  ok('ladder 10/25/50/75/100',lad==='hat:devilhorns:10,trail:bluearc:25,skin:bluebutcher:50,fx:hellportal:75,skin:demon:100',lad);
  r=(await db.query(`select has_function_privilege('anon','public.open_case_v094(text,integer)','execute') a,has_function_privilege('authenticated','public.open_case_v094(text,integer)','execute') u,has_function_privilege('anon','public.claim_match_reward(jsonb)','execute') ca`)).rows[0];
  ok('grants: anon denied, signed-in allowed',r.a===false&&r.u===true&&r.ca===false,r);
  await db.close();fs.mkdirSync(__dirname+'/out',{recursive:true});fs.writeFileSync(__dirname+'/out/blitz_reward_migration.json',JSON.stringify(report,null,2));console.log(report);console.log('errors: none');
})().catch(e=>{console.error(e);process.exit(1)});
