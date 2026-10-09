// Player-owned casino lobbies. This process routes messages; it runs no game or ledger.
import http from 'node:http';
import {randomInt, randomUUID} from 'node:crypto';
import {pathToFileURL} from 'node:url';
import {WebSocketServer, WebSocket} from 'ws';

export const WIRE='casino-relay-1', GAME='yard-29', CODE=/^R[A-Z2-9]{5}$/, RECONNECT_MS=120000;
const uidPattern=/^[0-9a-f-]{36}$/i, sessionPattern=/^[0-9a-f]{24}$/, uuidPattern=/^[0-9a-f-]{36}$/i;
const hostTypes=new Set(['welcome','lobby','start','ping','s','x','t','kick','c','relayResume']);
const guestTypes=new Set(['hello','loadout','ping','c','i','ready']);
const fail=message=>{throw new Error(message)};

export function supabaseIdentity(url,key){
 const read=async(path,token)=>{
  const r=await fetch(url+path,{headers:{apikey:key,Authorization:'Bearer '+token},signal:AbortSignal.timeout(8000)});
  if(!r.ok)fail('Account verification is unavailable.');return r.json();
 };
 return {
  async verify(token){
   if(typeof token!=='string'||token.length>8192)fail('Sign in to a saved account.');
   const u=await read('/auth/v1/user',token);
   if(!uidPattern.test(u.id)||u.is_anonymous)fail('Sign in to a saved account.');
   const rows=await read('/rest/v1/profiles?select=id,username,banned&id=eq.'+u.id,token),p=rows[0];
   if(!p||p.banned)fail('This account cannot enter the casino.');
   let exp;try{exp=JSON.parse(Buffer.from(token.split('.')[1],'base64url')).exp}catch{}
   if(!Number.isFinite(exp)||exp*1000<=Date.now())fail('Sign in again.');
   return {uid:u.id,name:String(p.username||'Player').slice(0,12),expires:exp*1000};
  }
 };
}

