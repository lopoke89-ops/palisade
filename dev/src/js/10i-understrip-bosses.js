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
function usBossWake(){const U=game.us;if(U.bossSpawned||NET.mode==='guest')return;U.bossSpawned=true;U.bossStage=0;spawnBoss('pitboss')}
function usBossReset(){const U=game.us;if(!U||!game.lay.arena)return;enemies=enemies.filter(e=>e.type!=='boss'&&!(e.us&&e.us.call));U.bossSpawned=false;U.bossStage=0;U.floodOn=false;floodOn=false;usGateOpen()}
// usTick: the boss is down (once), so the arena's shrine and the lift wake
function usBossTick(){const U=game.us;if(!U.bossSpawned||U.bossDown)return;if(enemies.some(e=>e.type==='boss'&&!e.dead))return;
  U.bossDown=true;U.floodOn=false;floodOn=false;U.floodWarned=false;U.flood=US.flood.every[0];usGateOpen();markFlow();   // the water drains, and the flash floods start over
  toastAll('THE PIT BOSS IS DOWN','The count room\'s shrine is lit and the lift is running. Rest, then take it down.')}
// the bar shows the stage's own health
const usBossFrac=e=>{const f=e.hp/e.max,s2=game.us&&game.us.bossStage>0;return clamp(s2?f/.5:(f-.5)/.5,0,1)};
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
