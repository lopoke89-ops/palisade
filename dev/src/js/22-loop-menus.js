/* ================= loop & menus ================= */
let last=performance.now(),fpsN=0,fpsT=0;
// v0.9.3.6 frame rate. 30 halves the drawing work (the biggest source of phone heat); 60 also stops 90/120 Hz
// phones drawing twice as often as needed. Auto: 60 on phones, dropping to 30 for the rest of the run when the
// phone is struggling or its battery is low and not charging; uncapped on desktops. The simulation, snapshots and
// input metering are all time-based, so a capped phone plays the same, just with fewer pictures.
const FPS_AUTO={drop:false,work:0,n:0,t:0},COARSE=(()=>{try{return matchMedia('(pointer:coarse)').matches}catch(e){return false}})();
let fpsDrawn=0,lowBattery=false;
try{navigator.getBattery().then(b=>{const f=()=>{lowBattery=!b.charging&&b.level<=.3};f();b.addEventListener('levelchange',f);b.addEventListener('chargingchange',f)}).catch(()=>{})}catch(e){}
function fpsCap(){
  const m=cfg.fpsMode;if(m==='30')return 30;if(m==='60')return 60;
  // v0.9.6.3: desktop Auto holds 60 too; uncapped, a 144 or 240 Hz monitor ran the whole game 2.4-4x as often for no visible gain
  if(!COARSE&&!touchMode)return 60;
  return FPS_AUTO.drop||lowBattery?30:60;
}
// Auto watches how long each frame's own work takes during play; a phone averaging over 12 ms can't hold 60 cool.
function fpsWatch(work,now){
  if(cfg.fpsMode!=='auto'||!playing()){FPS_AUTO.drop=false;FPS_AUTO.n=0;FPS_AUTO.work=0;FPS_AUTO.t=now;return}
  FPS_AUTO.work+=work;FPS_AUTO.n++;
  if(now-FPS_AUTO.t>=4000){if(FPS_AUTO.n>20&&FPS_AUTO.work/FPS_AUTO.n>12)FPS_AUTO.drop=true;FPS_AUTO.work=0;FPS_AUTO.n=0;FPS_AUTO.t=now}
}
function frame(now){
  const cap=fpsCap();
  if(cap){const iv=1000/cap,e=now-fpsDrawn;if(e<iv-1.5){requestAnimationFrame(frame);return}fpsDrawn=e>=iv&&e<iv*3?now-e%iv:now}else fpsDrawn=now;
  const t0=performance.now();
  const dt=Math.min(.05,(now-last)/1000);last=now;
  padTick(now);controlLocal(dt);
  // the menu always shows a background image, so the demo game behind it is neither run nor drawn
  const menuUp=!$('menu').hidden,bgUp=menuUp&&demo&&!$('lobbyBg').hidden;
  const every=demo&&menuUp?($('menu').classList.contains('sub')||!$('caseOv').hidden?1/12:DESK?0:1/30):0;
  demoAcc+=dt;const skip=every>0&&demoAcc<every,sdt=every?Math.min(.1,demoAcc):dt;if(!skip)demoAcc=0;
  if(NET.mode==='guest'&&NET.inGame){updateParticles(dt);if(running())guestUpdate(dt)}
  else{if(!skip&&!bgUp)update(sdt);if(NET.mode==='host')hostNet(dt);else if(NET.mode==='guest')lobbyNet(dt)}
  if(!caseIntroOn){drawPartyPreview(now);drawStageFx(now);if(bgUp)drawLobbyBg(now)}   // behind the blurred case intro nothing moves, so the blur is worked out once
  const wantCursor=playing()&&!touchMode&&!overlayOpen()?'none':'';if(cv.style.cursor!==wantCursor)cv.style.cursor=wantCursor;
  if(!skip&&!bgUp)render(sdt);musicTick();
  if(demo&&game.phase==='over'){demoT+=dt;if(demoT>4)startDemo()}
  const on=playing();
  if(on&&!game.paused)hud(dt);else if(toastT>0&&!game.paused){toastT-=dt;if(toastT<=0)$('toast').classList.remove('on')}
  hid($('top'),!on);hid($('kit'),!on);if(!on)hid($('respawnJobs'),true);hid($('chat'),!on||NET.mode==='solo');hid($('chatBtn'),NET.mode==='solo');if(!on&&chatOpen())closeChat();hid($('keys'),touchMode||!on);cls(document.body,'desk',!touchMode);hid($('tip'),!on||!$('tipText').textContent);
  fpsN++;fpsT+=now-(frame.prev||now);frame.prev=now;
  if(fpsT>=1000){if(cfg.fps)$('fpsLab').textContent=Math.round(fpsN*1000/fpsT)+' FPS'+(cap?' / '+cap:'');fpsN=0;fpsT=0}
  if(on&&now-(frame.draftT||0)>3000){frame.draftT=now;saveRunDraft()}   // v0.9.3.6: a crash or killed app still pays the run
  fpsWatch(performance.now()-t0,now);
  requestAnimationFrame(frame);
}
function startDemo(){
  const keep=[pick.diff,pick.mode,pick.map,pick.size,myId];pick.diff='easy';pick.mode='5';pick.map='yard';pick.size='std';myId='demo';   // the menu's live yard is always the Yard
  try{newGame([{id:'demo',name:'',cls:'soldier'}],'')}finally{[pick.diff,pick.mode,pick.map,pick.size,myId]=keep}
  demo=true;demoT=0;game.timer=6;
  player.alive=false;player.downed=false;player.rt=1e9;player.x=-3;player.y=-3;
  setTip('');$('toast').classList.remove('on');
}
// 'main' is the PLAY page now (the lobby with your character on stage); old callers still say 'main'
const PAGES=['solo','classes','multi','lobby','locker','skills','settings','account'];
function showPage(p){
  $('setupSheet').hidden=true;   // v0.9.5: leaving a page closes the match setup
  if(p==='main')p='solo';
  if((p==='multi'||p==='solo')&&(NET.mode==='host'||NET.mode==='guest')&&!NET.inGame)p='lobby';   // in a room, PLAY and MULTIPLAYER both mean the room
  if(p==='multi'&&window.PEER_SRC){needPeer();getIce()}   // warm up online play while they pick a name
  closeFriends();for(const id of PAGES)$('pg-'+id).hidden=id!==p;
  $('menu').classList.toggle('sub',p!=='solo');$('menu').dataset.page=p;if(p==='lobby')syncLobbyLoadout();syncPartyShell();
  if(p==='solo')showBest();
  syncBg();
  if(p==='multi'){syncPicks();$('mList').checked=cfg.listGame!==false;$('mListRow').hidden=!cloudOn}
  lobbyBrowse(p==='multi');
  if(p==='locker')renderLocker();
  if(p==='skills')renderSkills();
  if(p==='solo'||p==='lobby')renderMods();
  if(p==='solo'&&lockerNote){$('saveNote').textContent=lockerNote;$('saveNote').hidden=false}
  if(p==='solo')mainLabels();
  if(p==='account'){if(acct.state!=='wait'&&!acct.busy&&!acct.recovery)acct.msg=acct.hashMsg?acct.msg:'';renderAcct();acctResume()}
  if(p==='locker')lockMsg('');
  $('menu').querySelector('.panel').scrollTop=0;$('partyControls').scrollTop=0;
}
// v0.9.3.7: during a run, SETTINGS opens an overlay over the game instead of the main menu (the menu could start a new
// match or host a lobby while this one kept going). The setting cards move into the overlay and back, so every
// control keeps its one id and handler. Save backup stays on the menu page: importing a save mid-run makes no sense.
const inRun=()=>!demo&&running()&&game.phase!=='over';
function openSettings(fromPause){if(fromPause&&inRun()){openGameSettings();return}$('menu').hidden=false;$('pause').hidden=true;showPage('settings')}
function closeSettings(){showPage('main')}
function openGameSettings(){
  const box=$('igCards');for(const c of[...document.querySelectorAll('#pg-settings .cards > .setCard')])if(c.id!=='saveSet')box.append(c);
  $('igSetNote').textContent=NET.mode==='solo'?'The game is paused.':'The raid keeps going for everyone else while you change settings.';
  $('pause').hidden=true;$('igSet').hidden=false;applyCfg();if(typeof renderPadSet==='function')renderPadSet();
  const f=$('igSet').querySelector('#fpsSeg .sel')||$('igDone');try{f.focus({preventScroll:true})}catch(e){}
}
function closeGameSettings(back=true){
  if($('igSet').hidden)return;const home=$('pg-settings').querySelector('.cards'),save=$('saveSet');
  for(const c of[...$('igCards').children])home.insertBefore(c,save);$('igSet').hidden=true;
  if(back&&inRun()){$('pause').hidden=false;try{$('pSetBtn').focus({preventScroll:true})}catch(e){}}
}
$('qmCommand').addEventListener('click',()=>setQMMode(qm.mode==='defend'?'follow':'defend'));
for(const b of document.querySelectorAll('[data-qm]'))b.addEventListener('click',()=>setQMMode(b.dataset.qm));
$('igDone').addEventListener('click',()=>closeGameSettings());
function applyCfg(){
  if(master)master.gain.value=.55*cfg.volume;
  $('sVol').value=Math.round(cfg.volume*100);$('sVolV').textContent=Math.round(cfg.volume*100)+'%';
  $('sMus').value=Math.round(cfg.music*100);$('sMusV').textContent=Math.round(cfg.music*100)+'%';
  $('sShake').value=Math.round(cfg.shake*100);$('sShakeV').textContent=Math.round(cfg.shake*100)+'%';
  $('sHap').checked=cfg.haptics;$('sFps').checked=cfg.fps;$('fpsLab').hidden=!cfg.fps;$('sTips').checked=cfg.tips!==false;
  if(!['auto','30','60'].includes(cfg.fpsMode))cfg.fpsMode='auto';
  for(const b of document.querySelectorAll('#fpsSeg [data-fpsm]')){const on=b.dataset.fpsm===cfg.fpsMode;b.classList.toggle('sel',on);b.setAttribute('aria-checked',String(on))}
  $('mName').value=cfg.name||'';
}
$('sVol').addEventListener('input',e=>{cfg.volume=e.target.value/100;applyCfg();saveCfg()});
$('sMus').addEventListener('input',e=>{cfg.music=e.target.value/100;applyCfg();saveCfg()});
$('sShake').addEventListener('input',e=>{cfg.shake=e.target.value/100;applyCfg();saveCfg()});
$('sHap').addEventListener('change',e=>{cfg.haptics=e.target.checked;saveCfg();if(cfg.haptics)buzz(30)});
$('sFps').addEventListener('change',e=>{cfg.fps=e.target.checked;applyCfg();saveCfg()});
$('sTips').addEventListener('change',e=>{cfg.tips=e.target.checked;saveCfg();if(!cfg.tips)setTip('')});
for(const b of document.querySelectorAll('#fpsSeg [data-fpsm]'))b.addEventListener('click',()=>{cfg.fpsMode=b.dataset.fpsm;FPS_AUTO.drop=false;applyCfg();saveCfg()});
$('mName').addEventListener('input',e=>{cfg.name=e.target.value.slice(0,12);saveCfg();renderPartyState();renderIdentity()});
$('mList').addEventListener('change',e=>{cfg.listGame=e.target.checked;saveCfg()});
$('sDone').addEventListener('click',closeSettings);
$('sExport').addEventListener('click',()=>openSaveOv('export'));
$('sImport').addEventListener('click',()=>openSaveOv('import'));
$('saveClose').addEventListener('click',closeSaveOv);
$('saveCopy').addEventListener('click',()=>{const ta=$('saveText'),done=()=>{$('saveMsg').textContent='Copied. Paste it somewhere safe.'};
  if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(ta.value).then(done,()=>{ta.select();try{document.execCommand('copy');done()}catch(e){$('saveMsg').textContent='Select the code and copy it.'}});
  else{ta.select();try{document.execCommand('copy');done()}catch(e){$('saveMsg').textContent='Select the code and copy it.'}}});
