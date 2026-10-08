import test from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {WebSocket} from 'ws';
import {createRelay,WIRE,GAME} from '../relay.js';
const sleep=ms=>new Promise(r=>setTimeout(r,ms)),origin='http://test.example';
const identity={verify:async token=>{if(!/^user[0-9]+$/.test(token))throw new Error('Saved account required');return {uid:token,name:token,expires:Date.now()+60000}},restore:async()=>false};
function connect(port,role,token,extra={}){
 const ws=new WebSocket(`ws://127.0.0.1:${port}/relay`,{origin}),messages=[];
 ws.on('error',()=>{});ws.on('message',raw=>messages.push(JSON.parse(raw)));ws.on('open',()=>ws.send(JSON.stringify({type:'hello',wire:WIRE,game:GAME,role,token,session:'a'.repeat(24),incarnation:randomUUID(),...extra})));
 const wait=async type=>{const end=Date.now()+3000;while(Date.now()<end){const m=messages.find(m=>m.type===type);if(m)return m;await sleep(5)}throw new Error('Missing '+type+': '+JSON.stringify(messages))};
 return {ws,messages,wait,send:b=>ws.send(JSON.stringify(b))};
}
test('real sockets: six players, authenticated routing, grace, lock, kick, and host-owned closure',async()=>{
 const relay=createRelay({origins:[origin],identity,graceMs:150}),port=await relay.start();const sockets=[];
 try{
  const h=connect(port,'host','user0');sockets.push(h);const hw=await h.wait('welcome');assert.match(hw.code,/^R[A-Z2-9]{5}$/);
  assert.equal((await fetch(`http://127.0.0.1:${port}/rooms`)).status,404,'the relay must not expose an alternate directory of unlisted rooms');
  const gs=[];for(let i=1;i<6;i++){const g=connect(port,'guest','user'+i,{code:hw.code,incarnation:hw.incarnation});sockets.push(g);gs.push(g);await g.wait('welcome')}
  assert.equal(relay.people.size,6);
  const full=connect(port,'guest','user6',{code:hw.code});sockets.push(full);assert.match((await full.wait('error')).message,/full/);
  const gw=gs[0].messages[0];gs[0].send({type:'packet',to:gs[1].messages[0].id,data:{t:'hello',uid:'forged',name:'forged',session:'forged',v:'forged',cls:'soldier'}});
  const received=await h.wait('packet');assert.equal(received.from,gw.id);assert.equal(received.data.uid,'user1');assert.equal(received.data.name,'user1');assert.equal(received.data.v,GAME);
  assert.equal(gs[1].messages.some(m=>m.type==='packet'),false,'a guest cannot route to another guest');
  h.send({type:'packet',to:gw.id,data:{t:'c',m:'hello'}});assert.equal((await gs[0].wait('packet')).data.m,'hello');
  gs[0].ws.terminate();await sleep(30);assert.equal(relay.people.size,6,'brief outage retains the seat');
  const resumed=connect(port,'guest','user1',{resume:gw.resume,code:hw.code});sockets.push(resumed);assert.equal((await resumed.wait('welcome')).id,gw.id,'verified resume retains peer identity');
  const forged=connect(port,'guest','user6',{resume:gw.resume,code:hw.code});sockets.push(forged);assert.match((await forged.wait('error')).message,/resume/);
  h.send({type:'remove',peer:gw.id,ban:true});await sleep(30);assert.equal(relay.people.size,5);
  const banned=connect(port,'guest','user1',{code:hw.code});sockets.push(banned);assert.match((await banned.wait('error')).message,/removed/);
  h.send({type:'room',locked:true});await sleep(15);const locked=connect(port,'guest','user6',{code:hw.code});sockets.push(locked);assert.match((await locked.wait('error')).message,/locked/);
  h.send({type:'room',locked:false});await sleep(15);const wrong=connect(port,'guest','user6',{code:hw.code,incarnation:randomUUID()});sockets.push(wrong);assert.match((await wrong.wait('error')).message,/earlier/);
  h.ws.terminate();await sleep(30);assert.equal(relay.rooms.size,1,'host outage gets bounded grace');
  const hb=connect(port,'host','user0',{resume:hw.resume,code:hw.code});sockets.push(hb);assert.equal((await hb.wait('welcome')).id,hw.id);
  hb.send({type:'depart'});await sleep(30);assert.equal(relay.rooms.size,0);assert.equal(relay.people.size,0);assert.ok(gs[1].messages.some(m=>m.type==='closed'));
 }finally{for(const s of sockets)s.ws.terminate();await relay.stop()}
});
test('host expiry closes the lobby and an unauthenticated account cannot enter',async()=>{
 const relay=createRelay({origins:[origin],identity,graceMs:40}),port=await relay.start();const sockets=[];
 try{const bad=connect(port,'host','forged');sockets.push(bad);assert.match((await bad.wait('error')).message,/Saved account/);assert.equal(relay.rooms.size,0);
  const h=connect(port,'host','user0');sockets.push(h);await h.wait('welcome');h.ws.terminate();await sleep(100);assert.equal(relay.rooms.size,0);assert.equal(relay.people.size,0);
 }finally{for(const s of sockets)s.ws.terminate();await relay.stop()}
});
test('rooms isolate routing, token changes are refused, and floods do not evict other players',async()=>{
 const relay=createRelay({origins:[origin],identity,graceMs:40}),port=await relay.start(),sockets=[];
 try{
  const h1=connect(port,'host','user0'),h2=connect(port,'host','user1');sockets.push(h1,h2);const a=await h1.wait('welcome'),b=await h2.wait('welcome');
  const g1=connect(port,'guest','user2',{code:a.code,incarnation:a.incarnation}),g2=connect(port,'guest','user3',{code:b.code,incarnation:b.incarnation});sockets.push(g1,g2);await g1.wait('welcome');const gb=await g2.wait('welcome');
  h1.send({type:'packet',to:gb.id,data:{t:'c',m:'wrong room'}});await sleep(20);assert.equal(g2.messages.some(m=>m.type==='packet'),false);
  g1.send({type:'token',token:'user4'});assert.match((await g1.wait('error')).message,/Account changed/);await sleep(80);assert.equal(relay.people.size,3);
  for(let i=0;i<100;i++)g2.send({type:'ping'});await sleep(80);assert.equal(g2.ws.readyState,WebSocket.CLOSED);assert.equal(relay.rooms.size,2,'flood only closes its own connection');
  h1.send({type:'depart'});h2.send({type:'depart'});await sleep(25);assert.equal(relay.rooms.size,0);
 }finally{for(const s of sockets)s.ws.terminate();await relay.stop()}
});

