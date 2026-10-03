/* ================= state ================= */
let walls,debris,nodes,core,coreK,cores=[],coreKs=new Set(),player,qm,enemies,bullets,lobs,charges,parts=[],flashes=[],floats=[],sacks,dist,flowDirty=true,flowT=0;
let rockets=[],fires=[],zaps=[],slashes=[],rings=[],chains=[];   // boss rockets, burning ground, lightning, blade arcs and harpoon chains
let players=new Map(),myId='solo',nextId=1;   // every soldier in the yard; `player` is the one on this phone
let game={phase:'title',paused:false,time:0,wave:0,sel:0,piece:'wall',stats:{dropped:0,built:0,lost:0,repairs:0,revives:0}};
let pick={cls:'soldier',diff:'normal',mode:'5',pvp:'coop',map:'yard',size:'std',oct:false};
let demo=false,demoT=0,demoAcc=0;   // the menu's live background: Delgado alone against demo raids
const cfg={volume:.8,music:.7,shake:1,haptics:true,fps:false,fpsMode:'auto',tips:true,name:'',build:true,msgTime:1};
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
function foes(){if(!game.pvp)return enemies.some(e=>e.burrow)?enemies.filter(e=>!e.burrow):enemies;   // a burrowed Foreman can't be aimed at
  const o=[];for(const q of players.values())if(q.alive&&!(q.prot>0)&&rivals(player,q))o.push(q);return o}
function makeWall(mat,door,ratio=1){const hp=MAT[mat].hp*(door?.85:1);return{mat,door:!!door,hp:hp*ratio,max:hp,fire:0,char:0,flash:0,skip:0}}
const SPAWNS=[[5.5,11.5],[5.5,12.5],[3.5,12.5],[4.5,12.5],[5.5,10.5],[3.5,10.5]];
function makePlayer(id,name,cls,slot,cos,team,sk){
  if(!CLASSES[cls])cls='soldier';const C=CLASSES[cls],[x,y]=SPAWNS[slot%SPAWNS.length];
  const p={id,name,cls,slot,x,y,hp:C.hp,max:C.hp,alive:true,downed:false,rt:0,revive:0,aim:{x:.7,y:-.7},face:{x:.7,y:-.7},moveDir:{x:.7,y:-.7},
    cd:0,bcd:0,gt:0,ncd:0,mats:[24,0,0],cap:C.cap.slice(),nades:C.nades,maxN:C.nades,hurt:9,walk:0,flash:0,C,tp:0,fireIn:false,
    sal:0,kills:0,deaths:0,prot:0,ab:0,team:team==='b'?'b':team==='a'?'a':'',up:{d:0,r:0,g:0,a:0,n:0},upS:'00000',ammoEq:['',''],cos:parseCos(cos),cosS:'',sk:String(sk||''),perk:PERK0,rk:0,rkCd:0,stl:0,stlCd:0};
  p.cosS=cosStr(p.cos);refit(p);return p;
}
// The one way to change jobs (the room, Free-for-all respawns, and later the skill tree all use it): a fresh gun,
// full ammo, grenades and health for the new job. Kills, deaths, score, salvage, slot, team, armory upgrades and
// cosmetics stay. p.ab is the (future) class-ability state; it rides the network already and resets here.
function changeClass(p,cls){
  if(!p||!CLASSES[cls]||p.cls===cls)return false;
  const C=CLASSES[cls];p.cls=cls;p.C=C;p.cap=C.cap.slice();p.max=0;refit(p);p.hp=p.max;p.nades=p.maxN;
  p.mats=p.mats.map((m,i)=>Math.min(m,p.cap[i]));p.ammo=p.gun.mag?p.gun.mag:undefined;p.rl=0;p.rlReq=false;p.bolt=0;p.cd=0;p.bcd=0;p.sinceShot=9;
  p.bLeft=0;p.ab=0;p._lk='';p.nextShow='';if(p===player&&game)game.C=C;
  p.rk=abilRockets(p);p.rkCd=0;p.stl=0;p.stlCd=0;
  if(cls!=='sniper')p.ammoEq[1]='';
  return true;
}
/* ---------- armory: salvage buys upgrades between raids ---------- */
const ARM_MAX=8;
const UPG=[
  {k:'d',name:'DAMAGE',what:'Bullet damage up to +100%',cost:[20,45,80,130,175,225,290,370]},
  {k:'r',name:'FIRE RATE',what:'Shot cooldown up to 50% shorter',cost:[20,45,80,130,175,225,290,370]},
  {k:'g',name:'RANGE',what:'Reach up to +60%; bullet speed up to +50%',cost:[15,35,60,100,140,185,240,310]},
  {k:'a',name:'ARMOR',what:'Maximum health up to +75%',cost:[20,45,80,130,175,225,290,370]},
  {k:'n',name:'GRENADES',what:'Up to +5 grenades and +40% blast power',cost:[15,35,60,100,140,185,240,310]}];
