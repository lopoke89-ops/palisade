/* ================= THE UNDERSTRIP: regions 2 and 3 (Shelter 7 and Area 67; work order 4.2) ================= */
// What each region looks, sounds and hurts like. Region 1 floods (10h). Shelter 7 has gas vents that leak on a timer,
// radiation pockets, and the Custodian's blast doors; Area 67 has acid, low-gravity floors (shots and grenades slow over
// them), specimen tanks, containment alarms that call a drone pack, and the drones themselves (small, fast, weak to light).
// The host runs the hazards; guests build the same tiles from the seed and read the vents and doors from the snapshot.
const US_REG={
  1:{name:'THE FLOOD TUNNELS',short:'TUNNELS',col:'#7cff6b',dark:{r:3,g:5,b:7},music:{lp:US_MUFFLE,wet:0},
    wall:['#5f6258','#35372f','#2a2c26','#6a6d63'],floor:['#30322d','#2c2e29','#292b26']},
  2:{name:'SHELTER 7',short:'SHELTER 7',col:'#c8a03a',dark:{r:6,g:6,b:2},music:{lp:420,wet:.55},   // more muffled, with a reverb tail
    wall:['#5d604a','#34372a','#292b20','#6a6c55'],floor:['#30312a','#2d2e27','#2a2b24']},
  3:{name:'AREA 67',short:'AREA 67',col:'#9ad8ff',dark:{r:2,g:6,b:10},music:null,   // the music cuts out: only the hum until the bosses
    wall:['#a9b0b6','#6c747b','#555c62','#bfc6cc'],floor:['#363b40','#33383d','#30353a']}};
const usRegion=()=>game&&game.us?US_PLAN[game.us.level][0]:1;
const usReg=()=>US_REG[usRegion()];
// Shelter 7's raiders wear the Desert Civil Defence Authority's olive and orange; Area 67's are its lab security, in white
const US_DRESS={2:{body:'#5d6236',vest:'#2e3020',pants:'#3a3a2a',helmet:'#4a4e2c',bandana:'#d0782a'},3:{body:'#c9ced2',vest:'#4a5258',pants:'#5a6066',helmet:'#e4e8ea',bandana:'#3aa0d0'}};
function usLook(type,base){const D=US_DRESS[usRegion()];if(!D)return base;const o=Object.assign({},base);
  if(type!=='medic'){o.body=D.body;o.vest=D.vest}o.pants=D.pants;if(o.helmet&&type!=='medic')o.helmet=D.helmet;if(o.bandana)o.bandana=D.bandana;return o}

// ---------- the hazard tiles ----------
const HZ_RAD=1,HZ_ACID=2,HZ_GRAV=3,HZ_GAS=4,HZ_BLAST=5;
const US_HZ={rad:3,acid:6,gas:10,lung:.5,vent:{every:[13,21],warn:2,on:6},blast:{every:8,warn:1,shut:3,dmg:40},tick:.25,grav:.6};
let US_HAZ=new Uint8Array(0);
// joined runs of one marker (4-neighbour), each one vent or one door
function usGroups(L,ch){const T=L.T,seen=new Uint8Array(T*T),out=[];
  for(let y=0;y<T;y++)for(let x=0;x<T;x++){if(L.tiles[y][x]!==ch||seen[y*T+x])continue;const q=[[x,y]];seen[y*T+x]=1;
    for(let h=0;h<q.length;h++){const[a,b]=q[h];for(const[dx,dy]of[[1,0],[-1,0],[0,1],[0,-1]]){const X=a+dx,Y=b+dy;if(X<0||Y<0||X>=T||Y>=T||seen[Y*T+X]||L.tiles[Y][X]!==ch)continue;seen[Y*T+X]=1;q.push([X,Y])}}
    out.push({tiles:q,cx:q.reduce((s,t)=>s+t[0]+.5,0)/q.length,cy:q.reduce((s,t)=>s+t[1]+.5,0)/q.length})}
  return out}
