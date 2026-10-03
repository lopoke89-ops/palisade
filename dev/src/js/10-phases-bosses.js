/* ================= phases ================= */
function spawnNearCore(c=core,team=true){for(const[a,b]of[[1,0],[0,1],[-1,0],[0,-1],[1,1],[-1,-1],[1,-1],[-1,1],[2,0],[0,2],[-2,0],[0,-2]]){const i=c.i+a,j=c.j+b;if(!solidTile(i,j,team))return[i+.5,j+.5]}return[c.i+1.5,c.j+.5]}
// free-for-all: come back in at the spot furthest from everyone still standing
function ffaSpawn(p){const S=(game.lay&&game.lay.pspawns)||FFA_SPAWNS;let best=S[0],bd=-1;for(const s of S){let m=1e9;for(const o of players.values())if(o!==p&&o.alive)m=Math.min(m,Math.hypot(o.x-s[0],o.y-s[1]));m+=rnd()*.5;if(m>bd){bd=m;best=s}}return best.slice()}
const truce=()=>game.pvp==='base'&&game.phase==='build';
const respawnAt=p=>game.pvp==='ffa'?ffaSpawn(p):game.pvp==='base'?spawnNearCore(stakeOf(p),p.team):spawnNearCore();
// 0 day, 1 golden hour, 2 night. Endless cycles; fixed-length runs end in the dark.
function todStage(stage){
  if(MAP&&MAP.night&&!game.pvp||hasMod('nightmare'))return 2;   // Ashfall Quarry is always night (and Nightmare is, everywhere)
  const W=game.waves;
  if(!isFinite(W)){const c=((stage-1)%6+6)%6;return c>4.5?2:c>2.5?1:0}
  return stage>W-(W>=10?1.5:.5)?2:stage>W*.5?1:0;
}
const waveEff=()=>game.mode==='endless'?1+(game.wave-1)*.55:game.mode==='blitz'?game.wave*1.2+1:game.wave;   // Blitzkrieg Rush: every raid a notch harder
const raidName=w=>campaign()?(w>=13?'THE WHITEOUT GAUNTLET':`CHAPTER ${campaignChapter(w)+1} · RAID ${(w-1)%3+1}/3`):isFinite(game.waves)?`RAID ${w} OF ${game.waves}`:`RAID ${w}`;
function startBuild(dur){
  qm.completedRaids=Math.max(qm.completedRaids||0,game.wave);qm.planT=0;qm.commandJob=null;
  game.phase='build';game.timer=dur;game.prepEpoch=(game.prepEpoch||0)+1;
  const pay=8+game.wave;for(const p of players.values())p.sal+=pay;
  for(const p of players.values()){p.nades=Math.max(p.nades,p.maxN);if(p.downed){p.alive=true;p.downed=false;p.revive=0}p.hp=p.max;p.stun=0;if(p.gun.mag){p.ammo=p.gun.mag;p.rl=0}}
  if(!qm.alive&&!qm.gone){qm.alive=true;[qm.x,qm.y]=spawnNearCore();flt(qm.x,qm.y,'DELGADO IS BACK','#a9bccb')}qm.hp=qm.max;
  game.wx=0;refillAbilities();
  let note=qm.gone?'Grenades refilled.':'Grenades refilled. Delgado will head out for materials.';
  // v0.9.6.4 campaign: the Yard's metal opens after raid 2 (it was due at raid 4, after the map had already changed)
  if(campaign()&&!game.chapter)for(const n of nodes)if(n.locked&&n.unlock>3)n.unlock=3;
  for(const n of nodes)if(n.locked&&n.unlock===game.wave+1){n.locked=false;note=n.type===1?'A brick kiln is lit. Brick soaks rifle fire.':'Scrap metal is open. It shrugs off bullets.'}
  if(game.wave===2)note+=' Breachers join the next raid. Shoot them before they reach a wall.';
  if(todStage(game.wave+1)===2&&todStage(game.wave)!==2)note+=isFinite(game.waves)&&game.wave+1>=game.waves?' The last raid comes at night.':' The next raid comes at night.';
  toastAll(`RAID ${game.wave} BROKEN`,`+${pay} salvage each. Spend it at the stake. `+note);setTip('');
}
function startRaid(){
  if(game.pvp){startBattle();return}
  game.wave++;game.phase='raid';setTip('');closeArmory();
  if(blitz()&&game.wave>=finalWave()){game.bossShare=1;stormRaid();sfx('siren');game.flood={t:0,warned:false};if(campaign())startGauntlet();else startFinalBlitz();return}
  const k=Math.floor(waveEff()),Df=game.Df,P=Math.max(1,players.size),q=[];
  // a bigger crew mostly means more riflemen; grenadiers and breachers grow much more slowly
  const boss=bossOf(game.wave),boss2=boss&&N>16?bossPartner(game.wave):'',xb=boss?'':extraBoss(game.wave),xb2=xb?nightmareSecond(game.wave,xb):'',W=modWaveMix(waveMix(k,P,Df.extra,!!(boss||xb)),k);
  game.bossShare=boss2?XL_BOSS_SHARE:1;stormRaid();
  for(let n=0;n<W.rifle;n++)q.push('rifle');
  for(const t of['gren','fire','shield','medic','spotter','breach'])for(let n=0;n<W[t];n++)q.splice(1+Math.floor(rnd()*q.length),0,t);
  if(boss)q.splice(Math.max(2,Math.floor(q.length*.45)),0,'boss:'+boss);
  if(boss2)q.splice(Math.max(4,Math.floor(q.length*.62)),0,'boss:'+boss2);
  if(xb)q.splice(Math.max(2,Math.floor(q.length*.45)),0,'boss:'+xb+':sb');   // an in-between boss (Boss Rush, Nightmare): pays shards
  if(xb2)q.splice(Math.max(4,Math.floor(q.length*.7)),0,'boss:'+xb2+':sb2');   // v0.9.3.7 Nightmare + Boss Rush: a second one
  game.queue=q;game.spawnT=.8;game.spawnGap=Math.max(.5,1.1-.1*(P-1))*(N>16?.85:1);sfx('siren');game.flood={t:0,warned:false};
  const bits=[`${W.rifle} riflemen`];
  for(const t of['gren','breach','shield','medic','spotter','fire'])if(W[t])bits.push(`${W[t]} ${W[t]>1?ENAMES[t][1]:ENAMES[t][0]}`);
  const B=boss?bossInfo(boss):xb&&hasMod('bossrush')?bossInfo(xb):null,B2=boss2?bossInfo(boss2):null;   // Nightmare's surprise boss stays a surprise
  if(xb2)game.nmSecond=(game.nmSecond|0)+1;
  toastAll(B?`${raidName(game.wave)} · ${B2?'TWO BOSSES':'BOSS'}`:raidName(game.wave),`${bits.join(', ')}${B?(B2?', '+B.name+' and '+B2.name:' and '+B.name):''} coming ${(MAP||MAPS.yard).from}${todStage(game.wave)===2&&!(MAP&&MAP.night)?' in the dark':''}.`);
}
// Who comes in a raid. k is the raid's strength (raid number; in Endless it climbs faster), P the crew size.
// A bigger crew mostly means more riflemen. The four newer raiders each take a rifleman's place (riflemen never drop
// below about a third), so a raid gets harder through who is in it more than how many: firebrands from raid 2, shieldbearers from 3, medics from 4,
// spotters from 6. XL maps send about 40% more of everyone.
function waveMix(k,P,extra,boss){
  const W={rifle:Math.max(2,2+k+extra-(boss?2:0))+Math.round((P-1)*(1.5+k*.45)),
    gren:Math.max(0,k-1)+(k>=2?Math.floor((P-1)/3):0),
    breach:(k>=3?k-2+(extra>0?1:0):0)+(k>=3?Math.floor((P-1)/3):0),
    fire:k>=2?1+Math.floor((k-2)/3)+(P>=4?1:0):0,
    shield:k>=3?1+Math.floor((k-3)/3)+(P>=4?1:0):0,
    medic:k>=4?1+Math.floor((k-4)/4):0,
    spotter:k>=6?1+Math.floor((k-6)/5)+(P>=5?1:0):0};
  W.rifle=Math.max(2,Math.ceil(W.rifle*.35),W.rifle-W.fire-W.shield-W.medic-W.spotter);   // riflemen stay at least a third of the old count
  if(N>16)for(const t in W)W[t]=Math.round(W[t]*1.4);
  return W;
}
const ENAMES={rifle:['rifleman','riflemen'],gren:['grenadier','grenadiers'],breach:['breacher','breachers'],shield:['shieldbearer','shieldbearers'],
  medic:['field medic','field medics'],spotter:['spotter','spotters'],fire:['firebrand','firebrands']};
