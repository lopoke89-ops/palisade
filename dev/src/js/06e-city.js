/* ================= v0.9.7 City Black Out: the ruined city ================= */
// A 64×64 night city (48×48 is the fallback size): Main Command in a plaza at the centre, an inner ring road round it,
// four avenues out to the major POIs, an outer ring road through the four minor POIs, and ruined blocks in between.
// Everything is laid out from fixed numbers and hash(), so the host and every guest build the same city.
const T_ROAD=8,T_WALK=9,T_RUBBLE=10,T_BLDG=11;
const CITY={size:64,fallback:48,roadSpeed:1.35,rubbleSpeed:.8};
let CITY_N=CITY.size;   // set to CITY.fallback if the big map doesn't hold up (Phase 0 gate)
// [id, name, major, perk, what the perk does]
const CITY_POIS=[
  ['radio','RADIO TOWER',1,'warn','Warns which point is hit next, 15 s ahead (3 s without it).'],
  ['power','POWER STATION',1,'lights','Lights the roads. If it falls the whole city goes darker.'],
  ['hospital','HOSPITAL',1,'heal','Heals 3 HP a second within 5 tiles; teammates get up 50% faster there.'],
  ['armory','ARMORY DEPOT',1,'refill','A grenade and a rocket back every 30 s for everyone.'],
  ['gas','GAS STATION',0,'salvage','+25% salvage from kills nearby.'],
  ['hardware','HARDWARE STORE',0,'wood','Extra wood and metal piles that refill.'],
  ['brick','BRICK WORKS',0,'brick','Extra brick piles that refill.'],
  ['garage','PARKING GARAGE',0,'range','High ground: +2 tiles of range for anyone on it.']];
const cityGeo=n=>{const C=n>>1,ri=Math.round(n*.1),ro=Math.round(n*.25),rm=Math.round(n*.34);
  return{C,ri,ro,rm,maj:[[C,C-rm],[C+rm,C],[C,C+rm],[C-rm,C]],min:[[C-ro,C-ro],[C+ro,C-ro],[C+ro,C+ro],[C-ro,C+ro]]}};
// on a road tile? (two tiles wide: the inner ring, the outer ring, and the four avenues from the inner ring to the edge)
function cityRoad(i,j,G){const dx=Math.abs(i+.5-G.C),dy=Math.abs(j+.5-G.C),m=Math.max(dx,dy);
  if(m>=G.ri-1&&m<=G.ri+1&&m>G.ri-1)return true;   // inner ring
  if(m>G.ro-1&&m<=G.ro+1)return true;               // outer ring
  if(m>G.ri&&(dx<=1||dy<=1))return true;            // avenues
  return false}
const cityPlaza=(i,j,G,pois)=>{if(Math.max(Math.abs(i+.5-G.C),Math.abs(j+.5-G.C))<G.ri-1)return true;
  for(const p of pois){const r=p.major?3.5:2.5;if(Math.abs(i+.5-p.i-.5)<r&&Math.abs(j+.5-p.j-.5)<r)return true}return false};
