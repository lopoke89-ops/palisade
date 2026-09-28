/* ---------- drawing cosmetics ---------- */
const lookOf=(cos,cls)=>playerLook({cos,cls,C:CLASSES[cls]||CLASSES.soldier,slot:0});
function drawFig(ctx,w,h,look,sc,aim,cy){
  const kg=g,ku=u,kx=camX,ky=camY;g=ctx;u=sc;camX=w/2;camY=cy;
  try{drawPerson(0,0,Object.assign({aim:aim||{x:.9,y:.25},walk:0},look))}finally{g=kg;u=ku;camX=kx;camY=ky}
}
// The painter shares the exact calibrated head/tail segment with gameplay and previews.
function traceSeg(ctx,x1,y1,x2,y2,st,w,t,heavy){paintTracer(ctx,x1,y1,x2,y2,st,w,t,heavy)}
// A tracer stays on the firing ray at weapon height; its tail cannot draw inside the barrel.
function tracerPoints(b,L){
 const a=iso(b.x,b.y),c=iso(b.x-b.vx*L,b.y-b.vy*L),v=b.visual;
 if(!v)return {head:[a[0],a[1]-WH*.62],tail:[c[0],c[1]-WH*.62]};
 a[0]+=v[0]*u;a[1]+=v[1]*u;c[0]+=v[0]*u;c[1]+=v[1]*u;
 const m=iso(v[2],v[3]),dx=(b.vx-b.vy)*TW2,dy=(b.vx+b.vy)*TH2;
 if((a[0]-m[0])*dx+(a[1]-m[1])*dy<=0)return null;
 if((c[0]-m[0])*dx+(c[1]-m[1])*dy<0){c[0]=m[0];c[1]=m[1]}
 return {head:a,tail:c};
}
function drawTracer(b){
 const st=b.team===0?(TRAILS[TRAIL_IDS[b.tr|0]]||TRAILS.std):ENEMY_TR,L=.018*(st.len||1),points=tracerPoints(b,L);
 if(!points)return;
 const a=points.head,c=points.tail;
 traceSeg(g,a[0],a[1],c[0],c[1],st,(b.heavy?2.6:1.8)*u*(st.w||1),game.time,b.heavy);
 if(st.pk&&rnd()<st.pr*.6&&parts.length<520){const h=WH*.62,p=screenToWorld(c[0],c[1]+h);ambient(p.x,p.y,h,st.pk)}
}

