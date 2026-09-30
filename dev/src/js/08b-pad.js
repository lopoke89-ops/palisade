/* ================= controller (v0.9.2.1) ================= */
// One table says what every in-game action is on a controller. The keyboard keeps its own keys (08-input.js);
// the controller reads this table, and the player can change it in Settings (saved in palisade.pad.v1).
// Button numbers are the browser's "standard" layout, the same on Xbox, PlayStation and most others.
const PB={A:0,B:1,X:2,Y:3,LB:4,RB:5,LT:6,RT:7,VIEW:8,MENU:9,LS:10,RS:11,UP:12,DOWN:13,LEFT:14,RIGHT:15,HOME:16};
// [id, what Settings calls it, default button]. -1 = not on a button until the player puts it on one.
const PAD_ACTIONS=[['fire','FIRE',PB.RT],['nade','GRENADE',PB.LT],['build','BUILD',PB.A],['special','ABILITY / SPRINT',PB.B],
  ['armory','ARMORY',PB.X],['piece','WALL / DOOR',PB.Y],['matPrev','MATERIAL BACK',PB.LEFT],['matNext','MATERIAL NEXT',PB.RIGHT],
  ['kit','BUILD KIT',PB.DOWN],['start','START RAID',PB.VIEW],['reload','RELOAD',-1]];
const PAD_KEY='palisade.pad.v1';
const padDefaults=()=>Object.fromEntries(PAD_ACTIONS.map(a=>[a[0],a[2]]));
let padMap=padDefaults();
try{const s=JSON.parse(localStorage.getItem(PAD_KEY)||'{}');if(s&&s.map)for(const[a]of PAD_ACTIONS)if(Number.isInteger(s.map[a])&&s.map[a]>=-1&&s.map[a]<=17&&s.map[a]!==PB.MENU)padMap[a]=s.map[a]}catch(e){}
function savePad(){try{localStorage.setItem(PAD_KEY,JSON.stringify({map:padMap}))}catch(e){}}
// what each button is called on the controller in hand
const GLYPH={xbox:['A','B','X','Y','LB','RB','LT','RT','VIEW','MENU','LS','RS','▲','▼','◀','▶','HOME'],
  ps:['✕','○','□','△','L1','R1','L2','R2','CREATE','OPTIONS','L3','R3','▲','▼','◀','▶','PS']};
const padKind=id=>/054c|playstation|dualshock|dualsense|ps[345]/i.test(id||'')?'ps':'xbox';
const glyph=b=>b<0||b==null?'—':(GLYPH[pad.kind]||GLYPH.xbox)[b]||('B'+b);
const padKey=a=>glyph(padMap[a]);

const pad={n:0,idx:-1,kind:'xbox',mx:0,my:0,ax:0,ay:0,amag:0,fire:false,prev:[],el:null,navDir:'',navT:0,buildT:0,scan:0,bindAct:null,bindWait:false,bindT:0};
let padMode=false;   // true while the controller is the last thing used; any touch, click, mouse move or key hands back
addEventListener('gamepadconnected',e=>{pad.n++;const gp=e.gamepad;if(gp&&pad.idx<0){pad.idx=gp.index;pad.kind=padKind(gp.id)}renderPadSet()});
addEventListener('gamepaddisconnected',e=>{pad.n=Math.max(0,pad.n-1);if(!e.gamepad||e.gamepad.index===pad.idx){pad.idx=-1;if(padMode)padOff()}renderPadSet()});
function padRead(){
  let gs;try{gs=navigator.getGamepads?navigator.getGamepads():[]}catch(e){return null}
  let gp=gs&&gs[pad.idx];if(gp&&gp.connected)return gp;
  for(const x of gs||[])if(x&&x.connected){const was=pad.idx;pad.idx=x.index;pad.kind=padKind(x.id);if(was<0)renderPadSet();return x}
  if(pad.idx>=0){pad.idx=-1;renderPadSet()}return null;
}
// a stick's dead middle is ignored, and the rest is stretched back to 0..1
function deadzone(x,y,d){const l=Math.hypot(x,y);if(l<d)return[0,0,0];const m=Math.min(1,(l-d)/(1-d));return[x/l*m,y/l*m,m]}
function padOn(){padMode=true;touchMode=false;freeSticks();mouse.seen=false;mouse.down=false;document.body.classList.add('pad');padHints()}
function padOff(){padMode=false;pad.fire=false;document.body.classList.remove('pad');if(pad.el){pad.el.classList.remove('padF');pad.el=null}padHints()}
addEventListener('keydown',e=>{if(e.isTrusted&&padMode)padOff()},true);
addEventListener('pointerdown',e=>{if(e.isTrusted&&padMode){if(e.pointerType==='touch'||e.pointerType==='pen')touchMode=true;padOff()}},true);   // a finger anywhere, menus included, brings the touch controls back
let lastMX=null,lastMY=0;   // the mouse takes over once it really moves, not when a desk bump nudges it
addEventListener('mousemove',e=>{if(!e.isTrusted)return;if(padMode&&lastMX!==null&&Math.abs(e.clientX-lastMX)+Math.abs(e.clientY-lastMY)>6)padOff();lastMX=e.clientX;lastMY=e.clientY},true);

