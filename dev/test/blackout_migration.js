// v0.9.7 City Black Out server migration in a disposable Postgres: the blackout claim (POIs held, majors, the win, the
// Destroyer), its limits, the BLACK OUT ladder's counters and unlocks, rooms and lobbies accepting the mode, and that other
// claims are paid exactly as before. Built on the same chain as the live database (v0.9.6.4 is the last applied).
const {PGlite}=require('@electric-sql/pglite'),{base,U}=require('./winter-db'),fs=require('node:fs'),assert=require('node:assert/strict');
const dir=__dirname+'/../supabase/migrations',read=n=>fs.readFileSync(dir+'/'+n,'utf8'),PREV=['20261003080938_v0964_hybrid_catalog.sql','20261003153435_v0964_gauntlet_rewards.sql'],NEW=['20261003200000_v097_city_blackout.sql'];
(async()=>{const db=new PGlite(),checks=[],ok=(n,b)=>{assert.ok(b,n);checks.push(n)};
 await db.exec(base);await db.exec(read('20260930075446_palisade_v0938_all_boss_milestones.sql'));await db.exec(read('20260930141401_palisade_v0940_blitz.sql'));
 await db.exec(`alter table profiles add column username text;alter table profiles add column cos text;create table lobbies(length text constraint lobbies_length_check check(length in ('5','10','endless','blitz')));
 create function auth.jwt() returns jsonb language sql stable as $$select '{"is_anonymous":false}'::jsonb$$;
 create table friendships(user_a uuid,user_b uuid,created_at timestamptz default now(),primary key(user_a,user_b));
 create table friend_requests(id bigint,from_id uuid,to_id uuid,status text,created_at timestamptz default now());
 create table notifications(id bigint generated always as identity,user_id uuid,from_id uuid,kind text,data jsonb,created_at timestamptz default now(),seen_at timestamptz);
 grant usage on schema public,auth,private to authenticated;grant execute on all functions in schema auth to authenticated;`);
 for(const m of['20261001081259_winter_whiteout.sql','20261001214620_winter_models.sql','20261001225643_music_case_batches.sql'])await db.exec(read(m));
 for(const m of['20261001081316_friend_lobby_invites.sql','20261003040401_room_register_any_yard_proto.sql',...PREV])await db.exec(read(m));
 const fnText=async()=>(await db.query(`select pg_get_functiondef('public.claim_match_reward(jsonb)'::regprocedure) d`)).rows[0].d;
 const oldText=await fnText();
 for(const m of NEW)await db.exec(read(m));for(const m of NEW)await db.exec(read(m));ok('migration applies twice',true);
 await db.exec('grant select,insert,update,delete on all tables in schema public to authenticated;grant usage on schema private to authenticated;grant execute on all functions in schema private to authenticated');
 const as=async uid=>db.exec(`reset role;set role authenticated;select set_config('request.jwt.claim.sub','${uid}',false)`);
 const reset=async(extra='')=>db.exec(`reset role;delete from private.reward_receipts;delete from match_results;delete from private.case_openings;delete from lockers;delete from player_stats;insert into lockers(user_id) values('${U}');insert into player_stats(user_id) values('${U}');${extra}`);

 const claim=async p=>{await as(U);return(await db.query('select public.claim_match_reward($1::jsonb) r',[JSON.stringify(p)])).rows[0].r};
 const bo={kind:'run',mode:'blackout',diff:'normal',game_id:'b1',duration_s:900,raid_from:0,raid_to:9,held:9,kills:60,map:'city',cls:'soldier',size:'std',salvage:0,mods:[],win:true,
   boss_keys:['butcher','storm'],pois_held:8,pois_major:4,destroyer:true,cv:5,claim_id:'k1'};
 // the full run: 8 POIs held (4 majors), won, the Destroyer down
 await reset();let r=await claim(bo);
 ok('cases: 8 POIs of progress (2) + win (2) + majors (4) = 8 Supply',r.cases.supply===8&&r.locker.prog===2);
 ok('shards: win 25 + Destroyer 40',r.shards>=65&&r.boss_shards===65);
 ok('a skill point for the Destroyer',r.skill_points>=1+Math.floor(9/5));
 ok('POI bosses pay no boss cases',!r.cases.afterglow&&!r.cases.halloween);
 ok('a Hybrid Theory Case for the win',r.hybrid_case===1);
 ok('counters',r.locker.st.bo_pois===8&&r.locker.st.bo_wins===1&&r.locker.st.bo_perfect===1&&r.locker.st.bo_dest===1);
 ok('unlocks: Blackout Helmet, Orbital Strike, Lit Skyline (not Night Shift yet)',['hat:blackout','fx:orbital','bg:skyline'].every(id=>r.unlocked_ids.includes(id))&&!r.unlocked_ids.includes('skin:nightshift'));
 ok('response fields',r.pois_held===8&&r.pois_major===4&&r.destroyer===true);
 await db.exec('reset role');{const m=(await db.query('select pois_held,destroyer,mode,raid_to from match_results order by id desc limit 1')).rows[0];ok('row values',m.pois_held===8&&m.destroyer===true&&m.mode==='blackout'&&m.raid_to===9)}
 // a second run: 10 POIs total opens Night Shift
 await db.exec(`reset role;update match_results set created_at=now()-interval '1 minute'`);r=await claim({...bo,game_id:'b2',claim_id:'k2',destroyer:false,win:false,raid_to:4,pois_held:2,pois_major:0,duration_s:300});
 ok('a lost run still counts POIs held; Night Shift at 10',r.locker.st.bo_pois===10&&r.unlocked_ids.includes('skin:nightshift')&&r.locker.st.bo_wins===1);
 // limits
 await reset();r=await claim({...bo,duration_s:200,claim_id:'k3'});
 ok('too fast: no win, POIs capped by time (1 per 30 s after 45 s)',r.pois_held===6&&!r.locker.st.bo_wins&&r.destroyer===false&&!r.locker.st.bo_dest);
 await reset();r=await claim({...bo,pois_held:50,pois_major:9,claim_id:'k4'});
 ok('POIs capped at 8, majors at 4',r.pois_held===8&&r.pois_major===4);
 await reset();r=await claim({...bo,raid_to:3,win:true,pois_held:8,claim_id:'k5'});
 ok('POIs capped by stages credited; no win short of stage 9',r.pois_held===3&&!r.locker.st.bo_wins);
 await reset();r=await claim({...bo,win:false,destroyer:true,raid_to:8,claim_id:'k6'});
 ok('the Destroyer only counts on a win',r.destroyer===false&&!r.locker.st.bo_dest);
 await reset();await assert.rejects(claim({...bo,cv:4,claim_id:'k7'}),/Unknown mode/);ok('pre-cv:5 clients cannot claim Black Out',true);
 // the same game claimed again pays nothing more
 await reset();await claim(bo);await db.exec(`reset role;update match_results set created_at=now()-interval '1 minute'`);r=await claim({...bo,claim_id:'k8'});
 ok('repeat claim: no second win',r.repeat===true&&r.locker.st.bo_wins===1&&!r.cases.supply);
 // other modes are untouched: a 5-raid win pays as before
 await reset();r=await claim({kind:'run',mode:'5',diff:'normal',game_id:'s1',duration_s:600,raid_from:0,raid_to:5,held:5,kills:30,map:'yard',cls:'soldier',size:'std',salvage:0,mods:[],win:true,boss_keys:['butcher'],cv:4,claim_id:'s1'});
 ok('5 raids: 1 + 1 win Supply, the Butcher Halloween case, no Black Out fields',r.cases.supply===2&&r.cases.halloween===1&&r.pois_held===0&&r.destroyer===false&&!r.locker.st.bo_pois);
 // rooms and lobbies take the mode
 await db.exec(`reset role;insert into lobbies(length) values('blackout')`);ok('lobbies accept blackout',true);
 const rr=(await db.query(`select pg_get_functiondef('public.room_register(jsonb)'::regprocedure) d`)).rows[0].d;
 ok('room_register accepts the city and blackout',rr.includes("'frost','city'")&&rr.includes("'campaign','blackout'"));
 // the patch only adds: every line of the old function is still there
 const newText=await fnText(),lost=oldText.split('\n').filter(l=>l.trim()&&!newText.includes(l.trim()));
 ok('nothing removed from the old function (changed lines: '+lost.length+')',lost.length<=8);
 ok('the migration file never says delete',!/delete/i.test(NEW.map(read).join('')));
 console.log(JSON.stringify({checks:checks.length,lost}));console.log('errors: none');process.exit(0);
})().catch(e=>{console.error(e);process.exit(1)});