function killFx(x,y,id){
  if(id&&id!=='none')sfx('kx_'+id,x,y);
  if(id!=='skull'&&FINISH_LIFE[id])emit(x,y,WH*.6,'finish:'+id);
  const E=(n,k,z=.6)=>{for(let i=0;i<Math.ceil(n*.65);i++)emit(x,y,WH*z,k)};
  switch(id){
    case'pixel':E(14,'pix');break;
    case'frost':E(12,'ice');ringFx(x,y,0,.8,.35,'#ffffff','#9fd8f0',1.6);break;
    case'gradburst':E(16,'grad1');ringFx(x,y,0,1.1,.5,'#e0a0ff','#3a6aff',2);break;
    case'sunburst':E(16,'grad2');ringFx(x,y,0,1.1,.5,'#ff5ad8','#ffb03a',2);break;
    case'toxic':E(12,'toxic',.5);ringFx(x,y,0,.7,.45,'#b6ff3a','#3a6a10',2.4);break;
    case'supernova':E(18,'nova');E(8,'star',.8);ringFx(x,y,0,1.7,.6,'#ffffff','#6a8aff',2.6);addFlash({x,y,life:.25,max:.25,r:1.2});break;
    case'glitchout':E(16,'glitch');break;
    case'singularity':E(18,'void');ringFx(x,y,1.3,0,.42,'#b06aff','#1a0630',2.4);E(8,'nova',.6);break;
    case'shockwave':E(12,'neon');ringFx(x,y,0,1.8,.55,'#2af5ff','#1a4aff',2.4);ringFx(x,y,0,1.2,.45,'#ff3ad0','#6a1aff',2);break;
    case'bubbles':emitSpread(x,y,.4,WH*.3,WH*.9,'bubble',0,12);E(12,'goldsp',.7);E(6,'glint',.7);
      ringFx(x,y,0,1.5,.6,'#fff6c8','#e2b436',2.6);ringFx(x,y,0,.9,.4,'#ffffff','#ffd24a',1.6);addFlash({x,y,life:.22,max:.22,r:1.1});break;
    case'sparks':for(let n=0;n<10;n++)emit(x,y,WH*.6,'spark');break;
    case'smoke':for(let n=0;n<5;n++)emit(x,y,WH*.4,'smoke');break;
    case'confetti':for(let n=0;n<16;n++)emit(x,y,WH*.8,'confetti');break;
    case'embers':for(let n=0;n<12;n++)emit(x,y,WH*.4,'ember');break;
    case'glint':for(let n=0;n<10;n++)emit(x,y,WH*.6,'glint');break;
    case'bolt':for(let n=0;n<9;n++)emit(x+(rnd()-.5)*.15,y+(rnd()-.5)*.15,WH*(.2+n*.3),'bolt');addFlash({x,y,life:.22,max:.22,r:1.1});break;
    case'skull':flt(x,y,'☠','#efe6d2');for(let n=0;n<6;n++)emit(x,y,WH*.6,'spark');break;
  }
}
function keyCap(x,y,key,text,col){
  g.save();g.font=`800 ${Math.round(12*u)}px "Big Shoulders Stencil Display", "Arial Narrow", sans-serif`;
  const kw=key?Math.max(18*u,g.measureText(key).width+10*u):0,tw=g.measureText(text).width,h=20*u,w=kw+(key?6*u:0)+tw+16*u,x0=Math.round(x-w/2),y0=Math.round(y-h/2);
  g.fillStyle='rgba(14,12,10,.86)';g.fillRect(x0,y0,w,h);g.strokeStyle=col||'#e2b436';g.lineWidth=1;g.strokeRect(x0+.5,y0+.5,w-1,h-1);
  let cx=x0+8*u;g.textBaseline='middle';g.textAlign='left';
  if(key){g.fillStyle=col||'#e2b436';g.fillRect(cx,y0+3*u,kw,h-6*u);g.fillStyle='#17140f';g.textAlign='center';g.fillText(key,cx+kw/2,y0+h/2+.5);cx+=kw+6*u;g.textAlign='left'}
  g.fillStyle='#f3e9d6';g.fillText(text,cx,y0+h/2+.5);g.restore();
}
function drawPrompts(p){
  if(!p||!p.alive)return;
  if(canShop(p)&&$('armory').hidden){const c=stakeOf(p),s=iso(c.i+.5,c.j+.5);keyCap(s[0],s[1]-WH*1.15-(game.pvp==='base'?66:52)*u,touchMode?'':'E',touchMode?'TAP ARMORY':'ARMORY',null)}
  for(const o of players.values())if(o!==p&&o.downed&&(!game.pvp||(game.pvp==='base'&&o.team===p.team))){const d=dist2(o,p);if(d<2.2){const s=iso(o.x,o.y);keyCap(s[0],s[1]-34*u,'',d<1?'REVIVING · STAY CLOSE':'STAND CLOSE TO REVIVE','#a9bccb')}}
  if(!qm.gone&&!qm.alive&&dist2(qm,p)<2.2){const s=iso(qm.x,qm.y);keyCap(s[0],s[1]-34*u,'',dist2(qm,p)<1?'REVIVING DELL':'STAND CLOSE TO REVIVE DELL','#a9bccb')}
}
function drawCrosshair(p){
  let sx,sy,hot=false,faint=false;
  if(!touchMode&&mouse.seen){
    sx=mouse.x;sy=mouse.y;const w=screenToWorld(mouse.x,mouse.y+WH*.55);
    for(const e of foes())if(Math.hypot(e.x-w.x,e.y-w.y)<.45){hot=true;break}
  }else{
    const active=stickAim.id!==null&&stickAim.mag>.2,a=p.aim;let d=active?Math.min(p.gun.range,4.2):2.4;faint=!active;
    if(active){let best=1e9;for(const e of foes()){const dx=e.x-p.x,dy=e.y-p.y,dd=Math.hypot(dx,dy);if(dd<p.gun.range&&dd>.3&&(dx*a.x+dy*a.y)/dd>.992&&dd<best){best=dd;hot=true}}if(hot)d=best}
    const c=iso(p.x+a.x*d,p.y+a.y*d);sx=c[0];sy=c[1]-WH*.55;
  }
  const r=(hot?6:8)*Math.max(1,u*.9),col=hot?'#ff6a4a':'#f3e9d6';
  g.save();g.globalAlpha=faint?.4:.95;
  for(const[lw,cc]of[[3.4,'rgba(12,10,8,.75)'],[1.6,col]]){
    g.lineWidth=lw;g.strokeStyle=cc;g.beginPath();g.arc(sx,sy,r,0,Math.PI*2);
    for(const[dx,dy]of[[1,0],[-1,0],[0,1],[0,-1]]){g.moveTo(sx+dx*(r+2),sy+dy*(r+2));g.lineTo(sx+dx*(r+7),sy+dy*(r+7))}
    g.stroke()}
  g.fillStyle=col;g.fillRect(sx-1,sy-1,2,2);g.restore();
}
function drawIcon(cv2,c){
  const x=cv2.getContext('2d'),S=cv2.width;x.clearRect(0,0,S,S);
  if(c.cat==='skin')drawFig(x,S,S,lookOf({...locker.eq,skin:c.key},pick.cls),S/48,{x:.9,y:.25},S*.93);
  else if(c.cat==='hat')drawFig(x,S,S,lookOf({...locker.eq,hat:c.key},pick.cls),S/34,{x:.9,y:.25},S*.5+34*1.18*(S/34)*.93);
  else if(c.cat==='trail'){const st=TRAILS[c.key];x.fillStyle='#0c0b09';x.fillRect(0,0,S,S);
    for(const k of[0,1])traceSeg(x,S*(.2+k*.2),S*(.8-k*.12),S*(.62+k*.2),S*(.3-k*.12),st,S*.05*(st.w||1),k*.4,false)}
  else{x.fillStyle='#0c0b09';x.fillRect(0,0,S,S);
    if(c.key==='none'){x.strokeStyle='#6e7568';x.lineWidth=S*.025;x.beginPath();x.arc(S/2,S/2,S*.2,0,Math.PI*2);x.moveTo(S*.36,S*.64);x.lineTo(S*.64,S*.36);x.stroke()}
    else paintFinish(x,c.key,.3,S/92,S/2,S*.58)}
}

