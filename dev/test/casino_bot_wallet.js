// Real SQL and handler: funding, idempotent backfill, wallet reservations, rollback and legacy bots.
const {PGlite}=require('@electric-sql/pglite'),{base}=require('./winter-db'),fs=require('node:fs'),assert=require('node:assert/strict');
const dir=__dirname+'/../supabase/migrations/',walletSql=fs.readFileSync(dir+'20261009041955_casino_slim_wallet.sql','utf8');
(async()=>{
 const db=new PGlite(),H=await import('../supabase/functions/tables/handler.js'),E=await import('../supabase/functions/tables/engine.js'),checks=[];
 const ok=(name,b)=>{assert.ok(b,name);checks.push(name)},q=async(sql,p)=>(await db.query(sql,p)).rows;
 await db.exec(base);await db.exec(`create role service_role bypassrls;alter table profiles add column username text;grant usage on schema public,private to service_role;grant select on lockers,profiles to service_role;`);
 for(const name of ['20261004200000_v098_tables.sql','20261005200000_v0100_casino.sql','20261006200000_v0103_casino_games.sql'])await db.exec(fs.readFileSync(dir+name,'utf8'));
 const round=async(game,house)=>q(`insert into casino_hands(table_id,game,hand_no,result,created_at) values(0,$1,1,$2,now()-interval '3 days') returning id`,[game,JSON.stringify({house})]);
 for(const [g,n] of [['bj',100],['rl',30],['ba',40],['cr',-25],['sl',15],['pk',10],['he',999]])await round(g,n);
 await db.exec(walletSql);const wallet=async()=>(await q('select * from private.casino_bot_wallet'))[0],available=async()=>(await q('select public.casino_bot_balance() n'))[0].n;
 ok('historical net losses from all six non-poker games, including negative craps, total 170',(await wallet()).balance===170);
 await db.exec(walletSql);ok('backfill and migration replay do not credit twice',(await wallet()).balance===170&&(await q('select count(*)::int n from private.casino_bot_funding'))[0].n===6);
 for(const g of ['bj','rl','ba','cr','sl','pk'])await round(g,2);
 await round('he',400);ok('all non-poker games fund live and poker remains excluded',(await wallet()).balance===182);
 await round('bj',-12);ok('a player win subtracts from the fund',(await wallet()).balance===170);
 await db.exec('begin');await round('sl',25);await db.exec('rollback');ok('rolled-back settlements do not fund the wallet',(await wallet()).balance===170);
 await db.exec(`insert into casino_ledger(table_id,kind,shards) values(0,'buyin',-500),(0,'topup',-50),(0,'cashout',40),(0,'bot',80)`);
 ok('deposits, cashouts, and legacy bot records do not fund the wallet',(await wallet()).balance===170);
 ok('the old daily allowance RPC is disabled',(await q('select casino_bot_left() n'))[0].n===0);
 const U=['a','b','c','d'].map((_,i)=>(i+1).toString().repeat(8)+'-1111-4111-8111-111111111111');
 for(let i=0;i<U.length;i++)await q('insert into lockers(user_id,shards) values($1,1000);',[U[i]]);
 let clock=Date.now();const users=Object.fromEntries(['a','b','c','d'].map((s,i)=>[s,{id:U[i],anon:false}]));
 const fail=m=>/bot wallet changed/.test(m)?{conflict:true}:/insufficient/.test(m)?{error:'insufficient'}:/seated elsewhere/.test(m)?{error:'seated'}:/duplicate op/.test(m)?{dup:true}:{error:m};
 const D={now:()=>clock,auth:async t=>users[t],name:async u=>'USER'+U.indexOf(u),balance:async u=>(await q('select shards from lockers where user_id=$1',[u]))[0].shards,
   load:async id=>(await q('select * from casino_tables where id=$1',[id]))[0],byRoom:async(room,game,station)=>(await q('select id,code from casino_tables where room=$1 and game=$2 and station=$3 and open',[room,game,station||'']))[0],
   seatOf:async u=>(await q('select id,code,game,room,station from casino_tables where open and humans @> array[$1::uuid]',[u]))[0]||null,opGet:async()=>null,stale:async()=>[],books:async()=>{},botLeft:available,
   create:async a=>{try{return(await q('select casino_start($1,$2,$3,$4,$5,$6,$7,$8) r',[a.code,a.game,a.st,a.humans,a.ops,a.room,a.station||'',a.op]))[0].r}catch(e){return fail(e.message)}},
   commit:async a=>{try{return(await q('select casino_step($1,$2,$3,$4,$5,$6,$7,$8) r',[a.id,a.ver,a.st,a.humans,a.open,a.ops,a.hands,a.op]))[0].r}catch(e){return fail(e.message)}}};
 const call=async(w,b)=>{const r=await H.handle(b,w,D);assert.equal(r.status,200,JSON.stringify(r));return r.body};
 const room1='WALLET:one:1',room2='WALLET:two:2';
 const id1=(await call('a',{op:'sit',room:room1,game:'he',lim:100})).id;await call('b',{op:'sit',room:room1,game:'he'});
 const id2=(await call('c',{op:'sit',room:room2,game:'he',lim:100})).id;await call('d',{op:'sit',room:room2,game:'he'});
 // Both requests deliberately read the same pre-reservation wallet. The loser must retry.
 let reads=0,release;const gate=new Promise(r=>release=r),realBalance=D.botLeft;
 D.botLeft=async()=>{const n=await realBalance();if(reads++<2){if(reads===2)release();await gate}return n};
 const started=await Promise.all([call('a',{op:'start',id:id1}),call('c',{op:'start',id:id2})]);D.botLeft=realBalance;
 ok('two tables racing: exactly one seats SLIM',started.filter(r=>r.view.seats.some(s=>s&&s.bot)).length===1);
 const active=Number((await wallet()).active_table),other=active===id1?id2:id1,t=await D.load(active),bot=t.st.seats.find(s=>s&&s.bot);
 ok('SLIM reserves and brings all 170 shards',bot.brought===170&&(await wallet()).balance===0&&await available()===0);
 ok('retry rolled back the losing reservation and bot seat',!(await D.load(other)).st.seats.some(s=>s&&s.bot));
 await round('sl',20);ok('new revenue waits while he is seated',(await wallet()).balance===20&&await available()===0);
 // Finish a real hand through server requests, then leave both people and reconcile books.
 const who=active===id1?['a','b']:['c','d'];
 for(let k=0;k<30;k++){
   const t=await D.load(active);if(!t.open)break;
   clock+=E.NEXT_MS+1;for(const w of who)await call(w,{op:'leave',id:active});
 }
 const closed=await D.load(active);ok('disconnect/leave closes the table and returns the remaining bot stack',!closed.open&&(await wallet()).active_table===null);
 const net=Number((await q("select coalesce(sum(shards),0)::int n from casino_ledger where table_id=$1 and kind='bot'",[active]))[0].n);
 ok('wallet equals funding plus SLIM net poker result',(await wallet()).balance===190+net);
 const cashouts=await q("select shards from casino_ledger where table_id=$1 and kind='bot_cashout'",[active]);
 ok('exactly one full cashout',cashouts.length===1&&cashouts[0].shards===170+net);
 const day=(await q("select (now() at time zone 'America/New_York')::date d"))[0].d.toISOString().slice(0,10);
 await q('select private.casino_books_day($1)',[day]);ok('existing casino books still balance with wallet transfers',(await q('select ok from casino_books where day=$1',[day]))[0].ok);
 // A stale full-balance quote must roll back even when its amount is still affordable.
 const old=await available();await round('ba',5);const stale=await D.load(other),ctx={now:clock,rng:H.rng,seed:()=> 'walletseed',salt:()=> 's',ops:[],hands:[],botLeft:old};
 stale.st.hand=null;stale.st.phase='wait';stale.st.started=true;for(const s of stale.st.seats)if(s)s.seen=clock;E.tick(stale.st,ctx);
 const res=await D.commit({id:other,ver:stale.ver,st:stale.st,humans:stale.humans,open:true,ops:ctx.ops,hands:ctx.hands});
 ok('stale balance quote retries, preserving all fresh funding',res.conflict===true&&await available()===old+5&&!(await D.load(other)).st.seats.some(s=>s&&s.bot));
 // Negative net funding carries forward, rather than disappearing at a zero clamp.
 await round('cr',-(await available()+50));ok('house deficit blocks joining but remains on the books',(await wallet()).balance===-50&&await available()===0);
 await round('pk',30);ok('new losses first repay the deficit',(await wallet()).balance===-20&&await available()===0);
 await round('bj',25);ok('only the remainder after deficit is available',await available()===5);
 await db.exec(walletSql);ok('migration replay after play preserves current wallet',await available()===5);
 const legacy=(await q(`insert into casino_tables(code,game,st) values('LEGACY','he','{"seats":[{"bot":true,"stack":8,"brought":5}]}') returning id`))[0].id;
 ok('an already-seated legacy SLIM blocks a second bot during rollout',await available()===0);
 await q("update casino_tables set st='{"+'"seats":[]'+"}'::jsonb,open=false where id=$1",[legacy]);
 await q('select private.casino_apply($1,$2)',[legacy,[{k:'bot',d:3}]]);
 ok('legacy principal and past poker profit never enter the backfill',await available()===5);
 for(const role of ['anon','authenticated','service_role']){
   await db.exec('set role '+role);let denied=0;
   for(const sql of ['select * from private.casino_bot_wallet','select * from private.casino_bot_funding','select private.casino_bot_fund_round()'])try{await q(sql)}catch(e){denied++}
   let rpc=false;try{rpc=(await q('select casino_bot_balance() n'))[0].n===5}catch(e){}
   await db.exec('reset role');ok(role+': private wallet and funding inaccessible; RPC service only',denied===3&&rpc===(role==='service_role'));
 }
 await db.close();fs.mkdirSync(__dirname+'/out',{recursive:true});fs.writeFileSync(__dirname+'/out/casino_bot_wallet.json',JSON.stringify({checks},null,2));console.log(checks.length+' checks; errors: none');
})().catch(e=>{console.error(e);process.exit(1)});
