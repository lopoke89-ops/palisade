/* ================= THE UNDERSTRIP: the two-stage bosses (dev/plans/understrip/boss-move-sheets.md) ================= */
// Every boss here has two stages. At half health it stops, can't be hurt for 3 s while the arena changes, and its bar
// refills as a second bar. Every attack is telegraphed for at least 0.6 s, by shape: a wedge (a swing), a lane (a charge),
// a cone (a spray), a ring on the ground (something landing). Boss states 60-89 are this mode's (the Destroyer uses 40-49).
// usBossWake: the gate is closing, the boss comes in. usBossReset: the squad fell, the boss starts again.
const US_PIT={hp:960,speed:1.6,speed2:2.1,swing:{tell:.7,r:1.8,half:.9,dmg:22,cd:2.5,knock:1},chips:{tell:.9,r:1.4,power:.9,cd:[3.5,3],n:[2,3],reach:8},
  spray:{tell:.7,r:5,half:.45,n:6,dmg:8,cd:3},rush:{tell:.9,w:1.2,speed:8,dmg:32,knock:1.5,cd:6,daze:1},transition:3};
BOSSES.pitboss={name:'THE PIT BOSS',hp:US_PIT.hp,speed:US_PIT.speed,scan:11,bounty:40,col:'#e2b436',think:thinkPitBoss,us:true,box:'none',
  look:{body:'#2a2a30',vest:'#1c1c22',pants:'#26262c',head:'#b08a6a',helmet:'#1a1410',bandana:'#7a1a1a',gl:14,weapon:'sword'},
  intro:'He throws chips that go off: a ring shows where each one lands. When his jacket comes off, the floor floods and he charges.'};
ECODE.push('boss:pitboss');BOSS_WEAK.pitboss='blast';   // network type codes only ever grow at the end
function usBossWake(){const U=game.us;if(U.bossSpawned||NET.mode==='guest')return;U.bossSpawned=true;U.bossStage=0;U.bfx=[];U.blastT=0;spawnBoss(usBossOf(U.level))}
function usBossReset(){const U=game.us;if(!U||!game.lay.arena)return;enemies=enemies.filter(e=>e.type!=='boss'&&!(e.us&&(e.us.call||e.us.drone&&e.us.boss)));U.bossSpawned=false;U.bossStage=0;U.floodOn=false;floodOn=false;U.bfx=[];U.crush=null;usBlastOpenAll();usGateOpen()}
// usTick: the boss is down (once), so the arena's shrine and the lift wake. The Gatekeeper's two bodies: either one ends it
const US_DOWN={pitboss:['THE PIT BOSS IS DOWN','The count room\'s shrine is lit and the lift is running. Rest, then take it down.'],
  custodian:['THE CUSTODIAN IS DOWN','The hall\'s doors stand open, its shrine is lit, and the lift is running.'],
  gatekeeper:['THE GATEKEEPER IS DOWN','The lab door is open. Rest at the bay\'s shrine; the lift goes down to the core.'],
  visitor:['THE VISITOR IS DOWN','The field is dark for good. Rest, then take the lift out of Area 67.']};
function usBossTick(dt){const U=game.us;if(!U.bossSpawned||U.bossDown)return;const key=usBossOf(U.level),B=enemies.filter(e=>e.type==='boss'&&!e.dead);
  if(key==='custodian'&&U.gate===2)usBlastTick(dt||0);usBfxTick(dt||0);
  if(key==='gatekeeper'&&B.length&&enemies.some(e=>e.type==='boss'&&e.dead&&e.gk2))for(const e of B){e.dead=true;e.hp=0}   // one body down ends the fight
  if(enemies.some(e=>e.type==='boss'&&!e.dead))return;
  {const A=game.lay.arena,P=game.lay.bossAt[0]||[A.x+A.w/2,A.y+A.h/2];usBossLoot(P[0]+.5,P[1]+1.5,key)}
  U.bossDown=true;U.bossStage=0;U.floodOn=false;floodOn=false;U.floodWarned=false;U.flood=US.flood.every[0];U.bfx=[];U.crush=null;usBlastOpenAll();usGateOpen();markFlow();   // the water drains, and the flash floods start over
  for(const e of enemies)if(e.type==='drone')e.dead=true;
  toastAll(...US_DOWN[key])}
// the bar shows the stage's own health (the Visitor has a third, desperate stage under 10%; the Gatekeeper's pilot is its own bar)
const usBossFrac=e=>{const f=e.hp/e.max,st=game.us?game.us.bossStage|0:0;if(e.pilot)return clamp(f,0,1);
  if(e.boss==='visitor')return clamp(st>=2?f/.1:st>=1?(f-.1)/.4:(f-.5)/.5,0,1);return clamp(st>0?f/.5:(f-.5)/.5,0,1)};
function usPitCall(e,types){const A=game.lay.arena;if(!A)return;const gx=A.x+A.w/2,gy=A.y+A.h-2.5;
  types.forEach((t,n)=>{const r=spawnEnemyAt(t,gx-1+n*2,gy);if(r){r.us={home:[r.x,r.y],st:'hunt',sid:-1,t:0,look:0,call:1}}});
  toastAll('SECURITY!','He called two of the casino\'s guards in.');sfx('siren',e.x,e.y)}
