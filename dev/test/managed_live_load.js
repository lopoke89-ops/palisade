// Opt-in real staging capacity check. It cannot target production or use a server key.
const assert=require('node:assert/strict'),fs=require('node:fs'),{randomUUID}=require('node:crypto'),{performance}=require('node:perf_hooks'),WS=require('../render/node_modules/ws');
const {project,url:sb,key,refresh}=require('./staging_auth');require('../shared/casino-floor.js');
const {CAS,CAS_SEAT,move,blocked}=globalThis.CasinoFloor;
const service='https://palisade-casino-staging.onrender.com',codes=['PALACE','CASAAA','CASAAB','CASAAC','CASAAD','CASAAE','CASAAF','CASAAG','CASAAH','CASAAJ'];
const sleep=ms=>new Promise(r=>setTimeout(r,ms)),out=__dirname+'/out/managed-live-load',file=__dirname+'/out/soak-accounts.json';
const report={started:new Date().toISOString(),project,service,scope:'60 real staging Auth/WSS clients; 49 walking/chatting and 11 table/cabinet users polling at browser cadence; no network shaping or standing spectator peeks',requests:0,accepted:[],declined:[],errors:[],joins:[],samples:[],refreshes:0,bytesReceived:0};
const ackBins=new Uint32Array(10001);let ackCount=0,ackMax=0;
function ackSummary(){const percentile=p=>{let n=0;for(let i=0;i<ackBins.length;i++){n+=ackBins[i];if(n>=Math.ceil(ackCount*p))return i;}};return {count:ackCount,p50Ms:ackCount?percentile(.5):null,p95Ms:ackCount?percentile(.95):null,maxMs:ackMax,over10Seconds:ackBins[10000],scope:'entire attempt, 1 ms histogram; 10000 ms bucket is a lower bound'};}
const grid=[];for(let i=0;i<=60;i++)for(let j=0;j<=60;j++){const x=.5+i*.25,y=.5+j*.25;if(!blocked(x,y))grid.push({x,y,i,j});}
const closest=p=>grid.reduce((a,b)=>Math.hypot(b.x-p.x,b.y-p.y)<Math.hypot(a.x-p.x,a.y-p.y)?b:a),cell=p=>p.i+','+p.j,free=new Map(grid.map(p=>[cell(p),p]));
function route(start,target){const a=closest(start),z=closest({x:target[0],y:target[1]}),queue=[a],prev=new Map([[cell(a),null]]);for(let k=0;k<queue.length;k++){const p=queue[k];if(cell(p)===cell(z))break;for(const [di,dj]of [[1,0],[-1,0],[0,1],[0,-1]]){const id=(p.i+di)+','+(p.j+dj),q=free.get(id);if(q&&!prev.has(id)){prev.set(id,cell(p));queue.push(q);}}}assert.ok(prev.has(cell(z)));const result=[];for(let id=cell(z);id!==null;id=prev.get(id)){const p=free.get(id);result.unshift([p.x,p.y]);}result.push(target);return result;}
async function until(fn,label,ms=30000){const end=Date.now()+ms;while(Date.now()<end){if(fn())return;await sleep(50);}throw Error('Timeout: '+label);}
const roles=new Map([[0,11],[6,31],[12,51],[18,41],[24,101],[30,117],[36,11],[42,101],[48,51],[54,21],[55,22]]);
class Actor{
 constructor(account,index){this.account=account;this.index=index;this.code=codes[Math.floor(index/6)];this.session=randomUUID();this.seq=0;this.pending=[];this.sent=new Map();this.waypoints=[];this.messages=[];this.lastAct=0;this.closed=false;}
 check(){if(this.failure)throw Error('Actor '+this.index+': '+this.failure);}
 send(b){if(this.ws.readyState===WS.OPEN)this.ws.send(JSON.stringify(b));}
 update(r){if(!r)return;this.position={x:r.x,y:r.y};this.seat=r.seat;this.pending=this.pending.filter(b=>b.seq>r.seq);this.prediction={...this.position};if(!this.seat)for(const b of this.pending)move(this.prediction,...b.move,1/30);const at=this.sent.get(r.seq);if(at){const ms=performance.now()-at;ackBins[Math.min(10000,Math.ceil(ms))]++;ackCount++;ackMax=Math.max(ackMax,ms);for(const seq of this.sent.keys())if(seq<=r.seq)this.sent.delete(seq);}}
 async connect(){const at=performance.now();this.ws=new WS(service.replace('https:','wss:')+'/casino',{origin:'http://localhost:8080'});
  this.ws.on('error',e=>{this.failure=e.message;});this.ws.on('close',code=>{if(!this.closed)this.failure||='Socket closed '+code;});
  this.ws.on('open',()=>this.send({type:'hello',protocol:'casino-1',token:this.account.session.access_token,session:this.session,code:this.code,cls:'soldier',takeover:true}));
  this.ws.on('message',raw=>{report.bytesReceived+=raw.length;const m=JSON.parse(raw);if(m.type==='error'||m.type==='revoked'){this.failure=m.error;return;}if(m.type==='welcome'){this.room=m.room;this.controller=m.controller;this.slot=m.players.find(p=>p.id===this.account.id).slot;this.update(m.players.find(p=>p.id===this.account.id));}if(m.type==='roster')this.update(m.players.find(p=>p.id===this.account.id));if(m.type==='snapshot'){const r=m.players.find(p=>p[0]===this.slot);if(r)this.update({x:r[1]/1000,y:r[2]/1000,seat:r[5],seq:r[6]});}if(m.type==='reserved')this.reservation=m;});
  await until(()=>{this.check();return !!this.controller;},'admission');report.joins.push({index:this.index,code:this.code,ms:performance.now()-at});
 }
 input(){this.check();if(!this.controller||!this.prediction||this.ws.readyState!==WS.OPEN)return;let dx=0,dy=0;
  while(this.waypoints.length&&Math.hypot(this.prediction.x-this.waypoints[0][0],this.prediction.y-this.waypoints[0][1])<.065)this.waypoints.shift();
  if(!this.waypoints.length&&!roles.has(this.index)){const q=grid[Math.floor(Math.random()*grid.length)];this.waypoints=route(this.prediction,[q.x,q.y]);}
  if(this.waypoints.length&&!this.seat){const q=this.waypoints[0],x=q[0]-this.prediction.x,y=q[1]-this.prediction.y,l=Math.hypot(x,y),mag=Math.min(1,l/(3.3/30));if(l>1e-9){dx=x/l*mag;dy=y/l*mag;}}
  const b={type:'input',seq:++this.seq,move:[dx,dy],face:Math.hypot(dx,dy)>.001?[dx,dy]:[0,1]};this.pending.push(b);this.sent.set(b.seq,performance.now());if(this.sent.size>180)this.sent.delete(this.sent.keys().next().value);if(!this.seat)move(this.prediction,dx,dy,1/30);this.send(b);
 }
 async api(body,{allowDecline=false}={}){report.requests++;const r=await fetch(sb+'/functions/v1/tables',{method:'POST',headers:{apikey:key,Authorization:'Bearer '+this.account.session.access_token,'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(20000)}),b=await r.json();
  if(r.status!==200||b.error){if(allowDecline&&r.status===409&&/decision|conflict/.test(b.error||'')){report.declined.push({op:body.op,status:r.status,error:b.error});return null;}throw Error(body.op+': '+r.status+' '+b.error);}
  if(body.opId&&!b.replay)report.accepted.push({op:body.op,opId:body.opId,id:body.id||b.id,index:this.index});return b;
 }
 async act(body){const request={id:this.table.id,controller:this.controller,...(!['topup','leave'].includes(body.op)?{expected:this.table.view.expected}:{}),opId:'soak_'+randomUUID(),...body},b=await this.api(request,{allowDecline:true});if(b)this.table=b;return b;}
 async sit(code){this.busy=true;try{const q=CAS_SEAT.get(code);this.waypoints=route(this.prediction,q.pos);await until(()=>{this.check();return !this.waypoints.length&&Math.hypot(this.position.x-q.pos[0],this.position.y-q.pos[1])<.25;},'walk to table',90000);this.reservation=null;this.send({type:'reserve',seat:code});await until(()=>{this.check();return !!this.reservation;},'exact seat');
  this.table=await this.api({op:'sit',room:this.room,game:q.game,station:q.station,seat:q.k,reservation:this.reservation.reservation,controller:this.controller,opId:'soak_'+randomUUID()});await this.act({op:'topup',amt:100});this.send({type:'sync'});await until(()=>this.seat===code,'committed seat');
 }finally{this.busy=false;}}
 async play(){if(!this.table||this.busy)return;this.busy=true;try{this.table=await this.api({op:'state',id:this.table.id,controller:this.controller});const v=this.table.view;if(v.me<0)throw Error('Unexpected departure');if(v.seats[v.me].stack<20)await this.act({op:'topup',amt:100});
  if(v.game==='bj'&&v.myTurn){await this.act({op:'move',a:'stand'});return;}
  if(v.game==='bj'&&v.insure){await this.act({op:'insure',yes:false});return;}
  if(v.game==='he'&&v.myTurn){await this.act({op:'move',a:'fold'});return;}
  if(Date.now()-this.lastAct<60000)return;
  let b=null;if(v.game==='bj'&&v.phase==='bet'&&!v.bets?.[v.me])b={op:'bet',amt:2,side:false};
  if(v.game==='rl'&&v.phase==='bet'&&!Object.keys(v.myBets||{}).length)b={op:'rlbets',bets:{red:1}};
  if(v.game==='ba'&&v.phase==='bet'&&!Object.keys(v.myBets||{}).length)b={op:'babets',bets:{P:1}};
  if(v.game==='cr'&&v.phase==='bet'&&!Object.keys(v.myBets||{}).length)b={op:'crbet',k:'pass',amt:1};
  if(v.game==='sl'&&v.phase==='idle')b={op:'spin',amt:1};if(v.game==='pk'&&v.phase==='idle')b={op:'drop',amt:10};
  if(b&&await this.act(b)){this.lastAct=Date.now();if(v.game==='rl')await this.act({op:'rlready'});if(v.game==='ba')await this.act({op:'baready'});if(v.game==='cr')await this.act({op:'crready'});}
 }finally{this.busy=false;}}
 async leave(){if(this.table)await this.act({op:'leave'});this.closed=true;this.send({type:'depart'});await sleep(100);this.ws.close(1000,'Capacity test complete');}
}
(async()=>{
 assert.equal(process.env.PALISADE_LIVE_STAGING,'1');const duration=Number(process.env.SOAK_SECONDS||7200);assert.ok(duration>=60&&duration<=7200);report.durationSeconds=duration;report.twoHourGate=duration===7200;assert.ok(process.env.RENDER_EXPECTED_COMMIT,'Pin the deployed commit');
 const credentials=JSON.parse(fs.readFileSync(file,'utf8'));assert.equal(credentials.project,project);assert.equal(credentials.users.length,60);assert.ok(credentials.users.every(u=>u.email.endsWith('@example.test')&&u.session?.user?.id===u.id&&u.session.expires_at*1000>Date.now()+900000));
 fs.mkdirSync(out,{recursive:true});const actors=[],timers=[];let failure=null,refreshing=false;
 const cpuCores=Number(process.env.RENDER_CPU_CORES||.1),ramMB=Number(process.env.RENDER_RAM_MB||512);assert.ok([.1,.5,1,2].includes(cpuCores)&&[512,2048,4096].includes(ramMB),'Record the actual approved instance allocation');report.budgets={cpuCores,ramMB,maxCpuCorePercent:cpuCores*75,maxRssBytes:ramMB*1024*1024*.75};
 const save=()=>{report.ack=ackSummary();fs.writeFileSync(out+'/load.json',JSON.stringify(report,null,2)+'\n');};
 const health=async()=>{const r=await fetch(service+'/readyz',{signal:AbortSignal.timeout(30000)}),h=await r.json();assert.equal(r.status,200);assert.equal(h.ready,true);assert.equal(h.build,process.env.RENDER_EXPECTED_COMMIT);return h;};
 try{report.initialHealth=await health();assert.equal(report.initialHealth.admissions,true);assert.equal(report.initialHealth.occupants,0);assert.ok(report.initialHealth.metrics&&report.initialHealth.storage,'Capacity instrumentation required');
  // Node rounds interval delays to milliseconds. A plain 33 ms timer sends 30.3 Hz,
  // which eventually fills a correct 30 Hz server queue. Pace by elapsed time.
  let inputAt=performance.now(),inputAcc=0;
  timers.push(setInterval(()=>{const now=performance.now();inputAcc+=Math.min((now-inputAt)/1000,.2);inputAt=now;try{let n=0;while(inputAcc>=1/30&&n++<6){inputAcc-=1/30;for(const a of actors)a.input();}}catch(e){failure=e;}},1000/60));
  for(let i=0;i<60;i++){const a=new Actor(credentials.users[i],i);actors.push(a);await a.connect();}
  const full=await health();assert.equal(full.occupants,60);assert.equal(full.rooms,10);report.fullHealth=full;
  timers.push(setInterval(()=>{for(const a of actors)if(a.table)a.play().catch(e=>{failure=e;});},1000));
  for(const [i,seat]of roles)await actors[i].sit(seat);
  timers.push(setInterval(()=>{for(const a of actors)if(!a.table)a.send({type:'chat',text:'Staging capacity check '+a.index});},30000));
  timers.push(setInterval(async()=>{if(refreshing)return;refreshing=true;try{for(const a of actors)if(a.account.session.expires_at*1000<Date.now()+900000){await refresh(a.account);fs.writeFileSync(file,JSON.stringify(credentials,null,2)+'\n');a.send({type:'token',token:a.account.session.access_token});report.refreshes++;await sleep(3000);}}catch(e){failure=e;}finally{refreshing=false;}},60000));
  const start=Date.now();while(Date.now()-start<duration*1000){if(failure)throw failure;for(const a of actors)a.check();await sleep(10000);const h=await health();report.samples.push({at:new Date().toISOString(),health:h});save();assert.equal(h.occupants,60);assert.equal(h.rooms,10);assert.equal(h.worker.errors,report.initialHealth.worker.errors,'Recovery errors during capacity test');assert.ok(h.metrics.cpuCorePercent<=report.budgets.maxCpuCorePercent,'25% CPU headroom');assert.ok(h.rssBytes<=report.budgets.maxRssBytes,'25% memory headroom');assert.ok(h.metrics.tickP95Ms<1000/30,'Tick p95 within fixed simulation budget');if(h.stats.egressBytes-report.initialHealth.stats.egressBytes>1.8e9)throw Error('Staging traffic budget reached');console.log(JSON.stringify({elapsedSeconds:Math.round((Date.now()-start)/1000),occupants:h.occupants,cpuCorePercent:h.metrics.cpuCorePercent,rssBytes:h.rssBytes,workerSteps:h.worker.steps,edgeRequests:report.requests}));}
  report.completed=true;report.finished=new Date().toISOString();report.finalHealth=await health();const join=report.joins.map(j=>j.ms).sort((a,b)=>a-b);report.joinP95Ms=join[Math.ceil(join.length*.95)-1];
 }catch(e){report.errors.push(e.message);process.exitCode=1;}
 finally{report.actorFailures=actors.filter(a=>a.failure).map(a=>({index:a.index,error:a.failure}));timers.forEach(clearInterval);for(const a of actors){try{await until(()=>!a.busy,'in-flight action',25000);await a.leave();}catch(e){report.errors.push('Cleanup actor '+a.index+': '+e.message);a.closed=true;a.ws?.terminate();}}if(report.errors.length){report.completed=false;process.exitCode=1;}save();}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
