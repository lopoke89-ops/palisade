/* ================= THE UNDERSTRIP: the mode (dev/plans/understrip-work-order.md) ================= */
// A co-op crawl under the Strip. Region 1 (M1): two levels and the Pit Boss's level, each built by usGenerate (06g) from the
// run's seed. No stake, no build phase, no gathering, no Delgado, no healing out of a fight: healing comes from Lucky Juice
// (charges refilled at Neon Shrines). Resting at a shrine sets where the squad comes back and brings the level's raiders
// back. A squad that's all down loses one of its shared lives and starts again at the last shrine; salvage you carried is
// left where you fell, for you to pick up (die again first and it's gone). Everyone alive in the lift's ring for 3 s goes down
// to the next level. The host runs all of it; guests build the same level from the same seed and read the rest from the
// snapshot (s.us).
const understrip=()=>!!game&&game.mode==='understrip'&&!game.pvp;
const US={rollCd:2,levels:3,   // rollCd: D5, the roll comes back in 2 s in this mode (3 s elsewhere; invulnerability unchanged)
  lives:3,regionLives:1,juice:3,juiceMax:6,drink:.8,heal:.45,drinkSlow:.4,exitR:1.6,exitHold:3,lift:5,wipe:2.6,bleed:20,
  restR:1.4,merchR:1.7,chestR:1.1,doorR:1.5,pickR:.85,restClear:8,
  sight:7.5,hear:3.2,shotHear:8,alertR:6,ambushR:2.6,regroupHp:.3,regroupT:4,maxAlive:40,
  flood:{first:[50,80],every:[75,115],warn:5,len:18},darkL:[.93,.86,.78,.66],zoom:.87};
const US_MUFFLE=650;   // Hz: the casino's music heard through concrete (region 1; work order 4.3)
const US_NAMES=['THE FLOOD TUNNELS · 1','THE FLOOD TUNNELS · 2','THE COUNT ROOM'];
const T_CONC=12,T_SHUT=13,T_JUNK=14;   // tunnel wall (solid, stops shots and sight), a shut door (the same until it opens), dumped junk (solid, bullets pass)
// the run being played (set before newGame by the host's start, a guest's start message, and each level change)
const US_RUN={seed:0,level:0};
let US_CUR=null;   // the generated level for US_RUN, and what usLay made of it
const usKind=lv=>lv>=US.levels-1?'boss':'normal';
function usLevel(){const key=US_RUN.seed+'|'+US_RUN.level;if(US_CUR&&US_CUR.key===key)return US_CUR.L;
  const kit=US_KITS[1],seed=usLevelSeed(US_RUN.seed,1,US_RUN.level+1),L=usGenerate(kit,seed,usKind(US_RUN.level));
  if(!L.ok)throw new Error('THE UNDERSTRIP: no level for seed '+seed);US_CUR={key,L};return L}
const usCell=c=>c==='#'||c==='%'?T_CONC:c==='o'?T_JUNK:c===','?T_LOW:c==='~'?T_WATER:c==='='?T_BRIDGE:c==='K'?T_SHUT:T_GROUND;
// the map entry (not in MAP_IDS: the mode chooses it)
MAPS.understrip={name:'THE FLOOD TUNNELS',short:'Tunnels',under:true,night:true,hp:1/1.1,   // hp: cancels the big-map +10% (mapHp), so the tables' health is what you fight
  col:'#7cff6b',from:'out of the dark',bosses:['pitboss'],
  blurb:'Flood tunnels under the Strip. Find the lift down.',lay(){return usLay()}};
let US_EDGE=new Uint8Array(0);   // tunnel wall tiles that face open ground (the only ones drawn standing)
function usLay(){
  const L=usLevel(),T=L.T,at=(x,y)=>[x+.5,y+.5];
  for(let y=0;y<T;y++)for(let x=0;x<T;x++)terr[y*T+x]=usCell(L.tiles[y][x]);
  US_EDGE=new Uint8Array(T*T);
  for(let y=0;y<T;y++)for(let x=0;x<T;x++){const k=y*T+x;if(terr[k]!==T_CONC)continue;
    for(let b=-1;b<=1;b++)for(let a=-1;a<=1;a++){const X=x+a,Y=y+b;if(X>=0&&Y>=0&&X<T&&Y<T&&!terrSolid(terr[Y*T+X]))US_EDGE[k]=1}}
  const M=L.marks,r=usRng(usHash(L.seed,77));
  // the shortcut doors: one per shortcut piece, opening from its side
  const doors=L.rooms.filter(q=>q.role==='shortcut').map(q=>({tiles:(M.K||[]).filter(([x,y])=>x>=q.x&&x<q.x+q.w&&y>=q.y&&y<q.y+q.h),side:q.opensFrom}));
  const arena=L.rooms.find(q=>q.role==='boss_arena'),inArena=p=>arena&&p[0]>=arena.x&&p[0]<arena.x+arena.w&&p[1]>=arena.y&&p[1]<arena.y+arena.h;
  const shrines=(M.S||[]).map(p=>({x:p[0]+.5,y:p[1]+.5,arena:!!inArena(p)}));
  const merchants=(M.M||[]).map((p,n)=>({x:p[0]+.5,y:p[1]+.5,stock:usStock(usRng(usHash(L.seed,500+n)))}));
  const chests=(M.C||[]).map((p,n)=>{const rr=usRng(usHash(L.seed,900+n));return{x:p[0]+.5,y:p[1]+.5,sal:15+Math.floor(rr()*16),item:rr()<.45?usPick(rr,['c_nade','c_flare','c_bar']):''}});
  const lay={under:true,us:L,core:M.P[0],starts:M.P.map(p=>at(p[0],p[1])),nodes:[],ruins:[],spawns:[{w:1,tiles:M.P.slice()}],bossAt:(M.B||[]).slice(),
    lamps:(M.L||[]).map(p=>at(p[0],p[1])),neon:(M.n||[]).map(p=>at(p[0],p[1])),exit:at(M.E[0][0],M.E[0][1]),shrines,merchants,chests,doors,
    gate:(M.G||[]).slice(),arena,raiders:usPopulate(L,r)};
  return lay;
}
// who waits where: decided by the level's seed, so every phone agrees (the host spawns them)
const US_MIX=[['rifle',48],['shield',12],['gren',12],['breach',9],['medic',7],['fire',7],['spotter',5]];
function usPopulate(L,r){
  const out=[],T=L.T,taken=new Set();let id=0;
  const floor=q=>{const f=[];for(let y=q.y+1;y<q.y+q.h-1;y++)for(let x=q.x+1;x<q.x+q.w-1;x++){const c=L.tiles[y][x];if(c==='.'||c===',')f.push([x,y])}return f};
  const type=()=>usWeighted(r,US_MIX,m=>m[1])[0];
  for(const q of L.rooms){
    if(['entrance','breather','exit','merchant','boss_ante','boss_arena'].includes(q.role))continue;
    const ambush=(L.marks.A||[]).filter(([x,y])=>x>=q.x&&x<q.x+q.w&&y>=q.y&&y<q.y+q.h);
    for(const a of ambush)if(r()<.75){taken.add(a[1]*T+a[0]);out.push({id:id++,type:r()<.8?'rifle':'shield',x:a[0]+.5,y:a[1]+.5,amb:1})}
    const n=q.role==='room'?(q.w>8||q.h>8?3+Math.floor(r()*3):1+Math.floor(r()*3)):q.role==='cache'?(r()<.5?1:0):q.role==='junction'?(r()<.7?1:0):r()<.4?1:0;
    const f=floor(q).filter(([x,y])=>!taken.has(y*T+x));
    const first=out.length;for(let k=0;k<n&&f.length;k++){const p=f.splice(Math.floor(r()*f.length),1)[0];taken.add(p[1]*T+p[0]);out.push({id:id++,type:type(),x:p[0]+.5,y:p[1]+.5,amb:0})}
    // one elite a room cluster (M2): a shieldbearer who charges, or a spotter who calls a mortar
    if(q.role==='room'&&out.length-first>=2&&r()<.6){const c=out.slice(first).find(s=>s.type==='shield'||s.type==='spotter')||out[first];if(c.type!=='shield'&&c.type!=='spotter')c.type=r()<.6?'shield':'spotter';c.elite=1}
  }
  return out.slice(0,US.maxAlive);
}

