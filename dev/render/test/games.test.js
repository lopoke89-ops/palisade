import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {randomUUID} from 'node:crypto';
import {handle,recoverTable} from '../../supabase/functions/tables/handler.js';
import {commit} from '../../supabase/functions/tables/storage.js';
import {managedHash} from '../../supabase/functions/tables/managed.js';
const require=createRequire(new URL('../../test/managed_casino.js',import.meta.url)),{PGlite}=require('@electric-sql/pglite'),{citext}=require('@electric-sql/pglite/contrib/citext'),{setup}=require('./managed_casino');
test('all seven managed games, complete request binding, offline settlement and revocation',{timeout:45000},async()=>{
 const db=new PGlite({extensions:{citext}});try{
  const {D,ids,rpc}=await setup(db);await db.exec('update casino_world_config set admissions=true,new_wagers=true');
  const owner=randomUUID(),lease=await D.world({action:'lease',name:'world',owner}),tables=[];let op=0;
  const sit=async(k,game,seat=0)=>{const session=randomUUID(),a=await D.world({action:'admit',uid:ids[k],session,owner,epoch:lease.epoch}),controller={session,generation:a.generation,owner,epoch:lease.epoch},station=game==='sl'?'s1':game==='pk'?'p1':'';
   const reservation=await D.world({action:'reserve',uid:ids[k],...controller,game,station,seat});
   const r=await handle({op:'sit',room:a.room,game,station,seat,reservation:reservation.reservation,controller,opId:'games_sit_'+ ++op},ids[k],D);assert.equal(r.body.error,null,JSON.stringify(r));return {k,controller,id:r.body.id,view:r.body.view};};
  const send=async(p,b)=>{const r=await handle({id:p.id,controller:p.controller,expected:p.view.expected,opId:'games_action_'+ ++op,...b},ids[p.k],D);assert.equal(r.body.error,null,JSON.stringify(r));p.view=r.body.view;return r;};
  for(const [k,game]of ['bj','he','rl','ba','cr','sl','pk'].entries()){
   const p=await sit(k,game);tables.push(p);await send(p,{op:'topup',amt:25});
   if(game==='he'){const other=await sit(8,game,1);tables.push(other);const state=await handle({op:'state',id:p.id,controller:p.controller},ids[k],D);p.view=state.body.view;assert.equal(p.view.phase,'play');}
   else if(game==='bj')await send(p,{op:'bet',amt:2,side:false});
   else if(game==='rl'){await send(p,{op:'rlbets',bets:{red:1}});await send(p,{op:'rlready'});}
   else if(game==='ba'){await send(p,{op:'babets',bets:{P:1}});await send(p,{op:'baready'});}
   else if(game==='cr'){await send(p,{op:'crbet',k:'pass',amt:1});await send(p,{op:'crflags',flags:{place:true}});await send(p,{op:'crready'});}
   else await send(p,{op:game==='sl'?'spin':'drop',amt:game==='sl'?1:10});
   assert.equal((await D.load(p.id)).st.managedRevision,1);
  }
  for(const [key,a,b]of [['k','pass','field'],['flags',{working:true},{working:false}],['seed','alpha','beta']])assert.notEqual(managedHash({op:'crbet',[key]:a}),managedHash({op:'crbet',[key]:b}),key+' is bound to operation id');
  const p=tables[0];await handle({op:'revoke',controller:p.controller},ids[p.k],D);const rejected=await handle({op:'state',id:p.id,controller:p.controller},ids[p.k],D);assert.equal(rejected.status,409,'logout immediately revokes HTTP controller');
  const workerOwner=randomUUID(),wl=await D.world({action:'lease',name:'worker',owner:workerOwner});
  const workerD={...D,commit:a=>commit(rpc,a,{worker:true,owner:workerOwner,epoch:wl.epoch})};
  for(let cycle=1;cycle<=6;cycle++){workerD.now=()=>Date.now()+cycle*120000;for(const id of new Set(tables.map(x=>x.id)))if((await D.load(id)).open){const r=await recoverTable(workerD,id);assert.equal(r.status,200,JSON.stringify(r));}}
  for(const id of new Set(tables.map(x=>x.id)))assert.equal((await D.load(id)).open,false,'departed '+id+' settles and closes');
  await db.exec("select private.casino_books_day((now() at time zone 'America/New_York')::date)");const books=(await db.query('select ok,tables_closed,bad_tables from casino_books')).rows[0];assert.equal(books.tables_closed,7);assert.equal(books.ok,true,JSON.stringify(books));
  console.log('Managed books:',JSON.stringify(books));
  console.log('All seven managed games accepted legal wagers/actions and recovered without clients; request hashes and HTTP revocation passed.');
 }finally{await db.close();}
});
