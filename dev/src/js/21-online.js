/* ================= online co-op ================= */
// One phone hosts and runs the real game. Others join with a 4-character room code.
// A free public matchmaking service (PeerJS) only introduces the phones; after that
// they talk directly. Each guest opens 'r' (reliable: hello, build, grenade, and every
// one-off event: sounds, particles, bullets, toasts, wall changes), 'u' (fast: movement in),
// and 'st' (never resent: game state out, 15 times a second).
const PROTO='yard-25',ROOM_PREFIX='palisade-yard-25-';   // v0.9.6.5: boss health +25%, weaknesses and new boss moves (states 20-30)
const ROOM_SESSION=(()=>{let id='';try{id=sessionStorage.getItem('palisade.roomSession')||''}catch(e){}
  if(!/^[0-9a-f]{24}$/.test(id)){id=Array.from(crypto.getRandomValues(new Uint8Array(12)),b=>b.toString(16).padStart(2,'0')).join('');try{sessionStorage.setItem('palisade.roomSession',id)}catch(e){}}
  return id})();
const NET={mode:'solo',inGame:false,peer:null,code:'',roster:[],conns:new Map(),host:null,fxq:[],snapT:0,snapN:0,lastN:0,inT:0,nextG:1,lastHeard:0,roomLocked:false,banned:new Set(),leftBy:new Map(),
  sendTo(id,msg){for(const c of this.conns.values())if(c.pid===id&&c.r&&c.r.open){try{c.r.send(msg)}catch(e){}}},
  sendAll(msg,ch='r'){for(const c of this.conns.values()){const x=c[ch]&&c[ch].open?c[ch]:c.r;if(c.pid&&x&&x.open)try{x.send(msg)}catch(e){}}},
  sendState(msg){let js=null;for(const c of this.conns.values()){if(!c.pid)continue;
    if(c.st&&c.st.readyState==='open'){try{c.st.send(js||(js=JSON.stringify(msg)));continue}catch(e){}}
    const x=c.u&&c.u.open?c.u:c.r;if(x&&x.open)try{x.send(msg)}catch(e){}}},
  toHost(msg,ch='r'){const x=this.host&&(this.host[ch]&&this.host[ch].open?this.host[ch]:this.host.r);if(x&&x.open)try{x.send(msg)}catch(e){}}
};
const onlineOK=()=>typeof Peer!=='undefined';
const HOST_LIMITS={name:12,chat:120,cos:160,skills:160,targetPad:100,moveBurst:2};
const hostFinite=(v,min,max)=>Number.isFinite(v)&&v>=min&&v<=max;
const hostInt=(v,min,max)=>Number.isInteger(v)&&v>=min&&v<=max;
const hostText=(v,max)=>typeof v==='string'&&v.length<=max;
// the website fetches PeerJS in the background once the menu is up, so it never holds up the first screen
const canOnline=()=>onlineOK()||!!window.PEER_SRC;
let peerLoad=null;
function needPeer(){
  if(onlineOK())return Promise.resolve(true);
  if(!window.PEER_SRC)return Promise.resolve(false);
  return peerLoad||(peerLoad=new Promise(res=>{const sc=document.createElement('script');sc.src=window.PEER_SRC;sc.async=true;
    sc.onload=()=>res(onlineOK());sc.onerror=()=>{peerLoad=null;sc.remove();res(false)};document.head.append(sc)}));
}
const PEER_FAIL="Couldn't load online play. Check your signal and try again.";
// Relay for networks that block direct links (many cellular networks). The TURN logins are short-lived and
// come from our Cloudflare Worker, which holds the real key; nothing secret is in this file.
const TURN_URL='https://palisade-turn.lopoke89.workers.dev/';
const STUN=[{urls:'stun:stun.l.google.com:19302'},{urls:'stun:stun1.l.google.com:19302'}];
let iceCache=null;
async function getIce(){
  if(iceCache&&Date.now()<iceCache.until)return iceCache.list;
  if(location.hostname!=='lopoke89-ops.github.io')return STUN;   // the Worker only answers the live site
  try{
    const ctl=new AbortController(),to=setTimeout(()=>ctl.abort(),3000);
    const r=await fetch(TURN_URL,{method:'POST',signal:ctl.signal});clearTimeout(to);
    const j=await r.json();
    if(Array.isArray(j.iceServers)&&j.iceServers.length){iceCache={list:[...j.iceServers,...STUN],until:Date.now()+3*3600e3};return iceCache.list}
  }catch(e){}
  return STUN;   // no relay this time: direct links still work
}
function peerOpts(ice){
  const q=new URLSearchParams(location.search),o={debug:0,config:{iceServers:ice||STUN}};
  if(q.get('peerhost')){o.host=q.get('peerhost');o.port=+q.get('peerport')||9000;o.path=q.get('peerpath')||'/';o.secure=q.get('peersecure')==='1'}
  return o;
}
function genCode(){const A='ABCDEFGHJKMNPQRSTUVWXYZ23456789';let s='';for(let i=0;i<4;i++)s+=A[Math.floor(rnd()*A.length)];return s}
function mStatus(t){$('mStatus').textContent=t||''}
function netFail(err){
  const why={'peer-unavailable':'No game with that code. Check it with the host, and make sure they’re sitting in the lobby.',
    'network':'Couldn’t reach the matchmaking service. Check your connection and try again.',
    'server-error':'The matchmaking service is having trouble. Try again in a minute.',
    'socket-error':'Couldn’t reach the matchmaking service. Check your connection and try again.',
    'browser-incompatible':'This browser can’t do online play. Try Safari or Chrome.',
    'timeout':'The room didn’t answer. Some mobile networks block direct connections; try both being on Wi-Fi.'}[err&&err.type]||`Couldn’t connect (${err&&err.type||'unknown'}).`;
  netReset();showPage('multi');mStatus(why);
}
function netReset(){
  if(NET.mode==='host')lobbyUnpublish();
  clearChat();
  try{NET.peer&&NET.peer.destroy()}catch(e){}
  Object.assign(NET,{mode:'solo',inGame:false,peer:null,code:'',roster:[],host:null,fxq:[],lastN:0,hostMods:[],roomLocked:false,banned:new Set(),leftBy:new Map()});NET.conns.clear();myId='solo';
}
function netLeave(msg){netReset();toMenu();if(msg){showPage('multi');mStatus(msg)}}