// ---------- the run ----------
// newGame calls this once the map and the players are set up
function usBegin(L,opt){
  game.phase='raid';game.timer=0;game.wave=1;game.waves=US.levels;game.queue=[];
  game.us={seed:US_RUN.seed,level:US_RUN.level,lives:opt.usLives??US.lives,exitT:0,lift:0,wipe:0,gate:0,flood:usFirstFlood(),floodT:0,
    rest:{x:L.starts[0][0],y:L.starts[0][1],ix:-1},lit:0,opened:0,chests:0,drops:[],flares:[],loot:[],eliteDown:[],left:L.merchants.map(m=>m.stock.map(s=>s.n)),
    stats:{kills:0,time:0,levelStart:0,falls:0,rests:0},log:[],alerted:new Set()};
  for(const p of players.values()){usKitOut(p,true);usRefit(p)}
  if(NET.mode!=='guest')usSpawnRaiders();
  MODE_ZOOM=1.15;setTimeout(()=>{if(resize())caches=null},0);   // 15% closer in (02-view)
  usToast(true);
}
const usFirstFlood=()=>US.flood.first[0]+rnd()*(US.flood.first[1]-US.flood.first[0]);
function usKitOut(p,fresh){if(fresh||p.uj===undefined){p.uj=US.juice;p.ujm=US.juice;p.ujT=0;p.ui={bar:0,flare:0};p.uSel='bar';p.w2=null;p.wSel=0;p.uPerks=[];p.uRelic='';p.breakUsed=false;p.ripT=0}}
function usToast(first){const U=game.us,boss=usKind(U.level)==='boss';
  toastAll(US_NAMES[U.level]||'THE UNDERSTRIP',boss?'The Pit Boss waits past the gate. Rest at the shrine before you go through.':first?'Find the freight lift down. Neon Shrines refill your Lucky Juice; raiders come back when you rest.':'Deeper. Find the next lift.')}