function drawLockerPreview(now){
  const c=$('lockPrev'),x=c.getContext('2d');x.clearRect(0,0,c.width,c.height);
  const ang=now/2200,aim={x:Math.cos(ang),y:Math.sin(ang)},sc=3.5,base=c.height*.92;
  const look=lookOf(locker.eq,pick.cls);drawFig(x,c.width,c.height,look,sc,aim,base);
  const sd=wdirToScreen(aim),st=TRAILS[locker.eq.trail]||TRAILS.std,ph=(now%800)/800;
  const muzzle=wardrobeBarrel(look,sd).tip,ox=c.width/2+muzzle[0]*sc*FIG,oy=base+muzzle[1]*sc*FIG,d0=ph*200,len=34*(st.len||1);
  if(ph>.08)traceSeg(x,ox+sd.x*d0,oy+sd.y*d0,ox+sd.x*Math.max(0,d0-len),oy+sd.y*Math.max(0,d0-len),st,3.4*(st.w||1),now/1000,false);
}

/* ---------- locker screen ---------- */
let lockCat='skin',caseItem=null;
function itemTile(c){
  const d=document.createElement('button');d.type='button';d.className='item';d.style.setProperty('--rc',RAR[c.r].col);
  const cv2=document.createElement('canvas');cv2.width=cv2.height=128;drawIcon(cv2,c);
  const b=document.createElement('b');b.textContent=c.name;const i=document.createElement('i');
  const own=owns(c.id),eq=locker.eq[c.cat]===c.key;if(c.r==='g')d.classList.add('gold');
  i.textContent=eq?'EQUIPPED':own?RAR[c.r].n:c.how;if(!own)d.classList.add('lock');if(eq)d.classList.add('eq');
  d.setAttribute('aria-label',`${c.name}, ${RAR[c.r].n.toLowerCase()} ${CATN[c.cat].toLowerCase()}, ${eq?'equipped':own?'owned':'locked: '+c.how}`);
  d.append(cv2,b,i);return d;
}
// one panel per case: how many you hold, OPEN, and BUY for cases that have a shard price
function renderCaseBoxes(){
  const box=$('caseBoxes');box.textContent='';
  for(const id of CASE_IDS){const C=CASES[id],n=caseCount(id),d=document.createElement('div');d.className='cbox';d.style.setProperty('--cc',C.col);
    const nm=document.createElement('span');nm.textContent=C.name;const b=document.createElement('b');b.textContent=n;
    const how=document.createElement('i');how.textContent=C.how;const bt=document.createElement('div');bt.className='btns';
    const op=document.createElement('button');op.type='button';op.className='go';op.textContent='OPEN';op.dataset.open=id;op.disabled=n<1||lockBusy;bt.append(op);
    if(C.cost){const buy=document.createElement('button');buy.type='button';buy.className='ghost';buy.textContent=`BUY · ${C.cost} SHARDS`;buy.dataset.buy=id;buy.disabled=locker.shards<C.cost||lockBusy;bt.append(buy)}
    d.append(nm,b,how,bt);box.append(d)}
  $('shardTxt').textContent=`${locker.shards} shard${locker.shards===1?'':'s'} · duplicates and leftover run salvage turn into shards`;
}
function renderLocker(){
  renderCaseBoxes();
  document.querySelectorAll('#lockTabs button').forEach(b=>b.classList.toggle('sel',b.dataset.cat===lockCat));
  const grid=$('lockGrid');grid.textContent='';let sec='';
  const ord=c=>c.box?1+CASE_IDS.indexOf(c.box):0;   // free and unlockable items first, then each case's own section
  for(const c of COS.filter(c=>c.cat===lockCat).sort((a,b)=>ord(a)-ord(b))){
    if(c.box&&c.box!==sec){sec=c.box;const h=document.createElement('div');h.className='gsec';h.style.setProperty('--cc',CASES[c.box].col);h.textContent=CASES[c.box].name;grid.append(h)}
    const t=itemTile(c);
    t.addEventListener('click',()=>{if(!owns(c.id))return;locker.eq[c.cat]=c.key;saveLocker();renderLocker();cloudEquip(c.id)});grid.append(t)}
  const st=locker.st;$('lockHint').textContent=`Earn a supply case every 3 raids you survive and for every win. Duplicates turn into shards. So far: ${st.raids} raids held, ${st.wins} win${st.wins===1?'':'s'}, ${st.drops} raiders dropped.${locker.cloud?' Saved to your account.':''}`;
}
document.querySelectorAll('#lockTabs button').forEach(b=>b.addEventListener('click',()=>{lockCat=b.dataset.cat;renderLocker()}));
let lockBusy=false;
function buyCase(id){const C=CASES[id];if(!C||!C.cost||locker.shards<C.cost)return;
  if(locker.cloud){lockWait(true);rpc('buy_case',{p_case:id}).then(r=>{lockWait(false);if(r.ok){takeLocker(r.j);renderLocker();uiSfx('restock')}else lockMsg(r.status?sbErr(r):'Buying a case needs a connection. Your shards are safe.')});return}
  locker.shards-=C.cost;caseAdd(id,1);saveLocker();renderLocker();uiSfx('restock')}