// ---------- host ----------
async function netHost(){
  if(inRun()&&$('menu').hidden)return;   // v0.9.3.7: never host or join over a live run
  if(!onlineOK()){mStatus('Getting online play ready…');if(!await needPeer()){mStatus(PEER_FAIL);return}if(NET.mode!=='solo')return}
  if(NET.mode==='opening'||NET.mode==='joining')return;   // already on its way
  pick.diff=pick.diff||'normal';mStatus('Opening a room…');NET.mode='opening';
  const ice=await getIce();
  if(NET.mode!=='opening')return;   // they backed out while the relay logins loaded
  const code=genCode(),peer=new Peer(ROOM_PREFIX+code,peerOpts(ice));NET.peer=peer;NET.mode='opening';
  peer.on('open',()=>{NET.incarnation=crypto.randomUUID();NET.mode='host';NET.code=code;NET.roomLocked=false;NET.banned=new Set();myId='host';NET.roster=[{id:'host',name:myName(),cls:pick.cls,cos:cosStr(myCos()),team:'a',sk:mySkills()}];mStatus('');showLobby();lobbyStartPublishing()});
  peer.on('connection',hostConn);
  peer.on('error',err=>{
    if(err.type==='unavailable-id'&&NET.mode==='opening'){try{peer.destroy()}catch(e){}netHost();return}
    if(NET.mode==='host'&&['network','server-error','socket-error','socket-closed','disconnected'].includes(err.type))return; // players already connected keep playing
    if(NET.mode==='host'&&err.type==='peer-unavailable')return;
    netFail(err)});
  peer.on('disconnected',()=>{if(NET.mode==='host')setTimeout(()=>{try{peer.reconnect()}catch(e){}},1500)});
}
function hostConn(conn){
  let c=NET.conns.get(conn.peer);if(!c){c={r:null,u:null,pid:null,heard:performance.now()};NET.conns.set(conn.peer,c)}
  c[conn.label==='u'?'u':'r']=conn;
  if(conn.label!=='u')conn.on('open',()=>{c.st=openStateCh(conn)});
  conn.on('data',d=>hostData(conn.peer,d));
  // only the reliable channel going away means the player left; the fast one can hiccup
  if(conn.label==='u')conn.on('close',()=>{const cc=NET.conns.get(conn.peer);if(cc&&cc.u===conn)cc.u=null});
  else conn.on('close',()=>hostDrop(conn.peer));
  conn.on('error',()=>{});
}
const rosterNow=()=>running()&&!demo?[...players.values()].map(p=>({id:p.id,name:p.name,cls:p.cls,cos:p.cosS,team:p.team,sk:p.sk})):NET.roster;
// v0.9.2: a guest's skill tree only counts once the host has checked it against their account (the server's copy);
// until then, and for players without an account, they play without perks
function checkSkills(c,claimed){
  const want=parseSkills(claimed);c.sk='';if(!validPlayerId(c.uid)||!claimed)return;
  const put=sk=>{c.sk=sk;const r=NET.roster.find(x=>x.id===c.pid);if(r){r.sk=sk;if(!NET.inGame)broadcastLobby()}
    const p=players.get(c.pid);if(p&&NET.inGame&&p.sk!==sk){p.sk=sk;const hp=p.hp/p.max;p.perk=perkMods(parseSkills(sk),!!game.pvp);p.max=0;refit(p);p.hp=Math.max(1,Math.round(p.max*hp))}};
  if(!cloudOn||!acct.s){if(new URLSearchParams(location.search).has('trustskills'))put(skillStr(want,want.molOff));return}   // offline test rooms only
  rpc('skills_of',{p_uid:c.uid}).then(r=>{if(!r.ok||!r.j||typeof r.j!=='object')return;const t={};
    for(const S of SKILLS)t[S.id]=Math.min(want[S.id]|0,r.j[S.id]|0);put(skillStr(parseSkills(skillStr(t)),want.molOff))}).catch(()=>{});
}
const startMsg=()=>({t:'start',roster:rosterNow(),diff:pick.diff,mode:game.mode,pvp:game.pvp,map:game.map,size:game.size,oct:game.oct?1:0,gid:game.gid,mods:game.mods,job:game.job,shots:bullets.filter(b=>!b.dead).map(bulletEvent)});
const lighterSide=list=>{let a=0,b=0;for(const r of list)if(r.team==='b')b++;else a++;return a<=b?'a':'b'};
function hostData(peerId,d){
  const c=NET.conns.get(peerId);if(!c||c.kicked||!d||typeof d!=='object'||Array.isArray(d)||typeof d.t!=='string')return;c.heard=performance.now();
  if(d.t==='hello'){
    if(c.pid||!c.r||!c.r.open)return;
    if(d.v!==PROTO){c.r.send({t:'kick',why:'Your copy of PALISADE is a different version from the host’s. Both of you reload the page.'});return}
    if(d.invitationSession&&d.invitationSession!==NET.incarnation){c.r.send({t:'kick',why:'That invitation belongs to an earlier room. Ask for a new invite.'});return}
    if(!/^[0-9a-f]{24}$/.test(d.session||''))return;
    if(NET.banned.has(d.session)){c.r.send({t:'kick',why:'The host removed you from the game.'});return}
    if(NET.roomLocked){c.r.send({t:'kick',why:'Room is locked.'});return}
    if(!hostText(d.name,HOST_LIMITS.name)||!CLASSES[d.cls]||!hostText(d.cos,HOST_LIMITS.cos)||!hostText(d.sk,HOST_LIMITS.skills)||
       !(d.uid===''||validPlayerId(d.uid)))return;
    if(NET.roster.length>=6){c.r.send({t:'kick',why:'That game is full (6 players).'});return}
    c.pid='g'+(NET.nextG++);c.session=d.session;c.name=String(d.name||'Player').slice(0,12);c.cls=CLASSES[d.cls]?d.cls:'soldier';c.cos=cosStr(parseCos(d.cos));c.uid=validPlayerId(d.uid)?d.uid:'';
    const team=NET.inGame&&game.pvp==='base'?lighterSide([...players.values()]):lighterSide(NET.roster);
    NET.roster.push({id:c.pid,name:c.name,cls:c.cls,cos:c.cos,team,sk:''});checkSkills(c,d.sk);
    c.r.send({t:'welcome',id:c.pid});
    if(NET.inGame){   // dropping into a game already running
      const p=makePlayer(c.pid,c.name,game.job||c.cls,players.size,c.cos,game.pvp==='base'?team:'',c.sk);kitUp(p);[p.x,p.y]=respawnAt(p);if(game.pvp)p.prot=PVP.prot;if(game.pvp==='base')p.sal=PVP.startSal;if(game.pvp==='ffa')p.mats=[0,0,0];const back=restoreLeaver(c,p);players.set(c.pid,p);
      c.r.send(startMsg());NET.wlSent=null;NET.piSent=null;NET.psLast=null;
      toastAll(`${c.name.toUpperCase()} ${back?'IS BACK':'JOINED'}`,back?'Armory and salvage restored.':game.pvp==='base'?`Dropped in on ${TEAMS[team].name}.`:game.pvp?'Dropped into the fight.':'Dropped in at the stake.')}
    broadcastLobby();return;
  }
  if(!c.pid)return;
  if(d.t==='loadout'){
    if(c.pid&&!NET.inGame){const r=NET.roster.find(x=>x.id===c.pid);if(r){
      if(!CLASSES[d.cls]||!hostText(d.cos,HOST_LIMITS.cos)||!hostText(d.name,HOST_LIMITS.name)||
         (d.sk!==undefined&&!hostText(d.sk,HOST_LIMITS.skills)))return;
      c.cls=CLASSES[d.cls]?d.cls:r.cls;c.cos=cosStr(parseCos(d.cos));c.name=String(d.name||r.name).slice(0,12);
      Object.assign(r,{cls:c.cls,cos:c.cos,name:c.name});if(d.sk!==undefined&&d.sk!==c.skAsk){c.skAsk=d.sk;checkSkills(c,d.sk)}broadcastLobby();
    }}return;
  }
  if(d.t==='ping')return;
  if(d.t==='c'){if(hostText(d.m,HOST_LIMITS.chat))hostChat(c.pid,d.m);return}
  if(d.t==='nextcls'){const p=players.get(c.pid);if(p&&NET.inGame&&game.pvp==='ffa'&&!game.job&&CLASSES[d.cls])p.nextCls=d.cls===p.cls?'':d.cls;return}
  if(d.t==='team'){if(!NET.inGame){const r=NET.roster.find(x=>x.id===c.pid);if(r){r.team=r.team==='b'?'a':'b';broadcastLobby()}}return}
  const p=players.get(c.pid);if(!p||!NET.inGame||!running())return;
  if(d.t==='i'){
    // Ignore malformed guest coordinates/aim before they reach collision, rendering or simulation.
    if(!hostFinite(d.x,0,N)||!hostFinite(d.y,0,N)||!hostFinite(d.ax,-1.1,1.1)||!hostFinite(d.ay,-1.1,1.1)||
       !hostInt(d.tp,0,1000000)||(d.n!==undefined&&(!Number.isSafeInteger(d.n)||d.n<0))||
       !hostInt(d.f,0,1)||!hostInt(d.a,0,1))return;
    const l=Math.hypot(d.ax,d.ay);if(l>.01){p.aim={x:d.ax/l,y:d.ay/l};p.face=p.aim}
    p.fireIn=!!d.f&&p.alive;p.autoFire=d.a!==0;if(d.n!==undefined&&d.n!==p.pullIn){if(p.pullIn===undefined)p.pullUsed=d.n;p.pullIn=d.n;p.pullT=game.time}
    if(p.alive&&d.tp===p.tp){
      const now=performance.now(),dt=Math.max(0,Math.min(.5,(now-(c.moveAt??now))/1000));c.moveAt=now;
      // Allow the class's maximum honest pace, including terrain at either end of this step.
      // A small margin absorbs guest/host storm timing and packet jitter without banking idle time.
      const speed=3.3*(p.C.spd||1)*(p.C.sprint?SPRINT.mult:1)*
        (p.perk||PERK0).speed*(hasMod('adrenaline')?1.2:1)*
        Math.max(slowAt(p.x,p.y),slowAt(d.x,d.y))*1.15;
      c.moveBudget=Math.min(HOST_LIMITS.moveBurst,(c.moveBudget??.55)+speed*dt);
      const dd=Math.hypot(d.x-p.x,d.y-p.y);
      if(dd<=c.moveBudget+.02&&dd<3&&travelClear(p.x,p.y,d.x,d.y,pt(p))){c.moveBudget=Math.max(0,c.moveBudget-dd);p.walk+=dd*3;p.x=d.x;p.y=d.y;p.z=heightAt(p.x,p.y)}
      else{p.tp++;if(new URLSearchParams(location.search).has('debug'))c.moveRejects=(c.moveRejects||0)+1}
    }
  }
  else if(d.t==='b'){if(hostInt(d.i,0,N-1)&&hostInt(d.j,0,N-1)&&hostInt(d.s,0,2)&&typeof d.d==='boolean')doBuild(p,d.i,d.j,d.s,d.d)}
  else if(d.t==='n'){if(hostFinite(d.x,-HOST_LIMITS.targetPad,N+HOST_LIMITS.targetPad)&&hostFinite(d.y,-HOST_LIMITS.targetPad,N+HOST_LIMITS.targetPad))throwNade(p,d.x,d.y)}
  else if(d.t==='u'){if(typeof d.k==='string'&&(UPG.some(u=>u.k===d.k)||d.k==='core'||d.k==='dell'))buyUpgrade(p,d.k)}
  else if(d.t==='am'){if(typeof d.id==='string'&&AMMO_BY[d.id]&&hostInt(d.slot,0,1))buyAmmo(p,d.id,d.slot)}
  else if(d.t==='rl'){if(p.gun.mag)p.rlReq=true}
  else if(d.t==='ab'){if(hostFinite(d.x,-HOST_LIMITS.targetPad,N+HOST_LIMITS.targetPad)&&hostFinite(d.y,-HOST_LIMITS.targetPad,N+HOST_LIMITS.targetPad))useAbility(p,d.x,d.y)}
}
function hostDrop(peerId){
  const c=NET.conns.get(peerId);if(!c)return;NET.conns.delete(peerId);
  try{c.r&&c.r.close()}catch(e){}try{c.u&&c.u.close()}catch(e){}
  if(!c.pid)return;
  NET.roster=NET.roster.filter(r=>r.id!==c.pid);
  if(NET.inGame&&players.has(c.pid)){const p=players.get(c.pid);stashLeaver(c,p);players.delete(c.pid);toastAll(`${c.name.toUpperCase()} LEFT`,'')}
  if(NET.inGame&&!$('pause').hidden)renderPauseCrew();
  broadcastLobby();
}
// v0.9.3.6: a player who drops (lost signal, reload, crash) and comes back to the same game keeps their armory,
// salvage and kills. Keyed by the browser's room session, which survives a reload in the same tab.
function stashLeaver(c,p){
  if(!c.session||c.kicked||!p||game.pvp)return;
  NET.leftBy.set(c.session,{gid:game.gid,chapter:game.chapter,prepEpoch:game.prepEpoch||0,cls:p.cls,up:{...p.up},ammoEq:p.ammoEq.slice(),sal:p.sal|0,kills:p.kills|0,deaths:p.deaths|0,out:!!p.out,chEvac:(p.chEvac||[]).slice(0,3),
    x:p.x,y:p.y,z:heightAt(p.x,p.y),hp:p.hp,max:p.max,alive:p.alive,downed:p.downed,rt:p.rt,revive:p.revive,mats:p.mats.slice(),nades:p.nades,ammo:p.ammo,rl:p.rl,rk:p.rk,rkCd:p.rkCd,stl:p.stl,stlCd:p.stlCd});
  if(NET.leftBy.size>12)NET.leftBy.delete(NET.leftBy.keys().next().value);
}
function restoreLeaver(c,p){
  const s=NET.leftBy.get(c.session);if(!s||s.gid!==game.gid||game.pvp)return false;NET.leftBy.delete(c.session);
  if(s.cls===p.cls){for(const k in p.up)p.up[k]=Math.max(0,Math.min(ARM_MAX,s.up[k]|0));p.upS=upStr(p);refit(p);p.nades=p.maxN}
  if(Array.isArray(s.ammoEq)&&ammoMode()){const a=s.ammoEq.map(id=>AMMO_BY[id]?id:'');p.ammoEq=[a[0]||'',p.cls==='sniper'&&a[1]&&a[1]!==a[0]?a[1]:'']}
  if(campaign()){
    const prepared=(game.prepEpoch||0)>s.prepEpoch;
    p.mats=s.mats.map((m,i)=>Math.min(m,p.cap[i]));
    if(!prepared){p.hp=Math.min(p.max,s.hp*(p.max/s.max));p.alive=s.alive;p.downed=s.downed;p.rt=s.rt;p.revive=s.revive;p.nades=Math.min(p.maxN,s.nades);p.rk=s.rk;p.rkCd=s.rkCd;p.stl=s.stl;p.stlCd=s.stlCd;if(s.cls===p.cls&&p.gun.mag){p.ammo=Math.min(p.gun.mag,s.ammo??p.gun.mag);p.rl=s.rl||0}}
    if(s.chapter===game.chapter&&!collides(s.x,s.y,.27,pt(p))){p.x=s.x;p.y=s.y;p.z=heightAt(p.x,p.y);p.tx=p.x;p.ty=p.y;p.tp++}
  }
  p.sal=Math.max(p.sal|0,s.sal);p.kills=s.kills;p.deaths=s.deaths;if(Array.isArray(s.chEvac))p.chEvac=s.chEvac.slice(0,3);   // v0.9.6.4: chapter evac results come back too
  if(s.out&&game.fb&&!game.fb.done&&s.chapter===game.chapter){p.out=true;p.alive=false;p.downed=false;p.ev=BLITZ.hold}return true;   // out is out, but only for the evac that's still running
}
function hostKick(pid){
  if(NET.mode!=='host'||pid==='host')return;
  for(const [peerId,c] of NET.conns)if(c.pid===pid&&!c.kicked){
    c.kicked=true;if(c.session)NET.banned.add(c.session);
    try{c.r&&c.r.open&&c.r.send({t:'kick',why:'The host removed you from the game.'})}catch(e){}
    setTimeout(()=>hostDrop(peerId),250);return;
  }
}
function broadcastLobby(){
  const msg={t:'lobby',roster:NET.roster,code:NET.code,diff:pick.diff,mode:pick.mode,pvp:pick.pvp,map:pick.map,size:pick.size,playing:NET.inGame,mods:roomMods(),job:pick.job,locked:NET.roomLocked};
  NET.sendAll(msg);if(!NET.inGame)renderLobby();
  if(NET.mode==='host'&&pubTimer)lobbyPublish();
}
function lobbyBlock(){
  if(pick.pvp==='coop')return'';
  if(NET.roster.length<2)return'PvP needs at least two players. Share the code.';
  if(pick.pvp==='base'&&(NET.roster.every(r=>r.team!=='b')||NET.roster.every(r=>r.team==='b')))return'Both sides need at least one player. Someone tap SWITCH SIDES.';
  return'';
}
function startOnline(){
  if(NET.mode!=='host')return;
  const why=lobbyBlock();if(why){$('lNote').textContent=why;return}
  demo=false;pick.oct=isOctober();newGame(NET.roster.map(r=>({...r})),pick.pvp,{mods:roomMods(),job:pick.job});NET.inGame=true;NET.snapN=0;
  const now=performance.now();for(const c of NET.conns.values())c.heard=now;   // the lobby wait is not silence
  NET.sendAll(startMsg());NET.wlSent=null;NET.piSent=null;NET.psLast=null;modsToast();
  enterGame();broadcastLobby();
}
// keep quiet lobbies alive (and NAT mappings open), and notice players who vanish
let lobbyT=0;
function lobbyNet(dt){
  lobbyT-=dt;if(lobbyT>0)return;lobbyT=2;const now=performance.now();
  if(NET.mode==='host'){NET.sendAll({t:'ping'});for(const[id,c]of NET.conns)if(c.pid&&now-c.heard>25000)hostDrop(id)}
  else if(NET.mode==='guest'){NET.toHost({t:'ping'});if(now-NET.lastHeard>25000)netLeave('Lost the host while waiting in the lobby.')}
}
function hostNet(dt){
  if(!NET.inGame){lobbyNet(dt);return}
  NET.snapT-=dt;
  if(NET.snapT<=0){NET.snapT=1/15;NET.snapN++;
    NET.sendState(makeSnap(false));
    // walls: checked 5 times a second; only changed tiles go out (events arrive reliably and in order),
    // with the whole grid at game start, when someone drops in, and every 10 s as a safety net
    let wl=null,wd=null;const now=performance.now();
    if(NET.snapN%3===1){const b=wallBytes(),old=NET.wlSent;
      if(!old||now-NET.wlAt>10000){wl=encodeWalls();NET.wlAt=now}
      else{for(let k=0,o=0;k<N*N;k++,o+=4)if(b[o]!==old[o]||b[o+1]!==old[o+1]||b[o+2]!==old[o+2]||b[o+3]!==old[o+3])(wd||(wd=[])).push(k,b[o],b[o+1],b[o+2],b[o+3])}
      NET.wlSent=b}
    const pi=changedInfo();
    if(NET.fxq.length||wl||wd||pi){sendEvents(NET.fxq,wl,wd,pi);NET.fxq=[]}}
  const now=performance.now();
  for(const[id,c]of NET.conns)if(c.pid&&now-c.heard>12000)hostDrop(id);   // phone locked or walked out of signal
}
// one-off events (sounds, particles, toasts, bullets, kill feed) and wall changes go on the reliable channel, so a
// lost or late state packet never takes them with it; big batches are split to stay under PeerJS's 16 KB JSON limit
function sendEvents(fx,wl,wd,pi){
  const out=[],put=(list,w,d,i)=>{const m={t:'x',n:NET.snapN,fx:list};if(campaign())m.cm=game.chapter;if(w)m.wl=w;if(d)m.wd=d;if(i)m.pi=i;
    if(list.length>1&&JSON.stringify(m).length>12000){const h=list.length>>1;put(list.slice(0,h),w,d,i);put(list.slice(h),null,null,null)}else out.push(m)};
  put(fx,wl,wd,pi);for(const m of out)NET.sendAll(m);
}
// a data channel that never resends (state is replaced 15 times a second, so a lost one is better skipped);
// both sides create it on the reliable connection with the same fixed id, no extra handshake
function openStateCh(conn){
  try{const pc=conn.peerConnection;if(!pc||!pc.createDataChannel)return null;return pc.createDataChannel('st',{negotiated:true,id:1000,ordered:false,maxRetransmits:0})}catch(e){return null}
}
function wallBytes(){
  const b=new Uint8Array(N*N*4);
  for(let k=0;k<N*N;k++){const w=walls[k],o=k*4;
    if(w){b[o]=0x80|(w.door?0x40:0)|(w.tm==='b'?0x20:w.tm==='a'?0x10:0)|(w.slab?0x08:0)|(w.mat&3);b[o+1]=clamp(Math.round(w.hp/w.max*255),1,255);b[o+2]=(w.fire>0?0x80:0)|clamp(Math.round(w.char*127),0,127)}
    b[o+3]=debris[k]}
  return b;
}
function encodeWalls(){const b=wallBytes();let s='';for(let i=0;i<b.length;i++)s+=String.fromCharCode(b[i]);return btoa(s)}
function setWallTile(k,f,hp,fc,db){
  debris[k]=db;
  if(!(f&0x80)){walls[k]=null;return}
  const mat=f&3,door=!!(f&0x40),ratio=hp/255;let w=walls[k];
  if(!w||w.mat!==mat||w.door!==door){w=makeWall(mat,door,ratio);walls[k]=w}
  else{const nh=w.max*ratio;if(nh<w.hp-.5)w.flash=.08;w.hp=nh}
  w.fire=fc&0x80?1:0;w.char=(fc&0x7f)/127;w.tm=f&0x20?'b':f&0x10?'a':undefined;w.slab=!!(f&0x08);
}
function decodeWalls(str){const s=atob(str);for(let k=0;k<N*N;k++){const o=k*4;setWallTile(k,s.charCodeAt(o),s.charCodeAt(o+1),s.charCodeAt(o+2),s.charCodeAt(o+3))}}
// only the tiles that changed: [tile, flags, health, fire/char, debris, tile, ...]
function applyWallDiff(d){for(let q=0;q+4<d.length;q+=5)setWallTile(d[q],d[q+1],d[q+2],d[q+3],d[q+4])}
// One list per kind of row, used by the host to pack and by guests to unpack, so the two can't drift apart.
// PL_STATE changes all the time and rides every state packet; PL_INFO rarely changes (joining, upgrades)
// and goes on the reliable channel only when it does.
// v0.9.6.3: the fields that are usually zero sit last and trailing zeros are dropped (like raider rows); height isn't sent
// because every screen works it out from the same map. PL_SLOW rarely changes, so it goes out only when it does (see slowRows).
const PL_STATE=[['id',p=>p.id],['x',p=>r2(p.x)],['y',p=>r2(p.y)],['ax',p=>r2(p.aim.x)],['ay',p=>r2(p.aim.y)],['hp',p=>Math.ceil(p.hp)],
  ['alive',p=>p.alive?1:0],['ammo',p=>p.gun.mag?p.ammo|0:-1],['tp',p=>p.tp],['down',p=>p.downed?1:0],['rev',p=>r2(p.revive)],['rt',p=>r2(p.rt)],
  ['bcd',p=>r2(Math.max(0,p.bcd))],['bolt',p=>p.bolt>0?r2(p.bolt/p.boltT):0],['rl',p=>p.rl>0?1:0],['stun',p=>r2(p.stun||0)],['ev',p=>r2(p.ev||0)]];   // ev (v0.9.4.0): seconds stood in the evac ring
