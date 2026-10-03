/* ================= v0.9.4.0: Blitzkrieg Rush ================= */
// 15 hard raids (Blitzkrieg bosses on 5 and 10), then raid 15 is the Final Blitz: a 5-minute clock with a new
// Blitzkrieg boss every 30 s (at most 4 alive; the rest wait their turn). The last minute is the evacuation: an evac
// site opens away from the core and each soldier has to stand in it for 3 s, on their feet, to get out. Whoever is
// still on the field at 0:00 is left behind: they lose, and their cases and shards are halved (odd counts round up
// first). Their squadmates who made it still win. Host (or solo) runs all of it; guests see the result in snapshots.
const BLITZ={waves:15,fb:300,evac:60,evacHot:45,every:30,everyDT:20,max:10,maxDT:15,cap:4,ring:1.5,ringHot:1,hold:3,fbHp:.85,
  order:['bluebutcher','arsonist','tempest','harbinger','bulldozer'],
  of:{butcher:'bluebutcher',demolisher:'arsonist',storm:'tempest',ferryman:'harbinger',foreman:'bulldozer'}};
const blitz=()=>!!game&&['blitz','campaign'].includes(game.mode)&&!game.pvp;
const bossBase=k=>(BOSSES[k]&&BOSSES[k].base)||k;
const blitzBoss=k=>BLITZ.of[k]||k;
const evacR=()=>hasMod('hotlz')?BLITZ.ringHot:BLITZ.ring;
// the five Blitzkrieg variants: the same rig as the boss they come from, their own name, colours and attacks.
// box/cases: what each player gets when one goes down (two Blitzkrieg Cases).
Object.assign(BOSSES,{
  harbinger:{base:'ferryman',name:'THE HARBINGER',hp:720,speed:1.45,scan:12,bounty:50,col:'#ff7a3a',think:thinkHarbinger,raft:true,box:'blitz',cases:2,
    look:{body:'#3a2e2a',vest:'#1c1512',pants:'#2a221e',head:'#a58566',boonie:'#231a16',bandana:'#ff6a2a',pack:'#4a3a2a',gl:20,weapon:'rpg'},
    intro:'He fires missiles from his boat in a high arc. Each one shows a red ring where it lands: keep moving and it misses.'},
  bluebutcher:{base:'butcher',name:'THE BLUE BUTCHER',hp:780,speed:2.05,scan:10,bounty:50,col:'#3ae0e0',think:thinkBlueButcher,box:'blitz',cases:2,
    look:{body:'#16465a',vest:'#0a2230',pants:'#10212a',head:'#9c7456',helmet:'#0c3440',bandana:'#3ae0e0',gl:14,weapon:'swordb'},
    intro:'His sword throws a glowing blue arc that goes straight through brick walls and breaks them. A teal lane shows where it goes: get out of it.'},
  arsonist:{base:'demolisher',name:'THE ARSONIST',hp:640,speed:1.05,scan:10,bounty:50,col:'#ff5a1a',think:thinkArsonist,box:'blitz',cases:2,
    look:{body:'#3a2a20',vest:'#16100c',pants:'#22180f',head:'#a98262',helmet:'#15110d',pack:'#6a2a12',bandana:'#ff6a1a',gl:20,weapon:'rpg'},
    intro:'He aims, then lobs a chain of napalm down the line. It burns for 10 seconds and eats through metal faster than normal fire.'},
  tempest:{base:'storm',name:'THE TEMPEST',hp:560,speed:1.2,scan:12.5,bounty:50,col:'#bff4ff',think:thinkTempest,box:'blitz',cases:2,
    look:{body:'#16222e',vest:'#080e16',pants:'#101820',head:'#b0896a',boonie:'#0c1620',glow:'#dff8ff',gl:20,weapon:'zap'},
    intro:'Two lightning shots at once, side by side. Two blue lines show them coming. Get caught by both and it hurts twice as much.'},
  bulldozer:{base:'foreman',name:'THE BULLDOZER',hp:800,speed:1.35,scan:9,bounty:50,col:'#ffd23a',think:thinkBulldozer,box:'blitz',cases:2,
    look:{body:'#4a3a22',vest:'#f0c020',pants:'#2a2620',head:'#a98262',helmet:'#f0d030',pack:'#2a2a2a',gl:14,weapon:'drill'},
    intro:'No more digging. He charges at you fast down a marked lane. When he hits a wall he breaks it, and he\'s dazed for a few seconds.'}});
