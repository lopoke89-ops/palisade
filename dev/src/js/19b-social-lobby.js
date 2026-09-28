/* Account identity and a party lobby. Saved players use the signed-in user's existing metadata. */
const SAVED_PLAYERS_KEY='palisade_saved_players_v1';
const SOCIAL={owner:null,ids:[],profiles:[],rooms:[],result:null,status:'',busy:false,loading:false,roomsOK:false,seq:0,searchSeq:0,timer:0};
const validPlayerId=v=>typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
const savedPlayerIds=user=>[...new Set((Array.isArray(user?.user_metadata?.[SAVED_PLAYERS_KEY])?user.user_metadata[SAVED_PLAYERS_KEY]:[]).filter(validPlayerId))].slice(0,50);
const socialAccount=()=>cloudOn&&acct.state==='full'&&!isGuest()&&!!myUid();
const socialVisible=()=>!$('menu').hidden&&['multi','lobby'].includes($('menu').dataset.page);
// the pages that use the lobby shell (character on stage, columns either side)
const STAGE_PAGES=['solo','classes','multi','lobby'];
const stageVisible=()=>!$('menu').hidden&&STAGE_PAGES.includes($('menu').dataset.page);
const inRoom=()=>NET.mode==='host'||NET.mode==='guest';
function socialReset(){SOCIAL.owner=myUid();SOCIAL.ids=[];SOCIAL.profiles=[];SOCIAL.rooms=[];SOCIAL.result=null;SOCIAL.status='';SOCIAL.loading=false;SOCIAL.busy=false;SOCIAL.roomsOK=false;SOCIAL.seq++;SOCIAL.searchSeq++;}
function renderIdentity(){
 const b=$('identityButton');if(!b)return;
 const full=acct.state==='full'&&!isGuest(),name=acct.name||(full?'SET USERNAME':myName());
 $('identityName').textContent=name;
 const named=full&&!!acct.name;$('mName').readOnly=named;if(named)$('mName').value=acct.name.slice(0,12);else if(document.activeElement!==$('mName'))$('mName').value=cfg.name||'';
 const state=full?(locker.cloud&&locker.cloud.id===myUid()?'SIGNED IN · LOCKER SYNCED':'SIGNED IN · LOCKER SYNC PENDING'):acct.state==='wait'?'CONNECTING TO ACCOUNT':acct.state==='guest'?'GUEST · SAVE YOUR ACCOUNT':acct.state==='down'?'ACCOUNT OFFLINE':'LOCAL PROFILE';
 $('identityState').textContent=state;b.classList.toggle('signedIn',full);b.setAttribute('aria-label',name+', '+state+'. Open account');$('identityShards').textContent=String(locker.shards||0);
 const cv=$('identityAvatar'),key=cosStr(locker.eq)+'|'+pick.cls;if(cv.dataset.look!==key){cv.dataset.look=key;const x=cv.getContext('2d');x.clearRect(0,0,88,88);drawFig(x,88,88,lookOf(locker.eq,pick.cls),2.2,{x:.8,y:.3},106)}
 if(SOCIAL.owner!==myUid())socialReset();
 if(socialVisible())renderSocial();
}
function syncPartyShell(){
 const pg=$('menu').dataset.page,on=STAGE_PAGES.includes(pg),social=socialVisible();$('partyShell').hidden=!on;$('menu').classList.toggle('partyMenu',on);
 document.querySelectorAll('[data-nav]').forEach(b=>{const cur=b.dataset.nav===pg||(b.dataset.nav==='multi'&&pg==='lobby');if(cur)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current')});
 if(on){renderIdentity();renderPartyState();partyPaintAt=0;partySig=''}
 if(social){refreshSocial();if(!SOCIAL.timer)SOCIAL.timer=setInterval(()=>{if(socialVisible())refreshSocial();else{clearInterval(SOCIAL.timer);SOCIAL.timer=0}},15000)}
 else{clearInterval(SOCIAL.timer);SOCIAL.timer=0}
 if(on&&(pg==='solo'||pg==='classes'))renderPlayPanel();
}
function partyRows(){return inRoom()?NET.roster:[{id:myId,name:myName(),cls:pick.cls,cos:cosStr(locker.eq)}]}
function partyInvite(){
 if(NET.code){$('shareBtn').click();$('partyHint').textContent='Use the invite link or room code to bring your crew.'}
 else{$('partyHint').textContent='Create a room with HOST, then copy its invite link for your crew.';$('hostBtn').focus();$('hostBtn').scrollIntoView({block:'nearest'})}
}
function renderPartyState(){
 if(!$('partyShell')||$('partyShell').hidden)return;
 const room=inRoom(),rows=partyRows(),me=rows.find(r=>r.id===myId)||rows[0],pg=$('menu').dataset.page,C=CLASSES[pick.cls]||CLASSES.soldier,M=MAPS[pick.map]||MAPS.yard;
 if(pg==='solo'||pg==='classes'){
  $('partyMode').textContent=pg==='solo'?`SOLO · ${M.name}${pick.size==='xl'?' XL':''}`:'CLASSES';$('partyTitle').textContent=pg==='solo'?'HOLD THE STAKE.':C.name;
  $('partySubtitle').textContent=pg==='solo'?`${LEN_NAME[pick.mode]||'5 RAIDS'} · ${DIFF[pick.diff].name} · ${C.name}`:'Your job carries into solo and multiplayer.';
  $('partyPlayerName').textContent=myName();$('partyPlayerState').textContent=pg==='solo'?'READY':'CHOOSING A JOB';
  $('partyHint').textContent=pg==='solo'?M.blurb:'';return}
 $('partyMode').textContent=MODE_NAME[pick.pvp]||'CO-OP';$('partyTitle').textContent=room?'PARTY LOBBY':'YOUR CREW. YOUR CLAIM.';
 $('partySubtitle').textContent=room?`ROOM ${NET.code} · ${rows.length} / 6 PLAYERS${pick.pvp==='coop'?' · '+M.name+(pick.size==='xl'?' XL':''):''}`:'Choose your job. Bring your crew.';
 $('partyPlayerName').textContent=me?.name||myName();$('partyPlayerState').textContent=room?(NET.mode==='host'?'PARTY LEADER':'WAITING FOR HOST'):'CHOOSING A LOADOUT';
 const box=$('partySlots');box.textContent='';
 for(let i=0;i<6;i++){const r=rows[i],el=document.createElement(r?'div':'button');el.className='partySlot'+(r?' occupied':'');
  const b=document.createElement('b'),small=document.createElement('small');b.textContent=r?r.name:'+';small.textContent=r?`${r.id===myId?'YOU · ':''}${CLASSES[r.cls]?.name||'PLAYER'}`:'INVITE';el.append(b,small);
  if(!r){el.type='button';el.setAttribute('aria-label','Invite player to slot '+(i+1));el.addEventListener('click',partyInvite)}box.append(el)}
 $('partyHint').textContent=room?'Share your room link. Your host starts the match.':'Up to six players · desktop and mobile';
}
let partyPaintAt=0,partySig='';
// The stage is repainted only when something on it changes: who is on it, their looks, the (slowly swinging)
// heading step or an animated cosmetic's tick. Idle, that is every few seconds instead of 10-20 times a second.
function drawPartyPreview(now){
 if(!stageVisible()||now-partyPaintAt<(touchMode?LOBBY.stageTouch:LOBBY.stageDesk))return;partyPaintAt=now;
 const rows=partyRows(),me=rows.find(r=>r.id===myId)||rows[0],others=rows.filter(r=>r!==me),solo=!socialVisible(),t=now/1000;   // PLAY and CLASSES: just you on the stage
 const meA=.35+Math.sin(now/4500)*.16,look=r=>lookOf(parseCos(r.cos),r.cls),looks=[me,...(solo?[]:others.slice(0,2))].map(r=>r&&look(r));
 const sig=solo+'|'+rows.map(r=>r.id+r.cls+r.cos).join()+'|'+(looks[0]?wardrobePoseSig(looks[0],meA,t,13.4):'')+'|'+looks.slice(1).map((o,i)=>o?wardrobePoseSig(o,i?-.3:.3,t,8):'').join();
 if(sig===partySig)return;partySig=sig;
 const cv=$('partyPreview'),x=cv.getContext('2d');x.clearRect(0,0,cv.width,cv.height);
 const pad=(px,py,r,active)=>{cosmeticGlow(x,px,py,r*1.5,active?'#7de6e8':'#536f89',active?.15:.1);x.fillStyle=active?'rgba(170,239,239,.12)':'rgba(122,171,192,.06)';x.strokeStyle=active?'#b4edee':'#597386';x.lineWidth=active?3:2;x.beginPath();x.ellipse(px,py,r,r*.22,0,0,Math.PI*2);x.fill();x.stroke()};
 if(!solo)for(const [i,px]of [160,840].entries()){pad(px,625,90,!!others[i]);if(others[i])drawWardrobeCharacter(x,looks[i+1],i?-.3:.3,t,8,px,610,false);else{x.fillStyle='#7e98a5';x.font='300 60px system-ui';x.textAlign='center';x.fillText('+',px,590)}}
 pad(500,720,154,true);if(me)drawWardrobeCharacter(x,looks[0],meA,t,13.4,500,700,false);
}
function socialMessage(){return !cloudOn?'Saved players are available on the live site.':acct.state==='wait'?'Connecting to your account…':!socialAccount()?'Sign in to save players across your devices.':SOCIAL.status}
function socialRow(profile,result=false){
 const row=document.createElement('div');row.className='friendRow';const avatar=document.createElement('canvas');avatar.width=avatar.height=80;avatar.setAttribute('aria-hidden','true');drawFig(avatar.getContext('2d'),80,80,lookOf(parseCos(profile.cos),'soldier'),1.65,{x:.8,y:.3},82);
 const copy=document.createElement('div'),name=document.createElement('b'),status=document.createElement('small');name.textContent=profile.username||'PLAYER';
 const room=SOCIAL.rooms.find(r=>r.host_id===profile.id),saved=SOCIAL.ids.includes(profile.id);
 status.textContent=result?(saved?'Already saved':'Player found'):room?(room.in_game?'IN MATCH':'IN LOBBY')+` · ${room.players}/6`:SOCIAL.roomsOK?'NO LISTED ROOM':'ROOM STATUS UNAVAILABLE';copy.append(name,status);
 const actions=document.createElement('div');actions.className='friendActions';
 const button=(label,fn)=>{const q=document.createElement('button');q.type='button';q.textContent=label;q.disabled=SOCIAL.busy;q.addEventListener('click',fn);actions.append(q);return q};
 if(result){const q=button(saved?'SAVED':'SAVE',()=>savePlayer(profile.id,true));q.disabled=saved||SOCIAL.busy||profile.id===myUid()}
 else{if(room){const q=button(room.players>=6?'FULL':'JOIN',()=>{if(NET.mode!=='solo')return;$('mCode').value=room.code;initAudio();netJoin(room.code)});q.disabled=SOCIAL.busy||room.players>=6||NET.mode!=='solo';q.title=NET.mode!=='solo'?'Leave your current party to join another':'Join '+profile.username}
 const q=button('REMOVE',()=>savePlayer(profile.id,false));q.setAttribute('aria-label','Remove '+profile.username+' from saved players')}
 row.append(avatar,copy,actions);return row;
}
function renderSocial(){
 const active=socialAccount();$('savedCount').textContent=String(active?SOCIAL.ids.length:0);$('friendName').disabled=!active||SOCIAL.busy;$('friendSearch').querySelector('button').disabled=!active||SOCIAL.busy;$('socialRefresh').disabled=!active||SOCIAL.loading||SOCIAL.busy;
 $('socialStatus').textContent=socialMessage()||'';
 const result=$('friendResult');result.textContent='';if(active&&SOCIAL.result)result.append(socialRow(SOCIAL.result,true));
 const list=$('savedPlayers');list.textContent='';
 if(active&&SOCIAL.profiles.length)for(const p of SOCIAL.profiles)list.append(socialRow(p));
 else{const p=document.createElement('p');p.className='socialEmpty';p.textContent=!active?'Your crew starts here. Sign in, then find a player by username.':SOCIAL.loading?'Loading your saved players…':SOCIAL.ids.length?'Saved players could not be loaded. Try Refresh.':'No saved players yet. Find someone above to keep your crew close.';list.append(p);
 if(!active){const q=document.createElement('button');q.className='ghost';q.type='button';q.textContent='OPEN ACCOUNT';q.addEventListener('click',()=>showPage('account'));list.append(q)}}
}
async function refreshSocial(){
 if(SOCIAL.owner!==myUid())socialReset();if(!socialAccount()){renderSocial();return}if(SOCIAL.loading||SOCIAL.busy)return;
 const owner=myUid(),seq=++SOCIAL.seq;SOCIAL.loading=true;renderSocial();
 const current=()=>owner===myUid()&&seq===SOCIAL.seq&&socialAccount();
 try{
  if(!await freshToken()||!current())return;
  const user=await sbFetch('/auth/v1/user');if(!current())return;
  if(!user.ok||user.j?.id!==owner){SOCIAL.status='Could not refresh saved players. Try again.';SOCIAL.rooms=[];SOCIAL.roomsOK=false;return}
  acct.s.user=user.j;setSession(acct.s);SOCIAL.ids=savedPlayerIds(user.j).filter(id=>id!==owner);
  if(!SOCIAL.ids.length){SOCIAL.profiles=[];SOCIAL.rooms=[];SOCIAL.roomsOK=true;return}
  const ids=SOCIAL.ids.join(','),[profiles,rooms]=await Promise.all([sbFetch('/rest/v1/profiles?select=id,username,cos&id=in.('+ids+')&banned=eq.false&limit=50'),sbFetch('/rest/v1/lobbies?select=host_id,code,players,in_game&host_id=in.('+ids+')&proto=eq.'+PROTO+'&limit=50')]);if(!current())return;
  SOCIAL.roomsOK=rooms.ok&&Array.isArray(rooms.j);SOCIAL.rooms=SOCIAL.roomsOK?rooms.j:[];
  if(profiles.ok&&Array.isArray(profiles.j)){SOCIAL.profiles=profiles.j.filter(p=>SOCIAL.ids.includes(p.id));SOCIAL.status=''}else SOCIAL.status='Could not load player profiles. Try Refresh.';
 }finally{if(owner===myUid()&&seq===SOCIAL.seq){SOCIAL.loading=false;renderSocial()}}
}
async function findPlayer(){
 if(!socialAccount()||SOCIAL.busy)return;const name=$('friendName').value.trim();if(!/^[A-Za-z0-9_]{3,16}$/.test(name)){SOCIAL.status='Enter an exact username (3–16 letters, numbers or _).';renderSocial();return}
 const owner=myUid(),seq=++SOCIAL.searchSeq;SOCIAL.result=null;SOCIAL.status='Looking for '+name+'…';renderSocial();if(!await freshToken()){if(owner===myUid()&&seq===SOCIAL.searchSeq){SOCIAL.status='Sign-in could not be refreshed. Try again.';renderSocial()}return}
 const r=await sbFetch('/rest/v1/profiles?select=id,username,cos&username=eq.'+encodeURIComponent(name)+'&banned=eq.false&limit=1');if(owner!==myUid()||seq!==SOCIAL.searchSeq||!socialAccount())return;
 const p=r.ok&&Array.isArray(r.j)?r.j.find(p=>validPlayerId(p.id)):null;
 if(p?.id===owner)SOCIAL.status='That is your account.';else if(p){SOCIAL.result=p;SOCIAL.status=''}else SOCIAL.status=r.ok?'No player with that username.':'Search is unavailable. Try again.';renderSocial();
}
async function savePlayer(id,add){
 if(!socialAccount()||SOCIAL.busy||!validPlayerId(id)||id===myUid())return;
 const owner=myUid();SOCIAL.seq++;SOCIAL.loading=false;SOCIAL.busy=true;SOCIAL.status=add?'Saving player…':'Removing player…';renderSocial();
 const current=()=>owner===myUid()&&socialAccount();
 try{
  if(!await freshToken()||!current())return;const fresh=await sbFetch('/auth/v1/user');if(!current())return;
  if(!fresh.ok||fresh.j?.id!==owner){SOCIAL.status='Could not save. Your list has not changed.';return}
  let ids=savedPlayerIds(fresh.j);if(add&&!ids.includes(id)){if(ids.length>=50){SOCIAL.status='Your list is full (50 players). Remove someone first.';return}ids.push(id)}else if(!add)ids=ids.filter(v=>v!==id);
  // Only our own metadata field is sent; passwords, profile fields and locker records are untouched.
  const r=await sbFetch('/auth/v1/user',{method:'PUT',body:{data:{[SAVED_PLAYERS_KEY]:ids}}});if(!current())return;
  if(!r.ok||r.j?.id!==owner){SOCIAL.status='Could not save. Try again.';return}
  acct.s.user=r.j;setSession(acct.s);SOCIAL.ids=ids;SOCIAL.status=add?'Player saved to your account.':'Player removed.';if(!add)SOCIAL.profiles=SOCIAL.profiles.filter(p=>p.id!==id);else if(SOCIAL.result?.id===id&&!SOCIAL.profiles.some(p=>p.id===id))SOCIAL.profiles.push(SOCIAL.result);
 }finally{if(current()){SOCIAL.busy=false;renderSocial()}}
}
$('partyControls').append($('pg-solo'),$('pg-classes'),$('pg-multi'),$('pg-lobby'));   // the left column of the lobby shell
$('friendSearch').addEventListener('submit',e=>{e.preventDefault();findPlayer()});$('socialRefresh').addEventListener('click',refreshSocial);


// Returning from the locker updates the real party loadout before the host starts.
function syncLobbyLoadout(){
 if(NET.inGame||!['host','guest'].includes(NET.mode))return;
 const r=NET.roster.find(r=>r.id===myId);if(!r)return;
 const next={name:myName(),cls:pick.cls,cos:cosStr(myCos())};
 if(r.name===next.name&&r.cls===next.cls&&r.cos===next.cos)return;
 if(NET.mode==='host'){Object.assign(r,next);broadcastLobby()}else NET.toHost({t:'loadout',...next});
}

// ---- PLAY: map cards (a painted thumbnail of each map), size, and the summary in the left column
const MAP_THUMBS=new Map();
function mapThumb(id,size){
 const key=id+'|'+size;let c=MAP_THUMBS.get(key);if(c)return c;
 c=document.createElement('canvas');c.width=172;c.height=116;const x=c.getContext('2d'),M=MAPS[id];
 // lay the map out on a scratch copy of the terrain, then draw it top-down as a tiny isometric diamond
 const keep=[terr,N,MAP,terrLog,MAPO,floodOn,floodLv];let L=null;
 try{L=layMap(id,size,'');const n=N,tw=172/(n+2)/1.02,th=tw*.5,ox=86,oy=6;
  x.fillStyle='#0e1519';x.fillRect(0,0,172,116);
  const col=t=>t===T_WATER?'#2a5a74':t===T_BRIDGE?'#7a5a38':t===T_LOW?'#3e4a30':t===T_CRACK?'#5a4838':t===T_ROCK?'#7c776d':t===T_DRUM?'#ff8a2a':id==='quarry'?'#403a33':id==='river'?'#394a2c':'#4a4030';
  for(let j=0;j<n;j++)for(let i=0;i<n;i++){const sx=ox+(i-j)*tw/2,sy=oy+(i+j)*th/2;x.fillStyle=col(terr[j*n+i]);x.beginPath();x.moveTo(sx,sy);x.lineTo(sx+tw/2,sy+th/2);x.lineTo(sx,sy+th);x.lineTo(sx-tw/2,sy+th/2);x.closePath();x.fill()}
  const dot=(i,j,c,r)=>{const sx=ox+(i-j)*tw/2,sy=oy+(i+j)*th/2+th/2;x.fillStyle=c;x.beginPath();x.arc(sx,sy,r,0,Math.PI*2);x.fill()};
  for(const nd of L.nodes)dot(nd.i,nd.j,nd.type===0?'#c09058':nd.type===1?'#a0533c':'#a3a9a8',1.6);
  for(const s of L.spawns)for(const t of s.tiles)dot(t[0],t[1],'#d65a3a',1.2);
  dot(L.core[0],L.core[1],'#e2b436',3);
 }finally{[terr,N,MAP,terrLog,MAPO,floodOn,floodLv]=keep}
 MAP_THUMBS.set(key,c);return c;
}
function renderPlayPanel(){
 const box=$('mapCards');if(!box)return;box.textContent='';
 for(const id of MAP_IDS){const M=MAPS[id],b=document.createElement('button');b.type='button';b.className='mapCard'+(pick.map===id?' sel':'');b.dataset.map=id;
  const cv=document.createElement('canvas');cv.width=172;cv.height=116;cv.getContext('2d').drawImage(mapThumb(id,pick.size),0,0);
  const t=document.createElement('div'),nm=document.createElement('b'),bl=document.createElement('span'),bs=document.createElement('i');
  nm.textContent=M.name;bl.textContent=M.blurb;bs.textContent='BOSSES · '+M.bosses.map(k=>(BOSSES[k]||{}).name||k).join(' · ').replace(/THE /g,'');
  t.append(nm,bl,bs);b.append(cv,t);b.setAttribute('aria-pressed',pick.map===id?'true':'false');b.addEventListener('click',()=>{pick.map=id;cfg.map=id;saveCfg();syncPicks();showBest()});box.append(b)}
 $('mapSizeTag').textContent=pick.size==='xl'?'24×24':'16×16';
 const C=CLASSES[pick.cls]||CLASSES.soldier,M=MAPS[pick.map]||MAPS.yard;$('soloMap').textContent=`${M.name} · ${pick.size==='xl'?'XL 24×24':'16×16'}${M.night?' · always night':''}`;
}