const PL_SLOW=[['id',p=>p.id],['m0',p=>p.mats[0]],['m1',p=>p.mats[1]],['m2',p=>p.mats[2]],['nades',p=>p.nades],['sal',p=>p.sal|0],['kills',p=>p.kills|0],['deaths',p=>p.deaths|0],
  ['prot',p=>p.prot>0?1:0],['ab',p=>p.ab|0],['out',p=>p.out?1:0],['ce',p=>chEvacBits(p)]];   // ce (v0.9.6.4): chapter evac results, 2 bits a chapter   // out (v0.9.4.0): evacuated   // ab: class-ability state, reserved
const PL_INFO=[['id',p=>p.id],['name',p=>p.name],['cls',p=>p.cls],['slot',p=>p.slot],['max',p=>p.max],['maxN',p=>p.maxN],['upS',p=>p.upS],['cosS',p=>p.cosS],['team',p=>p.team||''],['ammoEq',p=>p.ammoEq.join(',')],['sk',p=>p.sk]];
// enemies: the boss-only fields sit last and trailing zeros are dropped, so a plain raider sends 7 numbers, not 12
const EN_STATE=[['id',e=>e.id],['type',e=>ECODE.indexOf(e.type==='boss'?'boss:'+e.boss:e.type)],['x',e=>r2(e.x)],['y',e=>r2(e.y)],['ax',e=>r2(e.aim.x)],['ay',e=>r2(e.aim.y)],
  ['hp',e=>r2(e.hp/e.max)],['plant',e=>e.planted?1:0],['st',e=>e.st||0],['stF',e=>e.st?r2(Math.max(0,e.stT/e.stM)):0],['lx',e=>r2(e.lx||0)],['ly',e=>r2(e.ly||0)],
  ['burn',e=>r2(e.burnT||0)],['slow',e=>r2(e.slowT||0)],['slowPct',e=>r2(e.slowPct||0)],['shieldLeft',e=>e.shieldHitsLeft||0],['shieldMax',e=>e.shieldHitsMax||0],['shieldBroken',e=>e.shieldBroken?1:0]];