$('caseBoxes').addEventListener('click',e=>{const b=e.target.closest('button');if(!b||b.disabled)return;initAudio();if(b.dataset.open)openCaseUI(b.dataset.open);else if(b.dataset.buy)buyCase(b.dataset.buy)});
function lockMsg(t){$('lockMsg').textContent=t||''}
function lockWait(on){lockBusy=on;renderCaseBoxes();lockMsg(on?'Talking to the quartermaster…':'')}
function cloudEquip(id){if(!locker.cloud)return;rpc('equip',{p_item:id}).then(r=>{if(r.ok)takeLocker(r.j);else if(r.status&&r.status!==401)syncLocker()})}
function openCaseUI(id='supply'){
  if(!CASES[id]||caseCount(id)<1)return;
  if(locker.cloud){lockWait(true);
    rpc('open_case_of',{p_case:id}).then(r=>{lockWait(false);
      if(!r.ok){lockMsg(r.status?sbErr(r):'Opening a case needs a connection. Your cases are safe.');renderLocker();return}
      const s=r.j.item,it=COSBY[s.id]||{...COSBY['fx:none'],id:s.id,name:s.name,r:s.rarity};
      takeLocker(r.j.locker);renderLocker();caseReel({it,dup:!!r.j.dup,box:id})});return}
  const res=openCase(id);if(!res)return;renderLocker();caseReel(res);
}
function caseReel(res){
  const ov=$('caseOv'),reel=$('reel'),WIN=29,COUNT=34,TW=94,C=CASES[res.box]||CASES.supply;
  ov.hidden=false;$('caseResult').hidden=true;$('caseEquip').hidden=true;$('caseDone').hidden=true;caseItem=null;
  $('caseEye').textContent=C.name;$('caseEye').style.color=C.col;
  reel.style.transition='none';reel.style.transform='translateX(0px)';reel.textContent='';
  const rs=[];for(let i=0;i<COUNT;i++){const it=i===WIN?res.it:rollCase(res.box||'supply'),t=itemTile(it);rs.push(it.r);t.classList.remove('lock','eq');t.querySelector('i').textContent=RAR[it.r].n;t.tabIndex=-1;reel.append(t)}
  const wrapW=reel.parentElement.clientWidth,target=WIN*TW+44-wrapW/2+(rnd()-.5)*50;
  const dur=matchMedia('(prefers-reduced-motion: reduce)').matches?.6:4.2,t0=performance.now();
  requestAnimationFrame(()=>requestAnimationFrame(()=>{reel.style.transition=`transform ${dur}s cubic-bezier(.08,.72,.16,1)`;reel.style.transform=`translateX(${-target}px)`}));
  let lastIdx=-1;const tick=()=>{if(ov.hidden)return;let tx=0;try{tx=new DOMMatrix(getComputedStyle(reel).transform).m41}catch(e){}
    const idx=Math.floor((-tx+wrapW/2)/TW);if(idx!==lastIdx){lastIdx=idx;caseTick(rs[idx])}
    if(performance.now()-t0<dur*1000)requestAnimationFrame(tick)};requestAnimationFrame(tick);
  setTimeout(()=>{
    const it=res.it,R=RAR[it.r];caseItem=it;
    $('caseName').textContent=it.name;$('caseName').style.color=R.col;$('caseName').classList.toggle('gold',it.r==='g');
    $('caseSub').textContent=`${R.n} ${CATN[it.cat]}`+(res.dup?` · already owned, +${R.sh} shard${R.sh>1?'s':''}`:' · new');
    $('caseResult').hidden=false;$('caseEquip').hidden=locker.eq[it.cat]===it.key;$('caseDone').hidden=false;
    uiSfx(it.r==='l'||it.r==='e'||it.r==='g'?'win':'restock');if(it.r==='g')uiSfx('kx_bubbles');buzz(it.r==='g'?[40,60,40,60,90]:40);
  },dur*1000+120);
}
$('caseEquip').addEventListener('click',()=>{if(caseItem&&owns(caseItem.id)){locker.eq[caseItem.cat]=caseItem.key;saveLocker();cloudEquip(caseItem.id)}$('caseOv').hidden=true;lockCat=caseItem?caseItem.cat:lockCat;renderLocker()});
$('caseDone').addEventListener('click',()=>{$('caseOv').hidden=true;renderLocker()});

