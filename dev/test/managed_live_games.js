// Opt-in real Auth -> Render movement/reservation -> Edge -> PostgreSQL game check.
// No server secret, economic mocks, invented user tokens, teleportation or clock overrides.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{randomUUID}=require('node:crypto'),WS=require('../render/node_modules/ws');
require('../shared/casino-floor.js');
const {CAS_SEAT,blocked,move}=globalThis.CasinoFloor;
const project='nxsqerlpqdzrjwqxhsdz',sb=`https://${project}.supabase.co`,service='https://palisade-casino-staging.onrender.com',key='sb_publishable_m1R1Frx4Te72Yl2qrINhKQ_VxV02RvV';
const sleep=ms=>new Promise(r=>setTimeout(r,ms)),out=path.join(__dirname,'out/managed-live');
const report={started:new Date().toISOString(),project,service,scope:'real staging WSS/Edge/Auth; two scripted saved accounts, not browser UI or capacity certification',games:[],requests:[],errors:[]};
async function until(fn,label,ms=20000){const end=Date.now()+ms;while(Date.now()<end){if(await fn())return;await sleep(100)}throw Error('Timeout: '+label)}
async function api(account,body){
 const at=Date.now(),r=await fetch(sb+'/functions/v1/tables',{method:'POST',headers:{apikey:key,Authorization:'Bearer '+account.session.access_token,'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(20000)}),b=await r.json();
 report.requests.push({op:body.op,opId:body.opId||null,id:body.id||b.id||null,status:r.status,error:b.error||null,replay:!!b.replay,ms:Date.now()-at});
 if(r.status!==200||b.error)throw Error(body.op+': '+r.status+' '+b.error);
 return b;
}
// Quarter-tile cardinal paths use the same collision model and fixed-step movement as the client.
const grid=[];for(let i=0;i<=60;i++)for(let j=0;j<=60;j++){const x=.5+i*.25,y=.5+j*.25;if(!blocked(x,y))grid.push({x,y,i,j})}
const closest=p=>grid.reduce((a,b)=>Math.hypot(b.x-p.x,b.y-p.y)<Math.hypot(a.x-p.x,a.y-p.y)?b:a);
function route(start,target){
 const a=closest(start),z=closest({x:target[0],y:target[1]}),key=p=>p.i+','+p.j,free=new Map(grid.map(p=>[key(p),p])),queue=[a],prev=new Map([[key(a),null]]);
 for(let k=0;k<queue.length;k++){const p=queue[k];if(key(p)===key(z))break;for(const [di,dj]of [[1,0],[-1,0],[0,1],[0,-1]]){const id=(p.i+di)+','+(p.j+dj),q=free.get(id);if(q&&!prev.has(id)){prev.set(id,key(p));queue.push(q)}}}
 assert.ok(prev.has(key(z)),'Seat is reachable');const result=[];for(let id=key(z);id!==null;id=prev.get(id)){const p=free.get(id);result.unshift([p.x,p.y])}result.push(target);return result;
}
class Actor{
 constructor(account){this.account=account;this.session=randomUUID();this.seq=0;this.pending=[];this.position=null;this.prediction=null;this.waypoints=[];this.messages=[];this.ending=false;this.lastSync=0;}
 async connect(){
  this.ws=new WS(service.replace('https:','wss:')+'/casino',{origin:'http://localhost:8080'});
  this.ws.on('error',e=>{this.failure=e.message});this.ws.on('close',(code)=>{if(!this.ending)this.failure='Socket closed '+code});
  this.ws.on('open',()=>this.send({type:'hello',protocol:'casino-1',token:this.account.session.access_token,session:this.session,code:'PALACE',cls:'soldier',takeover:true}));
  this.ws.on('message',raw=>{
   const m=JSON.parse(raw);this.messages.push(m);if(this.messages.length>30)this.messages.shift();
   if(m.type==='error'||m.type==='revoked'){this.failure=m.error;return}
   if(m.type==='welcome'){this.room=m.room;this.controller=m.controller;this.slot=m.players.find(p=>p.id===this.account.id).slot;this.update(m.players.find(p=>p.id===this.account.id));}
   if(m.type==='roster')this.update(m.players.find(p=>p.id===this.account.id));
   if(m.type==='snapshot'){const r=m.players.find(p=>p[0]===this.slot);if(r)this.update({x:r[1]/1000,y:r[2]/1000,seat:r[5],seq:r[6]});}
  });
  await until(()=>{this.check();return !!this.controller},'real floor admission');
  this.timer=setInterval(()=>{
   if(this.ws.readyState!==WS.OPEN)return;
   let dx=0,dy=0;while(this.waypoints.length&&Math.hypot(this.prediction.x-this.waypoints[0][0],this.prediction.y-this.waypoints[0][1])<.065)this.waypoints.shift();
   if(this.waypoints.length&&!this.seat){const q=this.waypoints[0],x=q[0]-this.prediction.x,y=q[1]-this.prediction.y,l=Math.hypot(x,y),mag=Math.min(1,l/(3.3/30));dx=x/l*mag;dy=y/l*mag;}
   const b={type:'input',seq:++this.seq,move:[dx,dy],face:Math.hypot(dx,dy)>.001?[dx,dy]:[0,1]};this.pending.push(b);if(!this.seat)move(this.prediction,dx,dy,1/30);this.send(b);
  },1000/30);
 }
 send(b){if(this.ws.readyState===WS.OPEN)this.ws.send(JSON.stringify(b));}
 check(){if(this.failure)throw Error(this.failure);}
 update(r){if(!r)return;this.position={x:r.x,y:r.y};this.seat=r.seat;this.pending=this.pending.filter(b=>b.seq>r.seq);this.prediction={...this.position};if(!this.seat)for(const b of this.pending)move(this.prediction,...b.move,1/30);}
 async sync(seat){await sleep(Math.max(0,this.lastSync+1100-Date.now()));this.lastSync=Date.now();this.send({type:'sync'});await until(()=>{this.check();return this.seat===seat},'committed seat '+seat);}
 async walk(code){const q=CAS_SEAT.get(code);assert.ok(q);assert.equal(this.seat,0);this.waypoints=route(this.prediction,q.pos);await until(()=>{this.check();return !this.waypoints.length&&Math.hypot(this.position.x-q.pos[0],this.position.y-q.pos[1])<.25},'walk to '+q.game,80000);}
 async sit(code){
  await this.walk(code);this.messages=[];this.send({type:'reserve',seat:code});await until(()=>{this.check();return this.messages.some(m=>m.type==='reserved'&&m.seat===code)},'exact reservation');
  const q=CAS_SEAT.get(code),reservation=this.messages.find(m=>m.type==='reserved').reservation;
  this.lastAccepted={op:'sit',room:this.room,game:q.game,station:q.station,seat:q.k,reservation,controller:this.controller,opId:'live_'+randomUUID()};
  this.table=await api(this.account,this.lastAccepted);await this.sync(code);return this.table;
 }
 async state(){this.table=await api(this.account,{op:'state',id:this.table.id,controller:this.controller});return this.table.view;}
 async action(body){this.lastAccepted={id:this.table.id,controller:this.controller,...(!['topup','leave'].includes(body.op)?{expected:this.table.view.expected}:{}),opId:'live_'+randomUUID(),...body};this.table=await api(this.account,this.lastAccepted);return this.table;}
 async replay(body=this.lastAccepted){const r=await api(this.account,body);assert.equal(r.replay,true,'Accepted retry must be pure replay');return r;}
 async leave(){await this.action({op:'leave'});}
 close(){this.ending=true;clearInterval(this.timer);this.ws?.close(1000,'Staging check complete');}
}
(async()=>{
 assert.equal(process.env.PALISADE_LIVE_STAGING,'1','Explicit live-staging opt-in required');
 const credentials=JSON.parse(fs.readFileSync(process.env.STAGING_ACCOUNTS_FILE||path.join(__dirname,'out/staging-accounts.json'),'utf8'));assert.equal(credentials.project,project);assert.equal(credentials.users.length,7);
 assert.ok(credentials.users.every(u=>u.email.endsWith('@example.test')&&u.session?.user?.id===u.id&&!u.session.user.is_anonymous));assert.ok(credentials.users.every(u=>u.session.expires_at*1000>Date.now()+900000),'Refresh the real saved-account sessions first');
 fs.mkdirSync(out,{recursive:true});const actors=[new Actor(credentials.users[0]),new Actor(credentials.users[1])];
 try{
  report.initialHealth=await fetch(service+'/readyz').then(r=>r.json());assert.equal(report.initialHealth.ready,true);assert.equal(report.initialHealth.admissions,true);
  await actors[0].connect();let p=actors[0];
  for(const [game,code]of [['bj',11],['he',21],['rl',31],['ba',51],['cr',41],['sl',101],['pk',117]]){
   const record={game,started:new Date().toISOString()};report.games.push(record);await p.sit(code);record.id=p.table.id;await p.replay();await p.action({op:'topup',amt:25});await p.replay();
   if(game==='he'){
    const q=actors[1];await q.connect();await q.sit(22);await p.state();assert.equal(p.table.view.phase,'play');record.accepted='two humans start with automatic blinds';
    await until(async()=>{const v=await p.state(),v2=await q.state();if(v.myTurn){await p.action({op:'move',a:'fold'});record.accepted+=' and a legal fold';return true}if(v2.myTurn){await q.action({op:'move',a:'fold'});record.accepted+=' and a legal fold';return true}return false},'Holdem human turn',15000);
    await q.leave();await p.leave();q.close();
   }else{
    if(game==='bj'){await p.action({op:'bet',amt:2,side:false});record.accepted='2 shard bet';}
    if(game==='rl'){await p.action({op:'rlbets',bets:{red:1}});await p.action({op:'rlready'});record.accepted='1 shard red bet and ready';}
    if(game==='ba'){await p.action({op:'babets',bets:{P:1}});await p.action({op:'baready'});record.accepted='1 shard Player bet and ready';}
    if(game==='cr'){
     // Reach an actual locked Pass point before departing. Random outcome is not injected.
     for(let attempt=0;attempt<10;attempt++){
      await until(async()=>{const v=await p.state();return v.phase==='bet'},'craps betting phase',30000);
      await p.action({op:'crbet',k:'pass',amt:1});await p.action({op:'crflags',flags:{place:true}});const before=p.table.view.handNo;await p.action({op:'crready'});
      await until(async()=>{const v=await p.state();return v.handNo>before},'real craps roll',30000);
      if(p.table.view.point&&p.table.view.locked.includes('pass')){record.lockedPoint=p.table.view.point;record.rollsBeforeDeparture=p.table.view.handNo;break;}
     }
     assert.ok(record.lockedPoint,'Natural rolls must establish a locked Pass point');record.accepted='1 shard locked Pass bet, flags and ready';
    }
    if(game==='sl'){await p.action({op:'spin',amt:1});record.accepted='1 shard spin';}
    if(game==='pk'){await p.action({op:'drop',amt:10});record.accepted='10 shard drop';}
    record.acceptedOperation=p.lastAccepted.opId;const retry={...p.lastAccepted};await p.replay(retry);await p.leave();
    if(game==='cr'){
     // No client remains at this table, and no further state request advances its clock.
     p.close();record.floorDisconnectedAt=new Date().toISOString();
     await until(async()=>!(await api(p.account,{op:'lobby'})).mine,'worker-only departed craps settlement',90000);
     const staleRetry=await p.replay(retry);assert.equal(staleRetry.replay,true);record.replayAfterControllerDeparture=true;
     actors[0]=new Actor(p.account);await actors[0].connect();p=actors[0];
    }
   }
   await until(async()=>!(await api(p.account,{op:'lobby'})).mine,'departure cashout',60000);
   await p.sync(0);const lobby=await api(p.account,{op:'lobby'});record.balance=lobby.balance;record.finished=new Date().toISOString();record.settled=true;
   console.log(JSON.stringify({game:record.game,id:record.id,settled:record.settled,balance:record.balance,lockedPoint:record.lockedPoint}));
  }
  const history=await api(actors[0].account,{op:'history'});report.historyGames=[...new Set(history.hands.map(h=>h.game))];for(const game of ['bj','he','rl','ba','cr','sl','pk'])assert.ok(report.historyGames.includes(game),'Real settled history for '+game);
  report.afterHealth=await fetch(service+'/healthz').then(r=>r.json());report.workerErrorDelta=report.afterHealth.worker.errors-report.initialHealth.worker.errors;assert.equal(report.workerErrorDelta,0,'No new worker errors during game check');report.finished=new Date().toISOString();report.passed=true;
 }catch(e){report.errors.push(e.message);throw e;}
 finally{
  for(const p of actors){if(p.table){try{const lobby=await api(p.account,{op:'lobby'});if(lobby.mine)await api(p.account,{op:'leave',id:lobby.mine.id,controller:p.controller,opId:'cleanup_'+randomUUID()});}catch(e){report.errors.push('Cleanup: '+e.message)}}p.close();}
  fs.writeFileSync(out+'/games.json',JSON.stringify(report,null,2)+'\n');
 }
})().catch(e=>{console.error(e);process.exitCode=1});