// called at the top of every frame. With no controller ever seen it only looks once a second, so phones pay nothing.
function padTick(now){
  if(!navigator.getGamepads)return;
  if(pad.idx<0&&!pad.n){if(now-pad.scan<1000)return;pad.scan=now}
  const gp=padRead();if(!gp){pad.fire=false;if(pad.bindAct&&now>pad.bindT){pad.bindAct=null;renderPadSet()}return}
  const B=gp.buttons||[],a=gp.axes||[],cur=[];
  for(let i=0;i<B.length;i++){const b=B[i];cur[i]=!!b&&(b.pressed||b.value>.35)}
  const hit=i=>i>=0&&!!cur[i]&&!pad.prev[i];
  const lx=a[0]||0,ly=a[1]||0,rx=a[2]||0,ry=a[3]||0;
  [pad.mx,pad.my]=deadzone(lx,ly,.2);[pad.ax,pad.ay,pad.amag]=deadzone(rx,ry,.25);
  if(!padMode&&(cur.some(Boolean)||Math.hypot(lx,ly)>.5||Math.hypot(rx,ry)>.5)){padOn();pad.prev=cur;pad.navDir='x';if(inMenus())menuPad([],()=>false,now,0,0,0);return}   // the first touch only wakes it
  const inM=padMode&&inMenus();if(inM!==pad.menuOn){pad.menuOn=inM;document.body.classList.toggle('padMenu',inM)}
  if(inM){const sc=navScope();if(sc!==pad.scope){pad.scope=sc;padHints()}}
  if(padMode){
    if(pad.bindAct)padBindTick(cur,hit,now);
    else if(inMenus()){pad.fire=false;menuPad(cur,hit,now,lx,ly,ry)}
    else gamePad(cur,hit,now);
  }
  pad.prev=cur;
}
const inMenus=()=>!playing()||overlayOpen()||chatOpen()||!!(player&&!player.alive&&!$('respawnJobs').hidden);

/* ---- playing ---- */
function gamePad(cur,hit,now){
  const M=padMap;
  pad.fire=!!cur[M.fire];if(hit(M.fire))mouse.pulls=(mouse.pulls+1)&255;   // one pull per trigger press, like a mouse click
  if(hit(PB.MENU)){pad.fire=false;togglePause();return}
  if(hit(M.nade))localNade();
  if(hit(M.build)){localBuild();pad.buildT=now+350}else if(cur[M.build]&&now>=pad.buildT){localBuild();pad.buildT=now+200}   // hold to keep building
  if(hit(M.special)){if(hasAbility(player))localAbility();else localSprint()}   // the phone's button next to the grenade
  if(hit(M.armory))tryArmory();
  if(hit(M.piece))game.piece=game.piece==='wall'?'door':'wall';
  if(hit(M.matPrev))game.sel=(game.sel+2)%3;
  if(hit(M.matNext))game.sel=(game.sel+1)%3;
  if(hit(M.kit))toggleBuild();
  if(hit(M.start)&&game.phase==='build'&&NET.mode!=='guest')startRaid();
  if(hit(M.reload))localReload();
}

