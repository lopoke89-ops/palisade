/* ================= modifiers and class abilities in play (v0.9.2) ================= */
// Everything a modifier changes goes through the small hooks below, so the main code only asks hasMod() once
// in each place. The host (or solo) runs them; guests only see the results.
const STORM={slow:.8,every:2,pvpOn:40,pvpOff:40,
  look:{yard:{name:'DUST STORM',col:[196,160,104],kind:'dust'},river:{name:'RAIN AND FOG',col:[150,172,190],kind:'rain'},quarry:{name:'ASH FALL',col:[120,112,104],kind:'ash'}}};
const stormLook=()=>STORM.look[game.map]||STORM.look.yard;
const stormSlow=()=>game.wx&&!demo?STORM.slow:1;
const nightmare=()=>hasMod('nightmare');
// Boss Rush: the even raids that don't already have one; Nightmare: 1 in 12 on any raid without one.
// These in-between bosses pay 15-30 shards each instead of a case.
function extraBoss(w){
  if(bossOf(w))return'';const L=(MAP&&MAP.bosses)||BOSS_ORDER;
  if(hasMod('bossrush')&&w%2===0)return L[(w/2)%L.length];
  if(nightmare()&&rnd()<1/12)return L[Math.floor(rnd()*L.length)];
  return'';
}
// Elite Raid: riflemen become specials (in turn: shieldbearer, grenadier, firebrand, medic, breacher);
// Firestorm: about twice the firebrands, from raid 1
function modWaveMix(W,k){
  if(hasMod('firestorm')){const add=Math.max(1,W.fire)+(k>=5?1:0);W.fire+=add;W.rifle=Math.max(2,W.rifle-add)}
  if(hasMod('elite')){const cyc=['shield','gren','fire','medic','breach'];for(let n=0;n<W.rifle;n++){const t=cyc[n%cyc.length];W[t]=(W[t]|0)+1}W.rifle=0}
  return W;
}
// the storm: every other raid in co-op; in PvP 40 s on, 40 s off once the fighting starts
function stormRaid(){
  game.wx=hasMod('weather')&&game.wave%2===0?1:0;
  if(game.wx){const S=stormLook();toastAll(S.name,'It slows everyone down, raiders included, and wears you down: 1 health every 2 seconds until the raid is broken.')}
}
function stormTick(dt){
  if(!hasMod('weather'))return;
  if(game.pvp&&game.phase==='raid'){game.wxT+=dt;const cyc=STORM.pvpOn+STORM.pvpOff,on=game.wxT%cyc>=STORM.pvpOff?1:0;
    if(on!==game.wx){game.wx=on;if(on)toastAll(stormLook().name,'Everyone slows down, and it wears you down: 1 health every 2 seconds.')}}
  if(!game.wx)return;
  game.wxHit=(game.wxHit||0)+dt;if(game.wxHit<STORM.every)return;game.wxHit-=STORM.every;
  for(const p of players.values())if(p.alive&&!(p.prot>0)&&p.hp>1)p.hp=Math.max(1,p.hp-1);   // it wears you down but never drops you on its own
}
// Free-for-all's Sudden Death: the last minute
function suddenTick(){if(hasMod('sudden')&&game.pvp==='ffa'&&!game.sd&&game.timer<=60){game.sd=true;for(const p of players.values())p.prot=0;toastAll('SUDDEN DEATH','One minute left. Every drop counts double, and nobody gets spawn protection.')}}
// Grenade Frenzy: a grenade back every 6 s
function frenzyTick(p,dt){if(!hasMod('frenzy')||!p.alive)return;if(p.nades>=p.maxN){p.nfT=0;return}p.nfT=(p.nfT||0)+dt;if(p.nfT>=6){p.nfT=0;p.nades++;personal(p,'restock')}}

