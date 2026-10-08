// Local disposable load harness. SOAK_SECONDS=7200 by default; a short run is only a smoke check.
const {PGlite}=require('@electric-sql/pglite'),{citext}=require('@electric-sql/pglite/contrib/citext'),{setup}=require('./managed_casino'),{randomUUID}=require('node:crypto'),{performance}=require('node:perf_hooks'),fs=require('node:fs'),assert=require('node:assert/strict'),WS=require('../render/node_modules/ws');
(async()=>{
 const duration=+(process.env.SOAK_SECONDS||7200);assert.ok(duration>=30&&duration<=7200);
 const db=new PGlite({extensions:{citext}}),{D,ids}=await setup(db,{count:60}),{createCasinoService}=await import('../render/server.js');
 await db.exec('update casino_world_config set admissions=true,new_wagers=true');let service=createCasinoService(D,{origins:['http://localhost:8080'],log:()=>{}});await service.start(10000,'127.0.0.1');
 let ending=false,failures=0,samples=[],received=0,statsBefore={},cpuBefore=process.cpuUsage();const clients=[],started=performance.now();
 const connect=async c=>{const ws=new WS('ws://127.0.0.1:10000/casino',{origin:'http://localhost:8080'});c.ws=ws;c.seq=0;c.sent=new Map();
  ws.on('error',()=>{});ws.on('open',()=>ws.send(JSON.stringify({type:'hello',protocol:'casino-1',token:c.uid,session:c.session,code:c.code,cls:'soldier'})));
  ws.on('message',raw=>{const m=JSON.parse(raw);if(m.type==='welcome'){c.code=m.code;c.slot=m.players.find(p=>p.id===c.uid).slot;c.ready=true;c.resolve?.();}else if(m.type==='snapshot'){received++;const me=m.players.find(p=>p[0]===c.slot),seq=me?.[6],at=c.sent.get(seq);if(at){samples.push(performance.now()-at);if(samples.length>20000)samples.shift();for(const n of c.sent.keys())if(n<=seq)c.sent.delete(n);}}else if(m.type==='error')failures++;});
  ws.on('close',()=>{c.ready=false;if(!ending)setTimeout(()=>connect(c),1000+Math.random()*1000)});
 };
 try{
  for(const uid of ids){const c={uid,session:randomUUID(),code:'',ready:false};clients.push(c);await new Promise(async(resolve,reject)=>{c.resolve=resolve;const timeout=setTimeout(()=>reject(new Error('Load admission timeout')),10000);await connect(c);await new Promise(r=>{c.resolve=()=>{clearTimeout(timeout);resolve();r()}});});}
  assert.equal(service.people.size,60);assert.equal(service.health().rooms,10);
  const inputs=setInterval(()=>{for(const c of clients)if(c.ready&&c.ws.readyState===WS.OPEN){const seq=++c.seq;c.sent.set(seq,performance.now());if(c.sent.size>180)c.sent.delete(c.sent.keys().next().value);c.ws.send(JSON.stringify({type:'input',seq,move:[0,0],face:[0,1]}));}},1000/30);
  const startedLoad=performance.now();let replaced=false;while(performance.now()-startedLoad<duration*1000){await new Promise(r=>setTimeout(r,1000));if(!replaced&&performance.now()-startedLoad>duration*500){statsBefore=service.health();await service.stop();service=createCasinoService(D,{origins:['http://localhost:8080'],log:()=>{}});await service.start(10000,'127.0.0.1');replaced=true;}}
  clearInterval(inputs);const sorted=samples.sort((a,b)=>a-b),cpu=process.cpuUsage(cpuBefore),health=service.health();assert.equal(service.people.size,60);assert.equal(health.rooms,10);assert.equal(failures,0);
  const report={scope:'local PGlite and synthetic clients share the server process; not Render capacity evidence',node:process.version,durationSeconds:duration,elapsedSeconds:(performance.now()-started)/1000,clients:60,rooms:10,restart:replaced,received,ackSampleCount:sorted.length,p50Ms:sorted[Math.floor(sorted.length*.5)],p95Ms:sorted[Math.floor(sorted.length*.95)],cpuSeconds:(cpu.user+cpu.system)/1e6,beforeRestart:statsBefore,afterRestart:health};
  fs.mkdirSync(__dirname+'/out/managed',{recursive:true});fs.writeFileSync(__dirname+'/out/managed/load.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));console.log('errors: none');
 }finally{ending=true;clients.forEach(c=>c.ws?.terminate());await service.stop();await db.close();}
})().catch(e=>{console.error(e);process.exitCode=1});