function usSpawnRaiders(){
  enemies=enemies.filter(e=>!e.us);   // gone, not killed: nobody is paid for them
  const L=game.lay,U=game.us,down=new Set((U&&U.eliteDown)||[]);for(const s of L.raiders){if(s.elite&&down.has(s.id))continue;const e=spawnEnemyAt(s.type,s.x,s.y);if(!e)continue;e.us={home:[s.x,s.y],st:s.amb?'ambush':'idle',sid:s.id,t:0,look:rnd()*6.28};
    if(s.elite)usMakeElite(e,usRng(usHash(L.us.seed,6000+s.id)))}
}
// the next level (host and guests alike; a guest calls it when the snapshot's level changes)
function usChangeLevel(lv,guest=false){
  const U=game.us;US_RUN.level=lv;const L=layMap('understrip',game.size,'');
  walls=new Array(N*N).fill(null);debris=new Int8Array(N*N);dist=new Float32Array(N*N);nodes=[];cores=[];coreKs=new Set();core={team:'',i:-9,j:-9,hp:1,max:1,flash:0};coreK=-1;
  game.lay=L;game.flood={t:0,warned:false};floodOn=false;floodLv=0;
  enemies=[];bullets=[];lobs=[];charges=[];rockets=[];fires=[];arcs=[];arcHaz.length=0;parts=[];flashes=[];floats=[];sacks=[];frostFields=[];
  let n=0;for(const p of players.values()){const s=L.starts[n++%L.starts.length];p.x=s[0];p.y=s[1];p.z=0;p.tp++;p.tx=p.x;p.ty=p.y;
    if(!p.alive){p.hp=p.max*(p.usDead?1:.25);p.alive=true;p.downed=false;p.usDead=false}p.ujT=0}
  Object.assign(U,{level:lv,exitT:0,lift:0,wipe:0,gate:0,flood:usFirstFlood(),floodT:0,rest:{x:L.starts[0][0],y:L.starts[0][1],ix:-1},lit:0,opened:0,chests:0,drops:[],flares:[],loot:[],eliteDown:[],
    left:L.merchants.map(m=>m.stock.map(s=>s.n))});U.alerted=new Set();
  US_FLOW.clear();caches=null;TERR_SPR.clear();computeFlow();flowDirty=false;NET.wlSent=null;NET.piSent=null;
  if(!guest){usSpawnRaiders();usToast(false)}
}
// host and solo, every frame of the mode (update's raid branch)
function usTick(dt){
  const U=game.us;U.stats.time+=dt;
  if(U.lift>0){U.lift-=dt;if(U.lift<=0)usChangeLevel(U.level+1);return true}   // in the lift: the world waits
  usFloodTick(dt);usFlowTick();usSteps(dt);
  for(const f of U.flares)f.t-=dt;U.flares=U.flares.filter(f=>f.t>0);
  for(const p of players.values()){usChargeTick(p,dt);if(p.ripT>0)p.ripT-=dt;if(p.compM!==undefined&&usMerchantAt(p)!==p.compM){const i=(p.uPerks||[]).indexOf('p_comped');if(i>=0)p.uPerks.splice(i,1);delete p.compM}}
  const crew=[...players.values()];
  // drinking: the heal lands when the drink is done
  for(const p of crew)if(p.ujT>0){p.ujT-=dt;if(p.ujT<=0){p.ujT=0;if(p.alive){const h=p.max*US.heal*usHealMul(p);p.hp=Math.min(p.max,p.hp+h);flt(p.x,p.y,`+${Math.round(h)}`,'#7cff6b');emit(p.x,p.y,WH*.6,'heal')}}}
  // salvage left where someone fell: theirs to pick up
  for(const p of crew)if(p.alive)for(let k=U.drops.length-1;k>=0;k--){const d=U.drops[k];if(d.id===p.id&&Math.hypot(d.x-p.x,d.y-p.y)<US.pickR){p.sal+=d.sal;U.drops.splice(k,1);flt(p.x,p.y,`+${d.sal} SALVAGE RECOVERED`,'#e2b436');personal(p,'restock')}}
  // chests open when you walk up to them
  game.lay.chests.forEach((c,n)=>{if(U.chests&(1<<n))return;for(const p of crew)if(p.alive&&Math.hypot(c.x-p.x,c.y-p.y)<US.chestR){U.chests|=1<<n;usOpenChest(p,c);break}});
  // the boss gate seals once someone is through
  if(game.lay.arena){usGateTick(dt);usBossTick()}
  // everyone down: the tunnels take the squad back to the last shrine (or end the run)
  if(!crew.some(p=>p.alive)){U.wipe+=dt;if(U.wipe>=US.wipe)usWipe();return false}U.wipe=0;
  // the lift: everyone standing in the ring for 3 s
  const ex=game.lay.exit,open=usKind(U.level)!=='boss'||U.bossDown,up=crew.filter(p=>p.alive);
  if(open&&up.length&&up.every(p=>Math.hypot(p.x-ex[0],p.y-ex[1])<US.exitR)){U.exitT+=dt;if(U.exitT>=US.exitHold)usLevelDone()}
  else U.exitT=Math.max(0,U.exitT-dt*2);
  return false;
}
function usLevelDone(){const U=game.us;U.exitT=0;
  const kills=[...players.values()].reduce((a,p)=>a+(p.kills|0),0)-(U.stats.killsAt|0);U.stats.killsAt=(U.stats.killsAt|0)+kills;
  const t=U.stats.time-U.stats.levelStart;U.stats.levelStart=U.stats.time;U.log.push([U.level,kills,Math.round(t)]);
  if(U.level>=US.levels-1){usFinish(true);return}
  U.lift=US.lift;sfx('horn');
  toastAll(`${US_NAMES[U.level]} · CLEARED`,`${kills} raiders dropped · ${Math.floor(t/60)}:${String(Math.round(t)%60).padStart(2,'0')} · the lift goes down.`);
  for(const p of players.values())if(!p.alive){p.alive=true;p.downed=false;p.usDead=false;p.hp=p.max*.25}   // the downed come along at 25%; the dead at the next start
}
function usFinish(win){const U=game.us;U.done=win?1:2;endGame(win,win?'understrip':'understrip-lost')}
function usWipe(){const U=game.us;U.wipe=0;U.stats.falls++;
  for(const p of players.values()){if(!p.usDead)usDrop(p);p.usDead=false}
  U.lives--;
  if(U.lives<0){usFinish(false);return}
  // back at the last shrine: everyone up, juice refilled, the level's raiders back, the boss (if he was fought) as new
  let n=0;for(const p of players.values()){const a=n++*2.1;p.x=U.rest.x+Math.cos(a)*.6*(n>1);p.y=U.rest.y+Math.sin(a)*.6*(n>1);if(solidTile(p.x|0,p.y|0)){p.x=U.rest.x;p.y=U.rest.y}
    p.tp++;p.alive=true;p.downed=false;p.hp=p.max;p.revive=0;p.ujT=0;p.uj=p.ujm;p.stun=0}
  bullets=[];lobs=[];charges=[];rockets=[];fires=[];
  usSpawnRaiders();usBossReset();
  toastAll('THE TUNNELS TAKE YOU',`${U.lives} ${U.lives===1?'life':'lives'} left. Back at the ${U.rest.ix>=0?'shrine':'lift'}; your salvage is where you fell.`);sfx('lose');
}
// a fall leaves that player's salvage on the floor (the one before it is gone)
function usDrop(p){const U=game.us;U.drops=U.drops.filter(d=>d.id!==p.id);const all=p.sal|0,s=usHas(p,'p_insure')?Math.ceil(all/2):all;if(s>0){U.drops.push({id:p.id,slot:p.slot|0,x:p.x,y:p.y,sal:s});p.sal=all-s}}
// hurtPlayer: down in the tunnels
function usDowned(p){
  const help=[...players.values()].some(o=>o!==p&&o.alive);
  p.dgE=-1;p.alive=false;p.downed=true;p.hp=0;p.revive=0;p.ujT=0;p.rt=help?US.bleed:1e6;p.deaths=(p.deaths|0)+1;
  if(usRelic(p,'x_hand')){for(const e of enemies)if(!e.dead&&Math.hypot(e.x-p.x,e.y-p.y)<2)hurtEnemy(e,60,p.id);explode(p.x,p.y,2,.6,p.id,true)}
  if(usHas(p,'p_break')&&!p.breakUsed){p.breakUsed=true;p.breakT=1.5}
  if(p.id===myId)buzz(80);sfx('drop',p.x,p.y);
  toastTo(p,'DOWN',help?`A teammate can get you up. ${US.bleed} seconds before you bleed out.`:'');
  if(players.size>1)flt(p.x,p.y,`${p.name.toUpperCase()} IS DOWN`,'#d65a3a');
}
// simPlayer, for someone down: bleeding out (the squad's wipe is usTick's)
function usDownTick(p,dt){if(p.usDead)return;if(p.breakT>0){p.breakT-=dt;if(p.breakT<=0){p.alive=true;p.downed=false;p.hp=p.max*.2;p.revive=0;flt(p.x,p.y,'LUCKY BREAK','#e2b436');sfx('revive',p.x,p.y)}return}p.rt-=dt;if(p.rt<=0){p.usDead=true;p.downed=false;usDrop(p);toastTo(p,'BLED OUT','You\'re back at the next shrine rest, or at the next level.');if(players.size>1)flt(p.x,p.y,`${p.name.toUpperCase()} BLED OUT`,'#9a8f7a')}}
const usHealMul=p=>usHealMulK(p);   // Big Gulp, the Cursed Chip, Dead Man's Hand