function thinkPitBoss(e,dt,tgt,mv,aimAt,Df){
  const U=game.us,P=US_PIT;if(!e.pb)e.pb={stage:1,calls:0,toss:2.2,swing:0,rush:3,spray:1.5};const S=e.pb;
  S.toss-=dt;S.swing-=dt;S.rush-=dt;S.spray-=dt;if(e.inv>0)e.inv-=dt;
  // half health: jacket off, the floor floods, stage 2
  if(S.stage===1&&e.hp<=e.max*.5){e.hp=e.max*.5;S.stage=2;e.st=60;e.stT=e.stM=P.transition;e.inv=P.transition;U.bossStage=1;U.floodOn=true;floodOn=true;markFlow();
    toastAll('THE PIT BOSS · JACKET OFF','The count room floods. Now he charges down a lane and sprays cards in a cone.');sfx('horn',e.x,e.y);addShake(e.x,e.y,8);return{eng:true,mv:null}}
  if(e.st===60){e.stT-=dt;if(e.stT<=0){e.st=0;e.speed=P.speed2}return{eng:true,mv:null}}
  if(S.calls===0&&e.hp<=e.max*.75){S.calls=1;usPitCall(e,['rifle','rifle'])}
  if(S.calls===1&&S.stage===2&&e.hp<=e.max*.25){S.calls=2;usPitCall(e,['rifle','shield'])}
  // the swing: a wedge, then the cut
  if(e.st===1){e.stT-=dt;if(e.foe)aimAt(e.foe.x,e.foe.y);if(e.stT<=0){e.st=0;const a0=Math.atan2(e.aim.y,e.aim.x);
      for(const a of allies()){if(!a.alive)continue;const dx=a.x-e.x,dy=a.y-e.y,d=Math.hypot(dx,dy);if(d>P.swing.r)continue;let da=Math.abs(Math.atan2(dy,dx)-a0);if(da>Math.PI)da=2*Math.PI-da;
        if(da<P.swing.half){hurtAlly(a,P.swing.dmg*Df.dmg);knock(a,e.x,e.y,P.swing.knock)}}
      sfx('slash',e.x,e.y);slashFx(e.x,e.y,e.aim.x,e.aim.y)}return{eng:true,mv:null}}
  // the card spray: a cone, then six cards
  if(e.st===61){e.stT-=dt;aimAt(e.lx,e.ly);if(e.stT<=0){e.st=0;const a0=Math.atan2(e.ly-e.y,e.lx-e.x);
      for(let k=0;k<P.spray.n;k++)fire(e,a0+(k/(P.spray.n-1)-.5)*2*P.spray.half,1,{dmg:P.spray.dmg*Df.dmg,speed:15,range:P.spray.r},0);sfx('cas_card',e.x,e.y)}
    return{eng:true,mv:null}}
  // the floor rush: a lane to the far wall, the run, then dazed for a second (the time to hit him)
  if(e.st===2){e.stT-=dt;aimAt(e.lx,e.ly);if(e.stT<=0){const a=Math.atan2(e.ly-e.y,e.lx-e.x);e.st=3;const L=Math.hypot(e.lx-e.x,e.ly-e.y);e.stT=e.stM=L/P.rush.speed+.05;
      e.cvx=Math.cos(a)*P.rush.speed;e.cvy=Math.sin(a)*P.rush.speed;e.hit=new Set();sfx('charge',e.x,e.y)}return{eng:true,mv:null}}
  if(e.st===3){e.stT-=dt;let stop=e.stT<=0;
    for(let s=0;s<3&&!stop;s++){const nx=e.x+e.cvx*dt/3,ny=e.y+e.cvy*dt/3,i=Math.floor(nx),j=Math.floor(ny);
      if(!inb(i,j)||terrSolid(terr[idx(i,j)])){stop=true;break}const k=idx(i,j);if(walls[k]){damageWall(k,150);if(walls[k]){stop=true;break}}
      e.x=nx;e.y=ny;
      for(const a of allies())if(a.alive&&!e.hit.has(a)&&Math.hypot(a.x-e.x,a.y-e.y)<.65){e.hit.add(a);hurtAlly(a,P.rush.dmg*Df.dmg);knock(a,e.x,e.y,P.rush.knock);addShake(a.x,a.y,6)}}
    e.walk+=dt*18;if(rnd()<.6)emit(e.x,e.y,4*u,'dust',0);
    if(stop){e.st=62;e.stT=e.stM=P.rush.daze;addShake(e.x,e.y,5);sfx('hit2',e.x,e.y)}return{eng:true,mv:null}}
  if(e.st===62){e.stT-=dt;if(e.stT<=0)e.st=0;return{eng:true,mv:null}}
  // who he's after: whoever he can see, or the nearest of you
  let f=e.foe;if(!f){let bd=1e9;for(const a of allies())if(a.alive){const d=Math.hypot(a.x-e.x,a.y-e.y);if(d<bd){bd=d;f=a}}}
  if(!f)return{eng:false,mv:null};const d=Math.hypot(f.x-e.x,f.y-e.y);aimAt(f.x,f.y);
  if(d<2&&S.swing<=0){e.st=1;e.stT=e.stM=P.swing.tell;S.swing=P.swing.cd;sfx('lock',e.x,e.y);return{eng:true,mv:null}}
  if(S.stage===2&&d>2.4&&d<10&&S.rush<=0&&losClear(e.x,e.y,f.x,f.y)){const a=Math.atan2(f.y-e.y,f.x-e.x);let L=0;while(L<14){const x=e.x+Math.cos(a)*(L+.5),y=e.y+Math.sin(a)*(L+.5);if(!inb(x|0,y|0)||terrSolid(terr[idx(x|0,y|0)]))break;L+=.5}
    e.st=2;e.stT=e.stM=P.rush.tell;e.lx=e.x+Math.cos(a)*L;e.ly=e.y+Math.sin(a)*L;S.rush=P.rush.cd;sfx('charge',e.x,e.y);return{eng:true,mv:null}}
  if(S.stage===2&&d<P.spray.r&&S.spray<=0){e.st=61;e.stT=e.stM=P.spray.tell;e.lx=f.x;e.ly=f.y;S.spray=P.spray.cd;sfx('lock',e.x,e.y);return{eng:true,mv:null}}
  if(S.toss<=0&&d<P.chips.reach){const n=P.chips.n[S.stage-1];for(let k=0;k<n;k++){const ox=k?(rnd()-.5)*3:0,oy=k?(rnd()-.5)*3:0,x1=clamp(f.x+ox,.5,N-.5),y1=clamp(f.y+oy,.5,N-.5),dd=Math.hypot(x1-e.x,y1-e.y);
      lobs.push({x0:e.x,y0:e.y,x1,y1,t:0,T:Math.max(P.chips.tell,.55+dd*.08),R:P.chips.r,power:P.chips.power*Df.dmg})}
    S.toss=P.chips.cd[S.stage-1];sfx('lob',e.x,e.y);return{eng:true,mv:null}}
  return{eng:false,mv:d<1.2?null:{x:f.x,y:f.y}}
}
// the warnings (drawBossFx), from the state every phone has (st, stF, lx, ly, aim)
function usPitFx(e,f,pulse,ch){
  const c0=iso(e.x,e.y),P=US_PIT,red=a=>`rgba(255,60,40,${a})`;
  if(e.st===1){const a0=Math.atan2(e.aim.y,e.aim.x);g.fillStyle=red(.18+.2*pulse);g.beginPath();g.moveTo(c0[0],c0[1]);
    for(let k=0;k<=10;k++){const a=a0+(k/10-.5)*2*P.swing.half,c=iso(e.x+Math.cos(a)*P.swing.r,e.y+Math.sin(a)*P.swing.r);g.lineTo(c[0],c[1])}g.closePath();g.fill();return true}
  if(e.st===61){const a0=Math.atan2(e.ly-e.y,e.lx-e.x);g.fillStyle=red(.14+.18*pulse);g.strokeStyle=red(.55+.3*pulse);g.lineWidth=1.4*u;g.beginPath();g.moveTo(c0[0],c0[1]);
    for(let k=0;k<=12;k++){const a=a0+(k/12-.5)*2*P.spray.half,c=iso(e.x+Math.cos(a)*P.spray.r,e.y+Math.sin(a)*P.spray.r);g.lineTo(c[0],c[1])}g.closePath();g.fill();g.stroke();return true}
  if(e.st===2){const dx=e.lx-e.x,dy=e.ly-e.y,l=Math.hypot(dx,dy)||1,nx=-dy/l*P.rush.w/2,ny=dx/l*P.rush.w/2,Q=[[e.x+nx,e.y+ny],[e.lx+nx,e.ly+ny],[e.lx-nx,e.ly-ny],[e.x-nx,e.y-ny]].map(q=>iso(q[0],q[1]));
    g.fillStyle=red(.16+.22*pulse);g.strokeStyle=red(.6+.3*pulse);g.lineWidth=1.6*u;g.beginPath();Q.forEach((q,i)=>i?g.lineTo(q[0],q[1]):g.moveTo(q[0],q[1]));g.closePath();g.fill();g.stroke();return true}
  if(e.st===60){g.strokeStyle=`rgba(226,180,54,${.4+.4*pulse})`;g.lineWidth=2.4*u;g.beginPath();g.ellipse(c0[0],c0[1],TW2*(1.2+f*.6),TH2*(1.2+f*.6),0,0,Math.PI*2);g.stroke();label('JACKET OFF',c0[0],c0[1]-WH*2.2,'#e2b436',11);return true}
  if(e.st===62){label('DAZED',c0[0],c0[1]-WH*2.1,'#e8e2d0',10);return true}
  return e.st===3}

