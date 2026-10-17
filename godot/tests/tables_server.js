// The casino's `tables` edge function on this machine, for tests/tables_test.gd: the real request handler
// (dev/supabase/functions/tables/handler.js) on a disposable Postgres (PGlite) with the casino migrations, the same
// database calls index.ts makes (as in dev/test/casino_server.js), and fake sign-in: the bearer token names the user.
// Nothing here talks to the real Supabase project.
//   node godot/tests/tables_server.js [port]      (prints "ready <port>" once it listens)
// Test-only routes: POST /test/advance {ms} moves the server's clock forward (reviews and betting windows pass at
// once); POST /test/balance {token} reads an account's shards; POST /test/ledger {token} lists its ledger rows.
const path=require('node:path'),http=require('node:http'),fs=require('node:fs');
const DT=path.join(__dirname,'..','..','dev','test'),req=require('node:module').createRequire(path.join(DT,'x.js'));
const {PGlite}=req('@electric-sql/pglite'),{base}=req('./winter-db');
const MIG=path.join(DT,'..','supabase','migrations'),MIGS=['20261004200000_v098_tables.sql','20261005200000_v0100_casino.sql','20261006200000_v0103_casino_games.sql','20261009041955_casino_slim_wallet.sql'].map(f=>path.join(MIG,f));
const PORT=+process.argv[2]||18787;
(async()=>{const H=await import(path.join(DT,'..','supabase','functions','tables','handler.js'));
 const db=new PGlite();
 await db.exec(base);await db.exec(`do $$begin if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role; end if; end$$;alter role service_role bypassrls;
   alter table profiles add column if not exists username text;alter table lockers add column if not exists rev integer default 0;alter table lockers add column if not exists updated_at timestamptz;
   alter table lockers add column if not exists bag jsonb default '{}'::jsonb;grant usage on schema public,private to service_role,authenticated;grant select on lockers,profiles to service_role;`);
 for(const f of MIGS)await db.exec(fs.readFileSync(f,'utf8'));
 // four players: A and B with plenty, C broke, G a guest (anonymous sign-in: refused by the handler)
 const U={'tok-a':{id:'a0000000-0000-4000-8000-00000000000a',anon:false,name:'Ace',shards:5000},'tok-b':{id:'b0000000-0000-4000-8000-00000000000b',anon:false,name:'Bea',shards:5000},
  'tok-c':{id:'c0000000-0000-4000-8000-00000000000c',anon:false,name:'Cy',shards:3},'tok-g':{id:'d0000000-0000-4000-8000-00000000000d',anon:true,name:'Guest',shards:50}};
 for(const u of Object.values(U))await db.query('insert into lockers(user_id,shards) values($1,$2)',[u.id,u.shards]),await db.query('insert into profiles(id,username) values($1,$2)',[u.id,u.name]);
 await db.exec('update private.casino_bot_wallet set balance=400');   // SLIM has a wallet to sit in with at Hold'em
 const svc=async(q,p)=>{await db.exec('set role service_role');try{return(await db.query(q,p)).rows}finally{await db.exec('reset role')}};
 const failed=m=>/bot wallet changed/.test(m)?{conflict:true}:/insufficient/.test(m)?{error:'insufficient'}:/seated elsewhere/.test(m)?{error:'seated'}:/duplicate op/.test(m)?{dup:true}:{error:'Server error'};
 let skew=0;
 const D={now:()=>Date.now()+skew,auth:async t=>U[t]?{id:U[t].id,anon:U[t].anon}:null,name:async u=>(await svc('select username from profiles where id=$1',[u]))[0]?.username,
  balance:async u=>(await svc('select shards from lockers where user_id=$1',[u]))[0]?.shards??0,
  load:async id=>(await svc('select id,code,game,st,ver,open from casino_tables where id=$1',[id]))[0],
  byRoom:async(room,game,station)=>(await svc('select id,code from casino_tables where room=$1 and game=$2 and station=$3 and open',[room,game,station||'']))[0],
  seatOf:async u=>(await svc('select id,code,game,room,station from casino_tables where open and humans @> array[$1::uuid]',[u]))[0]||null,
  opGet:async(u,o)=>(await svc('select req,table_id,res from casino_ops where user_id=$1 and op_id=$2',[u,o]))[0]||null,
  history:async(u,n)=>svc(`select id,table_id,game,hand_no,hash,salt,deck,result,created_at from casino_hands where result->'players' @> $1::jsonb order by id desc limit $2`,[JSON.stringify([{uid:u}]),n]),
  books:async()=>svc('select public.casino_books_run()'),
  stale:async ms=>svc(`select id from casino_tables where open and updated_at < now()-($1||' milliseconds')::interval`,[String(ms)]),
  botLeft:async()=>(await svc('select public.casino_bot_balance() v'))[0].v,
  commit:async a=>{try{return(await svc('select public.casino_step($1,$2,$3,$4,$5,$6,$7,$8) r',[a.id,a.ver,JSON.stringify(a.st),a.humans,a.open,JSON.stringify(a.ops),JSON.stringify(a.hands),a.op?JSON.stringify(a.op):null]))[0].r}catch(e){return failed(e.message)}},
  create:async a=>{try{return(await svc('select public.casino_start($1,$2,$3,$4,$5,$6,$7,$8) r',[a.code,a.game,JSON.stringify(a.st),a.humans,JSON.stringify(a.ops),a.room,a.station||'',a.op?JSON.stringify(a.op):null]))[0].r}catch(e){return failed(e.message)}}};
 // one request at a time, like one connection: PGlite has a single session and role switches must not interleave
 let q=Promise.resolve();const one=f=>{const p=q.then(f,f);q=p.catch(()=>{});return p};
 const send=(res,status,body)=>{res.writeHead(status,{'Content-Type':'application/json'});res.end(JSON.stringify(body))};
 http.createServer((rq,res)=>{let b='';rq.on('data',c=>b+=c);rq.on('end',()=>one(async()=>{let body={};try{body=b?JSON.parse(b):{}}catch(e){}
  const tok=(rq.headers.authorization||'').replace(/^Bearer\s+/i,'');
  try{
   if(rq.url==='/functions/v1/tables'&&rq.method==='POST'){const r=await H.handle(body,tok,D);return send(res,r.status,r.body)}
   if(rq.url==='/test/advance'){skew+=+body.ms||0;return send(res,200,{now:D.now()})}
   if(rq.url==='/test/balance'){const u=U[body.token];return send(res,200,{shards:u?await D.balance(u.id):null})}
   if(rq.url==='/test/ledger'){const u=U[body.token];return send(res,200,{rows:u?await svc('select kind,shards,table_id from casino_ledger where user_id=$1 order by id',[u.id]):[]})}
   if(rq.url==='/test/ping')return send(res,200,{ok:true});
   send(res,404,{error:'no route'})}catch(e){console.error(e);send(res,500,{error:'Server error'})}}))}).listen(PORT,'127.0.0.1',()=>console.log('ready '+PORT));
})().catch(e=>{console.error(e);process.exit(1)});