test('repeated hello messages cannot race a delayed identity lookup into duplicate rooms',async()=>{
 let lookups=0,release;const pending=new Promise(resolve=>release=resolve);
 const slowIdentity={verify:async token=>{lookups++;await pending;return identity.verify(token)}};
 const relay=createRelay({origins:[origin],identity:slowIdentity}),port=await relay.start();
 const h=connect(port,'host','user0');
 try{
  while(!lookups)await sleep(5);
  const hello={type:'hello',wire:WIRE,game:GAME,role:'host',token:'user0',session:'a'.repeat(24),incarnation:randomUUID()};
  h.send(hello);h.send(hello);await sleep(30);assert.equal(lookups,1,'only one lookup may own this connection');
  release();await h.wait('welcome');await sleep(20);assert.equal(relay.rooms.size,1);assert.equal(relay.people.size,1);
  h.send({type:'depart'});await sleep(20);assert.equal(relay.rooms.size,0);assert.equal(relay.people.size,0);
 }finally{release();h.ws.terminate();await relay.stop()}
});

test('untrusted origins and oversized messages cannot enter or disrupt another player',async()=>{
 const relay=createRelay({origins:[origin],identity,graceMs:40}),port=await relay.start(),sockets=[];
 try{
  const rejected=new WebSocket(`ws://127.0.0.1:${port}/relay`,{origin:'https://untrusted.example'});
  const originError=await new Promise(resolve=>rejected.on('error',resolve));assert.match(originError.message,/403/);assert.equal(relay.people.size,0);
  const h=connect(port,'host','user0');sockets.push(h);const w=await h.wait('welcome');
  const g=connect(port,'guest','user1',{code:w.code,incarnation:w.incarnation});sockets.push(g);await g.wait('welcome');g.ws.send('x'.repeat(65537));
  await sleep(100);assert.equal(g.ws.readyState,WebSocket.CLOSED);assert.equal(h.ws.readyState,WebSocket.OPEN);assert.equal(relay.rooms.size,1);assert.equal(relay.people.size,1);
  h.send({type:'depart'});await sleep(20);assert.equal(relay.rooms.size,0);
 }finally{for(const s of sockets)s.ws.terminate();await relay.stop()}
});

test('an expired host token closes its room and all guest access',async()=>{
 const expiring={verify:async token=>({...await identity.verify(token),expires:Date.now()+(token==='user0'?100:60000)})};
 const relay=createRelay({origins:[origin],identity:expiring}),port=await relay.start(),sockets=[];
 try{
  const h=connect(port,'host','user0');sockets.push(h);const w=await h.wait('welcome');const g=connect(port,'guest','user1',{code:w.code,incarnation:w.incarnation});sockets.push(g);await g.wait('welcome');
  await sleep(10500);assert.equal(relay.rooms.size,0);assert.equal(relay.people.size,0);assert.ok(h.messages.some(m=>m.type==='error'&&/Sign in again/.test(m.message)));assert.ok(g.messages.some(m=>m.type==='closed'));
 }finally{for(const s of sockets)s.ws.terminate();await relay.stop()}
});

test('a stalled receiver expires without blocking another guest',async()=>{
 const relay=createRelay({origins:[origin],identity,graceMs:40}),port=await relay.start(),sockets=[];
 try{
  const h=connect(port,'host','user0');sockets.push(h);const w=await h.wait('welcome');
  const slow=connect(port,'guest','user1',{code:w.code,incarnation:w.incarnation}),fast=connect(port,'guest','user2',{code:w.code,incarnation:w.incarnation});sockets.push(slow,fast);
  const sw=await slow.wait('welcome'),fw=await fast.wait('welcome');slow.ws._socket.pause();
  for(let i=0;i<200;i++){h.send({type:'packet',to:sw.id,data:{t:'s',pad:'x'.repeat(12000)}});await sleep(30)}
  h.send({type:'packet',to:fw.id,data:{t:'c',m:'still connected'}});assert.equal((await fast.wait('packet')).data.m,'still connected');assert.equal(h.ws.readyState,WebSocket.OPEN);
  // OS send buffers can absorb this local load; an unread socket must still lose access at the heartbeat deadline.
  await sleep(15000);assert.equal(relay.people.has(sw.id),false);assert.equal(relay.people.has(fw.id),true);assert.equal(relay.people.has(w.id),true);
  fast.messages.length=0;h.send({type:'packet',to:fw.id,data:{t:'c',m:'after stalled peer expired'}});assert.equal((await fast.wait('packet')).data.m,'after stalled peer expired');
  slow.ws._socket.resume();h.send({type:'depart'});await sleep(40);assert.equal(relay.rooms.size,0);assert.equal(relay.people.size,0);
 }finally{for(const s of sockets){s.ws._socket?.resume();s.ws.terminate()}await relay.stop()}
});