// usLay: the hazard map, the vents and the blast doors of this level
function usHazLay(L,lay){const T=L.T;US_HAZ=new Uint8Array(T*T);
  for(let y=0;y<T;y++)for(let x=0;x<T;x++){const c=L.tiles[y][x];US_HAZ[y*T+x]=c==='z'?HZ_RAD:c==='a'?HZ_ACID:c==='v'?HZ_GRAV:c==='g'?HZ_GAS:c==='b'?HZ_BLAST:0}
  const r=usRng(usHash(L.seed,4242));
  lay.vents=usGroups(L,'g').map(v=>({...v,every:US_HZ.vent.every[0]+r()*(US_HZ.vent.every[1]-US_HZ.vent.every[0]),first:3+r()*10}));
  lay.blast=usGroups(L,'b').map((d,n)=>({...d,off:n*2}));
  lay.tanks=[];for(let y=0;y<T;y++)for(let x=0;x<T;x++)if(L.tiles[y][x]==='t')lay.tanks.push([x+.5,y+.5]);
  // the cloud a vent breathes out: its tiles and the ring round them
  for(const v of lay.vents){const s=new Set();for(const[x,y]of v.tiles)for(let b=-1;b<=1;b++)for(let a=-1;a<=1;a++){const X=x+a,Y=y+b;if(X>=0&&Y>=0&&X<T&&Y<T&&US_WALKABLE(L.tiles[Y][X]))s.add(Y*T+X)}v.cloud=s}
  // lamps: Shelter 7's fluorescents run on timers; Area 67's fail more the deeper you are
  lay.lampT=(lay.lamps||[]).map(()=>({on:4+r()*6,off:.6+r()*1.4,ph:r()*10}))}
const usHazAt=(x,y)=>{const k=idx(x|0,y|0);return k>=0&&k<US_HAZ.length?US_HAZ[k]:0};
const usGravAt=(x,y)=>usHazAt(x,y)===HZ_GRAV?US_HZ.grav:1;
// the vents' and doors' state (0 quiet, 1 warning, 2 on / shut): the host keeps the clocks, guests read the snapshot
function usHazStart(U){const L=game.lay;U.vents=(L.vents||[]).map(v=>({s:0,t:v.first}));U.blast=(L.blast||[]).map(()=>0);U.blastT=0;U.alarms=[];U.alarmed=[]}
function usHazTick(dt){const U=game.us,L=game.lay;if(!U.vents)usHazStart(U);
  // gas vents: quiet, a hiss and a growing tint for 2 s, then the cloud for 6 s
  L.vents.forEach((v,n)=>{const S=U.vents[n];S.t-=dt;if(S.t>0)return;
    if(S.s===0){S.s=1;S.t=US_HZ.vent.warn;sfx('flood',v.cx,v.cy)}else if(S.s===1){S.s=2;S.t=US_HZ.vent.on}else{S.s=0;S.t=v.every}});
  // the Custodian's doors keep their rhythm only while he's fought (10i's usBlastTick drives them)
  // the floor: radiation, acid and the clouds
  for(const p of players.values()){if(!p.alive)continue;const k=idx(p.x|0,p.y|0),h=US_HAZ[k];let dps=0;
    const lung=usHas(p,'p_lung')?US_HZ.lung:1;
    if(h===HZ_RAD)dps+=US_HZ.rad*lung;else if(h===HZ_ACID)dps+=US_HZ.acid;
    L.vents.forEach((v,n)=>{if(U.vents[n].s===2&&v.cloud.has(k))dps+=US_HZ.gas*lung});
    if(!dps){p.hzAcc=0;continue}
    p.hzAcc=(p.hzAcc||0)+dps*dt;if(p.hzAcc>=dps*US_HZ.tick){hurtPlayer(p,p.hzAcc);p.hzAcc=0;if(p.id===myId&&!p.hzSaid){p.hzSaid=1;toastTo(p,h===HZ_ACID?'ACID':h===HZ_RAD?'RADIATION':'GAS','Get off it: it hurts while you stand there.')}}}
  usAlarmTick(dt)}
// the Custodian's blast doors (and his crush lanes): shut ones are wall; anyone under one is pushed out and hurt
function usBlastSet(n,s){const U=game.us,D=game.lay.blast[n];if(!D)return;const was=U.blast[n];U.blast[n]=s;if((was===2)===(s===2))return;
  for(const[x,y]of D.tiles)terr[idx(x,y)]=s===2?T_SHUT:T_GROUND;markFlow();
  if(s===2&&NET.mode!=='guest'){for(const a of allies())if(a.alive&&D.tiles.some(([x,y])=>(a.x|0)===x&&(a.y|0)===y)){hurtAlly(a,US_HZ.blast.dmg*game.Df.dmg);usShove(a,D)}
    for(const e of enemies)if(!e.dead&&D.tiles.some(([x,y])=>(e.x|0)===x&&(e.y|0)===y))usShove(e,D);sfx('collapse',D.cx,D.cy);addShake(D.cx,D.cy,4)}}