$('saveDl').addEventListener('click',()=>{const a=document.createElement('a'),url=URL.createObjectURL(new Blob([$('saveText').value+'\n'],{type:'text/plain'}));
  a.href=url;a.download=saveFileName();document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),4000);$('saveMsg').textContent='Saved as '+saveFileName()+'.'});
$('saveCheck').addEventListener('click',()=>checkImport($('saveText').value));
$('saveText').addEventListener('input',()=>{if(saveMode==='import'){$('saveConfirm').hidden=true;savePending=null}});
$('saveFileBtn').addEventListener('click',()=>$('saveFile').click());
$('saveFile').addEventListener('change',e=>{const f=e.target.files&&e.target.files[0];e.target.value='';if(!f)return;
  if(f.size>200000){$('saveMsg').textContent='That file is too big to be a save.';return}
  f.text().then(t=>{$('saveText').value=t.trim();checkImport(t)},()=>{$('saveMsg').textContent='Could not read that file.'})});
$('saveConfirm').addEventListener('click',()=>{if(!savePending)return;
  if(locker.cloud){const d=savePending;savePending=null;$('saveConfirm').hidden=true;$('saveMsg').textContent='Bringing it into your account…';
    rpc('import_local_save',{p_save:d.locker}).then(r=>{
      if(r.ok){takeLocker(r.j);restoreExtras(d);$('saveMsg').textContent='Added to your account. Items, cases and shards from the code are merged in.';sfx('restock',undefined,undefined,true)}
      else $('saveMsg').textContent=!r.status?'Bringing a save into your account needs a connection.':/already/.test(sbErr(r))?'This account already took in a save once. Your locker is kept on your account now, so a save code isn\'t needed.':sbErr(r)});return}
  restoreSave(savePending);savePending=null;$('saveConfirm').hidden=true;
  $('saveMsg').textContent='Restored. Your locker is back.';sfx('restock',undefined,undefined,true);showPage('settings')});