function startBattle(){
  if(game.pvp!=='base'||game.phase!=='build')return;
  game.phase='raid';game.timer=0;setTip('');sfx('siren');
  for(const p of players.values())p.sal+=10;game.wxT=0;
  toastAll('BATTLE','The truce is over. Knock down their stake, keep yours standing.');
}
function endPvp(winner){
  if(game.phase==='over')return;game.phase='over';game.winner=winner;bullets=[];lobs=[];rockets=[];fires=[];
  game.won=game.pvp==='base'?player.team===winner:player.id===winner;showOver();
}
function updatePvp(dt){
  stormTick(dt);suddenTick();
  if(game.phase==='build'){game.timer-=dt;if(game.timer<=0)startBattle()}
  else if(game.pvp==='ffa'){game.timer-=dt;if(game.timer<=0){let best=null;for(const p of players.values())if(!best||p.kills>best.kills||(p.kills===best.kills&&p.deaths<best.deaths))best=p;endPvp(best?best.id:'')}}
  else game.timer+=dt;
}
/* ---------- bosses ---------- */
// Every fifth raid in co-op has a boss in it (it replaces two riflemen; the raid isn't longer). Each boss is one
// entry here: stats, look, an intro line and a think() that runs its attacks. To add a boss, add an entry and
// put its key in a map's boss list (MAPS); the spawning, health bar, network sync and rewards all come for free.
// `box` is the case each player gets when it goes down (the October Butcher drops two).
const BOSSES={
  demolisher:{name:'THE DEMOLISHER',hp:620,speed:1.05,scan:9,bounty:40,col:'#ff8a3a',think:thinkDemolisher,
    look:{body:'#4b4a38',vest:'#23241c',pants:'#26241e',head:'#a98262',helmet:'#1f201a',pack:'#3a3a28',bandana:'#c8551e',gl:20,weapon:'rpg'},
    intro:'He fires slow rockets. A red line shows where the next one goes: step out of it.'},
  butcher:{name:'THE BUTCHER',hp:760,speed:2.05,scan:8,bounty:40,col:'#ff4a3a',think:thinkButcher,
    look:{body:'#5c1d18',vest:'#2a0c09',pants:'#221412',head:'#9c7456',helmet:'#3a0f0c',bandana:'#1a0a08',gl:14,weapon:'sword'},
    intro:'A blade and a temper. A red lane means he is about to charge down it: get out of the lane.',box:'halloween'},
  storm:{name:'THE STORMCALLER',hp:540,speed:1.2,scan:12.5,bounty:40,col:'#7fe0ff',think:thinkStorm,
    look:{body:'#26323f',vest:'#10171e',pants:'#1a2028',head:'#b0896a',boonie:'#1b2530',glow:'#7fe0ff',gl:20,weapon:'zap'},
    intro:'A lightning rifle that jumps between people. A blue line means a shot is coming: break line of sight, and spread out.'},
  ferryman:{name:'THE FERRYMAN',hp:700,speed:1.45,scan:10,bounty:40,col:'#5fd6c4',think:thinkFerryman,raft:true,box:'halloween',
    look:{body:'#34463f',vest:'#1d2925',pants:'#27302b',head:'#a58566',boonie:'#2b3630',bandana:'#1d2925',gl:22,weapon:'harpoon'},
    intro:'He works the river from a raft. A chain line means a harpoon: it drags whoever it hits (or a wall) toward the water. He lands boarding crews on the banks.'},
  foreman:{name:'THE FOREMAN',hp:760,speed:1.3,scan:9,bounty:40,col:'#ffb13a',think:thinkForeman,
    look:{body:'#5a4a2a',vest:'#e0a030',pants:'#3a3326',head:'#a98262',helmet:'#f0b830',pack:'#4a3a22',gl:14,weapon:'drill'},
    intro:'He drills under the ground where bullets can\'t reach. A dust trail and a rumble show where he\'s going: when it stops, he bursts up through whatever is on top.'}
};
const bossBox=k=>(BOSSES[k]||{}).box||'afterglow';
// name, colour and look for a boss, with the October look when it's on
function bossInfo(key){const B=BOSSES[key]||BOSSES.butcher,V=game.oct&&key==='butcher'?BOSS_VARIANTS.pumpkin:null;return V?{name:V.name,col:V.col,look:V.look,intro:B.intro}:B}
// seasonal looks for a boss: same fight, same telegraphs, a different outfit (and name)
const BOSS_VARIANTS={
  pumpkin:{boss:'butcher',name:'THE PUMPKIN BUTCHER',col:'#ff8a2a',
    look:{body:'#3a1f12',vest:'#1a0d07',pants:'#1e1410',head:'#9c7456',pumpkin:'#e8771e',pking:true,gl:14,weapon:'swordp'}}};