// ---------- shared by the three deeper bosses ----------
const usFoes=()=>allies().filter(a=>a.alive);
function usNearFoe(e){let f=null,bd=1e9;for(const a of usFoes()){const d=Math.hypot(a.x-e.x,a.y-e.y);if(d<bd){bd=d;f=a}}return f}
function usFarFoe(x,y){let f=null,bd=-1;for(const a of usFoes()){const d=Math.hypot(a.x-x,a.y-y);if(d>bd){bd=d;f=a}}return f}
function usInWedge(x,y,cx,cy,a0,r,half){const d=Math.hypot(x-cx,y-cy);if(d>r)return false;let da=Math.abs(Math.atan2(y-cy,x-cx)-a0);if(da>Math.PI)da=2*Math.PI-da;return da<half}
const usArenaC=()=>{const A=game.lay.arena;return[A.x+A.w/2,A.y+A.h/2]};
// what's on the floor from a boss (game.us.bfx; the snapshot carries it so guests draw the same): live water, a gas quarter, a
// psychic ring, acid, a gravity well, a landing circle, the ceiling turret's line, a blink's flash. warn: the telegraph's time
// before it does anything (never under 0.6 s), T: when it's gone
function usFx(k,o){const U=game.us;U.bfx=U.bfx||[];U.bfx.push({k,t:0,warn:0,...o})}
function usDot(a,dps,dt){if(a===qm){hurtQM(dps*dt);return}a.bDot=(a.bDot||0)+dps*dt;if(a.bDot>=dps*.25){hurtPlayer(a,a.bDot);a.bDot=0}}
function usBfxTick(dt){const U=game.us,Df=game.Df;if(!U.bfx)return;
  for(const f of U.bfx){f.t+=dt;const live=f.t>=f.warn,first=live&&!f.went;if(first)f.went=true;
    if(f.k==='water'&&live){for(const a of usFoes())if(usInWedge(a.x,a.y,f.x,f.y,f.a,f.r,f.half))usDot(a,US_CUS.mop.dps,dt)}
    else if(f.k==='gas'&&live){for(const a of usFoes())if(a.x>=f.x&&a.x<f.x1&&a.y>=f.y&&a.y<f.y1)usDot(a,US_CUS.gas.dps*(a!==qm&&usHas(a,'p_lung')?US_HZ.lung:1),dt)}
    else if(f.k==='acid'&&live){for(const a of usFoes())if(Math.hypot(a.x-f.x,a.y-f.y)<f.r)usDot(a,US_VIS.tank.acid,dt)}
    else if(f.k==='ring'&&live){const R=(f.t-f.warn)*US_VIS.pulse.speed;f.hit=f.hit||new Set();
      for(const a of usFoes()){if(f.hit.has(a))continue;const d=Math.hypot(a.x-f.x,a.y-f.y);if(Math.abs(d-R)<US_VIS.pulse.w){f.hit.add(a);if(a!==qm&&rollSafe(a))continue;hurtAlly(a,US_VIS.pulse.dmg*Df.dmg);knock(a,f.x,f.y,.6)}}}
    else if(f.k==='well'&&live){for(const a of usFoes()){const dx=f.x-a.x,dy=f.y-a.y,d=Math.hypot(dx,dy);if(d>US_VIS.well.r)continue;
        if(d<US_VIS.well.core)usDot(a,US_VIS.well.dps,dt);if(!(a!==qm&&usRelic(a,'x_lead'))&&d>.2)moveEnt(a,dx/d*US_VIS.well.pull*dt,dy/d*US_VIS.well.pull*dt,a===qm?true:pt(a))}}
    else if(f.k==='circle'&&first){for(const a of usFoes())if(Math.hypot(a.x-f.x,a.y-f.y)<f.r){hurtAlly(a,(f.dmg||0)*Df.dmg);if(f.push)knock(a,f.x,f.y,f.push)}addShake(f.x,f.y,6);sfx('boom',f.x,f.y);for(let n=0;n<8;n++)emit(f.x,f.y,6*u,'dust')}
    else if(f.k==='turret'&&first){const a0=Math.atan2(f.y1-f.y,f.x1-f.x),src=enemies.find(e=>e.type==='boss'&&!e.dead);
      if(src){const o={...src,x:f.x,y:f.y,aim:{x:Math.cos(a0),y:Math.sin(a0)}};for(let k=0;k<US_CUS.turret.n;k++)fire(o,a0+(k-1)*.035,1,{dmg:US_CUS.turret.dmg*Df.dmg,speed:22,range:34},k*.04)}sfx('smg',f.x,f.y)}}
  U.bfx=U.bfx.filter(f=>f.t<f.T)}
// the Custodian's doors: each shuts for 3 s every 8 s, out of step, with a 1 s amber warning; a crush lane forces two at once
function usBlastTick(dt){const U=game.us,L=game.lay;if(!L.blast||!L.blast.length)return;U.blastT=(U.blastT||0)+dt;const D=US_CUS.door,C=U.crush;
  if(C){C.t+=dt;if(C.t>=US_CUS.crush.tell+US_CUS.crush.shut)U.crush=null}
  L.blast.forEach((d,n)=>{let s;if(U.crush&&U.crush.doors.includes(n))s=U.crush.t<US_CUS.crush.tell?1:2;else{const ph=(U.blastT+d.off)%D.every;s=ph<D.every-D.warn-D.shut?0:ph<D.every-D.shut?1:2}
    if(s!==U.blast[n])usBlastSet(n,s,U.crush&&U.crush.doors.includes(n)?US_CUS.crush.dmg:D.dmg)})}

// ---------- 8.3 THE CUSTODIAN · Shelter 7 ----------
const US_CUS={hp:1440,speed:1,speed2:1.2,mop:{tell:.9,r:3,half:1.1,dmg:24,slow:.6,cd:[3,2.5],strip:3,dps:8},door:{every:8,warn:1,shut:3,dmg:40},
  crush:{tell:1,shut:1.5,dmg:45,cd:7},gas:{tell:2,len:8,dps:10,cd:14},turret:{tell:.8,n:3,dmg:9,cd:6},transition:3};
