/* ================= phases ================= */
function spawnNearCore(c=core,team=true){for(const[a,b]of[[1,0],[0,1],[-1,0],[0,-1],[1,1],[-1,-1],[1,-1],[-1,1],[2,0],[0,2],[-2,0],[0,-2]]){const i=c.i+a,j=c.j+b;if(!solidTile(i,j,team))return[i+.5,j+.5]}return[c.i+1.5,c.j+.5]}
// free-for-all: come back in at the spot furthest from everyone still standing
function ffaSpawn(p){let best=FFA_SPAWNS[0],bd=-1;for(const s of FFA_SPAWNS){let m=1e9;for(const o of players.values())if(o!==p&&o.alive)m=Math.min(m,Math.hypot(o.x-s[0],o.y-s[1]));m+=rnd()*.5;if(m>bd){bd=m;best=s}}return best.slice()}
const truce=()=>game.pvp==='base'&&game.phase==='build';
const respawnAt=p=>game.pvp==='ffa'?ffaSpawn(p):game.pvp==='base'?spawnNearCore(stakeOf(p),p.team):spawnNearCore();
// 0 day, 1 golden hour, 2 night. Endless cycles; fixed-length runs end in the dark.
function todStage(stage){
  const W=game.waves;
  if(!isFinite(W)){const c=((stage-1)%6+6)%6;return c>4.5?2:c>2.5?1:0}
  return stage>W-(W>=10?1.5:.5)?2:stage>W*.5?1:0;
}
const waveEff=()=>game.mode==='endless'?1+(game.wave-1)*.55:game.wave;
const raidName=w=>isFinite(game.waves)?`RAID ${w} OF ${game.waves}`:`RAID ${w}`;
function startBuild(dur){
  game.phase='build';game.timer=dur;
  const pay=8+game.wave;for(const p of players.values())p.sal+=pay;
  for(const p of players.values()){p.nades=Math.max(p.nades,p.maxN);if(p.downed){p.alive=true;p.downed=false;p.revive=0}p.hp=p.max;p.stun=0;if(p.gun.mag){p.ammo=p.gun.mag;p.rl=0}}
  if(!qm.alive){qm.alive=true;[qm.x,qm.y]=spawnNearCore();flt(qm.x,qm.y,'DELL IS BACK','#a9bccb')}qm.hp=qm.max;
  let note='Grenades refilled. Dell will head out for materials.';
  for(const n of nodes)if(n.locked&&n.unlock===game.wave+1){n.locked=false;note=n.type===1?'The brick kiln is lit, south-east of the stake. Brick soaks rifle fire.':'Scrap metal is open in the far yard. Six a plate, and it shrugs off bullets.'}
  if(game.wave===2)note+=' Breachers join the next raid. Shoot them before they reach a wall.';
  if(todStage(game.wave+1)===2&&todStage(game.wave)!==2)note+=isFinite(game.waves)&&game.wave+1>=game.waves?' The last raid comes at night.':' The next raid comes at night.';
  toastAll(`RAID ${game.wave} BROKEN`,`+${pay} salvage each. Spend it at the stake. `+note);setTip('');
}
function startRaid(){
  if(game.pvp){startBattle();return}
  game.wave++;game.phase='raid';setTip('');closeArmory();
  const k=Math.floor(waveEff()),Df=game.Df,P=Math.max(1,players.size),q=[];
  // a bigger crew mostly means more riflemen; grenadiers and breachers grow much more slowly
  const boss=bossOf(game.wave);
  const nr=Math.max(2,2+k+Df.extra-(boss?2:0))+Math.round((P-1)*(1.5+k*.45)),
        ng=Math.max(0,k-1)+(k>=2?Math.floor((P-1)/3):0),
        nb=(k>=3?k-2+(Df.extra>0?1:0):0)+(k>=3?Math.floor((P-1)/3):0);
  for(let n=0;n<nr;n++)q.push('rifle');
  for(let n=0;n<ng;n++)q.splice(1+Math.floor(rnd()*q.length),0,'gren');
  for(let n=0;n<nb;n++)q.splice(2+Math.floor(rnd()*(q.length-1)),0,'breach');
  if(boss)q.splice(Math.max(2,Math.floor(q.length*.45)),0,'boss:'+boss);
  game.queue=q;game.spawnT=.8;game.spawnGap=Math.max(.5,1.1-.1*(P-1));sfx('siren');
  const bits=[`${nr} riflemen`];if(ng)bits.push(`${ng} grenadier${ng>1?'s':''}`);if(nb)bits.push(`${nb} breacher${nb>1?'s':''}`);
  toastAll(boss?`${raidName(game.wave)} · BOSS`:raidName(game.wave),`${bits.join(', ')}${boss?' and '+BOSSES[boss].name:''} coming over the east fence${todStage(game.wave)===2?' in the dark':''}.`);
}
function startBattle(){
  if(game.pvp!=='base'||game.phase!=='build')return;
  game.phase='raid';game.timer=0;setTip('');sfx('siren');
  for(const p of players.values())p.sal+=10;
  toastAll('BATTLE','The truce is over. Knock down their stake, keep yours standing.');
}
function endPvp(winner){
  if(game.phase==='over')return;game.phase='over';game.winner=winner;bullets=[];lobs=[];rockets=[];fires=[];
  game.won=game.pvp==='base'?player.team===winner:player.id===winner;showOver();
}
function updatePvp(dt){
  if(game.phase==='build'){game.timer-=dt;if(game.timer<=0)startBattle()}
  else if(game.pvp==='ffa'){game.timer-=dt;if(game.timer<=0){let best=null;for(const p of players.values())if(!best||p.kills>best.kills||(p.kills===best.kills&&p.deaths<best.deaths))best=p;endPvp(best?best.id:'')}}
  else game.timer+=dt;
}
/* ---------- bosses ---------- */
// Every fifth raid in co-op has a boss in it (it replaces two riflemen; the raid isn't longer). Each boss is one
// entry here: stats, look, an intro line and a think() that runs its attacks. To add a boss, add an entry and
// put its key in BOSS_ORDER; the spawning, health bar, network sync and rewards all come for free.
const BOSSES={
  demolisher:{name:'THE DEMOLISHER',hp:620,speed:1.05,scan:9,bounty:40,col:'#ff8a3a',think:thinkDemolisher,
    look:{body:'#4b4a38',vest:'#23241c',pants:'#26241e',head:'#a98262',helmet:'#1f201a',pack:'#3a3a28',bandana:'#c8551e',gl:20,weapon:'rpg'},
    intro:'He fires slow rockets. A red line shows where the next one goes: step out of it.'},
  butcher:{name:'THE BUTCHER',hp:760,speed:2.05,scan:8,bounty:40,col:'#ff4a3a',think:thinkButcher,
    look:{body:'#5c1d18',vest:'#2a0c09',pants:'#221412',head:'#9c7456',helmet:'#3a0f0c',bandana:'#1a0a08',gl:14,weapon:'sword'},
    intro:'A blade and a temper. A red lane means he is about to charge down it: get out of the lane.'},
  storm:{name:'THE STORMCALLER',hp:540,speed:1.2,scan:12.5,bounty:40,col:'#7fe0ff',think:thinkStorm,
    look:{body:'#26323f',vest:'#10171e',pants:'#1a2028',head:'#b0896a',boonie:'#1b2530',glow:'#7fe0ff',gl:20,weapon:'zap'},
    intro:'A lightning rifle that jumps between people. A blue line means a shot is coming: break line of sight, and spread out.'}
};
const BOSS_ORDER=['demolisher','butcher','storm'];
const bossOf=w=>w%5===0?BOSS_ORDER[(w/5-1)%BOSS_ORDER.length]:'';
const ETYPES={rifle:{hp:36,speed:1.5},gren:{hp:46,speed:1.25},breach:{hp:30,speed:2.1}},ECODE=['rifle','gren','breach',...BOSS_ORDER.map(k=>'boss:'+k)];
function spawnBoss(key){
  const B=BOSSES[key];if(!B)return;let x=0,y=0;
  for(let a=0;a<40;a++){const i=N-1,j=2+Math.floor(rnd()*9);if(!solidTile(i,j)){x=i+.5;y=j+.5;break}}
  if(!x){x=N-.5;y=6.5}
  const P=Math.max(1,players.size),hp=B.hp*game.Df.hp*(1+.35*(P-1))*(1+.25*Math.floor(Math.max(0,game.wave-5)/15));
  enemies.push({id:nextId++,type:'boss',boss:key,big:true,x,y,hp,max:hp,cd:2.2,walk:0,aim:{x:-1,y:0},flash:0,speed:B.speed,scanT:0,foe:null,planted:false,st:0,stT:0,stM:1,lx:x,ly:y,shots:0,ab:3,sw:0});
  sfx('horn');addShake(x,y,8);toastAll(B.name,B.intro);
}
function bossDown(e,own){
  const B=BOSSES[e.boss],p=own&&own!=='dell'?players.get(own):null,share=p?15:20;game.bosses++;
  for(const o of players.values())o.sal+=o===p?B.bounty:share;
  flt(e.x,e.y-.4,p?`+${B.bounty} SALVAGE`:`+${share} SALVAGE EACH`,'#e2b436');
  for(let n=0;n<26;n++)emit(e.x,e.y,WH*.8,n%2?'fire':'spark');addShake(e.x,e.y,11);sfx('bigboom',e.x,e.y);
  const bc=bossCase(),cn=bc?` +1 ${CASES[bc].name.replace(' CASE',' Case')} each, added when the run ends (or when you leave it).`:'';
  toastAll(`${B.name} IS DOWN`,(p?`${p.name} landed it: +${B.bounty} salvage. Everyone else +${share}.`:`+${share} salvage each.`)+cn);
}
// the Demolisher: plants his feet, shows a red line for a second, then sends a slow rocket down it. Every third
// volley is a fan of three. Rockets burst on whatever they touch and leave the ground burning for a few seconds.
function thinkDemolisher(e,dt,tgt,mv,aimAt,Df){
  if(e.st){e.stT-=dt;aimAt(e.lx,e.ly);
    if(e.stT<=0){const a=Math.atan2(e.ly-e.y,e.lx-e.x),fan=e.st===2?[-.3,0,.3]:[0];e.st=0;e.shots++;
      for(const o of fan)rockets.push({x:e.x+Math.cos(a+o)*.7,y:e.y+Math.sin(a+o)*.7,vx:Math.cos(a+o)*4.2,vy:Math.sin(a+o)*4.2,d:0,max:12,pw:1.15*Df.dmg});
      sfx('rocket',e.x,e.y);addFlash({x:e.x+Math.cos(a)*.7,y:e.y+Math.sin(a)*.7,life:.14,max:.14,r:1.5});addShake(e.x,e.y,4);e.cd=2.4+rnd()*.8}
    return{eng:true,mv:null}}
  const t=e.foe?{x:e.foe.x,y:e.foe.y}:(tgt||lookAhead(e));
  if(t&&e.cd<=0&&Math.hypot(t.x-e.x,t.y-e.y)<10){e.st=e.shots%3===2?2:1;e.stT=e.stM=.95;e.lx=clamp(t.x,.3,N-.3);e.ly=clamp(t.y,.3,N-.3);sfx('lock',e.x,e.y);return{eng:true,mv:null}}
  return{eng:!!(e.foe&&dist2(e.foe,e)<7.5),mv};
}
// the Butcher: runs you down. Close up he winds up (a red wedge) and cuts; from a few tiles away he shows a red
// lane and charges down it, through wood, knocking people aside. Below 40% health he gets faster and angrier.
function thinkButcher(e,dt,tgt,mv,aimAt,Df){
  if(!e.rage&&e.hp<e.max*.4){e.rage=true;e.speed=BOSSES.butcher.speed*1.25;flt(e.x,e.y-.4,'ENRAGED','#ff4a3a');sfx('horn',e.x,e.y)}
  e.ab-=dt;
  if(e.st===1){e.stT-=dt;if(e.foe)aimAt(e.foe.x,e.foe.y);if(e.stT<=0){e.st=0;bladeSlash(e,Df);e.cd=e.rage?.75:1.05}return{eng:true,mv:null}}
  if(e.st===2){e.stT-=dt;aimAt(e.lx,e.ly);
    if(e.stT<=0){const a=Math.atan2(e.ly-e.y,e.lx-e.x);e.st=3;e.stT=e.stM=.72;e.cvx=Math.cos(a)*9;e.cvy=Math.sin(a)*9;e.hit=new Set();sfx('slash',e.x,e.y)}
    return{eng:true,mv:null}}
  if(e.st===3){e.stT-=dt;let stop=e.stT<=0;
    for(let s=0;s<3&&!stop;s++){const nx=e.x+e.cvx*dt/3,ny=e.y+e.cvy*dt/3,i=Math.floor(nx),j=Math.floor(ny);
      if(!inb(i,j)||(nodeAt(i,j)||{}).solid){stop=true;break}const k=idx(i,j);
      if(coreKs.has(k)){hurtStake(stakeAt(k),40*Df.dmg);addShake(nx,ny,8);stop=true;break}
      if(walls[k]){damageWall(k,150*MAT[walls[k].mat].blast);addShake(nx,ny,6);if(walls[k]){stop=true;break}}
      e.x=nx;e.y=ny;
      for(const a of allies())if(a.alive&&!e.hit.has(a)&&Math.hypot(a.x-e.x,a.y-e.y)<.62){e.hit.add(a);hurtAlly(a,32*Df.dmg);
        const l=Math.hypot(e.cvx,e.cvy),sd=((a.x-e.x)*-e.cvy+(a.y-e.y)*e.cvx)>=0?1:-1;moveEnt(a,-e.cvy/l*.55*sd,e.cvx/l*.55*sd,a===qm?true:pt(a));addShake(a.x,a.y,6)}}
    e.walk+=dt*18;if(rnd()<.5)emit(e.x,e.y,4*u,'dust',0);
    if(stop){e.st=0;e.ab=e.rage?3.5:5.5;e.cd=.45}
    return{eng:true,mv:null}}
  const f=e.foe;
  if(f){const d=dist2(f,e);
    if(d<1.15&&e.cd<=0){e.st=1;e.stT=e.stM=e.rage?.28:.4;aimAt(f.x,f.y);sfx('lock',e.x,e.y);return{eng:true,mv:null}}
    if(d>2.4&&d<7&&e.ab<=0){const a=aimAt(f.x,f.y);e.st=2;e.stT=e.stM=.8;e.lx=clamp(e.x+Math.cos(a)*6.5,.2,N-.2);e.ly=clamp(e.y+Math.sin(a)*6.5,.2,N-.2);sfx('charge',e.x,e.y);return{eng:true,mv:null}}
    aimAt(f.x,f.y);return{eng:false,mv:d<.85?null:{x:f.x,y:f.y}}}   // straight at you
  if(tgt&&Math.hypot(tgt.x-e.x,tgt.y-e.y)<1.35){aimAt(tgt.x,tgt.y);
    if(e.cd<=0){e.cd=.9;const k=idx(Math.floor(tgt.x),Math.floor(tgt.y));if(walls[k])damageWall(k,70*MAT[walls[k].mat].blast);else if(coreKs.has(k))hurtStake(stakeAt(k),20*Df.dmg);
      sfx('slash',e.x,e.y);slashFx(e.x,e.y,e.aim.x,e.aim.y)}
    return{eng:true,mv:null}}
  return{eng:false,mv};
}
function bladeSlash(e,Df){
  const a0=Math.atan2(e.aim.y,e.aim.x);let hit=false;
  for(const a of allies()){if(!a.alive)continue;const dx=a.x-e.x,dy=a.y-e.y,d=Math.hypot(dx,dy);if(d>1.5)continue;
    let da=Math.abs(Math.atan2(dy,dx)-a0);if(da>Math.PI)da=2*Math.PI-da;if(da<1.2){hurtAlly(a,28*Df.dmg);hit=true}}
  sfx('slash',e.x,e.y);slashFx(e.x,e.y,e.aim.x,e.aim.y);if(hit)addShake(e.x,e.y,5);
}
// the Stormcaller: keeps his distance. A blue line tracks you for most of a second, then locks for the last
// 0.4 s and the bolt goes down it: it tears through wood, stops at brick and metal, stuns whoever it hits and
// jumps to up to two people standing near them. Below half health he fires twice.
function thinkStorm(e,dt,tgt,mv,aimAt,Df){
  if(e.st){e.stT-=dt;if(e.stT>.4&&e.foe&&e.foe.alive){e.lx=e.foe.x;e.ly=e.foe.y}aimAt(e.lx,e.ly);
    if(e.stT<=0){lightning(e,Df);if(e.hp<e.max*.5&&!e.dbl){e.dbl=true;e.stT=e.stM=.5;sfx('charge',e.x,e.y)}else{e.st=0;e.dbl=false;e.cd=3+rnd()*.8}}
    return{eng:true,mv:null}}
  const f=e.foe;
  if(f&&e.cd<=0){e.st=1;e.stT=e.stM=1.15;e.lx=f.x;e.ly=f.y;sfx('charge',e.x,e.y);return{eng:true,mv:null}}
  if(f){const d=dist2(f,e);aimAt(f.x,f.y);
    if(d<4.5){const dx=e.x-f.x,dy=e.y-f.y,l=Math.hypot(dx,dy)||1;return{eng:false,mv:{x:clamp(e.x+dx/l,.5,N-.5),y:clamp(e.y+dy/l,.5,N-.5)}}}
    return{eng:true,mv:null}}
  if(tgt){aimAt(tgt.x,tgt.y);if(e.cd<=0){e.st=1;e.stT=e.stM=.8;e.lx=tgt.x;e.ly=tgt.y;sfx('charge',e.x,e.y)}return{eng:true,mv:null}}
  return{eng:false,mv};
}
function lightning(e,Df){
  const a=Math.atan2(e.ly-e.y,e.lx-e.x),cx=Math.cos(a),cy=Math.sin(a);let x=e.x,y=e.y,hitA=null,last=-1;
  for(let d=.5;d<12.5;d+=.1){x=e.x+cx*d;y=e.y+cy*d;const i=Math.floor(x),j=Math.floor(y);if(!inb(i,j))break;const k=idx(i,j);
    if(coreKs.has(k)){hurtStake(stakeAt(k),30*Df.dmg);break}
    if((nodeAt(i,j)||{}).solid)break;
    const w=walls[k];if(w&&k!==last){last=k;const m=w.mat;damageWall(k,m===0?95:40+60*MAT[m].bullet);if(m>0&&walls[k])break}
    for(const al of allies())if(al.alive&&Math.hypot(al.x-x,al.y-y)<.42){hitA=al;break}
    if(hitA)break}
  const pts=[e.x+cx*.5,e.y+cy*.5,hitA?hitA.x:x,hitA?hitA.y:y];
  if(hitA){hurtAlly(hitA,40*Df.dmg);stunAlly(hitA,.9);const done=new Set([hitA]);let from=hitA;
    for(let c=0;c<2;c++){let nb=null,nd=2.6;for(const o of allies())if(o.alive&&!done.has(o)){const d=dist2(o,from);if(d<nd){nd=d;nb=o}}
      if(!nb)break;done.add(nb);hurtAlly(nb,18*Df.dmg);stunAlly(nb,.5);pts.push(nb.x,nb.y);from=nb}}
  zapFx(pts);sfx('zap',x,y);addShake(x,y,7);addFlash({x,y,life:.2,max:.2,r:1.7});
  for(let n=0;n<8;n++)emit(x,y,WH*.6,'arc');
}
function stunAlly(a,t){if(a!==qm){a.stun=Math.max(a.stun||0,t);if(a.id)personal(a,'zap')}}
function zapFx(pts){rec(['z',...pts.map(r2)]);zaps.push({pts,life:.38,max:.38})}
function ringFx(x,y,r0,r1,life,c1,c2,w=2){rec(['o',r2(x),r2(y),r0,r1,life,c1,c2,w]);rings.push({x,y,r0,r1,life,max:life,c1,c2,w})}
function slashFx(x,y,ax,ay){rec(['w',r2(x),r2(y),r2(ax),r2(ay)]);slashes.push({x,y,ax,ay,life:.28,max:.28})}
// boss rockets: slow (4.2 tiles a second) so they can be seen and side-stepped
function updateRockets(dt){
  for(const r of rockets){const sp=Math.hypot(r.vx,r.vy),steps=Math.ceil(sp*dt/.12);
    for(let s=0;s<steps&&!r.dead;s++){r.x+=r.vx*dt/steps;r.y+=r.vy*dt/steps;r.d+=sp*dt/steps;
      const i=Math.floor(r.x),j=Math.floor(r.y);let hit=!inb(i,j)||r.d>r.max;
      if(!hit){const k=idx(i,j);hit=!!walls[k]||coreKs.has(k)||!!(nodeAt(i,j)||{}).solid}
      if(!hit)for(const a of allies())if(a.alive&&Math.hypot(a.x-r.x,a.y-r.y)<.45){hit=true;break}
      if(hit){r.dead=true;const bx=clamp(r.x-r.vx/sp*.2,.1,N-.1),by=clamp(r.y-r.vy/sp*.2,.1,N-.1);explode(bx,by,1.7,r.pw,null,true);fires.push({x:bx,y:by,t:4,max:4,tick:.2})}}}
  dropDead(rockets);
  for(const f of fires){f.t-=dt;f.tick-=dt;
    if(f.tick<=0){f.tick=.45;for(const a of allies())if(a.alive&&Math.hypot(a.x-f.x,a.y-f.y)<.9)hurtAlly(a,6*game.Df.dmg);
      const w=walls[idx(Math.floor(f.x),Math.floor(f.y))];if(w&&w.mat===0&&!(w.fire>0))w.fire=5}}
  fires=fires.filter(f=>f.t>0);
}
function spawnEnemy(type){
  if(type.startsWith('boss:')){spawnBoss(type.slice(5));return}
  let x=0,y=0;
  for(let a=0;a<30;a++){let i,j;if(rnd()<.6){i=N-1;j=Math.floor(rnd()*12)}else{j=0;i=6+Math.floor(rnd()*(N-6))}if(!solidTile(i,j)){x=i+.5;y=j+.5;break}}
  if(!x)return;const T=ETYPES[type],s=(1+(game.mode==='endless'?.045:.07)*(game.wave-1))*game.Df.hp;
  enemies.push({id:nextId++,type,x,y,hp:T.hp*s,max:T.hp*s,cd:1+rnd(),walk:rnd()*6,aim:{x:-1,y:0},flash:0,speed:T.speed,scanT:0,foe:null,planted:false});
}
function endGame(win){
  game.phase='over';game.won=win;bullets=[];lobs=[];rockets=[];fires=[];
  if(demo){demoT=0;return}
  showOver();
}
function setStats(pairs){const rows=[...document.querySelectorAll('#over .stats>div')];rows.forEach((d,i)=>{const pr=pairs[i];d.hidden=!pr;if(pr){d.children[0].textContent=pr[0];d.children[1].textContent=pr[1]}})}
const COOP_STATS=['Raids survived','Raiders dropped','Walls raised','Walls lost','Repairs by Dell','Revives'];
function showPvpOver(){
  const win=!!game.won,P=[...players.values()],me=player,S=game.stats;sfx(win?'win':'lose',undefined,undefined,true);
  $('overTitle').textContent=win?'VICTORY':'DEFEAT';$('overTitle').className=win?'':'lost';
  if(game.pvp==='base'){
    const wT=TEAMS[game.winner]||TEAMS.a,na=P.filter(p=>p.team==='a').length,nb=P.length-na;
    $('overEyebrow').textContent=`BASE BATTLE · ${na}V${nb} · ${wT.name} TOOK THE ${game.winner==='a'?'EAST':'WEST'} STAKE`;
    $('overLede').textContent=win?'Their stake is splinters. Run it back and swap sides if it was lopsided.':'They got through. Look at which wall went first; that\'s where to put metal next time.';
    let tk=0,ek=0;for(const p of P)if(p.team===me.team)tk+=p.kills;else ek+=p.kills;
    setStats([['Your drops',me.kills|0],['Times you fell',me.deaths|0],[`${TEAMS[me.team].name} drops`,tk],[`${TEAMS[me.team==='a'?'b':'a'].name} drops`,ek],['Walls raised',S.built],['Walls lost',S.lost]]);
  }else{
    const rank=P.slice().sort((a,b)=>b.kills-a.kills||a.deaths-b.deaths),place=rank.indexOf(me)+1,lead=rank[0];
    $('overEyebrow').textContent=`FREE-FOR-ALL · ${P.length} PLAYERS · ${lead?lead.name.toUpperCase():''} WINS`;
    $('overLede').textContent=rank.map((p,i)=>`${i+1}. ${p===me?'YOU':p.name.toUpperCase()} ${p.kills}`).join('   ');
    const ord=n=>n+(['th','st','nd','rd'][n%100>10&&n%100<14?0:Math.min(n%10,4)%4]||'th');
    setStats([['Your drops',me.kills|0],['Times you fell',me.deaths|0],['Place',`${ord(place)} of ${P.length}`],['Winning score',lead?`${lead.kills}`:'0']]);
  }
  const loot=game.rewarded?null:pvpReward(win,me.kills|0);game.rewarded=true;
  if(loot){$('overLoot').textContent=loot;$('overLoot').hidden=false}else $('overLoot').hidden=true;
  $('againBtn').hidden=NET.mode==='guest';$('overWait').hidden=NET.mode!=='guest';
  setTimeout(()=>{if(game.phase==='over')$('over').hidden=false},900);
}
function showOver(){
  if(game.pvp){showPvpOver();return}
  setStats(COOP_STATS.map(t=>[t,0]));
  const win=!!game.won;sfx(win?'win':'lose',undefined,undefined,true);
  $('overTitle').textContent=win?'CLAIM HELD':'CLAIM LOST';$('overTitle').className=win?'':'lost';
  const crew=players.size>1?` · CREW OF ${players.size}`:'',W=game.waves,endless=!isFinite(W);
  const held=win?W:Math.max(0,game.wave-1),S=game.stats;
  $('overEyebrow').textContent=`${player.C.name} · ${game.Df.name} · ${endless?'ENDLESS':W+' RAIDS'}${crew} · ${win?`ALL ${W} RAIDS BROKEN`:endless?`${held} RAIDS HELD`:`STAKE FELL IN RAID ${game.wave}`}`;
  $('overLede').textContent=win?'The stake is still standing. Try it with less wood and more nerve, or turn the threat up.':endless?`Endless only ends one way. ${held} raids is the number to beat.`:'They got to the core. Look at where they broke in. That hole is the lesson.';
  const loot=game.rewarded?null:lockerReward(held,win,player.kills|0);game.rewarded=true;
  if(loot){$('overLoot').textContent=loot;$('overLoot').hidden=false}else $('overLoot').hidden=true;
  $('sWaves').textContent=held;$('sDrop').textContent=S.dropped;$('sBuilt').textContent=S.built;$('sLost').textContent=S.lost;$('sRep').textContent=S.repairs;$('sRev').textContent=S.revives;
  if(NET.mode==='solo')saveBest(held,S.dropped);
  $('againBtn').hidden=NET.mode==='guest';$('overWait').hidden=NET.mode!=='guest';
  setTimeout(()=>{if(game.phase==='over')$('over').hidden=false},win?600:900);
}
function togglePause(){
  const open=$('pause').hidden;
  if(NET.mode==='solo')game.paused=open;
  $('pause').hidden=!open;
  $('pauseEyebrow').textContent=NET.mode!=='solo'?(game.pvp?'THE FIGHT DOESN’T PAUSE':'THE RAID DOESN’T PAUSE ONLINE'):`PAUSED · ${game.phase==='build'?'BUILD PHASE':raidName(game.wave)}`;
  for(const s of[stickMove,stickAim]){s.id=null;s.vx=s.vy=s.mag=0}mouse.down=false;
}