// out from under a door, to the nearer side of it
function usShove(a,D){const xs=D.tiles.map(t=>t[0]),ys=D.tiles.map(t=>t[1]),horiz=Math.max(...xs)-Math.min(...xs)>=Math.max(...ys)-Math.min(...ys);
  if(horiz){const y=D.tiles[0][1];a.y=a.y<y+.5?y-.45:y+1.45}else{const x=D.tiles[0][0];a.x=a.x<x+.5?x-.45:x+1.45}if(a.tp!==undefined)a.tp++}
function usBlastOpenAll(){const U=game.us;if(!U||!U.blast)return;U.blast.forEach((s,n)=>{if(s)usBlastSet(n,0)})}

// ---------- Area 67: containment alarms and the drones ----------
ETYPES.drone={hp:10,speed:2.6};ECODE.push('drone');BOUNTY.drone=2;   // network codes only grow at the end
const US_DRONE={touch:4,cd:.6,r:.55,light:2,litSpeed:.5,pack:[4,6],alive:12,alarm:3};   // tables/enemies.csv
const usRoomAt=(x,y)=>{const R=game.lay.us.rooms;for(let n=0;n<R.length;n++){const q=R[n];if(x>=q.x&&x<q.x+q.w&&y>=q.y&&y<q.y+q.h)return n}return -1};
// usAlert: the first raider to start hunting in a room of region 3 trips its alarm (once a room until the next rest)
function usAlarm(e){if(usRegion()!==3||NET.mode==='guest'||!e.us||e.type==='drone')return;const U=game.us;if(!U.alarms)usHazStart(U);const n=usRoomAt(e.us.home[0],e.us.home[1]);
  if(n<0||U.alarmed.includes(n))return;const q=game.lay.us.rooms[n];if(!['room','junction','corridor','cache'].includes(q.role))return;U.alarmed.push(n);
  U.alarms.push({n,t:US_DRONE.alarm});toastAll('CONTAINMENT ALARM','A drone pack is coming. Drones die fast in your light.');sfx('siren',q.x+q.w/2,q.y+q.h/2)}
function usAlarmTick(dt){const U=game.us;if(!U.alarms)return;for(const A of U.alarms){A.t-=dt;if(A.t>0)continue;A.done=true;const q=game.lay.us.rooms[A.n];
  const n=Math.min(US_DRONE.pack[1],US_DRONE.pack[0]+players.size-1);usDronePack(q.x+q.w/2,q.y+q.h/2,n)}U.alarms=U.alarms.filter(A=>!A.done)}
function usDronePack(x,y,n){let alive=enemies.filter(e=>e.type==='drone'&&!e.dead).length;
  for(let k=0;k<n&&alive<US_DRONE.alive;k++){const a=k/n*6.283,px=x+Math.cos(a)*.8,py=y+Math.sin(a)*.8;if(solidTile(px|0,py|0))continue;const e=spawnEnemyAt('drone',px,py);if(e){e.us={home:[px,py],st:'hunt',sid:-1,t:0,look:0,drone:1};alive++}}}
// updateEnemies hands drones to this: straight at the nearest of you, down your flow field round corners, a sting on touch
function usDroneTick(e,dt){e.cd=Math.max(-1,e.cd-dt);e.flash=Math.max(0,e.flash-dt);e.walk+=dt*12;
  let f=null,bd=1e9;for(const a of allies())if(a.alive){const d=Math.hypot(a.x-e.x,a.y-e.y);if(d<bd){bd=d;f=a}}if(!f)return;
  let tx=f.x,ty=f.y;if(bd>1.2&&!losClear(e.x,e.y,f.x,f.y)){const F=US_FLOW.get(f.id);if(F&&F.k>=0){const i=e.x|0,j=e.y|0;let b=F.f[idx(i,j)],bi=i,bj=j;
    for(const[a,c]of[[1,0],[-1,0],[0,1],[0,-1],[1,1],[1,-1],[-1,1],[-1,-1]]){const I=i+a,J=j+c;if(!inb(I,J)||solidTile(I,J))continue;const v=F.f[idx(I,J)];if(v<b){b=v;bi=I;bj=J}}tx=bi+.5;ty=bj+.5}}
  e.litT=(e.litT||0)-dt;if(e.litT<=0){e.litT=.2;e.lit=usLitAt(e.x,e.y)}   // in your light: half speed (checked five times a second)
  const dx=tx-e.x,dy=ty-e.y,l=Math.hypot(dx,dy)||1,s=Math.min(l,e.speed*dt*((game.Df&&game.Df.speed)||1)*(e.lit?US_DRONE.litSpeed:1));e.aim={x:dx/l,y:dy/l};moveEnt(e,dx/l*s,dy/l*s,false);
  if(bd<US_DRONE.r+.2&&e.cd<=0){e.cd=US_DRONE.cd;hurtAlly(f,US_DRONE.touch*game.Df.dmg);sfx('hit2',e.x,e.y)}}
