/* ---------- drawing cosmetics ---------- */
const lookOf=(cos,cls)=>playerLook({cos,cls,C:CLASSES[cls]||CLASSES.soldier,slot:0});
function drawFig(ctx,w,h,look,sc,aim,cy){
  const kg=g,ku=u,kx=camX,ky=camY,kp=heightPreview;heightPreview=true;g=ctx;u=sc;camX=w/2;camY=cy;
  try{drawPerson(0,0,Object.assign({aim:aim||{x:.9,y:.25},walk:0},look))}finally{g=kg;u=ku;camX=kx;camY=ky;heightPreview=kp}
}
// The painter shares the exact calibrated head/tail segment with gameplay and previews.
function traceSeg(ctx,x1,y1,x2,y2,st,w,t,heavy,tc=0){paintTracer(ctx,x1,y1,x2,y2,st,w,t,heavy,tc)}
// A tracer stays on the firing ray at weapon height; its tail cannot draw inside the barrel.
function tracerPoints(b,L,out={head:[0,0],tail:[0,0]}){
 const a=out.head,c=out.tail,v=b.visual;
 a[0]=(b.x-b.y)*TW2+camX;a[1]=(b.x+b.y)*TH2+camY;
 const hz=((b.z0===undefined?heightAt(b.x,b.y):bulletZ(b)-.7))*heightPx();a[1]-=hz;
 c[0]=a[0]-(b.vx-b.vy)*L*TW2;c[1]=a[1]-(b.vx+b.vy)*L*TH2+(b.zSlope||0)*Math.hypot(b.vx,b.vy)*L*heightPx();
 if(!v){a[1]-=WH*.62;c[1]-=WH*.62;return out}
 a[0]+=v[0]*u;a[1]+=v[1]*u;c[0]+=v[0]*u;c[1]+=v[1]*u;
 const mx=(v[2]-v[3])*TW2+camX,my=(v[2]+v[3])*TH2+camY-(v[4]??heightAt(v[2],v[3]))*heightPx(),dx=(b.vx-b.vy)*TW2,dy=(b.vx+b.vy)*TH2;
 if((a[0]-mx)*dx+(a[1]-my)*dy<=0)return null;
 if((c[0]-mx)*dx+(c[1]-my)*dy<0){c[0]=mx;c[1]=my}
 return out;
}
const TRACER_POINTS={head:[0,0],tail:[0,0]};
function drawTracer(b){
 const st=b.team===0?(TRAILS[TRAIL_IDS[b.tr|0]]||TRAILS.std):ENEMY_TR,L=.018*Math.min(st.len||1,2),points=tracerPoints(b,L,TRACER_POINTS);
 if(!points)return;
 const a=points.head,c=points.tail;
 const pad=24*u;if(Math.max(a[0],c[0])<-pad||Math.min(a[0],c[0])>W+pad||Math.max(a[1],c[1])<-pad||Math.min(a[1],c[1])>H+pad)return;
 traceSeg(g,a[0],a[1],c[0],c[1],st,(b.heavy?2.6:1.8)*u*(st.w||1),game.time,b.heavy,b.tc|0);
 // Time-based shedding avoids higher particle cost on faster displays.
 if(st.pk&&game.time>=(b.nextTrailFx||0)&&parts.length<520){b.nextTrailFx=game.time+.08;if(rnd()<st.pr){const h=WH*.62,p=screenToWorld(c[0],c[1]+h);ambient(p.x,p.y,h,st.pk)}}
}

