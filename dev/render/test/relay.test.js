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
