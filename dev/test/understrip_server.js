// v0.12 THE UNDERSTRIP server migration (dev/supabase/migrations/20261104200000_v012_understrip.sql) in a disposable
// Postgres built on the live chain (as blackout_migration.js builds it). Never connects to the live database.
// 1. import_local_save brings in only free cosmetics: a save listing a case skin, an unlock, 1000 shards, cases, a bag and
//    stats changes nothing but the free item and its equipment; a second import is refused.
// 2. The UNDERSTRIP CASE: its weights and cost, its 30 items in their tiers (case_items.csv), every weighted tier stocked;
//    open_cases_v012 opens one and awards one of its items; older catalogs never see them.
// 3. UNDERSTRIP claims (cv:6), with v0.12.3's scaling (20261104230000): regions pay 1, 3 and 6, the win 10 more, so a won
//    run pays 20 cases, 20 shards and 10 skill points; a run split by a rejoin pays the same in
//    total; a failed run pays by depth; claims replayed or too fast, and cv:5 claims of the mode, pay nothing extra.
// 4. room_register and lobbies accept the mode; other modes' claims are unchanged.
const {PGlite}=require('@electric-sql/pglite'),{base,U}=require('./winter-db'),fs=require('node:fs'),assert=require('node:assert/strict');
const dir=__dirname+'/../supabase/migrations',read=n=>fs.readFileSync(dir+'/'+n,'utf8'),MIG='20261104200000_v012_understrip.sql',MIG3='20261104230000_v0123_understrip_scaling_rewards.sql';
const csv=fs.readFileSync(__dirname+'/../plans/understrip/tables/case_items.csv','utf8').trim().split('\n').slice(1).map(l=>l.split(','));
(async()=>{const db=new PGlite(),checks=[],ok=(n,b)=>{assert.ok(b,n);checks.push(n)};
 await db.exec(base);await db.exec(read('20260930075446_palisade_v0938_all_boss_milestones.sql'));await db.exec(read('20260930141401_palisade_v0940_blitz.sql'));
 await db.exec(`alter table profiles add column username text;alter table profiles add column cos text;create table lobbies(length text constraint lobbies_length_check check(length in ('5','10','endless','blitz')));
 create function auth.jwt() returns jsonb language sql stable as $$select '{"is_anonymous":false}'::jsonb$$;
 create table friendships(user_a uuid,user_b uuid,created_at timestamptz default now(),primary key(user_a,user_b));
 create table friend_requests(id bigint,from_id uuid,to_id uuid,status text,created_at timestamptz default now());
 create table notifications(id bigint generated always as identity,user_id uuid,from_id uuid,kind text,data jsonb,created_at timestamptz default now(),seen_at timestamptz);
 grant usage on schema public,auth,private to authenticated;grant execute on all functions in schema auth to authenticated;`);
 for(const m of['20261001081259_winter_whiteout.sql','20261001214620_winter_models.sql','20261001225643_music_case_batches.sql','20261001081316_friend_lobby_invites.sql','20261003040401_room_register_any_yard_proto.sql',
   '20261003080938_v0964_hybrid_catalog.sql','20261003153435_v0964_gauntlet_rewards.sql','20261003200000_v097_city_blackout.sql','20261005200100_v0100_casino_rooms.sql'])await db.exec(read(m));
 // the live import_local_save (schema.sql) before the fix, and a free item and an unlock in the catalogue to test it with
 const schema=fs.readFileSync(__dirname+'/../supabase/schema.sql','utf8'),imp=schema.slice(schema.indexOf('CREATE OR REPLACE FUNCTION public.import_local_save'),schema.indexOf('CREATE OR REPLACE FUNCTION public.open_case_of'));
 await db.exec(imp);
 await db.exec(`insert into cosmetics values('hat:cap','hat','cap','Cap','c','free',null,null,0),('skin:nightshift2','skin','nightshift2','Night','r','unlock','{"bo_pois":10}',null,5) on conflict do nothing`);
 const claimBefore=(await db.query(`select pg_get_functiondef('public.claim_match_reward(jsonb)'::regprocedure) d`)).rows[0].d;
 await db.exec(read(MIG));await db.exec(read(MIG));await db.exec(read(MIG3));await db.exec(read(MIG3));await db.exec(read(MIG));ok('the migrations apply twice, in either order after the first',true);
 await db.exec('grant select,insert,update,delete on all tables in schema public to authenticated;grant usage on schema private to authenticated;grant execute on all functions in schema private to authenticated;grant execute on all functions in schema public to authenticated');
 const as=async uid=>db.exec(`reset role;set role authenticated;select set_config('request.jwt.claim.sub','${uid}',false)`);
 const reset=async()=>db.exec(`reset role;delete from private.reward_receipts;delete from match_results;delete from private.case_openings;delete from lockers;delete from player_stats;insert into lockers(user_id,eq) values('${U}','{"skin":"std","hat":"class","trail":"std","fx":"none"}');insert into player_stats(user_id) values('${U}') on conflict do nothing;insert into profiles(id) values('${U}') on conflict do nothing`);
 const locker=async()=>{await db.exec('reset role');return(await db.query(`select * from lockers where user_id='${U}'`)).rows[0]};
 // 1. import_local_save
 await reset();const L0=await locker();await as(U);
 const save={owned:['skin:std','hat:cap','skin:visitor','skin:nightshift2','skin:arcade'],eq:{skin:'visitor',hat:'cap',trail:'std',fx:'none'},cases:50,shards:1000,bag:{understrip:50,afterglow:50},prog:2,st:{raids:9999,wins:999,bo_pois:999}};
 await db.query('select public.import_local_save($1::jsonb)',[JSON.stringify(save)]);const L1=await locker();
 ok('import: the free item comes in',L1.owned.includes('hat:cap'));
 ok('import: case items and unlocks do not',!L1.owned.includes('skin:visitor')&&!L1.owned.includes('skin:nightshift2')&&!L1.owned.includes('skin:arcade'));
 ok('import: no shards, cases, bag or stats',L1.shards===L0.shards&&L1.cases===L0.cases&&JSON.stringify(L1.bag)===JSON.stringify(L0.bag)&&JSON.stringify(L1.st)===JSON.stringify(L0.st)&&L1.prog===L0.prog);
 ok('import: equipment only of what came in',L1.eq.hat==='cap'&&L1.eq.skin==='std'&&L1.imported===true);
 await as(U);let refused=false;try{await db.query('select public.import_local_save($1::jsonb)',[JSON.stringify(save)])}catch(e){refused=/already/.test(e.message)}ok('import: once only',refused);
 // 2. the case
 await db.exec('reset role');const ct=(await db.query(`select * from case_types where id='understrip'`)).rows[0];
 ok('the case: weights and 15 shards',['c','r','e','l','g'].map(k=>ct.weights[k]).join()==='40,32,18,8,2'&&ct.shard_cost===15);
 const items=(await db.query(`select id,cat,name,rarity,src,catalog_version from cosmetics where box='understrip' order by id`)).rows;
 ok('the case: 30 items',items.length===30);
 for(const [id,cat,name,r]of csv){const it=items.find(i=>i.id===id);ok(`${id} as in case_items.csv`,!!it&&it.cat===cat&&it.rarity===r&&it.src==='case'&&it.catalog_version===6&&it.name===name.replace(/''/g,"'"))}
 for(const r of Object.keys(ct.weights))ok('tier '+r+' stocked',items.some(i=>i.rarity===r));
 await reset();await db.exec(`update lockers set bag='{"understrip":6}' where user_id='${U}'`);await as(U);
 const op=await db.query(`select public.open_cases_v012('understrip',5,'00000000-0000-4000-8000-000000000001'::uuid) r`);const res=op.rows[0].r;
 ok('open_cases_v012: five understrip items',res.results.length===5&&res.results.every(x=>items.some(i=>i.id===x.item.id)));
 const op2=(await db.query(`select public.open_cases_v012('understrip',5,'00000000-0000-4000-8000-000000000001'::uuid) r`)).rows[0].r;ok('open_cases_v012: a repeat is the first answer',op2.retry===true&&JSON.stringify(op2.results)===JSON.stringify(res.results));
 ok('open_cases_v012: the bag goes down by five',(await locker()).bag.understrip===1);
 await as(U);let old=false;try{const r=(await db.query(`select public.open_cases_v0964('understrip',1,'00000000-0000-4000-8000-000000000002'::uuid) r`)).rows[0].r;old=false&&r}catch(e){old=/empty/i.test(e.message)}
 ok('older openers (catalog 4) never hand out catalog 6 items',old);
 // 3. claims
 const claim=async p=>{await as(U);return(await db.query('select public.claim_match_reward($1::jsonb) r',[JSON.stringify(p)])).rows[0].r};
 const run=(o)=>({kind:'run',mode:'understrip',cv:6,diff:'normal',game_id:'u1',duration_s:2700,raid_from:0,raid_to:10,held:10,kills:120,map:'understrip',cls:'soldier',size:'std',salvage:0,mods:[],win:true,boss_keys:[],claim_id:'c1',...o});
 await reset();let r=await claim(run({}));let L=await locker();
 ok('a won run: 20 UNDERSTRIP CASES (1+3+6, and 10 for the win)',L.bag.understrip===20&&r.us_cases===20&&r.cases.understrip===20);
 ok('a won run: 20 shards for the three regions (2+6+12)',r.boss_shards===20&&L.shards>=20);ok('a won run: 3 regions, 10 skill points for them (and the raids)',r.us_regions===3&&r.skill_points>=10);
 ok('a won run: the ladder counts',L.st.us_regions===3&&L.st.us_wins===1);
 const again=await claim(run({}));ok('the same claim again is the first answer',again.retry===true&&(await locker()).bag.understrip===20);
 // split by a rejoin: 0-4, then 4-10 in the same game
 await reset();await claim(run({raid_to:4,held:4,win:false,duration_s:1000,claim_id:'s1'}));await db.exec(`reset role;update match_results set created_at=now()-interval '1 minute'`);
 r=await claim(run({raid_from:4,raid_to:10,held:6,duration_s:1800,claim_id:'s2'}));L=await locker();
 ok('a split run pays the same: 20 cases (1, then 3+6+10)',L.bag.understrip===20&&L.st.us_regions===3);
 // failed at level 7: two regions
 await reset();r=await claim(run({raid_to:7,held:7,win:false,duration_s:1500,claim_id:'f1'}));L=await locker();
 ok('a failed run pays by depth: 4 cases (1+3), 8 shards',L.bag.understrip===4&&r.boss_shards===8&&!L.st.us_wins);
 // too fast
 await reset();let fast=false;try{await claim(run({duration_s:300,claim_id:'q1'}))}catch(e){fast=/add up/.test(e.message)}ok('ten levels in five minutes is refused',fast);
 await reset();r=await claim(run({duration_s:700,claim_id:'q2'}));L=await locker();ok('a win under 15 minutes isn\'t a win (10 region cases, not the 10 for the win)',L.bag.understrip===10&&!L.st.us_wins);
 await reset();let cv5=false;try{await claim(run({cv:5,claim_id:'v5'}))}catch(e){cv5=/Unknown mode/.test(e.message)}ok('an older client (cv:5) can\'t claim the mode',cv5);
 // other modes: the function's text only grew by the understrip lines
 const claimAfter=(await db.query(`select pg_get_functiondef('public.claim_match_reward(jsonb)'::regprocedure) d`)).rows[0].d;
 const lost=claimBefore.split('\n').filter(l=>l.trim()&&!claimAfter.includes(l));
 ok('the claim function keeps every line but the six it extends (the mode list, the level count, boss cases, skill points, the bag, the cases)',lost.length===6)
 await reset();r=await claim({kind:'run',mode:'10',diff:'normal',game_id:'b1',duration_s:900,raid_from:0,raid_to:10,held:10,kills:60,map:'yard',cls:'soldier',size:'std',salvage:0,mods:[],win:true,boss_keys:[],claim_id:'y1',cv:5});
 ok('a 10-raid run still pays as before (no UNDERSTRIP CASE)',r.cases_granted>=1&&!(await locker()).bag.understrip);
 // 4. rooms
 await as(U);const rr=(await db.query(`select public.room_register($1::jsonb) r`,[JSON.stringify({incarnation:'00000000-0000-4000-8000-0000000000aa',proto:'yard-31',code:'ABCD',mode:'coop',map:'understrip',length:'understrip',players:2})])).rows[0].r;
 ok('room_register takes an UNDERSTRIP room',rr.registered===true);
 await db.exec('reset role');await db.exec(`insert into lobbies(length) values('understrip')`);ok('lobbies take the mode',true);
 console.log(checks.length+' checks');console.log('PASS understrip_server; errors: none');
})().catch(e=>{console.error(e);process.exit(1)});