// ---------- drinking, items, the E key ----------
function usDrink(p){if(!p||!p.alive||p.ujT>0||!(p.uj>0)||p.hp>=p.max)return false;p.uj--;p.ujT=usHas(p,'p_sip')?.5:US.drink;sfx('medic',p.x,p.y);return true}
function localDrink(){const p=player;if(!understrip()||!p||!p.alive)return;if(!(p.uj>0)){toast('LUCKY JUICE','Empty. Rest at a Neon Shrine to refill.');return}if(p.hp>=p.max)return;
  if(NET.mode==='guest'){if(p.ujT<=0){NET.toHost({t:'ud'});p.ujT=US.drink}}else usDrink(p)}
function localSwap(to){const p=player;if(!understrip()||!p||!p.alive||!p.w2)return;const t=to===undefined?(p.wSel?0:1):to;if(t===p.wSel)return;
  if(NET.mode==='guest'){NET.toHost({t:'uw',to:t});usSwap(p,t)}else usSwap(p,t)}
// SPACE in the tunnels places the carried item you have selected (F switches)
function usItemSwap(){const p=player;if(p)p.uSel=p.uSel==='bar'?'flare':'bar'}
function localUseItem(){const p=player;if(!understrip()||!p||!p.alive)return;
  if(!(p.ui&&p.ui[p.uSel]>0)){toast(p.uSel==='bar'?'BARRICADE':'ROAD FLARE','You have none. The Tunnel Trader sells them.');return}
  const t=usItemTarget(p);if(!t.ok){toast(p.uSel==='bar'?'BARRICADE':'ROAD FLARE',t.why);return}
  if(NET.mode==='guest')NET.toHost({t:'uu',k:p.uSel,i:t.i,j:t.j});else usUseItem(p,p.uSel,t.i,t.j)}
function usItemTarget(p){if(p.uSel==='flare'){const d=2.4,x=clamp(p.x+p.aim.x*d,.5,N-.5),y=clamp(p.y+p.aim.y*d,.5,N-.5);return{ok:true,i:x|0,j:y|0}}
  const t=buildTarget(p,0,false),k=idx(t.i,t.j);if(!inb(t.i,t.j))return{ok:false,why:'Nothing to put it on'};
  if(solidTile(t.i,t.j)||walls[k])return{ok:false,why:'Something\'s in the way'};
  for(const o of players.values())if(o.alive&&(o.x|0)===t.i&&(o.y|0)===t.j)return{ok:false,why:'Someone\'s standing there'};
  return{ok:true,i:t.i,j:t.j}}
function usUseItem(p,k,i,j){if(!p.alive||!(p.ui[k]>0)||!inb(i,j)||Math.hypot(i+.5-p.x,j+.5-p.y)>3.2)return false;const kk=idx(i,j);
  if(k==='bar'){if(solidTile(i,j)||walls[kk])return false;const w=makeWall(0,true);w.hp=w.max=120;w.bar=true;walls[kk]=w;markFlow();sfx('place0',i+.5,j+.5)}
  else{game.us.flares.push({x:i+.5,y:j+.5,t:15});sfx('lob',i+.5,j+.5)}
  p.ui[k]--;return true}
