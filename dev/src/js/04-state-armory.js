/* ================= state ================= */
let walls,debris,nodes,core,coreK,cores=[],coreKs=new Set(),player,qm,enemies,bullets,lobs,charges,parts=[],flashes=[],floats=[],sacks,dist,flowDirty=true,flowT=0;
let rockets=[],fires=[],zaps=[],slashes=[],rings=[];   // boss rockets, burning ground, lightning and blade arcs
let players=new Map(),myId='solo',nextId=1;   // every soldier in the yard; `player` is the one on this phone
let game={phase:'title',paused:false,time:0,wave:0,sel:0,piece:'wall',stats:{dropped:0,built:0,lost:0,repairs:0,revives:0}};
let pick={cls:'soldier',diff:'normal',mode:'5',pvp:'coop'};
let demo=false,demoT=0,demoAcc=0;   // the menu's live background: Dell alone against demo raids
const cfg={volume:.8,music:.7,shake:1,haptics:true,fps:false,name:'',build:true};
try{Object.assign(cfg,JSON.parse(localStorage.getItem('palisade.cfg.v1')||'{}'))}catch(e){}
function saveCfg(){try{localStorage.setItem('palisade.cfg.v1',JSON.stringify(cfg))}catch(e){}}
const light={L:.12,r:28,g:34,b:44,warm:0};
function wallState(w){const r=w.hp/w.max;return r>.66?0:r>.33?1:2}
const allies=()=>game.pvp?[...players.values()]:[...players.values(),qm];
// who can hurt whom, and which doors let you through
const pt=p=>game.pvp==='base'?p.team:true;
const rivals=(a,b)=>!!game.pvp&&a!==b&&(game.pvp==='ffa'||a.team!==b.team);
const teamCol=p=>game.pvp==='base'&&TEAMS[p.team]?TEAMS[p.team].col:game.pvp==='ffa'?'#e0664a':SLOTCOL[p.slot%6];
const stakeOf=p=>game.pvp==='base'?cores[p.team==='b'?1:0]:core;
const stakeAt=k=>{for(const c of cores)if(idx(c.i,c.j)===k)return c;return null};
// the targets your crosshair and aim assist care about: raiders in co-op, rival players in PvP
function foes(){if(!game.pvp)return enemies;const o=[];for(const q of players.values())if(q.alive&&!(q.prot>0)&&rivals(player,q))o.push(q);return o}
function makeWall(mat,door,ratio=1){const hp=MAT[mat].hp*(door?.85:1);return{mat,door:!!door,hp:hp*ratio,max:hp,fire:0,char:0,flash:0,skip:0}}
const SPAWNS=[[5.5,11.5],[5.5,12.5],[3.5,12.5],[4.5,12.5],[5.5,10.5],[3.5,10.5]];
function makePlayer(id,name,cls,slot,cos,team){
  if(!CLASSES[cls])cls='soldier';const C=CLASSES[cls],[x,y]=SPAWNS[slot%SPAWNS.length];
  const p={id,name,cls,slot,x,y,hp:C.hp,max:C.hp,alive:true,downed:false,rt:0,revive:0,aim:{x:.7,y:-.7},face:{x:.7,y:-.7},moveDir:{x:.7,y:-.7},
    cd:0,bcd:0,gt:0,ncd:0,mats:[24,0,0],cap:C.cap.slice(),nades:C.nades,maxN:C.nades,hurt:9,walk:0,flash:0,C,tp:0,fireIn:false,
    sal:0,kills:0,deaths:0,prot:0,team:team==='b'?'b':team==='a'?'a':'',up:{d:0,r:0,g:0,a:0,n:0},upS:'00000',cos:parseCos(cos),cosS:''};
  p.cosS=cosStr(p.cos);refit(p);return p;
}
/* ---------- armory: salvage buys upgrades between raids ---------- */
const UPG=[
  {k:'d',name:'DAMAGE',what:'+20% bullet damage per level',cost:[20,45,80,130]},
  {k:'r',name:'FIRE RATE',what:'Shoots 10% faster per level',cost:[20,45,80,130]},
  {k:'g',name:'RANGE',what:'+12% reach and bullet speed per level',cost:[15,35,60,100]},
  {k:'a',name:'ARMOR',what:'+15% max health per level',cost:[20,45,80,130]},
  {k:'n',name:'GRENADES',what:'+1 grenade each raid, bigger blasts',cost:[15,35,60,100]}];
