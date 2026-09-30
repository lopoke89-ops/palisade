'use strict';
const $=id=>document.getElementById(id);
const cv=$('game'),G0=cv.getContext('2d',{alpha:false});
let g=G0;   // current drawing target; swapped to an offscreen canvas while scenery is cached
const lc=document.createElement('canvas'),lg=lc.getContext('2d');

/* ================= tuning ================= */
let N=16;   // the yard's size in tiles: 16, or 24 for an XL map (set by newGame)
const idx=(i,j)=>j*N+i,inb=(i,j)=>i>=0&&j>=0&&i<N&&j<N;
const D4=[[1,0],[-1,0],[0,1],[0,-1]];
const MAT=[
  {name:'WOOD', cost:4,hp:60, bullet:1.0, blast:2.2,cd:.22,rep:2,top:'#b8894f',l:'#8b6236',r:'#6b4a28',line:'rgba(52,32,14,.55)'},
  {name:'BRICK',cost:4,hp:170,bullet:.42,blast:1.3,cd:.55,rep:2,top:'#a0533c',l:'#7b3b2a',r:'#5d2c20',line:'rgba(220,190,160,.28)'},
  {name:'METAL',cost:4,hp:320,bullet:.14,blast:.55,cd:1.0,rep:2,top:'#a3a9a8',l:'#727a7a',r:'#565d5e',line:'rgba(28,32,33,.5)'},
  {name:'CONCRETE',cost:99,hp:9999,bullet:0,blast:0,cd:1,rep:9,top:'#8f8b80',l:'#6d6a61',r:'#56534c',line:'rgba(30,28,24,.4)'}
];
/* ---------- PvP ---------- */
// base: two crews, two stakes, a truce to build, then knock theirs down. ffa: everyone for themselves around fixed concrete cover.
const TEAMS={a:{name:'WEST',col:'#6fa8dc'},b:{name:'EAST',col:'#e0664a'}};
const PVP={stake:700,dmg:.7,snipe:52/47,snipeCd:1.25/.7,nade:.8,stakeHit:.35,truce:45,bounty:8,startSal:20,ffaGoal:15,ffaTime:300,prot:2};
const FFA_SPAWNS=[[1.5,1.5],[14.5,1.5],[14.5,14.5],[1.5,14.5],[7.5,1.3],[14.7,7.5],[8.5,14.7],[1.3,8.5]];
const CLASSES={
  // burst carbine: a burst always finishes once started. Bullets per burst and the pause after it follow the DAMAGE level;
  // FIRE RATE tightens the spacing inside a burst (cd)
  soldier:{name:'SOLDIER',hp:115,nades:2,build:.6,cap:[64,64,64],blast:1,nadeCd:1,spd:1,gun:{dmg:12,cd:.09,spread:.12,range:11,speed:22,snd:'ar',burst:true}},
  // bolt every 0.7 s in co-op (PvP keeps 1.25 s through PVP.snipeCd). 47 still drops a rifleman in one through raid 4 on Normal
  sniper:{name:'SNIPER',hp:90,nades:2,build:1,cap:[64,64,64],blast:1,nadeCd:1,spd:1.1,gun:{dmg:47,cd:.7,spread:.02,range:16,speed:34,pierce:2,snd:'sniper',bolt:true}},
  // pump shotgun: 7 pellets in a tight, even pattern, full damage out to 2.5 tiles, half by 7; a 6-shell tube loaded one shell at a time
  grenadier:{name:'GRENADIER',hp:105,nades:3,build:1,cap:[64,64,64],blast:1.25,nadeCd:.6,spd:.9,gun:{dmg:12,cd:.5,clickCd:.12,spread:.15,range:7.2,speed:24,snd:'shotgun',bolt:true,pump:true,pellets:7,fall:[2.5,7,.55],mag:6,reload:.42}},
  // support: walking over a downed teammate (or Delgado) gets them straight up; bigger packs, faster gathering, half-price repairs
  quartermaster:{name:'QUARTERMASTER',hp:110,nades:2,build:.85,cap:[96,96,96],blast:1,nadeCd:1,gather:.72,repair:.5,medic:true,spd:1,sprint:true,gun:{dmg:7,cd:.085,spread:.15,range:8.5,speed:22,snd:'smg'}}
};
const CLASS_IDS=Object.keys(CLASSES);
const DIFF={
  easy:{name:'EASY',dmg:.55,hp:.8,extra:-1,build:10,core:600},
  normal:{name:'NORMAL',dmg:.85,hp:1,extra:0,build:0,core:500},
  hard:{name:'HARD',dmg:1.15,hp:1.2,extra:1,build:-6,core:420}
};
const RATE=[.18,.225,.54],YIELD=[4,1,1],WAVES=5,QM_RESERVE=[16,8,8],STACK=64,WALL_COST=4,DOOR_COST=8;
const hash=(i,j)=>{let h=(i*374761393+j*668265263)|0;h=Math.imul(h^(h>>>13),1274126177);return((h^(h>>>16))>>>0)/4294967295};
const clamp=(v,a,b)=>v<a?a:v>b?b:v,rnd=Math.random,dist2=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);

