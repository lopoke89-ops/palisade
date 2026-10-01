/* ---------- v0.9.5 menu: PLAY with the setup behind it ----------
   The PLAY page shows what you're about to play as a few tappable lines (map, length and threat, job, modifiers)
   and one PLAY button. Each line opens the match setup sheet at its tab; the same sheet serves hosting a room and
   the room itself (host only), so there is one place to change a match. The right column of PLAY shows what's
   waiting for you: the new mode, cases to open, the next unlock and skill points. */
$('ssMap').append($('mapPanel'));   // the map picker lives in the setup sheet now
const setupOpen=()=>!$('setupSheet').hidden;
function setupRowsFor(kind){
  const pv=kind!=='home'&&pick.pvp!=='coop',M=MAPS[pick.map]||MAPS.yard,C=CLASSES[pick.cls]||CLASSES.soldier,mods=kind==='room'?roomMods():myMods(kind==='home'?coopMods():roomKind());
  const selMap=document.querySelector('#mapCards .mapCard.sel b'),pct=pv?0:modBonus(mods,pick.mode==='blitz'?'blitz':'');
  const rows=[['map','MAP',pick.mode==='campaign'&&!pv?'ALL FOUR MAPS':selMap?selMap.textContent:M.name,pv?'16×16 arena':`${pick.size==='xl'?'XL · 24×24':'16×16'} · bosses: ${(M.bosses||[]).map(k=>(BOSSES[k]||{name:k}).name.replace('THE ','').toLowerCase()).join(', ')}`]];
  if(!pv)rows.push(['rules','LENGTH',LEN_NAME[pick.mode]||'5 RAIDS',`Threat: ${DIFF[pick.diff].name.toLowerCase()}${pick.mode==='campaign'?' · 4 chapters, 12 raids + five-minute evac':pick.mode==='blitz'?' · the Final Blitz and the evacuation':''}`]);
  if(kind!=='room'){const tg=document.querySelector(`#classes .cls[data-c=${pick.cls}] i`);rows.push(['job','JOB',C.name,tg?tg.textContent:''])}
  rows.push(['mods','MODIFIERS',mods.length?modNames(mods).join(' · '):'NONE',mods.length?`${mods.length} on${pct?` · rewards ${pct>0?'+':''}${pct}%`:''}`:'Harder rules pay more']);
  return rows;
}
function fillRows(box,kind,edit){
  if(!box)return;const rows=setupRowsFor(kind),sig=kind+'|'+edit+'|'+JSON.stringify(rows);if(box.dataset.sig===sig)return;box.dataset.sig=sig;box.textContent='';
  for(const[id,k,v,sub]of rows){const b=document.createElement('button');b.type='button';b.className='setupRow';b.dataset.setup=id;b.disabled=!edit;
    const s=document.createElement('span');s.textContent=k;const bb=document.createElement('b');bb.textContent=v;const sm=document.createElement('small');sm.textContent=sub;
    b.append(s,bb,sm);if(edit){const i=document.createElement('i');i.className='suGo';i.setAttribute('aria-hidden','true');i.textContent='›';b.append(i);b.setAttribute('aria-label',`${k}: ${v}. Change`)}
    b.addEventListener('click',()=>{initAudio();openSetup(id,kind)});box.append(b)}
}
function renderHome(){
  const pg=$('menu').dataset.page;
  if(pg==='solo')fillRows($('homeRows'),'home',true);
  if(pg==='multi')fillRows($('hostRows'),'host',true);
  if(pg==='lobby'){const host=NET.mode!=='guest';fillRows($('roomRows'),'room',host);$('lModsBox').hidden=host}
  if(pg==='solo')renderHomeSide();
}
// ---- the setup sheet ----
function openSetup(tab,kind){
  if(kind==='room'&&NET.mode==='guest')return;
  SETUP.kind=kind||($('menu').dataset.page==='solo'?'home':$('menu').dataset.page==='lobby'?'room':'host');
  const K=SETUP.kind,pv=K!=='home'&&pick.pvp!=='coop';
  $('setupTitle').textContent=K==='home'?'SOLO RUN SETUP':K==='room'?'ROOM SETUP':'HOST SETUP';
  document.querySelector('.ssTabs [data-sst=rules]').hidden=pv;document.querySelector('.ssTabs [data-sst=job]').hidden=K==='room';
  closeFriends();$('setupSheet').hidden=false;renderMapPanel();renderMods();renderSetupJobs();
  setupTab(pv&&tab==='rules'?'map':tab||'map');
}
function setupTab(tab){
  for(const b of document.querySelectorAll('.ssTabs [data-sst]')){const on=b.dataset.sst===tab;b.setAttribute('aria-selected',on?'true':'false');b.classList.toggle('sel',on)}
  for(const s of document.querySelectorAll('.ssSec'))s.hidden=s.dataset.ss!==tab;
  const f=document.querySelector(`.ssTabs [data-sst=${tab}]`);if(f&&!padMode)f.focus({preventScroll:true});$('setupSheet').querySelector('.ssBody').scrollTop=0;
}
function closeSetup(){
  if(!setupOpen())return;$('setupSheet').hidden=true;
  if(NET.mode==='host'&&!NET.inGame)broadcastLobby();
  syncPicks();renderMods();renderHome();showBest();if(NET.mode==='host')renderLobby();
  const back=document.querySelector(`#${SETUP.kind==='home'?'homeRows':SETUP.kind==='room'?'roomRows':'hostRows'} [data-setup]`);if(back&&!padMode)back.focus({preventScroll:true});
}
// the job tab: the four jobs as cards with their one-line pitch (the full write-up stays on CLASSES)
function renderSetupJobs(){
  const box=$('ssJobs');if(!box)return;const sig=pick.cls;if(box.dataset.sig===sig)return;box.dataset.sig=sig;box.textContent='';
  for(const b of document.querySelectorAll('#classes .cls')){const c=b.dataset.c,d=document.createElement('p');d.className='ssJob'+(c===pick.cls?' sel':'');
    const n=document.createElement('b');n.textContent=b.querySelector('b').textContent;const t=document.createElement('span');t.textContent=b.querySelector('span').textContent;d.append(n,t);box.append(d)}
}
for(const b of document.querySelectorAll('.ssTabs [data-sst]'))b.addEventListener('click',()=>setupTab(b.dataset.sst));
$('setupDone').addEventListener('click',()=>{initAudio();closeSetup()});
$('setupSheet').addEventListener('click',e=>{if(e.target===$('setupSheet'))closeSetup()});   // a tap outside the card closes it
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&setupOpen()){e.preventDefault();e.stopPropagation();closeSetup()}},true);
document.querySelectorAll('#setupSheet [data-c]').forEach(b=>b.addEventListener('click',()=>{renderSetupJobs();renderHome()}));
// ---- the right column of PLAY: the new mode, cases to open, the next unlock, skill points ----
function homeCard(cls,kicker,title,body,btn,act){const d=document.createElement('div');d.className='homeCard '+cls;
  const k=document.createElement('span');k.className='hcK';k.textContent=kicker;const t=document.createElement('b');t.textContent=title;d.append(k,t);
  if(body){const p=document.createElement('p');if(typeof body==='string')p.textContent=body;else p.append(body);d.append(p)}
  if(btn){const b=document.createElement('button');b.type='button';b.className='ghost';b.textContent=btn;b.addEventListener('click',()=>{initAudio();act()});d.append(b)}
  return d}
