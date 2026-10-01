/* ================= maps and terrain ================= */
// A map is data: where the stake sits, resource piles, old ruins, the ground (terrain), where raiders come in,
// which bosses turn up and how it looks. lay() fills it in for the chosen size: 16×16, or 24×24 for XL, where
// the 16×16 layout sits in the south-west corner and the new ground to the north and east gets its own extras.
// Terrain is one byte a tile. Water slows everyone to half and can't be built on; bridges are dry ground;
// low banks flood on Riverbend; cracked ground collapses into pits under heavy blasts on Ashfall Quarry;
// rock and oil drums are solid and stop bullets.
const T_GROUND=0,T_WATER=1,T_BRIDGE=2,T_LOW=3,T_CRACK=4,T_PIT=5,T_ROCK=6,T_DRUM=7;
const SIZES={std:16,xl:24};
let terr=new Uint8Array(N*N),terrLog=[],floodOn=false,floodLv=0,MAP=null,MAPO={ox:0,oy:0,xl:false};   // terrLog: tiles changed since the start (host sends it)
const tAt=(i,j)=>inb(i,j)?terr[idx(i,j)]:T_GROUND;
const terrSolid=t=>t===T_PIT||t===T_ROCK||t===T_DRUM;
const terrShot=t=>t===T_ROCK;   // what stops a bullet and blocks sight: rock outcrops only (v0.9.1: oil drums don't; a pit doesn't)
const wetT=t=>t===T_WATER||(t===T_LOW&&floodOn);
// how fast you move on this spot (1 = normal)
function slowAt(x,y){const t=tAt(Math.floor(x),Math.floor(y)),s=(t===T_WATER?.5:t===T_LOW&&floodOn?.62:1)*stormSlow(),f=frostSlow(x,y);return f<1?Math.max(.5,s*f):s}
function terrNoBuild(k,hasWall){
  if(connectors[k])return'Keep the mountain connector clear';
  const t=terr[k];
  if(t===T_WATER)return'Can\'t build on water';
  if(t===T_PIT)return'That\'s a pit now';
  if(t===T_ROCK)return'Solid rock';
  if(t===T_DRUM)return'Oil drum in the way';
  if(t===T_LOW&&floodOn&&!hasWall)return'Flooded. Wait for the water to drop';
  return'';
}
function setTerr(k,t){if(terr[k]===t)return;terr[k]=t;terrLog.push(k,t);markFlow()}
// the host sends the whole change list with each state packet (a few numbers; it only grows by pits and a bridge)
function applyTerrLog(list){for(let q=0;q+1<list.length;q+=2){const k=list[q],t=list[q+1];if(k>=0&&k<N*N)terr[k]=t}}

