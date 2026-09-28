/* Account identity and a party lobby. Saved players use the signed-in user's existing metadata. */
const SAVED_PLAYERS_KEY='palisade_saved_players_v1';
const SOCIAL={owner:null,ids:[],profiles:[],rooms:[],result:null,status:'',busy:false,loading:false,roomsOK:false,seq:0,searchSeq:0,timer:0};
const validPlayerId=v=>typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
const savedPlayerIds=user=>[...new Set((Array.isArray(user?.user_metadata?.[SAVED_PLAYERS_KEY])?user.user_metadata[SAVED_PLAYERS_KEY]:[]).filter(validPlayerId))].slice(0,50);
const socialAccount=()=>cloudOn&&acct.state==='full'&&!isGuest()&&!!myUid();
const socialVisible=()=>!$('menu').hidden&&['multi','lobby'].includes($('menu').dataset.page);
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
 const on=['multi','lobby'].includes($('menu').dataset.page);$('partyShell').hidden=!on;$('menu').classList.toggle('partyMenu',on);
 if(on){renderIdentity();renderPartyState();refreshSocial();if(!SOCIAL.timer)SOCIAL.timer=setInterval(()=>{if(socialVisible())refreshSocial();else{clearInterval(SOCIAL.timer);SOCIAL.timer=0}},15000)}
 else{clearInterval(SOCIAL.timer);SOCIAL.timer=0}
}
function partyRows(){return NET.mode==='host'||NET.mode==='guest'?NET.roster:[{id:myId,name:myName(),cls:pick.cls,cos:cosStr(locker.eq)}]}
function partyInvite(){
 if(NET.code){$('shareBtn').click();$('partyHint').textContent='Use the invite link or room code to bring your crew.'}
 else{$('partyHint').textContent='Create a room with HOST, then copy its invite link for your crew.';$('hostBtn').focus();$('hostBtn').scrollIntoView({block:'nearest'})}
}
function renderPartyState(){
 if(!$('partyShell')||$('partyShell').hidden)return;
 const room=NET.mode==='host'||NET.mode==='guest',rows=partyRows(),me=rows.find(r=>r.id===myId)||rows[0];
 $('partyMode').textContent=MODE_NAME[pick.pvp]||'CO-OP';$('partyTitle').textContent=room?'PARTY LOBBY':'YOUR CREW. YOUR CLAIM.';
 $('partySubtitle').textContent=room?`ROOM ${NET.code} · ${rows.length} / 6 PLAYERS`:'Choose your job. Bring your crew.';
 $('partyPlayerName').textContent=me?.name||myName();$('partyPlayerState').textContent=room?(NET.mode==='host'?'PARTY LEADER':'WAITING FOR HOST'):'CHOOSING A LOADOUT';
 const box=$('partySlots');box.textContent='';
 for(let i=0;i<6;i++){const r=rows[i],el=document.createElement(r?'div':'button');el.className='partySlot'+(r?' occupied':'');
  const b=document.createElement('b'),small=document.createElement('small');b.textContent=r?r.name:'+';small.textContent=r?`${r.id===myId?'YOU · ':''}${CLASSES[r.cls]?.name||'PLAYER'}`:'INVITE';el.append(b,small);
  if(!r){el.type='button';el.setAttribute('aria-label','Invite player to slot '+(i+1));el.addEventListener('click',partyInvite)}box.append(el)}
 $('partyHint').textContent=room?'Share your room link. Your host starts the match.':'Up to six players · desktop and mobile';
}
let partyPaintAt=0;
function drawPartyPreview(now){
 if(!socialVisible()||now-partyPaintAt<(touchMode?100:50))return;partyPaintAt=now;
 const cv=$('partyPreview'),x=cv.getContext('2d'),rows=partyRows(),me=rows.find(r=>r.id===myId)||rows[0],others=rows.filter(r=>r!==me);x.clearRect(0,0,cv.width,cv.height);
 const pad=(px,py,r,active)=>{cosmeticGlow(x,px,py,r*1.5,active?'#7de6e8':'#536f89',active?.15:.1);x.fillStyle=active?'rgba(170,239,239,.12)':'rgba(122,171,192,.06)';x.strokeStyle=active?'#b4edee':'#597386';x.lineWidth=active?3:2;x.beginPath();x.ellipse(px,py,r,r*.22,0,0,Math.PI*2);x.fill();x.stroke()};
 for(const [i,px]of [160,840].entries()){pad(px,625,90,!!others[i]);if(others[i])drawWardrobeCharacter(x,lookOf(parseCos(others[i].cos),others[i].cls),i?-.3:.3,now/1000,8,px,610,false);else{x.fillStyle='#7e98a5';x.font='300 60px system-ui';x.textAlign='center';x.fillText('+',px,590)}}
 pad(500,720,154,true);if(me)drawWardrobeCharacter(x,lookOf(parseCos(me.cos),me.cls),.35+Math.sin(now/4500)*.16,now/1000,13.4,500,700,false);
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
$('partyControls').append($('pg-multi'),$('pg-lobby'));
$('friendSearch').addEventListener('submit',e=>{e.preventDefault();findPlayer()});$('socialRefresh').addEventListener('click',refreshSocial);

document.querySelectorAll('[data-party-go]').forEach(b=>b.addEventListener('click',()=>showPage(b.dataset.partyGo==='play'?'multi':b.dataset.partyGo)));

// Returning from the locker updates the real party loadout before the host starts.
function syncLobbyLoadout(){
 if(NET.inGame||!['host','guest'].includes(NET.mode))return;
 const r=NET.roster.find(r=>r.id===myId);if(!r)return;
 const next={name:myName(),cls:pick.cls,cos:cosStr(myCos())};
 if(r.name===next.name&&r.cls===next.cls&&r.cos===next.cos)return;
 if(NET.mode==='host'){Object.assign(r,next);broadcastLobby()}else NET.toHost({t:'loadout',...next});
}