BOSSES.custodian={name:'THE CUSTODIAN',hp:US_CUS.hp,speed:US_CUS.speed,scan:12,bounty:50,col:'#9bbf5a',think:thinkCustodian,us:true,box:'none',
  look:{body:'#7d8a5a',vest:'#4a5236',pants:'#3a3f2c',head:'#9aa27a',helmet:'#5a6240',gl:10,weapon:'sword'},
  intro:'A shock mop and the shelter\'s own doors. Watch the light over each door: amber means it\'s about to slam.'};
ECODE.push('boss:custodian');BOSS_WEAK.custodian='shock';
function thinkCustodian(e,dt,tgt,mv,aimAt,Df){const U=game.us,P=US_CUS;if(!e.cu)e.cu={stage:1,mop:1.5,crush:3,gas:5,turret:2.5};const S=e.cu;
  S.mop-=dt;S.crush-=dt;S.gas-=dt;S.turret-=dt;if(e.inv>0)e.inv-=dt;
  if(S.stage===1&&e.hp<=e.max*.5){e.hp=e.max*.5;S.stage=2;e.st=64;e.stT=e.stM=P.transition;e.inv=P.transition;U.bossStage=1;
    toastAll('THE CUSTODIAN · CASING CRACKED','Red light. The doors crush in lanes now, gas floods a quarter of the hall, and a ceiling turret finds whoever hangs back.');sfx('horn',e.x,e.y);addShake(e.x,e.y,8);return{eng:true,mv:null}}
  if(e.st===64){e.stT-=dt;if(e.stT<=0){e.st=0;e.speed=P.speed2}return{eng:true,mv:null}}
  // the mop arc: a wedge, then the shock, and a strip of live water left where it swept
  if(e.st===63){e.stT-=dt;if(e.stT<=0){e.st=0;const a0=Math.atan2(e.ly-e.y,e.lx-e.x);
      for(const a of usFoes())if(usInWedge(a.x,a.y,e.x,e.y,a0,P.mop.r,P.mop.half)){hurtAlly(a,P.mop.dmg*Df.dmg);a.stun=Math.max(a.stun||0,P.mop.slow)}
      usFx('water',{x:e.x,y:e.y,a:a0,r:P.mop.r,half:P.mop.half,T:P.mop.strip});sfx('zap',e.x,e.y);slashFx(e.x,e.y,Math.cos(a0),Math.sin(a0))}return{eng:true,mv:null}}
  const f=usNearFoe(e);if(!f)return{eng:false,mv:null};const d=Math.hypot(f.x-e.x,f.y-e.y);aimAt(f.x,f.y);
  if(S.stage===2){const [cx,cy]=usArenaC(),A=game.lay.arena;
    if(S.turret<=0){const far=usFarFoe(cx,cy);if(far){usFx('turret',{x:cx,y:cy,x1:far.x,y1:far.y,warn:P.turret.tell,T:P.turret.tell+.05});S.turret=P.turret.cd;sfx('lock',cx,cy)}}
    if(S.gas<=0){const q=Math.floor(rnd()*4),hx=A.w/2,hy=A.h/2,x0=A.x+1+(q&1)*(hx-1),y0=A.y+1+(q>>1)*(hy-1);usFx('gas',{x:x0,y:y0,x1:x0+hx-1,y1:y0+hy-1,warn:P.gas.tell,T:P.gas.tell+P.gas.len});S.gas=P.gas.cd;sfx('flood',x0+hx/2,y0+hy/2)}
    if(S.crush<=0&&game.lay.blast.length>=2&&!U.crush){const n=game.lay.blast.length,a=Math.floor(rnd()*n);let b=(a+1+Math.floor(rnd()*(n-1)))%n;U.crush={doors:[a,b],t:0};S.crush=P.crush.cd;sfx('siren',e.x,e.y)}}
  if(d<P.mop.r-.4&&S.mop<=0){e.st=63;e.stT=e.stM=P.mop.tell;e.lx=f.x;e.ly=f.y;S.mop=P.mop.cd[S.stage-1];sfx('lock',e.x,e.y);return{eng:true,mv:null}}
  // the sweep: with no one in reach, it goes after whoever is furthest
  const far=d>6?usFarFoe(e.x,e.y)||f:f;return{eng:false,mv:d<1.4?null:{x:far.x,y:far.y}}}

// ---------- 8.4 THE GATEKEEPER · Area 67 ----------
const US_GK={hp:1920,speed:.9,suit2:.8,pilot:2.4,pilotHp:.2,rockets:{tell:1.1,r:1.2,n:[4,3],cd:[5,7],power:.56},shield:{tell:.6,len:4,cd:10},stomp:{tell:.8,r:2.5,dmg:20,push:1.5,cd:4},
  pound:{tell:1.2,r:3,dmg:34,cd:5},sidearm:{tell:.6,n:3,dmg:9,cd:2},dive:{every:4,len:.5,speed:7},transition:3};
BOSSES.gatekeeper={name:'THE GATEKEEPER',hp:US_GK.hp,speed:US_GK.speed,scan:12,bounty:60,col:'#cfd8dc',think:thinkGatekeeper,us:true,box:'none',
  look:{body:'#cfd8dc',vest:'#8a959c',pants:'#6a747a',head:'#a98262',helmet:'#e4e8ea',gl:12,weapon:'shield'},
  intro:'Rockets fall where the circles are. His shield blocks shots from the front: go round it.'};
ECODE.push('boss:gatekeeper');BOSS_WEAK.gatekeeper='ap';
function thinkGatekeeper(e,dt,tgt,mv,aimAt,Df){if(e.pilot)return thinkGkPilot(e,dt,aimAt,Df);const U=game.us,P=US_GK;if(!e.gk)e.gk={stage:1,rock:2,shield:4,stomp:0,pound:3};const S=e.gk;
  S.rock-=dt;S.shield-=dt;S.stomp-=dt;S.pound-=dt;if(e.inv>0)e.inv-=dt;if(e.shT>0){e.shT-=dt;if(e.shT<=0)e.ub=(e.ub|0)&~1}
  // half health: the pilot ejects; the empty suit fights on (the stage-2 bar), the pilot is a second, quicker target
  if(S.stage===1&&e.hp<=e.max*.5){e.hp=e.max*.5;S.stage=2;e.st=72;e.stT=e.stM=P.transition;e.inv=P.transition;U.bossStage=1;e.shT=0;e.ub=0;e.gk2=1;
    toastAll('THE GATEKEEPER · THE PILOT EJECTS','The suit fights on empty and the pilot runs with a pistol. Bring down either one to end it.');sfx('horn',e.x,e.y);addShake(e.x,e.y,8);return{eng:true,mv:null}}
  if(e.st===72){e.stT-=dt;if(e.stT<=0){e.st=0;e.speed=P.suit2;usSpawnPilot(e)}return{eng:true,mv:null}}
  if(e.st===71){e.stT-=dt;if(e.stT<=0){e.st=0;usFx('circle',{x:e.x,y:e.y,r:P.stomp.r,dmg:P.stomp.dmg,push:P.stomp.push,T:.3})}return{eng:true,mv:null}}
  if(e.st===76){e.stT-=dt;if(e.stT<=0){e.st=0;e.shT=P.shield.len;e.ub=(e.ub|0)|1;sfx('shieldhit',e.x,e.y)}return{eng:true,mv:null}}
  const f=usNearFoe(e);if(!f)return{eng:false,mv:null};const d=Math.hypot(f.x-e.x,f.y-e.y);aimAt(f.x,f.y);
  if(S.stage===1&&d<2&&S.stomp<=0){e.st=71;e.stT=e.stM=P.stomp.tell;S.stomp=P.stomp.cd;sfx('lock',e.x,e.y);return{eng:true,mv:null}}
  if(S.stage===2&&d<4&&S.pound<=0){usFx('circle',{x:f.x,y:f.y,r:P.pound.r,dmg:P.pound.dmg,push:1,warn:P.pound.tell,T:P.pound.tell+.3});S.pound=P.pound.cd;sfx('lock',f.x,f.y)}
  if(S.stage===1&&S.shield<=0&&d<9){e.st=76;e.stT=e.stM=P.shield.tell;S.shield=P.shield.cd;return{eng:true,mv:null}}
  if(S.rock<=0&&d<12){const n=P.rockets.n[S.stage-1];for(let k=0;k<n;k++){const a=k/n*6.283+rnd(),rr=k?1.6+rnd()*.8:0,x1=clamp(f.x+Math.cos(a)*rr,.5,N-.5),y1=clamp(f.y+Math.sin(a)*rr,.5,N-.5);
      lobs.push({x0:e.x,y0:e.y,x1,y1,t:0,T:Math.max(P.rockets.tell,.6+Math.hypot(x1-e.x,y1-e.y)*.05),R:P.rockets.r,power:P.rockets.power*Df.dmg})}
    S.rock=P.rockets.cd[S.stage-1];sfx('rocket',e.x,e.y);return{eng:true,mv:null}}
  return{eng:false,mv:d<2.2?null:{x:f.x,y:f.y}}}
