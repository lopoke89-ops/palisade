/* v0.9.6.5: two new moves each for the four bosses that had one attack (the Stormcaller, the Tempest, the Arsonist and the
   Bulldozer). Each is a boss state (20-31) with a timed warning, so guests draw the same warning from the snapshot's
   st / stF / lx / ly with no new fields. The boss's original AI still runs: a new move only starts when he is free, and after
   one he goes back to his own attack before the next. Other bosses that borrow these AIs (the Permafrost Foreman uses the
   Bulldozer's) call the original functions directly and are unchanged. */
const MOVE={
  strike:{tell:1.1,r:1.05,dmg:30,stun:.5,gap:1.6,cd:11},          // Stormcaller: Thunderstrike
  pulse:{tell:.8,r:4,dmg:22,push:2,cd:9},                          // Stormcaller: Static Pulse
  cyclone:{tell:.8,go:3,len:9,r:.95,dps:8,cd:12},                   // Tempest: Cyclone
  cage:{tell:2.5,r:2,dmg:35,stun:.8,cd:10},                         // Tempest: Storm Cage
  flame:{tell:.7,go:1.5,tick:.3,range:3.6,half:.45,dmg:12,cd:7},    // Arsonist: Flamethrower
  firering:{tell:1.2,r:2.2,n:8,burn:6,cd:11},                       // Arsonist: Ring of Fire
  slam:{tell:.9,r:3.5,dmg:28,push:1.5,wall:90,cd:8},                // Bulldozer: Seismic Slam
  overdrive:{tell:1.5,off:1.4,dmg:24,cd:12}};                       // Bulldozer: Overdrive
const ST_MOVE={20:'strike',21:'pulse',22:'cyclone',23:'cyclone',24:'cage',25:'flame',26:'flame',27:'firering',28:'slam',29:'overdrive',30:'overdrive'};
// the three Thunderstrike points: on the target and either side of it, across the line from the boss
function strikePts(x,y,lx,ly){const a=Math.atan2(ly-y,lx-x),px=-Math.sin(a)*MOVE.strike.gap,py=Math.cos(a)*MOVE.strike.gap;return[[lx,ly],[lx+px,ly+py],[lx-px,ly-py]]}
// Overdrive's three legs: a zig-zag from the boss to the target point
function overdrivePts(x,y,lx,ly){const dx=lx-x,dy=ly-y,l=Math.hypot(dx,dy)||1,px=-dy/l*MOVE.overdrive.off,py=dx/l*MOVE.overdrive.off;
  return[[clamp(x+dx/3+px,.3,N-.3),clamp(y+dy/3+py,.3,N-.3)],[clamp(x+dx*2/3-px,.3,N-.3),clamp(y+dy*2/3-py,.3,N-.3)],[lx,ly]]}
// where the Cyclone is: from the boss to the end of its lane over the travel time (the boss stands still while it runs)
const cyclonePos=(e,f)=>[e.x+(e.lx-e.x)*(1-f),e.y+(e.ly-e.y)*(1-f)];
function knock(a,fx,fy,dist){const dx=a.x-fx,dy=a.y-fy,l=Math.hypot(dx,dy)||1,n=Math.ceil(dist/.4);for(let s=0;s<n;s++)moveEnt(a,dx/l*dist/n,dy/l*dist/n,a===qm?true:pt(a))}
function inWedge(e,x,y,range,half){const d=Math.hypot(x-e.x,y-e.y);if(d>range)return false;let da=Math.abs(Math.atan2(y-e.y,x-e.x)-Math.atan2(e.ly-e.y,e.lx-e.x));if(da>Math.PI)da=2*Math.PI-da;return da<half}
function setMove(e,st,T,lx,ly){e.st=st;e.stT=e.stM=T;e.lx=clamp(lx,.3,N-.3);e.ly=clamp(ly,.3,N-.3);e.lastNew=true}

