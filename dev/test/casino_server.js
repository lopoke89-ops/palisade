// v0.10.3 THE PALISADE FALLS CASINO on a disposable Postgres with all three casino migrations and the real request handler
// (the edge function's code, with the database calls index.ts makes). Operation ids: a repeat returns its first answer and
// never moves shards twice (one at a time, racing, after a "timeout", and a spin's outcome too), a changed request under the
// same id is refused, a new-game move without one is refused. Stations: two slot cabinets in one room are two sessions, two
// accounts racing for one cabinet get one winner. One activity per account, enforced inside the transaction (two tables at
// once from two tabs: one seat; a hand-written step that seats someone twice is undone). Craps: leaving with a Pass bet on
// the point keeps the account at the table; the dealer rolls it out; the shards come home once. Baccarat: hand history shows a
// hand's cards and their salts (they check against the shoe fingerprint now) but never the seed or undealt cards; the
// shoe's last row has the seed and reruns. The books balance for the new games; players can't reach the new tables or
// functions. node casino_server.js
const {PGlite}=require('@electric-sql/pglite'),{base}=require('./winter-db'),fs=require('node:fs'),assert=require('node:assert/strict');
const MIGS=['20261004200000_v098_tables.sql','20261005200000_v0100_casino.sql','20261006200000_v0103_casino_games.sql'].map(f=>__dirname+'/../supabase/migrations/'+f);
(async()=>{const H=await import('../supabase/functions/tables/handler.js'),E=await import('../supabase/functions/tables/engine.js'),X=await import('../supabase/functions/tables/games.js');
 const db=new PGlite(),checks=[],ok=(n,b)=>{assert.ok(b,n);checks.push(n)};
 await db.exec(base);await db.exec(`do $$begin if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role; end if; end$$;alter role service_role bypassrls;
   alter table profiles add column if not exists username text;alter table lockers add column if not exists rev integer default 0;alter table lockers add column if not exists updated_at timestamptz;
   alter table lockers add column if not exists bag jsonb default '{}'::jsonb;grant usage on schema public,private to service_role,authenticated;grant select on lockers,profiles to service_role;`);
 for(const f of MIGS)await db.exec(fs.readFileSync(f,'utf8'));await db.exec(fs.readFileSync(MIGS[2],'utf8'));ok('the casino migrations apply (v0.10.3 twice)',true);
 const A='a0000000-0000-4000-8000-00000000000a',B='b0000000-0000-4000-8000-00000000000b',C='c0000000-0000-4000-8000-00000000000c';
 await db.exec(`insert into lockers(user_id,shards) values('${A}',5000),('${B}',5000),('${C}',4);insert into profiles(id,username) values('${A}','BigU'),('${B}','Rab'),('${C}','Broke');`);
 const svc=async(q,p)=>{await db.exec('set role service_role');try{return(await db.query(q,p)).rows}finally{await db.exec('reset role')}};
 const failed=m=>/insufficient/.test(m)?{error:'insufficient'}:/seated elsewhere/.test(m)?{error:'seated'}:/duplicate op/.test(m)?{dup:true}:{error:m};
 let clock=1e12;const T={a:{id:A,anon:false},b:{id:B,anon:false},c:{id:C,anon:false}};
 // one connection, like the edge function's pooled calls: statements from racing requests interleave between awaits
 const D={now:()=>clock,auth:async t=>T[t]||null,name:async u=>(await svc('select username from profiles where id=$1',[u]))[0]?.username,
  balance:async u=>(await svc('select shards from lockers where user_id=$1',[u]))[0]?.shards??0,
  load:async id=>(await svc('select id,code,game,st,ver,open from casino_tables where id=$1',[id]))[0],
  byRoom:async(room,game,station)=>(await svc('select id,code from casino_tables where room=$1 and game=$2 and station=$3 and open',[room,game,station||'']))[0],
  seatOf:async u=>(await svc('select id,code,game,room,station from casino_tables where open and humans @> array[$1::uuid]',[u]))[0]||null,
  opGet:async(u,o)=>(await svc('select req,table_id,res from casino_ops where user_id=$1 and op_id=$2',[u,o]))[0]||null,
  history:async(u,n)=>svc(`select id,table_id,game,hand_no,hash,salt,deck,result,created_at from casino_hands where result->'players' @> $1::jsonb order by id desc limit $2`,[JSON.stringify([{uid:u}]),n]),
  books:async()=>svc('select public.casino_books_run()'),
  stale:async ms=>svc(`select id from casino_tables where open and updated_at < now()-($1||' milliseconds')::interval`,[String(ms)]),
  botLeft:async()=>(await svc('select public.casino_bot_left() v'))[0].v,
  commit:async a=>{try{return(await svc('select public.casino_step($1,$2,$3,$4,$5,$6,$7,$8) r',[a.id,a.ver,JSON.stringify(a.st),a.humans,a.open,JSON.stringify(a.ops),JSON.stringify(a.hands),a.op?JSON.stringify(a.op):null]))[0].r}catch(e){return failed(e.message)}},
  create:async a=>{try{return(await svc('select public.casino_start($1,$2,$3,$4,$5,$6,$7,$8) r',[a.code,a.game,JSON.stringify(a.st),a.humans,JSON.stringify(a.ops),a.room,a.station||'',a.op?JSON.stringify(a.op):null]))[0].r}catch(e){return failed(e.message)}}};
 const call=(who,body)=>H.handle(body,who,D),bal=u=>D.balance(u),ROOM='WXYZ:a0000000:1791300000000';let n=0;const oid=()=>'op'+(++n).toString(36).padStart(8,'0');

 // 1. operation ids on a slot machine
 let r=await call('a',{op:'sit',room:ROOM,game:'sl',station:'s1',opId:oid()});ok('a slot cabinet: sit (5-shard buy-in)',r.status===200&&r.body.view.game==='sl'&&await bal(A)===4995);const s1=r.body.id;
 r=await call('a',{op:'topup',id:s1,amt:100,opId:'topup-0001'});ok('top up 100',r.body.view.seats[0].stack===105&&await bal(A)===4895);
 r=await call('a',{op:'topup',id:s1,amt:100,opId:'topup-0001'});ok('the same top-up id again: its first answer, no second debit',r.status===200&&r.body.replay===true&&await bal(A)===4895&&r.body.view.seats[0].stack===105);
 r=await call('a',{op:'topup',id:s1,amt:50,opId:'topup-0001'});ok('the same id with a different amount: refused',r.status===409&&/different/.test(r.body.error)&&await bal(A)===4895);
 r=await call('a',{op:'spin',id:s1,amt:5});ok('a spin without an operation id: refused (update the game)',r.status===400&&/reload/.test(r.body.error));
 r=await call('a',{op:'spin',id:s1,amt:'5',opId:oid()});ok('a numeric string is not a stake',/at least/.test(r.body.error)&&r.body.view.seats[0].stack===105);
 const spinId=oid();r=await call('a',{op:'spin',id:s1,amt:5,opId:spinId});const first=r.body.rcpt;ok('a spin: settled at once, with its receipt',r.status===200&&first&&first.result.players[0].bet===5);
 const stackAfter=r.body.view.seats[0].stack;
 r=await call('a',{op:'spin',id:s1,amt:5,opId:spinId});ok('the spin replayed after a "timeout": the same reels, nothing moves',r.body.replay&&require('node:util').isDeepStrictEqual(r.body.rcpt,first)&&r.body.view.seats[0].stack===stackAfter);
 r=await call('a',{op:'spin',id:s1,amt:5,opId:oid()});ok('a new spin during the reels and review: refused by the server',/still turning/.test(r.body.error)&&r.body.view.seats[0].stack===stackAfter);
 clock+=X.SL.ANIM+E.REVIEW.sl;
 {const id=oid(),rs=await Promise.all([call('a',{op:'spin',id:s1,amt:3,opId:id}),call('a',{op:'spin',id:s1,amt:3,opId:id})]);const st=(await D.load(s1)).st;
  ok('two identical spins racing: one spin',rs.every(x=>x.status===200)&&st.handNo===2&&(await svc(`select count(*)::int n from casino_ops where user_id=$1 and op_id=$2`,[A,id]))[0].n===1)}
 // 2. stations: a second cabinet is its own session; two accounts racing for one cabinet
 r=await call('b',{op:'sit',room:ROOM,game:'sl',station:'s2',opId:oid()});ok('cabinet 2 is its own session',r.status===200&&r.body.id!==s1);const s2=r.body.id;
 r=await call('b',{op:'sit',room:ROOM,game:'sl',station:'s99',opId:oid()});ok('no cabinet 99',r.status===400);
 await call('b',{op:'leave',id:s2,opId:oid()});
 {const rs=await Promise.all([call('b',{op:'sit',room:ROOM,game:'pk',station:'p1',opId:oid()}),call('c',{op:'sit',room:ROOM,game:'pk',station:'p1',opId:oid()})]);
  ok('the Plinko board: the broke player is refused the buy-in; one session',rs.filter(x=>x.status===200&&x.body.view&&x.body.view.me>=0).length===1)}
 {await db.query('update lockers set shards=50 where user_id=$1',[C]);const rs=await Promise.all([call('b',{op:'sit',room:ROOM,game:'sl',station:'s5',opId:oid()}),call('c',{op:'sit',room:ROOM,game:'sl',station:'s5',opId:oid()})]);
  const seated=rs.filter(x=>x.status===200&&x.body.view&&x.body.view.me>=0).length;ok('two accounts racing for one cabinet: one plays it, the other is told it is taken',seated===1&&rs.some(x=>/full|seated/.test(x.body.error||'')))}
 // 3. one activity per account, in the transaction
 for(const u of['b','c']){const m=await D.seatOf(T[u].id);if(m)await call(u,{op:'leave',id:m.id,opId:oid()})}
 {const rs=await Promise.all([call('b',{op:'sit',room:ROOM,game:'ba',opId:oid()}),call('b',{op:'sit',room:ROOM,game:'cr',opId:oid()})]);
  const seats=(await svc('select table_id from casino_seats where user_id=$1',[B]));const open=(await svc(`select count(*)::int n from casino_tables where open and humans @> array[$1::uuid]`,[B]))[0].n;
  ok('two tables at once from two tabs: seated at one, refused at the other',seats.length===1&&open===1&&rs.filter(x=>x.status===200&&x.body.view&&x.body.view.me>=0).length===1)}
 {const t=(await svc(`select id,ver,st,humans from casino_tables where open and game='sl' and humans @> array[$1::uuid]`,[A]))[0],other=(await D.seatOf(B));
  let e=null;try{await svc('select public.casino_step($1,$2,$3,$4,true,$5,$6,null)',[t.id,t.ver,JSON.stringify(t.st),[A,B],'[]','[]'])}catch(x){e=x.message}
  ok('a step that would seat an account already seated elsewhere is undone',/seated elsewhere/.test(e||'')&&!!other&&(await svc('select ver from casino_tables where id=$1',[t.id]))[0].ver===t.ver)}
 {const m=await D.seatOf(B);if(m)await call('b',{op:'leave',id:m.id,opId:oid()})}
 // 4. craps: leave with the Pass Line on a point; the account stays; the dealer rolls it out; shards home once
 r=await call('b',{op:'sit',room:ROOM,game:'cr',opId:oid()});const cid=r.body.id;await call('b',{op:'topup',id:cid,amt:200,opId:oid()});
 const b0=await bal(B);let v=null;
 for(let k=0;k<300;k++){v=(await call('b',{op:'state',id:cid})).body.view;if(v.point)break;
  if(v.phase==='bet'&&!(v.myBets.pass>0))await call('b',{op:'crbet',id:cid,k:'pass',amt:10,opId:oid()});if(v.phase==='bet')await call('b',{op:'crready',id:cid});clock+=X.CR.MIN_MS+E.REVIEW.cr+X.CR.DICE_MS}
 ok('a point is on with a Pass Line bet',v.point>0&&v.myBets.pass===10);clock+=E.REVIEW.cr+X.CR.DICE_MS;v=(await call('b',{op:'state',id:cid})).body.view;
 r=await call('b',{op:'crbet',id:cid,k:'p6',amt:12,opId:oid()});ok('betting reopens after the review; Place 6 goes down',v.phase==='bet'&&!r.body.error&&r.body.view.myBets.p6===12);
 await call('c',{op:'sit',room:ROOM,game:'cr',opId:oid()});   // someone still playing: the dealer doesn't rush the rolls
 const stackBefore=(await call('b',{op:'state',id:cid})).body.view.seats[0].stack;
 r=await call('b',{op:'leave',id:cid,opId:oid()});ok('leave: the place bet comes back, the Pass Line stays working',r.body.view.seats.find(x=>x&&x.name==='RAB').stack===stackBefore+12&&r.body.view.myBets.pass===10&&(await D.load(cid)).open);
 r=await call('b',{op:'sit',room:ROOM,game:'ba',opId:oid()});ok('the account is still at the craps table: no other seat',/craps bets/.test(r.body.error||''));
 await call('c',{op:'leave',id:cid,opId:oid()});
 r=await call('b',{op:'lobby'});ok('the lobby rolls it out (nobody else is playing there) and sends the shards home',!r.body.mine&&!(await D.load(cid)).open);
 const led=(await svc(`select kind,shards from casino_ledger where table_id=$1 and user_id=$2 order by id`,[cid,B]));ok('one cash-out',led.filter(x=>x.kind==='cashout').length===1);
 const hs=(await svc(`select result from casino_hands where table_id=$1 order by id`,[cid])).map(x=>x.result);
 {const net=hs.reduce((a,x)=>a-x.house,0),co=led.find(x=>x.kind==='cashout').shards;ok('shards conserved: cash-out = 205 brought + the rolls\' net',co===205+net)}
 // 5. baccarat: hand history shows a hand's own cards (checkable now), never the seed; the retired shoe reruns
 r=await call('a',{op:'leave',id:s1,opId:oid()});r=await call('a',{op:'sit',room:ROOM,game:'ba',opId:oid()});const bid=r.body.id;await call('a',{op:'topup',id:bid,amt:400,opId:oid()});
 for(let k=0;k<3;k++){await call('a',{op:'babets',id:bid,bets:{B:20,P:5},opId:oid()});await call('a',{op:'baready',id:bid});clock+=X.BA.MIN_MS;r=await call('a',{op:'state',id:bid});
  ok('baccarat hand '+(k+1)+' dealt',r.body.view.phase==='done');clock+=10000+E.REVIEW.ba}
 r=await call('a',{op:'babets',id:bid,bets:{B:30},opId:oid()});ok('a Banker bet not in 20s is refused before it is taken',/20s/.test(r.body.error||''));
 const hist=(await call('a',{op:'history'})).body.hands.filter(h=>h.game==='ba');
 ok('history: no seed, no shoe while the shoe is in play',hist.length===3&&hist.every(h=>!h.seed&&!h.deck&&h.cards&&h.root));
 const proof=(await call('a',{op:'shoe',id:bid})).body;let good=proof.root===hist[0].root&&E.rootOf(proof.hashes)===proof.root;
 for(const h of hist)for(const[p,c,s]of h.cards)good=good&&E.cardHash(s,c)===proof.hashes[p];ok('each dealt card checks against the shoe fingerprint now',good&&proof.hashes.length===416);
 ok('the shoe proof has no card values',!JSON.stringify(proof).includes('"cards"'));
 await call('a',{op:'leave',id:bid,opId:oid()});const end=(await call('a',{op:'history'})).body.hands.find(h=>h.result&&h.result.shoeEnd);
 ok('the table closed: the shoe retires, its seed and every card go to your history and the shoe reruns',end&&end.seed&&E.sha256hex(end.seed)===end.commit&&JSON.stringify(E.shuffle(416,E.fairRng(end.seed,end.result.seeds,end.result.nonce)))===JSON.stringify(end.deck));
 // 6. the books cover the new games and balance; players can't reach the new tables or functions
 const today=(await db.query(`select (now() at time zone 'America/New_York')::date d`)).rows[0].d.toISOString().slice(0,10);
 await db.exec(`select private.casino_books_day('${today}'::date)`);const bk=(await db.query(`select * from casino_books where day='${today}'::date`)).rows[0];
 ok('the books balance with the new games',bk&&bk.ok&&bk.tables_closed>=4&&bk.shards_in-bk.shards_out===bk.house_bj+bk.house_he+bk.house_rl+bk.house_ba+bk.house_cr+bk.house_sl+bk.house_pk+bk.bot);
 await db.exec(`reset role;set role authenticated;select set_config('request.jwt.claim.sub','${A}',false)`);
 let denied=0;const qs=['select * from casino_ops','select * from casino_seats',`select public.casino_step(1,0,'{}'::jsonb,'{}',true,'[]'::jsonb,'[]'::jsonb,null)`,`select public.casino_start('X','sl','{}'::jsonb,'{}','[]'::jsonb,'r','s1',null)`,`select private.casino_seat_sync(1,'{}',true)`];
 for(const q of qs)try{await db.query(q)}catch(e){denied++}
 await db.exec('reset role');ok('players are kept out of the new tables and functions',denied===qs.length);
 fs.mkdirSync(__dirname+'/out',{recursive:true});fs.writeFileSync(__dirname+'/out/casino_server.json',JSON.stringify({checks},null,1));console.log(checks.length+' checks');console.log('errors: none');
})().catch(e=>{console.error(e);process.exit(1)});