// co-op / Endless only. Dell's level is shared by the whole crew; anyone can buy the next one.
// +15% damage, range and fire rate per level, added (not multiplied): level 4 = +60% each.
const DELL_UP={name:'DELL',what:'+15% damage, range and fire rate per level. Shared by the whole crew.',cost:[30,60,100,150]};
// the core doesn't heal on its own: 25 salvage (13 for the quartermaster) buys back up to 50 health
const CORE_FIX={hp:50,cost:25};
const coreFixCost=p=>Math.ceil(CORE_FIX.cost*(p.C.repair||1));
const BOUNTY={rifle:4,gren:7,breach:6};
function refit(p){
  const G=p.C.gun,U=p.up;
  p.gun=Object.assign({},G,{dmg:G.dmg*(1+.2*U.d),cd:G.cd*(1-.1*U.r),range:G.range*(1+.12*U.g),speed:G.speed*(1+.1*U.g)});
  const mx=Math.round(p.C.hp*(1+.15*U.a));if(mx>p.max)p.hp+=mx-p.max;p.max=mx;
  p.maxN=p.C.nades+U.n;p.blast=p.C.blast*(1+.08*U.n);
}
// burst carbine: 3/5/7/9/9 bullets at DAMAGE level 0-4; the pause after a burst is 0.40 s, 0.05 s shorter per level, never under 0.20 s
const BURST_N=[3,5,7,9,9],burstN=p=>BURST_N[Math.min(4,p.up.d|0)],burstGap=p=>Math.max(.2,.4-.05*(p.up.d|0));
const upStr=p=>UPG.map(x=>p.up[x.k]).join('');
const nearStake=p=>{const c=stakeOf(p);return!!c&&Math.hypot(p.x-(c.i+.5),p.y-(c.j+.5))<2.7};
const shopOpen=p=>!!p&&p.alive&&(game.pvp==='base'?game.phase!=='over':!game.pvp&&game.phase==='build');
const canShop=p=>shopOpen(p)&&nearStake(p);
function buyUpgrade(p,k){
  if(k==='core')return repairCore(p);
  if(k==='dell')return buyDell(p);
  const U=UPG.find(x=>x.k===k);if(!U||!canShop(p))return false;const t=p.up[k];if(t>=4||p.sal<U.cost[t])return false;
  p.sal-=U.cost[t];p.up[k]=t+1;p.upS=upStr(p);refit(p);if(k==='n')p.nades=Math.max(p.nades,p.maxN);
  personal(p,'restock');return true;
}
function repairCore(p){
  const c=cores[0],cost=coreFixCost(p);
  if(game.pvp||!canShop(p)||!c||c.hp<=0||c.hp>=c.max||p.sal<cost)return false;   // full core: nothing to buy, nothing charged
  const add=Math.min(CORE_FIX.hp,c.max-c.hp);p.sal-=cost;c.hp+=add;
  flt(c.i+.5,c.j+.5,`+${Math.round(add)} CORE`,'#8fe0a0');emit(c.i+.5,c.j+.5,WH*.6,'heal');personal(p,'restock');return true;
}
function buyDell(p){
  const L=game.dellLv|0;
  if(game.pvp||!canShop(p)||L>=4||p.sal<DELL_UP.cost[L])return false;
  p.sal-=DELL_UP.cost[L];game.dellLv=L+1;
  toastAll(`DELL · LEVEL ${L+1}`,`${p.name} upgraded Dell's shotgun: +${15*(L+1)}% damage, range and fire rate.`);personal(p,'restock');return true;
}
// who gets paid for a kill; bullets and grenades remember whose they were
function award(own,e){
  if(demo)return;
  if(own==='dell'){for(const p of players.values())p.sal+=1;return}
  const p=players.get(own);if(!p)return;
  const v=BOUNTY[e.type]||4;p.sal+=v;p.kills++;flt(e.x,e.y-.2,'+'+v,'#e2b436');killFx(e.x,e.y,p.cos.fx);
}
const myName=()=>(acct.state==='full'&&acct.name?acct.name.slice(0,12):(cfg.name||'').trim())||'Big U';
function newGame(roster,pvp=''){
  roster=roster||[{id:myId,name:myName(),cls:pick.cls,cos:cosStr(myCos())}];
  pvp=pvp==='base'||pvp==='ffa'?pvp:'';
  const Df=pvp?DIFF.normal:DIFF[pick.diff]||DIFF.normal;
  walls=new Array(N*N).fill(null);debris=new Int8Array(N*N);dist=new Float32Array(N*N);
  const wood=(i,j)=>({i,j,type:0,amt:48,max:48,rt:0,locked:false});
  const ruin=(list,mat,ratio,ch)=>list.forEach(([i,j])=>{const w=makeWall(mat,false,ratio);w.char=ch;walls[idx(i,j)]=w});
  const mir=([i,j])=>[N-1-i,N-1-j];
  if(pvp==='base'){
    cores=[{team:'a',i:4,j:11,hp:PVP.stake,max:PVP.stake,flash:0},{team:'b',i:11,j:4,hp:PVP.stake,max:PVP.stake,flash:0}];
    const west=[[2,8],[6,14],[1,13],[5,8]];
    nodes=[...west,...west.map(mir)].map(([i,j])=>wood(i,j));
    for(const[i,j]of[[1,6],[14,9]])nodes.push({i,j,type:1,locked:false,unlock:0,solid:true});
    for(const[i,j]of[[7,13],[8,2]])nodes.push({i,j,type:2,locked:false,unlock:0,solid:true});
    const fence=[[3,9],[4,9],[5,9]];ruin([...fence,...fence.map(mir)],0,.63,.25);
    ruin([[7,8],[8,7],[6,6],[9,9]],1,.55,.3);
  }else if(pvp==='ffa'){
    cores=[];nodes=[];
    // one quarter of the cover, turned four times around the middle so every corner plays the same
    const q=[[3,3],[4,3],[3,4],[6,2],[2,6],[6,6],[7,4]];
    const rot=([i,j])=>[N-1-j,i];
    for(const t of q){let c=t;for(let r=0;r<4;r++){walls[idx(c[0],c[1])]=makeWall(3,false);c=rot(c)}}
  }else{
    cores=[{team:'',i:4,j:11,hp:Df.core,max:Df.core,flash:0}];
    nodes=[wood(2,7),wood(7,13),wood(6,6),wood(9,9),wood(1,13),wood(10,4),wood(13,14),
      {i:11,j:11,type:1,locked:true,unlock:2,solid:true},{i:12,j:7,type:2,locked:true,unlock:4,solid:true}];
    ruin([[3,9],[4,9],[5,9]],0,.63,.25);
    ruin([[8,6],[8,7],[11,9]],1,.55,.3); // old brick ruins mid-yard
  }
  coreKs=new Set(cores.map(c=>idx(c.i,c.j)));
  players=new Map();
  roster.forEach((r,n)=>{const team=pvp==='base'?(r.team==='a'||r.team==='b'?r.team:n%2?'b':'a'):'';players.set(r.id,makePlayer(r.id,r.name,r.cls,n,r.cos,team))});
  if(pvp==='base'){const cnt={a:0,b:0};for(const p of players.values()){const s=SPAWNS[cnt[p.team]++%SPAWNS.length];[p.x,p.y]=p.team==='b'?[N-s[0],N-s[1]]:s}}
  if(pvp==='ffa'){let n=0;for(const p of players.values())[p.x,p.y]=FFA_SPAWNS[(n++*5)%FFA_SPAWNS.length]}
  player=players.get(myId)||[...players.values()][0];
  core=pvp==='base'?cores[player.team==='b'?1:0]:cores[0]||{team:'',i:-9,j:-9,hp:1,max:1,flash:0};
  coreK=cores.length?idx(core.i,core.j):-1;
  game.dellLv=0;
  qm={x:3.5,y:11.5,hp:180,max:180,alive:true,revive:0,aim:{x:1,y:0},cd:0,sup:8,gt:0,work:0,job:'',next:-1,pathT:0,scanT:0,foe:null,walk:0,flash:0,mats:[24,0,0],hurt:9};
  if(pvp)Object.assign(qm,{alive:false,gone:true,x:-9,y:-9});   // Dell sits PvP out
  enemies=[];bullets=[];lobs=[];charges=[];parts=[];flashes=[];floats=[];sacks=[];rockets=[];fires=[];zaps=[];slashes=[];rings=[];
  const mode=['5','10','endless'].includes(pick.mode)?pick.mode:'5';
  game={phase:pvp==='ffa'?'raid':'build',paused:false,wave:0,timer:pvp==='base'?PVP.truce:pvp==='ffa'?PVP.ffaTime:40+Df.build,queue:[],qn:0,spawnT:0,sel:game.sel||0,piece:'wall',time:0,tip:0,gathered:0,C:player.C,Df,
    mode,waves:mode==='endless'?Infinity:+mode,rewarded:false,bosses:0,pvp,goal:PVP.ffaGoal,winner:'',
    stats:{dropped:0,built:0,lost:0,repairs:0,revives:0}};
  for(const p of players.values()){if(pvp==='base')p.sal=PVP.startSal;if(pvp==='ffa'){p.mats=[0,0,0];p.prot=PVP.prot}}
  feedClear();
  Object.assign(light,{L:.12,r:28,g:34,b:44,warm:0});
  flowDirty=true;computeFlow();flowDirty=false;
  camSX=camX=W*(W<760?.4:.5)-(player.x-player.y)*TW2;camSY=camY=H*.52-(player.x+player.y)*TH2;
  if(pvp==='base'){const me=TEAMS[player.team],them=TEAMS[player.team==='a'?'b':'a'];game.tip=9;
    setTip(`You're ${me.name}. Truce for ${PVP.truce} seconds: gather and wall in your stake. Then knock down the ${them.name} stake. ${touchMode?'ARMORY':'E'} at your stake spends salvage.`)}
  else if(pvp==='ffa'){game.tip=9;setTip(`Free-for-all. First to ${PVP.ffaGoal} drops wins. The concrete cover can't be broken.`)}
  else setTip(touchMode?'Stand next to a wood pile to gather. Dell is gathering too.':'Walk next to a wood pile to gather. Dell is gathering too.');
}