export function createRelay({identity,origins=[],maxRooms=10,graceMs=RECONNECT_MS,log=()=>{}}){
 if(!identity?.verify)throw new Error('Verified identity provider required');
 const rooms=new Map(),people=new Map(),epoch=randomUUID(),allowed=new Set(origins);
 let closing=false,joins=0,forwarded=0,coalesced=0;
 const event=(name,p,extra={})=>log({at:new Date().toISOString(),event:name,epoch,...(p?{roomId:p.room.incarnation,peerId:p.id,role:p.role}:{}),...extra});
 const json=(res,status,body,origin)=>{res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store',...(allowed.has(origin)?{'Access-Control-Allow-Origin':origin,Vary:'Origin'}:{})});res.end(JSON.stringify(body))};
 const server=http.createServer((req,res)=>{
  const path=new URL(req.url,'http://relay').pathname;
  if(path==='/healthz'||path==='/readyz')return json(res,closing?503:200,{ready:!closing,kind:'player-hosted-relay',wire:WIRE,build:process.env.RENDER_GIT_COMMIT||'local',epoch,rooms:rooms.size,players:people.size,joins,forwarded,coalesced},req.headers.origin);
  // Open Games uses the existing Supabase directory, which honors each host's listing choice.
  json(res,404,{error:'Not found'},req.headers.origin);
 });
 const wss=new WebSocketServer({noServer:true,maxPayload:65536,perMessageDeflate:false});
 const send=(person,body,volatile=false)=>{
  const ws=person?.ws;if(ws?.readyState!==WebSocket.OPEN)return false;
  if(ws.bufferedAmount>65536){ws.close(4002,'Connection too slow');return false}
  if(volatile&&ws.bufferedAmount>16384){coalesced++;return false}
  ws.send(JSON.stringify(body));return true;
 };
 const notice=(r,b)=>{for(const p of r.members.values())send(p,b)};
 const remove=(p,reason='disconnect_timeout')=>{
  if(!people.has(p.id))return;clearTimeout(p.timer);people.delete(p.id);p.room.members.delete(p.id);
  event('member_removed',p,{reason});
  if(p.role==='host'){
   event('room_closed',p,{reason});
   const message=reason==='session_expired'?"The host's sign-in expired. Sign in and open a new casino.":reason==='disconnect_timeout'?'The host could not reconnect in time. Open or join a new casino.':'The host closed this casino.';
   rooms.delete(p.room.code);for(const g of [...p.room.members.values()]){send(g,{type:'closed',message});remove(g,'host_'+reason);g.ws?.close(1000,'Host left')}
  }else send(p.room.host,{type:'left',peer:p.id});
 };
 const welcome=p=>send(p,{type:'welcome',wire:WIRE,epoch,id:p.id,resume:p.resume,role:p.role,code:p.room.code,incarnation:p.room.incarnation,graceMs});
 const code=()=>{const chars='ABCDEFGHJKMNPQRSTUVWXYZ23456789';let s='R';for(let i=0;i<5;i++)s+=chars[randomInt(chars.length)];return s};
 server.on('upgrade',(req,socket,head)=>{
  if(closing||new URL(req.url,'http://relay').pathname!=='/relay'||!allowed.has(req.headers.origin)||wss.clients.size>=maxRooms*6+8){socket.write('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n');socket.destroy();return}
  wss.handleUpgrade(req,socket,head,ws=>wss.emit('connection',ws));
 });
 wss.on('connection',ws=>{
  let p=null,busy=false,started=Date.now(),count=0,bytes=0;ws.alive=true;
  const authDeadline=setTimeout(()=>ws.close(4001,'Sign in timed out'),20000);
  ws.on('pong',()=>ws.alive=true);
  ws.on('error',()=>{});
  ws.on('message',async(raw,binary)=>{
   if(binary)return ws.close(4001,'JSON required');
   if(Date.now()-started>1000){started=Date.now();count=0;bytes=0}count++;bytes+=raw.length;
   if(count>(p?.role==='host'?240:90)||bytes>(p?.role==='host'?524288:32768))return ws.close(4001,'Too many messages');
   let b;try{b=JSON.parse(raw)}catch{return ws.close(4001,'Bad message')}
   if(!b||typeof b!=='object'||Array.isArray(b))return;
   let ownsVerification=false;
   try{
    if(!p){
     if(busy)return;if(b.type!=='hello'||b.wire!==WIRE||b.game!==GAME||!sessionPattern.test(b.session)||!['host','guest'].includes(b.role))fail('Reload before joining this casino.');
     busy=true;ownsVerification=true;const who=await identity.verify(b.token);
     if(ws.readyState!==WebSocket.OPEN)return;
     const existing=b.resume&&[...people.values()].find(x=>x.resume===b.resume);
     if(existing){
      if(existing.uid!==who.uid||existing.session!==b.session||existing.role!==b.role)fail('Cannot resume this connection.');
      p=existing;clearTimeout(p.timer);const old=p.ws;p.ws=ws;if(old&&old!==ws)old.close(4004,'Connection replaced');p.expires=who.expires;welcome(p);
      event('connection_resumed',p);
      if(p.role==='guest')send(p.room.host,{type:'peer',peer:p.id,resumed:true});else{notice(p.room,{type:'hostBack'});for(const g of p.room.members.values())if(g!==p&&g.ws)send(p,{type:'peer',peer:g.id,resumed:true})}
     }else{
      if(b.resume)fail('The relay restarted. Open or join a new casino lobby.');
      let r=rooms.get(b.code);
      if(b.role==='host'){
       if(rooms.size>=maxRooms)fail('All casino lobbies are in use. Try again later.');
       if(b.code)fail('That lobby has closed. Open a new casino.');
       if(!uuidPattern.test(b.incarnation))fail('Bad lobby identity');
       let next=b.code;while(!next||rooms.has(next))next=code();
       r={code:next,incarnation:b.incarnation,locked:false,banned:new Set(),members:new Map()};rooms.set(next,r);
      }else{
       if(!CODE.test(b.code)||!r){send({ws},{type:'error',message:'Waiting for the casino host…',retry:true});return ws.close(4003,'Host not connected')}
       if(!r.host.ws){send({ws},{type:'error',message:'Reconnecting to the casino host…',retry:true});return ws.close(4003,'Host reconnecting')}
       if(r.locked)fail('This casino is locked.');if(r.members.size>=6)fail('This casino is full (6 players).');
       if(r.banned.has(who.uid))fail('The host removed you from this casino.');
       if(b.incarnation&&b.incarnation!==r.incarnation)fail('This invitation belongs to an earlier casino.');
      }
      if([...r.members.values()].some(x=>x.uid===who.uid))fail('This account is already in the casino.');
      p={id:randomUUID(),resume:randomUUID(),session:b.session,role:b.role,uid:who.uid,name:who.name,expires:who.expires,room:r,ws,timer:null};
      people.set(p.id,p);r.members.set(p.id,p);if(p.role==='host')r.host=p;joins++;welcome(p);
      event('connection_joined',p);
      if(p.role==='guest')send(r.host,{type:'peer',peer:p.id,resumed:false});
     }
     clearTimeout(authDeadline);return;
    }
    if(p.ws!==ws)return;
    if(p.expires<=Date.now())fail('Sign in again.');
    if(b.type==='token'){
     if(busy)return;busy=true;ownsVerification=true;const who=await identity.verify(b.token);if(p.ws!==ws||ws.readyState!==WebSocket.OPEN)return;if(who.uid!==p.uid)fail('Account changed.');p.expires=who.expires;send(p,{type:'token',expires:p.expires});event('token_updated',p);return;
    }
    if(b.type==='depart'){remove(p,'departed');return ws.close(1000,'Left casino')}
    if(b.type==='ping'){send(p,{type:'pong'});return}
    if(p.role==='host'&&b.type==='room'){p.room.locked=!!b.locked;return}
    if(p.role==='host'&&b.type==='remove'){
     const g=p.room.members.get(b.peer);if(g&&g!==p){if(b.ban)p.room.banned.add(g.uid);remove(g,'host_removed');g.ws?.close(4004,'Host removed player')}return;
    }
    if(b.type!=='packet'||!b.data||typeof b.data!=='object'||Array.isArray(b.data))return;
    const d=b.data;
    if(p.role==='host'){
     if(!hostTypes.has(d.t))return;const g=p.room.members.get(b.to);if(!g||g===p)return;
     if(d.t==='start'&&(d.mode!=='casino'||d.map!=='casino'||d.room!=='R:'+p.room.code+':'+p.room.incarnation))fail('Casino relay cannot start another game.');
     send(g,{type:'packet',data:d},d.t==='s');forwarded++;
    }else{
     if(!guestTypes.has(d.t))return;
     const safe=d.t==='hello'?{...d,uid:p.uid,name:p.name,session:p.session,v:GAME}:d;
     send(p.room.host,{type:'packet',from:p.id,data:safe},d.t==='i');forwarded++;
    }
   }catch(e){event('request_refused',p,{reason:e.message==='Sign in again.'?'session_expired':'verification_or_protocol'});send({ws},{type:'error',message:e.message});ws.close(4001,'Request refused')}
   finally{if(ownsVerification)busy=false}
  });
  ws.on('close',code=>{
   clearTimeout(authDeadline);if(!p||p.ws!==ws||!people.has(p.id))return;p.ws=null;
   event('connection_closed',p,{closeCode:code,graceMs});
   if(p.role==='host')notice(p.room,{type:'hostAway',message:'Reconnecting to the casino host…'});
   p.timer=setTimeout(()=>remove(p,'disconnect_timeout'),graceMs);
  });
 });
 const heartbeat=setInterval(()=>{
  for(const ws of wss.clients){if(!ws.alive){const p=[...people.values()].find(p=>p.ws===ws);event('heartbeat_timeout',p);ws.terminate();continue}ws.alive=false;ws.ping()}
  // Disconnected peers have no access. Preserve their bounded resume window so a
  // newly verified token can resume after the old token expired during an outage.
  for(const p of people.values())if(p.ws&&p.expires<=Date.now()){send(p,{type:'error',message:'Sign in again.'});remove(p,'session_expired');p.ws?.close(4001,'Session expired')}
 },10000);heartbeat.unref();
 return {rooms,people,server,wss,
  start:(port=0,host='127.0.0.1')=>new Promise(resolve=>server.listen(port,host,()=>resolve(server.address().port))),
  async stop(){closing=true;event('relay_stopping',null,{rooms:rooms.size,players:people.size});clearInterval(heartbeat);for(const r of rooms.values())event('room_closed',r.host,{reason:'relay_restart'});for(const p of people.values()){clearTimeout(p.timer);send(p,{type:'closed',message:'The casino connection server restarted. Open or join a new casino lobby.'})}for(const ws of wss.clients)ws.close(1012,'Relay restarting');await new Promise(resolve=>server.close(resolve));wss.close();people.clear();rooms.clear();event('relay_stopped');}
 };
}

if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
 const {SUPABASE_URL,SUPABASE_PUBLISHABLE_KEY,ALLOWED_ORIGINS}=process.env;
 if(!SUPABASE_URL||!SUPABASE_PUBLISHABLE_KEY||!ALLOWED_ORIGINS)throw new Error('Set public Auth configuration and exact allowed origins. No service-role key is needed.');
 const relay=createRelay({identity:supabaseIdentity(SUPABASE_URL,SUPABASE_PUBLISHABLE_KEY),origins:ALLOWED_ORIGINS.split(',').map(s=>s.trim()),maxRooms:Number(process.env.MAX_ROOMS)||10,log:e=>console.log(JSON.stringify(e))});
 await relay.start(Number(process.env.PORT)||10000,'0.0.0.0');console.log(JSON.stringify({event:'relay-listening',wire:WIRE}));
 process.on('SIGTERM',()=>relay.stop().then(()=>process.exit(0)));process.on('SIGINT',()=>relay.stop().then(()=>process.exit(0)));
}
