/* ================= best record (this browser only) ================= */
const BEST_KEY='palisade.best.v3';
function loadBest(){try{return JSON.parse(localStorage.getItem(BEST_KEY)||'{}')||{}}catch(e){return{}}}
// one record per length and threat on the Yard (the keys from before maps), and per map and size elsewhere
// v0.9.2: and per modifier set (no modifiers keeps the old key)
const bestKey=(mode,diff,map,size,mods)=>(mode==='campaign'?'campaign':mode)+':'+diff+(mode!=='campaign'&&(map&&map!=='yard')||size==='xl'?':'+(mode==='campaign'?'all':map||'yard')+(size==='xl'?':xl':''):'')+(mods&&mods.length?'|'+modKey(mods):'');
function saveBest(held,dropped){try{const b=loadBest(),k=bestKey(game.mode,pick.diff,game.map,game.size,game.mods),o=b[k];if(!o||held>o.held||(held===o.held&&dropped>o.dropped)){b[k]={held,dropped,cls:player.C.name};localStorage.setItem(BEST_KEY,JSON.stringify(b))}}catch(e){}}
function showBest(){const m=myMods(coopMods()),b=loadBest()[bestKey(pick.mode,pick.diff,pick.map,pick.size,m)],el=$('best');if(!b){el.hidden=true;return}el.hidden=false;
  const w=m.length?` with ${m.length>2?m.length+' modifiers':modNames(m).map(n=>n.toLowerCase()).join(' + ')}`:'';
  el.textContent=pick.mode==='endless'?`Best endless on ${DIFF[pick.diff].name.toLowerCase()}${w}: ${b.held} raids held, ${b.dropped} raiders dropped (${b.cls.toLowerCase()}).`:`Best on ${DIFF[pick.diff].name.toLowerCase()}${w}: ${b.held} of ${pick.mode==='campaign'?CAMPAIGN.waves:pick.mode==='blitz'?BLITZ.waves:pick.mode} stages held, ${b.dropped} raiders dropped (${b.cls.toLowerCase()}).`}

/* ================= HUD ================= */
let toastT=0;
function toast(big,small){if(demo)return;const el=$('toast');el.textContent='';el.append(big);if(small){const s=document.createElement('small');s.textContent=small;el.append(s)}el.classList.add('on');toastT=3}
function feed(text,col){rec(['q',text,col]);feedLocal(text,col)}
function feedLocal(text,col){if(demo)return;const box=$('feed'),el=document.createElement('span');el.textContent=text;el.style.color=col;box.prepend(el);
  while(box.children.length>4)box.lastChild.remove();setTimeout(()=>el.classList.add('old'),5000);setTimeout(()=>el.remove(),5700)}