// E: rest at a shrine, open a shortcut from its side, or trade
function usInteract(p,local){
  if(!p||!p.alive)return;const L=game.lay,U=game.us;
  {const l=usLootAt(p);if(l){if(NET.mode==='guest'&&local){NET.toHost({t:'ut',n:l.n});return}usTakeLoot(p,l.n);return}}
  const m=L.merchants.findIndex(q=>Math.hypot(q.x-p.x,q.y-p.y)<US.merchR);if(m>=0){if(local)openArmory();return}
  const s=L.shrines.findIndex(q=>Math.hypot(q.x-p.x,q.y-p.y)<US.restR&&(!q.arena||U.bossDown));
  if(s>=0){if(NET.mode==='guest'&&local){NET.toHost({t:'ui'});return}usRest(p,s);return}
  const d=L.doors.findIndex((q,n)=>!(U.opened&(1<<n))&&q.tiles.some(([x,y])=>Math.hypot(x+.5-p.x,y+.5-p.y)<US.doorR));
  if(d>=0){if(NET.mode==='guest'&&local){NET.toHost({t:'ui'});return}usDoor(p,d);return}
}
function usRest(p,s){const U=game.us,S=game.lay.shrines[s];
  if(enemies.some(e=>!e.dead&&Math.hypot(e.x-S.x,e.y-S.y)<US.restClear&&(e.type==='boss'||e.us&&e.us.st==='hunt'))){toastTo(p,'NEON SHRINE','Raiders are too close to rest.');return}
  U.rest={x:S.x,y:S.y,ix:s};U.lit|=1<<s;U.stats.rests++;
  for(const o of players.values()){if(!o.alive){o.alive=true;o.downed=false;o.usDead=false;o.x=S.x+(rnd()-.5);o.y=S.y+.6;o.tp++}o.hp=o.max;o.uj=o.ujm;o.ujT=0;o.revive=0;if(o.w2){o.w2.res=usReserveMax(o.w2,o);if(o.wSel===1)o.ammo=o.gun.mag;else o.w2.ammo=usWeaponGun(o.w2,o).mag}}
  usSpawnRaiders();sfx('revive',S.x,S.y);for(let n=0;n<10;n++)emit(S.x,S.y,WH*(.4+n*.06),'heal');
  toastAll('NEON SHRINE','Rested: Lucky Juice refilled, everyone back on their feet, and this is where you come back. The raiders are back too.')}
function usDoor(p,d){const U=game.us,D=game.lay.doors[d],cx=D.tiles.reduce((a,t)=>a+t[0]+.5,0)/D.tiles.length,cy=D.tiles.reduce((a,t)=>a+t[1]+.5,0)/D.tiles.length,s=US_STEP[D.side];
  if((p.x-cx)*s[0]+(p.y-cy)*s[1]<=0){toastTo(p,'SERVICE DOOR','Rusted shut. It won\'t budge from this side.');return}
  U.opened|=1<<d;for(const[x,y]of D.tiles)setTerr(idx(x,y),T_GROUND);sfx('collapse',cx,cy);addShake(cx,cy,3);
  toastAll('SHORTCUT','The service door is open: a quicker way back from the shrine.')}
function usOpenChest(p,c){const n=game.lay.chests.indexOf(c);usDropLoot(c.x,c.y+.6,usRollLoot(usRng(usHash(game.lay.us.seed,950+n)),'chest',1));sfx('gather',c.x,c.y);return;
  if(c.item){const k=c.item==='c_nade'?'nade':c.item==='c_flare'?'flare':'bar';if(k==='nade')p.nades=Math.min(p.maxN,p.nades+1);else p.ui[k]=Math.min(US_ITEMS[c.item].max,p.ui[k]+1);flt(c.x,c.y-.6,`+1 ${US_ITEMS[c.item].name}`,'#c8c3b8')}}

// ---------- the Tunnel Trader (dev/plans/understrip/tables/consumables.csv; the full table lands in M2) ----------
const US_ITEMS={c_nade:{name:'GRENADE',what:'+1 grenade',price:15,max:9},c_juice:{name:'SPARE JUICE',what:'Refills one Lucky Juice charge',price:40,max:9},
  c_bar:{name:'BARRICADE',what:'A one-tile barricade (120 HP). SPACE places it',price:25,max:2},c_flare:{name:'ROAD FLARE',what:'Lights 4 tiles round for 15 s. Select with F, SPACE throws',price:12,max:3}};
function usStock(r){const out=[{k:'c_nade',n:2+Math.floor(r()*3)},{k:'c_juice',n:1}];for(const k of usShuffle(r,['c_bar','c_flare']))if(r()<.8)out.push({k,n:1+Math.floor(r()*2)});return out.map(s=>({...s,price:US_ITEMS[s.k].price}))}
const usNearMerchant=p=>!!p&&!!game.lay&&!!game.lay.merchants&&game.lay.merchants.findIndex(q=>Math.hypot(q.x-p.x,q.y-p.y)<US.merchR);
function usMerchantAt(p){return game.lay&&game.lay.merchants?game.lay.merchants.findIndex(q=>Math.hypot(q.x-p.x,q.y-p.y)<US.merchR):-1}
const usPrice=(p,S)=>Math.round(S.price*(usRelic(p,'x_deck')?1.25:1)*(usHas(p,'p_comped')?.75:1));
function usBuy(p,m,si){const L=game.lay,U=game.us;if(!p||!p.alive||usMerchantAt(p)!==m)return false;const S=L.merchants[m].stock[si],deck=usRelic(p,'x_deck'),price=S?usPrice(p,S):0;if(!S||!(U.left[m][si]>0||deck)||p.sal<price)return false;
  const I=US_ITEMS[S.k];
  if(S.k==='c_nade'){if(p.nades>=p.maxN)return false;p.nades++}
  else if(S.k==='c_juice'){if(p.uj>=p.ujm)return false;p.uj++}
  else{const k=S.k==='c_bar'?'bar':'flare';if(p.ui[k]>=I.max)return false;p.ui[k]++}
  p.sal-=price;if(!deck)U.left[m][si]--;if(usHas(p,'p_comped'))p.compM=m;personal(p,'restock');return true}

// the trader's rows on the armory screen (renderArmory): what's left, what it costs, what it does
function usTradeRows(box,p){const m=usMerchantAt(p),L=game.lay,U=game.us;if(m<0)return;
  const h=document.createElement('div');h.className='arow usHead';const hb=document.createElement('b');hb.textContent='THE TUNNEL TRADER';const hi=document.createElement('i');hi.textContent='A casino cashier who never came back up. Stock runs out.';h.append(hb,hi);box.append(h);
  L.merchants[m].stock.forEach((S,si)=>{const I=US_ITEMS[S.k],left=U.left[m][si]|0,row=document.createElement('div');row.className='arow';
    const full=S.k==='c_nade'?p.nades>=p.maxN:S.k==='c_juice'?p.uj>=p.ujm:(p.ui[S.k==='c_bar'?'bar':'flare']|0)>=I.max;
    const b=document.createElement('b');b.textContent=I.name;const sm=document.createElement('small');sm.textContent=`${left} LEFT`;b.append(sm);
    const i=document.createElement('i');i.textContent=I.what;
    const btn=document.createElement('button');btn.type='button';btn.dataset.usBuy=si;btn.textContent=left<=0?'SOLD OUT':full?'FULL':S.price+' SAL';btn.disabled=left<=0||full||p.sal<S.price||!canShop(p);
    btn.setAttribute('aria-label',`${I.name}, ${I.what}, ${left} left, ${btn.textContent}`);
    btn.addEventListener('click',()=>{initAudio();if(NET.mode==='guest'){NET.toHost({t:'ub',m,s:si});btn.disabled=true}else if(usBuy(p,m,si))renderArmory()});
    const pips=document.createElement('div');pips.className='pips';row.append(b,btn,pips,i);box.append(row)})}

