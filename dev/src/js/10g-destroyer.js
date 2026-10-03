/* ================= v0.9.7 THE SUPREME DESTROYER ================= */
// City Black Out's last boss: a war-machine commander about twice a boss's size, ~7x a boss's health, weak to Armor
// Piercing. Five attacks, each with a warning drawn from the snapshot's st / stF / lx / ly (no new network fields):
//   40 Back Rockets: six landing rings round his target (1.4 s), then six missiles arc in
//   41/42 Fire barrel: a marked lane (0.9 s), then a stream down it that burns people and lights wood
//   43 Lightning barrel: a tracking blue line, then a heavier Stormcaller bolt that stuns and jumps
//   44 Poison Gas: a green ring grows round him (2 s), then a gas cloud fills it for 8 s
//   45 Minefield: a marked area (1 s), then ten mines; they arm after 1 s and blow when someone steps close.
//      Shooting one, or a grenade near it, sets it off safely
//   46/47 Orbital Cannon (below 40%, every 20 s): a targeting circle follows someone for 3 s, stops for 1 s, then a beam
// Gas clouds and mines live in `fires` (nap 2 and 3), so guests get them in the snapshot like napalm.
const DEST={hp:700*7,big:2.4,rockets:{tell:1.4,n:6,r:1.7,R:1.5,pw:1.35},fire:{tell:.9,go:1.6,len:7,w:.6,tick:.25,dmg:9},bolt:{tell:1.1,dmg:1.6},
  gas:{tell:2,r:3.2,t:8,dmg:4},mines:{tell:1,n:10,r:2.6,arm:1,life:40,trip:.7,R:1.3,pw:1.15},orb:{follow:3,lock:1,speed:2.6,r:1.8,dmg:70,wall:400,every:20,below:.4}};
Object.assign(BOSSES,{destroyer:{name:'THE SUPREME DESTROYER',hp:DEST.hp,speed:.85,scan:13,bounty:120,col:'#ff6a2a',think:thinkDestroyer,big:DEST.big,
  look:{body:'#2a2c30',vest:'#14161a',pants:'#1c1e22',head:'#8c7058',helmet:'#202226',pack:'#32353a',bandana:'#ff6a2a',glow:'#ff6a2a',gl:24,weapon:'rpg'},
  intro:'Back rockets, a fire-and-lightning gun, poison gas and mines. Below 40% he calls an orbital cannon. Every attack is marked first: read it and move.'}});
ECODE.push('boss:destroyer');   // append only
BOSS_WEAK.destroyer='ap';

// the six rocket landing spots: on the target and in a ring round it, turned to face the boss
function rocketPts(x,y,lx,ly){const a0=Math.atan2(ly-y,lx-x),R=DEST.rockets.r,out=[[lx,ly]];
  for(let n=0;n<5;n++){const a=a0+n*Math.PI*2/5;out.push([clamp(lx+Math.cos(a)*R,.3,N-.3),clamp(ly+Math.sin(a)*R,.3,N-.3)])}return out}
// the fire lane's far end (fixed length from the boss toward his mark)
function fireEnd(e){const dx=e.lx-e.x,dy=e.ly-e.y,l=Math.hypot(dx,dy)||1;return[clamp(e.x+dx/l*DEST.fire.len,.3,N-.3),clamp(e.y+dy/l*DEST.fire.len,.3,N-.3)]}
function inLane(x,y,x0,y0,x1,y1,w){const dx=x1-x0,dy=y1-y0,L2=dx*dx+dy*dy||1,t=clamp(((x-x0)*dx+(y-y0)*dy)/L2,0,1);return Math.hypot(x-(x0+dx*t),y-(y0+dy*t))<w}
function destState(e,st,T,lx,ly){e.st=st;e.stT=e.stM=T;e.lx=clamp(lx,.3,N-.3);e.ly=clamp(ly,.3,N-.3)}