/* ---------- armory screen ---------- */
let armSig='';
function tryArmory(){const p=player;if(!shopOpen(p))return;if(!nearStake(p)){toast('ARMORY',game.pvp?'Walk back to your stake to spend salvage.':'Walk back to the stake to spend salvage.');return}openArmory()}
function openArmory(){$('armEyebrow').textContent=game.pvp?'ARMORY · AT YOUR STAKE':'ARMORY · BETWEEN RAIDS';$('armory').hidden=false;if(NET.mode==='solo')game.paused=true;freeSticks();renderArmory()}
function closeArmory(){if($('armory').hidden)return;$('armory').hidden=true;if(NET.mode==='solo'&&$('pause').hidden)game.paused=false}
const armorySig=p=>p.sal+'|'+upStr(p)+'|'+canShop(p)+'|'+(game.dellLv|0)+'|'+(cores[0]?Math.ceil(cores[0].hp):'');
function renderArmory(){
  const p=player;if(!p)return;armSig=armorySig(p);$('armSal').textContent=p.sal|0;
  const box=$('armRows');box.textContent='';
  for(const U of UPG){
    const t=p.up[U.k],row=document.createElement('div');row.className='arow';
    const b=document.createElement('b');b.textContent=U.name;
    const pips=document.createElement('div');pips.className='pips';for(let n=0;n<4;n++){const sp=document.createElement('span');if(n<t)sp.className='on';pips.append(sp)}
    const i=document.createElement('i');i.textContent=U.what;
    const btn=document.createElement('button');btn.type='button';
    if(t>=4){btn.textContent='MAXED';btn.disabled=true}
    else{btn.textContent=U.cost[t]+' SAL';btn.disabled=p.sal<U.cost[t]||!canShop(p)}
    btn.setAttribute('aria-label',`${U.name} level ${t} of 4. ${t>=4?'Maxed':'Costs '+U.cost[t]+' salvage'}`);
    btn.addEventListener('click',()=>{initAudio();if(NET.mode==='guest'){NET.toHost({t:'u',k:U.k});btn.disabled=true}else if(buyUpgrade(p,U.k))renderArmory()});
    row.append(b,btn,pips,i);box.append(row);
  }
  if(game.pvp)return;
  const extra=(name,lvl,what,label,dis,aria,k)=>{
    const row=document.createElement('div');row.className='arow';
    const b=document.createElement('b');b.textContent=name;
    const pips=document.createElement('div');pips.className='pips';if(lvl>=0)for(let n=0;n<4;n++){const sp=document.createElement('span');if(n<lvl)sp.className='on';pips.append(sp)}
    const i=document.createElement('i');i.textContent=what;
    const btn=document.createElement('button');btn.type='button';btn.textContent=label;btn.disabled=dis;btn.setAttribute('aria-label',aria);
    btn.addEventListener('click',()=>{initAudio();if(NET.mode==='guest'){NET.toHost({t:'u',k});btn.disabled=true}else if(buyUpgrade(p,k))renderArmory()});
    row.append(b,btn,pips,i);box.append(row)};
  const L=game.dellLv|0;
  extra(DELL_UP.name,L,DELL_UP.what,L>=4?'MAXED':DELL_UP.cost[L]+' SAL',L>=4||p.sal<DELL_UP.cost[L]||!canShop(p),`Dell level ${L} of 4. ${L>=4?'Maxed':'Costs '+DELL_UP.cost[L]+' salvage'}`,'dell');
  const c=cores[0];
  if(c){const hp=Math.max(0,Math.ceil(c.hp)),full=c.hp>=c.max,cost=coreFixCost(p);
    extra('REPAIR CORE',-1,`Core ${hp} / ${c.max}. Each repair restores up to ${CORE_FIX.hp}.${p.C.repair?' Half price for you.':''}`,full?'FULL':cost+' SAL',full||c.hp<=0||p.sal<cost||!canShop(p),full?'Core is at full health':`Repair core, ${cost} salvage`,'core')}
}
$('armClose').addEventListener('click',closeArmory);