ECODE.push('boss:harbinger','boss:bluebutcher','boss:arsonist','boss:tempest','boss:bulldozer');   // append only

/* ---------- the Final Blitz ---------- */
function startFinalBlitz(){
  const dt=hasMod('blitzclock');
  game.fb={t:BLITZ.fb,n:0,max:dt?BLITZ.maxDT:BLITZ.max,every:dt?BLITZ.everyDT:BLITZ.every,evac:null,shellT:1,trickT:0,done:false};
  game.queue=[];game.spawnT=1.2;game.spawnGap=1.3;
  toastAll(campaign()?'WHITEOUT · FINAL EVAC':'THE FINAL BLITZ',`Five minutes. ${campaign()?'A summit assault':'A Blitzkrieg boss'} every ${game.fb.every} seconds. With ${hasMod('hotlz')?'45 seconds':'a minute'} left an evac site opens: every soldier has to get there on their own.`);
}
const liveBosses=()=>{let n=0;for(const e of enemies)if(!e.dead&&e.type==='boss')n++;return n};
function fbTick(dt){
  const F=game.fb;if(!F||F.done||game.phase!=='raid')return;
  F.t=Math.max(0,F.t-dt);const el=BLITZ.fb-F.t;
  const order=campaign()?['whitebutcher','whiteforeman','rime','tempest','bulldozer']:MAP===MAPS.frost?['bluebutcher','arsonist','tempest','rime','bulldozer']:BLITZ.order;
  while(F.n<F.max&&el>=F.n*F.every&&liveBosses()<BLITZ.cap){spawnBoss(order[F.n%order.length],false,false,true);F.n++}
  // raiders keep coming alongside: small groups whenever the field thins out
  F.trickT-=dt;const P=Math.max(1,players.size);
  if(F.mapEvac){if(F.trickT<=0&&!game.queue.length&&enemies.length<4+2*P){F.trickT=2.5;game.queue.push('shield','gren');if(P>=3)game.queue.push('shield')}}   // v0.9.6.4 map evac: shieldbearers and grenadiers only
  else if(F.trickT<=0&&!game.queue.length&&enemies.length-liveBosses()<5+2*P){F.trickT=2.5;const sp=['gren','breach','shield','fire','medic','spotter'];
    game.queue.push('rifle','rifle',sp[Math.floor(rnd()*sp.length)]);if(P>=3)game.queue.push('rifle')}
  if(!F.evac&&F.t<=(hasMod('hotlz')?BLITZ.evacHot:BLITZ.evac))openEvac();
  if(F.evac)evacTick(dt);
  if(F.t<=0)finishBlitz();
}
// the evac site: a clear 3x3 patch a good run from the core, on foot, away from where raiders come in
function evacSpot(){
  const L=game.lay||{},c=L.core||[core.i,core.j],want=game.fb&&game.fb.mapEvac?(N>16?MAP_EVAC.wantXL:MAP_EVAC.want):N>16?11:8,dist=new Int16Array(N*N).fill(-1),q=[idx(c[0],c[1])];dist[q[0]]=0;
  const pass=k=>{const t=terr[k];return!terrSolid(t)&&!(nodeAt(k%N,(k/N)|0)||{}).solid};
  for(let h=0;h<q.length;h++){const k=q[h],i=k%N,j=(k/N)|0;for(const[a,b]of D4){const ni=i+a,nj=j+b;if(!heightLink(i,j,ni,nj))continue;const nk=idx(ni,nj);if(dist[nk]>=0||!pass(nk))continue;dist[nk]=dist[k]+1;q.push(nk)}}
  const clear=(i,j)=>{for(let a=-1;a<=1;a++)for(let b=-1;b<=1;b++){const ni=i+a,nj=j+b;if(!inb(ni,nj))return false;const k=idx(ni,nj),t=terr[k];
    if(connectors[k]||heights[k]!==heights[idx(i,j)]||terrSolid(t)||t===T_WATER||t===T_BRIDGE||nodeAt(ni,nj)||coreKs.has(k))return false}return true};
  const spawns=[];for(const s of L.spawns||[])for(const t of s.tiles||[])spawns.push(t);
  let best=null,bs=1e9;const seed=String(game.gid||'').length*7+(game.gid||'').charCodeAt(3)|0;
  for(let k=0;k<N*N;k++){const d=dist[k];if(d<4)continue;const i=k%N,j=(k/N)|0;if(!clear(i,j))continue;
    let near=1e9;for(const t of spawns)near=Math.min(near,Math.hypot(t[0]-i,t[1]-j));
    let wl=0;for(let a=-1;a<=1;a++)for(let b=-1;b<=1;b++)if(walls[idx(i+a,j+b)])wl++;
    const s=Math.abs(d-want)*1.4+Math.max(0,5-near)*2+wl*1.5+hash(k,seed)*1.2;if(s<bs){bs=s;best=[i,j]}}
  return best?{x:best[0]+.5,y:best[1]+.5}:{x:c[0]+.5,y:clamp(c[1]+4,1,N-2)+.5};
}
function openEvac(){
  const F=game.fb,s=evacSpot();F.evac={x:s.x,y:s.y,r:evacR()};if(game.lay)game.lay.evacAt=[Math.floor(s.x),Math.floor(s.y)];
  sfx('siren');ringFx(s.x,s.y,.2,F.evac.r+.6,1.2,'#8aff9a','#2e7a48',3);flt(s.x,s.y-.5,'EVAC','#8aff9a');
  if(F.mapEvac)toastAll('EVACUATE',`Get to the green ring. The convoy leaves in ${MAP_EVAC.t} seconds. Stand in it for ${BLITZ.hold} seconds, on your feet. Miss it and you lose half this chapter's cases and shards.`);
  else toastAll('EVACUATE',`The evac site is open. Stand in the green ring for ${BLITZ.hold} seconds, on your feet, to get out. Anyone still here at 0:00 is left behind.`);
  for(const p of players.values()){p.ev=0;if(p.downed)p.rt=Math.max(p.rt,1e6)}
}
function evacTick(dt){
  const F=game.fb,E=F.evac;
  for(const p of players.values()){
    if(p.out)continue;
    if(p.downed){p.rt=Math.max(p.rt,1e6);p.ev=0;continue}   // no respawns in the evacuation: a teammate has to pick you up
    if(!p.alive){p.ev=0;continue}
    if(heightDist(p.x,p.y,E.x,E.y)<=E.r&&heightRayClear(p.x,p.y,E.x,E.y)){p.ev=(p.ev||0)+dt;if(p.ev>=BLITZ.hold)extract(p)}else p.ev=0;
  }
  if(hasMod('barrage')){F.shellT-=dt;if(F.shellT<=0){F.shellT=1.1;const on=[...players.values()].filter(p=>p.alive&&!p.out);
    if(on.length){const p=on[Math.floor(rnd()*on.length)],a=rnd()*6.283,r=.6+rnd()*2.6,tx=clamp(p.x+Math.cos(a)*r,.4,N-.4),ty=clamp(p.y+Math.sin(a)*r,.4,N-.4);
      if(Math.hypot(tx-E.x,ty-E.y)>E.r+.4)lobs.push({x0:tx-2.5,y0:ty-2.5,x1:tx,y1:ty,t:0,T:1.6,R:1.3,power:game.Df.dmg*.9,k:5})}}}
  // everyone is out, or nobody left standing (Delgado included) to pick the downed up: the clock doesn't need to run out
  let up=0,left=0;for(const p of players.values())if(!p.out){left++;if(p.alive)up++}
  if(!left)finishBlitz();else if(!up)checkDeadEnd();
}
function extract(p){
  p.out=true;p.ev=BLITZ.hold;p.alive=false;p.downed=false;p.stun=0;p.tp++;
  sfx('win',p.x,p.y);ringFx(p.x,p.y,.2,1.4,.7,'#8aff9a','#2e7a48',2.4);flt(p.x,p.y-.4,p.id===myId?'YOU MADE IT OUT':`${p.name.toUpperCase()} IS OUT`,'#8aff9a');
  toastTo(p,'EVACUATED','You made it out. Watch your crew: they have to get there on their own.');
  if(players.size>1)feed(`${p.name.toUpperCase()} EVACUATED`,'#8aff9a');
}
function finishBlitz(){
  const F=game.fb;if(F&&F.mapEvac){finishMapEvac();return}
  if(!F||F.done)return;F.done=true;
  for(const e of enemies)if(e.type==='boss'&&!e.dead)flt(e.x,e.y-.4,'RETREATS','#dcd2ba');   // they pull back; they don't count as kills
  enemies=[];game.queue=[];lobs=[];arcs=[];
  for(const p of players.values())p.res=p.out?'evac':'left';
  endGame(!!(player&&player.out));
}
// this soldier's evacuation result once the evac site is open: 'evac' (made it) or 'left' (left behind); '' before that
const blitzResult=p=>!p||!blitz()||game.fb&&game.fb.mapEvac?'':p.out?'evac':game.fb&&game.fb.evac?'left':'';   // a map evac (v0.9.6.4) is not the final one
function fbClock(){const F=game.fb;return F?F.t:0}