// ---------- raiders in the tunnels ----------
// idle and ambushing raiders wait where they were put; noise, sight or a hit sets them hunting the nearest of you, on that
// player's own flow field (rebuilt as you move, a couple a frame)
const US_FLOW=new Map();
function usFlowTick(){let n=0;for(const p of players.values()){if(!p.alive)continue;const k=idx(clamp(p.x|0,0,N-1),clamp(p.y|0,0,N-1));let F=US_FLOW.get(p.id);
  if(!F){F={k:-1,f:new Float32Array(N*N),t:0};US_FLOW.set(p.id,F)}
  if(F.f.length!==N*N)F.f=new Float32Array(N*N),F.k=-1;
  if((F.k!==k||flowDirty)&&game.time-F.t>.25&&n<2){const kk=coreK;coreK=k;try{flowTo(k,F.f)}finally{coreK=kk}F.k=k;F.t=game.time;n++}}}
// footsteps: hunting raiders on the move are heard, through walls, before they're seen (sfx muffles what's behind walls)
function usSteps(dt){let n=0;for(const e of enemies){if(!e.us||e.us.st!=='hunt'||e.dead)continue;const S=e.us;S.stepT=(S.stepT||0)-dt;
  if(S.stepT<=0&&n<3&&e.walk!==S.lastWalk){S.stepT=.42+rnd()*.12;S.lastWalk=e.walk;n++;sfx('step',e.x,e.y)}}}
function usAlert(e,why){if(!e.us||e.us.st==='hunt')return;e.us.st='hunt';e.us.t=0;sfx('mark',e.x,e.y);
  for(const o of enemies)if(o!==e&&o.us&&o.us.st!=='hunt'&&!o.dead&&Math.hypot(o.x-e.x,o.y-e.y)<US.alertR&&losClear(o.x,o.y,e.x,e.y)){o.us.st='hunt';o.us.t=0}}
// shots fired: raiders who hear them start hunting (called from shoot via usNoise)
function usNoise(x,y,r){if(!understrip())return;for(const e of enemies)if(e.us&&e.us.st==='idle'&&!e.dead&&Math.hypot(e.x-x,e.y-y)<r)usAlert(e,'noise')}
// updateEnemies, first thing for each tunnel raider: true = it's waiting this frame (skip the rest)
function usIdle(e,dt){const S=e.us;if(S.st==='hunt'||S.st==='regroup')return false;
  if(e.hp<e.max){usAlert(e,'hit');return false}
  for(const a of allies()){if(!seen(a))continue;const d=Math.hypot(a.x-e.x,a.y-e.y);
    if(S.st==='ambush'?d<US.ambushR:(d<US.hear||d<US.sight&&losClear(e.x,e.y,a.x,a.y))){usAlert(e,'seen');return false}}
  S.look+=dt*.35;e.aim={x:Math.cos(S.look),y:Math.sin(S.look)};e.cd=Math.max(e.cd,.6);return true}
// updateEnemies: a hunting raider treats its quarry's tile as "the core", on that player's flow field (as cityAim does for POIs)
function usAim(e){if(!e.us||!understrip())return false;const S=e.us;
  if(S.st==='regroup'){if(game.time>=S.until)S.st='hunt'}
  else if(e.hp<e.max*US.regroupHp&&e.type!=='medic'&&!S.regrouped){S.regrouped=true;S.st='regroup';S.until=game.time+US.regroupT}
  let best=null,bd=1e9;for(const p of players.values()){if(!p.alive)continue;const F=US_FLOW.get(p.id);if(!F||F.k<0)continue;const v=F.f[idx(e.x|0,e.y|0)];if(v<bd){bd=v;best={p,F}}}
  if(!best)return false;
  if(S.st==='regroup'){let m=null,md=1e9;for(const o of enemies)if(o!==e&&!o.dead&&o.us&&o.us.st==='hunt'){const d=Math.hypot(o.x-e.x,o.y-e.y);if(d<md){md=d;m=o}}
    if(m&&md>1.5){AIM.core=core;AIM.dist=dist;AIM.coreK=coreK;const fl=US_FLOW.get('rg'+e.id)||{f:new Float32Array(N*N),k:-1,t:0};US_FLOW.set('rg'+e.id,fl);
      const mk=idx(m.x|0,m.y|0);if(fl.k!==mk&&game.time-fl.t>.6){const kk=coreK;coreK=mk;try{flowTo(mk,fl.f)}finally{coreK=kk}fl.k=mk;fl.t=game.time}
      core={team:'',i:m.x|0,j:m.y|0,hp:1,max:1,flash:0};dist=fl.f;coreK=mk;return true}}
  AIM.core=core;AIM.dist=dist;AIM.coreK=coreK;core={team:'',i:best.p.x|0,j:best.p.y|0,hp:1,max:1,flash:0};dist=best.F.f;coreK=best.F.k;return true}
// a raider down: the level remembers it until the next rest (bosses and elites stay down; M2)
function usEnemyDown(e){if(!understrip())return;game.us.stats.kills++}

