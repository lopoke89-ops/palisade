import test from 'node:test';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createCasinoService} from '../server.js';
const pause=ms=>new Promise(r=>setTimeout(r,ms));
test('60 delayed controller checks finish within the membership budget without overlapping passes',{timeout:10000},async()=>{
 let active=0,max=0,checks=0;const D={
  auth:async token=>{max=Math.max(max,++active);await pause(50);active--;return {id:token,anon:false};},
  world:async p=>{if(p.action==='config')return {revision:1,admissions:true};if(p.action==='lease')return {epoch:1,until:new Date(Date.now()+15000).toISOString(),now:Date.now()};if(p.action==='heartbeat'){await pause(50);checks++;return {seat:null};}return {};}
 };
 const service=createCasinoService(D,{log:()=>{}});try{
  await service.start(0,'127.0.0.1');for(let i=0;i<60;i++)service.people.set('fixture'+i,{id:'fixture'+i,token:'fixture'+i,published:true,heard:performance.now(),room:'fixtureRoom',slot:i%6,queue:[],x:1,y:1,fx:0,fy:1,seat:0,ack:0,ws:{readyState:0,close:()=>assert.fail('Healthy controller was revoked')},session:'fixture',generation:1});
  const at=performance.now();await Promise.all([service.heartbeat(),service.heartbeat()]);assert.equal(checks,60,'One pass refreshes every controller exactly once');assert.ok(max<=4,'Authentication fan-out stays bounded');assert.ok(performance.now()-at<2500,'Regional request latency cannot turn refresh into a serial 6-second pass');
 }finally{service.people.clear();await service.stop();}
});
