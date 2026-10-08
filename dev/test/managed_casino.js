// Disposable database contract tests. No credentials or calls to the live Supabase project.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{randomUUID,webcrypto}=require('node:crypto');
if(!globalThis.crypto)globalThis.crypto=webcrypto;
async function setup(db,{count=9}={}){
 await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;create schema auth;create table auth.users(id uuid primary key,email text,is_anonymous boolean default false,raw_user_meta_data jsonb default '{}');create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;create function auth.jwt() returns jsonb language sql stable as $$select '{"is_anonymous":false}'::jsonb$$;`);
 await db.exec(fs.readFileSync(path.join(__dirname,'../supabase/schema.sql'),'utf8'));
 const ids=Array.from({length:count},()=>randomUUID());for(let k=0;k<ids.length;k++){await db.query('insert into auth.users(id,email) values($1,$2)',[ids[k],`casino${k}@example.test`]);await db.query('update profiles set username=$2 where id=$1',[ids[k],'Casino'+k]);await db.query('update lockers set shards=5000 where user_id=$1',[ids[k]]);}
 const rpc=async(name,a={})=>{
  const keys=Object.keys(a);const q='select public.'+name+'('+keys.map((k,i)=>k+'=> $'+(i+1)).join(',')+') r';
  const r=await db.query(q,keys.map(k=>k==='p_humans'?'{'+a[k].join(',')+'}':a[k]&&typeof a[k]==='object'?JSON.stringify(a[k]):a[k]));return r.rows[0].r;
 };
 const first=async(q,p)=>(await db.query(q,p)).rows[0]||null;
 const D={now:()=>Date.now(),rpc,auth:async t=>ids.includes(t)?{id:t,anon:false}:null,
  rows:async(table,q)=>{if(table==='profiles')return (await db.query('select cos from profiles where id=$1',[q.id.slice(3)])).rows;
   if(table==='casino_tables')return (await db.query('select id,next_due_at from casino_tables where open and next_due_at <= $1 order by next_due_at,id limit 10',[q.next_due_at.slice(4)])).rows;throw new Error('Unsupported fixture query');},
  name:async uid=>(await first('select username from profiles where id=$1',[uid])).username,
  balance:async uid=>(await first('select shards from lockers where user_id=$1',[uid])).shards,
  load:id=>first('select id,code,game,st,ver,open,room,station from casino_tables where id=$1',[id]),
  byRoom:(r,g,s)=>first('select id,code from casino_tables where open and room=$1 and game=$2 and station=$3',[r,g,s||'']),
  seatOf:uid=>first('select id,code,game,room,station from casino_tables where open and $1=any(humans) limit 1',[uid]),
  opGet:(uid,id)=>first('select req,table_id,res from casino_ops where user_id=$1 and op_id=$2',[uid,id]),
  botLeft:async()=>100,stale:async()=>[],books:async()=>{},history:async()=>[]};
 const {managedStorage}=await import('../supabase/functions/tables/storage.js');managedStorage(D,rpc);
 return {db,D,ids,rpc,first};
}
async function contracts(f){
 const {D,ids,rpc,db,first}=f,{handle,recoverTable}=await import('../supabase/functions/tables/handler.js'),{managedHash,decision}=await import('../supabase/functions/tables/managed.js');
 const {commit}=await import('../supabase/functions/tables/storage.js');const checks=[];const ok=(n,b)=>{assert.ok(b,n);checks.push(n)};
 const owner=randomUUID(),session=ids.map(()=>randomUUID());let lease=await D.world({action:'lease',name:'world',owner});
 ok('new migration starts with admissions and wagers disabled',!(await D.world({action:'config'})).admissions);
 await db.exec('update casino_world_config set admissions=true,new_wagers=true');
 const admit=async(k,code='',takeover=false)=>D.world({action:'admit',uid:ids[k],session:session[k],owner,epoch:lease.epoch,code,takeover});
 const a=await admit(0),ctl={session:session[0],generation:a.generation,owner,epoch:lease.epoch};
 ok('stable six character directory and managed namespace',a.room.startsWith('C:')&&a.code.length===6);
 const others=[];for(let k=1;k<6;k++)others.push(await admit(k,a.code));
 await assert.rejects(admit(6,a.code),/full/);ok('six admissions are bounded',true);
 const overflow=await admit(6);ok('overflow does not evict a member',overflow.room!==a.room);
 const reserve=(k,game,seat,station='',c=ctl)=>D.world({action:'reserve',uid:ids[k],session:session[k],generation:c.generation,owner,epoch:lease.epoch,game,seat,station});
 const res=await reserve(0,'bj',2);
 await assert.rejects(reserve(1,'bj',2,'',{generation:others[0].generation}),/unique|duplicate/);ok('reservation excludes another buyer of the same seat',true);
 let req={op:'sit',room:a.room,game:'bj',seat:2,station:'',opId:'managed_sit_001',reservation:res.reservation,controller:ctl};
 let r=await handle(req,ids[0],D);assert.equal(r.status,200,JSON.stringify(r.body));assert.equal(r.body.error,null);const tid=r.body.id;
 ok('exact reserved seat and automatic blackjack start',r.body.view.me===2&&r.body.view.started&&r.body.view.phase==='bet');
 ok('one atomic buyin',await D.balance(ids[0])===4995);
 const saved=await D.load(tid),bal=await D.balance(ids[0]);const rr=await handle({...req,controller:{session:randomUUID(),generation:999}},ids[0],D);
 ok('accepted retry is pure after revocation',rr.body.replay&&(await D.load(tid)).ver===saved.ver&&(await D.load(tid)).st.seats[2].seen===saved.st.seats[2].seen&&await D.balance(ids[0])===bal);
 const badHash=await handle({...req,seat:1},ids[0],D);ok('changed request under same id refused',badHash.status===409);
 const badCtl=await handle({op:'state',id:tid},ids[0],D);ok('missing controller cannot bypass null comparison',badCtl.status===409);
 const bet={op:'bet',id:tid,amt:1,side:false,opId:'managed_bet_001',expected:r.body.view.expected,controller:ctl};
 const before=await D.load(tid);const bad=await handle({...bet,expected:{...bet.expected,round:987}},ids[0],D);
 ok('stale unaccepted action never wagers',/decision has passed/.test(bad.body.error)&&(await D.load(tid)).st.seats[2].stack===before.st.seats[2].stack&&!await D.opGet(ids[0],bet.opId));
 const newSession=randomUUID();const next=await D.world({action:'admit',uid:ids[0],session:newSession,owner,epoch:lease.epoch,code:a.code,takeover:true});
 const revoked=await handle(bet,ids[0],D);ok('old tab cannot refresh or wager after takeover',revoked.status===409&&!await D.opGet(ids[0],bet.opId));
 const current={session:newSession,generation:next.generation,owner,epoch:lease.epoch};
 const state=await handle({op:'state',id:tid,controller:current},ids[0],D);assert.equal(state.status,200);
 const wager=await handle({...bet,expected:state.body.view.expected,controller:current},ids[0],D);ok('new controller plays existing game',wager.status===200&&!wager.body.error);
 await assert.rejects(rpc('casino_step',{p_table:tid,p_ver:(await D.load(tid)).ver,p_st:(await D.load(tid)).st,p_humans:[ids[0]],p_open:true,p_ops:[],p_hands:[],p_op:null}),/fenced/);ok('legacy writer cannot mutate managed room',true);
 ok('canonical hash excludes transport credentials',managedHash({...bet,reservation:'a',controller:{generation:1}})===managedHash({...bet,reservation:'b',controller:{generation:2}}));
 const wowner=randomUUID(),wl=await D.world({action:'lease',name:'worker',owner:wowner});
 const seenBeforeRepair=(await D.load(tid)).st.seats[2].seen;
 await db.query('update casino_tables set next_due_at=null where id=$1',[tid]);
 ok('startup repair restores a missing deadline',await rpc('casino_recovery_repair',{p_owner:wowner,p_epoch:wl.epoch})===1&&(await first('select next_due_at from casino_tables where id=$1',[tid])).next_due_at!==null);
 ok('schedule repair does not refresh player activity',(await D.load(tid)).st.seats[2].seen===seenBeforeRepair);
 const workerD={...D,now:()=>Date.now()+120000,commit:x=>commit(rpc,x,{worker:true,owner:wowner,epoch:wl.epoch})};
 const rec=await recoverTable(workerD,tid);workerD.now=()=>Date.now()+240000;const rec2=(await D.load(tid)).open?await recoverTable(workerD,tid):{status:200};ok('empty room obligations recover with shared engine',rec.status===200&&rec2.status===200&&!(await D.load(tid)).open);
 await D.world({action:'release',name:'world',owner,epoch:lease.epoch});const newer=await D.world({action:'lease',name:'world',owner:randomUUID()});
 await assert.rejects(D.world({action:'heartbeat',uid:ids[1],session:session[1],generation:others[0].generation,owner,epoch:lease.epoch}),/lease/);ok('old owner fenced after lease takeover',newer.epoch>lease.epoch);
 for(const fn of ['casino_world(jsonb)','casino_managed_step(bigint,integer,jsonb,uuid[],boolean,jsonb,jsonb,jsonb,jsonb)'])for(const role of ['anon','authenticated'])ok(role+' cannot call '+fn,!(await first('select has_function_privilege($1,$2,$3) v',[role,'public.'+fn,'execute'])).v);
 const closed=await first('select open,next_due_at from casino_tables where id=$1',[tid]);ok('closed table has no due time',!closed.open&&closed.next_due_at===null);
 const recover=await handle({op:'recover',session:newSession},ids[0],D);ok('financial recovery controller can be acquired',recover.status===200);
 const recoveryGuard={uid:ids[0],session:newSession,generation:recover.body.generation,op:'topup',wager:true};
 const tClosed=await D.load(tid);await assert.rejects(rpc('casino_managed_step',{p_table:tid,p_ver:tClosed.ver,p_st:tClosed.st,p_humans:[],p_open:false,p_ops:[],p_hands:[],p_op:null,p_guard:recoveryGuard}),/Recovery can finish/);ok('recovery controller refuses unrelated new exposure',true);
 const replayClosed=await handle({...req,controller:{session:newSession,generation:recover.body.generation}},ids[0],D);ok('accepted closed-table replay remains pure',replayClosed.body.replay&&(await D.load(tid)).ver===tClosed.ver);
 // Invitations target the durable room, not a player's process lifetime.
 const authRpc=async(uid,sql,args=[])=>(await db.query("with claim as materialized(select set_config('request.jwt.claim.sub',$1,false)) select "+sql+' r from claim',[uid,...args])).rows[0].r;
 // Restore a live world owner for the invitation sender.
 const currentOwner=await first("select owner,epoch from casino_leases where name='world'");
 const invitedSender=await D.world({action:'admit',uid:ids[1],session:session[1],owner:currentOwner.owner,epoch:currentOwner.epoch,code:a.code});
 await db.query('insert into friendships(user_a,user_b) values(least($1::uuid,$2::uuid),greatest($1::uuid,$2::uuid))',[ids[1],ids[2]]);
 const invite=await authRpc(ids[1],'public.casino_invite_send($2,$3,$4,$5)',[ids[2],a.room,session[1],invitedSender.generation]);
 await D.world({action:'depart',uid:ids[1],session:session[1],generation:invitedSender.generation,owner:currentOwner.owner,epoch:currentOwner.epoch});
 const answer=await authRpc(ids[2],'public.casino_invite_answer($2,true)',[invite.id]);ok('friend invitation survives sender departure',answer.room===a.room&&answer.code===a.code);
 await assert.rejects(authRpc(ids[3],'public.casino_invite_answer($2,true)',[invite.id]),/Invitation not found/);ok('only recipient can accept',true);
 await db.query("update private.lobby_invites set expires_at=clock_timestamp()-interval '1 second' where id=$1",[invite.id]);await assert.rejects(authRpc(ids[2],'public.casino_invite_answer($2,true)',[invite.id]),/expired/);ok('expired managed invite refused',true);
 console.log(JSON.stringify({database:process.env.CASINO_FULL_PG?'PostgreSQL':'PGlite',checks:checks.length,passed:checks},null,2));console.log('errors: none');return checks;
}
module.exports={setup,contracts};
if(require.main===module)(async()=>{const {PGlite}=require('@electric-sql/pglite'),{citext}=require('@electric-sql/pglite/contrib/citext');const db=new PGlite({extensions:{citext}});try{await contracts(await setup(db));}finally{await db.close()}})().catch(e=>{console.error(e);process.exitCode=1});