// the pilot: a second boss body (the same key, so the network and the bar know it), with 20% of the whole fight's health on top
function usSpawnPilot(suit){let x=suit.x+1,y=suit.y+.5;if(solidTile(x|0,y|0)){x=suit.x;y=suit.y}const hp=suit.max*US_GK.pilotHp;
  const e={id:nextId++,type:'boss',boss:'gatekeeper',big:true,x,y,hp,max:hp,cd:1,walk:0,aim:{x:1,y:0},flash:0,speed:US_GK.pilot,scanT:0,foe:null,planted:false,st:0,stT:0,stM:1,lx:x,ly:y,shots:0,ab:3,sw:0,pilot:true,gk2:1,ub:2};
  enemies.push(e);for(let n=0;n<12;n++)emit(x,y,WH*.6,'spark');sfx('rocket',x,y);return e}
// the pilot: quick, a three-shot sidearm with a line, a dodge roll every 4 s
function thinkGkPilot(e,dt,aimAt,Df){const P=US_GK;if(!e.gp)e.gp={side:1,dive:P.dive.every};const S=e.gp;S.side-=dt;S.dive-=dt;
  if(e.st===75){e.stT-=dt;moveEnt(e,e.cvx*dt,e.cvy*dt,false);e.walk+=dt*16;if(e.stT<=0)e.st=0;return{eng:true,mv:null}}
  if(e.st===74){e.stT-=dt;aimAt(e.lx,e.ly);if(e.stT<=0){e.st=0;const a0=Math.atan2(e.ly-e.y,e.lx-e.x);for(let k=0;k<P.sidearm.n;k++)fire(e,a0+(k-1)*.03,1,{dmg:P.sidearm.dmg*Df.dmg,speed:20,range:12},k*.06);sfx('pistol',e.x,e.y)}return{eng:true,mv:null}}
  const f=usNearFoe(e);if(!f)return{eng:false,mv:null};const d=Math.hypot(f.x-e.x,f.y-e.y);aimAt(f.x,f.y);
  if(S.dive<=0){const a=Math.atan2(e.y-f.y,e.x-f.x)+(rnd()<.5?1.2:-1.2);e.st=75;e.stT=e.stM=P.dive.len;e.cvx=Math.cos(a)*P.dive.speed;e.cvy=Math.sin(a)*P.dive.speed;S.dive=P.dive.every;sfx('roll',e.x,e.y);return{eng:true,mv:null}}
  if(S.side<=0&&d<10&&losClear(e.x,e.y,f.x,f.y)){e.st=74;e.stT=e.stM=P.sidearm.tell;e.lx=f.x;e.ly=f.y;S.side=P.sidearm.cd;return{eng:true,mv:null}}
  return{eng:false,mv:d<4?{x:e.x+(e.x-f.x),y:e.y+(e.y-f.y)}:d>7?{x:f.x,y:f.y}:null}}   // keeps his distance

// ---------- 8.5 THE VISITOR · the finale ----------
const US_VIS={hp:2800,speed:1.2,speed2:1.4,pulse:{tell:.8,speed:6,max:9,w:.45,dmg:24,cd:4},tank:{tell:1.2,r:1.3,dmg:30,acid:6,acidT:4,cd:6},
  blink:{tell:.9,r:2,dmg:16,cd:5},swarm:{n:6,cd:14},well:{tell:1,len:3,r:6,core:1.2,pull:1.2,dps:12,cd:12},desperate:.7,transition:3};
BOSSES.visitor={name:'THE VISITOR',hp:US_VIS.hp,speed:US_VIS.speed,scan:14,bounty:80,col:'#b8a8ff',think:thinkVisitor,us:true,box:'none',
  look:{body:'#9a9aa8',vest:'#7a7a88',pants:'#7a7a88',head:'#b8b8c4',gl:0,nogun:true},
  intro:'Psychic rings: roll through them. When the lights go out, a flash shows where it will be next.'};
