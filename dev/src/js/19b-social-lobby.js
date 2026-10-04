/* Account identity and a party lobby. Saved players use the signed-in user's existing metadata. */
const SAVED_PLAYERS_KEY='palisade_saved_players_v1';
const SOCIAL={owner:null,ids:[],profiles:[],rooms:[],result:null,status:'',busy:false,loading:false,roomsOK:false,seq:0,searchSeq:0,timer:0};
const validPlayerId=v=>typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
const savedPlayerIds=user=>[...new Set((Array.isArray(user?.user_metadata?.[SAVED_PLAYERS_KEY])?user.user_metadata[SAVED_PLAYERS_KEY]:[]).filter(validPlayerId))].slice(0,50);
const socialAccount=()=>cloudOn&&acct.state==='full'&&!isGuest()&&!!myUid();
const socialVisible=()=>!$('menu').hidden&&!$('friendsDrop').hidden;
// the pages that use the lobby shell (character on stage, columns either side)
const STAGE_PAGES=['solo','classes','multi','lobby','locker'];
const CARD_PAGES=['settings','account','skills'];   // the same shell, laid out as cards instead of a stage
const stageVisible=()=>!$('menu').hidden&&STAGE_PAGES.includes($('menu').dataset.page);
const inRoom=()=>NET.mode==='host'||NET.mode==='guest';
function socialReset(){FR.accountEpoch=(FR.accountEpoch||0)+1;FR.busy=false;FR.msg='';FR.friends=[];FR.incoming=[];FR.outgoing=[];FR.notes=[];FR.invites=[];FR.invConfirm='';FR.unseen=0;FR.ok=false;FR.loaded=false;FR.rooms=[];FR.seq++;SOCIAL.owner=myUid();SOCIAL.ids=[];SOCIAL.profiles=[];SOCIAL.rooms=[];SOCIAL.result=null;SOCIAL.status='';SOCIAL.loading=false;SOCIAL.busy=false;SOCIAL.roomsOK=false;SOCIAL.seq++;SOCIAL.searchSeq++;}
function renderIdentity(){
 const b=$('identityButton');if(!b)return;
 const full=acct.state==='full'&&!isGuest(),name=acct.name||(full?'SET USERNAME':myName());
 $('identityName').textContent=name;
 const named=full&&!!acct.name;$('mName').readOnly=named;if(named)$('mName').value=acct.name.slice(0,12);else if(document.activeElement!==$('mName'))$('mName').value=cfg.name||'';
 const state=full?(locker.cloud&&locker.cloud.id===myUid()?'SIGNED IN · LOCKER SYNCED':'SIGNED IN · LOCKER SYNC PENDING'):acct.state==='wait'?'CONNECTING TO ACCOUNT':acct.state==='guest'?'GUEST · SAVE YOUR ACCOUNT':acct.state==='down'?'ACCOUNT OFFLINE':'LOCAL PROFILE';
 $('identityState').textContent=state;b.classList.toggle('signedIn',full);b.setAttribute('aria-label',name+', '+state+'. Open account');$('identityShards').textContent=String(locker.shards||0);
 const cv=$('identityAvatar'),key=cosStr(locker.eq)+'|'+pick.cls;if(cv.dataset.look!==key){cv.dataset.look=key;const x=cv.getContext('2d');x.clearRect(0,0,88,88);drawFig(x,88,88,lookOf(locker.eq,pick.cls),2.2,{x:.8,y:.3},106)}
 if(SOCIAL.owner!==myUid())socialReset();
 if(socialAccount()&&!FR.timer&&!$('menu').hidden){friendsPoll();friendsTick()}   // signed in (or switched account): start checking
 renderFriendBadge();if(socialVisible())renderSocial();
}
function syncPartyShell(){
 const pg=$('menu').dataset.page,on=STAGE_PAGES.includes(pg);$('partyShell').hidden=!on;$('menu').classList.toggle('partyMenu',on);$('menu').classList.toggle('cardMenu',CARD_PAGES.includes(pg));
 document.querySelectorAll('[data-nav]').forEach(b=>{const cur=b.dataset.nav===pg||(b.dataset.nav==='multi'&&pg==='lobby');if(cur)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current')});
 if(on){renderIdentity();renderPartyState();partyPaintAt=0;partySig='';partyMeSig='';stageLay='';partyMeBox=''}
 if(!FR.timer&&socialAccount()){friendsPoll();friendsTick()}
 if(on&&MAP_PAGES.includes(pg))renderMapPanel();
 if(typeof renderHome==='function')renderHome();
}
function partyRows(){return inRoom()?NET.roster:[{id:myId,name:myName(),cls:pick.cls,cos:cosStr(locker.eq)}]}
function partyInvite(){
 if(NET.code){$('shareBtn').click();$('partyHint').textContent='Use the invite link or room code to bring your crew.'}
 else{$('partyHint').textContent='Create a room with HOST, then copy its invite link for your crew.';$('hostBtn').focus();$('hostBtn').scrollIntoView({block:'nearest'})}
}
function renderPartyState(){
 if(!$('partyShell')||$('partyShell').hidden)return;
 {const pg=$('menu').dataset.page,m=pg==='solo'?myMods(coopMods()):pg==='lobby'?roomMods():[],el=$('partyMods'),t=m.length?'MODIFIERS · '+modNames(m).join(' · '):'';el.hidden=!t;if(el.textContent!==t)el.textContent=t}
 const room=inRoom(),rows=partyRows(),me=rows.find(r=>r.id===myId)||rows[0],pg=$('menu').dataset.page,C=CLASSES[pick.cls]||CLASSES.soldier,M=pick.mode==='blackout'?MAPS.city:MAPS[pick.map]||MAPS.yard;
 if(pg==='locker'){const eq=locker.eq,nm=(c,k)=>(COSBY[c+':'+k]||{name:k}).name;
  $('partyMode').textContent='LOCKER';$('partyTitle').textContent='YOUR KIT';$('partySubtitle').textContent=`${nm('skin',eq.skin)} · ${nm('hat',eq.hat)} · ${nm("trail",eq.trail)}${/tracer/i.test(nm("trail",eq.trail))?"":" tracer"} · ${nm('fx',eq.fx)}`;
  $('partyPlayerName').textContent=myName();$('partyPlayerState').textContent='EQUIPPED';$('partyHint').textContent='Tap an item you own to wear it.';return}
 if(pg==='solo'||pg==='classes'){
  $('partyMode').textContent=pg==='solo'?`SOLO · ${M.name}${pick.size==='xl'&&!M.city?' XL':''}`:'CLASSES';$('partyTitle').textContent=pg==='solo'?(M.city?'HOLD THE CITY.':'HOLD THE STAKE.'):C.name;
  $('partySubtitle').textContent=pg==='solo'?`${LEN_NAME[pick.mode]||'5 RAIDS'} · ${DIFF[pick.diff].name} · ${C.name}`:'Your class carries into solo and multiplayer.';
  $('partyPlayerName').textContent=myName();$('partyPlayerState').textContent=pg==='solo'?'READY':'CHOOSING A CLASS';
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
let partyPaintAt=0,partySig='',partyMeSig='',partyCharSig='',partyCharCv=null;
// The stage has two layers: the back one holds the pads and the rest of the party (repainted only when who is
// there or how they look changes), the front one holds you, turning slowly in 2° steps. Each layer is painted
// straight from the model (no sprite cache at this size) and only when its pose changes, at most 30 times a
// second; the breathing bob is a CSS transform, so it costs no painting at all.
const STAGE={wide:{me:[500,722,13.4],others:[[250,660,8.2],[762,660,8.2],[88,612,7.4],[918,612,7.4],[395,568,6.8]]},
 phone:{me:[500,712,11.6],others:[[150,700,8.2],[830,712,8.2],[292,580,6.8],[690,572,6.8],[930,522,5.8]]}};   // v0.9.2: the sixth stands off to the side, not behind you
// The Locker leaves room below the feet for glowing rings and other skin effects.
const stageMe=L=>$('menu').dataset.page==='locker'?[L.me[0],Math.min(L.me[1],780-L.me[2]*11-8),L.me[2]]:L.me;
let stageLay='',stageLayW=-1;   // read the stage width only when the window size changes (reading it every frame forces a layout)
const stageLayout=()=>{if(stageLayW!==innerWidth||!stageLay){stageLayW=innerWidth;stageLay=$('partyHero').clientWidth<520?'phone':'wide'}return stageLay};
const stageBreath=t=>reduceMotion()?0:Math.round(Math.sin(t*1.35)*4)/4;
const stageAngle=(i,t)=>i<0?.35+(reduceMotion()?0:Math.sin(t/4.5)*.09):[.62,-.62,.5,-.5,.1][i]||0;
function stagePlate(x,px,py,name,sub,scale){
 const f=Math.round(scale*2.9);x.save();x.font=`800 ${f}px 'Big Shoulders Stencil Display',sans-serif`;const w=Math.max(x.measureText(name).width,f*3.2)+f*1.1,h=f*1.9;
 x.fillStyle='#12222bd8';x.strokeStyle='#718b8f';x.lineWidth=2;x.beginPath();x.rect(px-w/2,py,w,h);x.fill();x.stroke();
 x.fillStyle='#eef3ed';x.textAlign='center';x.textBaseline='top';x.fillText(name,px,py+f*.2);
 x.font=`600 ${Math.round(f*.52)}px 'IBM Plex Mono',monospace`;x.fillStyle='#ecd347';x.fillText(sub,px,py+f*1.25);x.restore();
}
function drawPartyPreview(now){
 if(!stageVisible()||now-partyPaintAt<33)return;
 const rows=partyRows(),me=rows.find(r=>r.id===myId)||rows[0],solo=!['multi','lobby'].includes($('menu').dataset.page),t=now/1000,L=STAGE[stageLayout()];
 const others=solo?[]:rows.filter(r=>r!==me).slice(0,5),look=r=>lookOf(parseCos(r.cos),r.cls);
 // back layer: pads, the rest of the party and their name plates
 const sig=(L===STAGE.phone?'p':'w')+($('menu').dataset.page==='locker'?'l':'');const backSig=sig+'|'+solo+'|'+others.map(r=>r.id+r.cls+r.cos+r.name).join();
 if(backSig!==partySig){partySig=backSig;
  const cv=$('partyPreview'),x=cv.getContext('2d');x.clearRect(0,0,cv.width,cv.height);
  const pad=(px,py,r,active)=>{cosmeticGlow(x,px,py,r*1.5,active?'#7de6e8':'#536f89',active?.15:.1);x.fillStyle=active?'rgba(170,239,239,.12)':'rgba(122,171,192,.06)';x.strokeStyle=active?'#b4edee':'#597386';x.lineWidth=active?3:2;x.beginPath();x.ellipse(px,py,r,r*.22,0,0,Math.PI*2);x.fill();x.stroke()};
  const [mx,my,ms]=stageMe(L);pad(mx,my,ms*11.5,true);
  if(!solo){
   // empty spots show where the next player stands; filled ones are drawn back to front
   const order=L.others.map((s,i)=>({s,i})).sort((a,b)=>a.s[1]-b.s[1]);
   for(const {s:[px,py,sc],i} of order){const r=others[i];pad(px,py,sc*9.5,!!r);
    if(r){const lr=look(r);if(lr.aura)paintAura(x,lr.aura,px,py,sc,1.3,1,'ground');paintWardrobeCharacter(x,lr,stageAngle(i,0),0,sc,px,py,false);if(lr.aura)paintAura(x,lr.aura,px,py,sc,1.3,1,'top')}   // the others' outfit effects hold still
    else if(i<4){x.fillStyle='#7e98a5';x.font='300 48px system-ui';x.textAlign='center';x.fillText('+',px,py-28)}}
   for(const {s:[px,py,sc],i} of order){const r=others[i];if(r)stagePlate(x,px,py+sc*2.4,(r.name||'PLAYER').toUpperCase(),CLASSES[r.cls]?.name||'PLAYER',sig==='p'?sc*1.35:sc)}
  }
 }
 // front layer: you, turning in 2° steps; animated outfits tick at 10 a second
 if(!me)return;const lk=Object.assign(look(me),{breath:stageBreath(t)}),ang=stageAngle(-1,t),step=Math.round(ang*90/Math.PI)*Math.PI/90;
 const animated=lk.stars||lk.holo||lk.glitter||lk.halo||lk.glitchm||lk.winterHat==='aurorahalo',tick=reduceMotion()?0:animated?Math.floor(t*10)/10:lk.pking?Math.floor(t*6)%4:0;
 // v0.9.3: an outfit effect moves at 12 frames a second over a copy of the figure (the figure is only repainted when it turns)
 const aura=lk.aura&&!reduceMotion()?lk.aura:'',at=aura?Math.floor(t*12)/12:0;
 const charSig=sig+'|'+me.cls+me.cos+'|'+step.toFixed(4)+'|'+tick+'|'+lk.breath,meSig=charSig+'|'+at;
 if(meSig===partyMeSig)return;partyMeSig=meSig;partyPaintAt=now;
 const cv=$('partyMe'),x=cv.getContext('2d'),[mx,my,ms]=stageMe(L);
 // v0.9.8.2: without an aura only a generous box around the figure is cleared and repainted (wiping the whole stage-sized
 // layer on every turn step was a big part of the Locker's frame cost on slow phones)
 if(!lk.aura){const T0=x.getTransform(),k0=T0.a,qx=Math.max(0,Math.floor((mx-ms*40)*k0+T0.e)),qy=Math.max(0,Math.floor((my-4-ms*70)*k0+T0.f)),qw=Math.min(cv.width-qx,Math.ceil(ms*80*k0)),qh=Math.min(cv.height-qy,Math.ceil(ms*86*k0)),q=qx+','+qy+','+qw+','+qh;
   x.save();x.setTransform(1,0,0,1,0,0);if(partyMeBox!==q){x.clearRect(0,0,cv.width,cv.height);partyMeBox=q}else x.clearRect(qx,qy,qw,qh);x.beginPath();x.rect(qx,qy,qw,qh);x.clip();x.setTransform(T0);
   paintWardrobeCharacter(x,lk,step,tick,ms,mx,my-4,false);x.restore();return}
 partyMeBox='';   // an aura outfit draws wider: the next plain outfit starts from a full clear
 // only the box around the figure is cleared and redrawn for each frame of the effect (the whole layer only when the figure turns)
 const T=x.getTransform(),k=T.a,bx=Math.max(0,Math.floor((mx-ms*24)*k+T.e)),by=Math.max(0,Math.floor((my-4-ms*50)*k+T.f)),bw=Math.min(cv.width-bx,Math.ceil(ms*48*k)),bh=Math.min(cv.height-by,Math.ceil(ms*62*k));
 let full=false;
 if(charSig!==partyCharSig||!partyCharCv||partyCharCv.width!==cv.width||partyCharCv.height!==cv.height){partyCharSig=charSig;full=true;partyCharCv=partyCharCv||document.createElement('canvas');partyCharCv.width=cv.width;partyCharCv.height=cv.height;
   const c=partyCharCv.getContext('2d');c.setTransform(T);paintAura(c,lk.aura,mx,my-4,ms,1.3,1,'sground');paintWardrobeCharacter(c,lk,step,tick,ms,mx,my-4,false);paintAura(c,lk.aura,mx,my-4,ms,1.3,1,'stop')}
 const ta=aura?at:1.3;x.save();x.setTransform(1,0,0,1,0,0);if(full)x.clearRect(0,0,cv.width,cv.height);else x.clearRect(bx,by,bw,bh);x.restore();
 x.save();x.setTransform(1,0,0,1,0,0);if(full)x.drawImage(partyCharCv,0,0);else x.drawImage(partyCharCv,bx,by,bw,bh,bx,by,bw,bh);x.restore();
 x.save();x.beginPath();x.rect((bx-T.e)/k,(by-T.f)/k,bw/k,bh/k);x.clip();paintAura(x,lk.aura,mx,my-4,ms,ta,1,'moving');x.restore();
}
let stageFxAt=0,stageFxOn=false,partyMeBox='',stageFxBox=null;
function drawStageFx(now){
 const on=stageVisible()&&$('menu').dataset.page==='locker';
 // v0.9.8.2: only the boxes the shot covered are cleared (wiping the stage-sized layer every frame of the shot was costly on slow phones)
 const fxClear=()=>{const c=$('partyFx'),x=c.getContext('2d'),b=stageFxBox;x.save();x.setTransform(1,0,0,1,0,0);if(b)x.clearRect(b[0],b[1],b[2],b[3]);else x.clearRect(0,0,c.width,c.height);x.restore();stageFxBox=null};
 if(!on||reduceMotion()){if(stageFxOn){stageFxOn=false;fxClear()}return}
 // one quick shot every 1.3 s; between shots the layer is left alone (clearing a stage-sized layer costs as much as drawing)
 const ph=(now%1300)/1300,live=ph>.05&&ph<.4;
 if(!live){if(stageFxOn){stageFxOn=false;fxClear()}return}
 if(now-stageFxAt<33)return;stageFxAt=now;stageFxOn=true;
 const cv=$('partyFx'),x=cv.getContext('2d');fxClear();
 const L=STAGE[stageLayout()],[mx,my,ms]=stageMe(L),lk=Object.assign(lookOf(locker.eq,pick.cls),{breath:stageBreath(now/1000)}),ang=stageAngle(-1,now/1000),step=Math.round(ang*90/Math.PI)*Math.PI/90;
 const m=paintWardrobeCharacter(null,lk,step,0,1,0,0,false),tip=[mx+m.tip[0]*ms,my-4+m.tip[1]*ms],dx=m.tip[0]-m.root[0],dy=m.tip[1]-m.root[1],dl=Math.hypot(dx,dy)||1,sd={x:dx/dl,y:dy/dl};
 const st=TRAILS[locker.eq.trail]||TRAILS.std,d0=(ph-.05)/.35*560,len=90*(st.len||1);
 const ax=tip[0]+sd.x*d0,ay=tip[1]+sd.y*d0,bx=tip[0]+sd.x*Math.max(0,d0-len),by=tip[1]+sd.y*Math.max(0,d0-len),T=x.getTransform(),pad=40*(st.w||1);
 const x0=Math.max(0,Math.floor((Math.min(ax,bx)-pad)*T.a+T.e)),y0=Math.max(0,Math.floor((Math.min(ay,by)-pad)*T.d+T.f)),x1=Math.min(cv.width,Math.ceil((Math.max(ax,bx)+pad)*T.a+T.e)),y1=Math.min(cv.height,Math.ceil((Math.max(ay,by)+pad)*T.d+T.f));
 stageFxBox=[x0,y0,Math.max(0,x1-x0),Math.max(0,y1-y0)];
 x.save();x.setTransform(1,0,0,1,0,0);x.beginPath();x.rect(x0,y0,x1-x0,y1-y0);x.clip();x.setTransform(T);traceSeg(x,ax,ay,bx,by,st,8*(st.w||1),now/1000,false);x.restore();
}
function socialMessage(){return !cloudOn?'Friends are available on the live site.':acct.state==='wait'?'Connecting to your account…':!socialAccount()?'Sign in with a saved account to add friends.':SOCIAL.status}
// ---- Friends: a real request system on the server (friend_send / friend_answer / friend_cancel / friend_remove,
// social_state for everything at once). "Recent" is the old saved-players list, kept in the account's metadata.
const FR={friends:[],incoming:[],outgoing:[],notes:[],unseen:0,ok:false,loaded:false,tab:'friends',busy:false,seq:0,timer:0,rooms:[],confirm:'',confirmT:0,last:0,act:Date.now()};
// v0.9.6.3: friends checks every 15 s only while someone is actually looking at the menus. A hidden tab doesn't ask at all,
// a match or 5 idle minutes slows it to once a minute, and coming back to the tab asks straight away.
const FR_IDLE=300000,FR_SLOW=60000;
for(const ev of['pointerdown','keydown','touchstart'])addEventListener(ev,()=>{FR.act=Date.now()},{passive:true,capture:true});
document.addEventListener('visibilitychange',()=>{if(!document.hidden&&FR.timer&&socialAccount()&&Date.now()-FR.last>15000){FR.act=Date.now();friendsPoll()}});
const dropOpen=()=>!$('friendsDrop').hidden;
const ago=t=>{const s=Math.max(0,(Date.now()-Date.parse(t))/1000);return s<60?'just now':s<3600?Math.floor(s/60)+' min ago':s<86400?Math.floor(s/3600)+' h ago':Math.floor(s/86400)+' d ago'};
const friendIds=()=>FR.friends.map(f=>f.id);
const roomOf=id=>SOCIAL.rooms.find(r=>r.host_id===id)||FR.rooms.find(r=>r.host_id===id);
function personRow(profile,status,actions,cls){
 const row=document.createElement('div');row.className='friendRow'+(cls?' '+cls:'');const avatar=document.createElement('canvas');avatar.width=avatar.height=80;avatar.setAttribute('aria-hidden','true');drawFig(avatar.getContext('2d'),80,80,lookOf(parseCos(profile.cos),'soldier'),1.65,{x:.8,y:.3},82);
 const copy=document.createElement('div'),name=document.createElement('b'),st=document.createElement('small');name.textContent=profile.username||'PLAYER';st.textContent=status;copy.append(name,st);
 const box=document.createElement('div');box.className='friendActions';
 for(const [label,fn,opt] of actions){const q=document.createElement('button');q.type='button';q.textContent=label;q.disabled=SOCIAL.busy||FR.busy||!!(opt&&opt.off);if(opt&&opt.aria)q.setAttribute('aria-label',opt.aria);if(opt&&opt.title)q.title=opt.title;if(opt&&opt.main)q.className='main';q.addEventListener('click',fn);box.append(q)}
 row.append(avatar,copy,box);return row;
}
function joinAction(id,name){const room=roomOf(id);if(!room)return null;
 return [room.players>=6?'FULL':'JOIN',()=>{if(NET.mode!=='solo')return;closeFriends();$('mCode').value=room.code;initAudio();netJoin(room.code)},{main:true,off:room.players>=6||NET.mode!=='solo',title:NET.mode!=='solo'?'Leave your current party to join another':'Join '+name}]}
const roomText=id=>{const room=roomOf(id);return room?(room.in_game?'IN MATCH':'IN LOBBY')+` · ${room.players}/6`:SOCIAL.roomsOK?'NO LISTED ROOM':'ROOM STATUS UNAVAILABLE'};
function askSure(key,fn){if(FR.confirm===key){FR.confirm='';clearTimeout(FR.confirmT);fn()}else{FR.confirm=key;clearTimeout(FR.confirmT);FR.confirmT=setTimeout(()=>{FR.confirm='';renderSocial()},3000);renderSocial()}}
function socialRow(profile,result=false){
 const saved=SOCIAL.ids.includes(profile.id),friend=friendIds().includes(profile.id),sent=FR.outgoing.some(r=>r.user.id===profile.id),acts=[];
 if(result){
  if(!friend)acts.push([sent?'REQUESTED':'ADD FRIEND',()=>friendSend(profile),{main:true,off:sent||profile.id===myUid()}]);
  acts.push([saved?'SAVED':'SAVE',()=>savePlayer(profile.id,true),{off:saved||profile.id===myUid()}]);
  return personRow(profile,friend?'Already your friend':saved?'In your Recent list':'Player found',acts)}
 const j=joinAction(profile.id,profile.username);if(j)acts.push(j);
 if(!friend&&FR.ok)acts.push([sent?'REQUESTED':'ADD',()=>friendSend(profile),{off:sent,aria:'Send '+profile.username+' a friend request'}]);
 acts.push(['REMOVE',()=>savePlayer(profile.id,false),{aria:'Remove '+profile.username+' from saved players'}]);
 return personRow(profile,roomText(profile.id),acts);
}
function renderSocial(){
 const active=socialAccount();
 $('savedCount').textContent=String(active?SOCIAL.ids.length:0);$('friendName').disabled=!active||SOCIAL.busy;$('friendSearch').querySelector('button').disabled=!active||SOCIAL.busy;$('socialRefresh').disabled=!active||SOCIAL.loading||SOCIAL.busy||FR.busy;
 $('socialStatus').textContent=socialMessage()||FR.msg||'';
 renderFriendBadge();
 const result=$('friendResult');result.textContent='';if(active&&SOCIAL.result)result.append(socialRow(SOCIAL.result,true));
 const empty=(box,txt,withAcct)=>{const p=document.createElement('p');p.className='socialEmpty';p.textContent=txt;box.append(p);if(withAcct){const q=document.createElement('button');q.className='ghost';q.type='button';q.textContent='OPEN ACCOUNT';q.addEventListener('click',()=>{closeFriends();showPage('account')});box.append(q)}};
 // friends
 const fl=$('friendList');fl.textContent='';
 if(!active)empty(fl,'Your crew starts here. Sign in with a saved account, then find a player by username.',true);
 else if(!FR.loaded)empty(fl,'Loading your friends…');
 else if(!FR.ok)empty(fl,'Friends could not be loaded right now. Try Refresh.');
 else if(!FR.friends.length)empty(fl,'No friends yet. Find someone above and send a request.');
 else for(const f of FR.friends){const acts=[],j=joinAction(f.id,f.username);if(j)acts.push(j);
  if(NET.mode==='host')acts.push(['INVITE',()=>inviteFriend(f),{main:true,off:!canInviteFriend(),title:NET.roomLocked?'Unlock the room first':NET.roster.length>=6?'Room is full':'Invite to this room'}]);
  acts.push([FR.confirm==='rm'+f.id?'SURE?':'REMOVE',()=>askSure('rm'+f.id,()=>friendRemove(f)),{aria:'Remove '+f.username+' from friends'}]);fl.append(personRow(f,roomText(f.id),acts,'isFriend'))}
 // recent (saved players)
 const list=$('savedPlayers');list.textContent='';
 if(active&&SOCIAL.profiles.length)for(const p of SOCIAL.profiles)list.append(socialRow(p));
 else if(active)empty(list,SOCIAL.loading?'Loading…':SOCIAL.ids.length?'Recent players could not be loaded. Try Refresh.':'Players you save show up here.');
 // requests
 const ri=$('reqIn'),ro=$('reqOut');ri.textContent='';ro.textContent='';
 if(!active){empty(ri,'Sign in with a saved account to get friend requests.',true)}
 else{if(!FR.incoming.length)empty(ri,'No requests waiting.');
  for(const r of FR.incoming)ri.append(personRow(r.user,'Sent '+ago(r.at),[['ACCEPT',()=>friendAnswer(r,true),{main:true,aria:'Accept '+r.user.username}],['DECLINE',()=>friendAnswer(r,false),{aria:'Decline '+r.user.username}]]));
  if(!FR.outgoing.length)empty(ro,'No requests sent.');
  for(const r of FR.outgoing)ro.append(personRow(r.user,'Waiting · sent '+ago(r.at),[['CANCEL',()=>friendCancel(r),{aria:'Cancel request to '+r.user.username}]]))}
 // mailbox
 const ml=$('mailList');ml.textContent='';if(active)renderLobbyInvites(ml);
 if(!active)empty(ml,'Sign in to get your mail.',true);
 else if(!FR.notes.length&&!(FR.invites||[]).length)empty(ml,'Nothing here yet.');
 else for(const n of FR.notes){const d=document.createElement('div');d.className='mailRow'+(n.seen_at?'':' unseen');const b=document.createElement('b'),sm=document.createElement('small');
  const who=(n.user&&n.user.username)||'A player';b.textContent=n.kind==='friend_request'?`${who} sent you a friend request`:n.kind==='friend_accepted'?`${who} accepted your friend request`:(n.data&&n.data.text)||'Message';sm.textContent=ago(n.created_at);d.append(b,sm);ml.append(d)}
 document.querySelectorAll('[data-ft]').forEach(b=>b.setAttribute('aria-selected',b.dataset.ft===FR.tab?'true':'false'));document.querySelectorAll('[data-fp]').forEach(s=>s.hidden=s.dataset.fp!==FR.tab);
}
function renderFriendBadge(){
 const on=socialAccount()&&FR.ok,n=on?FR.unseen:0,req=on?FR.incoming.length:0;
 $('friendsDot').hidden=!n;$('friendsDot').textContent=n>9?'9+':String(n);$('friendsBtn').setAttribute('aria-label',n?`Friends, ${n} new`:'Friends');
 $('pFriendsBtn').textContent=n?`FRIENDS · ${n>9?'9+':n} NEW`:'FRIENDS';
 $('fdFriendsN').textContent=String(on?FR.friends.length:0);$('fdReqN').hidden=!req;$('fdReqN').textContent=String(req);$('fdMailN').hidden=!n;$('fdMailN').textContent=String(n);
}
// the friends list, requests and mailbox in one call; the friends' listed rooms in a second
async function friendsPoll(){
 if(!socialAccount()){FR.loaded=true;FR.ok=false;renderFriendBadge();if(dropOpen())renderSocial();return}
 const owner=myUid(),seq=++FR.seq;FR.last=Date.now();const r=await rpc('social_state');if(owner!==myUid()||seq!==FR.seq)return;
 FR.loaded=true;
 if(r.ok&&r.j){FR.ok=true;FR.friends=r.j.friends||[];FR.incoming=r.j.incoming||[];FR.outgoing=r.j.outgoing||[];FR.notes=r.j.notes||[];FR.invites=r.j.invites||[];FR.unseen=r.j.unseen|0;
  const ids=FR.friends.map(f=>f.id).filter(id=>!SOCIAL.ids.includes(id));
  if(ids.length){const q=await sbFetch('/rest/v1/lobbies?select=host_id,code,players,in_game&host_id=in.('+ids.join(',')+')&proto=eq.'+PROTO+'&limit=60');if(owner!==myUid()||seq!==FR.seq)return;FR.rooms=q.ok&&Array.isArray(q.j)?q.j:[];if(q.ok)SOCIAL.roomsOK=true}else FR.rooms=[];
  if(dropOpen()&&FR.tab!=='friends'&&FR.unseen)markSeen()}
 else FR.ok=false;
 renderFriendBadge();if(dropOpen())renderSocial();
}
async function markSeen(){if(!FR.unseen)return;FR.unseen=0;for(const n of FR.notes)n.seen_at=n.seen_at||new Date().toISOString();renderFriendBadge();await rpc('notes_seen',{})}
async function friendDo(fn,args,okMsg){
 if(!socialAccount()||FR.busy)return;FR.busy=true;FR.msg='';renderSocial();
 try{const r=await rpc(fn,args);FR.msg=r.ok?okMsg(r.j||{}):sbErr(r)}finally{FR.busy=false;await friendsPoll();renderSocial()}
}
const friendSend=p=>friendDo('friend_send',{p_to:p.id},j=>j.state==='friends'?`You and ${p.username} are friends now.`:`Request sent to ${p.username}.`);
const friendAnswer=(r,yes)=>friendDo('friend_answer',{p_id:r.id,p_accept:!!yes},()=>yes?`You and ${r.user.username} are friends now.`:'Request declined.');
const friendCancel=r=>friendDo('friend_cancel',{p_id:r.id},()=>'Request cancelled.');
const friendRemove=f=>friendDo('friend_remove',{p_other:f.id},()=>`${f.username} removed from friends.`);
function friendsTickRun(){
 if(!socialAccount()){clearInterval(FR.timer);FR.timer=0;return false}
 if(document.hidden)return false;const now=Date.now();if((inRun()||now-FR.act>FR_IDLE)&&!dropOpen()&&now-FR.last<FR_SLOW)return false;
 friendsPoll();if(dropOpen()&&SOCIAL.ids.length)refreshSocial();return true;
}
function friendsTick(){   // every 15 s while the menus are in use (see FR_IDLE)
 clearInterval(FR.timer);FR.timer=0;if(!socialAccount())return;
 FR.timer=setInterval(friendsTickRun,15000);
}
function openFriends(){
 if(!demo&&inRun()){document.body.append($('friendsDrop'));$('friendsDrop').classList.add('inGame')}
 $('friendsDrop').hidden=false;$('friendsBtn').setAttribute('aria-expanded','true');FR.msg='';renderSocial();refreshSocial();friendsPoll();
 if(FR.tab!=='friends')markSeen();
 const f=$('friendsDrop').querySelector('[aria-selected=true]');if(f)f.focus();
}
function closeFriends(){if(!dropOpen())return;$('friendsDrop').hidden=true;$('friendsDrop').classList.remove('inGame');$('friendsBtn').parentNode.append($('friendsDrop'));$('friendsBtn').setAttribute('aria-expanded','false');if(!$('pause').hidden&&padMode)navFocus($('pFriendsBtn'))}
$('pFriendsBtn').addEventListener('click',()=>{initAudio();openFriends()});
$('friendsClose').addEventListener('click',closeFriends);
$('friendsBtn').addEventListener('click',e=>{e.stopPropagation();initAudio();if(dropOpen())closeFriends();else openFriends()});
document.querySelectorAll('[data-ft]').forEach(b=>b.addEventListener('click',()=>{FR.tab=b.dataset.ft;FR.msg='';renderSocial();if(FR.tab!=='friends')markSeen()}));
$('friendsDrop').addEventListener('keydown',e=>{if(e.key==='Escape'){e.stopPropagation();closeFriends();$('friendsBtn').focus()}
 if((e.key==='ArrowRight'||e.key==='ArrowLeft')&&e.target.dataset&&e.target.dataset.ft){const t=['friends','requests','mail'],i=(t.indexOf(FR.tab)+(e.key==='ArrowRight'?1:2))%3;FR.tab=t[i];renderSocial();if(FR.tab!=='friends')markSeen();$('friendsDrop').querySelector(`[data-ft=${FR.tab}]`).focus()}});
document.addEventListener('pointerdown',e=>{if(dropOpen()&&!e.target.closest('.friendsWrap,.friendsDrop')&&e.target.id!=='pFriendsBtn')closeFriends()});
async function refreshSocial(){
 if(SOCIAL.owner!==myUid())socialReset();if(!socialAccount()){renderSocial();return}if(SOCIAL.loading||SOCIAL.busy)return;
 const owner=myUid(),seq=++SOCIAL.seq;SOCIAL.loading=true;renderSocial();
 const current=()=>owner===myUid()&&seq===SOCIAL.seq&&socialAccount();
 try{
  if(!await freshToken()||!current())return;
  const user=await sbFetch('/auth/v1/user');if(!current())return;
  if(!user.ok||user.j?.id!==owner){SOCIAL.status='Could not refresh your players. Try again.';SOCIAL.rooms=[];SOCIAL.roomsOK=false;return}
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
  acct.s.user=r.j;setSession(acct.s);SOCIAL.ids=ids;SOCIAL.status=add?'Player saved to Recent.':'Player removed.';if(!add)SOCIAL.profiles=SOCIAL.profiles.filter(p=>p.id!==id);else if(SOCIAL.result?.id===id&&!SOCIAL.profiles.some(p=>p.id===id))SOCIAL.profiles.push(SOCIAL.result);
 }finally{if(current()){SOCIAL.busy=false;renderSocial()}}
}
$('partyControls').append($('pg-solo'),$('pg-classes'),$('pg-multi'),$('pg-lobby'),$('pg-locker'));   // the left column of the lobby shell
$('friendSearch').addEventListener('submit',e=>{e.preventDefault();findPlayer()});$('socialRefresh').addEventListener('click',()=>{refreshSocial();friendsPoll()});


// Returning from the locker updates the real party loadout before the host starts.
function syncLobbyLoadout(){
 if(NET.inGame||!['host','guest'].includes(NET.mode))return;
 const r=NET.roster.find(r=>r.id===myId);if(!r)return;
 const next={name:myName(),cls:pick.cls,cos:cosStr(myCos()),sk:mySkills()};
 if(r.name===next.name&&r.cls===next.cls&&r.cos===next.cos&&(r.sk||'')===next.sk)return;
 if(NET.mode==='host'){Object.assign(r,next);broadcastLobby()}else NET.toHost({t:'loadout',...next});
}

// ---- PLAY: map cards (a painted thumbnail of each map), size, and the summary in the left column
const MAP_THUMBS=new Map();
function mapThumb(id,size,pvp=''){
 const key=id+'|'+size+'|'+pvp;let c=MAP_THUMBS.get(key);if(c)return c;
 c=document.createElement('canvas');c.width=172;c.height=116;const x=c.getContext('2d'),M=MAPS[id];
 // lay the map out on a scratch copy of the terrain, then draw it top-down as a tiny isometric diamond
 const keep=[terr,N,MAP,terrLog,MAPO,floodOn,floodLv,heights,connectors,frostFields];let L=null;
 try{L=layMap(id,size,pvp);const n=N,tw=172/(n+2)/1.02,th=tw*.5,ox=86,oy=6;
  x.fillStyle='#0e1519';x.fillRect(0,0,172,116);
  const col=t=>t===T_WATER?'#2a5a74':t===T_BRIDGE?'#7a5a38':t===T_LOW?'#3e4a30':t===T_CRACK?'#5a4838':t===T_ROCK?'#7c776d':t===T_DRUM?'#ff8a2a':id==='quarry'?'#403a33':id==='river'?'#394a2c':'#4a4030';
  for(let j=0;j<n;j++)for(let i=0;i<n;i++){const sx=ox+(i-j)*tw/2,sy=oy+(i+j)*th/2-(heights[j*n+i]||0)*4;x.fillStyle=id==='frost'?(connectors[j*n+i]?'#749baa':['#bcd7e4','#dceaf0','#eef7fb'][heights[j*n+i]]):col(terr[j*n+i]);x.beginPath();x.moveTo(sx,sy);x.lineTo(sx+tw/2,sy+th/2);x.lineTo(sx,sy+th);x.lineTo(sx-tw/2,sy+th/2);x.closePath();x.fill()}
  const dot=(i,j,c,r)=>{const sx=ox+(i-j)*tw/2,sy=oy+(i+j)*th/2+th/2;x.fillStyle=c;x.beginPath();x.arc(sx,sy,r,0,Math.PI*2);x.fill()};
  if(L){for(const [i,j] of L.cover||[])dot(i,j,'#b8b4aa',1.5);
  for(const nd of L.nodes||[])dot(nd.i,nd.j,nd.type===0?'#c09058':nd.type===1?'#a0533c':'#a3a9a8',1.6);
  for(const s of L.spawns||[])for(const t of s.tiles)dot(t[0],t[1],'#d65a3a',1.2);
  for(const c of L.cores||(L.core?[L.core]:[]))dot(c[0],c[1],'#e2b436',3);
  for(const t of L.pspawns||[])dot(t[0],t[1],'#6fd0e0',1.8)}
 }finally{[terr,N,MAP,terrLog,MAPO,floodOn,floodLv,heights,connectors,frostFields]=keep}
 MAP_THUMBS.set(key,c);return c;
}
// the map panel (right column) is shared by SOLO, MULTIPLAYER and the room. PvP is always 16×16, so it hides the size;
// in a room only the host picks, and guests see the host's choice.
const MAP_PAGES=['solo','multi','lobby'];
const mapPvp=()=>{const pg=$('menu').dataset.page;return (pg==='multi'||pg==='lobby')&&pick.pvp!=='coop'?pick.pvp:''};
function pickMap(id){if(NET.mode==='guest'||!MAPS[id])return;pick.map=id;cfg.map=id;saveCfg();syncPicks();showBest();if(NET.mode==='host')broadcastLobby()}
function renderMapPanel(){
 const box=$('mapCards');if(!box)return;const pv=mapPvp(),guest=NET.mode==='guest',size=pv?'std':pick.size;
 const ids=MAP_IDS.filter(id=>!pv||id!=='frost'),key=[pick.map,size,pv,guest,pick.mode].join();if(box.dataset.key!==key||box.children.length!==ids.length){box.dataset.key=key;box.textContent='';
 for(const id of ids){const M=MAPS[id],b=document.createElement('button');b.type='button';b.className='mapCard'+(pick.map===id?' sel':'');b.dataset.map=id;b.dataset.mmap=id;
  const cv=document.createElement('canvas');cv.width=172;cv.height=116;cv.getContext('2d').drawImage(mapThumb(id,size,pv),0,0);
  const t=document.createElement('div'),nm=document.createElement('b'),bl=document.createElement('span'),bs=document.createElement('i');
  nm.textContent=M.name;bl.textContent=pv?((M.pvpBlurb||{})[pv]||M.blurb):M.blurb;bs.textContent=pv?(pv==='base'?'BASE BATTLE LAYOUT':'FREE-FOR-ALL ARENA'):'BOSSES · '+M.bosses.map(k=>(BOSSES[k]||{}).name||k).join(' · ').replace(/THE /g,'');
  t.append(nm,bl,bs);b.append(cv,t);b.setAttribute('aria-pressed',pick.map===id?'true':'false');b.disabled=(pick.mode==='campaign'||pick.mode==='blackout')&&!pv||guest&&pick.map!==id;b.addEventListener('click',()=>pickMap(id));box.append(b)}}
 $('mapSizeTag').textContent=size==='xl'?'24×24':'16×16';$('sizeBox').hidden=!!pv;$('pvpSizeNote').hidden=!pv;$('mapHostNote').hidden=!guest;
 document.querySelectorAll('#sizeSeg button').forEach(b=>b.disabled=guest);
 if(typeof renderHome==='function')renderHome();   // v0.9.5: the PLAY lines show the map
}
const renderPlayPanel=renderMapPanel;


/* ---- v0.9.2: modifiers. The host picks them on the SOLO page or in the room; guests see the host's picks. ---- */
// saved per mode (cfg.mods = {coop:[…], base:[…], ffa:[…]}); only the ones that work in that mode are ever used
const myMods=m=>pick.mode==='campaign'&&(m==='coop'||m==='campaign')?campaignMods(cleanMods((cfg.mods||{})[m],'')):cleanMods((cfg.mods||{})[m],m==='coop'?'':m);
const SETUP={kind:'home'};   // v0.9.5: which match the setup sheet is changing: 'home' (PLAY), 'host' (before hosting) or 'room'
const roomKind=()=>pick.pvp==='base'||pick.pvp==='ffa'?pick.pvp:coopMods();   // v0.9.4.0: Blitzkrieg Rush has its own list
const roomMods=()=>NET.mode==='guest'?(NET.hostMods||[]):myMods(roomKind());
function toggleMod(m,id){
  if(NET.mode==='guest')return;const all=Object.assign({coop:[],blitz:[],base:[],ffa:[]},cfg.mods||{}),cur=new Set(all[m]||[]);
  if(cur.has(id))cur.delete(id);else cur.add(id);all[m]=cleanMods([...cur],m==='coop'?'':m);cfg.mods=all;saveCfg();
  renderMods();showBest();if(NET.mode==='host')broadcastLobby();renderPartyState();
}
const modPct=list=>{const b=modBonus(list,coopMods()==='blitz'?'blitz':'');return b?`REWARDS ${b>0?'+':''}${b}%`:''};
function modBox(box,m,on,edit){
  const key=m+'|'+on.join()+'|'+edit+'|'+pick.mode;if(box.dataset.key===key)return;box.dataset.key=key;box.textContent='';
  for(const M of MODS){if(!M.modes.includes(m)||pick.mode==='campaign'&&!campaignMods([M.id]).length)continue;const sel=on.includes(M.id);if(!edit&&!sel)continue;
    const b=document.createElement('button');b.type='button';b.className='modChip'+(sel?' sel':'');b.dataset.mod=M.id;b.setAttribute('aria-pressed',sel?'true':'false');b.disabled=!edit;
    const n=document.createElement('b');n.textContent=M.name;const w=document.createElement('span');w.textContent=M.what;b.append(n,w);
    if((m==='coop'||m==='blitz')&&M.bonus){const r=document.createElement('i');r.textContent=(M.bonus>0?'+':'')+M.bonus+'%';r.className=M.bonus>0?'up':'down';b.append(r)}
    if(edit)b.addEventListener('click',()=>{initAudio();toggleMod(m,M.id)});box.append(b)}
  if(!box.children.length){const p=document.createElement('p');p.className='lede sm';p.textContent=edit?'No modifiers for this mode.':'No modifiers. The host picks them.';box.append(p)}
}
function renderMods(){
  if($('soloMods')){const k=!$('setupSheet').hidden&&SETUP.kind!=='home'?roomKind():coopMods(),on=myMods(k);modBox($('soloMods'),k,on,true);$('soloModTag').textContent=on.length?`${on.length} ON${modPct(on)?' · '+modPct(on):''}`:''}
  if($('lMods')){const m=roomKind(),on=roomMods(),host=NET.mode!=='guest';modBox($('lMods'),m,on,host);
    $('lModTag').textContent=on.length?`${on.length} ON${(m==='coop'||m==='blitz')&&modPct(on)?' · '+modPct(on):''}`:'';
    const oj=on.includes('onejob');$('lOneJob').hidden=!oj;$('lJobs').classList.toggle('locked',oj);
    document.querySelectorAll('[data-oj]').forEach(b=>{b.classList.toggle('sel',b.dataset.oj===pick.job);b.disabled=!host})}
  if(typeof renderHome==='function')renderHome();
}
function modsToast(){if(game.mods&&game.mods.length)toast('MODIFIERS',modNames(game.mods).join(' · ')+(game.job?` · everyone is a ${CLASSES[game.job].name.toLowerCase()}`:''))}

/* ---- v0.9.2: the skill tree page ---- */
function skillMsg(t){$('skMsg').textContent=t||''}
function renderSkills(){
  const box=$('skTree');if(!box)return;const L=locker,acc=!!L.cloud,t=L.skills||{},spent=skillSpent(t);
  $('skPts').textContent=acc?String(L.sp|0):'–';
  $('skLede').textContent=!acc?(cloudOn?'Skill points are kept on your account. Sign in, or play as a guest, to start earning them.':'Skill points are kept on your account, on the live site.')
    :`1 point for every 5 raids you hold (${5-(L.spProg|0)} more to the next one), and 1 for every boss that goes down. ${spent} spent, ${L.spTotal|0} earned in all.`;
  $('skReset').disabled=!acc||skillBusy||!spent||L.shards<RESPEC_COST;if(!skSure)$('skReset').textContent=`RESET TREE · ${RESPEC_COST} SHARDS`;
  const br=[...new Set(SKILLS.map(S=>S.br))];box.textContent='';
  for(const name of br){const card=document.createElement('div');card.className='setCard skBranch';const h=document.createElement('h3');h.textContent=name;card.append(h);
    for(const S of SKILLS.filter(x=>x.br===name)){const lv=t[S.id]|0,row=document.createElement('div');row.className='skRow'+(lv?' on':'');
      const nm=document.createElement('b');nm.textContent=S.name;const w=document.createElement('i');w.textContent=S.what+(S.cls?'':(S.id==='revive'?' (co-op)':''))+(S.gate&&lv<S.max?` Next tier: ${S.gate[lv]} lifetime SP earned, ${S.cost[lv]} SP to buy.`:'');
      const pips=document.createElement('div');pips.className='pips';for(let n=0;n<S.max;n++){const sp=document.createElement('span');if(n<lv)sp.className='on';pips.append(sp)}
      const btn=document.createElement('button');btn.type='button';btn.dataset.sk=S.id;const locked=S.req&&(t[S.req[0]]|0)<S.req[1],gate=S.gate&&S.gate[lv],gated=gate&&(L.spTotal|0)<gate;
      if(lv>=S.max){btn.textContent='MAXED';btn.disabled=true}
      else{const c=S.cost[lv];btn.textContent=locked?`NEEDS ${SKILLBY[S.req[0]].name}`:gated?`NEEDS ${gate} EARNED`:`${c} PT${c>1?'S':''}`;btn.disabled=!acc||skillBusy||locked||gated||(L.sp|0)<c}
      btn.setAttribute('aria-label',`${S.name}, level ${lv} of ${S.max}. ${btn.textContent}`);btn.addEventListener('click',()=>{initAudio();skillBuy(S.id)});
      row.append(nm,btn,pips,w);
      if(S.id==='molotov'&&lv){const tg=document.createElement('label');tg.className='tog';const cb=document.createElement('input');cb.type='checkbox';cb.id='skMolotov';cb.checked=!cfg.molOff;
        cb.addEventListener('change',()=>{cfg.molOff=!cb.checked;saveCfg();syncLobbyLoadout()});const sp=document.createElement('span');sp.textContent='Throw Molotovs';tg.append(cb,sp);row.append(tg)}
      card.append(row)}
    box.append(card)}
}
let skSure=0;   // resetting asks once more first
$('skReset').addEventListener('click',()=>{initAudio();if(skSure){clearTimeout(skSure);skSure=0;skillRespec();return}
  skSure=setTimeout(()=>{skSure=0;renderSkills()},3000);$('skReset').textContent='TAP AGAIN TO RESET';skillMsg(`Every point comes back; it costs ${RESPEC_COST} shards.`)});