// is this spot in someone's light (a cone, a flare, a lamp)? Drones there take double damage
function usLitAt(x,y){const L=game.lay,U=game.us;
  for(const p of players.values()){if(!p.alive)continue;const dx=x-p.x,dy=y-p.y,d=Math.hypot(dx,dy);if(d<1.4)return true;const k=usConeMul(p),a=p.aim||{x:1,y:0};
    if(d<5.6*k&&(dx*a.x+dy*a.y)/(d||1)>.86)return true}
  for(const f of U.flares)if(Math.hypot(x-f.x,y-f.y)<(f.r||4))return true;
  for(const p of L.lamps)if(Math.hypot(x-p[0],y-p[1])<2.6)return true;return false}
const usDroneMul=e=>usLitAt(e.x,e.y)?US_DRONE.light:1;
// a drone: a dark lens with a green ring, hovering over its own shadow
function usDrawDrone(e){const c=iso(e.x,e.y),h=WH*(.55+.08*Math.sin(e.walk)),lit=usLitAt(e.x,e.y);
  g.fillStyle='rgba(0,0,0,.35)';g.beginPath();g.ellipse(c[0],c[1],6*u,2.6*u,0,0,Math.PI*2);g.fill();
  g.fillStyle=e.flash>0?'#e8ffe0':'#1c2620';g.beginPath();g.ellipse(c[0],c[1]-h,5.5*u,4*u,0,0,Math.PI*2);g.fill();
  g.strokeStyle=lit?'#d8ff9a':'#7cff6b';g.lineWidth=1.6*u;g.beginPath();g.ellipse(c[0],c[1]-h,7*u,2.6*u,0,0,Math.PI*2);g.stroke();
  g.fillStyle='#b8ff7a';g.beginPath();g.arc(c[0]+e.aim.x*2.4*u,c[1]-h+e.aim.y*1.2*u,1.6*u,0,Math.PI*2);g.fill()}

// ---------- how a region's tunnels look (15b asks these) ----------
function usRegGround(i,j,h){const R=usReg(),t=terr[idx(i,j)],z=US_HAZ[idx(i,j)];
  if(z===HZ_ACID)return h<.5?'#2f5a1e':'#2a5219';
  if(z===HZ_RAD)return h<.5?'#3a3a1e':'#36361c';
  if(z===HZ_GRAV)return h<.5?'#2a3448':'#283244';
  if(z===HZ_GAS)return'#26281f';
  if(z===HZ_BLAST&&t!==T_SHUT)return((i+j)&1)?'#3a2a14':'#1e1a14';   // the door's track: hazard stripes
  if(t===T_TANK)return'#0b0c0d';
  return R.floor[h<.2?0:h<.75?1:2]}
function usRegDetail(i,j,h){const reg=usRegion(),z=US_HAZ[idx(i,j)],c=iso(i+.5,j+.5);
  if(z===HZ_RAD&&h>.82){g.fillStyle='rgba(226,214,60,.35)';for(let k=0;k<3;k++){const a=k*2.094+.5;g.beginPath();g.moveTo(c[0],c[1]);g.arc(c[0],c[1],5*u,a,a+.9);g.closePath();g.fill()}return true}
  if(z===HZ_GAS){g.strokeStyle='rgba(20,22,18,.8)';g.lineWidth=u;for(let k=-2;k<=2;k++){g.beginPath();g.moveTo(c[0]-6*u,c[1]+k*1.6*u);g.lineTo(c[0]+6*u,c[1]+k*1.6*u);g.stroke()}return true}   // a grate
  if(z===HZ_GRAV&&h>.7){g.strokeStyle='rgba(120,170,255,.25)';g.lineWidth=u;g.beginPath();g.ellipse(c[0],c[1],TW2*.4,TH2*.4,0,0,Math.PI*2);g.stroke();return true}
  if(reg===3&&h>.93){oval(c[0]+3*u,c[1],7*u,3*u,'rgba(140,60,170,.3)');oval(c[0]-2*u,c[1]+u,4*u,2*u,'rgba(124,255,107,.22)');return true}   // alien growth through the floor
  if(reg===3&&h<.5&&(i+j)%4===0){g.strokeStyle='rgba(200,215,225,.08)';g.lineWidth=u;const a=iso(i,j+1),b=iso(i+1,j+1);g.beginPath();g.moveTo(a[0],a[1]);g.lineTo(b[0],b[1]);g.stroke();return true}   // lab floor tiles
  if(reg===2&&h>.9){g.fillStyle='rgba(208,120,42,.22)';g.fillRect(c[0]-5*u,c[1]-u,10*u,2*u);return true}   // a painted line
  return false}