/* ---- menus: the d-pad or left stick moves a highlight to the nearest button that way ---- */
const NAV_SEL='button,input[type=range],label.tog,select,a[href],[tabindex]:not([tabindex="-1"])';
function navScope(){
  for(const id of['saveOv','caseOv','igSet','armory','pause','over']){const el=$(id);if(el&&!el.hidden)return el}
  if(typeof dropOpen==='function'&&dropOpen())return $('friendsDrop');
  if(!$('menu').hidden)return $('menu');
  const rj=$('respawnJobs');if(rj&&!rj.hidden)return rj;
  return null;
}
function navOk(el,scope){
  if(!el||!el.isConnected||el.disabled||!scope.contains(el)||el.closest('[hidden],[inert]'))return false;
  if(el.closest('#friendsDrop')&&scope!==$('friendsDrop'))return false;   // the friends list has its own turn when it's open
  const r=el.getBoundingClientRect();if(r.width<2||r.height<2)return false;
  const cs=getComputedStyle(el);return cs.visibility!=='hidden'&&cs.pointerEvents!=='none'&&+cs.opacity!==0;
}
const navList=scope=>[...scope.querySelectorAll(NAV_SEL)].filter(el=>navOk(el,scope));
function navFocus(el){
  if(pad.el&&pad.el!==el)pad.el.classList.remove('padF');pad.el=el;if(!el)return;
  const sc=navScope();if(sc){pad.lastScope=sc;pad.lastI=navList(sc).indexOf(el)}   // so a screen that redraws (buying in the armory) keeps the spot
  el.classList.add('padF');try{el.focus({preventScroll:true})}catch(e){}
  try{el.scrollIntoView({block:'nearest',inline:'nearest'})}catch(e){}
}
function navDefault(list){
  return list.find(el=>el.classList.contains('go'))||list.slice().sort((a,b)=>{const p=a.getBoundingClientRect(),q=b.getBoundingClientRect();return(p.top-q.top)||(p.left-q.left)})[0]||null;
}
function navMove(scope,dir){
  const cur=pad.el&&navOk(pad.el,scope)?pad.el:null;
  if(!cur){navFocus(navDefault(navList(scope)));return}
  if(cur.type==='range'&&(dir==='left'||dir==='right')){navStep(cur,dir==='right'?1:-1);return}
  const[dx,dy]={up:[0,-1],down:[0,1],left:[-1,0],right:[1,0]}[dir],r=cur.getBoundingClientRect(),cx=r.left+r.width/2,cy=r.top+r.height/2;
  let best=null,bs=1e9;
  for(const el of navList(scope)){
    if(el===cur||el.contains(cur)||cur.contains(el))continue;
    const q=el.getBoundingClientRect(),ex=q.left+q.width/2,ey=q.top+q.height/2;
    if((ex-cx)*dx+(ey-cy)*dy<=2)continue;   // not that way
    const gap=Math.max(0,dx>0?q.left-r.right:dx<0?r.left-q.right:dy>0?q.top-r.bottom:r.top-q.bottom);
    const lined=dx?Math.min(q.bottom,r.bottom)>Math.max(q.top,r.top):Math.min(q.right,r.right)>Math.max(q.left,r.left);
    const off=dx?Math.abs(ey-cy):Math.abs(ex-cx),s=gap+off*(lined?.3:2)+(lined?0:60);
    if(s<bs){bs=s;best=el}
  }
  if(best)navFocus(best);
}
function navStep(el,d){const st=+el.step||1,v=Math.max(+el.min||0,Math.min(+el.max||100,(+el.value)+d*st));if(v!==+el.value){el.value=v;el.dispatchEvent(new Event('input',{bubbles:true}));el.dispatchEvent(new Event('change',{bubbles:true}))}}
function navPress(){
  const el=pad.el;if(!el)return;
  if(el.type==='range')return;
  initAudio();if(el._tap)el._tap();else el.click();
}
function navBack(){
  if(!$('menu').hidden&&!$('pg-lobby').hidden&&navScope()===$('menu'))return;   // B never walks you out of a room; LEAVE is right there
  for(const t of['keydown','keyup'])dispatchEvent(new KeyboardEvent(t,{key:'Escape'}));
}
function navPage(d){   // the bumpers flip through the lobby's pages
  if(navScope()!==$('menu'))return;
  const tabs=[...document.querySelectorAll('.partyNav [data-nav]')].filter(b=>navOk(b,$('menu')));if(!tabs.length)return;
  const pg=$('menu').dataset.page,i=Math.max(0,tabs.findIndex(b=>b.dataset.nav===pg||(pg==='lobby'&&(b.dataset.nav==='multi'||b.dataset.nav==='solo'))));
  tabs[(i+d+tabs.length)%tabs.length].click();navFocus(null);
}
function navTab(d){    // the triggers flip through tabs inside a page (locker categories, the friends list)
  const scope=navScope();if(!scope)return;
  const set=[...scope.querySelectorAll('#lockTabs,[role=tablist]')].find(el=>navOk(el.querySelector('button')||el,scope));if(!set)return;
  const bs=[...set.querySelectorAll('button')].filter(b=>navOk(b,scope));if(!bs.length)return;
  const i=Math.max(0,bs.findIndex(b=>b.classList.contains('sel')||b.getAttribute('aria-selected')==='true'));
  const nb=bs[(i+d+bs.length)%bs.length];nb.click();navFocus(nb);
}
function menuPad(cur,hit,now,lx,ly,ry){
  const scope=navScope();
  if(hit(PB.MENU)&&(!$('pause').hidden)){togglePause();return}
  if(!scope)return;
  if(scope===$('armory')&&hit(padMap.armory)){closeArmory();return}
  if(!pad.el||!navOk(pad.el,scope)){const l=navList(scope);navFocus(pad.lastScope===scope&&pad.lastI>=0&&l.length?l[Math.min(pad.lastI,l.length-1)]:navDefault(l))}
  const dir=cur[PB.UP]||ly<-.5?'up':cur[PB.DOWN]||ly>.5?'down':cur[PB.LEFT]||lx<-.5?'left':cur[PB.RIGHT]||lx>.5?'right':'';
  if(!dir)pad.navDir='';
  else if(dir!==pad.navDir){pad.navDir=dir;pad.navT=now+380;navMove(scope,dir)}
  else if(now>=pad.navT){pad.navT=now+110;navMove(scope,dir)}   // hold to keep moving
  if(hit(PB.A))navPress();
  if(hit(PB.B))navBack();
  if(hit(PB.LB)||hit(PB.RB))navPage(hit(PB.RB)?1:-1);
  if(hit(PB.LT)||hit(PB.RT))navTab(hit(PB.RT)?1:-1);
  if(Math.abs(ry)>.3){const box=pad.el&&scrollBox(pad.el);if(box)box.scrollTop+=ry*16}   // right stick scrolls long pages
}
function scrollBox(el){for(let n=el.parentElement;n&&n!==document.body;n=n.parentElement){const cs=getComputedStyle(n);if(/(auto|scroll)/.test(cs.overflowY)&&n.scrollHeight>n.clientHeight+4)return n}return null}

