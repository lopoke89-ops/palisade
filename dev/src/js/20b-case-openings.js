/* One/five case sessions: rewards commit before animation, retry IDs survive reloads. */
const OPEN_KEY='palisade.case-opening.v1',CASE_ART_LIMIT=64,caseArt=new Map();
let caseSession=null,caseArtLook='',caseRecovering=false,caseRecoveredOperation='';
const openingStorageKey=owner=>OPEN_KEY+'.'+owner;
function pendingOpening(){const owner=locker.cloud?myUid():'local',p=readJSON(openingStorageKey(owner)).v;return p&&p.owner===owner?p:null}
function caseBusy(){return !!caseSession||!!pendingOpening()}
function openingID(){return crypto.randomUUID?crypto.randomUUID():'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g,c=>{const n=Math.random()*16|0;return(c==='x'?n:(n&3|8)).toString(16)})}
function localCases(id,quantity,operation){
  const saved=readJSON(LOCK_KEY).v;if(saved&&(saved.at||0)>(locker.at||0)&&!saved.cloud)locker=normLocker(saved);
  if(locker.lastOpening?.operation===operation)return locker.lastOpening.results.map(r=>({...r,it:COSBY[r.id],box:id}));
  if(!CASES[id]||![1,5].includes(quantity)||caseCount(id)<quantity)throw Error('Not enough cases for this opening.');
  const next=normLocker(JSON.parse(JSON.stringify(locker))),results=[];
  if(id==='supply')next.cases-=quantity;else next.bag[id]-=quantity;
  for(let i=0;i<quantity;i++){const it=rollCase(id),dup=next.owned.includes(it.id),shards=dup?RAR[it.r].sh:0;
    if(dup)next.shards+=shards;else next.owned.push(it.id);results.push({id:it.id,dup,shards})}
  next.lastOpening={operation,case:id,quantity,results};next.at=Math.max(Date.now(),(locker.at||0)+1);
  // One atomic storage write contains both the inventory and its receipt. Failure grants nothing.
  localStorage.setItem(LOCK_KEY,JSON.stringify(next));locker=next;keepStorage();
  return results.map(r=>({...r,it:COSBY[r.id],box:id}));
}
async function commitCases(p){
  if(p.owner==='local')return navigator.locks? navigator.locks.request('palisade-case-opening',()=>localCases(p.case,p.quantity,p.operation)):localCases(p.case,p.quantity,p.operation);
  const r=await rpc('open_cases_v0962',{p_case:p.case,p_quantity:p.quantity,p_operation:p.operation});
  if(!r.ok){const e=Error(r.status?sbErr(r):'Opening is awaiting confirmation. Reconnect and resume; your opening ID is saved.');e.uncertain=!r.status||r.status>=500||r.status===401;throw e}
  if(myUid()!==p.owner)throw Object.assign(Error('Sign back into the account that started this opening to resume.'),{uncertain:true});
  takeLocker(r.j.locker);
  return r.j.results.map(r=>({it:COSBY[r.item.id]||{...COSBY['fx:none'],...r.item,r:r.item.rarity},dup:r.dup,shards:r.shards,box:p.case}));
}
function clearCaseAnimation(){
  if(caseSession){cancelAnimationFrame(caseSession.frame);clearTimeout(caseSession.timer);caseSession.cancelIntro?.();caseSession.cancelIntro=null}
  $('caseIntro').onclick=null;caseIntroOn=false;
}
function closeCaseOpening(ack=true){
  clearCaseAnimation();const p=caseSession?.pending;
  if(ack&&caseSession?.results){if(pendingOpening()?.operation===p?.operation)try{localStorage.removeItem(openingStorageKey(p.owner))}catch(e){}
    if(locker.lastOpening?.operation===p?.operation){locker.lastOpening.acknowledged=true;saveLocker()}}
  caseSession=null;$('caseOv').hidden=true;$('caseOv').classList.remove('intro','blurring','batch');
  $('caseRows').replaceChildren();$('reel').replaceChildren();$('caseResults').replaceChildren();$('caseResult').hidden=true;renderLocker();
}
async function openCaseUI(id='supply',quantity=1,resume=false){
  if(caseSession||lockBusy||!CASES[id]||![1,5].includes(quantity))return;
  let p=pendingOpening();
  if(p&&!resume){lockMsg('Resume the saved opening before starting another.');return}
  if(!p){if(caseCount(id)<quantity||locker.cloud&&!myUid())return;p={owner:locker.cloud?myUid():'local',operation:openingID(),case:id,quantity};
    try{localStorage.setItem(openingStorageKey(p.owner),JSON.stringify(p))}catch(e){lockMsg('This opening needs working save storage. Free some space and try again.');return}}
  const session=caseSession={pending:p,results:null,frame:0,timer:0,cancelIntro:null};
  caseRecoveredOperation=p.operation;$('caseName').hidden=false;$('caseSub').hidden=false;$('caseResults').replaceChildren();$('caseRows').replaceChildren();
  $('caseOv').classList.toggle('batch',p.quantity===5);$('caseSkip').hidden=false;$('caseSkip').textContent='SKIP ANIMATION';$('caseResume').hidden=true;
  const intro=caseIntro(p.case);renderCaseBoxes();
  try{
    const results=await commitCases(p);session.results=results;renderLocker();await intro;
    if(caseSession!==session)return;
    if(session.skip)caseReveal(results);else caseReel(results);
  }catch(e){
    clearCaseAnimation();if(caseSession!==session)return;
    if(!e.uncertain){try{localStorage.removeItem(openingStorageKey(p.owner))}catch(_){}caseSession=null;$('caseOv').hidden=true;renderLocker();lockMsg(e.message)}
    else{$('caseOv').hidden=false;$('caseResult').hidden=false;$('caseName').textContent='OPENING SAVED';$('caseSub').textContent=e.message;$('caseSkip').hidden=true;$('caseResume').hidden=false;$('caseDone').hidden=false;renderCaseBoxes()}
  }
}
function resumeCaseOpening(){if(caseSession)return;const p=pendingOpening();if(p)openCaseUI(p.case,p.quantity,true)}
function recoverCaseOpening(){
  if(caseSession||caseRecovering||$('pg-locker').hidden)return;
  const p=pendingOpening();if(!p||caseRecoveredOperation===p.operation)return;caseRecoveredOperation=p.operation;caseRecovering=true;queueMicrotask(()=>{caseRecovering=false;resumeCaseOpening()});
}
function caseArtURL(it){
  const look=lockerThumbKey();if(caseArtLook!==look){caseArt.clear();caseArtLook=look}
  const key=it.id;if(caseArt.has(key))return caseArt.get(key);
  const cv=document.createElement('canvas');cv.width=cv.height=64;drawIcon(cv,it);const url=cv.toDataURL();cv.width=cv.height=0;
  if(caseArt.size>=CASE_ART_LIMIT)caseArt.delete(caseArt.keys().next().value);caseArt.set(key,url);return url;
}
function caseTile(it){const d=document.createElement('div');d.className='item';d.dataset.item=it.id;d.style.setProperty('--rc',RAR[it.r].col);
  const img=document.createElement('img');img.src=caseArtURL(it);img.width=img.height=52;img.alt='';const b=document.createElement('b');b.textContent=it.name;
  const r=document.createElement('i');r.textContent=RAR[it.r].n;d.append(img,b,r);return d}
function prepareCaseReels(results){
  const s=caseSession;if(s.reels)return s.reels;const batch=results.length===5,WIN=batch?9:29,COUNT=batch?13:34,TW=94;
  $('caseRows').replaceChildren();$('caseResult').hidden=true;$('caseEquip').hidden=true;$('caseDone').hidden=true;
  const filler=Array.from({length:COUNT},()=>rollCase(results[0].box)),rows=[];
  for(let row=0;row<results.length;row++){
    let reel;if(row===0)reel=$('reel');else{const wrap=document.createElement('div');wrap.className='reelWrap';reel=document.createElement('div');reel.className='reel';wrap.append(reel);$('caseRows').append(wrap)}
    reel.dataset.win=WIN;reel.style.transition='none';reel.style.transform='translateX(0px)';reel.replaceChildren();
    for(let i=0;i<COUNT;i++)reel.append(caseTile(i===WIN?results[row].it:filler[i]));rows.push(reel);
  }
  const width=$('reel').parentElement.clientWidth,target=WIN*TW+44-width/2;
  return s.reels={rows,WIN,TW,filler,width,target};
}
function caseReel(results){
  const s=caseSession;if(!s||s.revealed)return;
  const {rows,WIN,TW,filler,width,target}=prepareCaseReels(results);
  const dur=matchMedia('(prefers-reduced-motion: reduce)').matches?.6:4.2,t0=performance.now();
  let lastIdx=-1;
  const tick=now=>{if(caseSession!==s||$('caseOv').hidden)return;if(!s.reelStarted){s.reelStarted=true;for(const reel of rows){reel.style.transition=`transform ${dur}s cubic-bezier(.08,.72,.16,1)`;reel.style.transform=`translateX(${-target}px)`}}const p=Math.min(1,(now-t0)/(dur*1000));let q=p;
    for(let i=0;i<4;i++){const u=1-q,x=3*.08*u*u*q+3*.16*u*q*q+q*q*q,dx=3*.08*u*u+6*(.16-.08)*u*q+3*(1-.16)*q*q;q=Math.min(1,Math.max(0,q-(x-p)/dx))}
    const y=3*.72*(1-q)*(1-q)*q+3*(1-q)*q*q+q*q*q,index=Math.floor((target*y+width/2)/TW);
    if(index!==lastIdx){lastIdx=index;caseTick((index===WIN?results[0].it:filler[index])?.r)}
    if(p<1)s.frame=requestAnimationFrame(tick);
  };
  // One shared audio scheduler for every row. Transforms animate in CSS.
  s.frame=requestAnimationFrame(tick);s.timer=setTimeout(()=>{if(caseSession===s)caseReveal(results)},dur*1000+120);
}
function caseReveal(results){
  const s=caseSession;if(!s||s.revealed)return;clearCaseAnimation();
  const {rows,target}=prepareCaseReels(results);
  for(const reel of rows){reel.style.transition='none';reel.style.transform=`translateX(${-target}px)`}
  s.revealed=true;$('caseResult').hidden=false;$('caseDone').hidden=false;$('caseSkip').hidden=true;
  $('caseResults').replaceChildren();const batch=results.length===5;
  $('caseName').hidden=batch;$('caseSub').hidden=batch;caseItem=batch?null:results[0].it;
  if(!batch){const res=results[0],it=res.it,R=RAR[it.r];$('caseName').textContent=it.name;$('caseName').style.color=R.col;$('caseName').classList.toggle('gold',it.r==='g');$('caseName').classList.toggle('ultimate',it.r==='u');
    $('caseSub').textContent=`${R.n} ${CATN[it.cat]}`+(res.dup?` · already owned, +${res.shards} shards`:' · new');$('caseEquip').hidden=!canCaseEquip(res)}
  else for(const res of results){const it=res.it,R=RAR[it.r],d=document.createElement('div');d.className='caseResultRow';d.dataset.item=it.id;
    const text=document.createElement('span'),b=document.createElement('b'),sub=document.createElement('small');b.textContent=it.name;b.style.color=R.col;sub.textContent=R.n+(res.dup?` · DUPLICATE · +${res.shards} SHARDS`:' · NEW');text.append(b,sub);d.append(text);
    if(canCaseEquip(res)){const eq=document.createElement('button');eq.type='button';eq.className='ghost';eq.textContent='EQUIP';eq.onclick=()=>{equipCaseItem(it);eq.disabled=true;eq.textContent='EQUIPPED'};d.append(eq)}$('caseResults').append(d)}
  const best=results.slice().sort((a,b)=>RAR[b.it.r].sh-RAR[a.it.r].sh)[0].it;uiSfx('legu'.includes(best.r)?'win':'restock');buzz(best.r==='g'||best.r==='u'?[40,60,40]:40);
}
function canCaseEquip(res){const it=res.it;return !res.dup&&owns(it.id)&&locker.eq[it.cat]!==it.key&&(it.cat!=='hat'||headwearAllowed(locker.eq.skin,it.key))}
function equipCaseItem(it){if(!owns(it.id)||it.cat==='hat'&&!headwearAllowed(locker.eq.skin,it.key))return;locker.eq[it.cat]=it.key;saveLocker();cloudEquip(it.id)}
$('caseEquip').addEventListener('click',()=>{const it=caseItem;if(it){equipCaseItem(it);lockCat=it.ladder?'ms':it.cat;if(it.box)lockOpen.add(lockCat+':'+it.box)}closeCaseOpening();
  if(it){const tile=[...$('lockGrid').querySelectorAll('.item')].find(t=>t.dataset.item===it.id);if(tile){tile.scrollIntoView({block:'nearest'});tile.focus({preventScroll:true})}}});
$('caseDone').addEventListener('click',()=>closeCaseOpening());
$('caseSkip').addEventListener('click',()=>{if(!caseSession)return;caseSession.skip=true;caseSession.cancelIntro?.();if(caseSession.results)caseReveal(caseSession.results)});
$('caseResume').addEventListener('click',()=>{clearCaseAnimation();caseSession=null;resumeCaseOpening()});
