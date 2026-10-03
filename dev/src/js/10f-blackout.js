/* ================= v0.9.7 City Black Out: the run ================= */
// 45 s to gather, then the eight POIs are hit one at a time (the four minors first, then the four majors, random within
// each group), 30 s apart. Each attack is a random boss and his own troops from the edge nearest the POI. The fight ends
// when the boss dies (held), the POI's structure falls (lost), or 60 s pass (the boss pulls back; held but damaged).
// Then 5 minutes at Main Command: a boss with troops every 30 s (at most 4 bosses up) and, for the last 2 minutes,
// THE SUPREME DESTROYER with shieldbearer and grenadier squads. Main Command standing at 0:00, or the Destroyer dead,
// wins; Main Command falling loses. Host (or solo) runs all of it; guests see it in snapshots.
const BO={gather:45,gap:30,cap:60,warn:15,warnNo:3,push:300,dest:120,every:30,squad:20,bossCap:4,minorHp:.05,repair:2,heal:3,healR:5,refill:30,highR:2.5};
const blackout=()=>!!game&&game.mode==='blackout'&&!game.pvp;
// every boss can show up, except the ones that need a river (no repeats in a row)
const boPool=()=>Object.keys(BOSSES).filter(k=>k!=='destroyer'&&!['ferryman','whiteferryman'].includes(k));
const boPOIs=()=>cores.filter(c=>c.poi);
const boHeld=perk=>{const c=cores.find(o=>o.poi&&o.poi.perk===perk);return!!c&&!c.lost};
const boCore=n=>cores[n];
function boStart(){
  const P=boPOIs(),idxOf=c=>cores.indexOf(c),sh=a=>{for(let i=a.length-1;i>0;i--){const j=Math.floor(rnd()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a};
  const order=[...sh(P.filter(c=>!c.poi.major).map(idxOf)),...sh(P.filter(c=>c.poi.major).map(idxOf))];
  game.bo={stage:'gather',t:0,order,n:0,cur:null,q:[],qT:0,warned:-1,last:'',held:0,lost:0,refT:BO.refill,push:null,destroyer:false,log:[]};
}
// the gathering (the build phase's clock): the first target is called out like any other
function boGather(){if(!game.bo)boStart();const B=game.bo,warn=boHeld('warn')?BO.warn:BO.warnNo;
  if(B.warned!==0&&game.timer<=warn){B.warned=0;const c=cores[B.order[0]];c.next=true;
    toastAll(`FIRST TARGET · ${c.poi.name}`,boHeld('warn')?`The Radio Tower picked it up: ${Math.ceil(game.timer)} seconds.`:'It\'s coming now.')}}
// the next attack starts now (t 0); gathering hands over with no gap
function boNext(){const B=game.bo;if(B.n>=B.order.length){boPush();return}
  const ci=B.order[B.n],c=cores[ci];B.stage='attack';B.t=0;B.n++;game.wave=B.n;
  let k;const pool=boPool();for(let a=0;a<8;a++){k=pool[Math.floor(rnd()*pool.length)];if(k!==B.last)break}B.last=k;
  const side=cityEdgeFor(c.i,c.j),edge=game.lay.edges[side],near=edge.filter(t=>Math.abs(side==='n'||side==='s'?t[0]-c.i:t[1]-c.j)<9);
  B.cur={ci,side,tiles:near.length?near:edge,boss:0,key:k};
  game.bossShare=1;spawnBoss(k,false,false,false,boEdgeSpot(B.cur.tiles));const e=enemies[enemies.length-1];
  if(e&&e.type==='boss'){e.poi=ci;B.cur.boss=e.id}
  // his troops: a raid's mix, stronger for the majors and later attacks
  const P=Math.max(1,players.size),W=waveMix(Math.round(2+B.n*.6+(c.poi.major?1:0)),P,game.Df.extra,true);
  const q=[];for(const t in W)for(let n=0;n<W[t];n++)q.push(t);B.q=sh2(q);B.qT=1;
  c.attack=true;sfx('siren');
  toastAll(`POI UNDER ATTACK · ${c.poi.name}`,`${bossInfo(k).name} and ${q.length} raiders are coming from the ${({n:'north',e:'east',s:'south',w:'west'})[side]}. Kill him to hold it.`);
}
const sh2=a=>{for(let i=a.length-1;i>0;i--){const j=Math.floor(rnd()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a};
function boEdgeSpot(tiles){for(let a=0;a<30;a++){const t=tiles[Math.floor(rnd()*tiles.length)];if(t&&!solidTile(t[0],t[1]))return[t[0]+.5,t[1]+.5]}const t=spawnTile();return t?[t[0]+.5,t[1]+.5]:[N/2,.5]}
// everyone on this attack (or all of them) pulls back: they vanish into the streets, no pay
function boRetreat(ci){for(const e of enemies)if(!e.dead&&(ci===undefined||e.poi===ci)){e.dead=true;for(let n=0;n<6;n++)emit(e.x,e.y,WH*.5,'smoke');if(e.type==='boss')flt(e.x,e.y-.4,`${bossInfo(e.boss).name} PULLS BACK`,'#d8cfb8')}}
function boEnd(how){const B=game.bo,cu=B.cur,c=cores[cu.ci];c.attack=false;B.cur=null;
  if(how==='lost'){c.lost=true;c.hp=0;c.lostAt=game.time;B.lost++;boLosePerk(c);explode(c.i+.5,c.j+.5,1.4,1);
    toastAll(`${c.poi.name} IS LOST`,`${c.poi.major?'Its perk is gone, and every final-push wave brings an extra squad.':'Its perk is gone, and final-push bosses get +5% health.'}`)}
  else{B.held++;toastAll(`${c.poi.name} HELD`,how==='retreat'?'He pulled back before you finished him. It keeps its damage; the quiet repairs it slowly.':'The boss is down. Patch it up before the next one.')}
  B.log.push([c.poi.id,how]);boRetreat(cu.ci);B.q=[];
  B.stage='gap';B.t=B.n>=B.order.length?BO.gap*.5:BO.gap;
}
function boLosePerk(c){const id=c.poi.perk;
  if(id==='lights'){game.dark=true;toastAll('THE POWER IS OUT','The streetlights are dead. The city is darker for the rest of the run.')}
  if(id==='wood'||id==='brick')for(const n of nodes)if(n.poi===c.poi.id)n.locked=true;
}
// the final push: 5 minutes at Main Command
function boPush(){const B=game.bo;B.stage='push';
  const lm=boPOIs().filter(c=>c.lost&&c.poi.major).length,ln=boPOIs().filter(c=>c.lost&&!c.poi.major).length;
  B.push={t:BO.push,n:0,squadT:0,xs:lm,hp:1+BO.minorHp*ln,side:0,dest:false};
  game.wave=9;sfx('siren');
  toastAll('THE FINAL PUSH',`Five minutes at Main Command. A boss every 30 seconds${lm?`, ${lm} extra squad${lm>1?'s':''} each wave`:''}${ln?`, bosses +${Math.round(ln*BO.minorHp*100)}% health`:''}. Hold it.`);
}
const BO_SIDES=['n','e','s','w'];
function boSquad(types){const B=game.bo,side=BO_SIDES[B.push.side++%4],tiles=game.lay.edges[side];
  for(const t of types){const s=boEdgeSpot(tiles);B.q.push([t,s])}}
function boPushTick(dt){
  const B=game.bo,F=B.push,P=Math.max(1,players.size);F.t=Math.max(0,F.t-dt);const el=BO.push-F.t;
  if(el<BO.push-BO.dest){   // 0:00-3:00: a boss and his troops every 30 s, at most 4 bosses up
    while(F.n*BO.every<=el&&F.n<6&&liveBosses()<BO.bossCap){let k;const pool=boPool();for(let a=0;a<8;a++){k=pool[Math.floor(rnd()*pool.length)];if(k!==B.last)break}B.last=k;
      game.bossShare=F.hp;spawnBoss(k,false,false,false,boEdgeSpot(game.lay.edges[BO_SIDES[F.side%4]]));game.bossShare=1;F.n++;
      const W=waveMix(5+F.n,P,game.Df.extra,true),q=[];for(const t in W)for(let n=0;n<Math.ceil(W[t]*.6);n++)q.push(t);boSquad(sh2(q));
      for(let x=0;x<F.xs;x++)boSquad(['rifle','rifle','gren','shield'])}
  }else{
    if(!F.dest){F.dest=true;F.squadT=0;B.q=[];spawnDestroyer()}   // the last 2 minutes: only his own squads come
    F.squadT-=dt;if(F.squadT<=0){F.squadT=BO.squad;const q=[];for(let n=0;n<2+P;n++)q.push(n%2?'gren':'shield');boSquad(q);for(let x=0;x<F.xs;x++)boSquad(['shield','gren','shield'])}
  }
  if(F.dest&&B.destId&&!enemies.some(e=>e.id===B.destId&&!e.dead)){B.destroyer=true;boWin();return}   // he's down: the run ends at once
  if(F.t<=0)boWin();
}
// until the Destroyer has his own entry (BOSSES.destroyer), the strongest boss stands in for him
function spawnDestroyer(){const k=BOSSES.destroyer?'destroyer':'bulldozer';game.bossShare=BOSSES.destroyer?1:4;spawnBoss(k,false,false,false,boEdgeSpot(game.lay.edges[BO_SIDES[game.bo.push.side%4]]));game.bossShare=1;
  const e=enemies[enemies.length-1];if(e&&e.type==='boss'){e.dest=true;game.bo.destId=e.id}}
function boWin(){const B=game.bo;if(B.stage==='done')return;B.stage='done';boRetreat();endGame(true)}
function boTick(dt){
  const B=game.bo;if(!B||B.stage==='done'||game.phase!=='raid')return;
  // queued troops come in a little apart, at their own spot
  if(B.q.length){B.qT-=dt;if(B.qT<=0){B.qT=Math.max(.35,.9-.08*players.size);const x=B.q.shift();
    if(Array.isArray(x)){const e=spawnEnemyAt(x[0],x[1][0],x[1][1]);if(e)e.push=true}
    else if(B.cur){const s=boEdgeSpot(B.cur.tiles),e=spawnEnemyAt(x,s[0],s[1]);if(e)e.poi=B.cur.ci}}}
  boPerks(dt);
  if(B.stage==='push'){boPushTick(dt);return}
  if(B.stage==='attack'){B.t+=dt;const c=cores[B.cur.ci],boss=enemies.find(e=>e.id===B.cur.boss&&!e.dead);
    if(c.hp<=0)boEnd('lost');else if(!boss)boEnd('held');else if(B.t>=BO.cap)boEnd('retreat');return}
  // the quiet: POIs mend slowly, and the next one is called out (15 s ahead with the Radio Tower, else 3 s)
  B.t-=dt;for(const c of boPOIs())if(!c.lost&&c.hp<c.max)c.hp=Math.min(c.max,c.hp+BO.repair*dt);
  const warn=boHeld('warn')?BO.warn:BO.warnNo;
  if(B.n<B.order.length&&B.t<=warn&&B.warned!==B.n){B.warned=B.n;const c=cores[B.order[B.n]];c.next=true;
    toastAll(`NEXT · ${c.poi.name}`,boHeld('warn')?`The Radio Tower picked it up: ${Math.ceil(B.t)} seconds.`:'No radio. It\'s coming now.')}
  if(B.t<=0){for(const c of cores)c.next=false;boNext()}
}
/* ---------- perks ---------- */
function boPerks(dt){
  const B=game.bo;
  const H=cores.find(c=>c.poi&&c.poi.perk==='heal');
  if(H&&!H.lost)for(const p of players.values())if(p.alive&&p.hp<p.max&&Math.hypot(p.x-H.i-.5,p.y-H.j-.5)<BO.healR)p.hp=Math.min(p.max,p.hp+BO.heal*dt);
  B.refT-=dt;if(B.refT<=0){B.refT=BO.refill;if(boHeld('refill')){for(const p of players.values()){if(p.nades<p.maxN)p.nades++;if(p.cls==='soldier')p.rk=Math.min(abilRockets(p),(p.rk|0)+1)}flt(player.x,player.y-.5,'+1 GRENADE · ARMORY DEPOT','#e2b436')}}
}
// downed teammates near a held Hospital get up 50% faster
const boReviveMul=p=>{if(!blackout())return 1;const H=cores.find(c=>c.poi&&c.poi.perk==='heal');return H&&!H.lost&&Math.hypot(p.x-H.i-.5,p.y-H.j-.5)<BO.healR?1.5:1};
// +25% salvage from kills near a held Gas Station
const boSalvage=e=>{if(!blackout())return 1;const G=cores.find(c=>c.poi&&c.poi.perk==='salvage');return G&&!G.lost&&Math.hypot(e.x-G.i-.5,e.y-G.j-.5)<8?1.25:1};
// high ground: +2 tiles of range on the Parking Garage's deck while it holds
const boHigh=p=>{if(!blackout()||!p)return false;const G=cores.find(c=>c.poi&&c.poi.perk==='range');return!!G&&!G.lost&&Math.hypot(p.x-G.i-.5,p.y-G.j-.5)<BO.highR};

/* ---------- who a raider is after ---------- */
// raiders on a POI attack walk that POI's own flow field and treat it as "the core" while they think
const POI_FLOW=[];let poiFlowDirty=true;
function poiFlowsDirty(){poiFlowDirty=true}
function poiFlow(ci){if(poiFlowDirty){POI_FLOW.length=0;poiFlowDirty=false}
  let f=POI_FLOW[ci];if(f&&f.length===N*N)return f;f=new Float32Array(N*N);const c=cores[ci],kk=coreK;coreK=idx(c.i,c.j);try{flowTo(coreK,f)}finally{coreK=kk}POI_FLOW[ci]=f;return f}
const AIM={core:null,dist:null,coreK:-1};
function cityAim(e){if(e.poi===undefined||!cores[e.poi]||cores[e.poi].lost)return false;
  AIM.core=core;AIM.dist=dist;AIM.coreK=coreK;const f=poiFlow(e.poi);core=cores[e.poi];dist=f;coreK=idx(core.i,core.j);return true}
function cityAimEnd(){core=AIM.core;dist=AIM.dist;coreK=AIM.coreK}
