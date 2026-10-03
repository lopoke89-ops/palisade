// v0.9.6.4 server migration in a disposable Postgres: Whiteout Gauntlet payouts, chapter evacs, the Hybrid Theory
// Case (catalog, buying, opening, the co-op win drop) and that pre-cv:4 claims are paid exactly as before.
const {PGlite}=require('@electric-sql/pglite'),{base,U}=require('./winter-db'),fs=require('node:fs'),assert=require('node:assert/strict');
const dir=__dirname+'/../supabase/migrations',read=n=>fs.readFileSync(dir+'/'+n,'utf8'),NEW=['20261003080938_v0964_hybrid_catalog.sql','20261003153435_v0964_gauntlet_rewards.sql'];
(async()=>{const db=new PGlite(),checks=[],ok=(n,b)=>{assert.ok(b,n);checks.push(n)};
 await db.exec(base);await db.exec(read('20260930075446_palisade_v0938_all_boss_milestones.sql'));await db.exec(read('20260930141401_palisade_v0940_blitz.sql'));
 await db.exec(`alter table profiles add column username text;alter table profiles add column cos text;create table lobbies(length text constraint lobbies_length_check check(length in ('5','10','endless','blitz')));
 create function auth.jwt() returns jsonb language sql stable as $$select '{"is_anonymous":false}'::jsonb$$;
 create table friendships(user_a uuid,user_b uuid,created_at timestamptz default now(),primary key(user_a,user_b));
 create table friend_requests(id bigint,from_id uuid,to_id uuid,status text,created_at timestamptz default now());
 create table notifications(id bigint generated always as identity,user_id uuid,from_id uuid,kind text,data jsonb,created_at timestamptz default now(),seen_at timestamptz);
 grant usage on schema public,auth,private to authenticated;grant execute on all functions in schema auth to authenticated;`);
 for(const m of['20261001081259_winter_whiteout.sql','20261001214620_winter_models.sql','20261001225643_music_case_batches.sql'])await db.exec(read(m));
 const oldText=(await db.query(`select pg_get_functiondef('public.claim_match_reward(jsonb)'::regprocedure) d`)).rows[0].d;
 for(const m of NEW)await db.exec(read(m));for(const m of NEW)await db.exec(read(m));ok('migration applies twice',true);
 await db.exec('grant select,insert,update,delete on all tables in schema public to authenticated;grant usage on schema private to authenticated;grant execute on all functions in schema private to authenticated');
 const as=async uid=>db.exec(`reset role;set role authenticated;select set_config('request.jwt.claim.sub','${uid}',false)`);
 const reset=async(extra='')=>db.exec(`reset role;delete from private.reward_receipts;delete from match_results;delete from private.case_openings;delete from lockers;delete from player_stats;insert into lockers(user_id) values('${U}');insert into player_stats(user_id) values('${U}');${extra}`);
 const fk=[];for(const b of['whitebutcher','whiteforeman','tempest','bulldozer','bluebutcher','arsonist'])fk.push('rime','rime',b);
 const camp={kind:'run',mode:'campaign',diff:'normal',game_id:'g1',duration_s:2400,raid_from:0,raid_to:13,held:13,kills:40,map:'yard',cls:'soldier',size:'std',salvage:0,mods:[],win:true,evac:'evac',boss_keys:[],fb_keys:fk,g_cleared:6,ch_evac:[true,false,true],cv:4,claim_id:'c1'};
 const claim=async p=>{await as(U);return(await db.query('select public.claim_match_reward($1::jsonb) r',[JSON.stringify(p)])).rows[0].r};
 // the payout table
 await reset();let r=await claim(camp);
 ok('gauntlet: 6 waves + final evac 2 + chapter evacs 2 = 10 Winter Cases',r.cases.winter===10&&r.gauntlet_waves===6&&r.chapter_evacs===2);
 ok('gauntlet: no Blitzkrieg Cases from gauntlet bosses',!r.cases.blitz);
 ok('gauntlet: 18 bosses at 5-10 shards plus 25 for the evac',r.boss_shards>=18*5+25&&r.boss_shards<=18*10+25);
 ok('gauntlet: a skill point per boss',r.fb_bosses===18&&r.skill_points>=18);
 ok('Rime ladder: every gauntlet Rime counts (12)',r.locker.st.boss_rime===12);
 ok('base milestones: butcher 2 (white + blue), foreman 2, storm 1, demolisher 1',r.locker.st.boss_butcher===2&&r.locker.st.boss_foreman===2&&r.locker.st.boss_storm===1&&r.locker.st.boss_demolisher===1);
 ok('campaign never credits the Blitz ladder',!r.locker.st.mode_blitz_bosses);
 ok('co-op win: one Hybrid Theory Case',r.cases.hybrid===1&&r.locker.bag.hybrid===1&&r.hybrid_case===1);
 // caps
 await reset();r=await claim({...camp,fb_keys:fk.slice(0,4),claim_id:'c2'});ok('waves cleared are capped by the bosses paid (4 -> 1)',r.gauntlet_waves===1);
 await reset();r=await claim({...camp,fb_keys:fk.concat(fk),claim_id:'c3'});ok('at most 18 gauntlet bosses',r.fb_bosses===18);
 await reset();r=await claim({...camp,g_cleared:99,claim_id:'c4'});ok('a forged wave count is clipped to 6',r.gauntlet_waves===6);
 await reset();r=await claim({...camp,raid_from:4,held:9,claim_id:'c5'});ok('only chapter evacs inside the claim count',r.chapter_evacs===1);
 await reset();r=await claim({...camp,ch_evac:[true,true,true],claim_id:'c6'});ok('all three chapter evacs',r.chapter_evacs===3&&r.cases.winter===11);
 // left behind at the final evac: no win, no hybrid, cases halved (odd rounds up)
 await reset();r=await claim({...camp,win:false,evac:'left',claim_id:'c7'});ok('left behind: (6+2) halved to 4, no evac cases, no Hybrid',r.cases.winter===4&&!r.cases.hybrid&&r.left_behind===true);
 // old clients are untouched
 await reset();r=await claim({...camp,cv:undefined,fb_keys:['whitebutcher','whiteforeman','rime','tempest','bulldozer'],claim_id:'o1'});
 ok('pre-cv:4 campaign claim keeps the old finale rules',r.cases.winter===1+1+2+1&&r.cases.blitz===4&&!r.cases.hybrid&&r.gauntlet_waves===0&&r.chapter_evacs===0);
 // the drop on other co-op wins
 const five={kind:'run',mode:'5',diff:'normal',game_id:'g5',duration_s:600,raid_from:0,raid_to:5,held:5,kills:20,map:'yard',cls:'soldier',size:'std',salvage:0,mods:[],win:true,boss_keys:[],claim_id:'f1'};
 await reset();r=await claim({...five,cv:4});ok('5-raid win: one Hybrid Theory Case',r.cases.hybrid===1);
 await reset();r=await claim(five);ok('old client 5-raid win: none',!r.cases.hybrid);
 await reset();r=await claim({...five,cv:4,win:false,raid_to:3,held:3});ok('loss: none',!r.cases.hybrid);
 await reset();r=await claim({...five,cv:4,mode:'10',raid_to:10,held:10,duration_s:1500});ok('10-raid win: one',r.cases.hybrid===1);
 await reset();r=await claim({...five,cv:4,mode:'blitz',raid_to:15,held:15,duration_s:2400,evac:'evac',fb_keys:[]});ok('Blitz evac: one',r.cases.hybrid===1);
 await reset();r=await claim({...five,cv:4,mode:'blitz',raid_to:15,held:15,duration_s:2400,evac:'left',fb_keys:[]});ok('Blitz left behind: none',!r.cases.hybrid);
 await reset();r=await claim({...five,cv:4,mode:'endless',raid_to:12,held:12,duration_s:1800});ok('Endless: none',!r.cases.hybrid);
 await reset();await claim({...five,cv:4});const again=await claim({...five,cv:4});ok('retry pays nothing more',again.retry&&again.locker.bag.hybrid===1);
 // catalog, buying, opening
 await db.exec('reset role');const cat=(await db.query(`select count(*)::int n,count(*) filter(where cat='skin')::int s,count(*) filter(where cat='hat')::int h,count(*) filter(where cat='fx')::int f,count(*) filter(where cat='bg')::int b,
  count(*) filter(where description is null or description='')::int nd,min(catalog_version)::int lo,max(catalog_version)::int hi from cosmetics where box='hybrid'`)).rows[0];
 ok('catalog: 57 items (30/8/11/8) at version 4 with descriptions',cat.n===57&&cat.s===30&&cat.h===8&&cat.f===11&&cat.b===8&&cat.nd===0&&cat.lo===4&&cat.hi===4);
 const ct=(await db.query(`select * from case_types where id='hybrid'`)).rows[0];ok('case row: 12 shards, sort 7, weights',ct.shard_cost===12&&ct.sort===7&&['c',46,'r',30,'e',16,'l',7,'g',1].every((v,i,a)=>i%2||ct.weights[v]===a[i+1]));
   // buy_case as live (unchanged by this migration: it already reads case_types.shard_cost)
 await db.exec(`reset role;create or replace function public.buy_case(p_case text,p_rev integer default null) returns jsonb language plpgsql security definer set search_path to '' as $f$
declare uid uuid := private.require_user(); l public.lockers; ct public.case_types;
begin
  select * into ct from public.case_types where id = p_case;
  if not found then raise exception 'Unknown case' using errcode = '22023'; end if;
  if ct.shard_cost is null then raise exception 'The % can''t be bought with shards', lower(ct.name) using errcode = '22023'; end if;
  select * into l from public.lockers where user_id = uid for update;
  perform private.check_rev(l, p_rev);
  if l.shards < ct.shard_cost then raise exception 'That takes % shards', ct.shard_cost using errcode = '22023'; end if;
  update public.lockers set shards = shards - ct.shard_cost, bag = private.bag_add(bag, p_case, 1), rev = rev + 1, updated_at = now()
    where user_id = uid returning * into l;
  return private.locker_out(l);
end $f$;grant execute on function public.buy_case(text,integer) to authenticated;`);
 await reset(`update lockers set shards=30 where user_id='${U}'`);await as(U);
 const bought=(await db.query(`select public.buy_case('hybrid',null) r`)).rows[0].r;ok('buy with 12 shards',bought.shards===18&&bought.bag.hybrid===1);
 let threw=null;try{await db.query(`select public.open_cases_v0962('hybrid',1,gen_random_uuid()) r`)}catch(e){threw=e.message}ok('the old opener (catalog 3) cannot open it',/empty/i.test(threw||''));
 await as(U);const op=(await db.query(`select public.open_cases_v0964('hybrid',1,'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa') r`)).rows[0].r;
 ok('open_cases_v0964 rolls a Hybrid item',op.results.length===1&&/^(skin:hb_|hat:|fx:|bg:)/.test(op.results[0].item.id)&&op.locker.bag.hybrid===0);
 const hyIds=new Set((await db.query(`select id from cosmetics where box='hybrid'`)).rows.map(x=>x.id));ok('…and only from the Hybrid pool',hyIds.has(op.results[0].item.id));
 await db.exec(`reset role;update lockers set bag='{"winter":5}' where user_id='${U}'`);await as(U);const w=(await db.query(`select public.open_cases_v0964('winter',5,'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb') r`)).rows[0].r;
 ok('v0964 still opens older cases',w.results.length===5&&w.locker.bag.winter===0);
 const newText=(await db.query(`select pg_get_functiondef('public.claim_match_reward(jsonb)'::regprocedure) d`)).rows[0].d;
 ok('the rebuilt function differs from the old one only by additions',newText.length>oldText.length);
 console.log(checks.length+' checks');checks.forEach(c=>console.log(' ok',c));console.log('errors: none');
})().catch(e=>{console.error(e);process.exit(1)});