ECODE.push('boss:visitor');BOSS_WEAK.visitor='fire';
function thinkVisitor(e,dt,tgt,mv,aimAt,Df){const U=game.us,P=US_VIS;if(!e.vi)e.vi={stage:1,pulse:2,tank:3.5,blink:3,swarm:4,well:6};const S=e.vi,k=S.stage===3?P.desperate:1;
  S.pulse-=dt/k;S.tank-=dt/k;S.blink-=dt/k;S.swarm-=dt/k;S.well-=dt/k;if(e.inv>0)e.inv-=dt;
  // half health: the containment fails and the lights go out (a scripted blackout); 10%: desperate, every cooldown x0.7
  if(S.stage===1&&e.hp<=e.max*.5){e.hp=e.max*.5;S.stage=2;e.st=82;e.stT=e.stM=P.transition;e.inv=P.transition;U.bossStage=1;
    toastAll('THE VISITOR · THE FIELD FAILS','The lights are out. A white flash shows where it lands next; light kills its drones.');sfx('horn',e.x,e.y);addShake(e.x,e.y,10);return{eng:true,mv:null}}
  if(S.stage===2&&e.hp<=e.max*.1){S.stage=3;U.bossStage=2;e.speed=P.speed2*1.15;toastAll('THE VISITOR · DESPERATE','Everything it does comes faster now. Finish it.');sfx('siren',e.x,e.y)}
  if(e.st===82){e.stT-=dt;if(e.stT<=0){e.st=0;e.speed=P.speed2}return{eng:true,mv:null}}
  if(e.st===83){e.stT-=dt;if(e.stT<=0){e.st=0;e.x=e.lx;e.y=e.ly;usFx('circle',{x:e.x,y:e.y,r:P.blink.r,dmg:P.blink.dmg,push:1,T:.3});sfx('zap',e.x,e.y)}return{eng:true,mv:null}}
  const f=usNearFoe(e);if(!f)return{eng:false,mv:null};const d=Math.hypot(f.x-e.x,f.y-e.y);aimAt(f.x,f.y);
  if(S.pulse<=0&&d<P.pulse.max+1){usFx('ring',{x:e.x,y:e.y,warn:P.pulse.tell,T:P.pulse.tell+P.pulse.max/P.pulse.speed});S.pulse=P.pulse.cd;sfx('lock',e.x,e.y)}
  if(S.stage===1&&S.tank<=0){const x1=f.x,y1=f.y;usFx('circle',{x:x1,y:y1,r:P.tank.r,dmg:P.tank.dmg,warn:P.tank.tell,T:P.tank.tell+.3,tank:1});usFx('acid',{x:x1,y:y1,r:P.tank.r,warn:P.tank.tell,T:P.tank.tell+P.tank.acidT});S.tank=P.tank.cd;sfx('lob',e.x,e.y)}
  if(S.stage>=2){
    if(S.blink<=0){const spots=[];const A=game.lay.arena;for(let n=0;n<30&&spots.length<1;n++){const x=A.x+2+rnd()*(A.w-4),y=A.y+2+rnd()*(A.h-4);if(!solidTile(x|0,y|0)&&Math.hypot(x-f.x,y-f.y)>2.5&&Math.hypot(x-f.x,y-f.y)<8)spots.push([x,y])}
      if(spots.length){e.st=83;e.stT=e.stM=P.blink.tell;e.lx=spots[0][0];e.ly=spots[0][1];usFx('blink',{x:e.lx,y:e.ly,warn:P.blink.tell,T:P.blink.tell});S.blink=P.blink.cd;sfx('mark',e.lx,e.ly);return{eng:true,mv:null}}}
    if(S.swarm<=0){usDronePack(e.x,e.y,P.swarm.n);for(const o of enemies)if(o.type==='drone'&&o.us&&!o.us.boss)o.us.boss=1;S.swarm=P.swarm.cd;toastAll('THE DRONES','A swarm. Light them up: they take double damage in your light.');sfx('siren',e.x,e.y)}
    if(S.well<=0&&d<P.well.r){usFx('well',{x:e.x,y:e.y,warn:P.well.tell,T:P.well.tell+P.well.len});S.well=P.well.cd;sfx('charge',e.x,e.y)}}
  return{eng:false,mv:d<3?null:{x:f.x,y:f.y}}}

// ---------- the warnings (drawBossFx) ----------
function usBossFx(e,f,pulse,ch){const c0=iso(e.x,e.y),red=a=>`rgba(255,60,40,${a})`;
  if(e.boss==='pitboss')return usPitFx(e,f,pulse,ch);
  if(e.st===63){usWedgeDraw(e.x,e.y,Math.atan2(e.ly-e.y,e.lx-e.x),US_CUS.mop.r,US_CUS.mop.half,`rgba(120,200,255,${.16+.2*pulse})`,`rgba(160,220,255,${.6+.3*pulse})`);return true}
  if(e.st===64||e.st===72||e.st===82){const t=e.st===64?'CASING CRACKED':e.st===72?'THE PILOT EJECTS':'THE FIELD FAILS',col=e.st===64?'#ff3a2a':e.st===72?'#7cff6b':'#b8a8ff';
    g.strokeStyle=col;g.globalAlpha=.4+.4*pulse;g.lineWidth=2.4*u;g.beginPath();g.ellipse(c0[0],c0[1],TW2*(1.2+f*.6),TH2*(1.2+f*.6),0,0,Math.PI*2);g.stroke();g.globalAlpha=1;label(t,c0[0],c0[1]-WH*2.3,col,11);return true}
  if(e.st===71){const r=US_GK.stomp.r*(1-f*.6);g.strokeStyle=red(.55+.3*pulse);g.lineWidth=2*u;g.beginPath();g.ellipse(c0[0],c0[1],TW2*US_GK.stomp.r,TH2*US_GK.stomp.r,0,0,Math.PI*2);g.stroke();
    g.strokeStyle=red(.3);g.beginPath();g.ellipse(c0[0],c0[1],TW2*r,TH2*r,0,0,Math.PI*2);g.stroke();return true}
  if(e.st===76){label('SHIELD',c0[0],c0[1]-WH*2.2,'#9ad8ff',10);return true}
  if(e.st===74){g.strokeStyle=red(.5+.3*pulse);g.lineWidth=1.2*u;bossLine(e.x,e.y,e.lx,e.ly,ch);return true}
  return e.st===75||e.st===83}
function usWedgeDraw(x,y,a0,r,half,fill,stroke){const c0=iso(x,y);g.fillStyle=fill;g.beginPath();g.moveTo(c0[0],c0[1]);
  for(let k=0;k<=12;k++){const a=a0+(k/12-.5)*2*half,c=iso(x+Math.cos(a)*r,y+Math.sin(a)*r);g.lineTo(c[0],c[1])}g.closePath();g.fill();if(stroke){g.strokeStyle=stroke;g.lineWidth=1.4*u;g.stroke()}}