document.querySelectorAll('[data-go]').forEach(b=>b.addEventListener('click',()=>{initAudio();if(NET.mode==='opening'||NET.mode==='joining'){netReset();mStatus('')}if(b.dataset.go==='settings')openSettings(false);else showPage(b.dataset.go)}));
addEventListener('keydown',e=>{if(e.key==='Escape'&&e.target&&e.target.tagName==='INPUT'){e.target.blur();return}if(e.key==='Escape'&&!$('caseOv').hidden){closeCaseOpening();return}if(e.key==='Escape'&&!$('saveOv').hidden){closeSaveOv();return}if(e.key==='Escape'&&!$('armory').hidden){closeArmory();return}if(e.key==='Escape'&&dropOpen()){closeFriends();return}if(e.key==='Escape'&&!$('menu').hidden){if(!$('pg-settings').hidden)closeSettings();else if(!$('pg-lobby').hidden)netLeave('');else showPage('main')}});
function enterGame(){if(caseSession)closeCaseOpening();closeGameSettings(false);$('menu').hidden=true;$('lobbyBg').hidden=true;$('over').hidden=true;$('pause').hidden=true;$('deadEnd').hidden=true;$('armory').hidden=true;$('caseOv').hidden=true;game.paused=false;freeSticks();hud(0)}
// the Butcher wears his pumpkin look through October (the host's clock decides for everyone)
const isOctober=()=>new URLSearchParams(location.search).has('oct')||new Date().getMonth()===9;
function start(){if(inRun()&&$('menu').hidden)return;initAudio();netReset();demo=false;pick.oct=isOctober();newGame(null,'',{mods:myMods(coopMods())});enterGame();modsToast()}
function again(){if(NET.mode==='host')startOnline();else start()}
function leaveRun(){
  if(demo||!running()||game.pvp||game.phase==='over'||game.rewarded||!player)return;
  const held=game.phase==='build'?game.wave:Math.max(0,game.wave-1);
  if(held<=(game.joinHeld|0)&&(game.bossLog||[]).length<=(game.joinBoss|0)&&(game.sbN|0)<=(game.joinSB|0)&&(game.fbLog||[]).length<=(game.joinFB|0)&&!blitzResult(player))return;   // nothing new since this phone came in
  game.rewarded=true;const t=lockerReward(held,false,player.kills|0,true);if(t&&!locker.cloud)toast('RUN SAVED',t.text);
}
function toMenu(){closeGameSettings(false);leaveRun();game.paused=false;NET.inGame=false;$('pause').hidden=true;$('over').hidden=true;$('deadEnd').hidden=true;$('armory').hidden=true;$('menu').hidden=false;startDemo();showPage('main')}
function abandon(){if(NET.mode!=='solo')netLeave('');else toMenu()}
// class + threat pickers exist on the Solo and Multiplayer pages; keep them in step
function syncPicks(){
  document.querySelectorAll('[data-c]').forEach(x=>x.classList.toggle('sel',x.dataset.c===pick.cls));
  renderSetupJobs();   // v0.9.6.4: the class cards follow the pick (they were redrawn before it changed and showed the last class)
  document.querySelectorAll('[data-mc],[data-lc]').forEach(x=>x.classList.toggle('sel',(x.dataset.mc||x.dataset.lc)===pick.cls));
  document.querySelectorAll('#diff button,[data-md]').forEach(x=>x.classList.toggle('sel',(x.dataset.d||x.dataset.md)===pick.diff));
  document.querySelectorAll('[data-m5],[data-mm]').forEach(x=>x.classList.toggle('sel',(x.dataset.m5||x.dataset.mm)===pick.mode));
  document.querySelectorAll('[data-pv]').forEach(x=>x.classList.toggle('sel',x.dataset.pv===pick.pvp));
  $('coopOpts').hidden=pick.pvp!=='coop';document.querySelectorAll('.blitzNote').forEach(x=>x.hidden=pick.mode!=='blitz');
  document.querySelectorAll('[data-size]').forEach(x=>x.classList.toggle('sel',x.dataset.size===pick.size));
  if(MAP_PAGES.includes($('menu').dataset.page))renderMapPanel();
  renderPartyState();
  $('pvDesc').textContent={coop:'Everyone against the raiders, with Delgado. Pick how long and how hard.',
    base:`Two crews, two stakes. ${PVP.truce} seconds of truce to gather and wall in, then knock down theirs. Kills pay salvage for the armory. No raiders, no Delgado.`,
    ffa:`Everyone for themselves in a designed arena whose cover can't be broken. First to ${PVP.ffaGoal} drops, or the most after ${PVP.ffaTime/60} minutes. No building.`}[pick.pvp]||'';
  if(typeof renderHome==='function')renderHome();
}
document.querySelectorAll('[data-pv]').forEach(b=>b.addEventListener('click',()=>{pick.pvp=b.dataset.pv;syncPicks()}));   // the mode is chosen before hosting; the room keeps it
document.querySelectorAll('[data-m5]').forEach(b=>b.addEventListener('click',()=>{pick.mode=b.dataset.m5;syncPicks();renderMods();showBest()}));
document.querySelectorAll('[data-mm]').forEach(b=>b.addEventListener('click',()=>{pick.mode=b.dataset.mm;syncPicks();renderMods()}));
document.querySelectorAll('[data-size]').forEach(b=>b.addEventListener('click',()=>{if(NET.mode==='guest')return;pick.size=b.dataset.size==='xl'?'xl':'std';cfg.size=pick.size;saveCfg();syncPicks();showBest();if(NET.mode==='host')broadcastLobby()}));
document.querySelectorAll('[data-c]').forEach(b=>b.addEventListener('click',()=>{pick.cls=b.dataset.c;syncPicks()}));
document.querySelectorAll('[data-mc]').forEach(b=>b.addEventListener('click',()=>{pick.cls=b.dataset.mc;syncPicks()}));
// in the room: a job change goes to the host as the usual loadout message, so everyone sees it before the start
document.querySelectorAll('[data-lc]').forEach(b=>b.addEventListener('click',()=>{if(NET.inGame)return;pick.cls=b.dataset.lc;cfg.cls=pick.cls;syncPicks();syncLobbyLoadout();renderLobby()}));
// Free-for-all: the job for your next life (the host applies it when you respawn)
function nextJob(cls){
  if(!CLASSES[cls]||!player||game.pvp!=='ffa')return;pick.cls=cls;
  if(NET.mode==='guest')NET.toHost({t:'nextcls',cls});else player.nextCls=cls===player.cls?'':cls;
  player.nextShow=cls;syncJobPick();
}
function syncJobPick(){const want=player&&(player.nextShow||player.nextCls||player.cls);document.querySelectorAll('[data-nc]').forEach(x=>x.classList.toggle('sel',x.dataset.nc===want))}
document.querySelectorAll('[data-nc]').forEach(b=>b.addEventListener('click',()=>{initAudio();nextJob(b.dataset.nc)}));
document.querySelectorAll('#diff button').forEach(b=>b.addEventListener('click',()=>{pick.diff=b.dataset.d;syncPicks();showBest()}));
document.querySelectorAll('[data-md]').forEach(b=>b.addEventListener('click',()=>{pick.diff=b.dataset.md;syncPicks()}));
$('startBtn').addEventListener('click',start);$('againBtn').addEventListener('click',again);$('menuBtn').addEventListener('click',abandon);
$('resumeBtn').addEventListener('click',togglePause);$('quitBtn').addEventListener('click',abandon);
$('pSetBtn').addEventListener('click',()=>openSettings(true));
$('hostBtn').addEventListener('click',()=>{initAudio();if(NET.mode==='solo')netHost()});
$('joinBtn').addEventListener('click',()=>{initAudio();if(NET.mode==='solo')netJoin($('mCode').value)});
$('mCode').addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();$('joinBtn').click()}});
$('lStart').addEventListener('click',()=>{initAudio();startOnline()});
$('lLock').addEventListener('click',()=>{if(NET.mode!=='host')return;NET.roomLocked=!NET.roomLocked;broadcastLobby()});
document.querySelectorAll('[data-oj]').forEach(b=>b.addEventListener('click',()=>{if(NET.mode==='guest')return;pick.job=b.dataset.oj;cfg.job=pick.job;saveCfg();renderMods();if(NET.mode==='host')broadcastLobby()}));
$('lLeave').addEventListener('click',()=>netLeave(''));
$('shareBtn').addEventListener('click',()=>{
  const url=location.origin+location.pathname+'?room='+NET.code,text=`Join my PALISADE crew. Room ${NET.code}.`;
  if(navigator.share)navigator.share({title:'PALISADE',text,url}).catch(()=>{});
  else if(navigator.clipboard)navigator.clipboard.writeText(url).then(()=>{$('lNote').textContent='Invite link copied. Paste it to your crew.'},()=>{$('lNote').textContent=url});
  else $('lNote').textContent=url;
});
function showLobby(){$('menu').hidden=false;showPage('lobby');renderLobby()}
function crewRow(r,label){
  const li=document.createElement('li');li.textContent=label||r.name.toUpperCase()+' · '+(CLASSES[r.cls]?.name||'PLAYER');
  if(NET.mode==='host'&&r.id!=='host'){
    const b=document.createElement('button');b.type='button';b.className='ghost crewKick';b.textContent='REMOVE';b.setAttribute('aria-label','Remove '+r.name+' from room');b.addEventListener('click',()=>hostKick(r.id));li.append(b);
  }
  return li;
}
function renderPauseCrew(){
  const el=$('pauseCrew');el.hidden=NET.mode!=='host'||!NET.inGame;
  if(el.hidden)return;const ul=$('pauseCrewList');ul.textContent='';for(const r of NET.roster)ul.append(crewRow(r));
}
function renderLobby(){
  renderPartyState();if(!$('pg-lobby').hidden)renderMapPanel();
  $('lCode').textContent=NET.code||'····';
  const ul=$('lList');ul.textContent='';
  const base=pick.pvp==='base',host=NET.mode==='host';
  for(const r of NET.roster){const tm=TEAMS[r.team]||TEAMS.a,li=crewRow(r,`${r.name.toUpperCase()} · ${CLASSES[r.cls].name}${base?' · '+tm.name:''}${r.id==='host'?' · HOST':''}${r.id===myId?' · YOU':''}`);
    if(base)li.style.borderLeftColor=tm.col;else if(pick.pvp==='ffa')li.style.borderLeftColor='#e0664a';ul.append(li)}
  if(pick.pvp==='coop'){const dl=document.createElement('li');dl.className='ai';dl.textContent='DELGADO · SUPPLY RUNNER · AI';ul.append(dl)}
  $('lStart').hidden=!host;$('shareBtn').hidden=false;$('lTeam').hidden=!base;$('lLock').hidden=!host;$('lLock').textContent=NET.roomLocked?'UNLOCK ROOM':'LOCK ROOM';
  $('lStart').textContent=pick.pvp==='coop'?'START':'START THE FIGHT';
  renderMods();
  const len=pick.mode==='endless'?'endless':pick.mode==='campaign'?'Operation Whiteout':pick.mode==='blitz'?'Blitzkrieg Rush':pick.mode+' raids',what=pick.pvp==='base'?'Base battle':pick.pvp==='ffa'?'Free-for-all':`Co-op · ${(MAPS[pick.map]||MAPS.yard).name}${pick.size==='xl'?' XL':''} · ${len} · threat: ${DIFF[pick.diff].name.toLowerCase()}`;
  const block=lobbyBlock();
  $('lNote').textContent=host?`${NET.roster.length} of 6 in the room · ${what}. ${block||'Share the code, then start when everyone is in.'}`:`Waiting for the host to start · ${what}.`;
  if(typeof renderHome==='function')renderHome();
}
$('lTeam').addEventListener('click',()=>{initAudio();if(NET.mode==='host'){const r=NET.roster.find(x=>x.id==='host');if(r){r.team=r.team==='b'?'a':'b';broadcastLobby()}}else if(NET.mode==='guest')NET.toHost({t:'team'})});
// the Multiplayer page needs the matchmaking library; the in-Claude preview doesn't ship it
if(!canOnline()){$('hostBtn').disabled=true;$('joinBtn').disabled=true;$('mOffline').hidden=false}

