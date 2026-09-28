/* ================= input ================= */
let touchMode=matchMedia('(pointer: coarse)').matches;
const keys={},mouse={x:0,y:0,down:false,seen:false,pulls:0};
const stickMove={id:null,ox:0,oy:0,vx:0,vy:0,mag:0},stickAim={id:null,ox:0,oy:0,vx:0,vy:0,mag:0},SR=56;
function stickSet(s,x,y){let dx=x-s.ox,dy=y-s.oy;const l=Math.hypot(dx,dy);if(l>SR){dx*=SR/l;dy*=SR/l}s.vx=dx/SR;s.vy=dy/SR;s.mag=Math.min(1,l/SR)}
cv.addEventListener('pointerdown',e=>{
  initAudio();
  if(e.pointerType==='mouse'){touchMode=false;mouse.seen=true;mouse.x=e.clientX;mouse.y=e.clientY;if(e.button===0){mouse.down=true;mouse.pulls=(mouse.pulls+1)&255}return}
  touchMode=true;const s=e.clientX<W*.45?stickMove:stickAim;if(s.id!==null)return;
  s.id=e.pointerId;s.ox=e.clientX;s.oy=e.clientY;s.vx=s.vy=s.mag=0;try{cv.setPointerCapture(e.pointerId)}catch(_){}
  e.preventDefault();
});
cv.addEventListener('pointermove',e=>{
  if(e.pointerType==='mouse'){mouse.x=e.clientX;mouse.y=e.clientY;mouse.seen=true;return}
  if(e.pointerId===stickMove.id)stickSet(stickMove,e.clientX,e.clientY);
  if(e.pointerId===stickAim.id)stickSet(stickAim,e.clientX,e.clientY);
});
const endP=e=>{if(e.pointerType==='mouse'){mouse.down=false;return}for(const s of[stickMove,stickAim])if(e.pointerId===s.id){s.id=null;s.vx=s.vy=s.mag=0}};
cv.addEventListener('pointerup',endP);cv.addEventListener('pointercancel',endP);cv.addEventListener('lostpointercapture',endP);
const freeSticks=()=>{for(const s of[stickMove,stickAim]){s.id=null;s.vx=s.vy=s.mag=0}mouse.down=false};
// Safari can hand a touch to text selection or a system gesture and never tell the canvas it ended.
cv.addEventListener('touchstart',e=>e.preventDefault(),{passive:false});
cv.addEventListener('touchmove',e=>e.preventDefault(),{passive:false});
addEventListener('touchend',e=>{if(!e.touches.length)freeSticks()},{passive:true});
addEventListener('touchcancel',e=>{if(!e.touches.length)freeSticks()},{passive:true});
document.addEventListener('selectstart',e=>{if(!(e.target&&e.target.closest&&e.target.closest('input,textarea')))e.preventDefault()});
addEventListener('pointerdown',e=>{if(e.target&&e.target.closest&&e.target.closest('input'))return;try{const sel=getSelection();if(sel&&sel.rangeCount&&!sel.isCollapsed)sel.removeAllRanges()}catch(_){}},true);
cv.addEventListener('contextmenu',e=>e.preventDefault());
addEventListener('keydown',e=>{
  if(e.target&&e.target.tagName==='INPUT'){if(e.key==='Escape'&&e.target.id==='chatIn'){e.preventDefault();closeChat()}return}
  const k=e.key.toLowerCase();keys[k]=true;
  if((k==='e'||k==='u')&&!$('armory').hidden){closeArmory();return}
  if(k==='p'||k==='escape'){if(!$('armory').hidden)return;if(playing())togglePause();return}
  if(!playing()||overlayOpen())return;
  if((k==='t'||k==='/')&&NET.mode!=='solo'){e.preventDefault();keys[k]=false;openChat();return}
  if(k===' '){e.preventDefault();localBuild()}
  else if(k==='1'||k==='2'||k==='3')game.sel=+k-1;
  else if(k==='f')game.piece=game.piece==='wall'?'door':'wall';
  else if(k==='q'&&hasAbility(player))localAbility();   // the soldier's rocket, the sniper's stealth (co-op)
  else if(k==='g'||k==='q')localNade();
  else if(k==='shift')localSprint();
  else if(k==='r')localReload();
  else if(k==='enter'&&game.phase==='build'&&NET.mode!=='guest')startRaid();
  else if(k==='b')toggleBuild();
  else if(k==='u'||k==='e')tryArmory();
  if(['arrowup','arrowdown','arrowleft','arrowright'].includes(k))e.preventDefault();
});
addEventListener('keyup',e=>{keys[e.key.toLowerCase()]=false});
addEventListener('blur',()=>{for(const k in keys)keys[k]=false;mouse.down=false});
document.addEventListener('visibilitychange',()=>{freeSticks();if(document.hidden&&playing()&&!game.paused&&NET.mode==='solo')togglePause()});
function localReload(){const p=player;if(!p||!p.alive||!p.gun.mag||p.ammo>=p.gun.mag)return;if(NET.mode==='guest')NET.toHost({t:'rl'});else p.rlReq=true}
function tapBtn(el,fn){el.addEventListener('pointerdown',e=>{e.preventDefault();e.stopPropagation();initAudio();fn()});el.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();fn()}})}
const live=fn=>()=>{if(playing()&&!overlayOpen())fn()};
[0,1,2].forEach(m=>tapBtn($('c'+m),live(()=>{game.sel=m})));
tapBtn($('pWall'),live(()=>{game.piece='wall'}));tapBtn($('pDoor'),live(()=>{game.piece='door'}));
tapBtn($('buildBtn'),live(localBuild));tapBtn($('nadeBtn'),live(localNade));tapBtn($('sprBtn'),live(localSprint));tapBtn($('abBtn'),live(localAbility));
tapBtn($('skipBtn'),live(()=>{if(game.phase==='build'&&NET.mode!=='guest')startRaid()}));
tapBtn($('pauseBtn'),()=>{if(playing())togglePause()});
$('chatBtn').addEventListener('click',e=>{e.preventDefault();initAudio();chatOpen()?closeChat():openChat()});
cv.addEventListener('pointerdown',()=>{if(chatOpen())closeChat()},true);
$('chatBar').addEventListener('submit',e=>{e.preventDefault();sendChat($('chatIn').value);closeChat()});
for(const b of $('chatBar').querySelectorAll('.quick button'))tapBtn(b,()=>{sendChat(b.textContent);closeChat()});
$('lChatForm').addEventListener('submit',e=>{e.preventDefault();sendChat($('lChatIn').value);$('lChatIn').value=''});
function toggleBuild(){if(game.pvp==='ffa')return;cfg.build=!cfg.build;saveCfg();$('bmBtn').setAttribute('aria-pressed',String(cfg.build));hud(0)}
tapBtn($('bmBtn'),live(toggleBuild));tapBtn($('armBtn'),live(()=>tryArmory()));
const playing=()=>!demo&&(game.phase==='build'||game.phase==='raid');
const running=()=>game.phase==='build'||game.phase==='raid';
const overlayOpen=()=>game.paused||!$('pause').hidden||!$('menu').hidden||!$('armory').hidden;