// what's on the floor from the bosses (every phone draws it from the snapshot)
function usBfxDraw(pulse){const U=game.us;if(!U||!U.bfx)return;const t=game.time;
  for(const f of U.bfx){const c=iso(f.x,f.y),w=f.warn>0?Math.min(1,f.t/f.warn):1,live=f.t>=f.warn;
    if(f.k==='water'){usWedgeDraw(f.x,f.y,f.a,f.r,f.half,`rgba(90,170,255,${.16+.08*Math.sin(t*30)})`,null);for(let n=0;n<3;n++){const a=f.a+(Math.random()-.5)*2*f.half,d=Math.random()*f.r,p=iso(f.x+Math.cos(a)*d,f.y+Math.sin(a)*d);g.fillStyle='rgba(200,235,255,.8)';g.fillRect(p[0]-u,p[1]-u,2*u,2*u)}}
    else if(f.k==='gas'){const Q=[[f.x,f.y],[f.x1,f.y],[f.x1,f.y1],[f.x,f.y1]].map(q=>iso(q[0],q[1]));g.fillStyle=`rgba(150,210,70,${live?.26:.06+.16*w})`;g.strokeStyle=`rgba(180,230,90,${live?.5:.4+.4*pulse})`;g.lineWidth=1.6*u;
      g.beginPath();Q.forEach((q,i)=>i?g.lineTo(q[0],q[1]):g.moveTo(q[0],q[1]));g.closePath();g.fill();g.stroke();if(!live){const m=iso((f.x+f.x1)/2,(f.y+f.y1)/2);label('GAS',m[0],m[1],'#b8e06a',11)}}
    else if(f.k==='ring'){if(!live){g.strokeStyle=`rgba(184,168,255,${.4+.5*pulse})`;g.lineWidth=2.6*u;g.beginPath();g.ellipse(c[0],c[1],TW2*.9,TH2*.9,0,0,Math.PI*2);g.stroke()}
      else{const R=(f.t-f.warn)*US_VIS.pulse.speed;g.strokeStyle='rgba(184,168,255,.85)';g.lineWidth=US_VIS.pulse.w*2*TH2;g.beginPath();g.ellipse(c[0],c[1],TW2*R,TH2*R,0,0,Math.PI*2);g.stroke();
        g.strokeStyle='rgba(255,255,255,.5)';g.lineWidth=1.2*u;g.stroke()}}
    else if(f.k==='acid'&&live){g.fillStyle='rgba(124,255,107,.3)';g.beginPath();g.ellipse(c[0],c[1],TW2*f.r,TH2*f.r,0,0,Math.PI*2);g.fill();for(let n=0;n<3;n++){const a=t*2+n*2.1,p=[c[0]+Math.cos(a)*TW2*f.r*.5,c[1]+Math.sin(a*1.3)*TH2*f.r*.5];oval(p[0],p[1],2*u,1.2*u,'rgba(200,255,160,.7)')}}
    else if(f.k==='circle'&&!live){g.strokeStyle=`rgba(255,60,40,${.55+.35*pulse})`;g.lineWidth=1.8*u;g.beginPath();g.ellipse(c[0],c[1],TW2*f.r,TH2*f.r,0,0,Math.PI*2);g.stroke();
      g.fillStyle=f.tank?`rgba(10,20,20,${.2+.4*w})`:`rgba(255,60,40,${.12+.18*w})`;g.beginPath();g.ellipse(c[0],c[1],TW2*f.r*w,TH2*f.r*w,0,0,Math.PI*2);g.fill()}
    else if(f.k==='well'){const R=US_VIS.well.r;g.strokeStyle=`rgba(184,168,255,${live?.6:.3+.4*pulse})`;g.lineWidth=1.6*u;g.setLineDash([8*u,6*u]);g.lineDashOffset=-t*40;g.beginPath();g.ellipse(c[0],c[1],TW2*R,TH2*R,0,0,Math.PI*2);g.stroke();g.setLineDash([]);
      if(live){for(let n=0;n<6;n++){const a=t*3+n*1.05,r2=R*(1-((t*.6+n/6)%1));g.strokeStyle='rgba(184,168,255,.35)';g.beginPath();g.ellipse(c[0],c[1],TW2*r2,TH2*r2,0,a,a+1.2);g.stroke()}
        g.fillStyle='rgba(120,90,255,.35)';g.beginPath();g.ellipse(c[0],c[1],TW2*US_VIS.well.core,TH2*US_VIS.well.core,0,0,Math.PI*2);g.fill()}}
    else if(f.k==='turret'&&!live){g.strokeStyle=`rgba(255,60,40,${.45+.4*pulse})`;g.lineWidth=1.4*u;bossLine(f.x,f.y,f.x1,f.y1,WH*.55);const e=iso(f.x1,f.y1);label('TURRET',e[0],e[1]-WH*1.9,'#ff8a6a',10)}
    else if(f.k==='blink'){g.fillStyle=`rgba(255,255,255,${.25+.55*w})`;g.beginPath();g.ellipse(c[0],c[1],TW2*US_VIS.blink.r*w,TH2*US_VIS.blink.r*w,0,0,Math.PI*2);g.fill();g.strokeStyle='#fff';g.lineWidth=1.6*u;g.beginPath();g.ellipse(c[0],c[1],TW2*US_VIS.blink.r,TH2*US_VIS.blink.r,0,0,Math.PI*2);g.stroke()}}}

// ---------- the bosses' own models (the Pit Boss is the shared figure; the case's boss skins reuse these painters) ----------
function usDrawBoss(e){if(e.boss==='custodian'){usPaintCustodian(e.x,e.y,e.aim,e.walk,game.us&&game.us.bossStage>0,e.flash>0,1.5,e.st===63);return true}
  if(e.boss==='gatekeeper'){if(e.pilot){drawPerson(e.x,e.y,{aim:e.aim,walk:e.walk,flash:e.flash>0,hp:e.hp/e.max,big:1.1,tag:'THE PILOT',tagCol:'#7cff6b',body:'#e4e8ea',vest:'#7cff6b',pants:'#b8c0c4',head:'#a98262',helmet:'#e4e8ea',weapon:'pistol',gl:10});return true}
    usPaintGatekeeper(e.x,e.y,e.aim,e.walk,!!e.gk2||game.us&&game.us.bossStage>0,e.flash>0,!!((e.ub|0)&1));return true}
  if(e.boss==='visitor'){usPaintVisitor(e.x,e.y,e.aim,game.time,game.us&&game.us.bossStage>0,e.flash>0,1.5);return true}
  return false}
// a point s along the aim on screen, h up
const usAimPt=(c,aim,s,h)=>[c[0]+(aim.x-aim.y)*TW2*s,c[1]+(aim.x+aim.y)*TH2*s-h];
function usPaintCustodian(x,y,aim,walk,cracked,flash,k=1.5,mop=false){const c=iso(x,y),s=k*u,a=aim||{x:1,y:0},bob=Math.sin((walk||0)*.5)*s;
  oval(c[0],c[1],15*s,6*s,'rgba(0,0,0,.4)');
  g.fillStyle='#2a2c24';g.fillRect(c[0]-12*s,c[1]-6*s,24*s,7*s);g.fillStyle='#3a3c32';for(let n=0;n<5;n++)g.fillRect(c[0]-11*s+n*5*s,c[1]-5*s,3*s,5*s);   // treads
  g.fillStyle=flash?'#fff':'#7d8a5a';g.fillRect(c[0]-10*s,c[1]-34*s+bob,20*s,28*s);g.fillStyle='#5e6a44';g.fillRect(c[0]+4*s,c[1]-34*s+bob,6*s,28*s);   // the casing, its shaded side
  g.fillStyle='#d0782a';g.fillRect(c[0]-10*s,c[1]-20*s+bob,20*s,3*s);g.fillStyle='#2e3220';g.font=`900 ${5*s}px "Big Shoulders Stencil Display",sans-serif`;g.textAlign='center';g.fillText('S-7',c[0]-2*s,c[1]-24*s+bob);
  g.fillStyle='#6a7450';g.beginPath();g.ellipse(c[0],c[1]-35*s+bob,9*s,5*s,0,Math.PI,0);g.fill();   // the dome
  g.fillStyle=cracked?'#ff3a2a':'#ffd23a';g.beginPath();g.arc(c[0]+(a.x-a.y)*3*s,c[1]-37*s+bob,2.6*s,0,Math.PI*2);g.fill();   // the one lens
  if(cracked){g.strokeStyle='#1a1a12';g.lineWidth=1.2*s;g.beginPath();g.moveTo(c[0]-6*s,c[1]-31*s+bob);g.lineTo(c[0]-2*s,c[1]-25*s+bob);g.lineTo(c[0]-5*s,c[1]-18*s+bob);g.lineTo(c[0]-1*s,c[1]-11*s+bob);g.stroke();
    g.fillStyle='rgba(255,60,40,.6)';g.fillRect(c[0]-4*s,c[1]-26*s+bob,2*s,6*s)}
  // the mop arm: a pole along the aim, the head live with blue sparks while it winds up
  const p0=[c[0]+6*s,c[1]-22*s+bob],p1=usAimPt(c,a,1.4*k/1.5,8*s);g.strokeStyle='#8a7a5a';g.lineWidth=2*s;g.beginPath();g.moveTo(p0[0],p0[1]);g.lineTo(p1[0],p1[1]);g.stroke();
  g.fillStyle='#c8c0a0';g.beginPath();g.ellipse(p1[0],p1[1],5*s,2.4*s,0,0,Math.PI*2);g.fill();if(mop||Math.sin(game.time*9)>.7){g.strokeStyle='rgba(140,210,255,.9)';g.lineWidth=s;for(let n=0;n<3;n++){g.beginPath();g.moveTo(p1[0],p1[1]);g.lineTo(p1[0]+(Math.random()-.5)*10*s,p1[1]+(Math.random()-.5)*6*s);g.stroke()}}}