/* ---------- install as an app ---------- */
const standalone=matchMedia('(display-mode: standalone)').matches||navigator.standalone===true;
const iOS=/iPhone|iPad|iPod/.test(navigator.userAgent)||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1);
const ownSite=canOnline()&&location.protocol==='https:';
if(ownSite&&!standalone&&iOS)$('installTip').hidden=false;
let installEvt=null;
addEventListener('beforeinstallprompt',e=>{e.preventDefault();installEvt=e;if(!standalone)$('installBtn').hidden=false});
$('installBtn').addEventListener('click',async()=>{if(!installEvt)return;installEvt.prompt();try{await installEvt.userChoice}catch(e){}installEvt=null;$('installBtn').hidden=true});
if(ownSite&&'serviceWorker' in navigator)navigator.serviceWorker.register('sw.js').catch(()=>{});

pick.map=MAP_IDS.includes(cfg.map)?cfg.map:'yard';pick.size=cfg.size==='xl'?'xl':'std';pick.job=CLASSES[cfg.job]?cfg.job:'soldier';
applyCfg();syncPicks();recoverRunDraft();startDemo();showPage('main');
addEventListener('pagehide',saveRunDraft);document.addEventListener('visibilitychange',()=>{if(document.hidden)saveRunDraft()});
// accounts start after the first screen is up, so a slow connection never holds up the menu
if(cloudOn)setTimeout(acctBoot,400);
const invite=new URLSearchParams(location.search).get('room');
if(invite&&canOnline()){$('mCode').value=invite.toUpperCase().slice(0,4);showPage('multi');mStatus(`You're invited to room ${invite.toUpperCase().slice(0,4)}. Pick your name and job, then tap JOIN.`)}
if(new URLSearchParams(location.search).has('debug'))window.__pal={BOSS_WEAK,BOSS_HP,WEAK_BONUS,MOVE,bossWeak,strikePts,overdrivePts,cyclonePos,startMove,runMove,idxTab,IDX_BOSSES,IDX_RAIDERS,AMMO_BY,get nodes(){return nodes},skipMapEvac:()=>{if(game.fb&&game.fb.mapEvac&&!game.fb.done){for(const p of players.values())p.out=true;finishMapEvac()}},get coreKs(){return coreKs},mapHp,startMapEvac,finishMapEvac,startGauntlet,gauntletCleared,GAUNTLET,liveBosses,chEvacBits,chEvacFrom,friendsTickRun,caseArtURL,openCaseUI,closeCaseOpening,localCases,resumeCaseOpening,saveLocker,get caseSession(){return caseSession},get caseArtStats(){return {entries:caseArt.size,limit:CASE_ART_LIMIT}},musicRoute,musicTick,initAudio,glitchGeometry,glitchChannel,qmSafePlacement,paintSceneParticle,WINTER_MODELS,setQMMode,qmCommandJob,qmLayout,qmCanRevive,checkDeadEnd,updateQM,startBuild,endGame,RIOT_SHIELD_HITS,shieldBulletHit,drawPerson,inviteFriend,answerInvite,registerInviteRoom,canInviteFriend,renderLobbyInvites,WINTER_PAIRS,WINTER_BG,WINTER_TRACERS,WINTER_FX,heightAt,heightLink,heightCollision,travelClear,heightRayClear,heightDist,moveEnt,screenToWorld,chapterCredit,changeChapter,campaignAdvance,CAMPAIGN,thinkRime,addFrost,get frostFields(){return frostFields},get connectors(){return connectors},get heights(){return heights},shopOpen,stashLeaver,PROTO,makeWallHook:(m,d)=>makeWall(m,d),revivePlayer,runClaim,localRun,BLITZ,startFinalBlitz,fbTick,evacSpot,openEvac,extract,finishBlitz,blitzResult,launchArc,updateArcs,twinBolt,napalmLand,napalmTick,spawnBoss,bossBase,blitzBoss,halfUp,bossMilestone,fbCap,coopMods,liveBosses,get arcs(){return arcs},get arcHaz(){return arcHaz},localNade,nightmareSecond,touchLock,lockClear,lockKind,openGameSettings,closeGameSettings,togglePause,get touchModeSet(){return touchMode},set touchModeSet(v){touchMode=v},saveRunDraft,recoverRunDraft,runDraftDue,fpsCap,FPS_AUTO,get cfg(){return cfg},applyCfg,restoreLeaver,headwearAllowed,HALLOWEEN_HATS,RAR,shoot,simPlayer,drawTracer,makeSnap,applySnap,startMsg,bulletEvent,nextTracerColor,wardrobeStep,presentationMotion,stageBreath,get backgroundStats(){return {entries:BG_CACHE.size,bytes:bgCacheBytes,limit:BG_CACHE_LIMIT}},hostData,winDrop:()=>winDrop(),openCaseOf:id=>openCase(id),caseCount:id=>caseCount(id),TRAIL_IDS,parseCosT:v=>parseCos(v),paintAura,AURAS,LADDERS,FLAGS,addMilestones:(...a)=>addMilestones(...a),bossCounted:(...a)=>bossCounted(...a),needProgress:n=>needProgress(n),pvpReward:(...a)=>pvpReward(...a),winCase:()=>winCase(),hud:dt=>hud(dt),MODS,SKILLS,hasMod,cleanMods,modBonus,perkMods,parseSkills,skillStr,kitUp:p=>kitUp(p),useAbility:(p,x,y)=>useAbility(p,x,y),localAbility,stormTick:dt=>stormTick(dt),extraBoss:w=>extraBoss(w),stealthed,renderSkills,renderMods,toggleMod,myMods,roomMods,mySkills,takeLocker:j=>takeLocker(j),checkSkills:(c,s)=>checkSkills(c,s),leaveRun:()=>leaveRun(),get fires2(){return fires},updateRockets:dt=>updateRockets(dt),updateEnemies:dt=>updateEnemies(dt),updateLobs:dt=>updateLobs(dt),throwNade:(p,x,y)=>throwNade(p,x,y),get demo(){return demo},get caseIntroOn(){return caseIntroOn},set demo(v){demo=v},SOCIAL,losClear:(...a)=>losClear(...a),layPvp:(...a)=>layPvp(...a),claimReward,showRewards,changeClass:(p,c)=>changeClass(p,c),parseCos,paintWardrobeCharacter,FR,friendsPoll,renderMapPanel,refreshSocial,findPlayer,savePlayer,renderIdentity,renderPartyState,get floats(){return floats},TRAILS,traceSeg,paintFinish,FINISH_LIFE,paintCosmeticParticle,drawIcon,get cosmeticCache(){return {tracers:TRACE_STAMPS.size,glows:FX_GLOWS.size}},wardrobeBarrel,wardrobeShotVisual,wardrobeAimAngle,tracerPoints,flashPoint,fire,addGuestBullet,replayFx,get flashes(){return flashes},drawFig,lookOf,SKINS,drawWardrobeCharacter,get wardrobeStats(){return {workers:wardrobeWorkers?wardrobeWorkers.length:0,completed:wardrobeWorkerCompletions,pending:WARDROBE_JOBS.size,busy:WARDROBE_BUSY.size,entries:WARDROBE_CACHE.size,bytes:wardrobeCacheBytes}},get renderCacheStats(){const v=caches&&caches.back.view;return {viewBytes:v?v.cv.width*v.cv.height*4:0,viewBuilds:v?v.builds:0,sourceBytes:caches?(caches.back.cv.width*caches.back.cv.height+caches.front.cv.width*caches.front.cv.height)*4:0}},get ctx(){return g},get mus(){return mus},get AC(){return AC},musicWant,caseTick,MUSIC,get parts(){return parts},profOn(f){PROF={a:{},k:'x',f,t:performance.now()}},prof(){const o={};for(const k in PROF.a)if(k!=='end'&&k!=='x')o[k]=+PROF.a[k].toFixed(1);return o},get locker(){return locker},lockerReward:(...a)=>lockerReward(...a),openCase:()=>openCase(),buyUpgrade:(p,k)=>buyUpgrade(p,k),buyAmmo:(p,id,slot)=>buyAmmo(p,id,slot),ammoHit:(e,b)=>ammoHit(e,b),ammoRank:(p,id)=>ammoRank(p,id),ARM_MAX,AMMO,render,update,NET,get players(){return players},get player(){return player},get game(){return game},get enemies(){return enemies},get walls(){return walls},get core(){return core},get cores(){return cores},get bullets(){return bullets},startRaid:()=>startRaid(),scr:(x,y)=>{const c=iso(x,y);return[c[0],c[1]-WH*.55]},endPvp:w=>endPvp(w),hurtPlayer:(p,d,o)=>hurtPlayer(p,d,o),explode:(...a)=>explode(...a),buildEval:(...a)=>buildEval(...a),doBuild:(...a)=>doBuild(...a),acct,acctBoot,syncLocker,flushClaims,get claims(){return claims},showOver:()=>showOver(),showPage:x=>showPage(x),toMenu:()=>toMenu(),refreshLobbies:()=>refreshLobbies(),damageWall:(...a)=>damageWall(...a),spawnBoss:(k,sb)=>spawnBoss(k,sb),get rockets(){return rockets},get fires(){return fires},get zaps(){return zaps},get slashes(){return slashes},makePlayer:(...a)=>makePlayer(...a),get qm(){return qm},bdmg:b=>bdmg(b),makeWall:(...a)=>makeWall(...a),get walls2(){return walls},COS,CASES,rollCase:id=>rollCase(id),killFx:(...a)=>killFx(...a),renderLocker:()=>renderLocker(),playerLook:p=>playerLook(p),pvpReward:(w,k)=>pvpReward(w,k),bodyUnder,dellGun,salvageShards,iso,localSprint,renderArmory,CLASSES,burstN,burstGap,get light(){return light},BGS,drawBg,BOSSES,BOSS_VARIANTS,COSBY,TRAIL_IDS,get MAPS(){return MAPS},get terr(){return terr},get MAP(){return MAP},get N(){return N},setTerr:(k,t)=>setTerr(k,t),makePit:k=>makePit(k),spawnEnemyAt:(...a)=>spawnEnemyAt(...a),waveMix:(...a)=>waveMix(...a),pick,get lobs(){return lobs},get charges(){return charges},newGame:(...a)=>newGame(...a),get floodOn(){return floodOn},LOBBY,slowAtHook:(x,y)=>slowAt(x,y),solidTileHook:(i,j)=>solidTile(i,j),todStage:w=>todStage(w),updateBulletsHook:dt=>updateBullets(dt),bossOf:w=>bossOf(w),enterGameHook:()=>enterGame(),bossInfo:k=>bossInfo(k),hurtEnemyHook:(e,d,o)=>hurtEnemy(e,d,o),bossDropsHook:(k,h)=>bossDrops(k,h),get camX(){return camX},get camY(){return camY},get u(){return u},setMouse(x,y,d){mouse.x=x;mouse.y=y;mouse.seen=true;mouse.down=!!d},pad,get padMode(){return padMode},get padMap(){return padMap},PAD_ACTIONS,get padFocus(){return pad.el},padFocusEl:el=>navFocus(el),get touchMode(){return touchMode}};
if(window.PEER_SRC&&invite)needPeer();   // otherwise it loads when the Multiplayer page opens
requestAnimationFrame(frame);