// pick a new move for this boss now, or none (host)
function startMove(k,e){
  const f=e.foe;if(!f||!f.alive||e.cd>0||e.lastNew)return false;const d=Math.hypot(f.x-e.x,f.y-e.y);
  if(k==='storm'){
    if(d<MOVE.pulse.r&&e.mvA<=0){setMove(e,21,MOVE.pulse.tell,e.x,e.y);e.mvA=MOVE.pulse.cd;sfx('charge',e.x,e.y);return true}
    if(d<12&&e.mvB<=0){setMove(e,20,MOVE.strike.tell,f.x,f.y);e.mvB=MOVE.strike.cd;sfx('charge',e.x,e.y);return true}}
  else if(k==='tempest'){
    if(d>2.5&&d<10&&e.mvA<=0){const a=Math.atan2(f.y-e.y,f.x-e.x);setMove(e,22,MOVE.cyclone.tell,e.x+Math.cos(a)*MOVE.cyclone.len,e.y+Math.sin(a)*MOVE.cyclone.len);e.mvA=MOVE.cyclone.cd;sfx('charge',e.x,e.y);return true}
    if(d<11&&e.mvB<=0){setMove(e,24,MOVE.cage.tell,f.x,f.y);e.mvB=MOVE.cage.cd;sfx('charge',e.x,e.y);return true}}
  else if(k==='arsonist'){
    if(d<MOVE.flame.range&&e.mvA<=0){setMove(e,25,MOVE.flame.tell,f.x,f.y);e.mvA=MOVE.flame.cd;sfx('lock',e.x,e.y);return true}
    if(d<9.5&&e.mvB<=0){setMove(e,27,MOVE.firering.tell,f.x,f.y);e.mvB=MOVE.firering.cd;sfx('lock',e.x,e.y);return true}}
  else if(k==='bulldozer'){
    if(d<3&&e.mvA<=0){setMove(e,28,MOVE.slam.tell,e.x,e.y);e.mvA=MOVE.slam.cd;sfx('drill',e.x,e.y);return true}
    if(d>3.5&&d<10&&e.mvB<=0){setMove(e,29,MOVE.overdrive.tell,f.x,f.y);e.mvB=MOVE.overdrive.cd;sfx('drill',e.x,e.y);return true}}
  return false;
}
// run the move in progress (host)
function runMove(e,dt,aimAt,Df){
  e.stT-=dt;aimAt(e.lx,e.ly);const done=e.stT<=0,end=(cd=1.2)=>{e.st=0;e.cd=cd};
  switch(e.st){
    case 20:if(done){const M=MOVE.strike;for(const[x,y]of strikePts(e.x,e.y,e.lx,e.ly)){
        for(const a of allies())if(a.alive&&groundReach(a.x,a.y,x,y,M.r)){hurtAlly(a,M.dmg*Df.dmg);stunAlly(a,M.stun)}
        ringFx(x,y,.1,M.r,.45,'#ffffff','#7fe0ff',3);addFlash({x,y,life:.2,max:.2,r:1.6});for(let n=0;n<6;n++)emit(x,y,WH*.6,'arc')}
      sfx('zap',e.lx,e.ly);addShake(e.lx,e.ly,6);end()}break;
    case 21:if(done){const M=MOVE.pulse;for(const a of allies())if(a.alive&&groundReach(a.x,a.y,e.x,e.y,M.r)){hurtAlly(a,M.dmg*Df.dmg);knock(a,e.x,e.y,M.push);addShake(a.x,a.y,5)}
      ringFx(e.x,e.y,.3,M.r,.5,'#ffffff','#7fe0ff',3);sfx('zap',e.x,e.y);end()}break;
    case 22:if(done){e.st=23;e.stT=e.stM=MOVE.cyclone.go;e.cyT=0;sfx('rumble',e.x,e.y)}break;
    case 23:{const M=MOVE.cyclone,[cx,cy]=cyclonePos(e,Math.max(0,e.stT/e.stM));e.cyT-=dt;
      if(rnd()<dt*25)emit(cx+(rnd()-.5)*.8,cy+(rnd()-.5)*.8,WH*.5,'dust',0);
      for(const a of allies())if(a.alive&&groundReach(a.x,a.y,cx,cy,M.r)){if(e.cyT<=0)hurtAlly(a,M.dps*.5*Df.dmg);const ux=(e.lx-e.x),uy=(e.ly-e.y),l=Math.hypot(ux,uy)||1;moveEnt(a,ux/l*dt*2.4,uy/l*dt*2.4,a===qm?true:pt(a))}
      const k=idx(clamp(Math.floor(cx),0,N-1),clamp(Math.floor(cy),0,N-1));if(walls[k]&&walls[k].mat===0)damageWall(k,walls[k].max*4);
      if(e.cyT<=0)e.cyT=.5;if(done)end(1.4);break}
    case 24:if(done){const M=MOVE.cage;for(const a of allies())if(a.alive&&groundReach(a.x,a.y,e.lx,e.ly,M.r)){hurtAlly(a,M.dmg*Df.dmg);stunAlly(a,M.stun)}
      ringFx(e.lx,e.ly,M.r,.2,.4,'#ffffff','#bff4ff',3);zapFx([e.lx-M.r,e.ly,e.lx,e.ly,e.lx+M.r,e.ly]);sfx('zap',e.lx,e.ly);addShake(e.lx,e.ly,6);end()}break;
    case 25:if(done){e.st=26;e.stT=e.stM=MOVE.flame.go;e.flT=0;sfx('bottle',e.x,e.y)}break;
    case 26:{const M=MOVE.flame;e.flT-=dt;if(rnd()<dt*30){const a=Math.atan2(e.ly-e.y,e.lx-e.x)+(rnd()-.5)*M.half*2,r=rnd()*M.range;emit(e.x+Math.cos(a)*r,e.y+Math.sin(a)*r,WH*.4,'fire')}
      if(e.flT<=0){e.flT=M.tick;for(const a of allies())if(a.alive&&inWedge(e,a.x,a.y,M.range,M.half))hurtAlly(a,M.dmg*Df.dmg);
        for(let i=Math.floor(e.x-M.range);i<=e.x+M.range;i++)for(let j=Math.floor(e.y-M.range);j<=e.y+M.range;j++)if(inb(i,j)&&inWedge(e,i+.5,j+.5,M.range,M.half)){const w=walls[idx(i,j)];if(w&&w.mat===0&&!(w.fire>0))w.fire=6}}
      if(done)end(1.2);break}
    case 27:if(done){const M=MOVE.firering;for(let n=0;n<M.n;n++){const a=n*Math.PI*2/M.n,x=clamp(e.lx+Math.cos(a)*M.r,.3,N-.3),y=clamp(e.ly+Math.sin(a)*M.r,.3,N-.3);fires.push({x,y,t:M.burn,max:M.burn,tick:.3,r:.8,nap:1});for(let q=0;q<4;q++)emit(x,y,4*u,'fire')}
      sfx('bottle',e.lx,e.ly);addShake(e.lx,e.ly,3);end(1.4)}break;
    case 28:if(done){const M=MOVE.slam;for(const a of allies())if(a.alive&&groundReach(a.x,a.y,e.x,e.y,M.r)){hurtAlly(a,M.dmg*Df.dmg);knock(a,e.x,e.y,M.push)}
      for(let i=Math.floor(e.x-M.r);i<=e.x+M.r;i++)for(let j=Math.floor(e.y-M.r);j<=e.y+M.r;j++)if(inb(i,j)&&groundReach(e.x,e.y,i+.5,j+.5,M.r)){const k=idx(i,j);if(walls[k])damageWall(k,M.wall*MAT[walls[k].mat].blast);else if(coreKs.has(k))hurtStake(stakeAt(k),20*Df.dmg)}
      ringFx(e.x,e.y,.3,M.r,.55,'#ffe9a0','#ffd23a',3.5);sfx('bigboom',e.x,e.y);addShake(e.x,e.y,9);for(let q=0;q<10;q++)emit(e.x+(rnd()-.5)*2,e.y+(rnd()-.5)*2,4*u,'dust',0);end(1)}break;
    case 29:if(done){e.odPts=overdrivePts(e.x,e.y,e.lx,e.ly);e.odLeg=0;e.st=30;e.stT=e.stM=3;e.hit=new Set();sfx('charge',e.x,e.y)}break;
    case 30:return overdriveRun(e,dt,Df);
  }
  return{eng:true,mv:null};
}
// three rams, one leg after another; walls in the way take a heavy hit and end that leg; only the last leg can daze him
function overdriveRun(e,dt,Df){
  const moveDt=dt*(1-(e.slowT>0?e.slowPct||0:0));let blocked=false;
  for(let s=0;s<4;s++){const P=e.odPts[e.odLeg],dx=P[0]-e.x,dy=P[1]-e.y,l=Math.hypot(dx,dy);
    if(l<.15){e.odLeg++;e.hit=new Set();if(e.odLeg>=3)break;continue}
    const step=Math.min(l,BULL.speed*moveDt/4),nx=e.x+dx/l*step,ny=e.y+dy/l*step,i=Math.floor(nx),j=Math.floor(ny);
    let stop=!heightTravelClear(e.x,e.y,nx,ny)||!inb(i,j)||(nodeAt(i,j)||{}).solid||terrSolid(terr[idx(i,j)]);
    if(!stop){const k=idx(i,j);if(coreKs.has(k)){hurtStake(stakeAt(k),30*Df.dmg);stop=true}
      else if(walls[k]){damageWall(k,200*MAT[walls[k].mat].blast);addShake(nx,ny,8);sfx('collapse',nx,ny);if(walls[k])stop=true}}
    if(stop){blocked=true;e.odLeg++;e.hit=new Set();if(e.odLeg>=3)break;continue}
    e.x=nx;e.y=ny;
    for(const a of allies())if(a.alive&&!e.hit.has(a)&&Math.hypot(a.x-e.x,a.y-e.y)<.65){e.hit.add(a);hurtAlly(a,MOVE.overdrive.dmg*Df.dmg);
      const sd=((a.x-e.x)*-dy+(a.y-e.y)*dx)>=0?1:-1;moveEnt(a,-dy/l*.6*sd,dx/l*.6*sd,a===qm?true:pt(a));addShake(a.x,a.y,6)}}
  e.walk+=dt*20;if(rnd()<.6)emit(e.x,e.y,4*u,'dust',0);   // stT already counted down in runMove
  if(e.odLeg>=3||e.stT<=0){
    if(blocked&&e.odLeg>=3){e.st=6;e.stT=e.stM=BULL.daze;flt(e.x,e.y-.5,'DAZED','#ffd23a');addShake(e.x,e.y,8)}else{e.st=0;e.cd=.8}}
  return{eng:true,mv:null};
}
// wrap the four bosses' AI
for(const k of['storm','tempest','arsonist','bulldozer']){const base=BOSSES[k].think;
  BOSSES[k].think=(e,dt,tgt,mv,aimAt,Df)=>{
    e.mvA=(e.mvA??4)-dt;e.mvB=(e.mvB??7)-dt;
    if(e.st>=20&&e.st<=30)return runMove(e,dt,aimAt,Df);
    if(!e.st&&startMove(k,e))return{eng:true,mv:null};
    const r=base(e,dt,tgt,mv,aimAt,Df);if(e.st&&e.st<20)e.lastNew=false;   // his own attack has started: a new move may follow it
    return r}}