const fieldIdx=L=>Object.fromEntries(L.map((f,i)=>[f[0],i])),PS=fieldIdx(PL_STATE),PI=fieldIdx(PL_INFO),PW=fieldIdx(PL_SLOW);
const packRow=(L,x)=>L.map(f=>f[1](x)),packTrim=(L,x)=>{const r=packRow(L,x);while(r.length>1&&r[r.length-1]===0)r.pop();return r},PE=fieldIdx(EN_STATE);
// player info that changed since it was last sent (all of it after a reset: game start, someone dropping in)
function changedInfo(){
  if(!NET.piSent)NET.piSent=new Map();const out=[];
  for(const p of players.values()){const r=packRow(PL_INFO,p),k=JSON.stringify(r);if(NET.piSent.get(p.id)!==k){NET.piSent.set(p.id,k);out.push(r)}}
  return out.length?out:null;
}
function applyInfo(rows){
  for(const r of rows){const id=r[PI.id];let p=players.get(id);
    if(!p){p=makePlayer(id,r[PI.name],r[PI.cls],r[PI.slot],r[PI.cosS],r[PI.team]);players.set(id,p)}
    else if(r[PI.cls]&&r[PI.cls]!==p.cls)changeClass(p,r[PI.cls]);   // a job change on the host
    if(r[PI.sk]!==undefined&&p.sk!==r[PI.sk]){const t=parseSkills(r[PI.sk]);p.sk=skillStr(t,t.molOff);p.perk=perkMods(t,!!game.pvp);refit(p)}
    if(r[PI.upS]!==undefined&&String(r[PI.upS])!==p.upS){p.upS=String(r[PI.upS]);UPG.forEach((U,i)=>p.up[U.k]=clamp(+p.upS[i]||0,0,ARM_MAX));refit(p)}
    if(r[PI.ammoEq]!==undefined){const a=String(r[PI.ammoEq]).split(',');p.ammoEq=[AMMO_BY[a[0]]?a[0]:'',p.cls==='sniper'&&AMMO_BY[a[1]]&&a[1]!==a[0]?a[1]:'']}
    if(r[PI.cosS]&&r[PI.cosS]!==p.cosS){p.cos=parseCos(r[PI.cosS]);p.cosS=cosStr(p.cos)}
    p.name=r[PI.name];p.slot=r[PI.slot];p.max=r[PI.max];p.maxN=r[PI.maxN];if(r[PI.team])p.team=r[PI.team]}
}
// a player's slow row goes out when it changes and for the next 8 packets (the state channel drops packets rather
// than resending), every player's every 30 packets as a safety net, and all of them after someone joins
function slowRows(){
  if(!NET.psLast)NET.psLast=new Map();const out=[],n=NET.snapN;
  for(const p of players.values()){const r=packRow(PL_SLOW,p),k=r.join(),o=NET.psLast.get(p.id);
    if(!o||o.k!==k){NET.psLast.set(p.id,{k,n});out.push(r)}else if(n-o.n<8||n%30===0)out.push(r)}
  return out;
}
function makeSnap(withWalls){
  const S=game.stats,flat=(a,f)=>{const o=[];for(const x of a)o.push(...f(x));return o};
  const s={t:'s',n:NET.snapN,ph:game.phase,w:game.wave,bk:game.bosses|0,tm:r2(game.timer),q:game.queue.length,tt:r2(game.time),won:game.won?1:0,wn:game.winner||'',
    sb:game.sbN|0,wx:game.wx?1:0,sd:game.sd?1:0,er:game.endReason||'',ed:r2(Math.max(0,((game.endDeadline||0)-performance.now())/1000)),qc:[qm.mode||'follow',qm.completedRaids||0,qm.layoutSize||4,qm.status||''],
    cs:flat(cores,c=>[r2(c.hp),c.max,c.flash>0?1:0]),st:[S.dropped,S.built,S.lost,S.repairs,S.revives],
    pl:[...players.values()].map(p=>packTrim(PL_STATE,p)),ps:slowRows(),
    qm:[r2(qm.x),r2(qm.y),r2(qm.aim.x),r2(qm.aim.y),Math.ceil(qm.hp),qm.max,qm.alive?1:0,r2(qm.revive),game.dellLv|0],
    en:enemies.map(e=>packTrim(EN_STATE,e)),
    rk:flat(rockets,r=>[r2(r.x),r2(r.y),r2(r.vx),r2(r.vy)]),
    fz:flat(fires,f=>[r2(f.x),r2(f.y),r2(f.t),r2(f.r||.9),f.nap|0]),   // nap: 1 napalm, 2 poison gas, 3 mine (v0.9.7)
    lo:flat(lobs,l=>[r2(l.x0),r2(l.y0),r2(l.x1),r2(l.y1),r2(l.t),r2(l.T),r2(l.R),l.k|0]),
    ch:flat(charges,c=>[r2(c.x),r2(c.y),r2(c.fuse)]),
    sa:flat(sacks,k=>[r2(k.x),r2(k.y)]),
    nd:flat(nodes,n=>[n.amt|0,n.locked?1:0]),fo:floodOn?1:0};
  if(game.bossLog&&game.bossLog.length)s.bl=game.bossLog;
  if(campaign())s.cm=game.chapter;
  if(frostFields.length)s.ice=frostFields.map(f=>[r2(f.x),r2(f.y),r2(f.t),r2(f.z)]);
  if(game.fb){const F=game.fb,E=F.evac;s.fb=[r2(F.t),F.n,F.max,E?r2(E.x):0,E?r2(E.y):0,E?r2(E.r):0,F.done?1:0,F.mapEvac?1:F.gauntlet?2:0,F.ch|0,F.wave|0]}   // [7] kind (v0.9.6.4): 1 map evac, 2 gauntlet   // v0.9.4.0: the Final Blitz clock and the evac site
  if(game.fbLog&&game.fbLog.length)s.fl=game.fbLog;
  if(game.gKill&&game.gKill.length)s.gk=game.gKill;   // v0.9.6.4: gauntlet kills per wave (each soldier's claim counts cleared waves)
  if(arcs.length)s.ar=flat(arcs,r=>[r2(r.x),r2(r.y),r2(r.vx),r2(r.vy)]);
  if(game.sbLog&&game.sbLog.length)s.sl=game.sbLog;   // v0.9.3.8: which in-between bosses fell (boss milestones for everyone)   // which bosses fell (each player's rewards are worked out on their own phone)
  if(terrLog.length)s.tr=terrLog;   // ground that changed (pits, a rammed bridge): a few numbers
  if(withWalls){s.wl=encodeWalls();s.bu=bullets.filter(b=>!b.dead).map(bulletEvent)}
  return s;
}