/* ---------- Blitzkrieg attacks ---------- */
let arcs=[];   // the Blue Butcher's arcs in flight (host); guests get them in snapshots
const arcHaz=[];   // Scorched Earth: the arc's dust, hot for half a second
// the Blue Butcher: a teal lane for 0.65 s, then a crescent of light down it. It breaks every wood and brick wall in
// its way, stops at metal (after a heavy hit), and hurts everyone it crosses once. The blade and the charge stay, the
// charge less often, so the arc is what he's known for.
function thinkBlueButcher(e,dt,tgt,mv,aimAt,Df){
  e.arcT=(e.arcT===undefined?2.4:e.arcT)-dt;
  if(e.st===5){e.stT-=dt;aimAt(e.lx,e.ly);if(e.stT<=0){e.st=0;launchArc(e,Df);e.arcT=e.rage?3.1:4.3;e.cd=.55}return{eng:true,mv:null}}
  const f=e.foe;
  if(!e.st&&f&&e.arcT<=0){const d=dist2(f,e);if(d>1.6&&d<10.5){const a=aimAt(f.x,f.y);e.st=5;e.stT=e.stM=.65;
    e.lx=clamp(e.x+Math.cos(a)*10,.2,N-.2);e.ly=clamp(e.y+Math.sin(a)*10,.2,N-.2);sfx('charge',e.x,e.y);return{eng:true,mv:null}}}
  if(!e.st)e.ab+=dt*.5;   // his charge comes round at half the Butcher's rate
  return thinkButcher(e,dt,tgt,mv,aimAt,Df);
}
function launchArc(e,Df){
  const a=Math.atan2(e.ly-e.y,e.lx-e.x),c=Math.cos(a),s=Math.sin(a);
  arcs.push({x:e.x+c*.6,y:e.y+s*.6,vx:c*8.5,vy:s*8.5,d:0,max:11,hit:new Set(),wk:new Set(),pw:Df.dmg,dust:0});
  sfx('slash',e.x,e.y);slashFx(e.x,e.y,c,s);addShake(e.x,e.y,4);
}
function updateArcs(dt){
  for(const r of arcs){const sp=Math.hypot(r.vx,r.vy),steps=Math.ceil(sp*dt/.1);
    for(let n=0;n<steps&&!r.dead;n++){const ox=r.x,oy=r.y;r.x+=r.vx*dt/steps;r.y+=r.vy*dt/steps;if(!heightTravelClear(ox,oy,r.x,r.y)){r.dead=true;break}r.d+=sp*dt/steps;r.dust+=sp*dt/steps;
      if(r.dust>=.22){r.dust=0;emit(r.x,r.y,WH*.55,'tealdust');if(hasMod('scorched')&&arcHaz.length<60)arcHaz.push({x:r.x,y:r.y,t:.5})}
      const i=Math.floor(r.x),j=Math.floor(r.y);if(!inb(i,j)||r.d>r.max){r.dead=true;break}
      const k=idx(i,j);
      if((nodeAt(i,j)||{}).solid||terrSolid(terr[k])){r.dead=true;break}
      if(coreKs.has(k)){hurtStake(stakeAt(k),35*r.pw);addShake(r.x,r.y,6);r.dead=true;break}
      const w=walls[k];if(w&&!r.wk.has(k)){r.wk.add(k);
        if(w.mat<=1){damageWall(k,w.max*4);emitSpread(i+.5,j+.5,.8,0,WH*.5,'tealdust',0,6)}   // wood and brick: gone
        else{damageWall(k,w.mat===2?140:0);r.dead=true;break}}   // metal takes a heavy hit and stops it
      for(const al of allies())if(al.alive&&!r.hit.has(al)&&groundReach(al.x,al.y,r.x,r.y,.62)){r.hit.add(al);hurtAlly(al,30*r.pw);stunAlly(al,.3);addShake(al.x,al.y,5)}}
    if(r.dead){for(let n=0;n<8;n++)emit(r.x,r.y,WH*.5,'tealdust')}}
  arcs=arcs.filter(r=>!r.dead);
  for(let h=arcHaz.length-1;h>=0;h--){const z=arcHaz[h];z.t-=dt;if(z.t<=0){arcHaz.splice(h,1);continue}
    for(const al of allies())if(al.alive&&groundReach(al.x,al.y,z.x,z.y,.4))hurtAlly(al,16*dt*game.Df.dmg)}
}
// the Arsonist: plants his feet and shows a line with four rings down it for about a second, then lobs a chain of
// napalm bottles that land on the rings, one after another. Each patch burns 10 s (15 with Scorched Earth).
function thinkArsonist(e,dt,tgt,mv,aimAt,Df){
  if(e.st){e.stT-=dt;aimAt(e.lx,e.ly);
    if(e.stT<=0){e.st=0;e.shots++;const d=Math.hypot(e.lx-e.x,e.ly-e.y);
      for(let n=0;n<4;n++){const f=.5+n*.18,x1=clamp(e.x+(e.lx-e.x)*f,.3,N-.3),y1=clamp(e.y+(e.ly-e.y)*f,.3,N-.3),dd=d*f;
        lobs.push({x0:e.x,y0:e.y,x1,y1,t:-n*.14,T:.6+dd*.07,R:1,power:Df.dmg,k:4})}
      sfx('lob',e.x,e.y);addShake(e.x,e.y,3);e.cd=3+rnd()*.9}
    return{eng:true,mv:null}}
  const t=e.foe?{x:e.foe.x,y:e.foe.y}:(tgt||lookAhead(e));
  if(t&&e.cd<=0&&Math.hypot(t.x-e.x,t.y-e.y)<9.5){const a=Math.atan2(t.y-e.y,t.x-e.x),L=Math.min(8,Math.hypot(t.x-e.x,t.y-e.y)+1.2);
    e.st=1;e.stT=e.stM=1;e.lx=clamp(e.x+Math.cos(a)*L,.3,N-.3);e.ly=clamp(e.y+Math.sin(a)*L,.3,N-.3);sfx('lock',e.x,e.y);return{eng:true,mv:null}}
  return{eng:!!(e.foe&&dist2(e.foe,e)<7.5),mv};
}
const napalmT=()=>hasMod('scorched')?15:10;
function napalmLand(l){
  const T=napalmT();fires.push({x:l.x1,y:l.y1,t:T,max:T,tick:.3,r:1,nap:1});sfx('bottle',l.x1,l.y1);addFlash({x:l.x1,y:l.y1,life:.3,max:.3,r:1.2});
  for(let n=0;n<10;n++)emit(l.x1,l.y1,4*u,'fire');for(let n=0;n<4;n++)emit(l.x1,l.y1,4*u,'smoke');
}
// a napalm patch, every tick (0.45 s): it hurts whoever stands in it, sets wood alight and burns the wall it sits on or
// against. Regular fire only burns wood (9 a second); napalm burns brick at that rate and metal at twice it.
const NAPALM_BURN=9;
function napalmTick(f){
  for(const a of allies())if(a.alive&&groundReach(a.x,a.y,f.x,f.y,f.r))hurtAlly(a,7*game.Df.dmg);
  for(let i=Math.floor(f.x-f.r);i<=Math.floor(f.x+f.r);i++)for(let j=Math.floor(f.y-f.r);j<=Math.floor(f.y+f.r);j++){
    if(!inb(i,j)||!groundReach(i+.5,j+.5,f.x,f.y,f.r+.35))continue;const k=idx(i,j),w=walls[k];if(!w)continue;
    if(w.mat===0){if(!(w.fire>0))w.fire=6}else if(w.mat<3)damageWall(k,NAPALM_BURN*.45*(w.mat===2?2:1))}
}
// the Tempest: the Stormcaller's shot, exactly, twice, side by side
const TWIN_GAP=.34;
function thinkTempest(e,dt,tgt,mv,aimAt,Df){
  if(e.st){e.stT-=dt;if(e.stT>.4&&e.foe&&e.foe.alive){e.lx=e.foe.x;e.ly=e.foe.y}aimAt(e.lx,e.ly);
    if(e.stT<=0){twinBolt(e,Df);if(e.hp<e.max*.5&&!e.dbl){e.dbl=true;e.stT=e.stM=.5;sfx('charge',e.x,e.y)}else{e.st=0;e.dbl=false;e.cd=3+rnd()*.8}}
    return{eng:true,mv:null}}
  const f=e.foe;
  if(f&&e.cd<=0){e.st=1;e.stT=e.stM=1.15;e.lx=f.x;e.ly=f.y;sfx('charge',e.x,e.y);return{eng:true,mv:null}}
  if(f){const d=dist2(f,e);aimAt(f.x,f.y);
    if(d<4.5){const dx=e.x-f.x,dy=e.y-f.y,l=Math.hypot(dx,dy)||1;return{eng:false,mv:{x:clamp(e.x+dx/l,.5,N-.5),y:clamp(e.y+dy/l,.5,N-.5)}}}
    return{eng:true,mv:null}}
  if(tgt){aimAt(tgt.x,tgt.y);if(e.cd<=0){e.st=1;e.stT=e.stM=.8;e.lx=tgt.x;e.ly=tgt.y;sfx('charge',e.x,e.y)}return{eng:true,mv:null}}
  return{eng:false,mv};
}
const twinOff=e=>{const a=Math.atan2(e.ly-e.y,e.lx-e.x);return[-Math.sin(a)*TWIN_GAP,Math.cos(a)*TWIN_GAP]};
function twinBolt(e,Df){
  const[nx,ny]=twinOff(e),x=e.x,y=e.y,lx=e.lx,ly=e.ly;
  for(const s of[-1,1]){e.x=x+nx*s;e.y=y+ny*s;e.lx=lx+nx*s;e.ly=ly+ny*s;const end=lightning(e,Df);
    if(end&&hasMod('scorched'))fires.push({x:end.x,y:end.y,t:2,max:2,tick:.2,r:.6})}
  e.x=x;e.y=y;e.lx=lx;e.ly=ly;
}
// the Bulldozer: a dust kick and a lane for 0.7 s, then a charge faster than the Butcher's. People in the way get
// hit and thrown aside. Anything solid stops him: a wall takes a heavy hit (wood and brick break) and he's dazed 3 s.
const BULL={speed:10.5,lane:10,daze:3};
function thinkBulldozer(e,dt,tgt,mv,aimAt,Df){
  e.ab-=dt;
  if(e.st===6){e.stT-=dt;if(rnd()<dt*7)emit(e.x+(rnd()-.5)*.4,e.y+(rnd()-.5)*.4,WH*1.9,'star');if(e.stT<=0){e.st=0;e.ab=1.6;e.cd=.5}return{eng:false,mv:null}}   // dazed
  if(e.st===1){e.stT-=dt;aimAt(e.lx,e.ly);if(rnd()<dt*22)emit(e.x,e.y,3*u,'dust',0);
    if(e.stT<=0){const a=Math.atan2(e.ly-e.y,e.lx-e.x);e.st=2;e.stT=e.stM=BULL.lane/BULL.speed;e.cvx=Math.cos(a)*BULL.speed;e.cvy=Math.sin(a)*BULL.speed;e.hit=new Set();sfx('charge',e.x,e.y)}
    return{eng:true,mv:null}}
  if(e.st===2){e.stT-=dt;let stop=e.stT<=0,daze=false;
    const moveDt=dt*(1-(e.slowT>0?e.slowPct||0:0));
    for(let s=0;s<4&&!stop;s++){const nx=e.x+e.cvx*moveDt/4,ny=e.y+e.cvy*moveDt/4,i=Math.floor(nx),j=Math.floor(ny);
      if(!heightTravelClear(e.x,e.y,nx,ny)){stop=daze=true;break}
      if(!inb(i,j)||(nodeAt(i,j)||{}).solid||terrSolid(terr[idx(i,j)])){stop=daze=true;break}const k=idx(i,j);
      if(coreKs.has(k)){hurtStake(stakeAt(k),45*Df.dmg);stop=daze=true;break}
      if(walls[k]){damageWall(k,200*MAT[walls[k].mat].blast);addShake(nx,ny,9);sfx('collapse',nx,ny);stop=daze=true;break}
      e.x=nx;e.y=ny;
      for(const a of allies())if(a.alive&&!e.hit.has(a)&&Math.hypot(a.x-e.x,a.y-e.y)<.65){e.hit.add(a);hurtAlly(a,34*Df.dmg);
        const l=Math.hypot(e.cvx,e.cvy),sd=((a.x-e.x)*-e.cvy+(a.y-e.y)*e.cvx)>=0?1:-1;moveEnt(a,-e.cvy/l*.6*sd,e.cvx/l*.6*sd,a===qm?true:pt(a));if(a!==qm)a.tp++;addShake(a.x,a.y,6)}}
    e.walk+=dt*20;if(rnd()<.6)emit(e.x,e.y,4*u,'dust',0);
    if(daze){e.st=6;e.stT=e.stM=BULL.daze;flt(e.x,e.y-.5,'DAZED','#ffd23a');addShake(e.x,e.y,8);for(let n=0;n<8;n++)emit(e.x,e.y,WH*1.9,'star')}
    else if(stop){e.st=0;e.ab=2.4;e.cd=.6}
    return{eng:true,mv:null}}
  const f=e.foe;
  if(f&&e.cd<=0&&e.ab<=0&&dist2(f,e)<9&&dist2(f,e)>1.2){const a=aimAt(f.x,f.y);e.st=1;e.stT=e.stM=.7;e.lx=clamp(e.x+Math.cos(a)*BULL.lane,.2,N-.2);e.ly=clamp(e.y+Math.sin(a)*BULL.lane,.2,N-.2);sfx('drill',e.x,e.y);return{eng:true,mv:null}}
  if(tgt&&heightDist(tgt.x,tgt.y,e.x,e.y)<1.35){aimAt(tgt.x,tgt.y);
    if(e.cd<=0){e.cd=1;const k=idx(Math.floor(tgt.x),Math.floor(tgt.y));if(walls[k])damageWall(k,60*MAT[walls[k].mat].blast);else if(coreKs.has(k))hurtStake(stakeAt(k),20*Df.dmg);sfx('drill',e.x,e.y)}
    return{eng:true,mv:null}}
  if(f){aimAt(f.x,f.y);if(dist2(f,e)<1.3){if(e.cd<=0){e.cd=1.1;hurtAlly(f,20*Df.dmg);sfx('drill',e.x,e.y)}return{eng:true,mv:null}}return{eng:false,mv:{x:f.x,y:f.y}}}
  return{eng:false,mv};
}
// the Harbinger: missiles from his boat in a high arc. Three at a time, around whoever he's after; every one shows a
// ring where it will land for its whole flight (about 1.6 s), so anyone moving gets out of the way. On a map without a
// river he fires from a fixed spot at the edge. He still puts boarding crews ashore now and then.
function thinkHarbinger(e,dt,tgt,mv,aimAt,Df){
  e.ab-=dt;
  if(!e.rage&&e.hp<e.max*.5){e.rage=true;flt(e.x,e.y-.4,'FULL SALVO','#ff7a3a')}
  if(e.st===1){e.stT-=dt;if(e.stT>.3&&e.foe&&e.foe.alive){e.lx=e.foe.x;e.ly=e.foe.y}aimAt(e.lx,e.ly);
    if(e.stT<=0){e.st=0;const n=e.rage?4:3;
      for(let m=0;m<n;m++){const a=rnd()*6.283,r=m?.9+rnd()*1.1:0,x1=clamp(e.lx+Math.cos(a)*r,.3,N-.3),y1=clamp(e.ly+Math.sin(a)*r,.3,N-.3),d=Math.hypot(x1-e.x,y1-e.y);
        lobs.push({x0:e.x,y0:e.y,x1,y1,t:-m*.22,T:1.45+d*.03,R:1.35,power:1.1*Df.dmg,k:3})}
      sfx('rocket',e.x,e.y);addShake(e.x,e.y,4);e.cd=e.rage?2.6:3.4}
    return{eng:true,mv:null}}
  if(e.raft&&e.ab<=0&&e.crews<3){e.ab=20;const bank=bankTile(e);if(bank){e.crews++;['rifle','breach'].forEach((t,n)=>spawnEnemyAt(t,bank[0]+.5+(n-.5)*.2,bank[1]+.5));flt(bank[0]+.5,bank[1]+.2,'BOARDING PARTY','#ff7a3a');sfx('splash',bank[0]+.5,bank[1]+.5)}}
  const f=e.foe||nearestAlly(e);
  if(f&&e.cd<=0&&dist2(f,e)<12){e.st=1;e.stT=e.stM=.8;e.lx=f.x;e.ly=f.y;sfx('lock',e.x,e.y);return{eng:true,mv:null}}
  if(e.raft){const goal=f?nearestWater(f.x,f.y,false):nearestWater(core.i+.5,core.j+.5,false);raftMove(e,dt,goal)}
  if(f)aimAt(f.x,f.y);
  return{eng:true,mv:null};
}
// where a Blitzkrieg boss comes in: the Harbinger on the river if there is one, else on the edge like the rest
function blitzSpawnFix(e,key){if(key!=='harbinger')return;const R=game.lay&&game.lay.raftAt;e.raft=!!(R&&R.length);e.ab=e.raft?12:1e9;e.crews=0;e.pathT=0;e.next=-1}
// the after-action screen for a Blitzkrieg Rush that reached the evacuation: yours, then who else made it out
function blitzOverText(res,crew){
  const P=[...players.values()],outN=P.filter(p=>p.out).length,ok=res==='evac';
  $('overTitle').textContent=ok?'EVACUATED':'LEFT BEHIND';$('overTitle').className=ok?'':'lost';
  $('overEyebrow').textContent=`${player.C.name} · ${game.Df.name} · ${campaign()?'OPERATION WHITEOUT':'BLITZKRIEG RUSH'}${crew} · ${ok?'VICTORY':'HALF REWARDS'} · ${outN} OF ${P.length} MADE IT OUT${game.mods.length?' · '+modNames(game.mods).join(' + '):''}`;
  const made=P.filter(p=>p.out).map(p=>p===player?'you':p.name),left=P.filter(p=>!p.out).map(p=>p===player?'you':p.name);
  $('overLede').textContent=(ok?'You made it out of the Final Blitz.':'The evac left without you: half your cases and shards this time. Raids, boss kills and skill points still count in full.')+
    (P.length>1?` Made it: ${made.join(', ')||'nobody'}.${left.length?` Left behind: ${left.join(', ')}.`:''}`:'');
}