// keyboard: Tab stays inside an open window (pause, armory, save, case, game over, friends) instead of
// wandering onto the game's buttons behind it
addEventListener('keydown',e=>{
  if(e.key!=='Tab'||e.target&&e.target.id==='chatIn')return;const sc=navScope();if(!sc||sc===$('menu'))return;
  const l=navList(sc).filter(el=>el.tagName!=='LABEL');if(!l.length)return;
  const i=l.indexOf(document.activeElement);e.preventDefault();
  const n=i<0?(e.shiftKey?l.length-1:0):(i+(e.shiftKey?-1:1)+l.length)%l.length;l[n].focus();
},true);

/* ---- rumble: the same moments the phone vibrates for, under the same Vibration setting ---- */
function padRumble(ms){
  if(!padMode||!cfg.haptics)return;const gp=padRead(),v=gp&&gp.vibrationActuator;if(!v||!v.playEffect)return;
  const t=Array.isArray(ms)?ms.reduce((s,x)=>s+x,0):ms;
  try{const r=v.playEffect('dual-rumble',{startDelay:0,duration:Math.min(400,Math.max(60,t*1.5)),strongMagnitude:Math.min(1,t/90),weakMagnitude:Math.min(1,.3+t/120)});if(r&&r.catch)r.catch(()=>{})}catch(e){}
}