const AMMO=[
  {id:'ap',name:'ARMOR PIERCING',what:'Damage through a frontal riot shield',skill:'ammo_ap',col:'#c8e0f2'},
  {id:'fire',name:'INCENDIARY',what:'Burns for 10 HP/s; hits refresh the timer',skill:'ammo_fire',col:'#ff8244'},
  {id:'blast',name:'EXPLOSIVE',what:'Small enemy-only blast on impact',skill:'ammo_blast',col:'#ffc05a'},
  {id:'shock',name:'LIGHTNING',what:'Slows the target and nearby enemies',skill:'ammo_shock',col:'#81dafa'}];
const AMMO_BY=Object.fromEntries(AMMO.map(x=>[x.id,x]));
const ammoMode=()=>!game.pvp&&['5','10','endless','blitz','campaign','blackout'].includes(game.mode);
const ammoRank=(p,id)=>{const A=AMMO_BY[id];return A?Math.min(4,parseSkills(p.sk)[A.skill]|0):0};
const ammoEffect=(id,rank)=>id==='ap'?`${[50,60,70,85,100][rank]}% direct damage through frontal shields`:id==='fire'?`10 HP/s for ${3+.5*rank}s; hits refresh`:id==='blast'?`${8+2*rank} damage, 1.25-block blast; 0.4s proc limit`:`${25+5*rank}% slow for 2s; nearest 3 within 3 blocks`;
const armBoost=(lv,oldStep,newStep)=>oldStep*Math.min(4,lv)+newStep*Math.max(0,lv-4);
// Co-op only. Delgado's level is shared by the crew; anyone can buy the next one.
// The first four levels add 15% each; the next four add 3.75% each, to a +75% cap.
const DELL_UP={name:'DELGADO',what:'Shared damage, reach and fire rate up to +75%.',cost:[30,60,100,150,200,270,350,450]};
const dellBoost=lv=>armBoost(lv,.15,.0375);
// the core doesn't heal on its own: 25 salvage (13 for the quartermaster) buys back up to 50 health
const CORE_FIX={hp:50,cost:25};
const coreFixCost=p=>Math.ceil(CORE_FIX.cost*(p.C.repair||1));
const BOUNTY={rifle:4,gren:7,breach:6,shield:6,medic:5,spotter:5,fire:6};
// v0.9.2: skill-tree perks (p.perk) and modifiers (Glass Cannon, Grenade Frenzy) are folded in here too
const PERK0=perkMods({},false);
function refit(p){
  const G=p.C.gun,U=p.up,K=p.perk||PERK0;
  p.gun=Object.assign({},G,{dmg:G.dmg*(1+armBoost(U.d,.2,.05))*K.dmg,cd:G.cd*(1-armBoost(U.r,.1,.025))/K.rate,range:G.range*(1+armBoost(U.g,.12,.03))*K.range,speed:G.speed*(1+armBoost(U.g,.1,.025))});
  if(G.reload)p.gun.reload=G.reload*K.reload;
  const mx=Math.round(p.C.hp*(1+armBoost(U.a,.15,.0375))*K.hp*(hasMod('glass')?.7:1));if(mx>p.max)p.hp+=mx-p.max;p.max=mx;if(p.hp>p.max)p.hp=p.max;
  p.maxN=p.C.nades+Math.min(U.n,4)+(U.n>=8?1:0)+(p.cls==='grenadier'?K.pouch:0);p.blast=p.C.blast*(1+armBoost(U.n,.08,.02))*(hasMod('frenzy')?1.33:1);
  p.cap=p.C.cap.map(c=>c+K.carry);
}
// perks for this match (PvP halves them), then a full kit: health, grenades, rockets
function kitUp(p){p.perk=perkMods(parseSkills(p.sk),!!game.pvp);p.max=0;refit(p);p.hp=p.max;p.nades=p.maxN;p.rk=abilRockets(p);p.rkCd=0;p.stl=0;p.stlCd=0}
const abilRockets=p=>p.cls==='soldier'&&!game.pvp?ABIL.rocket.stock+((p.perk||PERK0).rockets|0):0;
// burst carbine: 3/5/7/9/9 bullets at DAMAGE level 0-4; the pause after a burst is 0.40 s, 0.05 s shorter per level, never under 0.20 s
const BURST_N=[3,5,7,9,9],burstN=p=>BURST_N[Math.min(4,p.up.d|0)],burstGap=p=>Math.max(.2,.4-.05*(p.up.d|0));
const upStr=p=>UPG.map(x=>p.up[x.k]).join('');
const nearStake=p=>{const c=stakeOf(p);return!!c&&Math.hypot(p.x-(c.i+.5),p.y-(c.j+.5))<2.7};
const lockdown=()=>hasMod('lockdown')&&game.mode==='blitz'&&game.wave>=BLITZ.waves-1;   // v0.9.4.0: the armory is shut before the Final Blitz
const shopOpen=p=>!!p&&p.alive&&!lockdown()&&(game.pvp==='base'?game.phase!=='over':!game.pvp&&(game.phase==='build'||boQuiet()));   // v0.9.7: Black Out's quiet windows (and the ready stage) too
const canShop=p=>shopOpen(p)&&(nearStake(p)||blackout()&&boNearHeld(p));   // v0.9.7.1: any held POI in Black Out
function buyUpgrade(p,k){
  if(k==='core')return repairCore(p);
  if(k==='dell')return buyDell(p);
  const U=UPG.find(x=>x.k===k);if(!U||!canShop(p))return false;const t=p.up[k];if(t>=ARM_MAX||p.sal<U.cost[t])return false;
  p.sal-=U.cost[t];p.up[k]=t+1;p.upS=upStr(p);refit(p);if(k==='n')p.nades=Math.max(p.nades,p.maxN);
  personal(p,'restock');return true;
}
function buyAmmo(p,id,slot){
  if(!AMMO_BY[id]||!ammoMode()||!canShop(p)||!Number.isInteger(slot)||slot<0||slot>=(p.cls==='sniper'?2:1))return false;
  if(p.ammoEq.includes(id))return p.ammoEq[slot]===id;
  const cost=p.ammoEq[slot]?75:150;if(p.sal<cost)return false;
  p.sal-=cost;p.ammoEq[slot]=id;personal(p,'restock');return true;
}
function repairCore(p){
  const c=cores[0],cost=coreFixCost(p);
  if(game.pvp||hasMod('nopatch')||!canShop(p)||!nearStake(p)||!c||c.hp<=0||c.hp>=c.max||p.sal<cost)return false;   // full core: nothing to buy, nothing charged
  const add=Math.min(CORE_FIX.hp,c.max-c.hp);p.sal-=cost;c.hp+=add;
  flt(c.i+.5,c.j+.5,`+${Math.round(add)} CORE`,'#8fe0a0');emit(c.i+.5,c.j+.5,WH*.6,'heal');personal(p,'restock');return true;
}
function buyDell(p){
  const L=game.dellLv|0;
  if(game.pvp||!canShop(p)||L>=ARM_MAX||p.sal<DELL_UP.cost[L])return false;
  p.sal-=DELL_UP.cost[L];game.dellLv=L+1;
  toastAll(`DELGADO · LEVEL ${L+1}`,`${p.name} upgraded Delgado's shotgun: +${Math.round(dellBoost(L+1)*100)}% damage, range and fire rate.`);personal(p,'restock');return true;
}
// who gets paid for a kill; bullets and grenades remember whose they were
function award(own,e){
  if(demo)return;
  if(own==='dell'){for(const p of players.values())p.sal+=1;return}
  const p=players.get(own);if(!p)return;
  const v=Math.round((BOUNTY[e.type]||4)*boSalvage(e));p.sal+=v;p.kills++;flt(e.x,e.y-.2,'+'+v,'#e2b436');killFx(e.x,e.y,p.cos.fx);
}
const myName=()=>(acct.state==='full'&&acct.name?acct.name.slice(0,12):(cfg.name||'').trim())||'Big U';
// opt (v0.9.2): {gid: the shared game id, mods: modifier ids, job: One Job's class, guest: true on a guest's phone}
const newGid=()=>{const A='abcdefghijkmnpqrstuvwxyz23456789';let s='';for(let i=0;i<12;i++)s+=A[Math.floor(rnd()*A.length)];return Date.now().toString(36)+'-'+s};
function newGame(roster,pvp='',opt={}){
  roster=roster||[{id:myId,name:myName(),cls:pick.cls,cos:cosStr(myCos()),sk:mySkills()}];
  pvp=pvp==='base'||pvp==='ffa'?pvp:'';
  const mods=pick.mode==='campaign'&&!pvp?campaignMods(cleanMods(opt.mods,'')):cleanMods(opt.mods,pvp||(pick.mode==='blitz'?'blitz':'')),job=mods.includes('onejob')&&CLASSES[opt.job]?opt.job:'';
  if(job)roster=roster.map(r=>({...r,cls:job}));
  const Df=pvp?DIFF.normal:DIFF[pick.diff]||DIFF.normal;
  const map=pick.mode==='blackout'&&!pvp?'city':pick.mode==='campaign'&&!pvp?'yard':pvp&&pick.map==='frost'?'yard':pick.map,L=layMap(map,pick.size,pvp);
  walls=new Array(N*N).fill(null);debris=new Int8Array(N*N);dist=new Float32Array(N*N);
  const wood=(i,j)=>({i,j,type:0,amt:48,max:48,rt:0,locked:false});
  const ruin=(list,mat,ratio,ch)=>list.forEach(([i,j])=>{const w=makeWall(mat,false,ratio);w.char=ch;walls[idx(i,j)]=w});
  const mir=([i,j])=>[N-1-i,N-1-j];
  if(pvp==='base'){
    cores=L.cores.map(([i,j],n)=>({team:n?'b':'a',i,j,hp:PVP.stake,max:PVP.stake,flash:0}));
    nodes=L.nodes;for(const[list,mat,ratio,ch]of L.ruins)ruin(list,mat,ratio,ch);
  }else if(pvp==='ffa'){
    cores=[];nodes=L.nodes||[];
    for(const[i,j,style]of L.cover){const w=makeWall(3,false);w.cov=style||'';walls[idx(i,j)]=w}   // the arena's cover can't be broken
  }else{
    cores=[{team:'',i:L.core[0],j:L.core[1],hp:Df.core,max:Df.core,flash:0}];
    nodes=L.nodes;
    // v0.9.7 City Black Out: the eight POIs are stakes too (bullets, blasts and the snapshot already handle cores);
    // Main Command stays cores[0], and only it ends the run
    if(L.pois)for(const p of L.pois){const hp=Math.round(Df.core*(p.major?.7:.5));cores.push({team:'',i:p.i,j:p.j,hp,max:hp,flash:0,poi:p,lost:false,dark:0})}
    for(const[list,mat,ratio,ch]of L.ruins)ruin(list,mat,ratio,ch);   // old ruins: they pay salvage when knocked down
    if(pick.mode==='campaign')for(const n of nodes)if(n.locked&&n.unlock>3)n.unlock=3;   // v0.9.6.4: the Yard's metal opens after raid 2 in the campaign
  }
  coreKs=new Set(cores.map(c=>idx(c.i,c.j)));
  players=new Map();
  roster.forEach((r,n)=>{const team=pvp==='base'?(r.team==='a'||r.team==='b'?r.team:n%2?'b':'a'):'';players.set(r.id,makePlayer(r.id,r.name,r.cls,n,r.cos,team,r.sk))});
  if(pvp==='base'){const cnt={a:0,b:0},TS=L.teamSpawns;for(const p of players.values()){const s=TS[cnt[p.team]++%TS.length];[p.x,p.y]=p.team==='b'?[N-s[0],N-s[1]]:s}}
  if(pvp==='ffa'){let n=0;const S=L.pspawns;for(const p of players.values())[p.x,p.y]=S[(n++*5)%S.length]}
  const off=pvp?[0,0]:[cores[0].i-4,cores[0].j-11];   // the spawn spots are laid out round a stake at (4,11)
  if(!pvp)for(const p of players.values()){p.x+=off[0];p.y+=off[1]}
  player=players.get(myId)||[...players.values()][0];
  core=pvp==='base'?cores[player.team==='b'?1:0]:cores[0]||{team:'',i:-9,j:-9,hp:1,max:1,flash:0};
  coreK=cores.length?idx(core.i,core.j):-1;
  game.dellLv=0;
  qm={x:3.5+off[0],y:11.5+off[1],hp:180,max:180,alive:true,revive:0,aim:{x:1,y:0},cd:0,sup:8,gt:0,work:0,job:'',next:-1,pathT:0,scanT:0,foe:null,walk:0,flash:0,mats:[24,0,0],hurt:9};
  if(pvp||mods.includes('alone'))Object.assign(qm,{alive:false,gone:true,x:-9,y:-9});   // Delgado sits PvP (and On Your Own) out
  Object.assign(qm,{mode:'follow',completedRaids:0,layout:null,layoutAnchor:'',layoutSize:4,status:'Following host',bcd:0,C:{build:1,repair:1},face:{x:1,y:0},tp:0});
  enemies=[];bullets=[];lobs=[];charges=[];parts=[];flashes=[];floats=[];sacks=[];rockets=[];fires=[];zaps=[];slashes=[];rings=[];chains=[];arcs=[];arcHaz.length=0;
  const mode=['5','10','endless','blitz','campaign','blackout'].includes(pick.mode)?pick.mode:'5';
  game={phase:pvp==='ffa'?'raid':'build',paused:false,wave:0,timer:pvp==='base'?PVP.truce:pvp==='ffa'?PVP.ffaTime:mode==='blackout'?BO.gather:40+Df.build,queue:[],qn:0,spawnT:0,sel:game.sel||0,piece:'wall',time:0,tip:0,gathered:0,C:player.C,Df,
    mode,waves:mode==='endless'?Infinity:mode==='blackout'?8:mode==='blitz'?BLITZ.waves:mode==='campaign'?CAMPAIGN.waves:+mode,rewarded:false,bosses:0,pvp,goal:PVP.ffaGoal,winner:'',chapter:0,
    stats:{dropped:0,built:0,lost:0,repairs:0,revives:0},
    map:map==='city'||MAP_IDS.includes(map)?map:'yard',size:N>16?'xl':'std',lay:L,flood:{t:0,warned:false},bossLog:[],oct:!!pick.oct,
    gid:String(opt.gid||newGid()).slice(0,40),mods,job,sbN:0,sbLog:[],fbLog:[],fb:null,joinFB:0,wx:0,wxT:0,sd:false,
    joinHeld:opt.guest?null:0,joinT:0,joinBoss:0,joinSB:0};   // join*: where this phone came in (guests learn it from the first state packet)
  for(const p of players.values())kitUp(p);
  for(const p of players.values()){if(pvp==='base')p.sal=PVP.startSal;if(pvp==='ffa'){p.mats=[0,0,0];p.prot=PVP.prot}}
  feedClear();toastClear();
  Object.assign(light,{L:.12,r:28,g:34,b:44,warm:0});
  flowDirty=true;computeFlow();flowDirty=false;
  camSX=camX=W*(W<760?.4:.5)-(player.x-player.y)*TW2;camSY=camY=H*.52-(player.x+player.y)*TH2;
  if(pvp==='base'){const me=TEAMS[player.team],them=TEAMS[player.team==='a'?'b':'a'];game.tip=9;
    setTip(`You're ${me.name}. Truce for ${PVP.truce} seconds: gather and wall in your stake. Then knock down the ${them.name} stake. ${ctl('ARMORY','E',padKey('armory'))} at your stake spends salvage.`)}
  else if(pvp==='ffa'){game.tip=9;setTip(`Free-for-all. First to ${PVP.ffaGoal} drops wins. The cover can't be broken.`)}
  else if(campaign())setTip(`CHAPTER 1 · THE YARD. ${CAMPAIGN.story[0]} Three raids here, then your kit travels onward. Prepare at the core.`);
  else setTip(touchMode?'Stand next to a wood pile to gather. Delgado is gathering too.':'Walk next to a wood pile to gather. Delgado is gathering too.');
}

