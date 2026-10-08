// Full PostgreSQL 17, including real concurrent connections and row/advisory locks.
import test from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {spawn,execFile} from 'node:child_process';
import {promisify} from 'node:util';
import path from 'node:path';
import {mkdir} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import pg from 'pg';
import getBinaries from '../node_modules/embedded-postgres/dist/binary.js';
const require=createRequire(import.meta.url),{setup,contracts}=require('../../test/managed_casino.js');
const run=promisify(execFile);
test('PostgreSQL contracts and concurrent admissions, seating, replay and takeover',{timeout:120000},async()=>{
 const bin=await getBinaries(),dir=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../test/out','pg-casino-'+randomUUID());await mkdir(dir,{recursive:true});
 const port=15434,ctl=path.join(path.dirname(bin.postgres),process.platform==='win32'?'pg_ctl.exe':'pg_ctl');
 await run(bin.initdb,['-D',dir,'-U','postgres','-A','trust','--encoding=UTF8','--locale=C'],{windowsHide:true});
 const child=spawn(bin.postgres,['-D',dir,'-h','127.0.0.1','-p',String(port)],{windowsHide:true,stdio:['ignore','ignore','pipe']});
 const pool=new pg.Pool({host:'127.0.0.1',port,user:'postgres',database:'postgres',max:16});
 try{
  await new Promise((resolve,reject)=>{const timeout=setTimeout(()=>reject(new Error('Postgres startup timeout')),10000);child.once('exit',c=>{clearTimeout(timeout);reject(new Error('Postgres exited '+c));});child.stderr.on('data',x=>{if(String(x).includes('ready to accept connections')){clearTimeout(timeout);resolve();}});});
  const db={exec:q=>pool.query(q),query:(q,a)=>pool.query(q,a)};process.env.CASINO_FULL_PG='1';const f=await setup(db);await contracts(f);
  const {D,ids}=f,{handle}=await import('../../supabase/functions/tables/handler.js');
  await db.exec('truncate casino_reservations,casino_members,casino_controllers cascade;update casino_leases set expires_at=clock_timestamp()');
  const owner=randomUUID(),lease=await D.world({action:'lease',name:'world',owner}),sessions=ids.map(()=>randomUUID());
  const attempts=await Promise.allSettled(ids.map((uid,k)=>D.world({action:'admit',uid,session:sessions[k],owner,epoch:lease.epoch,code:'PALACE'})));
  assert.equal(attempts.filter(x=>x.status==='fulfilled').length,6,'capacity survives simultaneous transactions');
  const occupants=attempts.map((x,k)=>x.status==='fulfilled'?{k,uid:ids[k],a:x.value}:null).filter(Boolean);
  const contenders=occupants.slice(0,2),res=await Promise.allSettled(contenders.map(x=>D.world({action:'reserve',uid:x.uid,session:sessions[x.k],generation:x.a.generation,owner,epoch:lease.epoch,game:'sl',station:'s1',seat:0})));
  assert.equal(res.filter(x=>x.status==='fulfilled').length,1,'only one reservation of a seat');
  const winner=contenders[res.findIndex(x=>x.status==='fulfilled')],reservation=res.find(x=>x.status==='fulfilled').value.reservation;
  const controller={session:sessions[winner.k],generation:winner.a.generation,owner,epoch:lease.epoch};
  const body={op:'sit',room:winner.a.room,game:'sl',station:'s1',seat:0,opId:'parallel_sit_001',reservation,controller},before=await D.balance(winner.uid);
  const retries=await Promise.all(Array.from({length:4},()=>handle(body,winner.uid,D)));
  assert.ok(retries.every(x=>x.status===200&&!x.body.error),JSON.stringify(retries));
  assert.equal(await D.balance(winner.uid),before-5,'four simultaneous sends buy in exactly once');
  assert.equal((await db.query('select count(*)::int n from casino_ops where user_id=$1 and op_id=$2',[winner.uid,body.opId])).rows[0].n,1);
  const newSession=randomUUID(),takeover=D.world({action:'admit',uid:winner.uid,session:newSession,takeover:true,code:winner.a.code,owner,epoch:lease.epoch});
  const move=handle({op:'topup',id:retries[0].body.id,amt:5,opId:'race_topup_001',controller},winner.uid,D);
  const [newController,result]=await Promise.all([takeover,move]);
  const later=await handle({op:'topup',id:retries[0].body.id,amt:5,opId:'race_topup_002',controller},winner.uid,D);
  assert.ok(later.body.error,'old controller loses all subsequent writes');
  assert.equal(await D.balance(winner.uid),before-5-(result.status===200&&!result.body.error?5:0),'wager racing takeover either commits once before revocation or is refused');
  assert.ok(newController.generation>controller.generation);
  console.log('Full PostgreSQL: concurrent capacity, reservation, duplicate buyin, and takeover ledger checks passed.');
 }finally{await pool.end();await run(ctl,['-D',dir,'stop','-m','fast','-w'],{windowsHide:true}).catch(()=>child.kill());delete process.env.CASINO_FULL_PG;}
});