function usPaintGatekeeper(x,y,aim,walk,empty,flash,shield,k=1.5){const c=iso(x,y),s=k*u,a=aim||{x:1,y:0},st=Math.sin((walk||0)*.6);
  oval(c[0],c[1],16*s,6*s,'rgba(0,0,0,.4)');
  g.fillStyle='#8a959c';g.fillRect(c[0]-9*s,c[1]-16*s+st*s,5*s,16*s);g.fillRect(c[0]+4*s,c[1]-16*s-st*s,5*s,16*s);g.fillStyle='#5a646a';g.fillRect(c[0]-10*s,c[1]-3*s,7*s,3*s);g.fillRect(c[0]+3*s,c[1]-3*s,7*s,3*s);   // legs and feet
  g.fillStyle=flash?'#fff':'#cfd8dc';g.fillRect(c[0]-13*s,c[1]-36*s,26*s,21*s);g.fillStyle='#a8b2b8';g.fillRect(c[0]+5*s,c[1]-36*s,8*s,21*s);   // the torso
  g.fillStyle='#3a4248';g.fillRect(c[0]-17*s,c[1]-38*s,6*s,9*s);g.fillRect(c[0]+11*s,c[1]-38*s,6*s,9*s);g.fillStyle='#ff5a3a';for(let n=0;n<3;n++){g.fillRect(c[0]-16*s+n*1.6*s,c[1]-36*s,1*s,1*s);g.fillRect(c[0]+12*s+n*1.6*s,c[1]-36*s,1*s,1*s)}   // rocket pods
  g.fillStyle=empty?'#1a2024':'rgba(124,255,107,.55)';g.fillRect(c[0]-7*s,c[1]-33*s,12*s,8*s);if(!empty){g.fillStyle='#a98262';g.beginPath();g.arc(c[0]-1*s,c[1]-29*s,2.4*s,0,Math.PI*2);g.fill()}   // the cockpit, and its pilot
  else{g.strokeStyle='#cfd8dc';g.lineWidth=s;g.beginPath();g.moveTo(c[0]-6*s,c[1]-33*s);g.lineTo(c[0]+4*s,c[1]-26*s);g.stroke()}
  g.fillStyle='#e4e8ea';g.fillRect(c[0]-4*s,c[1]-40*s,8*s,4*s);g.fillStyle='#3aa0d0';g.fillRect(c[0]-3*s,c[1]-39*s,6*s,1.4*s);
  if(shield){const a0=Math.atan2(a.y,a.x);g.strokeStyle=`rgba(154,216,255,${.6+.3*Math.sin(game.time*12)})`;g.lineWidth=3*s;g.beginPath();
    for(let n=0;n<=10;n++){const q=a0+(n/10-.5)*2.1,p=iso(x+Math.cos(q)*1.1,y+Math.sin(q)*1.1);if(n)g.lineTo(p[0],p[1]-18*s);else g.moveTo(p[0],p[1]-18*s)}g.stroke();
    g.fillStyle='rgba(154,216,255,.15)';g.fill()}}
function usPaintVisitor(x,y,aim,t,dark,flash,k=1.5){const c=iso(x,y),s=k*u,h=Math.sin(t*1.6)*2*s,a=aim||{x:1,y:0};
  const gl=g.createRadialGradient(c[0],c[1]-30*s,2*s,c[0],c[1]-30*s,30*s);gl.addColorStop(0,'rgba(184,168,255,.45)');gl.addColorStop(1,'rgba(184,168,255,0)');g.fillStyle=gl;g.fillRect(c[0]-30*s,c[1]-60*s,60*s,60*s);   // its glow
  oval(c[0],c[1],8*s,3*s,'rgba(0,0,0,.3)');
  const body=flash?'#fff':dark?'#4a4a58':'#9a9aa8';g.fillStyle=body;
  g.beginPath();g.moveTo(c[0]-3*s,c[1]-4*s+h);g.lineTo(c[0]-5*s,c[1]-26*s+h);g.lineTo(c[0]+5*s,c[1]-26*s+h);g.lineTo(c[0]+3*s,c[1]-4*s+h);g.closePath();g.fill();   // a thin body, floating
  g.strokeStyle=body;g.lineWidth=1.6*s;g.beginPath();g.moveTo(c[0]-5*s,c[1]-24*s+h);g.lineTo(c[0]-9*s,c[1]-12*s+h);g.lineTo(c[0]-8*s,c[1]-6*s+h);g.moveTo(c[0]+5*s,c[1]-24*s+h);const hand=usAimPt(c,a,.7,14*s-h);g.lineTo(hand[0],hand[1]);g.stroke();   // long arms, one reaching
  g.fillStyle=flash?'#fff':dark?'#5a5a6a':'#b8b8c4';g.beginPath();g.ellipse(c[0],c[1]-33*s+h,8*s,9*s,0,0,Math.PI*2);g.fill();g.beginPath();g.moveTo(c[0]-6*s,c[1]-29*s+h);g.lineTo(c[0],c[1]-22*s+h);g.lineTo(c[0]+6*s,c[1]-29*s+h);g.fill();   // the head, the narrow chin
  g.fillStyle='#08080c';for(const sx of[-1,1]){g.save();g.translate(c[0]+sx*3.4*s+(a.x-a.y)*.8*s,c[1]-33*s+h);g.rotate(sx*.45);g.beginPath();g.ellipse(0,0,2.6*s,4.2*s,0,0,Math.PI*2);g.fill();g.restore()}   // the eyes
  g.fillStyle='rgba(255,255,255,.6)';g.fillRect(c[0]-4*s,c[1]-35*s+h,1*s,1*s);g.fillRect(c[0]+3*s,c[1]-35*s+h,1*s,1*s)}