/* ---------- abilities ---------- */
// soldier: a rocket at what you aim at; sniper: stealth. Both co-op only (hasAbility).
function useAbility(p,tx,ty){
  if(!p||!p.alive||!hasAbility(p)||!running()||game.phase==='over'){if(p)personal(p,'deny');return}
  if(p.cls==='soldier'){
    const R=ABIL.rocket;if(p.rk<=0||p.rkCd>0){personal(p,'deny');return}
    let dx=tx-p.x,dy=ty-p.y;if(!isFinite(dx)||!isFinite(dy)||Math.hypot(dx,dy)<.2){dx=p.aim.x;dy=p.aim.y}const l=Math.hypot(dx,dy)||1;
    rockets.push({x:p.x+dx/l*.6,y:p.y+dy/l*.6,vx:dx/l*R.speed,vy:dy/l*R.speed,d:0,max:R.range,pw:R.power,pl:true,own:p.id});
    p.rk--;p.rkCd=R.cd;p.prot=0;sfx('rocket',p.x,p.y);addFlash({x:p.x+dx/l*.6,y:p.y+dy/l*.6,life:.14,max:.14,r:1.4});personal(p,'~f');
  }else if(p.cls==='sniper'){
    if(p.stl>0||p.stlCd>0){personal(p,'deny');return}
    p.stl=ABIL.stealth.dur+((p.perk||PERK0).ghillie|0);sfx('mark',p.x,p.y);for(let n=0;n<8;n++)emit(p.x,p.y,WH*.5,'smoke');
    toastTo(p,'STEALTH',`Raiders can't see you for ${Math.round(p.stl)} seconds. Anything already thrown can still land.`);
  }
  abState(p);
}
function simAbility(p,dt){
  p.rkCd=Math.max(0,(p.rkCd||0)-dt);
  if(p.stl>0){p.stl-=dt;if(p.stl<=0||!p.alive){p.stl=0;p.stlCd=ABIL.stealth.cd;if(p.alive)toastTo(p,'SEEN','Stealth is over. It comes back in 30 seconds.')}}
  else if(p.stlCd>0)p.stlCd=Math.max(0,p.stlCd-dt);
  abState(p);
}
// p.ab on the network: soldier = rockets left; sniper = stealth time ×10 while on, minus the seconds of recharge
function abState(p){p.ab=!hasAbility(p)?0:p.cls==='soldier'?p.rk|0:p.stl>0?Math.ceil(p.stl*10):-Math.ceil(p.stlCd||0)}
const stealthed=p=>!!p&&!game.pvp&&p.cls==='sniper'&&(NET.mode==='guest'?p.ab>0:p.stl>0);
function localAbility(){
  const p=player;if(!p||!p.alive||!hasAbility(p))return;let tx,ty;
  if(!touchMode&&mouse.seen){const w=screenToWorld(mouse.x,mouse.y+WH*.55);tx=w.x;ty=w.y}else{tx=p.x+p.aim.x*6;ty=p.y+p.aim.y*6}
  if(NET.mode==='guest'){if(p.cls==='soldier'&&p.ab<=0||p.cls==='sniper'&&p.ab!==0){sfx('deny',undefined,undefined,true);return}NET.toHost({t:'ab',x:r2(tx),y:r2(ty)});return}
  useAbility(p,tx,ty);
}
// rockets back each build phase (2, up to the stock)
function refillAbilities(){for(const p of players.values())if(p.cls==='soldier')p.rk=Math.min(abilRockets(p),(p.rk|0)+ABIL.rocket.refill)}
// the grenadier's Molotovs: a grenade that lands also leaves burning ground that only hurts raiders
function molotovAt(l){const p=l.own?players.get(l.own):null;if(!p||game.pvp||!(p.perk||PERK0).molotov)return;
  fires.push({x:l.x1,y:l.y1,t:5,max:5,tick:.3,r:1.2,pl:true,own:p.id});for(let n=0;n<8;n++)emit(l.x1,l.y1,4*u,'fire')}
// the storm over the yard: a tint and a few dozen streaks (rain), streaks (dust) or flakes (ash), in screen space
let wxA=0;
function drawStorm(dt){
  wxA+=((game.wx&&!demo&&running()?1:0)-wxA)*Math.min(1,dt*1.5);if(wxA<.01)return;
  const S=stormLook(),[r,gr,b]=S.col,t=game.time,n=W<760?36:72;
  g.fillStyle=`rgba(${r},${gr},${b},${(S.kind==='rain'?.2:.16)*wxA})`;g.fillRect(0,0,W,H);
  g.lineCap='round';
  if(S.kind==='rain'){g.strokeStyle=`rgba(200,220,235,${.45*wxA})`;g.lineWidth=1.1;g.beginPath();
    for(let i=0;i<n*1.5;i++){const h1=hash(i,7),h2=hash(i,13),sp=.8+h2*.6,y=((h2*H+t*620*sp)%(H+60))-30,x=((h1*W*1.2-t*90*sp)%(W*1.2)+W*1.2)%(W*1.2)-W*.1;g.moveTo(x,y);g.lineTo(x-5,y+16)}g.stroke()}
  else if(S.kind==='dust'){g.strokeStyle=`rgba(226,196,140,${.38*wxA})`;g.lineWidth=1.6;g.beginPath();
    for(let i=0;i<n;i++){const h1=hash(i,7),h2=hash(i,13),sp=.7+h2*.7,x=((h1*W*1.4+t*300*sp)%(W*1.4))-W*.2,y=h2*H+Math.sin(t*2+i)*6;g.moveTo(x,y);g.lineTo(x+26+h1*20,y+3)}g.stroke()}
  else{g.fillStyle=`rgba(190,180,168,${.55*wxA})`;
    for(let i=0;i<n;i++){const h1=hash(i,7),h2=hash(i,13),sp=.5+h2*.6,y=((h2*H+t*40*sp)%(H+20))-10,x=h1*W+Math.sin(t*1.3+i)*14;g.fillRect(x,y,2.2,2.2)}}
  g.lineCap='butt';
}