// each map has its own boss order (MAPS[..].bosses); the Yard's is the old default
const BOSS_ORDER=['butcher','demolisher','storm'];
const bossOf=w=>{if(campaign())return w<=12&&w%3===0?CAMPAIGN.bosses[w/3-1]:'';if(w%5!==0)return'';const L=(MAP&&MAP.bosses)||BOSS_ORDER,k=L[(w/5-1)%L.length];return blitz()?(w>=BLITZ.waves?'':blitzBoss(k)):k};
// XL boss raids bring a second boss: the next different one in the map's pool
const bossPartner=w=>{if(campaign())return'';const L=(MAP&&MAP.bosses)||BOSS_ORDER,i=(w/5-1)%L.length;for(let j=1;j<L.length;j++){const k=L[(i+j)%L.length];if(k!==L[i])return blitz()?blitzBoss(k):k}return''};
// enemy health: the map's multiplier (Yard 1, Riverbend 1.05, Quarry 1.1) and +10% on XL. Damage is never scaled.
const mapHp=()=>((MAP&&MAP.hp)||1)*(N>16?1.1:1);
const XL_BOSS_SHARE=.9;   // each of the two XL bosses has 90% of a normal boss's health
const ETYPES={rifle:{hp:36,speed:1.5},gren:{hp:46,speed:1.25},breach:{hp:30,speed:2.1},
  shield:{hp:66,speed:1.15},medic:{hp:34,speed:1.55},spotter:{hp:30,speed:1.45},fire:{hp:40,speed:1.4}};