/* ---- Settings: the controller card, where buttons can be changed ---- */
function renderPadSet(){
  const box=$('padMap');if(!box)return;
  const on=pad.idx>=0;
  $('padStatus').textContent=on?`Controller connected (${pad.kind==='ps'?'PlayStation':'Xbox-style'} buttons). Pick an action, then press the button you want for it.`:'No controller found. Plug one in or pair it, then press any button on it.';
  box.innerHTML=PAD_ACTIONS.map(([a,name])=>`<button type="button" class="padRow${pad.bindAct===a?' wait':''}" data-pa="${a}"><span>${name}</span><kbd>${pad.bindAct===a?'PRESS A BUTTON':padKey(a)}</kbd></button>`).join('')+
    `<div class="padFixed"><span>MOVE <kbd>${glyph(PB.LS)}</kbd></span><span>AIM <kbd>${glyph(PB.RS)}</kbd></span><span>PAUSE <kbd>${glyph(PB.MENU)}</kbd></span></div>`;
  if(pad.el&&!pad.el.isConnected&&pad.bindAct==null){const b=box.querySelector(`[data-pa="${pad.lastPa}"]`);if(b)navFocus(b)}
  padHints();
}
$('padMap').addEventListener('click',e=>{const b=e.target.closest('[data-pa]');if(!b)return;pad.lastPa=b.dataset.pa;pad.bindAct=b.dataset.pa;pad.bindWait=padMode;pad.bindT=performance.now()+6000;renderPadSet();const nb=$('padMap').querySelector(`[data-pa="${pad.lastPa}"]`);if(nb&&padMode)navFocus(nb)});
$('padReset').addEventListener('click',()=>{padMap=padDefaults();savePad();pad.bindAct=null;renderPadSet()});
function padBindTick(cur,hit,now){
  if(now>pad.bindT){pad.bindAct=null;renderPadSet();return}
  if(pad.bindWait){if(!cur.some(Boolean))pad.bindWait=false;return}   // let go of the button that opened it first
  if(hit(PB.MENU)||hit(PB.HOME)){pad.bindAct=null;renderPadSet();return}   // MENU cancels (it stays on pause)
  const b=cur.findIndex((v,i)=>v&&!pad.prev[i]);if(b<0)return;
  const a=pad.bindAct,old=padMap[a];for(const k in padMap)if(k!==a&&padMap[k]===b)padMap[k]=old;   // a button already in use swaps over
  padMap[a]=b;savePad();pad.bindAct=null;renderPadSet();uiSfx('restock');
}

/* ---- what the screen says about the controls ---- */
// text for a hint that differs by device: touch, keyboard and mouse, or controller
const ctl=(touch,keys,padT)=>padMode?padT:touchMode?touch:keys;
// the key labels on the play buttons (desktop layout) swap to the controller's buttons
const KC_ACT={ENTER:'start',B:'kit',F:'piece',SPACE:'build',E:'armory',G:'nade',SHIFT:'special',Q:'special'};
for(const k of document.querySelectorAll('.kc'))k.dataset.k=k.textContent;
function padHints(){
  const h=$('padHint');if(h){const show=padMode;h.hidden=!show;
    if(show){const lobby=navScope()===$('menu'),t=`<span><kbd>${glyph(PB.A)}</kbd>SELECT</span><span><kbd>${glyph(PB.B)}</kbd>BACK</span>`+(lobby?`<span><kbd>${glyph(PB.LB)} ${glyph(PB.RB)}</kbd>PAGES</span><span><kbd>${glyph(PB.LT)} ${glyph(PB.RT)}</kbd>TABS</span>`:'');if(h._h!==t){h._h=t;h.innerHTML=t}}}
  for(const k of document.querySelectorAll('.kc')){const a=KC_ACT[k.dataset.k],t=!padMode?k.dataset.k:a?padKey(a):'';if(k.textContent!==t)k.textContent=t;k.hidden=padMode&&(!t||t==='—')}
  const ah=document.querySelector('#armory .armHint');if(ah)ah.textContent=padMode?`${padKey('armory')} or ${glyph(PB.B)} closes the armory.`:'E or Esc closes the armory.';
  renderPadCard();
}
function renderPadCard(){
  const c=$('padCard');if(!c)return;const on=pad.idx>=0;c.hidden=!on;if(!on)return;
  const R=(k,t)=>`<span><kbd>${k}</kbd>${t}</span>`;
  const t=R(glyph(PB.LS),'MOVE')+R(glyph(PB.RS),'AIM')+PAD_ACTIONS.filter(([a])=>padMap[a]>=0).map(([a,n])=>R(padKey(a),n)).join('')+R(glyph(PB.MENU),'PAUSE');
  if(c._h!==t){c._h=t;c.innerHTML=`<div class="padCardT">CONTROLLER</div><div class="padCardG">${t}</div>`}
}
renderPadSet();