function feedClear(){$('feed').textContent=''}
/* ---- text chat: the host relays every line, so it reaches everyone in the lobby and in the game ---- */
const chatLines=[];let chatNew=false;
const chatOpen=()=>!$('chatBar').hidden;
function cleanChat(s){return String(s||'').replace(/[\u0000-\u001f\u007f\u200b-\u200f\u202a-\u202e\u2066-\u2069]/g,'').replace(/\s+/g,' ').trim().slice(0,120)}
function chatColor(id,team){
  if(game.pvp&&team&&TEAMS[team])return TEAMS[team].col;
  const p=players.get(id);if(p&&NET.inGame)return SLOTCOL[p.slot%6];
  const i=NET.roster.findIndex(r=>r.id===id);return SLOTCOL[Math.max(0,i)%6];
}
function addChat(id,name,text,team){
  const line={id,name:String(name||'?').slice(0,12),text,col:chatColor(id,team),t:performance.now()};
  chatLines.push(line);if(chatLines.length>40)chatLines.shift();
  for(const[boxId,lobby]of[['chatLog',false],['lChatLog',true]]){
    const box=$(boxId),li=document.createElement('li'),b=document.createElement('b'),sp=document.createElement('span');
    b.textContent=(id===myId?'YOU':line.name.toUpperCase());b.style.color=line.col;li.style.color=line.col;sp.textContent=text;li.append(b,sp);box.append(li);
    while(box.children.length>(lobby?40:8))box.firstChild.remove();
    if(lobby)box.scrollTop=box.scrollHeight;else setTimeout(()=>li.classList.add('old'),9000);
  }
  if(id!==myId){sfx('chat',undefined,undefined,true);if(!chatOpen()&&NET.inGame){chatNew=true;cls($('chatBtn'),'new',true)}}
}
function sendChat(raw){
  const text=cleanChat(raw);if(!text||NET.mode==='solo')return;
  if(NET.mode==='host')hostChat('host',text);else NET.toHost({t:'c',m:text});
}
const chatRate=new Map();
function hostChat(pid,raw){
  const text=cleanChat(raw);if(!text)return;
  const now=performance.now(),r=chatRate.get(pid)||[];while(r.length&&now-r[0]>6000)r.shift();if(r.length>=5)return;r.push(now);chatRate.set(pid,r);
  const who=NET.roster.find(x=>x.id===pid),name=who?who.name:'?',team=(players.get(pid)||who||{}).team||'';
  NET.sendAll({t:'c',id:pid,n:name,m:text,tm:team});addChat(pid,name,text,team);
}
function openChat(){
  if(NET.mode==='solo'||!playing())return;
  for(const k in keys)keys[k]=false;mouse.down=false;freeSticks();
  $('chatBar').hidden=false;$('chat').classList.add('open');chatNew=false;cls($('chatBtn'),'new',false);
  const i=$('chatIn');i.value='';i.focus();
}
function closeChat(){$('chatBar').hidden=true;$('chat').classList.remove('open');$('chatIn').blur()}
function clearChat(){chatLines.length=0;$('chatLog').textContent='';$('lChatLog').textContent='';chatRate.clear();closeChat()}
// v0.9.3.9: Settings > Show tips during games. Tips are the how-to hints; toasts (bosses, rewards, IS BACK) always show.
function setTip(t){const show=!!t&&cfg.tips!==false;$('tip').hidden=!show;$('tipText').textContent=show?t:''}
const txt=(el,v)=>{if(el._v!==v){el._v=v;el.textContent=v}};
const cls=(el,c,on)=>{if(el.classList.contains(c)!==on)el.classList.toggle(c,on)};
const SLOTCOL=['#8fb58a','#a9bccb','#d0b077','#c29ac4','#86c0b8','#d08f78'];
// the desktop key bar says what the keys do right now
function keyBar(){
  if(touchMode)return;if(padMode)return padBar();const p=player,PV=game.pvp,K=(k,t)=>`<span class="kb"><kbd>${k}</kbd>${t}</span>`,a=[K('WASD','move'),K('MOUSE',p.gun&&p.gun.clickCd?'aim, click or hold to fire':p.gun&&p.gun.burst?'aim, hold to fire bursts':'aim, hold to fire'),K('G','grenade')];if(p.C&&p.C.sprint)a.push(K('SHIFT','sprint'));
  if(p.gun&&p.gun.mag)a.push(K('R','reload'));
  if(PV!=='ffa'&&cfg.build)a.push(K('SPACE','build'),K('1 2 3','material'),K('F','door'));
  if(PV!=='ffa')a.push(K('B','build kit'));
  if(shopOpen(p))a.push(K('E','armory'));
  if(game.phase==='build'&&NET.mode!=='guest')a.push(K('ENTER',PV?'start battle':'start raid'));
  if(NET.mode!=='solo')a.push(K('T','chat'));
  a.push(K('ESC','pause'));
  if(hasAbility(p))a.splice(3,0,K('Q',p.cls==='sniper'?'stealth':'rocket'));
  const h=a.join(''),el=$('keys');if(el._h!==h){el._h=h;el.innerHTML=h}
}
// v0.9.2.1: the same bar with controller buttons (they follow the player's own button changes)
function padBar(){
  const p=player,PV=game.pvp,K=(k,t)=>k==='—'?'':`<span class="kb"><kbd>${k}</kbd>${t}</span>`,a=[K(glyph(PB.LS),'move'),K(glyph(PB.RS),'aim'),K(padKey('fire'),'fire'),K(padKey('nade'),'grenade')];
  if(hasAbility(p))a.push(K(padKey('special'),p.cls==='sniper'?'stealth':'rocket'));else if(p.C&&p.C.sprint)a.push(K(padKey('special'),'sprint'));
  if(PV!=='ffa'&&cfg.build)a.push(K(padKey('build'),'build'),K(padKey('matPrev')+' '+padKey('matNext'),'material'),K(padKey('piece'),'door'));
  if(PV!=='ffa')a.push(K(padKey('kit'),'build kit'));
  if(shopOpen(p))a.push(K(padKey('armory'),'armory'));
  if(game.phase==='build'&&NET.mode!=='guest')a.push(K(padKey('start'),PV?'start battle':'start raid'));
  a.push(K(glyph(PB.MENU),'pause'));
  const h=a.join(''),el=$('keys');if(el._h!==h){el._h=h;el.innerHTML=h}
}
function mateRows(){
  const box=$('mates'),mates=[...players.values()].filter(p=>p!==player&&(!game.pvp||(game.pvp==='base'&&p.team===player.team)));
  while(box.children.length<mates.length){const d=document.createElement('div');d.className='meter mate';d.innerHTML='<span class="lab"></span><div class="track"><i></i></div><b></b>';box.append(d)}
  [...box.children].forEach((row,n)=>{const p=mates[n];row.hidden=!p;if(!p)return;
    txt(row.children[0],p.name.toUpperCase());row.children[1].firstChild.style.transform=`scaleX(${Math.max(0,p.hp/p.max)})`;row.children[1].firstChild.style.background=SLOTCOL[p.slot%6];
    txt(row.children[2],p.alive?String(Math.ceil(p.hp)):'DOWN');cls(row,'alarm',!p.alive)});
}
function hud(dt){
  if(toastT>0){toastT-=dt;if(toastT<=0)$('toast').classList.remove('on')}
  const p=player;if(!p)return;
  const rj=game.pvp==='ffa'&&!game.job&&!p.alive&&game.phase!=='over';if($('respawnJobs').hidden===rj){$('respawnJobs').hidden=!rj;if(rj)syncJobPick()}
  $('hpF').style.transform=`scaleX(${Math.max(0,p.hp/p.max)})`;txt($('hpN'),p.alive?String(Math.ceil(p.hp)):'DOWN');cls($('hpM'),'alarm',!p.alive);
  mateRows();
  hud.t=(hud.t||0)-dt;if(hud.t<=0){hud.t=.5;const b=$('top').getBoundingClientRect().bottom;if(b>0){hud.topB=b;const v=Math.round(b+10)+'px';if($('tip').style.top!==v)$('tip').style.top=v}
    const tp=$('tip');hud.tipB=tp.hidden||!$('tipText').textContent?0:tp.getBoundingClientRect().bottom}
  if($('tipText').textContent&&(game.pvp==='ffa'&&game.time>9||game.pvp==='base'&&game.phase==='raid'))setTip('');
  const PV=game.pvp,clock=t=>{const s=Math.max(0,Math.ceil(t));return`${Math.floor(s/60)}:${String(s%60).padStart(2,'0')}`};
  $('qmM').hidden=!!PV||!!qm.gone;$('coreM').hidden=PV==='ffa';$('core2M').hidden=PV!=='base';$('board').hidden=PV!=='ffa';$('salv').hidden=PV==='ffa';
  syncQMControls();
  if(!PV){$('qmF').style.transform=`scaleX(${Math.max(0,qm.hp/qm.max)})`;txt($('qmN'),qm.alive?String(Math.ceil(qm.hp)):'DOWN');cls($('qmM'),'alarm',!qm.alive)}
  if(PV!=='ffa'){txt($('coreL'),PV?'STAKE':'CORE');$('coreF').style.transform=`scaleX(${Math.max(0,core.hp/core.max)})`;txt($('coreN'),String(Math.max(0,Math.ceil(core.hp))));
    cls($('coreM'),'alarm',core.flash>0||core.hp/core.max<.3);$('coreF').style.background=PV?(TEAMS[p.team]||TEAMS.a).col:''}
  if(PV==='base'&&cores[p.team==='a'?1:0]){const ec=cores[p.team==='a'?1:0];$('core2F').style.transform=`scaleX(${Math.max(0,ec.hp/ec.max)})`;$('core2F').style.background=(TEAMS[ec.team]||TEAMS.b).col;txt($('core2N'),String(Math.max(0,Math.ceil(ec.hp))))}
  const lab=$('phaseLab'),host=NET.mode!=='guest';
  if(PV==='base'){
    let mine=0,theirs=0;for(const o of players.values())if(o.team===p.team)mine+=o.kills;else theirs+=o.kills;
    if(game.phase==='build'){txt(lab,'TRUCE');cls(lab,'raid',false);txt($('phaseVal'),`${clock(game.timer)} until the battle`);$('skipBtn').hidden=!host;txt($('skipLab'),'START BATTLE')}
    else{txt(lab,'BATTLE');cls(lab,'raid',true);txt($('phaseVal'),`${TEAMS[p.team].name} ${mine} · ${TEAMS[p.team==='a'?'b':'a'].name} ${theirs} drops`);$('skipBtn').hidden=true}
  }else if(PV==='ffa'){
    txt(lab,W<700?'FFA':'FREE-FOR-ALL');cls(lab,'raid',true);txt($('phaseVal'),`${clock(game.timer)} left · first to ${game.goal}`);$('skipBtn').hidden=true;
    const rows=[...players.values()].sort((a,b)=>b.kills-a.kills||a.deaths-b.deaths).slice(0,6),bd=$('board'),sig=rows.map(o=>o.id+o.kills).join();
    if(bd._sig!==sig){bd._sig=sig;bd.textContent='';for(const o of rows){const li=document.createElement('li');if(o===p)li.className='me';const n=document.createElement('span');n.textContent=o===p?'YOU':o.name.toUpperCase();const b=document.createElement('b');b.textContent=o.kills;li.append(n,b);bd.append(li)}}
  }
  else if(game.phase==='build'){txt(lab,campaign()?`CH ${game.chapter+1} · BUILD`:'BUILD');cls(lab,'raid',false);txt($('phaseVal'),campaign()?`${clock(game.timer)} · ${MAP.short} · ${game.wave===12?'final evacuation':`raid ${game.wave%3+1}/3`}`:`${clock(game.timer)} until raid ${game.wave+1}`);$('skipBtn').hidden=!host;txt($('skipLab'),'START RAID')}
  else if(game.fb&&!game.fb.done){const F=game.fb,ev=!!F.evac;txt(lab,ev?'EVACUATE':W<700?'BLITZ':'FINAL BLITZ');cls(lab,'raid',true);cls(lab,'evac',ev);   // v0.9.4.0
    txt($('phaseVal'),ev?(p.out?`${clock(F.t)} · you're out`:`${clock(F.t)} · get to the green ring`):`${clock(F.t)} · boss ${Math.min(F.n,F.max)}/${F.max}`);$('skipBtn').hidden=true}
  else{txt(lab,campaign()?`CH ${game.chapter+1} · RAID ${(game.wave-1)%3+1}/3`:isFinite(game.waves)?`RAID ${game.wave}/${game.waves}`:`RAID ${game.wave}`);cls(lab,'evac',false);cls(lab,'raid',true);txt($('phaseVal'),`${campaign()?MAP.short+' · ':''}${enemies.length+(NET.mode==='guest'?game.qn:game.queue.length)} raiders left`);$('skipBtn').hidden=true}
  for(let m=0;m<3;m++){
    const c=$('c'+m),locked=m>0&&!!(nodes.find(n=>n.type===m)||{}).locked&&p.mats[m]===0;
    txt($('n'+m),locked?(m===1?'R2':'R4'):String(p.mats[m]));cls(c,'sel',game.sel===m);cls(c,'locked',locked);
  }
  cls($('pWall'),'sel',game.piece==='wall');cls($('pDoor'),'sel',game.piece==='door');
  cls($('kit'),'nobuild',!cfg.build||PV==='ffa');$('bmBtn').hidden=PV==='ffa';txt($('bmLab'),cfg.build?'BUILD ON':'BUILD OFF');cls($('bmBtn'),'off',!cfg.build);
  if(cfg.build&&PV!=='ffa'){const t=buildTarget(p,game.sel,game.piece==='door'),b=$('buildBtn');
    txt($('buildAct'),t.ok?t.act:(t.act==='SOLID'?'SOLID':'BUILD'));
    txt($('buildSub'),t.ok?`${MAT[t.mat].name} · ${t.cost}`:t.reason);cls(b,'no',!t.ok)}
  txt($('salN'),String(p.sal|0));
  const ab=$('armBtn'),shopPhase=shopOpen(p);ab.hidden=!shopPhase;
  if(shopPhase){const near=nearStake(p),afford=UPG.some(U=>p.up[U.k]<ARM_MAX&&p.sal>=U.cost[p.up[U.k]])||!game.pvp&&((game.dellLv|0)<ARM_MAX&&p.sal>=DELL_UP.cost[game.dellLv|0]||ammoMode()&&p.sal>=(p.ammoEq.some(Boolean)?75:150));
    txt($('armLab'),'ARMORY');cls(ab,'far',!near);cls(ab,'pulse',near&&afford)}
  keyBar();
  if(!$('armory').hidden&&armorySig(p)!==armSig)renderArmory()
  txt($('nadeN'),String(p.nades));cls($('nadeBtn'),'empty',p.nades<=0);
  const abb=$('abBtn'),hasAb=hasAbility(p);if(abb.hidden===hasAb)abb.hidden=!hasAb;
  if(hasAb){const a=p.ab|0,snipe=p.cls==='sniper';txt($('abLab'),snipe?'STEALTH':'ROCKET');
    txt($('abN'),snipe?(a>0?Math.ceil(a/10)+'s':a<0?(-a)+'s':'READY'):String(Math.max(0,a)));cls(abb,'on',snipe&&a>0);cls(abb,'empty',snipe?a<0:a<=0)}
  const sb=$('sprBtn');sb.hidden=!p.C.sprint;if(p.C.sprint){const on=p.sprT>0,cd=p.sprCd||0;txt($('sprN'),on?'GO':cd>0?Math.ceil(cd)+'s':'READY');cls(sb,'on',on);cls(sb,'empty',!on&&cd>0)}
}