// ---------- the maps ----------
const riverC=(j,o)=>9+o.ox+1.2*Math.sin((j-o.oy)*.5+.6);   // Riverbend's river: centre column for each row
const MAPS={
  yard:{name:'THE YARD',short:'Yard',blurb:'The claim you know. Open ground, a few old ruins, raiders over the east fence.',
    from:'over the east fence',bosses:['butcher','demolisher','storm'],col:'#b8894f',hp:1,
    lay(o){
      const P=([i,j])=>[i+o.ox,j+o.oy],L={core:P([4,11]),nodes:[],ruins:[]};
      const wood=[[2,7],[7,13],[6,6],[9,9],[1,13],[10,4],[13,14]].map(P);
      if(o.xl)wood.push([14,3],[20,9],[19,20],[9,2],[3,3]);
      L.nodes=wood.map(woodNode);
      L.nodes.push(kiln(P([11,11]),2),scrap(P([12,7]),4));if(o.xl)L.nodes.push(scrap([18,4],6));
      L.ruins.push([[[3,9],[4,9],[5,9]].map(P),0,.63,.25],[[[8,6],[8,7],[11,9]].map(P),1,.55,.3]);
      if(o.xl)L.ruins.push([[[16,11],[16,12]],1,.55,.3],[[[12,4],[13,4]],0,.63,.25]);
      L.spawns=[{w:.6,tiles:edgeTiles('e',0,o.oy+12)},{w:.4,tiles:edgeTiles('n',o.ox+6,N)}];
      L.bossAt=edgeTiles('e',o.oy+2,o.oy+11);
      return L;
    }},
  river:{name:'RIVERBEND',short:'Riverbend',blurb:'A river cuts the yard in two. Two bridges, slow wading, more scrap, less wood. From raid 3 the banks flood.',
    from:'across the river',bosses:['ferryman','butcher','storm'],col:'#4a9ac0',hp:1.05,
    lay(o){
      const P=([i,j])=>[i+o.ox,j+o.oy],L={core:P([4,11]),nodes:[],ruins:[]};
      // the river: about two tiles wide, winding north to south; the bridges cross it
      for(let j=0;j<N;j++){const c=riverC(j,o);for(let i=0;i<N;i++)if(Math.abs(i+.5-c)<1)terr[idx(i,j)]=T_WATER}
      const rows=[o.oy+4,o.oy+11];if(o.xl)rows.push(1);
      for(const j of rows)for(let i=0;i<N;i++)if(terr[idx(i,j)]===T_WATER)terr[idx(i,j)]=T_BRIDGE;
      // low banks next to the water flood (the ends of the bridges stay dry)
      const nearBridge=(i,j)=>{for(let a=-1;a<=1;a++)for(let b=-1;b<=1;b++)if(tAt(i+a,j+b)===T_BRIDGE)return true;return false};
      for(let j=0;j<N;j++)for(let i=0;i<N;i++){const k=idx(i,j);if(terr[k]!==T_GROUND||nearBridge(i,j))continue;
        let w=false;for(let a=-1;a<=1&&!w;a++)for(let b=-1;b<=1;b++)if(tAt(i+a,j+b)===T_WATER){w=true;break}if(w)terr[k]=T_LOW}
      const wood=[[2,7],[6,14],[1,13],[4,3],[13,13]].map(P);if(o.xl)wood.push([5,2],[17,3],[20,18],[19,11]);
      L.nodes=wood.map(woodNode);
      L.nodes.push(kiln(P([3,14]),2),scrap(P([1,4]),2),scrap(P([13,5]),0));if(o.xl)L.nodes.push(scrap([21,6],3));
      L.ruins.push([[[4,8],[5,8]].map(P),0,.63,.25],[[[12,9],[12,10]].map(P),1,.55,.3]);
      if(o.xl)L.ruins.push([[[16,15],[17,15]],1,.55,.3]);
      const c0=riverC(0,o);
      L.spawns=[{w:.7,tiles:edgeTiles('e',0,N)},{w:.3,tiles:edgeTiles('n',Math.ceil(c0)+2,N)}];
      L.bossAt=edgeTiles('e',o.oy+1,N-2);
      // the Ferryman comes down the river from the north
      L.raftAt=[];for(let i=0;i<N;i++)if(terr[idx(i,0)]===T_WATER)L.raftAt.push([i,0]);
      return L;
    },
    // outside the fence the river keeps going, so it reads as one river
    outWater(i,j,o){if(o.pvp==='base')return Math.abs(i-j)<=1;if(o.pvp==='ffa')return i===7||i===8||j===7||j===8;if(i<0||i>=N)return false;const c=riverC(j,o);return Math.abs(i+.5-c)<1}},
  quarry:{name:'ASHFALL QUARRY',short:'Quarry',blurb:'A night pit lit by oil drums. Plenty of brick, little wood, three ramps in. Heavy blasts crack the floor into pits.',
    from:'down the ramps',bosses:['foreman','demolisher','storm'],col:'#e0763a',night:true,hp:1.1,
    lay(o){
      const P=([i,j])=>[i+o.ox,j+o.oy],L={core:P([4,11]),nodes:[],ruins:[]};
      const put=(list,t)=>{for(const[i,j]of list)if(inb(i,j))terr[idx(i,j)]=t};
      put([[7,8],[8,8],[10,12],[10,13],[5,5],[13,10],[12,2]].map(P),T_ROCK);
      put([[3,9],[8,11],[9,3],[13,7],[2,2],[12,14]].map(P),T_DRUM);
      if(o.xl){put([[16,4],[17,4],[20,13],[19,21],[8,1]],T_ROCK);put([[15,9],[21,3],[18,17],[5,1]],T_DRUM)}
      const wood=[[2,7],[1,13],[7,5],[3,3]].map(P);if(o.xl)wood.push([14,2],[20,20]);
      L.nodes=wood.map(woodNode);
      const k1=kiln(P([6,13]),0);k1.locked=false;
      L.nodes.push(k1,kiln(P([11,9]),3),scrap(P([12,4]),4));if(o.xl)L.nodes.push(kiln([18,8],2));
      L.ruins.push([[[5,8],[6,8]].map(P),1,.55,.3],[[[9,5],[10,5]].map(P),1,.55,.3],[[[2,10]].map(P),0,.63,.25]);
      if(o.xl)L.ruins.push([[[15,14],[16,14]],1,.55,.3]);
      // three ramps down into the pit: north, east, south-east
      const rN=[o.ox+8,o.ox+9],rE=[o.oy+4,o.oy+5],rS=[o.oy+12,o.oy+13];
      L.ramps=[...rN.map(i=>[i,0]),...[...rE,...rS].map(j=>[N-1,j])];
      L.spawns=[{w:1/3,tiles:rN.map(i=>[i,0])},{w:1/3,tiles:rE.map(j=>[N-1,j])},{w:1/3,tiles:rS.map(j=>[N-1,j])}];
      L.bossAt=L.ramps.slice();
      // cracked floor across the middle of the pit, where the fighting is
      const nodeK=new Set(L.nodes.map(n=>idx(n.i,n.j)));
      for(let j=o.oy+5;j<=o.oy+11;j++)for(let i=o.ox+7;i<=o.ox+13;i++){const k=idx(i,j);if(inb(i,j)&&terr[k]===T_GROUND&&!nodeK.has(k)&&hash(i*5+3,j*9+1)>.4)terr[k]=T_CRACK}
      if(o.xl)for(let j=2;j<=9;j++)for(let i=15;i<=21;i++){const k=idx(i,j);if(terr[k]===T_GROUND&&!nodeK.has(k)&&hash(i*5+3,j*9+1)>.5)terr[k]=T_CRACK}
      return L;
    }}
};
const MAP_IDS=Object.keys(MAPS);
const woodNode=([i,j])=>({i,j,type:0,amt:48,max:48,rt:0,locked:false});
const kiln=([i,j],unlock)=>({i,j,type:1,locked:unlock>0,unlock,solid:true});
const scrap=([i,j],unlock)=>({i,j,type:2,locked:unlock>0,unlock,solid:true});
function edgeTiles(side,a,b){const out=[];for(let s=Math.max(0,a);s<Math.min(N,b);s++)out.push(side==='e'?[N-1,s]:[s,0]);return out}
// fills terrain and returns the layout for newGame; sets N for the size
function layMap(id,size,pvp){
  const n=pvp?16:SIZES[size]||16;
  if(n!==N){N=n}
  terr=new Uint8Array(N*N);heights=new Uint8Array(N*N);connectors=new Uint8Array(N*N);frostFields=[];terrLog=[];floodOn=false;floodLv=0;
  if(pvp){MAP=MAPS[id]||MAPS.yard;MAPO={ox:0,oy:0,xl:false,pvp};return layPvp(MAP===MAPS[id]?id:'yard',pvp)}   // v0.9.1: PvP plays on every map
  MAP=MAPS[id]||MAPS.yard;
  const o={ox:N>16?2:0,oy:N>16?N-16-2:0,xl:N>16,pvp:''};   // XL: the 16×16 layout moves in a little from the south-west corner
  MAPO=o;const L=MAP.lay(o);
  // piles, ruins and the stake always stand on plain ground
  for(const[i,j]of[L.core,...L.nodes.map(n=>[n.i,n.j]),...L.ruins.flatMap(r=>r[0])]){const k=idx(i,j);if(terr[k]!==T_GROUND&&terr[k]!==T_LOW)terr[k]=T_GROUND}
  return L;
}
// a random free tile to come in on, from the map's spawn edges (weighted)
function spawnTile(L){
  const groups=L||game.lay.spawns;let r=rnd(),grp=groups[groups.length-1];
  for(const s of groups){if(r<s.w){grp=s;break}r-=s.w}
  for(let a=0;a<20;a++){const t=grp.tiles[Math.floor(rnd()*grp.tiles.length)];if(t&&!solidTile(t[0],t[1]))return t}
  for(const s of groups)for(const t of s.tiles)if(!solidTile(t[0],t[1]))return t;
  return null;
}
// blasts at or above this power break cracked ground into pits
const PIT_POWER=1.2;
function crackBlast(x,y,R,power){
  if(power<PIT_POWER||!MAP||MAP!==MAPS.quarry)return;
  const r=Math.max(.8,R*.55);
  for(let i=Math.floor(x-r);i<=Math.floor(x+r);i++)for(let j=Math.floor(y-r);j<=Math.floor(y+r);j++)
    if(inb(i,j)&&terr[idx(i,j)]===T_CRACK&&Math.hypot(i+.5-x,j+.5-y)<r+.35)makePit(idx(i,j));
}
function makePit(k){
  if(terr[k]===T_PIT)return;const i=k%N,j=(k/N)|0;
  if(coreKs.has(k)||nodeAt(i,j))return;
  setTerr(k,T_PIT);if(walls[k]){walls[k]=null;game.stats.lost++}debris[k]=0;
  emitSpread(i+.5,j+.5,.7,0,WH*.3,'chunk',1,10);for(let n=0;n<8;n++)emit(i+.5,j+.5,WH*.3,'dust',1);
  sfx('collapse',i+.5,j+.5);addShake(i+.5,j+.5,6);
  // anyone standing there is pushed to solid ground
  const out=e=>{if(Math.floor(e.x)!==i||Math.floor(e.y)!==j)return false;for(const[a,b]of[[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,-1],[1,-1],[-1,1]])if(!solidTile(i+a,j+b)){e.x=i+a+.5;e.y=j+b+.5;return true}return false};
  for(const p of players.values())if(out(p))p.tp++;
  for(const e of enemies)out(e);out(qm);
}
// Riverbend floods from raid 3: a warning, then the low banks go under for a while, then drain
const FLOOD={from:3,delay:14,warn:5,len:24},PVP_FLOOD={every:75,at:45,len:20};
function updateFlood(dt){
  if(MAP!==MAPS.river||game.pvp==='ffa')return;
  const F=game.flood;
  if(game.pvp==='base'){if(game.phase!=='raid'){if(floodOn){floodOn=false;markFlow()}return}
    F.t+=dt;const c=F.t%PVP_FLOOD.every;
    if(!F.warned&&c>=PVP_FLOOD.at-FLOOD.warn&&c<PVP_FLOOD.at){F.warned=true;toastAll('THE RIVER IS RISING','Both low banks go under in a few seconds.');sfx('flood')}
    const on=c>=PVP_FLOOD.at&&c<PVP_FLOOD.at+PVP_FLOOD.len;if(on!==floodOn){floodOn=on;markFlow();if(!on){F.warned=false;toastAll('THE WATER DROPS','The banks are dry again.')}}
    return}
  if(game.phase==='raid'&&game.wave>=FLOOD.from){
    F.t+=dt;
    if(!F.warned&&F.t>=FLOOD.delay-FLOOD.warn){F.warned=true;toastAll('THE RIVER IS RISING','The low banks go under in a few seconds. Wading is slow, and nothing new can be built there while it floods.');sfx('flood')}
    const on=F.t>=FLOOD.delay&&F.t<FLOOD.delay+FLOOD.len;
    if(on!==floodOn){floodOn=on;markFlow();if(!on)toastAll('THE WATER DROPS','The banks are dry again.')}
  }else if(floodOn){floodOn=false;markFlow()}
}
function floodVisual(dt){floodLv+=((floodOn?1:0)-floodLv)*Math.min(1,dt*1.2)}