function layCity(){
  const n=N,G=cityGeo(n),L={core:[G.C,G.C],nodes:[],ruins:[],pois:[],city:G};
  // which POI goes where: majors on the avenues, minors on the outer ring's corners
  let mi=0,ni=0;for(const [id,name,major,perk,what]of CITY_POIS){const at=major?G.maj[mi++]:G.min[ni++];L.pois.push({id,name,major:!!major,perk,what,i:at[0],j:at[1]})}
  const nodeK=new Set();const node=x=>{if(!inb(x.i,x.j))return;const k=idx(x.i,x.j);if(nodeK.has(k))return;nodeK.add(k);L.nodes.push(x)};
  for(let j=0;j<n;j++)for(let i=0;i<n;i++){const k=idx(i,j);
    if(cityRoad(i,j,G)){terr[k]=T_ROAD;continue}
    if(cityPlaza(i,j,G,L.pois)||i<2||j<2||i>=n-2||j>=n-2)continue;   // plazas and the edge strip stay open ground
    // the blocks: 4×4 cells, a 3×3 building in most of them, one-tile alleys between; ruined corners become rubble
    const cx=Math.floor(i/4),cy=Math.floor(j/4),h=hash(cx*7+3,cy*13+5);
    if(h>.32&&i%4<3&&j%4<3){terr[k]=hash(i*3+1,j*5+2)>.87?T_RUBBLE:T_BLDG;continue}
    if(hash(i+51,j+17)>.9)terr[k]=T_RUBBLE}
  // sidewalks along every road, where the ground is open
  for(let j=0;j<n;j++)for(let i=0;i<n;i++){const k=idx(i,j);if(terr[k]!==T_GROUND)continue;
    for(const [a,b]of D4)if(tAt(i+a,j+b)===T_ROAD){terr[k]=T_WALK;break}}
  // parks: open lots off the roads get a wood pile
  for(let cy=1;cy<n/4-1;cy++)for(let cx=1;cx<n/4-1;cx++){if(hash(cx*7+3,cy*13+5)>.32)continue;const i=cx*4+1,j=cy*4+1;
    if(terr[idx(i,j)]===T_GROUND&&!cityPlaza(i,j,G,L.pois))node({i,j,type:0,amt:48,max:48,rt:0,locked:false})}
  // Main Command's supply: a kiln and a scrap pile just off the plaza; the Brick Works and the Hardware Store add more
  node({i:G.C-2,j:G.C+2,type:1,locked:false,unlock:0,solid:true});node({i:G.C+2,j:G.C-2,type:2,locked:false,unlock:0,solid:true});
  for(const p of L.pois){if(p.perk==='brick'){node({i:p.i-1,j:p.j+1,type:1,locked:false,unlock:0,solid:true});node({i:p.i+1,j:p.j+1,type:1,locked:false,unlock:0,solid:true})}
    if(p.perk==='wood'){node({i:p.i-1,j:p.j+1,type:2,locked:false,unlock:0,solid:true});node({i:p.i+1,j:p.j-1,type:0,amt:48,max:48,rt:0,locked:false})}}
  // sandbag walls: a broken ring round Main Command's plaza, and a few round each major POI
  const used=new Set([...nodeK,idx(G.C,G.C),...L.pois.map(p=>idx(p.i,p.j))]);   // never on a pile, a stake or another sandbag
  const ring=(ci,cj,r)=>{const out=[];for(let a=-r;a<=r;a++)for(const [i,j]of[[ci+a,cj-r],[ci+a,cj+r],[ci-r,cj+a],[ci+r,cj+a]]){const k=idx(i,j);
    if(used.has(k)||hash(i*9+1,j*3+7)<=.45||terr[k]!==T_GROUND)continue;used.add(k);out.push([i,j])}return out};
  L.ruins.push([ring(G.C,G.C,2),1,.8,0]);for(const p of L.pois)if(p.major)L.ruins.push([ring(p.i,p.j,2),1,.6,0]);
  // raiders come in along the four edges; each attack uses the edge nearest its POI
  const edge=side=>{const out=[];for(let s=3;s<n-3;s++)out.push(side==='n'?[s,0]:side==='s'?[s,n-1]:side==='w'?[0,s]:[n-1,s]);return out};
  L.edges={n:edge('n'),e:edge('e'),s:edge('s'),w:edge('w')};
  L.spawns=[{w:.25,tiles:L.edges.n},{w:.25,tiles:L.edges.e},{w:.25,tiles:L.edges.s},{w:.25,tiles:L.edges.w}];
  L.bossAt=L.edges.e;
  return L;
}
// the nearest edge to a point (attack spawns)
function cityEdgeFor(i,j){const n=N,d={n:j,s:n-1-j,w:i,e:n-1-i};return Object.keys(d).sort((a,b)=>d[a]-d[b])[0]}

