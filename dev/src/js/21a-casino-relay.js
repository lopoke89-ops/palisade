// Casino lobbies keep their player host. WSS carries their existing floor packets.
const RLY={active:false,connected:false,role:'',owner:'',ws:null,code:'',incarnation:'',resume:'',epoch:'',peer:'',timer:0,heartbeat:0,attempt:0,deadline:0,error:'',refreshing:false};
const rlyEnabled=()=>!!globalThis.PALISADE_RELAY?.enabled;
const rlyCode=code=>/^R[A-Z2-9]{5}$/.test(code);
const rlyActive=()=>RLY.active;
function rlyStatus(message){mStatus(message);tbMsg(message);if(casino()&&player)toast('CONNECTION',message);}
function rlySend(body,volatile=false){const ws=RLY.ws;if(ws?.readyState!==WebSocket.OPEN)return;
 if(ws.bufferedAmount>65536){ws.close(4002,'Connection too slow');return}if(volatile&&ws.bufferedAmount>16384)return;ws.send(JSON.stringify(body));}
function rlyDisconnect(){
 RLY.active=false;clearTimeout(RLY.timer);clearInterval(RLY.heartbeat);rlySend({type:'depart'});const ws=RLY.ws;RLY.ws=null;ws?.close(1000,'Left casino');
 Object.assign(RLY,{connected:false,role:'',owner:'',code:'',resume:'',epoch:'',peer:'',error:'',refreshing:false});
}
function rlyChannel(peer,ch='r'){
 return {peer,label:ch,get open(){return RLY.connected},send(data){rlySend({type:'packet',to:peer,data},ch==='u')},close(){rlySend({type:'remove',peer})}};
}
function rlyHello(){NET.toHost({t:'hello',name:myName(),cls:pick.cls,cos:cosStr(myCos()),v:PROTO,sk:mySkills(),uid:myUid(),session:ROOM_SESSION,invitationSession:RLY.incarnation});}
function rlyHostPeer(id,resumed){
 let c=NET.conns.get(id);
 if(!c){c={r:rlyChannel(id),u:rlyChannel(id,'u'),pid:null,heard:performance.now()};NET.conns.set(id,c)}
 c.heard=performance.now();
 if(resumed&&c.pid){
  c.r.send({t:'relayResume',id:c.pid});
  if(NET.inGame){c.r.send({t:'x',n:NET.snapN,pi:[...players.values()].map(p=>packRow(PL_INFO,p))});c.r.send(makeSnap(true))}
  else broadcastLobby();
 }
}
async function rlyEnter(role,code='',incarnation=''){
 if(inRun()&&$('menu').hidden)return;const no=tbCanPlay();if(no){rlyStatus(no);return}
 if(!rlyEnabled()||!globalThis.PALISADE_RELAY.url){rlyStatus('Casino connections are being updated. Try again shortly.');return}
 if(RLY.active||NET.mode!=='solo')return;
 if(!await freshToken())return;netReset();
 Object.assign(RLY,{active:true,connected:false,role,owner:myUid(),code,incarnation:incarnation||(role==='host'?crypto.randomUUID():''),resume:'',epoch:'',attempt:0,deadline:performance.now()+120000,error:''});
 NET.mode=role==='host'?'opening':'joining';pick.mode='casino';pick.pvp='coop';rlyConnect();
}
async function rlyConnect(){
 if(!RLY.active||RLY.owner!==myUid())return;
 if(performance.now()>RLY.deadline)return rlyFail(RLY.error||'Could not reconnect. Open or join the casino again.');
 if(!await freshToken()){rlyFail('Sign in again before joining the casino.');return}
 rlyStatus(RLY.attempt?'Reconnecting to the casino…':'Connecting to the casino… First connection can take about a minute.');
 const ws=new WebSocket(globalThis.PALISADE_RELAY.url.replace(/^http/,'ws')+'/relay');RLY.ws=ws;RLY.connected=false;
 const timeout=setTimeout(()=>{if(RLY.ws===ws&&!RLY.connected)ws.close()},70000);
 ws.onopen=()=>{if(RLY.ws!==ws)return;rlySend({type:'hello',wire:'casino-relay-1',game:PROTO,role:RLY.role,token:acct.s.access_token,session:ROOM_SESSION,code:RLY.code,incarnation:RLY.incarnation,resume:RLY.resume});};
 ws.onmessage=e=>{
  if(RLY.ws!==ws||RLY.owner!==myUid())return;let b;try{b=JSON.parse(e.data)}catch{return}
  if(b.type==='welcome'){
   clearTimeout(timeout);const first=!RLY.resume,reset=!!RLY.epoch&&RLY.epoch!==b.epoch;
   Object.assign(RLY,{connected:true,attempt:0,code:b.code,incarnation:b.incarnation,resume:b.resume,epoch:b.epoch,peer:b.id,error:'',deadline:performance.now()+120000});
   NET.code=b.code;NET.incarnation=b.incarnation;NET.transport='relay';NET.lastHeard=performance.now();rlyStatus('');
   if(RLY.role==='host'){
    NET.mode='host';
    if(reset){for(const [id,c]of NET.conns){if(c.pid&&players.has(c.pid))stashLeaver(c,players.get(c.pid));if(c.pid)players.delete(c.pid)}NET.conns.clear();NET.roster=NET.roster.filter(p=>p.id==='host');}
    if(first){myId='host';NET.roster=[{id:'host',name:myName(),cls:pick.cls,cos:cosStr(myCos()),team:'a',sk:mySkills()}];NET.roomLocked=false;lobbyStartPublishing();NET.autoCasino=false;startOnline();}
    else broadcastLobby();
   }else{NET.host={r:rlyChannel('host'),u:rlyChannel('host','u')};if(first||reset)rlyHello();else rlySend({type:'ping'});}
   clearInterval(RLY.heartbeat);RLY.heartbeat=setInterval(rlyHeartbeat,5000);return;
  }
  if(b.type==='packet'){
   if(RLY.role==='host')hostData(b.from,b.data);
   else if(b.data?.t==='relayResume'){NET.lastHeard=performance.now();if(myId!==b.data.id)rlyFail('The casino session changed. Join again.');}
   else guestData(b.data);return;
  }
  if(b.type==='peer'&&RLY.role==='host'){rlyHostPeer(b.peer,b.resumed);return}
  if(b.type==='left'&&RLY.role==='host'){hostDrop(b.peer);return}
  if(b.type==='hostAway'){rlyStatus(b.message);return}
  if(b.type==='hostBack'){rlyStatus('');return}
  if(b.type==='closed'){rlyFail(b.message);return}
  if(b.type==='error'){RLY.error=b.message;if(!b.retry)rlyFail(b.message);}
 };
 ws.onerror=()=>{};
 ws.onclose=e=>{
  clearTimeout(timeout);if(RLY.ws!==ws||!RLY.active)return;if(RLY.connected)RLY.deadline=performance.now()+120000;RLY.connected=false;clearInterval(RLY.heartbeat);
  if(e.code===4004)return rlyFail('This connection was replaced or removed by the host.');
  if(performance.now()>RLY.deadline)return rlyFail(RLY.error||'The casino connection timed out. Try again.');
  rlyStatus('Reconnecting to the casino…');clearTimeout(RLY.timer);RLY.timer=setTimeout(rlyConnect,Math.min(5000,500*2**Math.min(4,RLY.attempt++))+Math.random()*250);
 };
}
async function rlyHeartbeat(){
 if(!RLY.active||RLY.owner!==myUid()){if(RLY.active)netLeave('Account changed. Join the casino again.');return}
 rlySend({type:'ping'});
 if(!RLY.refreshing&&acct.s?.expires_at*1000<Date.now()+90000){RLY.refreshing=true;try{if(await freshToken())rlySend({type:'token',token:acct.s.access_token});else rlyFail('Sign in again.')}finally{RLY.refreshing=false}}
}
function rlyFail(message){NET.autoCasino=false;netLeave(message);tbMsg(message);}

