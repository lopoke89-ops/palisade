import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {randomUUID} from 'node:crypto';
import {WebSocket} from 'ws';
import {createCasinoService} from '../server.js';
const require=createRequire(new URL('../../test/managed_casino.js',import.meta.url)),{PGlite}=require('@electric-sql/pglite'),{citext}=require('@electric-sql/pglite/contrib/citext'),{setup}=require('./managed_casino.js');
const pause=ms=>new Promise(r=>setTimeout(r,ms));
test('an older periodic seat read cannot undo an acknowledged buy-in',{timeout:30000},async()=>{
 const db=new PGlite({extensions:{citext}}),{D,ids}=await setup(db),{handle}=await import('../../supabase/functions/tables/handler.js');
 await db.exec('update casino_world_config set admissions=true,new_wagers=true');
 const service=createCasinoService(D,{origins:['http://127.0.0.1:8080'],log:()=>{}});let c,release;
 try{
  const {port}=await service.start(0,'127.0.0.1');c=client(port,ids[0]);const welcome=await c.wait('welcome'),p=service.people.get(ids[0]);[p.x,p.y]=globalThis.CasinoFloor.CAS_SEAT.get(101).pos;
  c.send({type:'reserve',seat:101});const reservation=(await c.wait('reserved')).reservation;
  let captured;const gate=new Promise(r=>release=r),started=new Promise(r=>captured=r),world=D.world;let held=false;
  D.world=async b=>{const h=await world(b);if(b.action==='heartbeat'&&!held){held=true;captured();await gate;}return h;};
  const old=service.heartbeat();await started;
  const sit=await handle({op:'sit',room:welcome.room,game:'sl',station:'s1',seat:0,reservation,controller:welcome.controller,opId:'sync_'+randomUUID()},ids[0],D);assert.equal(sit.status,200);assert.equal(sit.body.error,null);
  c.send({type:'sync',seq:1});assert.equal((await c.wait('seat')).seat,101);release();await old;assert.equal(p.seat,101,'stale standing response cannot overwrite the committed seat');
  D.world=world;const leave=await handle({op:'leave',id:sit.body.id,controller:welcome.controller,opId:'sync_'+randomUUID()},ids[0],D);assert.equal(leave.status,200);
 }finally{release?.();c?.ws.terminate();await service.stop();await db.close();}
});
test('joining avatars are published only after their identity roster',{timeout:30000},async()=>{
 const db=new PGlite({extensions:{citext}}),{D,ids}=await setup(db);
 await db.exec('update casino_world_config set admissions=true,new_wagers=true');
 let releaseJoin,joinStarted;const gate=new Promise(r=>releaseJoin=r),started=new Promise(r=>joinStarted=r);
 const world=D.world;let blockedOnce=false;D.world=async p=>{if(p.action==='heartbeat'&&p.uid===ids[1]&&!blockedOnce){blockedOnce=true;joinStarted();await gate}return world(p)};
 const service=createCasinoService(D,{origins:['http://127.0.0.1:8080'],log:()=>{}}),clients=[];
 try{
  const {port}=await service.start(0,'127.0.0.1');const a=client(port,ids[0]);clients.push(a);const first=await a.wait('welcome');
  const before=a.messages.length,b=client(port,ids[1],{code:first.code});clients.push(b);
  await started;await pause(180);
  const snapshots=a.messages.slice(before).filter(m=>m.type==='snapshot');assert.ok(snapshots.length,'ticks continue during the database delay');
  assert.ok(snapshots.every(m=>m.players.every(row=>row[0]===first.players[0].slot)),'existing browser never sees an unannounced avatar slot');
  assert.ok(!b.messages.some(m=>['snapshot','roster'].includes(m.type)),'joining browser receives no floor data before welcome');
  releaseJoin();const second=await b.wait('welcome');assert.equal(second.players.length,2);
  await pause(100);const announced=new Set();for(const m of a.messages){if(['welcome','roster'].includes(m.type))for(const p of m.players)announced.add(p.slot);if(m.type==='snapshot')assert.ok(m.players.every(p=>announced.has(p[0])),'roster precedes every new packed slot');}
 }finally{releaseJoin();clients.forEach(c=>c.ws.terminate());await service.stop();await db.close();}
});
function client(port,token,{session=randomUUID(),code='',takeover=false,protocol='casino-1'}={}){
 const ws=new WebSocket(`ws://127.0.0.1:${port}/casino`,{origin:'http://127.0.0.1:8080'}),messages=[];
 ws.on('message',x=>messages.push(JSON.parse(x)));ws.on('error',()=>{});
 ws.on('open',()=>ws.send(JSON.stringify({type:'hello',token,session,code,takeover,protocol,cls:'soldier'})));
 const wait=async type=>{const until=Date.now()+6000;while(Date.now()<until){const m=messages.find(x=>x.type===type);if(m)return m;await pause(20)}throw new Error('No '+type+': '+JSON.stringify(messages));};
 return {ws,messages,wait,session,send:b=>ws.send(JSON.stringify(b))};
}
test('authoritative floor, first/last departure, takeover, privacy and restart',{timeout:45000},async()=>{
 const db=new PGlite({extensions:{citext}}),f=await setup(db),{D,ids}=f;
 await db.exec('update casino_world_config set admissions=true,new_wagers=true');
 let service=createCasinoService(D,{origins:['http://127.0.0.1:8080'],log:()=>{}});const clients=[];
 try{
  const address=await service.start(0,'127.0.0.1');
  const a=client(address.port,ids[0]);clients.push(a);const welcome=await a.wait('welcome');
  const b=client(address.port,ids[1],{code:welcome.code});clients.push(b);assert.equal((await b.wait('welcome')).room,welcome.room);
  a.send({type:'depart'});await new Promise(resolve=>a.ws.once('close',resolve));await pause(100);
  assert.equal(service.people.size,1,'first entrant has no host role');assert.equal(b.ws.readyState,WebSocket.OPEN);
  const p=service.people.get(ids[1]),start=p.x;for(let seq=1;seq<=8;seq++){b.send({type:'input',seq,move:[1,0],face:[1,0]});await pause(35)}await pause(80);
  assert.ok(p.x>start&&p.x-start<1.1,'fixed pace ignores claimed positions');
  const publicMessages=b.messages.filter(x=>x.type==='snapshot');assert.ok(publicMessages.length);
  assert.ok(publicMessages.every(x=>!JSON.stringify(x).includes('token')&&!JSON.stringify(x).includes('seed')&&!JSON.stringify(x).includes('stack')),'floor has no private economic state');
  b.send({type:'chat',text:'<script>hello</script>\u0000'});const chat=await b.wait('chat');assert.equal(chat.text,'<script>hello</script>');
  await service.heartbeat();const before=[p.x,p.y];const same=client(address.port,ids[1],{code:welcome.code});clients.push(same);await same.wait('error');assert.ok(same.messages.some(x=>/another tab/.test(x.error)));
  const replacement=client(address.port,ids[1],{code:welcome.code,takeover:true});clients.push(replacement);await replacement.wait('welcome');await b.wait('revoked');assert.equal(service.people.size,1);
  const claimed=service.people.get(ids[1]);assert.ok(Math.hypot(claimed.x-before[0],claimed.y-before[1])<.01,'safe position checkpoint restored');
  replacement.send({type:'sync',seq:1});const seatAck=await replacement.wait('seat');assert.equal(seatAck.seq,1);assert.equal(seatAck.seat,0,'sync acknowledges the authoritative SQL seat');
  replacement.send({type:'reserve',seat:101});assert.match((await replacement.wait('error')).error,/Walk up/,'remote reservation refused');
  replacement.send({type:'depart'});await new Promise(resolve=>replacement.ws.once('close',resolve));await pause(80);const ticks=service.stats.ticks;await pause(100);assert.equal(service.stats.ticks,ticks,'empty floor is not simulated');
  await service.stop();service=createCasinoService(D,{origins:['http://127.0.0.1:8080'],log:()=>{}});const restarted=await service.start(0,'127.0.0.1');
  const c=client(restarted.port,ids[2],{code:welcome.code});clients.push(c);const r=await c.wait('welcome');assert.equal(r.room,welcome.room);assert.equal(r.players.length,1,'restart has no stale avatar');
  const incompatible=client(restarted.port,ids[3],{code:welcome.code,protocol:'casino-old'});clients.push(incompatible);assert.match((await incompatible.wait('error')).error,/Update/);
  c.send({type:'input',seq:1,move:[999,0],face:[1,0]});assert.match((await c.wait('error')).error,/movement/);
  console.log('WebSocket tests: hostless continuity, shared fixed movement, safe checkpoint, chat/privacy, explicit takeover, empty sleep and stable restart passed.');
 }finally{clients.forEach(x=>x.ws.terminate());await service.stop();await db.close();}
});