function killFx(x,y,id){
  emitThin=parts.length>480?.3:parts.length>320?.6:1;try{killFxAt(x,y,id)}finally{emitThin=1}
}
function killFxAt(x,y,id){
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
    // Halloween Case
    case'bats':E(11,'bat',.55);E(3,'smoke',.3);break;
    // v0.9.4.0: Blitzkrieg
    case'hellportal':E(10,'ember',.3);E(4,'smoke',.25);ringFx(x,y,0,1.1,.5,'#ffb040','#7a0c06',2.4);ringFx(x,y,1.2,0,.9,'#ff3a0a','#1a0204',2);break;
    case'cinder':E(12,'ember',.5);E(3,'smoke',.4);break;
    case'tealslash':E(12,'tealdust',.6);break;
    case'ashbrand':E(6,'ember',.3);E(5,'smoke',.3);ringFx(x,y,0,.9,.45,'#ffd070','#5a1a0a',1.8);break;
    case'demonclaw':E(8,'ember',.4);ringFx(x,y,1,0,.6,'#c8102e','#1a0204',2.2);addShake(x,y,3);break;
    case'spider':E(1,'spider',0);ringFx(x,y,0,.75,.7,'#f0f0f8','#8a8aa0',1.1);ringFx(x,y,0,.45,.55,'#f0f0f8','#8a8aa0',.8);break;
    case'souls':E(4,'soul',.35);E(10,'gflame',.25);ringFx(x,y,0,1.3,.7,'#c8ffe0','#1ee860',2.2);addFlash({x,y,life:.2,max:.2,r:.9});break;
    // v0.9.3 class rewards
    case'rocketburst':E(10,'fire',.5);E(5,'smoke',.5);ringFx(x,y,0,1.3,.5,'#ffd070','#ff6a1a',2.4);addFlash({x,y,life:.2,max:.2,r:1});break;
    case'reticle':E(6,'glint',.7);ringFx(x,y,1.1,0,.4,'#ff6a6a','#ff2a2a',1.6);break;
    case'frag':E(10,'rock',.5);E(8,'spark');ringFx(x,y,0,1.2,.45,'#fff0c0','#8a8680',2);addFlash({x,y,life:.16,max:.16,r:.8});break;
    case'salvage':E(10,'rock',.6);E(6,'heal',.5);break;
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
  if(canShop(p)&&$('armory').hidden){const c=stakeOf(p),s=iso(c.i+.5,c.j+.5);keyCap(s[0],s[1]-WH*1.15-(game.pvp==='base'?66:52)*u,ctl('','E',padKey('armory')),touchMode&&!padMode?'TAP ARMORY':'ARMORY',null)}
  for(const o of players.values())if(o!==p&&o.downed&&(!game.pvp||(game.pvp==='base'&&o.team===p.team))){const d=dist2(o,p);if(d<2.2){const s=iso(o.x,o.y);keyCap(s[0],s[1]-34*u,'',d<1?'REVIVING · STAY CLOSE':'STAND CLOSE TO REVIVE','#a9bccb')}}
  if(!qm.gone&&!qm.alive&&dist2(qm,p)<2.2){const s=iso(qm.x,qm.y);keyCap(s[0],s[1]-34*u,'',dist2(qm,p)<1?'REVIVING DELGADO':'STAND CLOSE TO REVIVE DELGADO','#a9bccb')}
}
function drawCrosshair(p){
  let sx,sy,hot=false,faint=false;
  if(!touchMode&&!padMode&&mouse.seen){
    sx=mouse.x;sy=mouse.y;const w=screenToWorld(mouse.x,mouse.y+WH*.55);
    for(const e of foes())if(Math.hypot(e.x-w.x,e.y-w.y)<.45){hot=true;break}
  }else{
    const active=padMode?pad.amag>.2:stickAim.id!==null&&stickAim.mag>.2,a=p.aim;let d=active?Math.min(p.gun.range,4.2):2.4;faint=!active;
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
// Locker thumbnails. Figures are framed from where the model really is (measured once on a small scratch canvas:
// the whole body for skins, the head and what sits on it for headgear) and then painted straight at the canvas's
// own pixel size, so nothing is scaled up or cut off. Backgrounds are painted wide and cropped to the middle.
const THUMB_CACHE=new Map(),THUMB_SCR=document.createElement('canvas'),THUMB_ANG=.55;
function figFrame(look,part){
  const k=3,W=96*k,H=126*k,ox=48*k,oy=100*k;if(THUMB_SCR.width!==W){THUMB_SCR.width=W;THUMB_SCR.height=H}
  const x=THUMB_SCR.getContext('2d',{willReadFrequently:true});x.clearRect(0,0,W,H);
  const aura=part==='skin'&&look.aura;
  if(aura)paintAura(x,aura,ox,oy,k,1.3,1,'ground');
  paintWardrobeCharacter(x,look,THUMB_ANG,0,k,ox,oy,false);
  if(aura)paintAura(x,aura,ox,oy,k,1.3,1,'top');
  const yMax=part==='hat'?oy-25*k:aura?H:oy+12*k,d=x.getImageData(0,0,W,yMax).data;let l=W,r=-1,t=H,b=-1;
  for(let y=0;y<yMax;y++)for(let q=0;q<W;q++)if(d[(y*W+q)*4+3]>40){if(q<l)l=q;if(q>r)r=q;if(y<t)t=y;if(y>b)b=y}
  if(r<0)return{cx:0,cy:-20,s:44};
  if(part==='hat')b=Math.max(b,oy-25*k);   // the head's bottom edge
  return{cx:((l+r)/2-ox)/k,cy:((t+b)/2-oy)/k,s:Math.max(r-l,b-t)/k};
}
function drawIcon(cv2,c){
  const x=cv2.getContext('2d'),S=cv2.width;x.clearRect(0,0,S,S);
  if(c.cat==='skin'||c.cat==='hat'){
    const look=lookOf(c.cat==='skin'?{...locker.eq,skin:c.key}:{...locker.eq,skin:headwearAllowed(locker.eq.skin,c.key)?locker.eq.skin:'std',hat:c.key},pick.cls),key=c.id+'|'+pick.cls+'|'+(c.cat==='hat'?locker.eq.skin:locker.eq.hat)+'|'+S;
    let img=THUMB_CACHE.get(key);
    if(!img){const f=figFrame(look,c.cat),pad=c.cat==='hat'?(look.sahur?1.32:1.18):1.1,sc=S/(f.s*pad);img=document.createElement('canvas');img.width=img.height=S;
      const ic=img.getContext('2d'),au=c.cat==='skin'&&look.aura;   // v0.9.3: one moment of the outfit's moving effect
      if(au)paintAura(ic,au,S/2-f.cx*sc,S/2-f.cy*sc,sc,1.3,1,'ground');
      paintWardrobeCharacter(ic,look,THUMB_ANG,0,sc,S/2-f.cx*sc,S/2-f.cy*sc,false);
      if(au)paintAura(ic,au,S/2-f.cx*sc,S/2-f.cy*sc,sc,1.3,1,'top');
      if(THUMB_CACHE.size>240)THUMB_CACHE.clear();THUMB_CACHE.set(key,img)}
    x.drawImage(img,0,0);return}
  if(c.cat==='bg'){   // painted wide (16:9, like a screen) and cropped to the middle square
    const key='bg|'+c.key+'|'+S;let img=THUMB_CACHE.get(key);
    if(!img){const w=Math.round(S*16/9),o=document.createElement('canvas');o.width=w;o.height=S;drawBg(c.key,o.getContext('2d'),w,S,3);
      img=document.createElement('canvas');img.width=img.height=S;img.getContext('2d').drawImage(o,(w-S)/2,0,S,S,0,0,S,S);THUMB_CACHE.set(key,img)}
    x.drawImage(img,0,0);return}
  if(c.cat==='trail'){const st=TRAILS[c.key];x.fillStyle='#0c0b09';x.fillRect(0,0,S,S);
    if(st.cycle){for(let k=0;k<Math.min(3,st.cycle.length);k++)traceSeg(x,S*(.12+k*.27),S*.72,S*(.28+k*.27),S*.33,st,S*.04,0,false,k);return}
    for(const k of[0,1])traceSeg(x,S*(.2+k*.2),S*(.8-k*.12),S*(.62+k*.2),S*(.3-k*.12),st,S*.05*(st.w||1),k*.4,false);return}
  x.fillStyle='#0c0b09';x.fillRect(0,0,S,S);
  if(c.key==='none'){x.strokeStyle='#6e7568';x.lineWidth=S*.025;x.beginPath();x.arc(S/2,S/2,S*.2,0,Math.PI*2);x.moveTo(S*.36,S*.64);x.lineTo(S*.64,S*.36);x.stroke()}
  else paintFinish(x,c.key,.3,S/92,S/2,S*.58);
}
// grid thumbnails are painted at their displayed size × pixel ratio, a few per frame so a tab opens without a stall
const thumbQ=[];let thumbBusy=false;
// v0.9.3: a thumbnail is only painted once it scrolls into view (the Skins tab alone has about a hundred)
const thumbSeen=typeof IntersectionObserver==='function'?new IntersectionObserver(es=>{for(const e of es)if(e.isIntersecting){thumbSeen.unobserve(e.target);queueThumb(e.target,e.target._c)}},{rootMargin:'160px'}):null;
function queueThumb(cv2,c){thumbQ.push([cv2,c]);if(!thumbBusy){thumbBusy=true;requestAnimationFrame(thumbTick)}}
function thumbTick(){
  const t0=performance.now();
  while(thumbQ.length&&performance.now()-t0<10){const [cv2,c]=thumbQ.shift();if(!cv2.isConnected)continue;
    const css=cv2.clientWidth||64,px=Math.round(css*Math.min(2,devicePixelRatio||1));if(cv2.width!==px){cv2.width=cv2.height=px}drawIcon(cv2,c)}
  if(thumbQ.length)requestAnimationFrame(thumbTick);else thumbBusy=false;
}

/* ---------- locker screen ---------- */
let lockCat='skin',caseItem=null;
const lockOpen=new Set(),lockScroll=new Map();let lockRendered='';
const lockerThumbKey=()=>pick.cls+'|'+locker.eq.skin+'|'+locker.eq.hat;
function clearLockerItems(root){
  if(thumbSeen)for(const cv of root.querySelectorAll('canvas'))thumbSeen.unobserve(cv);
  root.replaceChildren();
}
function refreshItemTile(d,c){
  // A blocked hat stays equipped in the save but renders as Class Issue, so that tile shows EQUIPPED.
  const own=owns(c.id),blocked=c.cat==='hat'&&!headwearAllowed(locker.eq.skin,c.key),
    eq=!blocked&&(locker.eq[c.cat]===c.key||c.cat==='hat'&&c.key==='class'&&!headwearAllowed(locker.eq.skin,locker.eq.hat));
  d.classList.toggle('lock',!own);d.classList.toggle('eq',eq);
  d.classList.toggle('incompatible',blocked);d.setAttribute('aria-disabled',String(blocked));
  if(c.description)d.title=c.description;
  d.querySelector('i').textContent=blocked?'DOES NOT FIT THIS SKIN':eq?'EQUIPPED':own?RAR[c.r].n:c.how;
  const pr=!own&&c.src==='unlock'&&c.need?needProgress(c.need):null;
  d.setAttribute('aria-label',`${c.name}, ${RAR[c.r].n.toLowerCase()} ${CATN[c.cat].toLowerCase()}, ${blocked?'does not fit this skin':eq?'equipped':own?'owned':'locked: '+c.how+(pr?`, ${pr.have} of ${pr.need}`:'')}`);
  let bar=d.querySelector('.iprog');
  if(pr){if(!bar){bar=document.createElement('span');bar.className='iprog';bar.append(document.createElement('small'));d.append(bar)}
    bar.style.setProperty('--p',Math.round(pr.have/pr.need*100)+'%');bar.firstChild.textContent=`${pr.have} / ${pr.need}`;
  }else if(bar)bar.remove();
}
function itemTile(c,lazy){
  const d=document.createElement('button');d.type='button';d.className='item';d.dataset.item=c.id;d.style.setProperty('--rc',RAR[c.r].col);
  const art=document.createElement('span');art.className='art';const cv2=document.createElement('canvas');cv2.width=cv2.height=128;art.append(cv2);
  cv2._lockerLook=lockerThumbKey();
  if(lazy){if(thumbSeen){cv2._c=c;thumbSeen.observe(cv2)}else queueThumb(cv2,c)}else drawIcon(cv2,c);
  const b=document.createElement('b');b.textContent=c.name;const i=document.createElement('i');
  if(c.r==='g')d.classList.add('gold');
  if(c.r==='u')d.classList.add('ultimate');
  d.append(art,b,i);
  refreshItemTile(d,c);
  return d;
}
// one panel per case: how many you hold, OPEN, and BUY for cases that have a shard price
function renderCaseBoxes(){
  const box=$('caseBoxes');box.textContent='';
  // cases you hold come first; empty ones fold down to a name, a one-line how-to-earn and BUY
  for(const id of[...CASE_IDS].sort((x,y)=>(caseCount(y)>0)-(caseCount(x)>0))){const C=CASES[id],n=caseCount(id),d=document.createElement('div');d.className='cbox'+(n<1?' empty':'');d.style.setProperty('--cc',C.col);
    const nm=document.createElement('span');nm.textContent=C.name;const b=document.createElement('b');b.textContent=n;
    const how=document.createElement('i');how.textContent=C.how;const bt=document.createElement('div');bt.className='btns';
    const op=document.createElement('button');op.type='button';op.className='go';op.textContent='OPEN';op.dataset.open=id;op.disabled=n<1||lockBusy;bt.append(op);
    if(C.cost){const buy=document.createElement('button');buy.type='button';buy.className='ghost';buy.textContent=`BUY · ${C.cost} SHARDS`;buy.dataset.buy=id;buy.disabled=locker.shards<C.cost||lockBusy;bt.append(buy)}
    if(id==='supply'){const sp=locker.sp|0,s=document.createElement('button');s.type='button';s.className='ghost spBuy';s.dataset.spbuy='1';s.disabled=sp<SP_CASE||lockBusy;   // v0.9.3.9
      const armed=Date.now()-spArmed<3000;s.textContent=armed?`TAP AGAIN · SPEND ${SP_CASE} SKILL POINTS`:`BUY · ${SP_CASE} SKILL POINTS (${sp})`;
      s.title=sp<SP_CASE?`You have ${sp} skill point${sp===1?'':'s'}. Earn them by holding raids (1 per 5) and beating bosses.`:`Trade ${SP_CASE} unspent skill points for a Supply Case`;s.setAttribute('aria-label',s.textContent+'. '+s.title);bt.append(s)}
    d.append(nm,b,how,bt);box.append(d)}
  $('shardTxt').textContent=`${locker.shards} shard${locker.shards===1?'':'s'} · duplicates and leftover run salvage turn into shards`;
}
// v0.9.3: how far a counter has got toward an unlock's goal (the first counter it needs)
function needProgress(need){const k=Object.keys(need)[0];if(!k)return null;const n=need[k];return{key:k,have:Math.min(n,locker.st[k]|0),need:n}}
function lockerTile(c){
  const t=itemTile(c,true);t.addEventListener('click',()=>{if(!owns(c.id))return;if(c.cat==='hat'&&!headwearAllowed(locker.eq.skin,c.key)){toast('HEADGEAR DOES NOT FIT','Choose a skin with a standard head shape.');return}locker.eq[c.cat]=c.key;saveLocker();renderLocker();cloudEquip(c.id)});return t;
}
function setCollectionOpen(section,open){
  const button=section.firstChild,body=section.lastChild,key=section.dataset.collection;
  button.setAttribute('aria-expanded',String(open));body.hidden=!open;
  button.querySelector('.collectionArrow').textContent=open?'−':'+';
  if(open){lockOpen.add(key);if(!body.childElementCount)for(const c of section._items)body.append(lockerTile(c))}
  else{lockOpen.delete(key);clearLockerItems(body)}
}
function lockerCollection(id,items){
  const C=CASES[id],section=document.createElement('section'),button=document.createElement('button'),body=document.createElement('div');
  section.className='lockerCollection';section.dataset.collection=lockCat+':'+id;section._items=items;section.style.setProperty('--cc',C.col);
  button.type='button';button.className='collectionToggle';button.id='collection-'+lockCat+'-'+id;
  body.id=button.id+'-items';body.className='collectionItems';body.setAttribute('role','group');body.setAttribute('aria-labelledby',button.id);
  button.setAttribute('aria-controls',body.id);
  const name=document.createElement('span'),count=document.createElement('small'),arrow=document.createElement('span');
  name.textContent=C.name;count.className='collectionCount';arrow.className='collectionArrow';arrow.setAttribute('aria-hidden','true');button.append(name,count,arrow);
  button.addEventListener('click',()=>setCollectionOpen(section,button.getAttribute('aria-expanded')!=='true'));
  section.append(button,body);setCollectionOpen(section,lockOpen.has(section.dataset.collection));return section;
}
function renderLocker(){
  renderCaseBoxes();
  document.querySelectorAll('#lockTabs button').forEach(b=>b.classList.toggle('sel',b.dataset.cat===lockCat));renderPartyState();
  const grid=$('lockGrid');
  // Keep mounted tiles during equip/cloud refresh so scroll, focus, and unrelated art survive.
  if(lockRendered!==lockCat){
    if(lockRendered)lockScroll.set(lockRendered,grid.scrollTop);
    clearLockerItems(grid);lockRendered=lockCat;
    if(lockCat==='ms'){
      // one ladder per strip: its five unlocks side by side (swipe on a phone) so the tab is a list of ladders, not a wall of tiles
      for(const L of LADDERS){const h=document.createElement('div');h.className='gsec';h._ladder=L;h.append(document.createTextNode(L.title),document.createElement('small'));grid.append(h);
        const row=document.createElement('div');row.className='msRow';for(const [cat,key]of L.items)row.append(lockerTile(COSBY[cat+':'+key]));grid.append(row)}
    }else{
      const items=COS.filter(c=>c.cat===lockCat&&!c.ladder),plain=items.filter(c=>!c.box);
      if(plain.length){const h=document.createElement('div');h.className='gsec';h.textContent='STANDARD & UNLOCKS';grid.append(h);for(const c of plain)grid.append(lockerTile(c))}
      for(const id of CASE_IDS){const group=items.filter(c=>c.box===id);if(group.length)grid.append(lockerCollection(id,group))}
    }
    grid.scrollTop=lockScroll.get(lockCat)||0;
  }
  for(const section of grid.querySelectorAll('.lockerCollection')){
    const open=lockOpen.has(section.dataset.collection);if((section.firstChild.getAttribute('aria-expanded')==='true')!==open)setCollectionOpen(section,open);
    section.querySelector('.collectionCount').textContent=`${section._items.filter(c=>owns(c.id)).length} / ${section._items.length} owned`;
  }
  for(const h of grid.querySelectorAll('.gsec'))if(h._ladder){const L=h._ladder,got=L.items.filter(([c,k])=>owns(c+':'+k)).length;h.lastChild.textContent=`${locker.st[L.st]|0} ${L.unit} · ${got} / ${L.items.length} unlocked`}
  const look=lockerThumbKey();
  for(const t of grid.querySelectorAll('.item')){const c=COSBY[t.dataset.item];refreshItemTile(t,c);
    const cv=t.querySelector('canvas');if((c.cat==='skin'||c.cat==='hat')&&cv._lockerLook!==look){cv._lockerLook=look;
      if(thumbSeen){cv._c=c;thumbSeen.observe(cv)}else queueThumb(cv,c)}
  }
  syncBg();
  const st=locker.st;$('lockHint').textContent=`Earn a supply case every 3 raids you survive and for every win. Duplicates turn into shards. So far: ${st.raids} raids held, ${st.wins} win${st.wins===1?'':'s'}, ${st.drops} raiders dropped.${locker.cloud?' Saved to your account.':''}`;
}
document.querySelectorAll('#lockTabs button').forEach(b=>b.addEventListener('click',()=>{lockCat=b.dataset.cat;renderLocker()}));
let lockBusy=false;
// v0.9.3.9: 3 unspent skill points buy a Supply Case (no cap). Tap twice: the first tap arms it for 3 s.
// A skill-tree reset refunds only the tree's own costs, so points traded here never come back.
const SP_CASE=3;let spArmed=0;
function buyCaseSP(){
  if((locker.sp|0)<SP_CASE||lockBusy)return;
  if(Date.now()-spArmed>=3000){spArmed=Date.now();renderCaseBoxes();setTimeout(()=>{if(spArmed&&Date.now()-spArmed>=3000){spArmed=0;renderCaseBoxes()}},3050);return}
  spArmed=0;
  if(locker.cloud){lockWait(true);rpc('buy_case_sp',{}).then(r=>{lockWait(false);if(r.ok){takeLocker(r.j);renderLocker();uiSfx('restock');if(typeof renderAcct==='function')renderAcct()}else lockMsg(r.status?sbErr(r):'Trading skill points needs a connection. Your points are safe.')});return}
  locker.sp-=SP_CASE;caseAdd('supply',1);saveLocker();renderLocker();uiSfx('restock');
}
function buyCase(id){const C=CASES[id];if(!C||!C.cost||locker.shards<C.cost)return;
  if(locker.cloud){lockWait(true);rpc('buy_case',{p_case:id}).then(r=>{lockWait(false);if(r.ok){takeLocker(r.j);renderLocker();uiSfx('restock')}else lockMsg(r.status?sbErr(r):'Buying a case needs a connection. Your shards are safe.')});return}
  locker.shards-=C.cost;caseAdd(id,1);saveLocker();renderLocker();uiSfx('restock')}
$('caseBoxes').addEventListener('click',e=>{const b=e.target.closest('button');if(!b||b.disabled)return;initAudio();if(b.dataset.open)openCaseUI(b.dataset.open);else if(b.dataset.buy)buyCase(b.dataset.buy);else if(b.dataset.spbuy)buyCaseSP()});
function lockMsg(t){$('lockMsg').textContent=t||''}
function lockWait(on){lockBusy=on;renderCaseBoxes();lockMsg(on?'Talking to the quartermaster…':'')}
function cloudEquip(id){if(!locker.cloud)return;rpc('equip',{p_item:id}).then(r=>{if(r.ok)takeLocker(r.j);else if(r.status&&r.status!==401)syncLocker()})}
// Opening a case: a 3 s intro (the case shakes, the screen blurs, it breaks apart into sparks), then the reel.
// The server rolls while the intro plays; a tap skips it. Reduced motion: a short fade instead.
let caseIntroOn=false;
function caseIntro(id){
  const ov=$('caseOv'),btn=$('caseIntro'),cv=$('caseIntroCv'),x=cv.getContext('2d'),C=CASES[id]||CASES.supply;
  const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches,T=reduced?.7:3,t0=performance.now();
  ov.hidden=false;ov.classList.add('intro');btn.hidden=false;$('caseResult').hidden=true;$('caseEquip').hidden=true;$('caseDone').hidden=true;$('reel').textContent='';
  $('caseEye').textContent=C.name;$('caseEye').style.color=C.col;caseIntroOn=true;
  const crate=document.createElement('canvas');crate.width=crate.height=180;drawCaseIcon(crate,id);
  const bits=Array.from({length:46},(_,i)=>{const a=Math.PI*2*i/46+Math.random()*.3,sp=120+Math.random()*260;return{vx:Math.cos(a)*sp,vy:Math.sin(a)*sp-120,r:2+Math.random()*5,c:i%3?C.col:'#f3e9d6',rot:Math.random()*6}});
  return new Promise(done=>{
    let lastTick=0,finished=false;
    const end=()=>{if(finished)return;finished=true;caseIntroOn=false;btn.hidden=true;ov.classList.remove('intro','blurring');done()};
    btn.onclick=end;
    let lastDraw=0;   // 30 fps is plenty for a shake
    const step=now=>{if(finished)return;if(now-lastDraw<31){requestAnimationFrame(step);return}lastDraw=now;const t=(now-t0)/1000;x.clearRect(0,0,cv.width,cv.height);const cx=cv.width/2,cy=cv.height/2+10;
      if(reduced){x.globalAlpha=Math.max(0,1-t/T);x.drawImage(crate,cx-81,cy-81,162,162);x.globalAlpha=1}
      else if(t<2){   // shake, harder and faster, and the screen behind blurs from 1.2 s
        const k=Math.min(1,t/1.8),amp=2+k*9,f=10+k*26,dx=Math.sin(t*f)*amp,rot=Math.sin(t*f*1.3)*.06*k;
        if(t>1.2)ov.classList.add('blurring');
        const tick=Math.floor(t*(4+k*10));if(tick!==lastTick){lastTick=tick;caseTick(k>.6?'e':'r')}
        x.save();x.translate(cx+dx,cy);x.rotate(rot);x.shadowColor=C.col;x.shadowBlur=10+k*30;x.drawImage(crate,-81,-81,162,162);x.restore();
      }else{          // it breaks: sparks fly out and fade
        const u=t-2;if(!step.boom){step.boom=true;uiSfx('kx_confetti')}
        x.save();x.globalAlpha=Math.max(0,1-u*3);x.translate(cx,cy);x.scale(1+u*1.2,1+u*1.2);x.drawImage(crate,-81,-81,162,162);x.restore();
        for(const b of bits){const px=cx+b.vx*u,py=cy+b.vy*u+260*u*u,a=Math.max(0,1-u);x.globalAlpha=a;x.fillStyle=b.c;x.save();x.translate(px,py);x.rotate(b.rot+u*6);x.fillRect(-b.r,-b.r*.6,b.r*2,b.r*1.2);x.restore()}
        x.globalAlpha=1}
      if(t>=T||ov.hidden){end();return}requestAnimationFrame(step)};
    requestAnimationFrame(step);
  });
}
function openCaseUI(id='supply'){
  if(!CASES[id]||caseCount(id)<1||caseIntroOn||lockBusy)return;
  const intro=caseIntro(id);
  let roll;
  if(locker.cloud){lockWait(true);
    roll=rpc('open_case_v094',{p_case:id}).then(r=>{lockWait(false);
      if(!r.ok){lockMsg(r.status?sbErr(r):'Opening a case needs a connection. Your cases are safe.');renderLocker();return null}
      const s=r.j.item,it=COSBY[s.id]||{...COSBY['fx:none'],id:s.id,name:s.name,r:s.rarity};
      takeLocker(r.j.locker);renderLocker();return{it,dup:!!r.j.dup,box:id}})}
  else{const res=openCase(id);renderLocker();roll=Promise.resolve(res)}
  Promise.all([intro,roll]).then(([,res])=>{if(res&&!$('caseOv').hidden)caseReel(res);else{$('caseOv').hidden=true;renderLocker()}});   // closed during the intro: the item is already yours
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
  let lastIdx=-1;const tick=now=>{if(ov.hidden)return;const p=Math.min(1,Math.max(0,(now-t0)/(dur*1000)));
    // Mirror the CSS cubic-bezier easing without forcing a style/layout read every frame.
    let q=p;for(let i=0;i<4;i++){const u=1-q,x=3*.08*u*u*q+3*.16*u*q*q+q*q*q;const dx=3*.08*u*u+6*(.16-.08)*u*q+3*(1-.16)*q*q;q=Math.min(1,Math.max(0,q-(x-p)/dx))}
    const u=1-q,y=3*.72*(1-q)*(1-q)*q+3*(1-q)*q*q+q*q*q;
    const idx=Math.floor((target*y+wrapW/2)/TW);if(idx!==lastIdx){lastIdx=idx;caseTick(rs[idx])}
    if(p<1)requestAnimationFrame(tick)};requestAnimationFrame(tick);
  setTimeout(()=>{
    const it=res.it,R=RAR[it.r];caseItem=it;
    $('caseName').textContent=it.name;$('caseName').style.color=R.col;$('caseName').classList.toggle('gold',it.r==='g');$('caseName').classList.toggle('ultimate',it.r==='u');
    $('caseSub').textContent=`${R.n} ${CATN[it.cat]}`+(res.dup?` · already owned, +${R.sh} shard${R.sh>1?'s':''}`:' · new');
    $('caseResult').hidden=false;$('caseEquip').hidden=locker.eq[it.cat]===it.key||it.cat==='hat'&&!headwearAllowed(locker.eq.skin,it.key);$('caseDone').hidden=false;
    uiSfx('legu'.includes(it.r)?'win':'restock');if(it.r==='g')uiSfx('kx_bubbles');buzz(it.r==='g'||it.r==='u'?[40,60,40,60,90]:40);
  },dur*1000+120);
}
$('caseEquip').addEventListener('click',()=>{if(caseItem&&owns(caseItem.id)&&(caseItem.cat!=='hat'||headwearAllowed(locker.eq.skin,caseItem.key))){locker.eq[caseItem.cat]=caseItem.key;saveLocker();cloudEquip(caseItem.id)}$('caseOv').hidden=true;
  if(caseItem){lockCat=caseItem.ladder?'ms':caseItem.cat;if(caseItem.box)lockOpen.add(lockCat+':'+caseItem.box)}renderLocker();
  if(caseItem){const tile=[...$('lockGrid').querySelectorAll('.item')].find(t=>t.dataset.item===caseItem.id);if(tile){tile.scrollIntoView({block:'nearest'});tile.focus({preventScroll:true})}}
});
$('caseDone').addEventListener('click',()=>{$('caseOv').hidden=true;renderLocker()});

// a small crate in the case's colour, for the reward cards and the case intro
function drawCaseIcon(cv2,id){
  const x=cv2.getContext('2d'),S=cv2.width,C=CASES[id]||CASES.supply;x.clearRect(0,0,S,S);x.save();x.translate(S/2,S*.56);x.scale(S/100,S/100);
  const face=(pts,col)=>{x.beginPath();pts.forEach((p,i)=>i?x.lineTo(p[0],p[1]):x.moveTo(p[0],p[1]));x.closePath();x.fillStyle=col;x.fill();x.strokeStyle='#0b0a08';x.lineWidth=2.4;x.stroke()};
  face([[-34,-12],[0,-28],[34,-12],[0,4]],mix(C.col,'#ffffff',.18));face([[-34,-12],[0,4],[0,38],[-34,22]],mix(C.col,'#000000',.28));face([[0,4],[34,-12],[34,22],[0,38]],mix(C.col,'#000000',.45));
  x.strokeStyle='#1a1510';x.lineWidth=3;x.beginPath();x.moveTo(-17,-4);x.lineTo(-17,30);x.moveTo(17,-4);x.lineTo(17,30);x.stroke();
  x.fillStyle='#f3e9d6';x.beginPath();x.arc(0,-12,4,0,Math.PI*2);x.fill();x.restore();
}
/* ---------- the reward cards on the after-action screen: cases, shards, new items, then progress to the next
   Supply Case. They come in one after another over about 1.5 s; a tap shows them all at once. */
let rwRaf=0;
function showRewards(R){
  const box=$('overRewards');cancelAnimationFrame(rwRaf);box.textContent='';box.classList.remove('skip');
  if(!R){box.hidden=true;$('overLoot').classList.remove('srOnly');return}
  box.hidden=false;$('overLoot').classList.add('srOnly');
  const cards=[],card=(cls,label)=>{const d=document.createElement('div');d.className='rwCard '+cls;if(label){const b=document.createElement('b');b.textContent=label;d.append(b)}cards.push(d);return d};
  const small=(d,t)=>{const s=document.createElement('small');s.textContent=t;d.append(s)};
  if(R.pending){const d=card('rwWait','SAVING');small(d,'Sending your result to your account…')}
  else{
    for(const id of Object.keys(R.cases))if(R.cases[id]>0&&CASES[id]){const d=card('rwCase');d.style.setProperty('--cc',CASES[id].col);const cv=document.createElement('canvas');cv.width=cv.height=96;drawCaseIcon(cv,id);
      const n=document.createElement('b');n.textContent='×'+R.cases[id];d.append(cv,n);small(d,CASES[id].name)}
    if(R.kind==='match'&&R.missCase&&CASES[R.missCase]){const d=card('rwMiss','NO DROP');small(d,`${Math.round((R.chance||0)*100)}% chance of a ${CASES[R.missCase].name.toLowerCase()}`)}
    if(R.shards>0){const d=card('rwShard');const n=document.createElement('b');n.className='rwNum';n.dataset.to=R.shards;n.textContent='+0';const g=document.createElement('i');g.textContent='◆';d.append(g,n);small(d,'SHARDS')}
    if(R.sp>0){const d=card('rwShard rwSkill');const n=document.createElement('b');n.className='rwNum';n.dataset.to=R.sp;n.textContent='+0';const g=document.createElement('i');g.textContent='✦';d.append(g,n);small(d,R.sp===1?'SKILL POINT':'SKILL POINTS')}
    for(const id of R.unlocked){const c=COSBY[id];if(!c)continue;const d=card('rwNew');d.style.setProperty('--rc',RAR[c.r].col);const t=document.createElement('span');t.textContent='UNLOCKED';
      const cv=document.createElement('canvas');cv.width=cv.height=Math.round(88*Math.min(2,devicePixelRatio||1));drawIcon(cv,c);const n=document.createElement('b');n.textContent=c.name;d.append(t,cv,n)}
    // v0.9.3: the milestone this player is closest to (of the ladders they've started)
    if(R.kind==='run'){let best=null;for(const L of LADDERS){const have=locker.st[L.st]|0;if(!have)continue;const i=L.items.findIndex(([c,k])=>!owns(c+':'+k));if(i<0)continue;const f=have/L.steps[i];if(!best||f>best.f)best={L,i,f,have}}
      if(best){const{L,i,have}=best,it=COSBY[L.items[i][0]+':'+L.items[i][1]],d=card('rwProg rwMile',L.title);const bar=document.createElement('div');bar.className='rwBar';const f=document.createElement('i');bar.append(f);
        f.style.setProperty('--to',Math.min(100,have/L.steps[i]*100)+'%');d.append(bar);small(d,`${have} / ${L.steps[i]} ${L.unit} · next: ${it.name}`)}}
    if(R.kind==='run'){const d=card('rwProg','SUPPLY CASE');const bar=document.createElement('div');bar.className='rwBar';const f=document.createElement('i');bar.append(f);
      for(let k=1;k<3;k++){const m=document.createElement('u');m.style.left=(k*100/3)+'%';bar.append(m)}
      f.style.setProperty('--to',((R.prog|0)/3*100)+'%');d.append(bar);small(d,R.toNext===1?'1 more raid to the next case':`${R.toNext} more raids to the next case`)}
    if(!cards.length){const d=card('rwMiss','NO REWARDS');small(d,'Hold a raid or win to earn cases.')}
  }
  const reduced=matchMedia('(prefers-reduced-motion: reduce)').matches,step=reduced?0:Math.min(.32,1.5/Math.max(1,cards.length));
  cards.forEach((d,i)=>{d.style.animationDelay=(i*step)+'s';d.style.setProperty('--d',(i*step)+'s');box.append(d)});if(reduced)box.classList.add('skip');
  // the shard counter counts up while its card comes in
  const nums=[...box.querySelectorAll('.rwNum')],t0=performance.now();
  const tick=now=>{let busy=false;for(const n of nums){const i=cards.indexOf(n.parentElement),k=box.classList.contains('skip')?1:Math.max(0,Math.min(1,((now-t0)/1000-i*step)/.5));n.textContent='+'+Math.round(+n.dataset.to*k);if(k<1)busy=true}if(busy)rwRaf=requestAnimationFrame(tick)};
  if(nums.length)rwRaf=requestAnimationFrame(tick);
}
$('overRewards').addEventListener('click',()=>$('overRewards').classList.add('skip'));

/* ---------- armory screen ---------- */
let armSig='',armTab='upgrades',armSlot=0;
function tryArmory(){const p=player;if(p&&p.alive&&game.phase==='build'&&lockdown()){toast('ARMORY','Lockdown: the armory stays shut until the run is over.');return}if(!shopOpen(p))return;if(!nearStake(p)){toast('ARMORY',game.pvp?'Walk back to your stake to spend salvage.':'Walk back to the stake to spend salvage.');return}openArmory()}
function openArmory(){$('armEyebrow').textContent=game.pvp?'ARMORY · AT YOUR STAKE':'ARMORY · BETWEEN RAIDS';$('armory').hidden=false;if(NET.mode==='solo')game.paused=true;freeSticks();renderArmory();if(padMode)navFocus($('armRows').querySelector('button:not(:disabled)')||$('armClose'))}
function closeArmory(){if($('armory').hidden)return;$('armory').hidden=true;if(NET.mode==='solo'&&$('pause').hidden)game.paused=false}
const armorySig=p=>p.sal+'|'+upStr(p)+'|'+p.ammoEq.join(',')+'|'+p.sk+'|'+p.cls+'|'+canShop(p)+'|'+(game.dellLv|0)+'|'+(cores[0]?Math.ceil(cores[0].hp):'');
function renderArmory(){
  const p=player;if(!p)return;armSig=armorySig(p);$('armSal').textContent=p.sal|0;
  const box=$('armRows');box.textContent='';
  if(!ammoMode())armTab='upgrades';if(p.cls!=='sniper')armSlot=0;
  $('armAmmoTab').hidden=!ammoMode();$('armUpTab').setAttribute('aria-selected',armTab==='upgrades');$('armAmmoTab').setAttribute('aria-selected',armTab==='ammo');
  box.setAttribute('aria-labelledby',armTab==='ammo'?'armAmmoTab':'armUpTab');box.classList.toggle('ammoPanel',armTab==='ammo');
  if(armTab==='ammo'){
    if(p.cls==='sniper'){
      const slots=document.createElement('div');slots.className='armSlots';slots.setAttribute('role','group');slots.setAttribute('aria-label','Sniper ammo slot');
      for(let slot=0;slot<2;slot++){const btn=document.createElement('button'),id=p.ammoEq[slot];btn.type='button';btn.dataset.armSlot=slot;btn.setAttribute('aria-pressed',slot===armSlot);
        btn.textContent=`${slot+1}: ${id?AMMO_BY[id].name:'EMPTY'}`;btn.setAttribute('aria-label',`Ammo slot ${slot+1}: ${id?AMMO_BY[id].name:'empty'}`);
        btn.addEventListener('click',()=>{armSlot=slot;renderArmory();box.querySelector(`[data-arm-slot="${slot}"]`).focus({preventScroll:true})});slots.append(btn)}box.append(slots);
    }
    for(const A of AMMO){const row=document.createElement('div');row.className='arow ammoRow';row.style.setProperty('--ammo-color',A.col);
      const b=document.createElement('b');b.textContent=A.name;const i=document.createElement('i'),rank=ammoRank(p,A.id);i.textContent=ammoEffectShort(A.id,rank);i.title=ammoEffect(A.id,rank)+` · skill ${rank}/4`;
      const btn=document.createElement('button');btn.type='button';btn.dataset.armAmmo=A.id;
      const same=p.ammoEq[armSlot]===A.id,other=p.ammoEq.includes(A.id),cost=p.ammoEq[armSlot]?75:150;
      btn.textContent=same?'EQUIPPED':other?'OTHER SLOT':cost+' SAL';btn.disabled=same||other||p.sal<cost||!canShop(p);
      btn.setAttribute('aria-label',`${A.name}, ${ammoEffect(A.id,rank)}, skill ${rank} of 4, ${p.cls==='sniper'?'slot '+(armSlot+1)+', ':''}${btn.textContent}`);
      const slot=armSlot;btn.addEventListener('click',()=>{initAudio();if(NET.mode==='guest'){NET.toHost({t:'am',id:A.id,slot});btn.disabled=true}else if(buyAmmo(p,A.id,slot))renderArmory()});
      row.append(b,btn,i);box.append(row)}return;
  }
  for(const U of UPG){
    const t=p.up[U.k],row=document.createElement('div');row.className='arow';
    const b=document.createElement('b');b.textContent=U.name;const level=document.createElement('small');level.textContent=`${t}/${ARM_MAX}`;b.append(level);
    const pips=document.createElement('div');pips.className='pips';for(let n=0;n<ARM_MAX;n++){const sp=document.createElement('span');if(n<t)sp.className='on';pips.append(sp)}
    const i=document.createElement('i');i.textContent=armUpgradeSummary(U.k,t);i.title=U.what;
    const btn=document.createElement('button');btn.type='button';
    if(t>=ARM_MAX){btn.textContent='MAXED';btn.disabled=true}
    else{btn.textContent=U.cost[t]+' SAL';btn.disabled=p.sal<U.cost[t]||!canShop(p)}
    btn.setAttribute('aria-label',`${U.name} level ${t} of ${ARM_MAX}. ${i.textContent}. ${t>=ARM_MAX?'Maxed':'Costs '+U.cost[t]+' salvage'}`);
    btn.addEventListener('click',()=>{initAudio();if(NET.mode==='guest'){NET.toHost({t:'u',k:U.k});btn.disabled=true}else if(buyUpgrade(p,U.k))renderArmory()});
    row.append(b,btn,pips,i);box.append(row);
  }
  if(game.pvp)return;
  const extra=(name,lvl,what,label,dis,aria,k)=>{
    const row=document.createElement('div');row.className='arow';
    const b=document.createElement('b');b.textContent=name;if(lvl>=0){const level=document.createElement('small');level.textContent=`${lvl}/${ARM_MAX}`;b.append(level)}
    const pips=document.createElement('div');pips.className='pips';if(lvl>=0)for(let n=0;n<ARM_MAX;n++){const sp=document.createElement('span');if(n<lvl)sp.className='on';pips.append(sp)}
    const i=document.createElement('i');i.textContent=what;
    const btn=document.createElement('button');btn.type='button';btn.textContent=label;btn.disabled=dis;btn.setAttribute('aria-label',aria);
    btn.addEventListener('click',()=>{initAudio();if(NET.mode==='guest'){NET.toHost({t:'u',k});btn.disabled=true}else if(buyUpgrade(p,k))renderArmory()});
    row.append(b,btn,pips,i);box.append(row)};
  const L=game.dellLv|0;
  if(!qm.gone)extra(DELL_UP.name,L,armUpgradeSummary('dell',L),L>=ARM_MAX?'MAXED':DELL_UP.cost[L]+' SAL',L>=ARM_MAX||p.sal<DELL_UP.cost[L]||!canShop(p),`Delgado level ${L} of ${ARM_MAX}. ${L>=ARM_MAX?'Maxed':'Costs '+DELL_UP.cost[L]+' salvage'}`,'dell');
  const c=hasMod('nopatch')?null:cores[0];   // No Patch-Ups: no core repair
  if(c){const hp=Math.max(0,Math.ceil(c.hp)),full=c.hp>=c.max,cost=coreFixCost(p);
    extra('REPAIR CORE',-1,`${hp}/${c.max} HP · repairs +${CORE_FIX.hp}`,full?'FULL':cost+' SAL',full||c.hp<=0||p.sal<cost||!canShop(p),full?'Core is at full health':`Repair core, ${cost} salvage`,'core')}
}
function armUpgradeSummary(k,lv){
  const n=Math.min(ARM_MAX,lv+1),pct=v=>+(100*v).toFixed(2),steps={d:[.2,.05,'Damage'],r:[.1,.025,'Cooldown'],g:[.12,.03,'Reach'],a:[.15,.0375,'HP'],dell:[.15,.0375,'Power']};
  if(k==='n')return lv>=ARM_MAX?'+5 stock · +40% blast':`Next: +${Math.min(n,4)+(n>=8?1:0)} stock · +${pct(armBoost(n,.08,.02))}% blast`;
  const [oldStep,newStep,label]=steps[k],sign=k==='r'?'−':'+';return`${label} ${sign}${pct(armBoost(lv,oldStep,newStep))}%${lv<ARM_MAX?' → '+sign+pct(armBoost(n,oldStep,newStep))+'%':''}`;
}
const ammoEffectShort=(id,rank)=>{
  const effect=id==='ap'?`${[50,60,70,85,100][rank]}% frontal shield damage`:id==='fire'?`10 HP/s · ${3+.5*rank}s burn`:id==='blast'?`${8+2*rank} dmg · 1.25-block blast`:`${25+5*rank}% slow · 2s · 3 nearby/3 blocks`;
  return effect+` · skill ${rank}/4`;
};
for(const [id,tab] of [['armUpTab','upgrades'],['armAmmoTab','ammo']])$(id).addEventListener('click',()=>{armTab=tab;renderArmory()});
$('armClose').addEventListener('click',closeArmory);