// the warnings (host and guests alike, from st / stF / lx / ly)
function drawBossMove(e,f,pulse,ch){
  const k=ST_MOVE[e.st];if(!k)return false;
  const ring=(x,y,r,col,w=2)=>{const q=iso(x,y);g.strokeStyle=col;g.lineWidth=w*u;g.beginPath();g.ellipse(q[0],q[1],TW2*r,TH2*r,0,0,Math.PI*2);g.stroke()};
  const disc=(x,y,r,col)=>{const q=iso(x,y);g.fillStyle=col;g.beginPath();g.ellipse(q[0],q[1],TW2*r,TH2*r,0,0,Math.PI*2);g.fill()};
  const lane=(x0,y0,x1,y1,w,fill,line)=>{const dx=x1-x0,dy=y1-y0,l=Math.hypot(dx,dy)||1,nx=-dy/l*w,ny=dx/l*w,P=[[x0+nx,y0+ny],[x1+nx,y1+ny],[x1-nx,y1-ny],[x0-nx,y0-ny]].map(q=>iso(q[0],q[1]));
    g.fillStyle=fill;g.strokeStyle=line;g.lineWidth=1.6*u;g.beginPath();P.forEach((q,i)=>i?g.lineTo(q[0],q[1]):g.moveTo(q[0],q[1]));g.closePath();g.fill();g.stroke()};
  const wedge=(range,half,fill)=>{const a0=Math.atan2(e.ly-e.y,e.lx-e.x),c0=iso(e.x,e.y);g.fillStyle=fill;g.beginPath();g.moveTo(c0[0],c0[1]);
    for(let n=0;n<=10;n++){const a=a0+(n/10-.5)*half*2,c=iso(e.x+Math.cos(a)*range,e.y+Math.sin(a)*range);g.lineTo(c[0],c[1])}g.closePath();g.fill()};
  switch(e.st){
    case 20:for(const[x,y]of strikePts(e.x,e.y,e.lx,e.ly)){disc(x,y,MOVE.strike.r,`rgba(127,224,255,${.12+.18*pulse})`);ring(x,y,MOVE.strike.r*(1.3-.3*(1-f)),`rgba(200,245,255,${.6+.35*pulse})`)}break;
    case 21:disc(e.x,e.y,MOVE.pulse.r*(1-f),`rgba(127,224,255,${.12+.12*pulse})`);ring(e.x,e.y,MOVE.pulse.r,`rgba(127,224,255,${.55+.4*pulse})`,2.2);break;
    case 22:lane(e.x,e.y,e.lx,e.ly,MOVE.cyclone.r,`rgba(191,244,255,${.12+.16*pulse})`,`rgba(191,244,255,${.55+.35*pulse})`);break;
    case 23:{const[cx,cy]=cyclonePos(e,f),q=iso(cx,cy),t=game.time;g.strokeStyle='rgba(220,248,255,.75)';g.lineWidth=1.6*u;
      for(let n=0;n<4;n++){const r=(.35+n*.18)*MOVE.cyclone.r,a=t*8+n;g.beginPath();g.ellipse(q[0],q[1]-n*6*u,TW2*r,TH2*r,0,a,a+4.2);g.stroke()}break}
    case 24:{const M=MOVE.cage,gapA=Math.atan2(e.ly-e.y,e.lx-e.x);disc(e.lx,e.ly,M.r,`rgba(191,244,255,${.08+.14*(1-f)})`);
      for(let n=0;n<14;n++){const a=n*Math.PI*2/14;let da=Math.abs(a-gapA)%(Math.PI*2);if(da>Math.PI)da=2*Math.PI-da;if(da<.4)continue;
        const c=iso(e.lx+Math.cos(a)*M.r,e.ly+Math.sin(a)*M.r);g.strokeStyle=`rgba(230,250,255,${.6+.35*pulse})`;g.lineWidth=2*u;g.beginPath();g.moveTo(c[0],c[1]);g.lineTo(c[0],c[1]-ch*(1.2-f*.6));g.stroke()}
      break}
    case 25:wedge(MOVE.flame.range,MOVE.flame.half,`rgba(255,140,40,${.16+.2*pulse})`);break;
    case 26:wedge(MOVE.flame.range*(.85+.15*Math.sin(game.time*30)),MOVE.flame.half,`rgba(255,${120+60*pulse|0},40,.42)`);break;
    case 27:{const M=MOVE.firering;ring(e.lx,e.ly,M.r,`rgba(255,110,40,${.5+.4*pulse})`,2.2);for(let n=0;n<M.n;n++){const a=n*Math.PI*2/M.n;ring(e.lx+Math.cos(a)*M.r,e.ly+Math.sin(a)*M.r,.7*(1.2-.2*(1-f)),`rgba(255,150,60,${.45+.4*pulse})`,1.4)}break}
    case 28:disc(e.x,e.y,MOVE.slam.r,`rgba(255,210,58,${.1+.16*pulse})`);ring(e.x,e.y,MOVE.slam.r*(1.15-.15*(1-f)),`rgba(255,210,58,${.6+.35*pulse})`,2.4);break;
    case 29:{const P=overdrivePts(e.x,e.y,e.lx,e.ly),shown=Math.min(3,Math.floor((1-f)*3)+1);let x0=e.x,y0=e.y;
      for(let n=0;n<shown;n++){lane(x0,y0,P[n][0],P[n][1],.45,`rgba(255,210,58,${.14+.2*pulse})`,`rgba(255,220,90,${.6+.3*pulse})`);x0=P[n][0];y0=P[n][1]}break}
    case 30:break;
  }
  return true;
}

// v0.9.6.5 weaknesses: a bullet carrying the boss's weak ammo deals +35% bullet damage (not burn ticks or splash)
const BOSS_WEAK={demolisher:'ap',bulldozer:'ap',rime:'fire',whitebutcher:'fire',whiteferryman:'fire',whiteforeman:'fire',
  storm:'blast',foreman:'blast',tempest:'blast',butcher:'shock',bluebutcher:'shock',arsonist:'shock',ferryman:'shock',harbinger:'shock'};
const WEAK_BONUS=1.35,BOSS_HP=1.25;   // and every boss has 25% more health (stacks with map, XL, crew and gauntlet scaling)
function bossWeak(e,b){
  if(e.type!=='boss'||!ammoMode()||!b.ammo||!b.ammo.length)return 1;const w=BOSS_WEAK[e.boss];if(!w||!b.ammo.some(a=>a[0]===w))return 1;
  if(!e.weakSeen){e.weakSeen=true;flt(e.x,e.y-.6,'WEAK POINT','#ffe08a')}
  return WEAK_BONUS;
}