// ---------- drawing ----------
const isCity=()=>!!(MAP&&MAP.city);
function cityGroundCol(i,j,h){const t=terr[idx(i,j)];
  if(t===T_ROAD)return h<.5?'#1e2023':'#202226';
  if(t===T_WALK)return h<.5?'#3a3a38':'#363634';
  if(t===T_RUBBLE)return h<.5?'#3b342c':'#352f28';
  if(t===T_BLDG)return '#1a1a1c';
  return h<.2?'#2c2a26':h<.75?'#282622':'#24221f'}
function cityGroundDetail(i,j,h){const t=terr[idx(i,j)];
  if(t===T_ROAD){   // dashed centre lines where two road lanes meet
    const G=game&&game.lay&&game.lay.city;if(!G)return true;g.strokeStyle='rgba(220,190,90,.32)';g.lineWidth=1.2*u;g.beginPath();
    if(tAt(i+1,j)===T_ROAD&&tAt(i-1,j)!==T_ROAD&&j%2===0){const a=iso(i+1,j+.2),b=iso(i+1,j+.8);g.moveTo(a[0],a[1]);g.lineTo(b[0],b[1])}
    if(tAt(i,j+1)===T_ROAD&&tAt(i,j-1)!==T_ROAD&&i%2===0){const a=iso(i+.2,j+1),b=iso(i+.8,j+1);g.moveTo(a[0],a[1]);g.lineTo(b[0],b[1])}
    g.stroke();return true}
  if(t===T_RUBBLE){for(let q=0;q<3;q++){const c=iso(i+.2+hash(i+q,j)*.6,j+.2+hash(i,j+q)*.6);oval(c[0],c[1],(2+q)*u,(1+q*.5)*u,q%2?'#5a5048':'#4a423a')}return true}
  if(t===T_WALK){g.strokeStyle='rgba(0,0,0,.18)';g.lineWidth=u;g.beginPath();const a=iso(i,j+.5),b=iso(i+1,j+.5);g.moveTo(a[0],a[1]);g.lineTo(b[0],b[1]);g.stroke();return true}
  return t===T_BLDG}
