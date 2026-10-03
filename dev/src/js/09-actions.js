/* ================= actions ================= */
function buildTarget(p,sel,door){
  const f=p.face;let ox=Math.abs(f.x)>.38?Math.sign(f.x):0,oy=Math.abs(f.y)>.38?Math.sign(f.y):0;if(!ox&&!oy)ox=1;
  return buildEval(p,Math.floor(p.x)+ox,Math.floor(p.y)+oy,sel,door);
}
function buildEval(p,i,j,sel,door){
  const t={i,j,ok:false,act:'PLACE',mat:sel,cost:0,door,reason:''};
  if(!p.alive){t.reason='You are down';return t}
  if(!inb(i,j)){t.reason='That is the fence line';return t}
  const k=idx(i,j);
  if(game.pvp==='ffa'){t.reason='No building in free-for-all';return t}
  if(coreKs.has(k)){t.reason='That is the stake';return t}
  if(nodeAt(i,j)){t.reason='Resource in the way';return t}
  {const tb=terrNoBuild(k,!!walls[k]);if(tb){t.reason=tb;return t}}
  if(game.pvp==='base'){
    if(game.phase==='build'&&(p.team==='a'?i-j>-1:i-j<1)){t.reason='Your side of the truce line';return t}
    const ec=cores[p.team==='a'?1:0];if(Math.max(Math.abs(i-ec.i),Math.abs(j-ec.j))<=1){t.reason='Too close to their stake';return t}
  }
  const near=o=>Math.abs(o.x-(i+.5))<.77&&Math.abs(o.y-(j+.5))<.77;
  for(const e of enemies)if(near(e)){t.reason='Raider in the way';return t}
  if(!door&&!walls[k]){
    for(const o of players.values())if(o!==p&&(o.alive||o.downed)&&near(o)){t.reason=game.pvp?'Someone is in the way':'Teammate in the way';return t}
    if(!game.pvp&&near(qm)){t.reason='Delgado is standing there';return t}
  }
  const w=walls[k];
  if(!w){t.cost=door?DOOR_COST:WALL_COST;t.act=door?'DOOR':'PLACE'}
  else if(game.pvp==='base'&&w.tm&&w.tm!==p.team){t.reason=w.door?'Their door':'Their wall';return t}
  else if(sel>w.mat){t.act='UPGRADE';t.door=w.door;t.cost=w.door?DOOR_COST:WALL_COST}
  else if(w.hp<w.max-.5){t.act='REPAIR';t.mat=w.mat;t.door=w.door;t.cost=Math.max(1,Math.round((w.door?DOOR_COST:WALL_COST)*(1-w.hp/w.max)*(p.C.repair||1)))}
  else if(door!==w.door){t.act=door?'MAKE DOOR':'SEAL DOOR';t.mat=w.mat;t.cost=door?DOOR_COST-WALL_COST:0}
  else{t.act='SOLID';t.mat=w.mat;t.reason=sel<w.mat?`Already ${MAT[w.mat].name.toLowerCase()}`:'At full strength';return t}
  if(p.mats[t.mat]<t.cost){t.reason=`Need ${t.cost} ${MAT[t.mat].name.toLowerCase()}`;return t}
  t.ok=true;return t;
}
// host/solo: actually place it
function doBuild(p,i,j,sel,door){
  if(p.bcd>0)return;if(heightDist(p.x,p.y,i+.5,j+.5)>2.1||!heightRayClear(p.x,p.y,i+.5,j+.5))return;
  const t=buildEval(p,i,j,clamp(sel|0,0,2),!!door);
  if(!t.ok){personal(p,'deny');return}
  const k=idx(t.i,t.j),prev=walls[k];
  if(t.act==='REPAIR'){prev.hp=prev.max;prev.fire=0}
  else if(t.act==='MAKE DOOR'||t.act==='SEAL DOOR'){const nw=makeWall(prev.mat,t.door,prev.hp/prev.max);nw.char=prev.char;walls[k]=nw}
  else{walls[k]=makeWall(t.mat,t.door);walls[k].flash=.1;debris[k]=0}
  walls[k].crew=true;   // any wall a player has built on, fixed or changed is theirs now: it won't pay salvage
  if(game.pvp==='base')walls[k].tm=p.team;
  if(collides(p.x,p.y,.27,pt(p))){
    let ok=false;for(let s=1;s<=10&&!ok;s++){const nx=p.x-p.face.x*.1*s,ny=p.y-p.face.y*.1*s;if(!collides(nx,ny,.27,pt(p))){p.x=nx;p.y=ny;ok=true}}
    if(!ok){walls[k]=prev;personal(p,'deny');return}
    p.tp++;
  }
  p.mats[t.mat]-=t.cost;p.bcd=MAT[t.mat].cd*(t.mat===0?p.C.build:(p.C.build+1)/2);
  if(t.act==='PLACE'||t.act==='DOOR')game.stats.built++;markFlow();
  sfx('place'+t.mat,t.i+.5,t.j+.5);
  for(let n=0;n<5;n++)emit(t.i+.5,t.j+.5,WH*.3,t.mat===2?'spark':t.mat===1?'dust':'splinter',t.mat);
}
function throwNade(p,tx,ty){
  if(!p.alive||p.nades<=0||p.ncd>0||truce()){personal(p,'deny');return}
  let dx=tx-p.x,dy=ty-p.y;const d0=Math.hypot(dx,dy)||1,m=d0*Math.min(1,6.5/(heightDist(p.x,p.y,tx,ty)||1));
  tx=clamp(p.x+dx/d0*m,.3,N-.3);ty=clamp(p.y+dy/d0*m,.3,N-.3);
  const FZ=hasMod('frenzy'),d=Math.hypot(tx-p.x,ty-p.y);lobs.push({x0:p.x,y0:p.y,x1:tx,y1:ty,t:0,T:.5+d*.08,R:1.65*(p.C.blast>1?1.15:1)*(1+armBoost(p.up.n,.05,.0125))*(FZ?1.33:1),power:p.blast,own:p.id});p.nades--;p.ncd=p.C.nadeCd*(p.perk||PERK0).reload*(FZ?.5:1);sfx('lob',p.x,p.y);
}
// this phone's buttons: do it (host/solo) or ask the host (guest)
function localBuild(){
  const p=player;if(!p||!p.alive||!cfg.build||game.pvp==='ffa')return;const t=buildTarget(p,game.sel,game.piece==='door');
  if(NET.mode==='guest'){if(!t.ok){sfx('deny',undefined,undefined,true);return}NET.toHost({t:'b',i:t.i,j:t.j,s:game.sel,d:game.piece==='door'});return}
  doBuild(p,t.i,t.j,game.sel,game.piece==='door');
  if(game.tip===1&&game.stats.built>=3){game.tip=2;setTip('Ring the CORE. Make one tile a DOOR so your crew and Delgado can get in and out. Raiders treat doors like walls.')}
}
// quartermaster sprint: 1.4x speed for 2.5 s, no shooting while it lasts, then 6 s to recharge
const SPRINT={mult:1.4,dur:2.5,cd:6};
function localSprint(){const p=player;if(!p||!p.alive||!p.C.sprint||demo||(p.sprCd||0)>0)return;const L=(p.perk||PERK0).stride|0;p.sprT=SPRINT.dur+.6*L;p.sprCd=p.sprT+SPRINT.cd-L}   // Long Stride: longer, and back sooner
// v0.9.3.7 touch aim assist: on a touch screen a grenade or rocket locks onto the nearest raider at least 6 tiles away
// with nothing solid in between, so the blast can't land on your own walls or crew by accident. Mouse and controller
// aim stay manual, PvP stays manual, and the host checks the throw exactly as before (it is just a target point).
const LOCK={min:6,nade:8,rocket:12,every:.15};
function lockClear(x0,y0,x1,y1){
  if(!heightRayClear(x0,y0,x1,y1))return false;
  const d=Math.hypot(x1-x0,y1-y0),st=Math.ceil(d/.2),k0=idx(x0|0,y0|0),k1=idx(x1|0,y1|0);
  for(let s=1;s<st;s++){const t=s/st,x=x0+(x1-x0)*t,y=y0+(y1-y0)*t,i=x|0,j=y|0;if(!inb(i,j))return false;const k=idx(i,j);if(k===k0||k===k1)continue;
    if(walls[k]||coreKs.has(k)||terrShot(terr[k]))return false;const n=nodeAt(i,j);if(n&&n.solid)return false}
  return true;
}
function touchLock(p,kind){
  if(!touchMode||padMode||game.pvp||!p||!p.alive)return null;
  const max=LOCK[kind]||LOCK.nade;let best=null,bd=1e9;
  for(const e of enemies){if(e.dead||!(e.hp>0)||e.burrow)continue;const d=heightDist(e.x,e.y,p.x,p.y);if(d<LOCK.min||d>max||d>=bd)continue;
    if(lockClear(p.x,p.y,e.x,e.y)){best=e;bd=d}}
  return best;
}
// what the marker shows: the rocket's target when a rocket is ready, otherwise the grenade's
function lockKind(p){return p.cls==='soldier'&&hasAbility(p)&&(NET.mode==='guest'?p.ab>0:p.rk>0&&!(p.rkCd>0))?'rocket':p.nades>0?'nade':''}
function lockNow(p){const L=game.lockC||(game.lockC={t:-1,e:null});if(game.time-L.t>=LOCK.every||game.time<L.t){L.t=game.time;const k=lockKind(p);L.e=k?touchLock(p,k):null}return L.e}
function localNade(){
  const p=player;if(!p||!p.alive)return;let tx,ty;const L=touchLock(p,'nade');
  if(L){tx=L.x;ty=L.y}
  else if(!touchMode&&!padMode&&mouse.seen){const w=screenToWorld(mouse.x,mouse.y+WH*.55);tx=w.x;ty=w.y}else{tx=p.x+p.face.x*5;ty=p.y+p.face.y*5}
  if(NET.mode==='guest'){if(p.nades<=0){sfx('deny',undefined,undefined,true);return}NET.toHost({t:'n',x:r2(tx),y:r2(ty)});return}
  throwNade(p,tx,ty);
}
// one pull of the trigger: a shotgun throws an even fan of pellets (a little jitter so it isn't a grid)
function shoot(p,G,late){
  const a=Math.atan2(p.aim.y,p.aim.x),P=G.pellets|0,tc=nextTracerColor(p);
  const shot=++shotSeq;
  if(P>1)for(let i=0;i<P;i++)fire(p,a+(i/(P-1)-.5)*G.spread+(rnd()-.5)*G.spread*.3,0,G,late,i>0,tc,shot);
  else fire(p,a+(rnd()-.5)*G.spread,0,G,late,false,tc,shot);
}
let shotSeq=0;
// pellets lose punch with distance: full damage to fall[0] tiles, down to fall[2] of it by fall[1]
function bdmg(b){if(!b.fall)return b.dmg;const[a,z,m]=b.fall,d=b.dist*bulletRangeScale(b);return b.dmg*(d<=a?1:d>=z?m:1-(1-m)*(d-a)/(z-a))}
// late = seconds ago the shot was due (a slow frame can owe one); the bullet starts that much further along
function fire(from,ang,team,gun,late=0,quiet=false,tc=nextTracerColor(from),shot=++shotSeq){
  const ahead=.33+gun.speed*clamp(late,0,.25);
  const own=from===qm?'dell':(from.id!==undefined&&players.get(from.id)===from?from.id:null);
  const visual=wardrobeShotVisual(from,ang,gun);if(visual)from._shotDrawUntil=game.time+.08;
  const [z0,zSlope]=bulletHeight(from,ang,gun.range);
  bullets.push({z0:z0+zSlope*.33,zSlope,visual,id:++bulletSeq,pt:from.team||'',x:from.x+Math.cos(ang)*ahead,y:from.y+Math.sin(ang)*ahead,vx:Math.cos(ang)*gun.speed,vy:Math.sin(ang)*gun.speed,team,dmg:gun.dmg,dist:ahead-.33,over:gun.over!==false,skipped:false,last:-1,range:gun.range+(team===0&&boHigh(from)?2:0),pierce:gun.pierce||0,heavy:!!gun.pierce,
    own,tr:own&&own!=='dell'?Math.max(0,TRAIL_IDS.indexOf(from.cos.trail)):0,tc,fall:gun.fall||null,pel:gun.pellets>1,shot,ammo:team===0&&ammoMode()&&from.ammoEq?from.ammoEq.filter(Boolean).map(id=>[id,ammoRank(from,id)]):[]});
  rec(bulletEvent(bullets[bullets.length-1]));
  if(!quiet)addFlash({x:from.x+Math.cos(ang)*.4,y:from.y+Math.sin(ang)*.4,life:.06,max:.06,r:gun.pellets>1?1.3:.9,muzzle:true,visual:visual?visual.slice(2):null});
}
function bulletEvent(b){return ['b',b.id,r2(b.x),r2(b.y),r2(b.vx),r2(b.vy),b.team,b.heavy?1:0,b.tr|0,r2(b.range/bulletRangeScale(b)-b.dist),b.visual,b.visual?b.own:null,b.tc|0,r2(bulletZ(b)),r2(b.zSlope||0)]}