// ---------- drawing ----------
// ground colour for a tile in the cached back layer (water is painted here; bridges, pits and floods are drawn live)
function groundCol(i,j,h){
  const t=terr[idx(i,j)],m=MAP||MAPS.yard;
  if(t===T_WATER||t===T_BRIDGE)return h<.33?'#1d3848':h<.66?'#1f3b4c':'#1b3544';
  if(m===MAPS.river)return t===T_LOW?(h<.5?'#343423':'#2f3021'):h<.2?'#35402a':h<.75?'#303a26':'#2b3322';
  if(m===MAPS.quarry)return h<.2?'#3b3731':h<.75?'#35312c':'#2f2b27';
  return h<.2?'#3d3528':h<.75?'#352e23':'#2f291f';
}
// ground details painted once: bank edges, cracks, gravel
function groundDetail(i,j,h){
  const t=terr[idx(i,j)];
  if(t===T_WATER||t===T_BRIDGE){
    // a soft bank line where water meets land
    g.strokeStyle='rgba(120,150,120,.25)';g.lineWidth=1.2*u;
    for(const[a,b,p,q]of[[1,0,[i+1,j],[i+1,j+1]],[-1,0,[i,j],[i,j+1]],[0,1,[i,j+1],[i+1,j+1]],[0,-1,[i,j],[i+1,j]]]){const n=tAt(i+a,j+b);if(inb(i+a,j+b)&&n!==T_WATER&&n!==T_BRIDGE){const A=iso(p[0],p[1]),B=iso(q[0],q[1]);g.beginPath();g.moveTo(A[0],A[1]);g.lineTo(B[0],B[1]);g.stroke()}}
    return true}
  if(t===T_CRACK){
    g.strokeStyle='rgba(14,11,9,.7)';g.lineWidth=1.1*u;g.beginPath();
    let p=[i+.2+hash(i,j+3)*.2,j+.25+hash(i+9,j)*.2];let A=iso(p[0],p[1]);g.moveTo(A[0],A[1]);
    for(let s=0;s<4;s++){p=[p[0]+.14+hash(i+s,j*3)*.1,p[1]+.1+hash(i*7,j+s)*.12];A=iso(p[0],p[1]);g.lineTo(A[0],A[1])}
    const c=iso(i+.5,j+.5);g.moveTo(c[0],c[1]);const b=iso(i+.3,j+.8);g.lineTo(b[0],b[1]);g.stroke();
    g.strokeStyle='rgba(255,140,60,.12)';g.lineWidth=.8*u;g.stroke();return true}
  if(MAP===MAPS.quarry&&h>.8){const c=iso(i+.3+h*.4,j+.5);oval(c[0],c[1],2.4*u,1.2*u,'rgba(150,140,120,.3)');return true}
  return false;
}
// live ground layer (after the cached back layer, before anything standing): water glints, bridges, floods, pits, ripples
function drawTerrainLive(){
  if(!MAP||(MAP===MAPS.yard&&!terrLog.length))return;
  const t0=game.time;
  if(MAP===MAPS.river){
    // glints drifting downstream
    g.strokeStyle='rgba(150,200,220,.28)';g.lineWidth=1.2*u;g.beginPath();
    for(let k=0;k<N*N;k++){if(terr[k]!==T_WATER)continue;const i=k%N,j=(k/N)|0,h=hash(i+31,j+7),y=(j+((t0*.35+h)%1));
      const a=iso(i+.25+h*.4,y),b=iso(i+.45+h*.4,y);g.moveTo(a[0],a[1]);g.lineTo(b[0],b[1])}
    g.stroke();
    if(floodLv>.02){g.globalAlpha=floodLv*.7;
      for(let k=0;k<N*N;k++){if(terr[k]!==T_LOW)continue;const i=k%N,j=(k/N)|0;quad(iso(i,j),iso(i+1,j),iso(i+1,j+1),iso(i,j+1),'#23475a')}
      g.globalAlpha=1}
    for(let k=0;k<N*N;k++)if(terr[k]===T_BRIDGE)drawBridge(k%N,(k/N)|0);
  }
  for(let q=0;q<terrLog.length;q+=2){const k=terrLog[q];if(terr[k]===T_PIT)drawPit(k%N,(k/N)|0)}
  // ripples round anyone wading
  const rip=e=>{if(!wetT(tAt(Math.floor(e.x),Math.floor(e.y))))return;const c=iso(e.x,e.y),r=(7+Math.sin(t0*6+e.x*3)*1.5)*u;g.strokeStyle='rgba(170,210,230,.45)';g.lineWidth=1*u;g.beginPath();g.ellipse(c[0],c[1],r,r*.5,0,0,Math.PI*2);g.stroke()};
  if(MAP===MAPS.river){for(const e of enemies)if(!e.burrow)rip(e);if(!demo)for(const p of players.values())if(p.alive)rip(p);if(qm.alive)rip(qm)}
}
function drawBridge(i,j){
  const along=tAt(i-1,j)===T_BRIDGE||tAt(i+1,j)===T_BRIDGE||terr[idx(i,j)]===T_BRIDGE&&(tAt(i-1,j)!==T_WATER);
  quad(iso(i,j+.08),iso(i+1,j+.08),iso(i+1,j+.92),iso(i,j+.92),'#5a4330');
  g.strokeStyle='rgba(20,14,8,.6)';g.lineWidth=1*u;g.beginPath();
  for(let s=1;s<6;s++){const a=iso(i+s/6,j+.08),b=iso(i+s/6,j+.92);g.moveTo(a[0],a[1]);g.lineTo(b[0],b[1])}g.stroke();
  for(const y of[j+.08,j+.92]){const a=iso(i,y),b=iso(i+1,y);g.strokeStyle='#2c2016';g.lineWidth=2*u;g.beginPath();g.moveTo(a[0],a[1]-3*u);g.lineTo(b[0],b[1]-3*u);g.stroke()}
  return along;
}
function drawPit(i,j){
  quad(iso(i+.04,j+.04),iso(i+.96,j+.04),iso(i+.96,j+.96),iso(i+.04,j+.96),'#0b0908');
  const a=iso(i+.04,j+.04),b=iso(i+.96,j+.04),d=iso(i+.04,j+.96);
  quad(a,b,[b[0],b[1]+WH*.35],[a[0],a[1]+WH*.35],'#1c1713');quad(a,d,[d[0],d[1]+WH*.35],[a[0],a[1]+WH*.35],'#241d18');
  quad(iso(i+.04,j+.04),iso(i+.96,j+.04),iso(i+.96,j+.96),iso(i+.04,j+.96),'rgba(0,0,0,.35)');
}
// rock and oil drums stand up, so they're depth-sorted with everything else
// rock and drum bodies never change, so each is drawn once into a small sprite (like walls); only the flames are live
const TERR_SPR=new Map();
function itemTerr(k){
  const i=k%N,j=(k/N)|0,t=terr[k],key=t+'|'+i+'|'+j+'|'+N+'|'+TW2+'|'+DPR;let S=TERR_SPR.get(k);
  if(!S||S.key!==key){if(TERR_SPR.size>256)TERR_SPR.clear();const pad=t===T_DRUM?0:0;
    const hz=heightAt(i+.5,j+.5)*heightPx(),x0=Math.floor(((i-j-1)*TW2-4*u)*DPR)/DPR,y0=Math.floor(((i+j)*TH2-hz-WH*1.4-4*u)*DPR)/DPR,x1=(i-j+1)*TW2+4*u,y1=(i+j+2)*TH2-hz+4*u;
    const cv2=document.createElement('canvas');cv2.width=Math.ceil((x1-x0)*DPR);cv2.height=Math.ceil((y1-y0)*DPR);const ctx=cv2.getContext('2d');ctx.setTransform(DPR,0,0,DPR,0,0);
    const kg=g,kx=camX,ky=camY;g=ctx;camX=-x0;camY=-y0;try{terrShape(i,j,t,false)}finally{g=kg;camX=kx;camY=ky}
    S={key,cv:cv2,x:x0,y:y0,w:cv2.width/DPR,h:cv2.height/DPR};TERR_SPR.set(k,S)}
  g.drawImage(S.cv,camX+S.x,camY+S.y,S.w,S.h);
  if(t===T_DRUM)terrShape(i,j,t,true);
}
function terrShape(i,j,t,flames){
  const h=hash(i+3,j+17);
  if(t===T_ROCK){
    boxR(i+.08,j+.12,i+.9,j+.88,0,WH*(.75+h*.3),'#6b655b','#4e4a43','#3c3934');
    boxR(i+.2+h*.2,j+.2,i+.7+h*.2,j+.62,WH*(.75+h*.3),WH*(.25+h*.2),'#787166','#58534b','#45413b');
  }else if(t===T_DRUM){
    const c=iso(i+.5,j+.5),w=TW2*.34,hh=WH*.9;
    if(!flames){oval(c[0],c[1],w*1.2,w*.6,'rgba(0,0,0,.35)');
    g.fillStyle='#3b2f24';g.fillRect(c[0]-w,c[1]-hh,w*2,hh);g.fillStyle='#4d3d2e';g.fillRect(c[0]-w*.35,c[1]-hh,w*.7,hh);
    g.fillStyle='#2a211a';g.fillRect(c[0]-w,c[1]-hh*.66,w*2,2*u);g.fillRect(c[0]-w,c[1]-hh*.33,w*2,2*u);
    oval(c[0],c[1]-hh,w,w*.45,'#1a1411');return}
    // the flame on top: three flickering tongues
    const t0=game.time*9+h*20;
    for(let q=0;q<3;q++){const fx=c[0]+(q-1)*w*.45,fh=(9+Math.sin(t0+q*2.1)*3+q%2*2)*u;g.fillStyle=q===1?'#ffd070':'#ff8a2a';
      g.beginPath();g.moveTo(fx-w*.28,c[1]-hh);g.quadraticCurveTo(fx+Math.sin(t0*1.3+q)*2*u,c[1]-hh-fh*1.2,fx+w*.28,c[1]-hh);g.fill()}
  }
}