// a ruined building tile, drawn from a small set of shared sprites (5 heights × 4 face shapes × 3 colours × 4 window
// patterns): one image copy a tile instead of three faces and four windows, so a screenful of city stays cheap
const BLD_SPR=new Map();
function cityBuildingSprite(hb,mask,pal,win){
  const key=hb+'|'+mask+'|'+pal+'|'+win+'|'+TW2+'|'+DPR;let S=BLD_SPR.get(key);if(S)return S;
  if(BLD_SPR.size>300)BLD_SPR.clear();
  const H=WH*(.85+hb*.225),pad=2*u,w=TW2*2+pad*2,h=H+TH2*2+pad*2,sc=Math.min(DPR,2),cv2=document.createElement('canvas');
  cv2.width=Math.ceil(w*sc);cv2.height=Math.ceil(h*sc);const ctx=cv2.getContext('2d');ctx.setTransform(sc,0,0,sc,0,0);
  const kg=g,kx=camX,ky=camY;g=ctx;camX=TW2+pad;camY=H+pad;   // the tile's north corner sits here
  try{
    const wall=[['#3e4246','#303438','#26292c'],['#4b4239','#3b342d','#2e2924'],['#4a4744','#3a3735','#2d2b29']][pal];
    const A=iso(0,1),B=iso(1,1),C=iso(1,0),D=iso(0,0);
    if(mask&1)quad(A,B,[B[0],B[1]-H],[A[0],A[1]-H],wall[1]);
    if(mask&2)quad(B,C,[C[0],C[1]-H],[B[0],B[1]-H],wall[2]);
    quad([D[0],D[1]-H],[C[0],C[1]-H],[B[0],B[1]-H],[A[0],A[1]-H],wall[0]);
    if(mask&1)for(let r=0;r<2;r++)for(let q=0;q<2;q++){const lit=((win>>(r*2+q))&1)&&win===3,x=A[0]+(B[0]-A[0])*(.2+q*.45),y=A[1]+(B[1]-A[1])*(.2+q*.45)-H*(.35+r*.3);
      g.fillStyle=lit?'rgba(255,210,120,.55)':'rgba(10,10,12,.75)';g.fillRect(x,y,4*u,4*u)}
  }finally{g=kg;camX=kx;camY=ky}
  S={cv:cv2,ox:TW2+pad,oy:H+pad,w,h};BLD_SPR.set(key,S);return S;
}
function cityBuilding(i,j,baked=false){
  const cx=Math.floor(i/4),cy=Math.floor(j/4),hbv=hash(cx*7+3,cy*13+5),hb=Math.min(4,Math.floor(hbv*5))-(hash(i*3+1,j*5+2)>.8?1:0),
    mask=(tAt(i,j+1)!==T_BLDG?1:0)|(tAt(i+1,j)!==T_BLDG?2:0),pal=hbv>.7?2:hbv>.5?1:0,win=Math.floor(hash(i*5,j*7)*4),S=cityBuildingSprite(Math.max(0,hb),mask,pal,win);
  const p=player,dd=i+j+1-(p.x+p.y),lat=(i-j)-(p.x-p.y),fade=!baked&&!demo&&dd>0&&dd<4.5&&Math.abs(lat)<2.6,c=iso(i,j),z=heightAt(i+.5,j+.5)*heightPx();
  if(fade)g.globalAlpha=.32;g.drawImage(S.cv,c[0]-S.ox,c[1]-z-S.oy,S.w,S.h);if(fade)g.globalAlpha=1;
}

// the city as a map entry (not in MAP_IDS: it isn't on the map picker; the City Black Out mode chooses it)
MAPS.city={name:'THE CITY',short:'City',city:true,night:true,hp:1,col:'#8f9aa8',from:'from every edge',bosses:['butcher','demolisher','storm','ferryman','foreman'],
  blurb:'A ruined city in a blackout. Eight points to hold, then Main Command.',lay(){return layCity()}};

// every building, back to front, into the painted city (chunk painting skips the ones outside the chunk)
function paintCityBuildings(){
  forTiles(0,N,paintRange(0,N,WH*2.4),(i,j)=>{if(terr[idx(i,j)]===T_BLDG)cityBuilding(i,j,true)});   // back to front
}
// the building tiles standing in front of anyone on screen are drawn again over them, at the right depth
const CITY_OCC=new Set();
function cityOccluders(){
  CITY_OCC.clear();
  const look=(x,y)=>{const ci=Math.floor(x),cj=Math.floor(y);
    for(let a=0;a<=3;a++)for(let b=0;b<=3;b++){const i=ci+a,j=cj+b;if(!inb(i,j))continue;const k=idx(i,j);if(terr[k]!==T_BLDG||CITY_OCC.has(k))continue;
      const dd=i+j+1-(x+y),lat=(i-j)-(x-y);if(dd>0&&dd<3.8&&Math.abs(lat)<1.8)CITY_OCC.add(k)}};
  const onScreen=(x,y)=>{const c=iso(x,y);return c[0]>-60&&c[0]<W+60&&c[1]>-80&&c[1]<H+80};
  if(!demo)for(const p of players.values())if((p.alive||p.downed)&&onScreen(p.x,p.y))look(p.x,p.y);
  if(qm.alive&&onScreen(qm.x,qm.y))look(qm.x,qm.y);
  for(const e of enemies)if(onScreen(e.x,e.y))look(e.x,e.y);
  for(const s of sacks)if(onScreen(s.x,s.y))look(s.x,s.y);
  for(const k of CITY_OCC)ritem((k%N)+((k/N)|0)+1,itemTerr,k);
}