function nextUnlock(){
  let best=null;for(const L of LADDERS){const have=locker.st[L.st]|0,i=L.items.findIndex(([c,k])=>!owns(c+':'+k));if(i<0)continue;const f=have/L.steps[i];if(!best||f>best.f)best={L,i,f,have}}
  return best;
}
function renderHomeSide(){
  const box=$('homeSide');if(!box)return;const n=allCases(),nu=nextUnlock(),sig=[pick.mode,n,locker.sp|0,JSON.stringify(locker.bag),locker.cases,nu&&nu.have,nu&&nu.i,nu&&nu.L.id].join('|');
  if(box.dataset.sig===sig)return;box.dataset.sig=sig;box.textContent='';
  box.append(pick.mode==='campaign'?homeCard('hcMode','SELECTED','OPERATION WHITEOUT','Travel all four maps. Carry upgrades and supplies through 12 raids, then survive a five-minute summit evacuation.'):pick.mode==='blitz'?homeCard('hcMode','SELECTED','BLITZKRIEG RUSH','15 hard raids, then the Final Blitz: a boss every 30 seconds for five minutes. Reach the evac in the last minute or keep only half your cases and shards.')
    :homeCard('hcMode','NEW CAMPAIGN','OPERATION WHITEOUT','Four connected maps, revamped bosses and a summit evacuation. Frostpeak adds ramps, stairs and the Rime Colossus.','TRY IT',()=>{pick.mode='campaign';syncPicks();renderMods();showBest();renderHome()}));
  if(n>0){const chips=document.createElement('span');chips.className='hcChips';for(const id of CASE_IDS){const c=caseCount(id);if(!c)continue;const s=document.createElement('i');s.style.setProperty('--cc',CASES[id].col);s.textContent=`${c} ${CASES[id].short.replace(/ Cases$/,'').toUpperCase()}`;chips.append(s)}
    box.append(homeCard('hcCases','READY TO OPEN',`${n} CASE${n>1?'S':''}`,chips,'OPEN IN LOCKER',()=>showPage('locker')))}
  else box.append(homeCard('hcCases','CASES','NONE WAITING','You earn a Supply Case every 3 raids you hold, and bosses drop their own.'));
  if(nu){const it=COSBY[nu.L.items[nu.i][0]+':'+nu.L.items[nu.i][1]],bar=document.createElement('span');bar.className='hcBar';const f=document.createElement('i');f.style.width=Math.min(100,nu.have/nu.L.steps[nu.i]*100)+'%';bar.append(f);
    const wrap=document.createElement('span');wrap.append(bar,document.createTextNode(`${nu.have} / ${nu.L.steps[nu.i]} ${nu.L.unit}`));
    box.append(homeCard('hcNext','NEXT UNLOCK · '+nu.L.title,it?it.name:'',wrap,'MILESTONES',()=>{showPage('locker');const t=document.querySelector('#lockTabs [data-cat=ms]');if(t)t.click()}))}
  const sp=locker.sp|0;if(sp>0)box.append(homeCard('hcSp','SKILL POINTS',`${sp} TO SPEND`,locker.cloud?'Spend them on the skill tree, or trade 3 for a Supply Case in the Locker.':'Trade 3 for a Supply Case in the Locker.',locker.cloud?'SKILL TREE':'LOCKER',()=>showPage(locker.cloud?'skills':'locker')));
}