function thinkDestroyer(e,dt,tgt,mv,aimAt,Df){
  e.orbT=(e.orbT??4)-dt;
  if(!e.rage&&e.hp<e.max*DEST.orb.below){e.rage=true;flt(e.x,e.y-.6,'ORBITAL CANNON ONLINE','#ff6a2a');sfx('siren')}
  if(e.st>=40&&e.st<=47)return runDestroyer(e,dt,aimAt,Df);
  const f=e.foe&&e.foe.alive?e.foe:null,d=f?Math.hypot(f.x-e.x,f.y-e.y):1e9;
  if(e.cd<=0&&(f||tgt)){
    const t=f||tgt;
    if(e.rage&&f&&e.orbT<=0){destState(e,46,DEST.orb.follow,f.x,f.y);e.orbT=DEST.orb.every;sfx('lock',e.x,e.y);return{eng:true,mv:null}}
    const seq=['rockets','gun','gas','mines'];
    for(let n=0;n<4;n++){const k=seq[(e.seq=(e.seq|0)+1)%4];
      if(k==='rockets'){destState(e,40,DEST.rockets.tell,t.x,t.y);sfx('lock',e.x,e.y);return{eng:true,mv:null}}
      if(k==='gun'&&f&&d<11){e.barrel=!e.barrel;if(e.barrel){destState(e,41,DEST.fire.tell,f.x,f.y);sfx('lock',e.x,e.y)}else{destState(e,43,DEST.bolt.tell,f.x,f.y);sfx('charge',e.x,e.y)}return{eng:true,mv:null}}
      if(k==='gas'&&f&&d<DEST.gas.r+.5){destState(e,44,DEST.gas.tell,e.x,e.y);sfx('rumble',e.x,e.y);return{eng:true,mv:null}}
      if(k==='mines'&&f&&d<10){destState(e,45,DEST.mines.tell,f.x,f.y);sfx('lock',e.x,e.y);return{eng:true,mv:null}}}
  }
  if(f){aimAt(f.x,f.y);if(d<9)return{eng:true,mv:null}}   // in range: he stands and fights
  return{eng:false,mv};                                     // otherwise he walks the path to Main Command
}
function runDestroyer(e,dt,aimAt,Df){
  e.stT-=dt;aimAt(e.lx,e.ly);const done=e.stT<=0,end=(cd=1.6)=>{e.st=0;e.cd=cd};
  switch(e.st){
    case 40:if(done){const M=DEST.rockets;rocketPts(e.x,e.y,e.lx,e.ly).forEach(([x1,y1],m)=>{const d=Math.hypot(x1-e.x,y1-e.y);
        lobs.push({x0:e.x,y0:e.y,x1,y1,t:-m*.12,T:1.1+d*.03,R:M.R,power:M.pw*Df.dmg,k:3})});
      sfx('rocket',e.x,e.y);addShake(e.x,e.y,5);end(2.2)}break;
    case 41:if(done){e.st=42;e.stT=e.stM=DEST.fire.go;e.flT=0;sfx('bottle',e.x,e.y)}break;
    case 42:{const M=DEST.fire,[x1,y1]=fireEnd(e);e.flT-=dt;
      if(rnd()<dt*40){const t=rnd();emit(e.x+(x1-e.x)*t+(rnd()-.5)*.6,e.y+(y1-e.y)*t+(rnd()-.5)*.6,WH*.4,'fire')}
      if(e.flT<=0){e.flT=M.tick;for(const a of allies())if(a.alive&&inLane(a.x,a.y,e.x,e.y,x1,y1,M.w))hurtAlly(a,M.dmg*Df.dmg);
        const L=Math.hypot(x1-e.x,y1-e.y);for(let s=.5;s<L;s+=.5){const i=Math.floor(e.x+(x1-e.x)*s/L),j=Math.floor(e.y+(y1-e.y)*s/L);if(!inb(i,j))continue;const w=walls[idx(i,j)];if(w&&w.mat===0&&!(w.fire>0))w.fire=6}}
      if(done){for(let n=1;n<=4;n++){const t=n/4;fires.push({x:e.x+(x1-e.x)*t,y:e.y+(y1-e.y)*t,t:5,max:5,tick:.3})}end(1.6)}break}
    case 43:if(e.stT>.35&&e.foe&&e.foe.alive){e.lx=e.foe.x;e.ly=e.foe.y}
      if(done){lightning(e,{...Df,dmg:Df.dmg*DEST.bolt.dmg});end(1.8)}break;
    case 44:if(done){const M=DEST.gas;fires.push({x:e.lx,y:e.ly,t:M.t,max:M.t,tick:.2,r:M.r,nap:2});sfx('rumble',e.x,e.y);for(let n=0;n<14;n++)emit(e.lx+(rnd()-.5)*4,e.ly+(rnd()-.5)*4,WH*.3,'smoke');end(2)}break;
    case 45:if(done){const M=DEST.mines;for(let n=0;n<M.n;n++)for(let tr=0;tr<4;tr++){const a=rnd()*6.283,r=Math.sqrt(rnd())*M.r,x=clamp(e.lx+Math.cos(a)*r,.3,N-.3),y=clamp(e.ly+Math.sin(a)*r,.3,N-.3);
        if(solidTile(Math.floor(x),Math.floor(y)))continue;fires.push({x,y,t:M.life,max:M.life,tick:1e9,r:.45,nap:3,arm:M.arm});break}
      sfx('lob',e.x,e.y);end(1.6)}break;
    case 46:{const f=e.foe&&e.foe.alive?e.foe:nearestAlly(e);if(f){const dx=f.x-e.lx,dy=f.y-e.ly,l=Math.hypot(dx,dy),s=Math.min(l,DEST.orb.speed*dt);if(l>.01){e.lx+=dx/l*s;e.ly+=dy/l*s}}
      if(done){e.st=47;e.stT=e.stM=DEST.orb.lock;sfx('charge',e.lx,e.ly)}break}
    case 47:if(done){const M=DEST.orb;
        for(const a of allies())if(a.alive&&Math.hypot(a.x-e.lx,a.y-e.ly)<M.r)hurtAlly(a,M.dmg*Df.dmg);
        for(let i=Math.floor(e.lx-M.r);i<=e.lx+M.r;i++)for(let j=Math.floor(e.ly-M.r);j<=e.ly+M.r;j++){if(!inb(i,j)||Math.hypot(i+.5-e.lx,j+.5-e.ly)>M.r)continue;const k=idx(i,j);
          if(walls[k])damageWall(k,M.wall);else if(coreKs.has(k))hurtStake(stakeAt(k),60*Df.dmg)}
        ringFx(e.lx,e.ly,.2,M.r*1.3,.6,'#ffffff','#ff6a2a',4);addFlash({x:e.lx,y:e.ly,life:.35,max:.35,r:3});addShake(e.lx,e.ly,14);sfx('bigboom',e.lx,e.ly);
        for(let n=0;n<24;n++)emit(e.lx+(rnd()-.5)*2,e.ly+(rnd()-.5)*2,WH*.8,n%2?'fire':'spark');end(1.4)}break;
  }
  return{eng:true,mv:null};
}
// gas clouds hurt whoever stands in them (host, on the fires tick)
function gasTick(f){for(const a of allies())if(a.alive&&Math.hypot(a.x-f.x,a.y-f.y)<f.r)hurtAlly(a,DEST.gas.dmg*game.Df.dmg)}
// mines: arm, then blow when someone steps close; a bullet or a grenade sets one off safely (host, every frame)
function minesTick(dt){
  for(const f of fires){if(f.nap!==3||f.t<=0)continue;f.arm=Math.max(0,(f.arm||0)-dt);
    if(!f.blow)for(const b of bullets)if(b.team===0&&!b.dead&&Math.hypot(b.x-f.x,b.y-f.y)<.4){b.dead=true;f.blow=1;break}
    if(f.blow){f.t=0;explode(f.x,f.y,.9,.6,null,false);continue}
    if(!f.arm)for(const a of allies())if(a.alive&&Math.hypot(a.x-f.x,a.y-f.y)<DEST.mines.trip){f.t=0;explode(f.x,f.y,DEST.mines.R,DEST.mines.pw*game.Df.dmg,null,true);break}}
}
// a friendly blast near a mine sets it off on the next frame
function minesNear(x,y,R){for(const f of fires)if(f.nap===3&&f.t>0&&Math.hypot(f.x-x,f.y-y)<R+.3)f.blow=1}

