import http from 'node:http';
import {randomUUID} from 'node:crypto';
import {performance} from 'node:perf_hooks';
import {pathToFileURL} from 'node:url';
import {WebSocketServer,WebSocket} from 'ws';
import '../shared/casino-floor.js';
import {restStorage} from '../supabase/functions/tables/storage.js';
import {RecoveryWorker} from './worker.js';
import {serviceMetrics} from './metrics.js';
const {CAS,CAS_SEAT,move,blocked}=globalThis.CasinoFloor;
const PROTOCOL='casino-1',MAX_PAYLOAD=4096,MAX_QUEUE=64*1024;
const clean=s=>String(s||'').replace(/[\x00-\x1f\x7f]/g,'').replace(/\s+/g,' ').trim().slice(0,120);
export function createCasinoService(D,{origins=['https://lopoke89-ops.github.io'],owner=randomUUID(),log=console.log}={}){
 const sockets=new Set(),people=new Map();let epoch=0,until=0,draining=false,renewing=false,heartbeating=false,config=null,last=performance.now(),acc=0,step=0;
 const stats={connections:0,snapshots:0,rejected:0,ticks:0,egressBytes:0,ingressBytes:0,tickMaxMs:0,bufferMaxBytes:0,inputQueueMax:0,coalescedSnapshots:0,heartbeatFailures:0};let authBusy=0,authWindow=performance.now(),authCount=0;
 const metrics=serviceMetrics(),ready=()=>!draining&&epoch>0&&performance.now()<until&&config?.revision===1;
 const authenticate=async token=>{if(authBusy>=8)throw new Error('Authentication busy. Reconnect shortly');authBusy++;try{return await D.auth(token)}finally{authBusy--}};
 const worker=new RecoveryWorker(D,owner,{log});
 const health=()=>({ok:true,protocol:PROTOCOL,layout:1,revision:1,build:process.env.RENDER_GIT_COMMIT||'local',ready:ready(),admissions:!!config?.admissions,standby:!epoch,occupants:people.size,rooms:new Set([...people.values()].map(p=>p.room)).size,worker:worker.stats,stats,metrics:metrics.stats,storage:D.metrics||null,rssBytes:process.memoryUsage().rss,uptimeSeconds:Math.floor(process.uptime())});
 const server=http.createServer((req,res)=>{
  const origin=req.headers.origin;if(origin&&origins.includes(origin))res.setHeader('Access-Control-Allow-Origin',origin);
  res.setHeader('Vary','Origin');res.setHeader('Cache-Control','no-store');res.setHeader('Content-Type','application/json');
  if(req.url==='/healthz'){res.writeHead(200);res.end(JSON.stringify(health()));}
  else if(req.url==='/readyz'){const h=health();res.writeHead(h.ready?200:503);res.end(JSON.stringify(h));}
  else if(req.url==='/rooms'&&req.method==='GET')D.world({action:'directory'}).then(x=>res.end(JSON.stringify(x))).catch(()=>{res.writeHead(503);res.end('{"error":"Casino unavailable"}');});
  else{res.writeHead(404);res.end('{"error":"Not found"}');}
 });
 const wss=new WebSocketServer({noServer:true,maxPayload:MAX_PAYLOAD,perMessageDeflate:false});
 server.on('upgrade',(req,socket,head)=>{
  if(req.url!=='/casino'||!origins.includes(req.headers.origin)||!health().ready||!health().admissions||sockets.size>=96){socket.write('HTTP/1.1 503 Service Unavailable\r\nConnection: close\r\n\r\n');socket.destroy();return}
  wss.handleUpgrade(req,socket,head,ws=>wss.emit('connection',ws));
 });
 const send=(ws,msg)=>{if(ws.readyState!==WebSocket.OPEN)return;stats.bufferMaxBytes=Math.max(stats.bufferMaxBytes,ws.bufferedAmount);if(ws.bufferedAmount>MAX_QUEUE){ws.close(1013,'Connection too slow');return}if(msg.type==='snapshot'&&ws.bufferedAmount>MAX_QUEUE/4){stats.coalescedSnapshots++;return}const data=JSON.stringify(msg);stats.egressBytes+=Buffer.byteLength(data);ws.send(data);};
 const broadcast=(room,msg)=>{for(const p of people.values())if(p.published&&p.room===room)send(p.ws,msg);};
 const row=p=>({id:p.id,slot:p.slot,name:p.name,cls:p.cls,cos:p.cos,x:p.x,y:p.y,fx:p.fx,fy:p.fy,seat:p.seat,seq:p.ack});
 const packed=p=>[p.slot,Math.round(p.x*1000),Math.round(p.y*1000),Math.round(p.fx*1000),Math.round(p.fy*1000),p.seat,p.ack];
 const scope=p=>({uid:p.id,session:p.session,generation:p.generation,owner,epoch});
 const seatFrom=r=>{if(!r)return 0;const k=r.seats?.findIndex(s=>s?.uid===r.uid&&!s.gone&&!s.leaving);return k>=0?[...CAS_SEAT].find(([,q])=>q.game===r.game&&q.station===(r.station||'')&&q.k===k)?.[0]||0:0;};
 const syncSeat=(p,r)=>{const seat=seatFrom(r?{...r,uid:p.id}:null);p.seat=seat;if(seat){const q=CAS_SEAT.get(seat);[p.x,p.y]=q.pos;const to=q.t?q.t.c:q.m.at;const dx=to[0]-p.x,dy=to[1]-p.y,l=Math.hypot(dx,dy)||1;p.fx=dx/l;p.fy=dy/l;p.input=[0,0];}};
 wss.on('connection',ws=>{
  sockets.add(ws);stats.connections++;let person=null,pending=false,lastMsg=performance.now(),windowAt=lastMsg,count=0;const timeout=setTimeout(()=>{if(!person)ws.close(1008,'Authenticate first')},10000);
  ws.on('error',()=>{});
  ws.on('message',async raw=>{
   stats.ingressBytes+=raw.length;
   const now=performance.now();if(now-windowAt>1000){windowAt=now;count=0}if(++count>45){stats.rejected++;ws.close(1008,'Message rate exceeded');return}
   let b;try{b=JSON.parse(raw)}catch{ws.close(1008,'Invalid message');return}if(!b||typeof b!=='object'){ws.close(1008,'Invalid message');return}
   try{
    if(!person){
     if(pending||b.type!=='hello'||b.protocol!==PROTOCOL||typeof b.token!=='string'||b.token.length>3500||typeof b.session!=='string')throw new Error('Update the game and sign in');pending=true;
     if(now-authWindow>60000){authWindow=now;authCount=0}if(++authCount>180)throw new Error('Authentication busy. Reconnect shortly');
     const u=await authenticate(b.token);if(!u||u.anon)throw new Error('Sign in with a saved account');
     const a=await D.world({action:'admit',uid:u.id,session:b.session,owner,epoch,code:String(b.code||'').slice(0,80),takeover:!!b.takeover});
     if(ws.readyState!==WebSocket.OPEN)return;
     const old=people.get(u.id);if(old){send(old.ws,{type:'revoked',error:'Casino opened in another connection'});old.ws.close(4001,'Controller replaced');}
     const name=clean(await D.name(u.id)).slice(0,12).toUpperCase(),profile=(await D.rows('profiles',{select:'cos',id:'eq.'+u.id,limit:1}))[0];
     const spawn=CAS.spawn[[...people.values()].filter(p=>p.room===a.room).length%6];
     person={ws,published:false,id:u.id,name,cos:String(profile?.cos||'').slice(0,160),cls:['soldier','sniper','grenadier'].includes(b.cls)?b.cls:'soldier',room:a.room,code:a.code,session:b.session,generation:a.generation,x:spawn[0],y:spawn[1],fx:0,fy:1,input:[0,0],queue:[],seq:0,ack:0,seat:0,heard:now,chat:[],refresh:now,token:b.token};
     const occupied=new Set([...people.values()].filter(p=>p.room===a.room&&p.id!==u.id).map(p=>p.slot));person.slot=[0,1,2,3,4,5].find(s=>!occupied.has(s));
     if(Array.isArray(a.position)&&!blocked(...a.position)){[person.x,person.y]=a.position;}
     people.set(u.id,person);clearTimeout(timeout);const h=await D.world({action:'heartbeat',...scope(person)});syncSeat(person,h.seat);
     if(ws.readyState!==WebSocket.OPEN||!ready()){ws.close(1012,'Casino reconnecting');return}
     // Reserve the slot during SQL work, then publish identity before any packed movement.
     person.published=true;
     send(ws,{type:'welcome',protocol:PROTOCOL,room:a.room,code:a.code,id:u.id,controller:{session:b.session,generation:a.generation,owner,epoch},players:[...people.values()].filter(p=>p.published&&p.room===a.room).map(row)});
     broadcast(person.room,{type:'roster',players:[...people.values()].filter(p=>p.published&&p.room===person.room).map(row)});
    }else{
     if(people.get(person.id)!==person||!ready())throw new Error('Casino connection changed');person.heard=now;
     if(b.type==='input'){
      if(!Number.isSafeInteger(b.seq)||b.seq<=person.seq||!Array.isArray(b.move)||b.move.length!==2||!b.move.every(x=>Number.isFinite(x)&&Math.abs(x)<=1)||!Array.isArray(b.face)||b.face.length!==2||!b.face.every(x=>Number.isFinite(x)&&Math.abs(x)<=1))throw new Error('Invalid movement');
      if(person.queue.length>=12)throw new Error('Movement queue exceeded');person.queue.push(b);stats.inputQueueMax=Math.max(stats.inputQueueMax,person.queue.length);person.seq=b.seq;person.lastInput=now;
     }else if(b.type==='chat'){
      const text=clean(b.text);person.chat=person.chat.filter(x=>now-x<6000);if(text&&person.chat.length<5){person.chat.push(now);broadcast(person.room,{type:'chat',id:person.id,name:person.name,text});}
     }else if(b.type==='reserve'){
      const q=CAS_SEAT.get(b.seat);if(person.reserving||now-(person.reservedAt||0)<1000||person.seat||!q||Math.hypot(person.x-q.pos[0],person.y-q.pos[1])>.75)throw new Error('Walk up to a free seat');person.reserving=true;person.reservedAt=now;
      try{const r=await D.world({action:'reserve',...scope(person),game:q.game,station:q.station,seat:q.k});send(ws,{type:'reserved',seat:b.seat,reservation:r.reservation});}finally{person.reserving=false;}
     }else if(b.type==='sync'){
      if(b.seq!==undefined&&(!Number.isSafeInteger(b.seq)||b.seq<1))throw new Error('Invalid seat sync');
      if(person.syncing||now-(person.synced||0)<1000)throw new Error('Seat sync rate exceeded');person.syncing=true;person.synced=now;person.seatSyncGeneration=(person.seatSyncGeneration||0)+1;
      try{const h=await D.world({action:'heartbeat',...scope(person)});syncSeat(person,h.seat);send(ws,{type:'seat',seat:person.seat,...(b.seq===undefined?{}:{seq:b.seq})});}finally{person.syncing=false;}
     }else if(b.type==='token'){
      if(typeof b.token!=='string'||b.token.length>3500||now-(person.tokenAt||0)<9000)throw new Error('Token refresh rate exceeded');person.tokenAt=now;
      const u=await authenticate(b.token);if(!u||u.anon||u.id!==person.id)throw new Error('Sign in again');person.token=b.token;
     }else if(b.type==='depart'){await D.world({action:'depart',...scope(person)});ws.close(1000,'Left casino');}
     else if(b.type!=='ping')throw new Error('Unknown message');
    }
   }catch(e){send(ws,{type:'error',error:e.message,request:b.type});if(!person||/revoked|expired|changed|unavailable/i.test(e.message))ws.close(4001,'Reconnect');}finally{pending=false;lastMsg=now;}
  });
  ws.on('close',()=>{clearTimeout(timeout);sockets.delete(ws);if(person&&people.get(person.id)===person){people.delete(person.id);broadcast(person.room,{type:'left',id:person.id});}});
 });
 async function renew(){if(renewing||draining)return;renewing=true;try{config=await D.world({action:'config'});if(config.revision!==1)throw new Error('Unsupported storage revision');const l=await D.world({action:'lease',name:'world',owner});if(l.standby){epoch=0;until=0;return}epoch=l.epoch;until=performance.now()+Math.max(0,Date.parse(l.until)-Number(l.now)-1500);}catch(e){epoch=0;until=0;log(JSON.stringify({event:'world_unavailable',error:e.message}));}finally{renewing=false;}}
 async function heartbeat(){if(heartbeating||draining)return;heartbeating=true;
  // Refresh a fixed roster in bounded parallel lanes so a 60-player pass fits its leases.
  const pending=[...people.values()].filter(p=>p.published);let cursor=0;
  const lane=async()=>{while(cursor<pending.length){const p=pending[cursor++];if(people.get(p.id)!==p)continue;
  if(performance.now()-p.heard>25000){p.ws.close(4000,'Connection timed out');continue}if(p.checking)continue;p.checking=true;
  const seatGeneration=p.seatSyncGeneration||0;
  try{const u=await authenticate(p.token);if(!u||u.anon||u.id!==p.id)throw new Error('Sign in again');const r=await D.world({action:'heartbeat',...scope(p),x:p.x,y:p.y});if(seatGeneration===(p.seatSyncGeneration||0))syncSeat(p,r.seat);}catch(e){stats.heartbeatFailures++;log(JSON.stringify({event:'controller_check_failed',error:e.message}));send(p.ws,{type:'revoked',error:e.message});p.ws.close(4001,'Controller revoked');}finally{p.checking=false;}
  }};try{await Promise.all(Array.from({length:Math.min(4,pending.length)},lane));}finally{heartbeating=false;}
 }
 function tick(){const now=performance.now();acc+=Math.min((now-last)/1000,.2);last=now;if(!ready()){for(const ws of sockets)ws.close(1012,'Casino reconnecting');acc=0;return}if(!people.size){acc=0;return}
  let n=0;while(acc>=1/30&&n++<6){acc-=1/30;step++;stats.ticks++;for(const p of people.values()){if(!p.published)continue;const b=p.queue.shift();if(b){p.ack=b.seq;const l=Math.hypot(...b.face);if(l>.01){p.fx=b.face[0]/l;p.fy=b.face[1]/l;}if(!p.seat)move(p,...b.move,1/30);}}
   if(step%2===0){const rooms=new Set([...people.values()].filter(p=>p.published).map(p=>p.room));for(const room of rooms){broadcast(room,{type:'snapshot',tick:step,packed:true,players:[...people.values()].filter(p=>p.published&&p.room===room).map(packed)});stats.snapshots++;}}
  }
  const ms=performance.now()-now;stats.tickMaxMs=Math.max(stats.tickMaxMs,ms);metrics.tick(ms);
 }
 let intervals=[];
 return {server,wss,people,worker,stats,health,renew,heartbeat,tick,
  async start(port=Number(process.env.PORT)||10000,host='0.0.0.0'){await renew();await new Promise(resolve=>server.listen(port,host,resolve));intervals=[setInterval(renew,4000),setInterval(heartbeat,10000),setInterval(tick,1000/60),setInterval(()=>worker.cycle(),1000),setInterval(()=>metrics.sample(),1000)];return server.address();},
  async stop(){draining=true;intervals.forEach(clearInterval);for(const ws of sockets){send(ws,{type:'reconnect',error:'Casino updating. Reconnecting…'});ws.close(1012,'Service updating');}const force=setTimeout(()=>{for(const ws of sockets)ws.terminate()},2000);force.unref();await worker.stop();if(epoch)await D.world({action:'release',name:'world',owner,epoch}).catch(()=>{});await new Promise(resolve=>wss.close(resolve));clearTimeout(force);await new Promise(resolve=>server.close(resolve));}
 };
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
 const D=restStorage(process.env.SUPABASE_URL,process.env.SUPABASE_SERVICE_ROLE_KEY);
 const origins=(process.env.ALLOWED_ORIGINS||'https://lopoke89-ops.github.io').split(',').map(s=>s.trim());
 const service=createCasinoService(D,{origins});await service.start();console.log(JSON.stringify({event:'listening',port:service.server.address().port}));
 let stopping=false;for(const sig of ['SIGTERM','SIGINT'])process.on(sig,async()=>{if(stopping)return;stopping=true;const to=setTimeout(()=>process.exit(1),25000);to.unref();await service.stop();process.exit(0);});
}