// ---------- the boss gate (the boss's own moves: 10i-understrip-bosses.js) ----------
function usGateTick(dt){if(game.us.bossDown)return;const U=game.us,A=game.lay.arena,inA=p=>p.x>=A.x+1&&p.x<A.x+A.w-1&&p.y>=A.y+1&&p.y<A.y+A.h-1;
  const crew=[...players.values()];
  if(U.gate===0&&crew.some(p=>p.alive&&inA(p))){U.gate=1;U.gateT=4;toastAll('THE GATE IS CLOSING','Four seconds: everyone through, or wait it out.');sfx('horn');usBossWake()}
  else if(U.gate===1){U.gateT-=dt;if(U.gateT<=0){U.gate=2;for(const[x,y]of game.lay.gate)setTerr(idx(x,y),T_SHUT);
    // the ones still standing outside are pulled through with the rest
    for(const p of crew)if(p.alive&&!inA(p)){p.x=A.x+A.w/2-.5+rnd();p.y=A.y+A.h-2.5;p.tp++}markFlow()}}
}
function usGateOpen(){const U=game.us;if(!U||!game.lay.gate)return;U.gate=0;for(const[x,y]of game.lay.gate)setTerr(idx(x,y),T_GROUND);markFlow()}

// ---------- flash floods (Riverbend's low ground, on a timer) ----------
function usFloodTick(dt){const U=game.us;if(U.gate===2)return;   // the arena keeps its own water
  U.flood-=dt;
  if(!U.floodOn&&U.flood<=US.flood.warn&&!U.floodWarned){U.floodWarned=true;toastAll('FLASH FLOOD','Water\'s coming down the tunnels. Get off the low ground.');sfx('flood')}
  if(!U.floodOn&&U.flood<=0){U.floodOn=true;U.flood=US.flood.len;floodOn=true;markFlow()}
  else if(U.floodOn&&U.flood<=0){U.floodOn=false;U.floodWarned=false;U.flood=US.flood.every[0]+rnd()*(US.flood.every[1]-US.flood.every[0]);floodOn=false;markFlow();toastAll('THE WATER DROPS','')}}

// ---------- the network (yard-31) ----------
const usPlayerBits=p=>(p.uj|0)|((p.ujm|0)<<3)|(((p.ui&&p.ui.bar)|0)<<6)|(((p.ui&&p.ui.flare)|0)<<8)|((p.ujT>0?1:0)<<10)|((p.usDead?1:0)<<11)|((p.uSel==='flare'?1:0)<<12);
function usReadBits(p,v){if(!Number.isInteger(v))return;p.uj=v&7;p.ujm=(v>>3)&7;p.ui={bar:(v>>6)&3,flare:(v>>8)&3};const drinking=(v>>10)&1;if(!drinking)p.ujT=0;else if(!(p.ujT>0))p.ujT=US.drink;p.usDead=!!((v>>11)&1);if(p!==player)p.uSel=(v>>12)&1?'flare':'bar'}
function usSnap(){const U=game.us;return[U.level,U.lives,r2(U.exitT),r2(U.lift),r2(U.wipe),U.gate|0,U.lit|0,U.opened|0,U.chests|0,U.floodOn?1:0,U.bossDown?1:0,U.rest.ix,
  U.drops.map(d=>[d.slot,r2(d.x),r2(d.y),d.sal]),U.flares.map(f=>[r2(f.x),r2(f.y),r2(f.t),f.r||4]),U.left,U.done|0,U.bossStage|0,(U.loot||[]).map(l=>[l.n,r2(l.x),r2(l.y),l.kind,l.kind==='weapon'?[l.w.id,l.w.r,l.w.mods]:l.kind==='salvage'?l.sal:l.k])]}
function usApplySnap(a){const U=game.us;if(!U||!Array.isArray(a))return;
  if(a[0]!==U.level&&Number.isInteger(a[0])&&a[0]>U.level&&a[0]<US.levels)usChangeLevel(a[0],true);
  [,U.lives,U.exitT,U.lift,U.wipe,U.gate,U.lit,U.opened,U.chests]=a;U.floodOn=!!a[9];floodOn=U.floodOn;U.bossDown=!!a[10];U.rest={...U.rest,ix:a[11]};
  const slot=s=>[...players.values()].find(p=>(p.slot|0)===s);
  U.drops=(a[12]||[]).map(([s,x,y,sal])=>({id:(slot(s)||{}).id,slot:s,x,y,sal}));U.flares=(a[13]||[]).map(([x,y,t,r])=>({x,y,t,r}));if(Array.isArray(a[14]))U.left=a[14];U.done=a[15]|0;U.bossStage=a[16]|0;
  U.loot=(a[17]||[]).map(([n,x,y,kind,v])=>kind==='weapon'?{n,x,y,kind,w:{id:v[0],r:v[1],mods:v[2]||[]}}:kind==='salvage'?{n,x,y,kind,sal:v}:{n,x,y,kind,k:v}).filter(l=>l.kind!=='weapon'||US_WEAPONS[l.w.id])}
function usHostData(p,d){
  if(d.t==='uw'){if(d.to===0||d.to===1)usSwap(p,d.to)}
  else if(d.t==='ut'){if(hostInt(d.n,0,1e6))usTakeLoot(p,d.n)}
  else if(d.t==='ud')usDrink(p);
  else if(d.t==='ui')usInteract(p,false);
  else if(d.t==='uu'){if((d.k==='bar'||d.k==='flare')&&hostInt(d.i,0,N-1)&&hostInt(d.j,0,N-1))usUseItem(p,d.k,d.i,d.j)}
  else if(d.t==='ub'){if(hostInt(d.m,0,8)&&hostInt(d.s,0,8))usBuy(p,d.m,d.s)}
}