/* ---------- drawing ---------- */
function drawGas(f,c,t){const a=Math.min(1,f.t)*.32,r=f.r||3;
  for(let n=0;n<5;n++){const ox=Math.sin(t*.7+n*1.7)*TW2*.5,oy=Math.cos(t*.6+n*2.1)*TH2*.5;g.fillStyle=`rgba(120,200,70,${a*(.5+.1*n)})`;g.beginPath();g.ellipse(c[0]+ox,c[1]+oy-n*2*u,TW2*r*(.55+.1*n),TH2*r*(.55+.1*n),0,0,Math.PI*2);g.fill()}
  g.strokeStyle=`rgba(160,240,90,${a*1.6})`;g.lineWidth=1.4*u;g.beginPath();g.ellipse(c[0],c[1],TW2*r,TH2*r,0,0,Math.PI*2);g.stroke()}
function drawMine(f,c,t){const armed=NET.mode==='guest'?f.t<DEST.mines.life-DEST.mines.arm:!(f.arm>0),blink=Math.sin(t*(armed?14:5)+f.x*7)>0;
  oval(c[0],c[1],5*u,2.6*u,'#1a1b1c');oval(c[0],c[1]-1.5*u,4*u,2*u,'#3a3c3e');oval(c[0],c[1]-2.4*u,1.6*u,1*u,blink?(armed?'#ff3a2a':'#ffb03a'):'#5a2a1a')}
