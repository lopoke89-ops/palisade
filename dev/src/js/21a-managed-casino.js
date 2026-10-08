// Persistent casino transport. Combat keeps its existing NET host/guest adapter.
const MC={session:crypto.randomUUID(),ws:null,room:'',controller:null,seq:0,pending:[],input:[0,0],acc:0,connected:false,active:false,attempt:0,timer:0,code:'',seatPending:0,remote:new Map(),owner:''};
const mcEnabled=()=>!!globalThis.PALISADE_CASINO?.enabled;
const mcActive=()=>NET.mode==='casino';
const mcSend=b=>{if(MC.ws?.readyState===WebSocket.OPEN&&MC.ws.bufferedAmount<16384)MC.ws.send(JSON.stringify(b));};
function mcStatus(t){tbMsg(t);if(casino()&&player)toast('CASINO',t);}
function mcDisconnect(intent=true){MC.active=false;MC.connected=false;clearTimeout(MC.timer);MC.timer=0;if(intent)mcSend({type:'depart'});const ws=MC.ws;MC.ws=null;ws?.close(1000,'Left casino');MC.pending=[];MC.remote.clear();MC.room='';MC.controller=null;}
async function mcRevoke(){if(MC.controller&&acct.s)await sbFetch('/functions/v1/tables',{method:'POST',body:{op:'revoke',controller:MC.controller},timeout:5000});mcDisconnect();}
async function mcEnter(code='',takeover=false){
 const no=tbCanPlay();if(no){tbMsg(no);return}const url=globalThis.PALISADE_CASINO?.url;
 if(!mcEnabled()||!url){tbMsg('The persistent casino is awaiting its server deployment.');mStatus('The persistent casino is awaiting its server deployment.');return}
 await tbLobby();if(TB.mine&&!String(TB.mine.room||'').startsWith('C:')){tbMsg('Stand up at your previous table before entering the persistent casino.');return}
 if(!await freshToken())return;if(MC.owner&&MC.owner!==myUid())mcDisconnect();
 if(!MC.active){netReset();NET.mode='casino';MC.active=true;MC.owner=myUid();MC.attempt=0;}
 MC.code=String(code||'').trim().toUpperCase();MC.connected=false;tbMsg(MC.attempt?'Reconnecting to the casino…':'Opening the casino…');
 const ws=new WebSocket(url.replace(/^http/,'ws')+'/casino');MC.ws=ws;
 const timeout=setTimeout(()=>{if(MC.ws===ws&&!MC.connected)ws.close()},70000);
 ws.onopen=()=>{if(MC.ws!==ws)return;mcSend({type:'hello',protocol:'casino-1',token:acct.s.access_token,session:MC.session,code:MC.code,cls:pick.cls,takeover});};
 ws.onmessage=async e=>{if(MC.ws!==ws||MC.owner!==myUid())return;let b;try{b=JSON.parse(e.data)}catch{return}
  if(b.type==='welcome'){
   clearTimeout(timeout);MC.connected=true;MC.attempt=0;MC.room=b.room;MC.code=b.code;MC.controller=b.controller;MC.seq=0;MC.pending=[];MC.remote.clear();
   NET.mode='casino';NET.inGame=true;NET.code=b.code;NET.casRoom=b.room;myId=b.id;NET.roster=b.players;pick.mode='casino';pick.pvp='coop';
   if(!casino()||!players.has(myId)){demo=false;pick.oct=isOctober();newGame(b.players,'',{gid:b.room});game.casRoom=b.room;enterGame();}mcSnapshot(b.players,true);tbMsg('');
   await mcResolveJournal();await tbLobby();if(TB.mine?.room===b.room&&!TB.mine.pending){TB.id=TB.mine.id;await tbSend({op:'state',id:TB.id},true);}
  }else if(b.type==='roster')mcSnapshot(b.players,true);
  else if(b.type==='snapshot')mcSnapshot(b.packed?b.players.map(r=>({id:MC.slots?.get(r[0]),x:r[1]/1000,y:r[2]/1000,fx:r[3]/1000,fy:r[4]/1000,seat:r[5],seq:r[6]})):b.players);
  else if(b.type==='chat')addChat(b.id,b.name,b.text,'');
  else if(b.type==='left'){players.delete(b.id);MC.remote.delete(b.id);NET.roster=NET.roster.filter(p=>p.id!==b.id);}
  else if(b.type==='reserved'){
   const q=casSeatOf(b.seat);if(q&&MC.seatPending===b.seat){MC.reservation=b.reservation;await tbSitAt(q.game,q.k,q.station);MC.reservation='';MC.seatPending=0;}
  }else if(b.type==='revoked'){
   MC.active=false;MC.connected=false;mcStatus(b.error||'Casino active in another tab. Use TAKE OVER to continue here.');
  }else if(b.type==='error'){
   MC.seatPending=0;mcStatus(b.error||'Could not connect');if(/another tab|revoked|saved account|sign in|Update|staging is limited|room is full/.test(b.error||'')){MC.active=false;MC.connected=false;}
  }else if(b.type==='reconnect')mcStatus(b.error);
 };
 ws.onerror=()=>{};
 ws.onclose=()=>{clearTimeout(timeout);if(MC.ws!==ws)return;MC.connected=false;MC.seatPending=0;MC.pending=[];
  if(MC.active&&MC.owner===myUid()){const wait=Math.min(15000,1000*2**Math.min(4,MC.attempt++))*(.8+Math.random()*.4);tbMsg('Casino connection interrupted. Reconnecting…');MC.timer=setTimeout(()=>mcEnter(MC.code),wait);}
 };
}
function mcSnapshot(rows,initial=false){
 if(initial){MC.slots=new Map((rows||[]).map(r=>[r.slot,r.id]));}
 const ids=new Set();for(const r of rows||[]){if(typeof r.id!=='string'||!r.id)continue;ids.add(r.id);let p=players.get(r.id);if(!p){if(!initial||typeof r.name!=='string')continue;p=makePlayer(r.id,r.name,r.cls,players.size,r.cos,'');players.set(r.id,p);}
  if(r.id===myId){const oldX=p.x,oldY=p.y;MC.pending=MC.pending.filter(x=>x.seq>r.seq);p.x=r.x;p.y=r.y;p.seat=r.seat||0;if(p.seat)setTip('');
   if(!p.seat)for(const x of MC.pending)CasinoFloor.move(p,...x.move,1/30);
   if(!initial&&!p.seat&&Math.hypot(p.x-oldX,p.y-oldY)<.6){MC.correction={x:oldX-p.x,y:oldY-p.y};}
 }else{MC.remote.set(r.id,{from:[p.x,p.y],to:[r.x,r.y],at:performance.now()});p.seat=r.seat||0;p.face=p.aim={x:r.fx,y:r.fy};if(initial||p.seat){p.x=r.x;p.y=r.y;}}
 }
 for(const id of players.keys())if(!ids.has(id)&&id!==myId){players.delete(id);MC.remote.delete(id);}if(initial)NET.roster=(rows||[]).map(r=>({...r}));
}
function mcTick(dt){if(!mcActive())return;if(MC.connected&&player){MC.acc+=dt;let n=0;while(MC.acc>=1/30&&n++<6){MC.acc-=1/30;
  const move=player.seat||document.hidden?[0,0]:MC.input,b={type:'input',seq:++MC.seq,move,face:[player.face.x,player.face.y]};
  if(MC.pending.length<120){mcSend(b);MC.pending.push(b);if(!player.seat)CasinoFloor.move(player,...move,1/30);if(Math.hypot(...move)>.12)player.walk+=1/3;}
 }
 }
 for(const [id,r]of MC.remote){const p=players.get(id);if(!p||p.seat)continue;const t=Math.min(1,(performance.now()-r.at)/100);p.x=r.from[0]+(r.to[0]-r.from[0])*t;p.y=r.from[1]+(r.to[1]-r.from[1])*t;p.walk+=dt*Math.min(1,Math.hypot(r.to[0]-r.from[0],r.to[1]-r.from[1])*15)*10;}
}
// One unresolved economic request per account/project. Persist before the first send and never replace an uncertain id.
const mcJournalKey=()=> 'palisade.casino.ops.v1:'+SB_URL+':'+myUid();
function mcJournal(){try{const x=JSON.parse(localStorage.getItem(mcJournalKey())||'null');return x&&x.owner===myUid()?x:null}catch{return null}}
function mcPrepare(body){MC.journalError='';const old=mcJournal();if(old){MC.journalError='An earlier casino request is awaiting confirmation. Use RECOVER TABLE before playing again.';return body.opId===old.body.opId?old.body:null;}
 const b={...body,opId:body.opId||tbOpId(),...(body.op!=='sit'&&TB.v?.expected?{expected:{...TB.v.expected}}:{})};
 try{localStorage.setItem(mcJournalKey(),JSON.stringify({owner:myUid(),body:b}));}catch{MC.journalError='Your browser could not save this casino request. Enable local storage before playing.';return null}return b;
}
function mcClearJournal(id){try{if(mcJournal()?.body.opId===id)localStorage.removeItem(mcJournalKey())}catch{}}
async function mcResolveJournal(){const x=mcJournal();if(x)await tbSend(x.body,true);}
async function mcRecover(takeover=false){if(!await freshToken())return;const r=await tbCall({op:'recover',session:MC.session,takeover});
 if(r.error){tbMsg(r.error);return}MC.active=false;MC.connected=false;MC.ws?.close();MC.controller={session:MC.session,generation:r.generation};await mcResolveJournal();if(TB.mine){TB.id=TB.mine.id;await tbSend({op:'state',id:TB.id},true);}}
setInterval(async()=>{if(!mcActive())return;if(MC.connected){mcSend({type:'ping'});if(await freshToken())mcSend({type:'token',token:acct.s.access_token});}},10000);
window.addEventListener('pagehide',()=>{if(mcActive())mcDisconnect();});