// ---------- guest ----------
async function netJoin(code,invitationSession=''){
  if(inRun()&&$('menu').hidden)return;   // v0.9.3.7: never host or join over a live run
  if(!onlineOK()){mStatus('Getting online play ready…');if(!await needPeer()){mStatus(PEER_FAIL);return}if(NET.mode!=='solo')return}
  code=String(code||'').toUpperCase().replace(/[^A-Z0-9]/g,'');
  if(code.length!==4){mStatus('Room codes are 4 letters and numbers.');return}
  if(NET.mode==='opening'||NET.mode==='joining')return;
  mStatus('Finding room '+code+'…');NET.mode='joining';
  const ice=await getIce();
  if(NET.mode!=='joining')return;
  const peer=new Peer(undefined,peerOpts(ice));NET.peer=peer;NET.mode='joining';NET.code=code;
  const to=setTimeout(()=>{if(NET.mode==='joining')netFail({type:'timeout'})},15000);
  peer.on('open',()=>{
    const tgt=ROOM_PREFIX+code,r=peer.connect(tgt,{label:'r',reliable:true,serialization:'json'}),uu=peer.connect(tgt,{label:'u',reliable:false,serialization:'json'});
    NET.host={r,u:uu};
    r.on('open',()=>{clearTimeout(to);NET.lastHeard=performance.now();const st=openStateCh(r);if(st){NET.host.st=st;st.onmessage=ev=>{try{guestData(JSON.parse(ev.data))}catch(e){}}}r.send({t:'hello',name:myName(),cls:pick.cls,cos:cosStr(myCos()),v:PROTO,sk:mySkills(),uid:locker.cloud?myUid():'',session:ROOM_SESSION,invitationSession})});
    for(const c of[r,uu]){c.on('data',guestData);c.on('error',()=>{})}
    r.on('close',()=>{if(NET.mode==='guest')netLeave('The host closed the game.')});
  });
  peer.on('error',err=>{clearTimeout(to);if(NET.mode==='guest'&&['network','server-error','socket-error','socket-closed','disconnected'].includes(err.type))return;netFail(err)});
}
function guestData(d){
  if(!d)return;NET.lastHeard=performance.now();
  switch(d.t){
    case'welcome':myId=d.id;NET.mode='guest';mStatus('');showLobby();break;
    case'lobby':NET.roster=d.roster;NET.code=d.code;NET.roomLocked=!!d.locked;pick.diff=d.diff;if(d.mode)pick.mode=d.mode;pick.pvp=d.pvp||'coop';NET.hostMods=cleanMods(d.mods,pick.pvp==='base'||pick.pvp==='ffa'?pick.pvp:d.mode==='blitz'?'blitz':'');pick.job=CLASSES[d.job]?d.job:pick.job;if(d.map)pick.map=MAP_IDS.includes(d.map)?d.map:'yard';if(d.size)pick.size=d.size==='xl'?'xl':'std';if(!NET.inGame)renderLobby();break;
    case'start':pick.diff=d.diff;if(d.mode)pick.mode=d.mode;pick.pvp=d.pvp||'coop';pick.map=MAP_IDS.includes(d.map)?d.map:'yard';pick.size=d.size==='xl'?'xl':'std';pick.oct=!!d.oct;demo=false;
      newGame(d.roster,d.pvp||'',{gid:d.gid,mods:d.mods,job:d.job,guest:true});replayFx(d.shots||[]);NET.lastN=0;NET.inGame=true;enterGame();modsToast();break;
    case'ping':break;
    case's':if(NET.inGame&&d.n>NET.lastN){NET.lastN=d.n;applySnap(d)}break;
    case'x':if(NET.inGame){if(campaign()&&d.cm!==undefined){if(d.cm<game.chapter)break;if(d.cm!==game.chapter)changeChapter(d.cm,true)}if(d.pi)applyInfo(d.pi);if(d.wl)decodeWalls(d.wl);if(d.wd)applyWallDiff(d.wd);replayFx(d.fx||[])}break;
    case't':toast(d.b,d.s);break;
    case'kick':netLeave(d.why);break;
    case'c':addChat(d.id,d.n,cleanChat(d.m),d.tm);break;
  }
}
function applySnap(s){
  if(campaign()&&s.cm!==undefined){if(s.cm<game.chapter)return;if(s.cm!==game.chapter)changeChapter(s.cm,true)}
  const wasOver=game.phase==='over';
  game.phase=s.ph;game.wave=s.w;game.timer=s.tm;game.bosses=s.bk|0;game.qn=s.q;game.won=!!s.won;game.winner=s.wn||'';
  game.sbN=s.sb|0;game.wx=s.wx?1:0;game.sd=!!s.sd;
  game.endReason=s.er||'';if(!wasOver&&s.ph==='over')game.endDeadline=performance.now()+Math.max(0,s.ed||0)*1000;
  if(s.qc){qm.mode=s.qc[0];qm.completedRaids=s.qc[1];qm.layoutSize=s.qc[2];qm.status=s.qc[3]}
  if(game.joinHeld==null){game.joinHeld=s.ph==='build'||s.ph==='over'&&s.won?s.w:Math.max(0,s.w-1);game.joinT=s.tt;game.joinBoss=(s.bl||[]).length;game.joinSB=s.sb|0;game.joinFB=(s.fl||[]).length}   // where this phone came in
  if(game.pvp)game.won=game.pvp==='base'?!!player&&player.team===game.winner:myId===game.winner;
  if(Math.abs(game.time-s.tt)>1)game.time=s.tt;
  for(let i=0;i<cores.length&&i*3<s.cs.length;i++){const c=cores[i],o=i*3;if(s.cs[o]<c.hp-.01)c.flash=.12;c.hp=s.cs[o];c.max=s.cs[o+1]}
  const st=s.st;game.stats={dropped:st[0],built:st[1],lost:st[2],repairs:st[3],revives:st[4]};
  const seen=new Set();
  for(const r of s.pl){
    const v=k=>r[PS[k]]||0,id=r[PS.id];let p=players.get(id);seen.add(id);
    if(!p)continue;   // their details (name, job, outfit) arrive on the reliable channel; they appear a moment later
    if(p.fresh===undefined){p.fresh=0;p.x=v('x');p.y=v('y')}
    p.z=heightAt(v('x'),v('y'));   // v0.9.6.3: worked out here, not sent
    const mine=id===myId;
    if(mine){if(v('tp')!==p.tp){p.x=v('x');p.y=v('y');p.tp=v('tp')}}
    else{p.tx=v('x');p.ty=v('y');p.aim={x:v('ax'),y:v('ay')};p.tp=v('tp')}
    if(v('hp')<p.hp-.01)p.flash=.1;
    p.hp=v('hp');p.alive=!!v('alive');p.downed=!!v('down');p.revive=v('rev');p.rt=v('rt');p.bcd=v('bcd');
    if(v('bolt')>(p.boltF||0)+.05)p.boltF=v('bolt');
    p.ammo=v('ammo');p.rl=v('rl')?1:0;p.stun=v('stun');p.ev=v('ev');
  }
  for(const id of[...players.keys()])if(!seen.has(id))players.delete(id);
  player=players.get(myId)||player;
  for(const r of s.ps||[]){const p=players.get(r[PW.id]);if(!p)continue;   // v0.9.6.3: slow fields, only when they changed
    p.mats=[r[PW.m0]|0,r[PW.m1]|0,r[PW.m2]|0];p.nades=r[PW.nades]|0;p.sal=r[PW.sal]|0;p.kills=r[PW.kills]|0;p.deaths=r[PW.deaths]|0;p.prot=r[PW.prot]?1:0;p.ab=r[PW.ab]|0;p.out=!!r[PW.out];p.chEvac=chEvacFrom(r[PW.ce]|0)}
  const q=s.qm;if(q[4]<qm.hp-.01)qm.flash=.1;qm.tx=q[0];qm.ty=q[1];qm.aim={x:q[2],y:q[3]};qm.hp=q[4];qm.max=q[5];qm.alive=!!q[6];qm.revive=q[7];game.dellLv=q[8]|0;
  const old=new Map(enemies.map(e=>[e.id,e]));enemies=[];
  for(const r of s.en){const v=k=>r[PE[k]]||0,id=r[PE.id];let e=old.get(id);
    if(!e)e={id,x:v('x'),y:v('y'),walk:rnd()*6,flash:0,max:1,hp:1};
    if(v('hp')<e.hp-.001)e.flash=.08;
    const c=ECODE[v('type')]||'rifle',bk=c.startsWith('boss:')?c.slice(5):'';
    Object.assign(e,{type:bk?'boss':c,boss:bk||undefined,big:!!bk,raft:!!(BOSSES[bk]&&BOSSES[bk].raft)&&waterK(idx(clamp(Math.floor(v('x')),0,N-1),clamp(Math.floor(v('y')),0,N-1))),burrow:bk==='foreman'&&(v('st')===2||v('st')===4),tx:v('x'),ty:v('y'),aim:{x:v('ax'),y:v('ay')},hp:v('hp'),max:1,planted:!!v('plant'),st:v('st'),stF:v('stF'),lx:v('lx'),ly:v('ly'),burnT:v('burn'),slowT:v('slow'),slowPct:v('slowPct'),z:heightAt(v('x'),v('y')),shieldHitsLeft:v('shieldLeft'),shieldHitsMax:v('shieldMax'),shieldBroken:!!v('shieldBroken')});enemies.push(e)}
  frostFields=(s.ice||[]).map(f=>({x:f[0],y:f[1],t:f[2],z:f[3],r:.72,k:idx(Math.floor(f[0]),Math.floor(f[1]))}));
  rockets=[];for(let o=0;o<(s.rk||[]).length;o+=4)rockets.push({x:s.rk[o],y:s.rk[o+1],vx:s.rk[o+2],vy:s.rk[o+3]});
  fires=[];for(let o=0;o<(s.fz||[]).length;o+=5)fires.push({x:s.fz[o],y:s.fz[o+1],t:s.fz[o+2],r:s.fz[o+3],nap:s.fz[o+4]|0,max:4});
  arcs=[];for(let o=0;o<(s.ar||[]).length;o+=4)arcs.push({x:s.ar[o],y:s.ar[o+1],vx:s.ar[o+2],vy:s.ar[o+3]});
  if(Array.isArray(s.fb)){const f=s.fb;game.fb={t:f[0],n:f[1],max:f[2],evac:f[5]?{x:f[3],y:f[4],r:f[5]}:null,done:!!f[6],mapEvac:f[7]===1,gauntlet:f[7]===2,ch:f[8]|0,wave:f[9]|0}}else game.fb=null;
  if(Array.isArray(s.fl))game.fbLog=s.fl.slice(0,20);
  if(Array.isArray(s.gk))game.gKill=s.gk.slice(0,6);
  if(s.bu){bullets.length=0;for(const e of s.bu)addGuestBullet(e)}
  lobs=[];for(let o=0;o<s.lo.length;o+=8)lobs.push({x0:s.lo[o],y0:s.lo[o+1],x1:s.lo[o+2],y1:s.lo[o+3],t:s.lo[o+4],T:s.lo[o+5],R:s.lo[o+6],k:s.lo[o+7]});
  charges=[];for(let o=0;o<s.ch.length;o+=3)charges.push({x:s.ch[o],y:s.ch[o+1],fuse:s.ch[o+2]});
  sacks=[];for(let o=0;o<s.sa.length;o+=2)sacks.push({x:s.sa[o],y:s.sa[o+1]});
  for(let i=0;i<nodes.length&&i*2<s.nd.length;i++){nodes[i].amt=s.nd[i*2];nodes[i].locked=!!s.nd[i*2+1]}
  if(s.wl)decodeWalls(s.wl);
  if(s.tr&&s.tr.length!==terrLog.length){applyTerrLog(s.tr);terrLog=s.tr.slice()}
  floodOn=!!s.fo;if(s.bl)game.bossLog=s.bl.slice(0,40);if(Array.isArray(s.sl))game.sbLog=s.sl.slice(0,100);
  replayFx(s.fx||[]);
  if(blitz()&&game.phase==='over'&&player)game.won=!!player.out;   // v0.9.4.0: each soldier's own evacuation decides their result
  if(game.phase==='over'&&!wasOver)showOver();
}
// Optional tail fields keep old shot events readable; no simulation data depends on them.
function cosmeticPoint(v,n){return Array.isArray(v)&&(v.length===n||v.length===n+1)&&v.every(Number.isFinite)?v:null}
function addGuestBullet(e){
 if(bullets.some(b=>b.id===e[1]))return; // start snapshot and queued reliable shot may overlap
 const visual=cosmeticPoint(e[10],4),owner=visual&&players.get(e[11]);if(owner)owner._shotDrawUntil=game.time+.08;
 if(bullets.length<300)bullets.push({id:e[1],x:e[2],y:e[3],vx:e[4],vy:e[5],team:e[6],heavy:!!e[7],tr:e[8],tc:Math.max(0,e[12]|0),left:e[9],dist:0,z0:Number.isFinite(e[13])?e[13]:heightAt(e[2],e[3])+.7,zSlope:Number.isFinite(e[14])?e[14]:0,visual});
}
function replayFx(list){
  replaying=true;
  try{for(const e of list)switch(e[0]){
    case'e':for(let n=e[6]||1;n>0;n--)emit(e[1],e[2],e[3]*u,e[4],e[5]);break;
    case'E':emitSpread(e[1],e[2],e[3],e[4]*u,e[5]*u,e[6],e[7],e[8]);break;
    case'b':addGuestBullet(e);break;
    case'bx':{const gone=new Set(e.slice(1));for(const b of bullets)if(gone.has(b.id))b.dead=true;compactBullets();break}
    case's':sfx(e[1],e[2]===null?undefined:e[2],e[3]===null?undefined:e[3],true);break;
    case'f':flt(e[1],e[2],e[3],e[4]);break;
    case'k':addShake(e[1],e[2],e[3]);break;
    case'h':flashes.push({x:e[1],y:e[2],r:e[3],muzzle:!!e[4],life:e[5],max:e[5],visual:cosmeticPoint(e[6],2)});break;
    case't':toast(e[1],e[2]);break;
    case'p':if(e[1]===myId)feel(e[2]);break;
    case'q':feedLocal(e[1],e[2]);break;
    case'z':zaps.push({pts:e.slice(1),life:.38,max:.38});break;
    case'w':slashes.push({x:e[1],y:e[2],ax:e[3],ay:e[4],life:.28,max:.28});break;
    case'C':chains.push({x0:e[1],y0:e[2],x1:e[3],y1:e[4],life:.45,max:.45});break;
    case'o':rings.push({x:e[1],y:e[2],r0:e[3],r1:e[4],life:e[5],max:e[5],c1:e[6],c2:e[7],w:e[8]});break;
  }}finally{replaying=false}
}
function guestUpdate(dt){
  game.time+=dt;if(game.phase==='raid'&&$('tipText').textContent&&!game.pvp)setTip('');for(const c of cores)c.flash=Math.max(0,c.flash-dt);
  const k=1-Math.exp(-dt*14);
  const smooth=e=>{if(e.tx===undefined)return;const dx=e.tx-e.x,dy=e.ty-e.y,d=Math.hypot(dx,dy);
    if(d>3){e.x=e.tx;e.y=e.ty}else{e.x+=dx*k;e.y+=dy*k;e.walk=(e.walk||0)+d*k*3}};
  for(const p of players.values()){if(p!==player)smooth(p);p.flash=Math.max(0,(p.flash||0)-dt);if(p.boltF>0)p.boltF=Math.max(0,p.boltF-dt*1.9);if(p.stun>0)p.stun=Math.max(0,p.stun-dt)}
  smooth(qm);qm.flash=Math.max(0,qm.flash-dt);
  for(const e of enemies){smooth(e);e.flash=Math.max(0,e.flash-dt);e.burnT=Math.max(0,(e.burnT||0)-dt);e.slowT=Math.max(0,(e.slowT||0)-dt)}
  for(const b of bullets){b.x+=b.vx*dt;b.y+=b.vy*dt;b.dist=(b.dist||0)+Math.hypot(b.vx,b.vy)*dt;if(b.left!==undefined){b.left-=Math.hypot(b.vx,b.vy)*dt;if(b.left<=0||!inb(b.x|0,b.y|0))b.dead=true}}
  compactBullets();
  for(const l of lobs)l.t=Math.min(l.T,l.t+dt);
  for(const r of arcs){r.x+=r.vx*dt;r.y+=r.vy*dt}if(game.fb&&!game.fb.done&&game.phase==='raid')game.fb.t=Math.max(0,game.fb.t-dt);   // v0.9.4.0
  for(const r of rockets){r.x+=r.vx*dt;r.y+=r.vy*dt}for(const f of fires)f.t-=dt;
  for(const e of enemies)if(e.st&&e.stF>0)e.stF=Math.max(0,e.stF-dt/1.1);
  for(const c of charges)c.fuse-=dt;
  for(const w of walls)if(w)w.flash=Math.max(0,w.flash-dt);
  if(player&&player.alive){NET.inT-=dt;if(NET.inT<=0){NET.inT=1/30;const p=player;
    NET.toHost({t:'i',x:r2(p.x),y:r2(p.y),ax:r2(p.aim.x),ay:r2(p.aim.y),f:p.fireIn?1:0,tp:p.tp,n:mouse.pulls,a:p.autoFire?1:0},'u')}}
  else{NET.inT-=dt;if(NET.inT<=0){NET.inT=1;NET.toHost({t:'ping'},'u')}}
  if(performance.now()-NET.lastHeard>12000)netLeave('Lost the host. Their phone may have locked or dropped signal.');
}

