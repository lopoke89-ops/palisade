// v0.9.8 THE TABLES on a disposable Postgres with the real migration and the real request handler (the edge function's
// code, with the database calls the edge function makes): open, join, play, cash out, the ledger to the shard, a short
// balance refused, two requests racing on one table, side-bet prizes into the bag, the bot's daily budget, guests and
// players kept out of the casino tables, and the migration applying twice with no `delete`. node tables_server.js
const {PGlite}=require('@electric-sql/pglite'),{base}=require('./winter-db'),fs=require('node:fs'),assert=require('node:assert/strict');
const MIG=__dirname+'/../supabase/migrations/20261004200000_v098_tables.sql';
(async()=>{const H=await import('../supabase/functions/tables/handler.js'),E=await import('../supabase/functions/tables/engine.js');
 const db=new PGlite(),checks=[],ok=(n,b)=>{assert.ok(b,n);checks.push(n)};
 await db.exec(base);await db.exec(`do $$begin if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role; end if; end$$;alter role service_role bypassrls;
   alter table profiles add column if not exists username text;alter table lockers add column if not exists rev integer default 0;alter table lockers add column if not exists updated_at timestamptz;
   alter table lockers add column if not exists bag jsonb default '{}'::jsonb;grant usage on schema public,private to service_role,authenticated;grant select on lockers,profiles to service_role;`);   // as live (service_role reads everything)
 const sql=fs.readFileSync(MIG,'utf8');ok('no delete in the migration',!/delete/i.test(sql));
 await db.exec(sql);await db.exec(sql);ok('migration applies twice',true);
 const A='a0000000-0000-4000-8000-00000000000a',B='b0000000-0000-4000-8000-00000000000b',C='c0000000-0000-4000-8000-00000000000c',G='d0000000-0000-4000-8000-00000000000d';
 await db.exec(`insert into lockers(user_id,shards) values('${A}',100),('${B}',40),('${C}',3),('${G}',50);insert into profiles(id,username) values('${A}','BigU'),('${B}','Rab'),('${C}','Broke');`);
 const svc=async(q,p)=>{await db.exec('set role service_role');try{return(await db.query(q,p)).rows}finally{await db.exec('reset role')}};
 let clock=1e12;const T={a:{id:A,anon:false},b:{id:B,anon:false},c:{id:C,anon:false},g:{id:G,anon:true}};
 const D={now:()=>clock,auth:async t=>T[t]||null,
  name:async u=>(await svc('select username from profiles where id=$1',[u]))[0]?.username,
  balance:async u=>(await svc('select shards from lockers where user_id=$1',[u]))[0]?.shards??0,
  load:async id=>(await svc('select id,code,game,st,ver,open from casino_tables where id=$1',[id]))[0],
  byCode:async c=>(await svc('select id,code from casino_tables where code=$1 and open',[c]))[0],
  seatOf:async u=>(await svc('select id,code from casino_tables where open and humans @> array[$1::uuid]',[u]))[0]||null,
  list:async()=>svc('select id,code,game,st from casino_tables where open order by updated_at desc limit 30'),
  stale:async ms=>svc(`select id from casino_tables where open and updated_at < now()-($1||' milliseconds')::interval`,[String(ms)]),
  botLeft:async()=>(await svc('select public.casino_bot_left() v'))[0].v,
  commit:async a=>{try{return(await svc('select public.casino_commit($1,$2,$3,$4,$5,$6,$7) r',[a.id,a.ver,JSON.stringify(a.st),a.humans,a.open,JSON.stringify(a.ops),JSON.stringify(a.hands)]))[0].r}catch(e){return{error:/insufficient/.test(e.message)?'insufficient':e.message}}},
  create:async a=>{try{return(await svc('select public.casino_open($1,$2,$3,$4,$5) r',[a.code,a.game,JSON.stringify(a.st),a.humans,JSON.stringify(a.ops)]))[0].r}catch(e){return{error:/insufficient/.test(e.message)?'insufficient':e.message}}}};
 const call=(who,body)=>H.handle(body,who,D),bal=async u=>D.balance(u);
 // who may play
 ok('no token: refused',(await call('x',{op:'lobby'})).status===401);
 ok('a guest account: refused',(await call('g',{op:'lobby'})).status===403);
 ok('under the 5-shard buy-in: refused',/buy-in/.test((await call('c',{op:'open',game:'bj'})).body.error));
 // blackjack: A opens, B joins by code
 let r=await call('a',{op:'open',game:'bj',lim:100,side:true});if(r.status!==200)console.log(JSON.stringify(r));ok('open a table',r.status===200&&r.body.view.seats[0].name==='BIGU');const id=r.body.id,code=r.body.code;
 ok('buy-in taken',await bal(A)===95);
 r=await call('b',{op:'join',code});ok('join by code',r.status===200&&r.body.view.seats.filter(Boolean).length===2&&await bal(B)===35);
 r=await call('a',{op:'open',game:'he'});ok('already seated: back to your own table, no second buy-in',r.body.id===id&&await bal(A)===95);
 ok('the lobby lists it',(await call('b',{op:'lobby'})).body.tables.some(t=>t.code===code&&t.seated===2));
 // top up, and a top-up bigger than the balance
 r=await call('a',{op:'topup',id,amt:50});ok('top up',r.body.view.seats[0].stack===55&&await bal(A)===45);
 r=await call('b',{op:'topup',id,amt:500});ok('a top-up over the balance is refused and nothing moves',/Not enough/.test(r.body.error)&&await bal(B)===35);
 // play hands until a few are done, with simple strategy
 let hands=0;for(let k=0;k<400&&hands<6;k++){clock+=300;
  for(const who of['a','b']){const v=(await call(who,{op:'state',id})).body.view;
   if(v.phase==='bet'&&v.bets&&v.bets[v.me]===undefined)await call(who,{op:'bet',id,amt:2,side:true});
   if(v.insure)await call(who,{op:'insure',id,yes:false});
   if(v.myTurn){const p=v.players.find(p=>p.seat===v.me),hh=p.hands[v.turn.h];await call(who,{op:'move',id,a:hh.total<17?'hit':'stand'})}
   if(v.phase==='done'&&v.last&&v.last.no>hands)hands=v.last.no}
  if(k%10===0)clock+=E.PAUSE_MS}
 ok('hands are dealt and settled automatically',hands>=6);
 const logged=await svc('select hash,salt,deck,hand_no from casino_hands where table_id=$1 order by id',[id]);
 ok('every hand is logged',logged.length>=6);
 {let good=true;for(const h of logged)good=good&&h.hash===await H.deckHash(h.salt,h.deck)&&h.deck.length===208;ok('provably fair: each logged deck matches its hash (4 decks)',good)}
 // two requests racing on the same table both land (one retries)
 const [x,y]=await Promise.all([call('a',{op:'side',id,on:false}),call('b',{op:'side',id,on:false})]);ok('racing requests both land',x.status===200&&y.status===200);
 // side-bet prize
 await db.exec(`update casino_tables set st=jsonb_set(st,'{picks}','{"${A}":1}'::jsonb) where id=${id}`);
 r=await call('a',{op:'pick',id,kind:'hybrid'});const bag=(await svc('select bag from lockers where user_id=$1',[A]))[0].bag;ok('a side-bet prize lands in the bag',r.status===200&&bag.hybrid===10);
 // everyone leaves: shards go home, the ledger balances, the table closes
 for(let k=0;k<30;k++){clock+=E.PAUSE_MS+E.TURN_MS;await call('a',{op:'leave',id});await call('b',{op:'leave',id});const t=await D.load(id);if(!t.open)break}
 ok('the table closes when everyone has left',!(await D.load(id)).open);
 const L=await svc(`select coalesce(sum(shards),0)::int s from casino_ledger where table_id=$1 and kind<>'case'`,[id]),rake=0;
 ok('shards conserved: (A + B now) - (A + B before) = ledger total, and the ledger total is never positive',(await bal(A))+(await bal(B))-140===L[0].s&&L[0].s<=0);
 // hold'em: two people, the bot joins; the bot's daily budget
 r=await call('a',{op:'open',game:'he',lim:250});const hid=r.body.id;await call('b',{op:'join',code:r.body.code});clock+=1000;r=await call('a',{op:'state',id:hid});
 ok('hold\'em: two people get a bot',r.body.view.seats.some(s=>s&&s.bot)&&r.body.view.players.length===3);
 await svc(`insert into casino_ledger(table_id,kind,shards) values(0,'bot',-30)`);ok('the bot\'s budget is spent after a 30-shard day',(await D.botLeft())===0);
 // players can't read or write the casino directly
 await db.exec(`reset role;set role authenticated;select set_config('request.jwt.claim.sub','${A}',false)`);
 let denied=0;for(const q of['select * from casino_tables','select * from casino_ledger',`select public.casino_commit(1,0,'{}'::jsonb,'{}',true,'[]'::jsonb,'[]'::jsonb)`,`select public.casino_bot_left()`])try{await db.query(q)}catch(e){denied++}
 await db.exec('reset role');ok('players are kept out of the casino tables and functions',denied===4);
 fs.writeFileSync(__dirname+'/out/tables_server.json',JSON.stringify({checks},null,1));console.log(checks.length+' checks');console.log('errors: none');
})().catch(e=>{console.error(e);process.exit(1)});