// ---------- the HUD ----------
function usHudPhase(lab,host){const U=game.us,p=player,clock=t=>{const s=Math.max(0,Math.ceil(t));return`${Math.floor(s/60)}:${String(s%60).padStart(2,'0')}`};
  const boss=usKind(U.level)==='boss';
  txt(lab,W<700?(boss?'COUNT ROOM':`TUNNELS ${U.level+1}`):US_NAMES[U.level]);cls(lab,'raid',boss&&U.gate>0&&!U.bossDown);cls(lab,'evac',U.exitT>0||U.lift>0);
  const lives=`${Math.max(0,U.lives)} ${U.lives===1?'LIFE':'LIVES'}`;
  txt($('phaseVal'),U.lift>0?`the lift · ${Math.ceil(U.lift)}s`:U.wipe>0?'the tunnels take you…':U.exitT>0?`${lives} · in the lift ${Math.ceil(US.exitHold-U.exitT)}…`:boss&&!U.bossDown?`${lives} · ${U.gate?'the Pit Boss':'past the gate'}`:`${lives} · find the lift`);
  $('skipBtn').hidden=true;
  // the core meter carries Lucky Juice here
  txt($('coreL'),'JUICE');$('coreF').style.transform=`scaleX(${p.ujm?Math.max(0,p.uj/p.ujm):0})`;txt($('coreN'),`${p.uj|0}/${p.ujm|0}`);cls($('coreM'),'alarm',!(p.uj>0));$('coreF').style.background='#7cff6b'}
function usKitHud(p){const k=$('usKit');if(!k)return;usWeaponHud(p);
  txt($('usDrinkN'),p.ujT>0?'…':`${p.uj|0}`);cls($('usDrink'),'empty',!(p.uj>0));cls($('usDrink'),'on',p.ujT>0);
  const bar=p.uSel==='bar',n=p.ui?p.ui[p.uSel]|0:0;txt($('usItemLab'),bar?'BARRICADE':'FLARE');txt($('usItemN'),String(n));cls($('usUse'),'empty',!n);
  txt($('usOtherN'),String(p.ui?(bar?p.ui.flare:p.ui.bar)|0:0));txt($('usOtherLab'),bar?'FLARE':'BARRICADE')}
// what E does here (the kit's button label): TRADE, REST, DOOR, or nothing
function usUseHere(p){if(!p||!p.alive||!game.lay)return'';const L=game.lay,U=game.us;if(usMerchantAt(p)>=0)return'TRADE';
  if(L.shrines.some(q=>Math.hypot(q.x-p.x,q.y-p.y)<US.restR&&(!q.arena||U.bossDown)))return'REST';
  if(L.doors.some((q,n)=>!(U.opened&(1<<n))&&q.tiles.some(([x,y])=>Math.hypot(x+.5-p.x,y+.5-p.y)<US.doorR)))return'DOOR';return''}
// the floating prompts near a shrine, a merchant, a shortcut door and the lift (drawPrompts)
function usPrompts(p){if(!p.alive)return;const L=game.lay,U=game.us,E=ctl;if(usLootPrompt(p))return;
  const near=(q,r)=>Math.hypot(q.x-p.x,q.y-p.y)<r,say=(x,y,t,col)=>{const c=iso(x,y);label(t,c[0],c[1]-WH*1.9,col||'#e8e2d0',11)};
  if(usMerchantAt(p)>=0){const m=L.merchants[usMerchantAt(p)];say(m.x,m.y,E('TAP ARMORY · THE TUNNEL TRADER','E · THE TUNNEL TRADER',`${padKey('armory')} · THE TUNNEL TRADER`),'#c78bff');return}
  L.shrines.forEach((s,n)=>{if(near(s,US.restR+.4)&&(!s.arena||U.bossDown))say(s.x,s.y,U.rest.ix===n?E('TAP ARMORY · REST AGAIN','E · REST AGAIN',`${padKey('armory')} · REST AGAIN`):E('TAP ARMORY · REST AT THE SHRINE','E · REST AT THE SHRINE',`${padKey('armory')} · REST AT THE SHRINE`),'#ff5ad8')});
  L.doors.forEach((d,n)=>{if(U.opened&(1<<n))return;const t=d.tiles[0];if(Math.hypot(t[0]+.5-p.x,t[1]+.5-p.y)<US.doorR+.5)say(t[0]+.5,t[1]+.5,E('TAP ARMORY · SERVICE DOOR','E · SERVICE DOOR',`${padKey('armory')} · SERVICE DOOR`),'#ff9a3a')});
  for(const d of U.drops)if(d.id===p.id){const c=iso(d.x,d.y);label('YOUR SALVAGE · '+d.sal,c[0],c[1]-WH*1.2,'#e2b436',10)}
  const ex=L.exit;if(Math.hypot(ex[0]-p.x,ex[1]-p.y)<4)say(ex[0],ex[1],usKind(U.level)==='boss'&&!U.bossDown?'THE LIFT · DEAD':'THE LIFT · EVERYONE IN THE RING','#7cff6b')}
// the run's end screen (showOver hands over to this)
function usOver(){const U=game.us,win=!!game.won,me=player;sfx(win?'win':'lose',undefined,undefined,true);
  $('overTitle').textContent=win?'OUT OF THE COUNT ROOM':'THE TUNNELS KEPT YOU';$('overTitle').className=win?'':'lost';
  $('overEyebrow').textContent=`THE UNDERSTRIP · REGION 1 · ${players.size} ${players.size===1?'PLAYER':'PLAYERS'} · ${DIFF[pick.diff]?DIFF[pick.diff].name:''}`;
  $('overLede').textContent=win?'The Pit Boss is down and the way deeper is open. Shelter 7 is next (coming in M3).':`You reached ${US_NAMES[U.level]}. Rest at every shrine you find; it's where you come back.`;
  const t=Math.round(U.stats.time);setStats([['Deepest',`${U.level+1} of ${US.levels}`],['Raiders dropped',me.kills|0],['Times the squad fell',U.stats.falls],['Shrine rests',U.stats.rests],['Time',`${Math.floor(t/60)}:${String(t%60).padStart(2,'0')}`],['Lives left',Math.max(0,U.lives)]]);
  $('overLoot').hidden=true;if(typeof showRewards==='function')showRewards(null);game.rewarded=true;
  $('againBtn').hidden=NET.mode==='guest';$('overWait').hidden=NET.mode!=='guest';
  setTimeout(()=>{if(game.phase==='over')$('over').hidden=false},900)}