// type codes for the network: never reorder, only add to the end
const ECODE=['rifle','gren','breach','boss:demolisher','boss:butcher','boss:storm','shield','medic','spotter','fire','boss:ferryman','boss:foreman'];
function spawnBoss(key,sb,second=false,fb=false,pos=null){
  if(key==='ferryman'&&!(game.lay&&game.lay.raftAt&&game.lay.raftAt.length))key='butcher';   // no river, no raft
  const B=BOSSES[key];if(!B)return;let x=0,y=0;
  const at=B.raft&&game.lay.raftAt&&game.lay.raftAt.length?game.lay.raftAt:(game.lay&&game.lay.bossAt)||[];
  for(let a=0;a<40&&at.length;a++){const t=at[Math.floor(rnd()*at.length)];if(!solidTile(t[0],t[1])){x=t[0]+.5;y=t[1]+.5;break}}
  if(!x){const t=spawnTile();if(t){x=t[0]+.5;y=t[1]+.5}else{x=N-.5;y=6.5}}
  if(pos){x=pos[0];y=pos[1]}   // v0.9.6.4: the gauntlet picks its own spots
  const P=Math.max(1,players.size),hp=B.hp*BOSS_HP*game.Df.hp*(1+.35*(P-1))*(1+.25*Math.floor(Math.max(0,game.wave-5)/15))*mapHp()*(game.bossShare||1)*(fb?(game.fb&&game.fb.gauntlet?GAUNTLET.hp:BLITZ.fbHp):1);
  const e={id:nextId++,type:'boss',boss:key,big:true,x,y,hp,max:hp,cd:2.2,walk:0,aim:{x:-1,y:0},flash:0,speed:B.speed,scanT:0,foe:null,planted:false,st:0,stT:0,stM:1,lx:x,ly:y,shots:0,ab:3,sw:0,sb:!!sb,fb:!!fb};
  if(B.raft){e.raft=true;e.ab=9;e.crews=0;e.pathT=0;e.next=-1}
  if(key==='foreman'){e.ab=5;e.cd=2.5}
  blitzSpawnFix(e,key);
  enemies.push(e);
  const I=bossInfo(key);sfx('horn');addShake(x,y,8);if(fb){if(game.fb&&game.fb.gauntlet)return;toastAll(`BLITZ · ${game.fb.n+1}/${game.fb.max} · ${I.name}`,B.intro);return}toastAll(second?'NIGHTMARE · SECOND BOSS · '+I.name:sb&&nightmare()&&!hasMod('bossrush')?'SURPRISE · '+I.name:I.name,B.intro);
}
function bossDown(e,own){
  const B=BOSSES[e.boss],I=bossInfo(e.boss),p=own&&own!=='dell'?players.get(own):null,share=p?15:20;game.bosses++;
  const oct=game.oct&&e.boss==='butcher'&&!e.sb;if(e.fb){if(game.fbLog.length<20)game.fbLog.push(e.boss);if(e.gw){game.gKill=game.gKill||[];game.gKill[e.gw-1]=(game.gKill[e.gw-1]|0)+1}}else if(e.sb){game.sbN=(game.sbN|0)+1;if(game.sbLog.length<100)game.sbLog.push(e.boss)}else game.bossLog.push(oct?'butcher_oct':e.boss);   // v0.9.4.0: Final Blitz bosses have their own list   // v0.9.3.8: in-between bosses are named too, for milestones
  for(const o of players.values())o.sal+=o===p?B.bounty:share;
  flt(e.x,e.y-.4,p?`+${B.bounty} SALVAGE`:`+${share} SALVAGE EACH`,'#e2b436');
  for(let n=0;n<26;n++)emit(e.x,e.y,WH*.8,n%2?'fire':'spark');addShake(e.x,e.y,11);sfx('bigboom',e.x,e.y);
  const bc=bossBox(e.boss),n=oct?2:B.cases||1,cn=e.fb?` +${n} ${CASES[bc].name.replace(' CASE',' Cases')} and 15-30 shards each, added when the run ends.`:e.sb?' +15-30 shards each, added when the run ends (or when you leave it).':CASES[bc]?` +${n} ${CASES[bc].name.replace(' CASE',n>1?' Cases':' Case')} each, added when the run ends (or when you leave it).`:'';
  toastAll(`${I.name} IS DOWN`,(p?`${p.name} landed it: +${B.bounty} salvage. Everyone else +${share}.`:`+${share} salvage each.`)+cn);
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
    const moveDt=dt*(1-(e.slowT>0?e.slowPct||0:0));
    for(let s=0;s<3&&!stop;s++){const nx=e.x+e.cvx*moveDt/3,ny=e.y+e.cvy*moveDt/3,i=Math.floor(nx),j=Math.floor(ny);
      if(!heightTravelClear(e.x,e.y,nx,ny)){stop=true;break}
      if(!inb(i,j)||(nodeAt(i,j)||{}).solid||terrSolid(terr[idx(i,j)])){stop=true;break}const k=idx(i,j);
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
  if(tgt&&heightDist(tgt.x,tgt.y,e.x,e.y)<1.35){aimAt(tgt.x,tgt.y);
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
  const a=Math.atan2(e.ly-e.y,e.lx-e.x),cx=Math.cos(a),cy=Math.sin(a),z0=heightAt(e.x,e.y)+.7,zs=(heightAt(e.lx,e.ly)+.7-z0)/Math.max(.5,Math.hypot(e.lx-e.x,e.ly-e.y));let x=e.x,y=e.y,hitA=null,last=-1;
  for(let d=.5;d<12.5;d+=.1){x=e.x+cx*d;y=e.y+cy*d;const i=Math.floor(x),j=Math.floor(y);if(!inb(i,j))break;const k=idx(i,j);
    const z=z0+zs*d;if(heightAt(x,y)>z-.05)break;
    if(coreKs.has(k)&&z<heightAt(x,y)+1.35){hurtStake(stakeAt(k),30*Df.dmg);break}
    if((nodeAt(i,j)||{}).solid||terrShot(terr[k]))break;
    const w=walls[k];if(w&&k!==last&&z<heightAt(x,y)+1.35){last=k;const m=w.mat;damageWall(k,m===0?95:40+60*MAT[m].bullet);if(m>0&&walls[k])break}
    for(const al of allies())if(al.alive&&Math.hypot(al.x-x,al.y-y)<.42&&Math.abs(heightAt(al.x,al.y)+.7-z)<.6){hitA=al;break}
    if(hitA)break}
  const pts=[e.x+cx*.5,e.y+cy*.5,hitA?hitA.x:x,hitA?hitA.y:y];
  if(hitA){hurtAlly(hitA,40*Df.dmg);stunAlly(hitA,.9);const done=new Set([hitA]);let from=hitA;
    for(let c=0;c<2;c++){let nb=null,nd=2.6;for(const o of allies())if(o.alive&&!done.has(o)){const d=dist2(o,from);if(d<nd){nd=d;nb=o}}
      if(!nb)break;done.add(nb);hurtAlly(nb,18*Df.dmg);stunAlly(nb,.5);pts.push(nb.x,nb.y);from=nb}}
  zapFx(pts);sfx('zap',x,y);addShake(x,y,7);addFlash({x,y,life:.2,max:.2,r:1.7});
  for(let n=0;n<8;n++)emit(x,y,WH*.6,'arc');
  return{x,y};
}
function stunAlly(a,t){if(a!==qm){a.stun=Math.max(a.stun||0,t);if(a.id)personal(a,'zap')}}
function zapFx(pts){rec(['z',...pts.map(r2)]);zaps.push({pts,life:.38,max:.38})}
function ringFx(x,y,r0,r1,life,c1,c2,w=2){rec(['o',r2(x),r2(y),r0,r1,life,c1,c2,w]);rings.push({x,y,r0,r1,life,max:life,c1,c2,w})}
function slashFx(x,y,ax,ay){rec(['w',r2(x),r2(y),r2(ax),r2(ay)]);slashes.push({x,y,ax,ay,life:.28,max:.28})}
// boss rockets: slow (4.2 tiles a second) so they can be seen and side-stepped
function updateRockets(dt){
  for(const r of rockets){const sp=Math.hypot(r.vx,r.vy),steps=Math.ceil(sp*dt/.12);
    for(let s=0;s<steps&&!r.dead;s++){const ox=r.x,oy=r.y;r.x+=r.vx*dt/steps;r.y+=r.vy*dt/steps;if(!heightTravelClear(ox,oy,r.x,r.y)){r.dead=true;explode(ox,oy,1.7,r.pw,r.own,!r.pl);break}r.d+=sp*dt/steps;
      const i=Math.floor(r.x),j=Math.floor(r.y);let hit=!inb(i,j)||r.d>r.max;
      if(!hit){const k=idx(i,j);hit=!!walls[k]||coreKs.has(k)||!!(nodeAt(i,j)||{}).solid||terrShot(terr[k])}
      if(!hit&&r.pl){for(const e of enemies)if(!e.dead&&!e.burrow&&Math.hypot(e.x-r.x,e.y-r.y)<(e.big?.6:.4)){hit=true;break}}   // a soldier's rocket: raiders
      else if(!hit)for(const a of allies())if(a.alive&&Math.hypot(a.x-r.x,a.y-r.y)<.45){hit=true;break}
      if(hit){r.dead=true;const bx=clamp(r.x-r.vx/sp*.2,.1,N-.1),by=clamp(r.y-r.vy/sp*.2,.1,N-.1);
        if(r.pl)explode(bx,by,ABIL.rocket.R,r.pw,r.own,false);else{explode(bx,by,1.7,r.pw,null,true);fires.push({x:bx,y:by,t:4,max:4,tick:.2})}}}}
  dropDead(rockets);
  for(const f of fires){f.t-=dt;f.tick-=dt;
    if(f.tick<=0){f.tick=.45;const R=f.r||.9;
      if(f.pl){for(const e of enemies)if(!e.dead&&!e.burrow&&groundReach(e.x,e.y,f.x,f.y,R))hurtEnemy(e,e.type==='boss'?5:9,f.own);continue}   // Molotov fire: raiders only, never your walls
      if(f.nap){napalmTick(f);continue}   // v0.9.4.0: the Arsonist's napalm
      for(const a of allies())if(a.alive&&groundReach(a.x,a.y,f.x,f.y,R))hurtAlly(a,6*game.Df.dmg);
      const w=walls[idx(Math.floor(f.x),Math.floor(f.y))];if(w&&w.mat===0&&!(w.fire>0))w.fire=hasMod('firestorm')?8:5}}
  fires=fires.filter(f=>f.t>0);
}
function spawnEnemy(type){
  if(type.startsWith('boss:')){const[,k,sb]=type.split(':');spawnBoss(k,sb==='sb'||sb==='sb2',sb==='sb2');return}
  const t=spawnTile();if(!t)return;spawnEnemyAt(type,t[0]+.5,t[1]+.5);
}
function spawnEnemyAt(type,x,y){
  const T=ETYPES[type]||ETYPES.rifle,s=(1+(game.mode==='endless'?.045:game.mode==='blitz'?.085:.07)*(game.wave-1))*game.Df.hp*mapHp();
  const e={id:nextId++,type,x,y,hp:T.hp*s,max:T.hp*s,cd:1+rnd(),walk:rnd()*6,aim:{x:-1,y:0},flash:0,speed:T.speed,scanT:0,foe:null,planted:false};
  if(type==='medic')e.ab=1.5;if(type==='spotter'){e.st=0;e.stT=0;e.stM=1;e.lx=x;e.ly=y}
  if(type==='shield')Object.assign(e,{shieldHitsMax:RIOT_SHIELD_HITS,shieldHitsLeft:RIOT_SHIELD_HITS,shieldBroken:false});
  enemies.push(e);return e;
}
function endGame(win,reason=''){
  if(game.phase==='over')return;
  game.endReason=reason;game.endDeadline=performance.now()+(reason==='deadend'?2100:0);
  game.phase='over';game.won=win;bullets=[];lobs=[];rockets=[];fires=[];
  if(demo){demoT=0;return}
  showOver();
}
function setStats(pairs){const rows=[...document.querySelectorAll('#over .stats>div')];rows.forEach((d,i)=>{const pr=pairs[i];d.hidden=!pr;if(pr){d.children[0].textContent=pr[0];d.children[1].textContent=pr[1]}})}
const COOP_STATS=['Raids survived','Raiders dropped','Walls raised','Walls lost','Repairs by Delgado','Revives'];
function showPvpOver(){
  const win=!!game.won,P=[...players.values()],me=player,S=game.stats;sfx(win?'win':'lose',undefined,undefined,true);
  $('overTitle').textContent=win?'VICTORY':'DEFEAT';$('overTitle').className=win?'':'lost';
  if(game.pvp==='base'){
    const wT=TEAMS[game.winner]||TEAMS.a,na=P.filter(p=>p.team==='a').length,nb=P.length-na;
    $('overEyebrow').textContent=`BASE BATTLE · ${na}V${nb} · ${wT.name} TOOK THE ${game.winner==='a'?'EAST':'WEST'} STAKE${game.mods.length?' · '+modNames(game.mods).join(' + '):''}`;
    $('overLede').textContent=win?'Their stake is splinters. Run it back and swap sides if it was lopsided.':'They got through. Look at which wall went first; that\'s where to put metal next time.';
    let tk=0,ek=0;for(const p of P)if(p.team===me.team)tk+=p.kills;else ek+=p.kills;
    setStats([['Your drops',me.kills|0],['Times you fell',me.deaths|0],[`${TEAMS[me.team].name} drops`,tk],[`${TEAMS[me.team==='a'?'b':'a'].name} drops`,ek],['Walls raised',S.built],['Walls lost',S.lost]]);
  }else{
    const rank=P.slice().sort((a,b)=>b.kills-a.kills||a.deaths-b.deaths),place=rank.indexOf(me)+1,lead=rank[0];
    $('overEyebrow').textContent=`FREE-FOR-ALL · ${P.length} PLAYERS · ${lead?lead.name.toUpperCase():''} WINS${game.mods.length?' · '+modNames(game.mods).join(' + '):''}`;
    $('overLede').textContent=rank.map((p,i)=>`${i+1}. ${p===me?'YOU':p.name.toUpperCase()} ${p.kills}`).join('   ');
    const ord=n=>n+(['th','st','nd','rd'][n%100>10&&n%100<14?0:Math.min(n%10,4)%4]||'th');
    setStats([['Your drops',me.kills|0],['Times you fell',me.deaths|0],['Place',`${ord(place)} of ${P.length}`],['Winning score',lead?`${lead.kills}`:'0']]);
  }
  const loot=game.rewarded?null:pvpReward(win,me.kills|0);game.rewarded=true;
  if(loot){$('overLoot').textContent=loot.text;$('overLoot').hidden=false;showRewards(loot)}else{$('overLoot').hidden=true;showRewards(null)}
  $('againBtn').hidden=NET.mode==='guest';$('overWait').hidden=NET.mode!=='guest';
  setTimeout(()=>{if(game.phase==='over')$('over').hidden=false},900);
}
function showOver(){closeGameSettings(false);
  if(game.pvp){showPvpOver();return}
  setStats(COOP_STATS.map(t=>[t,0]));
  const win=!!game.won;sfx(win?'win':'lose',undefined,undefined,true);
  $('overTitle').textContent=win?'CLAIM HELD':'CLAIM LOST';$('overTitle').className=win?'':'lost';
  const crew=players.size>1?` · CREW OF ${players.size}`:'',W=game.waves,endless=!isFinite(W);
  const res=blitzResult(player),held=win||res?W:game.endReason==='evacfail'?game.wave:Math.max(0,game.wave-1),S=game.stats;
  $('overEyebrow').textContent=`${player.C.name} · ${game.Df.name} · ${campaign()?'OPERATION WHITEOUT':endless?'ENDLESS':W+' RAIDS'}${crew} · ${win?`ALL ${W} RAIDS BROKEN`:endless?`${held} RAIDS HELD`:`STAKE FELL IN RAID ${game.wave}`}${game.mods.length?' · '+modNames(game.mods).join(' + '):''}`;
  if(game.endReason==='evacfail')$('overEyebrow').textContent=$('overEyebrow').textContent.replace(`STAKE FELL IN RAID ${game.wave}`,`EVAC FAILED · CHAPTER ${game.chapter+1}`);   // v0.9.6.4
  $('overLede').textContent=game.endReason==='evacfail'?`Nobody made the convoy out of ${MAP.name}. The campaign ends here.`:game.endReason==='deadend'?'The crew could not recover. No one left could get them back up.':win?'The stake is still standing. Try it with less wood and more nerve, or turn the threat up.':endless?`Endless only ends one way. ${held} raids is the number to beat.`:'They got to the core. Look at where they broke in. That hole is the lesson.';
  const loot=game.rewarded?null:lockerReward(held,win,player.kills|0);game.rewarded=true;
  if(res)blitzOverText(res,crew);   // v0.9.4.0: your own evacuation result
  if(loot){$('overLoot').textContent=loot.text;$('overLoot').hidden=false;showRewards(loot)}else{$('overLoot').hidden=true;showRewards(null)}
  $('sWaves').textContent=held;$('sDrop').textContent=S.dropped;$('sBuilt').textContent=S.built;$('sLost').textContent=S.lost;$('sRep').textContent=S.repairs;$('sRev').textContent=S.revives;
  if(NET.mode==='solo')saveBest(held,S.dropped);
  $('againBtn').hidden=NET.mode==='guest';$('overWait').hidden=NET.mode!=='guest';
  if(game.endReason==='deadend'){if(!res)$('overEyebrow').textContent=$('overEyebrow').textContent.replace(`STAKE FELL IN RAID ${game.wave}`,`CREW LOST IN RAID ${game.wave}`);showDeadEnd()}
  else{const run=game;setTimeout(()=>{if(game===run&&game.phase==='over')$('over').hidden=false},win?600:900)}
}
function togglePause(){
  if(dropOpen()){closeFriends();return}
  if(!$('igSet').hidden){closeGameSettings();return}   // pause/Escape from in-game settings goes back to the pause menu
  const open=$('pause').hidden;
  if(NET.mode==='solo')game.paused=open;
  $('pause').hidden=!open;$('pauseJobs').hidden=game.pvp!=='ffa';if(game.pvp==='ffa')syncJobPick();
  if(open)renderPauseCrew();
  $('pauseEyebrow').textContent=NET.mode!=='solo'?(game.pvp?'THE FIGHT DOESN’T PAUSE':'THE RAID DOESN’T PAUSE ONLINE'):`PAUSED · ${game.phase==='build'?'BUILD PHASE':raidName(game.wave)}`;
  $('pFriendsBtn').hidden=!socialAccount();renderFriendBadge();
  for(const s of[stickMove,stickAim]){s.id=null;s.vx=s.vy=s.mag=0}mouse.down=false;
}

// the Ferryman: rides a raft on the river. A chain line shows where the next harpoon goes; it drags the first
// person it hits (or the first wall) toward the water. Every so often he puts a boarding crew ashore. Below half
// health he rams a bridge, and that crossing is gone for the rest of the run.
const waterK=k=>terr[k]===T_WATER||terr[k]===T_BRIDGE;
function waterStep(from,goal){   // breadth-first along the river (under bridges too): the next tile toward goal
  if(from===goal)return goal;const prev=new Int16Array(N*N).fill(-1);prev[from]=from;const q=[from];
  for(let h=0;h<q.length;h++){const k=q[h];if(k===goal){let c=k;while(prev[c]!==from)c=prev[c];return c}
    const i=k%N,j=(k/N)|0;for(const[di,dj]of D4){const a=i+di,b=j+dj;if(!inb(a,b))continue;const nk=idx(a,b);if(prev[nk]!==-1||!waterK(nk))continue;prev[nk]=k;q.push(nk)}}
  return-1;
}
function nearestWater(x,y,bridgeOK){let best=-1,bd=1e9;for(let k=0;k<N*N;k++){if(!(terr[k]===T_WATER||(bridgeOK&&terr[k]===T_BRIDGE)))continue;const d=Math.hypot(k%N+.5-x,((k/N)|0)+.5-y);if(d<bd){bd=d;best=k}}return best}
function raftMove(e,dt,goalK){
  e.pathT-=dt;const here=idx(clamp(Math.floor(e.x),0,N-1),clamp(Math.floor(e.y),0,N-1));
  if(e.pathT<=0||e.next<0){e.pathT=.4;e.next=goalK>=0?waterStep(here,goalK):-1}
  if(e.next<0)return false;
  const tx=e.next%N+.5,ty=((e.next/N)|0)+.5,dx=tx-e.x,dy=ty-e.y,l=Math.hypot(dx,dy);
  if(l<.05){e.pathT=0;return e.next===goalK}
  const s=Math.min(l,e.speed*dt*(1-(e.slowT>0?e.slowPct||0:0)));e.x+=dx/l*s;e.y+=dy/l*s;e.walk+=dt*3;if(rnd()<dt*6)emit(e.x,e.y,2*u,'dust',0);
  return false;
}
function thinkFerryman(e,dt,tgt,mv,aimAt,Df){
  e.ab-=dt;
  if(e.st===1){e.stT-=dt;if(e.stT>.35&&e.foe&&e.foe.alive){e.lx=e.foe.x;e.ly=e.foe.y}aimAt(e.lx,e.ly);
    if(e.stT<=0){harpoon(e,Df);e.st=0;e.cd=e.rage?2.2:3.1}return{eng:true,mv:null}}
  if(e.st===3){e.stT-=dt;aimAt(e.lx,e.ly);   // going for a bridge
    const arrived=raftMove(e,dt,e.ramK);if(arrived||e.stT<=0)ramBridge(e);return{eng:true,mv:null}}
  if(!e.rammed&&e.hp<e.max*.5){const B=bridgeRows();if(B.length){
      let best=B[0],bd=1e9;for(const r of B){const d=Math.abs(r.j+.5-e.y);if(d<bd){bd=d;best=r}}
      e.rammed=true;e.st=3;e.stT=e.stM=7;e.ramRow=best.j;e.ramK=best.ks[best.ks.length>>1];e.lx=best.ks.reduce((a,k)=>a+k%N+.5,0)/best.ks.length;e.ly=best.j+.5;e.pathT=0;e.next=-1;
      sfx('horn',e.x,e.y);toastAll('THE FERRYMAN IS GOING FOR A BRIDGE','Get off it. When he hits it, that crossing is gone for good.');return{eng:true,mv:null}}
    e.rammed=true;e.rage=true}
  // boarding crews: two raiders ashore on the nearest bank (three with four or more players)
  if(e.ab<=0&&e.crews<5){e.ab=16;const bank=bankTile(e);if(bank){e.crews++;const P=players.size,crew=P>=4?['rifle','breach','rifle']:['rifle','breach'];
    crew.forEach((t,n)=>spawnEnemyAt(t,bank[0]+.5+(n-1)*.2,bank[1]+.5+(n%2)*.2));flt(bank[0]+.5,bank[1]+.2,'BOARDING PARTY','#5fd6c4');sfx('splash',bank[0]+.5,bank[1]+.5)}}
  const f=e.foe||nearestAlly(e);
  if(f&&e.cd<=0&&e.foe&&dist2(e.foe,e)<9){e.st=1;e.stT=e.stM=1.05;e.lx=e.foe.x;e.ly=e.foe.y;sfx('chain',e.x,e.y);return{eng:true,mv:null}}
  // keep level with whoever he's hunting, from the water
  const goal=f?nearestWater(f.x,f.y,false):nearestWater(core.i+.5,core.j+.5,false);raftMove(e,dt,goal);
  if(f)aimAt(f.x,f.y);
  return{eng:true,mv:null};
}
function nearestAlly(e){let b=null,bd=1e9;for(const a of allies())if(a.alive&&!(a.stl>0)){const d=dist2(a,e);if(d<bd){bd=d;b=a}}return b}
function bridgeRows(){const rows=new Map();for(let k=0;k<N*N;k++)if(terr[k]===T_BRIDGE){const j=(k/N)|0;if(!rows.has(j))rows.set(j,[]);rows.get(j).push(k)}return[...rows].map(([j,ks])=>({j,ks}))}
// a dry tile next to the water near the raft, preferring the stake's side of the river
function bankTile(e){let best=null,bs=1e9;const ei=Math.floor(e.x),ej=Math.floor(e.y);
  for(let j=ej-3;j<=ej+3;j++)for(let i=ei-3;i<=ei+3;i++){if(!inb(i,j)||solidTile(i,j)||walls[idx(i,j)]||waterK(idx(i,j)))continue;
    let wet=false;for(const[a,b]of D4)if(inb(i+a,j+b)&&waterK(idx(i+a,j+b)))wet=true;if(!wet)continue;
    const s=Math.hypot(i+.5-e.x,j+.5-e.y)+(i<e.x?0:1.5);if(s<bs){bs=s;best=[i,j]}}
  return best}
function harpoon(e,Df){
  const a=Math.atan2(e.ly-e.y,e.lx-e.x),cx=Math.cos(a),cy=Math.sin(a);let hit=null,wk=-1,end=9.5;
  for(let d=.6;d<9.5;d+=.1){const x=e.x+cx*d,y=e.y+cy*d,i=Math.floor(x),j=Math.floor(y);if(!inb(i,j)){end=d;break}const k=idx(i,j);
    if(coreKs.has(k)||(nodeAt(i,j)||{}).solid||terrShot(terr[k])){end=d;break}
    if(walls[k]&&walls[k].mat!==3){wk=k;end=d;break}
    for(const al of allies())if(al.alive&&Math.hypot(al.x-x,al.y-y)<.45){hit=al;break}
    if(hit){end=d;break}}
  const ex=e.x+cx*end,ey=e.y+cy*end;chainFx(e.x,e.y,ex,ey);sfx('harpoon',e.x,e.y);addShake(ex,ey,4);
  if(hit){hurtAlly(hit,18*Df.dmg);stunAlly(hit,.45);pullToward(hit,e.x,e.y,2.6)}
  else if(wk>=0)dragWall(wk,e.x,e.y);
}
// yank someone up to `max` tiles toward (tx,ty), stopping at anything solid and short of the raft itself
function pullToward(a,tx,ty,max){
  const d=Math.hypot(tx-a.x,ty-a.y),n=Math.min(max,d-.9);if(n<=0)return;const ux=(tx-a.x)/d,uy=(ty-a.y)/d,team=a===qm?true:pt(a);
  let moved=0;for(let s=.1;s<=n;s+=.1){const nx=a.x+ux*.1,ny=a.y+uy*.1;if(collides(nx,ny,.27,team))break;a.x=nx;a.y=ny;moved=s}
  if(moved>0&&a!==qm)a.tp++;
  for(let k=0;k<5;k++)emit(a.x,a.y,WH*.3,'dust',0);
}
// the harpoon catches a wall: it's dragged a tile toward the raft, or into the river and gone
function dragWall(k,tx,ty){
  const w=walls[k];if(!w)return;const i=k%N,j=(k/N)|0;let best=null,bd=Math.hypot(i+.5-tx,j+.5-ty);
  for(const[a,b]of D4){const ni=i+a,nj=j+b;if(!inb(ni,nj))continue;const d=Math.hypot(ni+.5-tx,nj+.5-ty);if(d<bd){bd=d;best=[ni,nj]}}
  if(!best){damageWall(k,90*MAT[w.mat].blast);return}
  const nk=idx(best[0],best[1]),busy=[...allies(),...enemies].some(o=>(o.alive===undefined||o.alive)&&Math.floor(o.x)===best[0]&&Math.floor(o.y)===best[1]);
  if(terr[nk]===T_WATER){walls[k]=null;debris[k]=0;game.stats.lost++;markFlow();sfx('splash',best[0]+.5,best[1]+.5);emitSpread(best[0]+.5,best[1]+.5,.8,0,WH*.4,'splinter',w.mat,10);flt(i+.5,j+.3,'INTO THE RIVER','#5fd6c4');return}
  if(walls[nk]||coreKs.has(nk)||nodeAt(best[0],best[1])||terrSolid(terr[nk])||busy){damageWall(k,90*MAT[w.mat].blast);return}
  walls[nk]=w;walls[k]=null;debris[k]=0;w.hp*=.85;w.flash=.1;w._spr=null;markFlow();sfx('collapse',i+.5,j+.5);emitSpread(i+.5,j+.5,.8,0,WH*.4,'dust',w.mat,8);
}
function ramBridge(e){
  const row=e.ramRow;e.st=0;e.rage=true;e.cd=1.5;let n=0;
  for(let i=0;i<N;i++){const k=idx(i,row);if(terr[k]!==T_BRIDGE)continue;n++;if(walls[k]){walls[k]=null;game.stats.lost++}debris[k]=0;setTerr(k,T_WATER);
    emitSpread(i+.5,row+.5,.9,0,WH*.5,'splinter',0,12)}
  if(n){sfx('collapse',e.x,e.y);sfx('splash',e.x,e.y);addShake(e.x,e.y,10);toastAll('A BRIDGE IS DOWN','That crossing is river now. He harpoons faster from here on.')}
}
function chainFx(x0,y0,x1,y1){rec(['C',r2(x0),r2(y0),r2(x1),r2(y1)]);chains.push({x0,y0,x1,y1,life:.45,max:.45})}
// the Foreman: a drill rig that burrows. Underground he can't be hit; a dust trail and a rumble show where he's
// going, and when it stops the ground swells for a moment before he bursts up, wrecking the wall above. On the
// surface he throws rock slabs (cover for you, or a wall in your way) and, below half health, brings a rockfall
// down a marked lane.
function thinkForeman(e,dt,tgt,mv,aimAt,Df){
  e.ab-=dt;const half=e.hp<e.max*.5;
  if(e.st===1){e.stT-=dt;aimAt(e.lx,e.ly);if(e.stT<=0){e.st=0;throwSlab(e,Df);e.cd=half?2.4:3.2}return{eng:true,mv:null}}
  if(e.st===2){e.stT-=dt;const dx=e.lx-e.x,dy=e.ly-e.y,l=Math.hypot(dx,dy);   // underground
    if(l>.12){const s=Math.min(l,2.6*dt);e.x=clamp(e.x+dx/l*s,.3,N-.3);e.y=clamp(e.y+dy/l*s,.3,N-.3);e.aim={x:dx/l,y:dy/l}}
    e.rum-=dt;if(e.rum<=0){e.rum=.8;sfx('rumble',e.x,e.y);addShake(e.x,e.y,2)}
    if(rnd()<dt*18)emit(e.x+(rnd()-.5)*.4,e.y+(rnd()-.5)*.4,2*u,'dust',1);
    if(l<=.12||e.stT<=0){e.st=4;e.stT=e.stM=.9;sfx('rumble',e.x,e.y)}
    return{eng:true,mv:null}}
  if(e.st===4){e.stT-=dt;if(rnd()<dt*30)emit(e.x+(rnd()-.5)*1.2,e.y+(rnd()-.5)*1.2,2*u,'dust',1);
    if(e.stT<=0){burstUp(e,Df);e.st=0;e.burrow=false;e.ab=half?7:9.5;e.cd=1}return{eng:true,mv:null}}
  if(e.st===3){e.stT-=dt;aimAt(e.lx,e.ly);if(e.stT<=0){rockfall(e,Df);e.st=0;e.cd=1.8;e.rf=6.5}return{eng:true,mv:null}}
  if(e.ab<=0){const t=burrowTarget(e);e.st=2;e.burrow=true;e.stT=e.stM=6.5;e.lx=t.x;e.ly=t.y;e.rum=0;sfx('drill',e.x,e.y);for(let n=0;n<10;n++)emit(e.x,e.y,4*u,'dust',1);return{eng:true,mv:null}}
  const f=e.foe;
  if(half){e.rf=(e.rf===undefined?1:e.rf)-dt;
    if(e.rf<=0&&f&&e.cd<=0){const a=aimAt(f.x,f.y);e.st=3;e.stT=e.stM=1.4;e.lx=clamp(e.x+Math.cos(a)*9,.2,N-.2);e.ly=clamp(e.y+Math.sin(a)*9,.2,N-.2);sfx('charge',e.x,e.y);return{eng:true,mv:null}}}
  if(f&&e.cd<=0&&dist2(f,e)<8){e.st=1;e.stT=e.stM=.85;e.lx=clamp(f.x,.3,N-.3);e.ly=clamp(f.y,.3,N-.3);sfx('lob',e.x,e.y);return{eng:true,mv:null}}
  if(tgt&&heightDist(tgt.x,tgt.y,e.x,e.y)<1.35){aimAt(tgt.x,tgt.y);
    if(e.cd<=0){e.cd=1;const k=idx(Math.floor(tgt.x),Math.floor(tgt.y));if(walls[k])damageWall(k,60*MAT[walls[k].mat].blast);else if(coreKs.has(k))hurtStake(stakeAt(k),20*Df.dmg);sfx('drill',e.x,e.y)}
    return{eng:true,mv:null}}
  if(f)aimAt(f.x,f.y);
  return{eng:!!(f&&dist2(f,e)<2.5),mv};
}
// where he comes up: the wall standing nearest the stake on his side, else under whoever is closest
function burrowTarget(e){
  let best=null,bs=1e9;
  for(let k=0;k<N*N;k++){const w=walls[k];if(!w||w.mat===3)continue;const i=k%N,j=(k/N)|0,dc=Math.hypot(i-core.i,j-core.j);if(dc>7)continue;
    const s=Math.hypot(i+.5-e.x,j+.5-e.y)+dc*.6;if(s<bs){bs=s;best={x:i+.5,y:j+.5}}}
  if(best)return best;const a=nearestAlly(e);return a?{x:a.x,y:a.y}:{x:core.i+1.5,y:core.j+.5};
}
function burstUp(e,Df){
  const i=Math.floor(e.x),j=Math.floor(e.y);
  for(let a=-1;a<=1;a++)for(let b=-1;b<=1;b++){const ni=i+a,nj=j+b;if(!inb(ni,nj))continue;const k=idx(ni,nj),w=walls[k];if(w)damageWall(k,(a||b?70:240)*MAT[w.mat].blast)}
  for(const c of cores)if(Math.hypot(c.i+.5-e.x,c.j+.5-e.y)<1.6)hurtStake(c,40*Df.dmg);
  for(const al of allies())if(al.alive){const d=Math.hypot(al.x-e.x,al.y-e.y);if(d<1.4){hurtAlly(al,30*Df.dmg);const l=d||1;moveEnt(al,(al.x-e.x)/l*.7,(al.y-e.y)/l*.7,al===qm?true:pt(al));if(al!==qm)al.tp++}}
  crackBlast(e.x,e.y,2.2,PIT_POWER);
  emitSpread(e.x,e.y,1.2,0,WH*.8,'chunk',1,18);for(let n=0;n<12;n++)emit(e.x,e.y,WH*.5,'dust',1);sfx('bigboom',e.x,e.y);addShake(e.x,e.y,10);
  if(solidTile(i,j,false)){for(const[a,b]of[[1,0],[0,1],[-1,0],[0,-1],[1,1],[-1,-1],[1,-1],[-1,1]])if(!solidTile(i+a,j+b,false)){e.x=i+a+.5;e.y=j+b+.5;break}}
}
// a rock slab: lands where the ring was; on open ground it stays as a stone block you can hide behind or break
function throwSlab(e,Df){const d=Math.hypot(e.lx-e.x,e.ly-e.y);lobs.push({x0:e.x,y0:e.y,x1:e.lx,y1:e.ly,t:0,T:.5+d*.07,R:.8,power:Df.dmg,k:2});sfx('lob',e.x,e.y)}
function slabLand(l){
  const i=Math.floor(l.x1),j=Math.floor(l.y1),k=idx(i,j);
  for(const al of allies())if(al.alive&&heightDist(al.x,al.y,l.x1,l.y1)<.8)hurtAlly(al,26*l.power);
  emitSpread(l.x1,l.y1,.8,0,WH*.4,'chunk',1,10);sfx('collapse',l.x1,l.y1);addShake(l.x1,l.y1,5);
  if(!inb(i,j))return;
  if(walls[k]){damageWall(k,90*MAT[walls[k].mat].blast);return}
  if(coreKs.has(k)||nodeAt(i,j)||terrSolid(terr[k])||terr[k]===T_WATER)return;
  const w=makeWall(1,false,.8);w.slab=true;walls[k]=w;markFlow();
  // nobody ends up inside it
  const out=o=>{if(Math.floor(o.x)!==i||Math.floor(o.y)!==j)return;for(const[a,b]of[[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,-1],[1,-1],[-1,1]])if(!solidTile(i+a,j+b)){o.x=i+a+.5;o.y=j+b+.5;if(o.tp!==undefined&&o!==qm)o.tp++;return}};
  for(const p of players.values())out(p);out(qm);for(const en of enemies)out(en);
}
function rockfall(e,Df){
  const dx=e.lx-e.x,dy=e.ly-e.y,L=Math.hypot(dx,dy)||1,hitA=new Set(),hitK=new Set();
  for(let d=.8;d<=L;d+=.45){const x=e.x+dx/L*d,y=e.y+dy/L*d,i=Math.floor(x),j=Math.floor(y);if(!inb(i,j))break;const k=idx(i,j);
    if(walls[k]&&!hitK.has(k)){hitK.add(k);damageWall(k,70*MAT[walls[k].mat].blast)}
    for(const al of allies())if(al.alive&&!hitA.has(al)&&Math.hypot(al.x-x,al.y-y)<.6){hitA.add(al);hurtAlly(al,34*Df.dmg)}
    if(terr[k]===T_CRACK&&rnd()<.5)makePit(k);
    emit(x,y,WH*1.6,'chunk',1);emit(x,y,WH*.3,'dust',1)}
  sfx('rockfall',e.x,e.y);addShake(e.x,e.y,8);
}