function drawDestroyerFx(e,f,pulse,ch){
  if(e.boss!=='destroyer'||!(e.st>=40&&e.st<=47))return false;
  const ring=(x,y,r,col,w=2)=>{const q=iso(x,y);g.strokeStyle=col;g.lineWidth=w*u;g.beginPath();g.ellipse(q[0],q[1],TW2*r,TH2*r,0,0,Math.PI*2);g.stroke()};
  const disc=(x,y,r,col)=>{const q=iso(x,y);g.fillStyle=col;g.beginPath();g.ellipse(q[0],q[1],TW2*r,TH2*r,0,0,Math.PI*2);g.fill()};
  const lane=(x0,y0,x1,y1,w,fill,line)=>{const dx=x1-x0,dy=y1-y0,l=Math.hypot(dx,dy)||1,nx=-dy/l*w,ny=dx/l*w,P=[[x0+nx,y0+ny],[x1+nx,y1+ny],[x1-nx,y1-ny],[x0-nx,y0-ny]].map(q=>iso(q[0],q[1]));
    g.fillStyle=fill;g.strokeStyle=line;g.lineWidth=1.6*u;g.beginPath();P.forEach((q,i)=>i?g.lineTo(q[0],q[1]):g.moveTo(q[0],q[1]));g.closePath();g.fill();g.stroke()};
  switch(e.st){
    case 40:for(const[x,y]of rocketPts(e.x,e.y,e.lx,e.ly)){disc(x,y,DEST.rockets.R*.8,`rgba(255,60,40,${.1+.15*pulse})`);ring(x,y,DEST.rockets.R*(1.2-.2*(1-f)),`rgba(255,70,50,${.6+.35*pulse})`,2)}break;
    case 41:{const[x1,y1]=fireEnd(e);lane(e.x,e.y,x1,y1,DEST.fire.w,`rgba(255,120,40,${.14+.2*pulse})`,`rgba(255,150,60,${.6+.3*pulse})`);break}
    case 42:{const[x1,y1]=fireEnd(e);lane(e.x,e.y,x1,y1,DEST.fire.w*(.85+.15*Math.sin(game.time*30)),`rgba(255,${130+50*pulse|0},40,.45)`,'rgba(255,200,90,.7)');break}
    case 43:{g.setLineDash([6*u,4*u]);g.lineWidth=2.4*u;g.strokeStyle=`rgba(127,224,255,${.55+.4*pulse})`;bossLine(e.x,e.y,e.lx,e.ly,ch*1.3);g.setLineDash([]);ring(e.lx,e.ly,.7,`rgba(200,245,255,${.6+.35*pulse})`);break}
    case 44:disc(e.lx,e.ly,DEST.gas.r*(1-f),`rgba(120,200,70,${.16+.12*pulse})`);ring(e.lx,e.ly,DEST.gas.r,`rgba(160,240,90,${.55+.4*pulse})`,2.4);break;
    case 45:disc(e.lx,e.ly,DEST.mines.r,`rgba(255,176,58,${.08+.12*pulse})`);ring(e.lx,e.ly,DEST.mines.r,`rgba(255,176,58,${.55+.4*pulse})`,2);break;
    case 46:case 47:{const lock=e.st===47,r=DEST.orb.r*(lock?1:1.15+.1*Math.sin(game.time*6)),q=iso(e.lx,e.ly),col=lock?`rgba(255,70,40,${.7+.3*pulse})`:`rgba(255,140,60,${.55+.35*pulse})`;
      disc(e.lx,e.ly,r,lock?`rgba(255,60,30,${.18+.2*pulse})`:'rgba(255,120,50,.1)');ring(e.lx,e.ly,r,col,2.6);ring(e.lx,e.ly,r*.45,col,1.6);
      g.strokeStyle=col;g.lineWidth=1.6*u;g.beginPath();g.moveTo(q[0]-TW2*r*1.2,q[1]);g.lineTo(q[0]+TW2*r*1.2,q[1]);g.moveTo(q[0],q[1]-TH2*r*1.2);g.lineTo(q[0],q[1]+TH2*r*1.2);g.stroke();
      if(lock){g.fillStyle=`rgba(255,200,160,${.12+.18*(1-f)})`;g.fillRect(q[0]-TW2*.35,0,TW2*.7,q[1])}break}
  }
  return true;
}
// his kit over the figure: the back rocket pod (open while it fires) and the red-orange core glow
function drawDestroyerKit(e){const c=iso(e.x,e.y),B=DEST.big,s=u*FIG*B,open=e.st===40,t=game.time;
  const px=c[0]-6*s,py=c[1]-30*s;g.fillStyle='#24262a';g.fillRect(px,py,12*s,7*s);g.fillStyle='#3a3d42';g.fillRect(px,py-(open?3*s:1.2*s),12*s,1.4*s);
  for(let n=0;n<3;n++){g.fillStyle=open?'#ff5a2a':'#4a2a20';g.beginPath();g.arc(px+2.5*s+n*3.5*s,py+3.5*s,1.1*s,0,Math.PI*2);g.fill()}
  g.globalAlpha=.55+.25*Math.sin(t*5);oval(c[0],c[1]-17*s,3.2*s,3.2*s,'#ff6a2a');g.globalAlpha=1;oval(c[0],c[1]-17*s,1.4*s,1.4*s,'#ffd0a0')}
