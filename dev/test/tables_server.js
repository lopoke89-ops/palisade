// v0.9.8 THE TABLES on a disposable Postgres with the real migration and the real request handler (the edge function's
// code, with the database calls the edge function makes): open, join, play, cash out, the ledger to the shard, a short
// balance refused, two requests racing on one table, side-bet prizes into the bag, the bot's daily budget, guests and
// players kept out of the casino tables, and the migration applying twice with no `delete`.
// v0.10.0: tables are found by casino room (op 'sit'; the old open/join is refused), roulette through the real database, the
// commit-and-rerun check on every logged hand, hand history, and the daily books check (balanced, then a planted error).
// node tables_server.js
const {PGlite}=require('@electric-sql/pglite'),{base}=require('./winter-db'),fs=require('node:fs'),assert=require('node:assert/strict');
const MIG=__dirname+'/../supabase/migrations/20261004200000_v098_tables.sql',MIG2=__dirname+'/../supabase/migrations/20261005200000_v0100_casino.sql';
(async()=>{const H=await import('../supabase/functions/tables/handler.js'),E=await import('../supabase/functions/tables/engine.js');
 const db=new PGlite(),checks=[],ok=(n,b)=>{assert.ok(b,n);checks.push(n)};
 await db.exec(base);await db.exec(`do $$begin if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role; end if; end$$;alter role service_role bypassrls;
   alter table profiles add column if not exists username text;alter table lockers add column if not exists rev integer default 0;alter table lockers add column if not exists updated_at timestamptz;
   alter table lockers add column if not exists bag jsonb default '{}'::jsonb;grant usage on schema public,private to service_role,authenticated;grant select on lockers,profiles to service_role;`);   // as live (service_role reads everything)
 const sql=fs.readFileSync(MIG,'utf8');ok('no delete in the migration',!/delete/i.test(sql));
 await db.exec(sql);await db.exec(sql);ok('migration applies twice',true);
 const sql2=fs.readFileSync(MIG2,'utf8');ok('no delete in the v0.10.0 migration',!/delete/i.test(sql2));await db.exec(sql2);await db.exec(sql2);ok('the v0.10.0 migration applies twice',true);
 // casino rooms (the second v0.10.0 file: Open Games and friend invites accept length and map 'casino')
 {await db.exec(`create table if not exists lobbies(host_id uuid primary key,code text,name text,mode text,length text check (length = any (array['5','10','endless','blitz','campaign','blackout'])),diff text,players int,in_game boolean,proto text,updated_at timestamptz default now());
   create table if not exists private.room_sessions(host_id uuid primary key,incarnation uuid,code text,proto text,mode text,length text,map text,chapter int default 0,players int,locked boolean,updated_at timestamptz default now());
   create or replace function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}'::jsonb) $$;`);
  const sql3=fs.readFileSync(__dirname+'/../supabase/migrations/20261005200100_v0100_casino_rooms.sql','utf8');await db.exec(sql3);await db.exec(sql3);
  await db.exec(`insert into lobbies(host_id,code,name,mode,length,players,in_game,proto) values('a0000000-0000-4000-8000-00000000000a','QWER','x','coop','casino',1,true,'yard-28')`);
  await db.exec(`select set_config('request.jwt.claim.sub','a0000000-0000-4000-8000-00000000000a',false)`);
  let reg=null;try{reg=(await db.query(`select public.room_register('{"incarnation":"11111111-2222-4333-8444-555555555555","code":"QWER","proto":"yard-28","mode":"coop","length":"casino","map":"casino","players":2}'::jsonb) r`)).rows[0].r}catch(e){reg={error:e.message}}
  ok('casino rooms: listed in Open Games and registered for invites (the rooms file applies twice)',reg&&reg.registered===true)}
 const A='a0000000-0000-4000-8000-00000000000a',B='b0000000-0000-4000-8000-00000000000b',C='c0000000-0000-4000-8000-00000000000c',G='d0000000-0000-4000-8000-00000000000d';
 await db.exec(`insert into lockers(user_id,shards) values('${A}',100),('${B}',40),('${C}',3),('${G}',50);insert into profiles(id,username) values('${A}','BigU'),('${B}','Rab'),('${C}','Broke');`);
 const svc=async(q,p)=>{await db.exec('set role service_role');try{return(await db.query(q,p)).rows}finally{await db.exec('reset role')}};
 let clock=1e12;const T={a:{id:A,anon:false},b:{id:B,anon:false},c:{id:C,anon:false},g:{id:G,anon:true}};
 const D={now:()=>clock,auth:async t=>T[t]||null,
  name:async u=>(await svc('select username from profiles where id=$1',[u]))[0]?.username,
  balance:async u=>(await svc('select shards from lockers where user_id=$1',[u]))[0]?.shards??0,
  load:async id=>(await svc('select id,code,game,st,ver,open from casino_tables where id=$1',[id]))[0],
  byRoom:async(room,game)=>(await svc('select id,code from casino_tables where room=$1 and game=$2 and open',[room,game]))[0],
  seatOf:async u=>(await svc('select id,code,game,room from casino_tables where open and humans @> array[$1::uuid]',[u]))[0]||null,
  history:async(u,n)=>svc(`select game,hand_no,hash,salt,deck,result,created_at from casino_hands where result->'players' @> $1::jsonb order by id desc limit $2`,[JSON.stringify([{uid:u}]),n]),
  books:async()=>svc('select public.casino_books_run()'),
  stale:async ms=>svc(`select id from casino_tables where open and updated_at < now()-($1||' milliseconds')::interval`,[String(ms)]),
  botLeft:async()=>(await svc('select public.casino_bot_left() v'))[0].v,
  commit:async a=>{try{return(await svc('select public.casino_commit($1,$2,$3,$4,$5,$6,$7) r',[a.id,a.ver,JSON.stringify(a.st),a.humans,a.open,JSON.stringify(a.ops),JSON.stringify(a.hands)]))[0].r}catch(e){return{error:/insufficient/.test(e.message)?'insufficient':e.message}}},
  create:async a=>{try{return(await svc('select public.casino_open($1,$2,$3,$4,$5,$6) r',[a.code,a.game,JSON.stringify(a.st),a.humans,JSON.stringify(a.ops),a.room]))[0].r}catch(e){return{error:/insufficient/.test(e.message)?'insufficient':e.message}}}};
 const call=(who,body)=>H.handle(body,who,D),bal=async u=>D.balance(u);
 // who may play
 ok('no token: refused',(await call('x',{op:'lobby'})).status===401);
 ok('a guest account: refused',(await call('g',{op:'lobby'})).status===403);
 const ROOM='QWER:a0000000:1791200000000';
 ok('under the 5-shard buy-in: refused',/buy-in/.test((await call('c',{op:'sit',room:ROOM,game:'bj'})).body.error));
 ok('the old menu tables are gone: open and join are refused',/CASINO/.test((await call('a',{op:'open',game:'bj'})).body.error)&&/CASINO/.test((await call('a',{op:'join',code:'ABCD'})).body.error));
 ok('a sit needs a casino room and a game',(await call('a',{op:'sit',game:'bj'})).status===400&&(await call('a',{op:'sit',room:ROOM,game:'craps'})).status===400);
 // blackjack: A walks up first (opens the room's table), B walks up to the same table
 let r=await call('a',{op:'sit',room:ROOM,game:'bj',lim:100,side:true,seed:'bigu-seed'});if(r.status!==200)console.log(JSON.stringify(r));ok('the first to sit opens the table',r.status===200&&r.body.view.seats[0].name==='BIGU'&&r.body.view.seed==='bigu-seed');const id=r.body.id,code=r.body.code;
 ok('buy-in taken',await bal(A)===95);
 r=await call('b',{op:'sit',room:ROOM,game:'bj'});ok('the second lands at the same table',r.status===200&&r.body.id===id&&r.body.view.seats.filter(Boolean).length===2&&await bal(B)===35);
 ok('another room has its own table',(await svc(`select count(*)::int n from casino_tables where room='OTHR:x:1'`))[0].n===0);
 r=await call('a',{op:'sit',room:ROOM,game:'he'});ok('seated at another table: stand up there first, no second buy-in',/still seated/.test(r.body.error)&&await bal(A)===95);
 r=await call('a',{op:'sit',room:ROOM,game:'bj'});ok('the same seat again: back to it',r.body.id===id&&await bal(A)===95);
 r=await call('a',{op:'peek',room:ROOM,game:'bj'});ok('peek: the table as anyone walking past sees it',r.status===200&&r.body.view&&r.body.view.me===-1&&r.body.view.seats.filter(Boolean).length===2&&r.body.balance===undefined);
 r=await call('a',{op:'peek',room:ROOM,game:'rl'});ok('peek at a table nobody has opened: nothing',r.status===200&&r.body.view===null);
 r=await call('b',{op:'start',id});ok('only the host starts the table',/host/.test(r.body.error));r=await call('a',{op:'start',id});ok('the host starts it',r.body.view.started===true);
 ok('the lobby tells you where you sit',(await call('b',{op:'lobby'})).body.mine.id===id);
 // top up, and a top-up bigger than the balance
 r=await call('a',{op:'topup',id,amt:50});ok('top up',r.body.view.seats[0].stack===55&&await bal(A)===45);
 r=await call('b',{op:'topup',id,amt:500});ok('a top-up over the balance is refused and nothing moves',/Not enough/.test(r.body.error)&&await bal(B)===35);
 // play hands until a few are done, with simple strategy
 let hands=0;for(let k=0;k<400&&hands<6;k++){clock+=300;
  for(const who of['a','b']){const v=(await call(who,{op:'state',id})).body.view;
   if(v.phase==='bet'&&v.bets&&v.bets[v.me]===undefined){if(v.seats[v.me].stack<3)await call(who,{op:'topup',id,amt:5});await call(who,{op:'bet',id,amt:2,side:true})}
   if(v.insure)await call(who,{op:'insure',id,yes:false});
   if(v.myTurn){const p=v.players.find(p=>p.seat===v.me),hh=p.hands[v.turn.h];await call(who,{op:'move',id,a:hh.total<17?'hit':'stand'})}
   if(v.last&&v.last.no>hands)hands=v.last.no}
  if(k%10===0)clock+=E.PAUSE_MS}
 if(hands<6)console.log('STUCK',hands,JSON.stringify((await call('a',{op:'state',id})).body).slice(0,600)); ok('hands are dealt and settled automatically',hands>=6);
 const logged=await svc('select hash,salt,deck,hand_no from casino_hands where table_id=$1 order by id',[id]);
 ok('every hand is logged',logged.length>=6);
 {const rows=await svc('select hash,salt,deck,result from casino_hands where table_id=$1 order by id',[id]);let good=true;
  for(const h of rows)good=good&&h.hash===E.sha256hex(h.salt)&&h.deck.length===208&&JSON.stringify(E.shuffle(208,E.fairRng(h.salt,h.result.seeds,h.result.nonce)))===JSON.stringify(h.deck)&&h.result.seeds.includes('bigu-seed');
  ok('provably fair: every logged shoe matches its committed seed and reruns from the seeds (4 decks)',good)}
 {const hs=(await call('a',{op:'history'})).body.hands;ok('hand history lists your hands, blackjack in full',hs.length>=6&&hs.every(x=>x.game==='bj'&&x.seed&&x.deck))}
 // two requests racing on the same table both land (one retries)
 const [x,y]=await Promise.all([call('a',{op:'side',id,on:false}),call('b',{op:'side',id,on:false})]);ok('racing requests both land',x.status===200&&y.status===200);
 // side-bet prize
 await db.exec(`update casino_tables set st=jsonb_set(st,'{picks}','{"${A}":1}'::jsonb) where id=${id}`);
 r=await call('a',{op:'pick',id,kind:'hybrid'});const bag=(await svc('select bag from lockers where user_id=$1',[A]))[0].bag;ok('a side-bet prize lands in the bag',r.status===200&&bag.hybrid===10);
 // everyone leaves: shards go home, the ledger balances, the table closes
 for(let k=0;k<30;k++){clock+=E.PAUSE_MS+1000;await call('a',{op:'leave',id});await call('b',{op:'leave',id});const t=await D.load(id);if(!t.open)break}
 ok('the table closes when everyone has left',!(await D.load(id)).open);
 const L=await svc(`select coalesce(sum(shards),0)::int s from casino_ledger where table_id=$1 and kind<>'case'`,[id]),rake=0;
 ok('shards conserved: (A + B now) - (A + B before) = ledger total, and the ledger total is never positive',(await bal(A))+(await bal(B))-140===L[0].s&&L[0].s<=0);
 // hold'em: two people, the bot joins; the bot's daily budget
 r=await call('a',{op:'sit',room:ROOM,game:'he',lim:250});const hid=r.body.id;await call('b',{op:'sit',room:ROOM,game:'he'});clock+=1000;r=await call('a',{op:'state',id:hid});ok('hold\'em waits for the host',r.body.view.phase==='wait'&&!r.body.view.started);await call('a',{op:'start',id:hid});r=await call('a',{op:'state',id:hid});
 ok('hold\'em: two people get a bot',r.body.view.seats.some(s=>s&&s.bot)&&r.body.view.players.length===3);
 await svc(`insert into casino_ledger(table_id,kind,shards) values(0,'bot',-30)`);ok('the bot\'s budget is spent after a 30-shard day',(await D.botLeft())===0);
 for(let k=0;k<30;k++){clock+=E.NEXT_MS+1;await call('a',{op:'leave',id:hid});await call('b',{op:'leave',id:hid});if(!(await D.load(hid)).open)break}ok('the hold\'em table closes',!(await D.load(hid)).open);
 // roulette through the real database: both walk up, bet, spin, get paid
 r=await call('a',{op:'sit',room:ROOM,game:'rl',lim:250,side:true});const rid=r.body.id;ok('roulette: always no limit, no side bet',r.status===200&&r.body.view.lim===0&&!r.body.view.side&&r.body.view.phase==='bet');
 await call('b',{op:'sit',room:ROOM,game:'rl'});await call('a',{op:'topup',id:rid,amt:20});
 r=await call('a',{op:'rlbets',id:rid,bets:{'n:00':1}});ok('only real spots',/spot/.test(r.body.error));
 r=await call('a',{op:'rlbets',id:rid,bets:{red:10,'n:37':5}});ok('bets placed',r.body.view.myBets.red===10&&r.body.view.number===undefined);
 r=await call('b',{op:'rlbets',id:rid,bets:{black:3}});await call('a',{op:'rlready',id:rid});r=await call('b',{op:'rlready',id:rid});
 ok('everyone ready: the ball goes, and only now the number shows',r.body.view.phase==='spin'&&r.body.view.number>=0);const num=r.body.view.number;
 clock+=E.SPIN_MS+1;r=await call('a',{op:'state',id:rid});ok('settled after the spin',r.body.view.phase==='done'&&r.body.view.last.deck[0]===num&&E.sha256hex(r.body.view.last.seed)===r.body.view.last.hash);
 const sp=(await svc('select result from casino_hands where table_id=$1',[rid]))[0].result;ok('the spin is logged with the house\'s take',sp.number===num&&sp.house===18-E.rlPay({red:10,'n:37':5},num)-E.rlPay({black:3},num));
 for(let k=0;k<30;k++){clock+=E.RL_SHOW_MS+1;await call('a',{op:'leave',id:rid});await call('b',{op:'leave',id:rid});if(!(await D.load(rid)).open)break}ok('the roulette table closes',!(await D.load(rid)).open);
 // the daily books check: every table closed today balances; then one with a planted error doesn't
 const today=(await db.query(`select (now() at time zone 'America/New_York')::date d`)).rows[0].d.toISOString().slice(0,10);
 await db.exec(`select private.casino_books_day('${today}'::date)`);let bk=(await db.query(`select * from casino_books where day='${today}'::date`)).rows[0];
 ok('the books balance for the day (in - out = the house\'s take + the bot)',bk&&bk.ok&&bk.tables_closed===3&&bk.shards_in-bk.shards_out===bk.house_bj+bk.house_he+bk.house_rl+bk.bot);
 await db.exec(`update casino_tables set updated_at=updated_at-interval '3 days' where id=${rid};insert into casino_ledger(table_id,user_id,kind,shards) values(${rid},'${A}','cashout',7)`);
 const d3=(await db.query(`select ((now()-interval '3 days') at time zone 'America/New_York')::date d`)).rows[0].d.toISOString().slice(0,10);
 await db.exec(`select private.casino_books_day('${d3}'::date)`);bk=(await db.query(`select * from casino_books where day='${d3}'::date`)).rows[0];
 ok('a table that doesn\'t balance is caught',bk&&!bk.ok&&bk.bad_tables.map(Number).includes(rid));
 const n0=(await svc('select public.casino_books_run() n'))[0].n;ok('the lobby\'s books run fills in finished days once',n0>=0&&(await svc('select public.casino_books_run() n'))[0].n===0);
 // players can't read or write the casino directly
 await db.exec(`reset role;set role authenticated;select set_config('request.jwt.claim.sub','${A}',false)`);
 let denied=0;for(const q of['select * from casino_tables','select * from casino_ledger','select * from casino_books',`select public.casino_commit(1,0,'{}'::jsonb,'{}',true,'[]'::jsonb,'[]'::jsonb)`,`select public.casino_bot_left()`,`select public.casino_books_run()`,`select public.casino_open('X','rl','{}'::jsonb,'{}','[]'::jsonb,'r')`])try{await db.query(q)}catch(e){denied++}
 await db.exec('reset role');ok('players are kept out of the casino tables and functions',denied===7);
 fs.writeFileSync(__dirname+'/out/tables_server.json',JSON.stringify({checks},null,1));console.log(checks.length+' checks');console.log('errors: none');
})().catch(e=>{console.error(e);process.exit(1)});