// the vents' clouds, the doors' warning lights, the acid's bubbles (drawn as items)
function usHazItems(){const L=game.lay,U=game.us;if(!L.vents)return;
  L.vents.forEach((v,n)=>{const s=U.vents&&U.vents[n]?U.vents[n].s:0;if(s)ritem(v.cx+v.cy+.2,usDrawCloud,v,s)});
  (L.blast||[]).forEach((d,n)=>{const s=U.blast?U.blast[n]|0:0;if(s===1)ritem(d.cx+d.cy+.3,usDrawBlastWarn,d)})}
function usDrawCloud(v,s){const t=game.time;for(const k of v.cloud){if((k*7)%3)continue;const x=k%N+.5,y=((k/N)|0)+.5,c=iso(x,y),a=s===2?.34:.12+.1*Math.sin(t*8);
  g.fillStyle=`rgba(150,210,70,${a})`;g.beginPath();g.ellipse(c[0]+Math.sin(t+k)*3*u,c[1]-WH*.4,TW2*.9,TH2*1.2+WH*.2,0,0,Math.PI*2);g.fill()}
  if(s===1){const c=iso(v.cx,v.cy);label('GAS',c[0],c[1]-WH*1.4,'#b8e06a',10)}}
function usDrawBlastWarn(d){for(const[x,y]of d.tiles){const c=iso(x+.5,y+.5);g.fillStyle=`rgba(255,170,40,${.25+.25*Math.sin(game.time*14)})`;g.beginPath();g.ellipse(c[0],c[1],TW2*.45,TH2*.45,0,0,Math.PI*2);g.fill()}
  const c=iso(d.cx,d.cy);label('DOOR',c[0],c[1]-WH*1.6,'#ffb02a',10)}
// lamps by region: Shelter 7's tubes flicker on timers; Area 67's lab lights fail more on its second level
function usLampOn(n){const R=usRegion(),T=game.lay.lampT&&game.lay.lampT[n];if(R===1||!T)return 1;if(reduceMotion())return R===3&&game.us.level-US_PLAN.findIndex(q=>q[0]===3)>=1?.7:1;const t=(game.time+T.ph)%(T.on+T.off);   // Reduce Motion: steady light
  if(R===2)return t<T.on?1:t<T.on+.12?.3:0;const lvl=game.us.level-US_PLAN.findIndex(q=>q[0]===3);return lvl>=1&&t>T.on*.6?(Math.sin(t*37)>0?.5:0):1}
// the darkness's tint: Shelter 7 olive (red when the Custodian cracks), Area 67 cold blue (black when the Visitor's field fails)
function usDarkTint(){const R=usReg(),U=game.us,b=usBossNow();let d=R.dark;
  if(b==='custodian'&&U.bossStage>0&&!U.bossDown)d={r:40,g:2,b:2};
  return{L:usDarkL()+(b==='visitor'&&U.bossStage>0&&!U.bossDown?.04:0),r:d.r,g:d.g,b:d.b,warm:0}}
// ---------- Area 67's hum (work order 4.3: the music cuts out, only ambience plays) ----------
// Two low sines a fifth apart, the upper one drifting, on the music volume; it fades with the boss tracks and off the mode.
let US_AMB=null;
function usAmbience(){if(!AC)return;const now=AC.currentTime,on=understrip()&&!document.hidden&&cfg.music>0&&usRegion()===3&&!usMusicRoute()&&game.phase!=='over',want=on?.05*cfg.music:0;
  if(!US_AMB){if(!on)return;const g=AC.createGain();g.gain.value=0;g.connect(master);const lp=AC.createBiquadFilter();lp.type='lowpass';lp.frequency.value=320;lp.connect(g);
    const a=AC.createOscillator(),b=AC.createOscillator(),l=AC.createOscillator(),lg=AC.createGain();a.frequency.value=55;b.frequency.value=82.6;b.type='triangle';l.frequency.value=.13;lg.gain.value=1.6;
    l.connect(lg);lg.connect(b.frequency);a.connect(lp);b.connect(lp);a.start();b.start();l.start();US_AMB={g,want:-1}}
  if(Math.abs(US_AMB.want-want)>.001){US_AMB.want=want;US_AMB.g.gain.setTargetAtTime(want,now,want?1.2:.4)}}
