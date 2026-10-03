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
  // streetlamps: every sixth sidewalk tile along a road, leaning out over it (lit while the Power Station holds)
  L.lamps=[];for(let j=0;j<n;j++)for(let i=0;i<n;i++){if(terr[idx(i,j)]!==T_WALK||nodeK.has(idx(i,j)))continue;
    for(const [a,b]of D4)if(tAt(i+a,j+b)===T_ROAD&&(a?j%6===0:i%6===0)){L.lamps.push([i,j,a,b]);break}}
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
  if(cityPad(i,j))return h<.5?'#3d3f42':'#393b3e';   // concrete pads under Main Command and the POIs
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
// on a POI's or Main Command's concrete pad?
function cityPad(i,j){const L=game&&game.lay;if(!L||!L.city)return false;return cityPlaza(i,j,L.city,L.pois)}
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

// ---------- the POI structures (each one a stake in cores, with its own look) ----------
function poiPole(x,y,h,col,w=1.6){const a=iso(x,y,heightAt(x,y));g.strokeStyle=col;g.lineWidth=w*u;g.beginPath();g.moveTo(a[0],a[1]);g.lineTo(a[0],a[1]-h);g.stroke();return[a[0],a[1]-h]}
function poiBar(c,x,y){if(c.lost)return;const near=player&&Math.hypot(player.x-c.i-.5,player.y-c.j-.5)<8,hurt=c.hp<c.max;
  if(c.attack||near)label(c.poi?c.poi.name:'MAIN COMMAND',x,y-10*u,c.attack?'#ff8a6a':'#d8cfb8',10);
  if(c.attack||hurt){const w=38*u,hb=4*u,x0=x-w/2,y0=y-6*u;g.fillStyle='rgba(10,8,6,.85)';g.fillRect(x0-1,y0-1,w+2,hb+2);
    g.fillStyle=c.attack?'#e8573a':'#e2b436';g.fillRect(x0,y0,w*Math.max(0,c.hp/c.max),hb)}}
function drawPoi(c){
  const {i,j}=c,id=c.poi.id,f=c.flash>0,T=(col,hot)=>f?(hot||'#8a4a34'):col,t=game.time;
  if(c.lost){   // a burnt-out shell: low scorched blocks and a little smoke
    boxR(i+.1,j+.15,i+.9,j+.85,0,WH*.35,'#2a2622','#1d1a17','#151311');boxR(i+.2,j+.25,i+.55,j+.6,WH*.35,WH*.3,'#332d27','#231f1b','#1a1714');
    if(Math.random()<.04)emit(i+.5,j+.5,WH*.7,'smoke');return}
  let top;
  if(id==='radio'){   // a lattice mast on a block, with a blinking light
    boxR(i+.15,j+.15,i+.85,j+.85,0,WH*.5,T('#5a5f63'),T('#43474a'),T('#33363a'));
    const b=iso(i+.5,j+.5,heightAt(i+.5,j+.5)),H=WH*3.4,bx=b[0],by=b[1]-WH*.5;g.strokeStyle=T('#8a8f93','#a05a40');g.lineWidth=1.4*u;g.beginPath();
    for(const s of[-1,1]){g.moveTo(bx+s*9*u,by);g.lineTo(bx+s*1.5*u,by-H)}
    for(let q=0;q<7;q++){const y0=by-H*q/7,y1=by-H*(q+1)/7,w0=9*u*(1-q/7)+1.5*u*q/7,w1=9*u*(1-(q+1)/7)+1.5*u*(q+1)/7;g.moveTo(bx-w0,y0);g.lineTo(bx+w1,y1);g.moveTo(bx+w0,y0);g.lineTo(bx-w1,y1)}
    g.stroke();top=[bx,by-H];if(Math.sin(t*4)>0){g.fillStyle='#ff4a3a';g.beginPath();g.arc(bx,by-H,2.6*u,0,Math.PI*2);g.fill()}}
  else if(id==='power'){   // transformer block, a cooling stack, and sparks
    boxR(i-.15,j+.2,i+.6,j+.95,0,WH*.9,T('#4d5a52'),T('#38423c'),T('#2b332e'));
    for(let q=0;q<3;q++)boxR(i+.62,j+.1+q*.28,i+.88,j+.3+q*.28,0,WH*.55,T('#6b6f5a'),T('#505442'),T('#3d4033'));
    const s=iso(i+.25,j+.15,heightAt(i+.5,j+.5));for(let q=0;q<5;q++){const r=(9-q*.6)*u;oval(s[0],s[1]-q*WH*.4,r,r*.45,T(q%2?'#7a7c78':'#6a6c68'))}
    oval(s[0],s[1]-WH*2,8*u,3.6*u,'#2a2b2a');top=[s[0],s[1]-WH*2.1];
    if(Math.random()<.08){const p=iso(i+.75,j+.5,heightAt(i+.5,j+.5));g.strokeStyle='#bfe6ff';g.lineWidth=1.2*u;g.beginPath();g.moveTo(p[0],p[1]-WH*.6);g.lineTo(p[0]+4*u,p[1]-WH*.8);g.lineTo(p[0]-2*u,p[1]-WH*.95);g.stroke()}}
  else if(id==='hospital'){   // a white block with a red cross on the roof
    const {A,B,C,D}=boxR(i-.25,j-.25,i+1.15,j+1.15,0,WH*1.5,T('#d9dad4'),T('#b9bbb4'),T('#9c9e98'));
    const m=lerp2(lerp2(A,C,.5),lerp2(B,D,.5),.5),cy=m[1]-WH*1.5;g.fillStyle='#d23a32';
    const k=6*u;g.fillRect(m[0]-k*1.6,cy-k*.3,k*3.2,k*.6);g.fillRect(m[0]-k*.4,cy-k*.9,k*.8,k*1.8);
    for(let q=0;q<3;q++){const p=lerp2(D,C,.2+q*.3);g.fillStyle='rgba(120,190,220,.7)';g.fillRect(p[0]-2*u,p[1]-WH*1.05,4*u,5*u)}top=[m[0],cy]}
  else if(id==='armory'){   // fenced compound with crate stacks
    for(const [x,y,h]of[[.1,.15,.5],[.5,.15,.8],[.1,.55,.8],[.5,.55,.5],[.3,.35,1.2]])boxR(i+x,j+y,i+x+.38,j+y+.36,0,WH*h,T('#59633d'),T('#434b2e'),T('#343a24'));
    for(const [x,y]of[[-.2,-.2],[1.2,-.2],[1.2,1.2],[-.2,1.2]])poiPole(i+x,j+y,WH*.9,T('#77736a'),1.2);
    const c0=iso(i+.5,j+.5,heightAt(i+.5,j+.5));top=[c0[0],c0[1]-WH*1.3];g.fillStyle='#e2b436';g.fillRect(top[0]-5*u,top[1]+WH*.2,10*u,3*u)}
  else if(id==='gas'){   // canopy on posts over a pump, and a little shop
    boxR(i+.45,j-.2,i+1.1,j+.45,0,WH*.8,T('#6a5f52'),T('#524a40'),T('#3f3931'));
    boxR(i+.2,j+.4,i+.38,j+.6,0,WH*.6,T('#c64a36'),T('#9e3a2a'),T('#7a2d20'));
    for(const [x,y]of[[-.1,.2],[.7,.2],[.7,1],[-.1,1]])poiPole(i+x,j+y,WH*1.25,T('#9a9890'),1.4);
    boxR(i-.15,j+.15,i+.75,j+1.05,WH*1.25,WH*.15,T('#e8e2d0'),T('#c63a2e'),T('#a02e24'));const c0=iso(i+.3,j+.6,heightAt(i+.5,j+.5));top=[c0[0],c0[1]-WH*1.45]}
  else if(id==='hardware'){   // big-box store with an orange band and a lumber stack
    const {D,C}=boxR(i-.2,j-.2,i+.9,j+.75,0,WH*1.1,T('#5b5953'),T('#47453f'),T('#383631'));
    quad(up(D,WH*.8),up(C,WH*.8),up(C,WH*1),up(D,WH*1),'#d8752a');
    for(let q=0;q<3;q++)boxR(i+.1,j+.8+q*.0,i+.9,j+.95,q*WH*.12,WH*.11,T('#a8834f'),T('#87683d'),T('#6b5230'));const c0=iso(i+.35,j+.3,heightAt(i+.5,j+.5));top=[c0[0],c0[1]-WH*1.1]}
  else if(id==='brick'){   // a kiln yard: a squat kiln and a tall chimney with a glow
    boxR(i+.05,j+.25,i+.8,j+.95,0,WH*.8,T('#8a4a34'),T('#6e3a28'),T('#55301f'));boxR(i+.5,j+.05,i+.75,j+.3,0,WH*2.4,T('#7a3e2c'),T('#5e3022'),T('#4a261b'));
    const c0=iso(i+.62,j+.18,heightAt(i+.5,j+.5));oval(c0[0],c0[1]-WH*2.4,3*u,1.4*u,'rgba(255,140,60,.8)');top=[c0[0],c0[1]-WH*2.5];
    const m=iso(i+.4,j+.6,heightAt(i+.5,j+.5));g.fillStyle='rgba(255,150,70,.7)';g.fillRect(m[0]-3*u,m[1]-WH*.4,6*u,4*u)}
  else{   // parking garage: three concrete decks on pillars
    for(let q=0;q<3;q++){const z=q*WH*.75;boxR(i-.2,j-.2,i+1.2,j+1.2,z+WH*.6,WH*.15,T('#6f716e'),T('#585a57'),T('#474946'));
      if(q<2)for(const [x,y]of[[-.1,1.1],[1.1,1.1],[1.1,-.1],[.5,1.1],[1.1,.5]])boxR(i+x-.05,j+y-.05,i+x+.05,j+y+.05,z+WH*.75,WH*.6,'#5a5c59','#4a4c49','#3c3e3b')}
    const c0=iso(i+.5,j+.5,heightAt(i+.5,j+.5));top=[c0[0],c0[1]-WH*2.3];g.fillStyle='#e2b436';g.font=`bold ${9*u}px sans-serif`;g.textAlign='center';g.fillText('P',top[0],top[1]+WH*.2)}
  poiBar(c,top[0],top[1]-4*u);
}
// streetlamps (queued only when on screen)
function drawLamp(l){const [i,j,a,b]=l,on=!game.dark;const x=i+.5+a*.38,y=j+.5+b*.38,p=poiPole(x,y,WH*1.7,'#3e4245',1.6);
  const q=iso(x+a*.3,y+b*.3,heightAt(x,y));const h=[q[0],q[1]-WH*1.75];g.strokeStyle='#3e4245';g.lineWidth=1.4*u;g.beginPath();g.moveTo(p[0],p[1]);g.lineTo(h[0],h[1]);g.stroke();
  oval(h[0],h[1]+1.5*u,3*u,1.6*u,on?'#ffe7a8':'#2a2c2e')}
function cityLampItems(){const L=game.lay;if(!L||!L.lamps)return;
  for(const l of L.lamps){const c=iso(l[0]+.5,l[1]+.5);if(c[0]<-40||c[0]>W+40||c[1]<-40||c[1]>H+WH*3)continue;ritem(l[0]+l[1]+1,drawLamp,l)}}
// the city's light pools: Main Command's floodlights always, a held POI's lights (a lost one flickers out), and the
// streetlamps while the Power Station holds
function cityLights(hole,at){
  const vis=(c,m=120)=>c[0]>-m&&c[0]<W+m&&c[1]>-m&&c[1]<H+m;
  for(const k of cores){const c=at(k.i+.5,k.j+.5,WH);if(!vis(c,TW2*5))continue;
    if(!k.poi){hole(c[0],c[1],TW2*4.4,.95);continue}
    let s=k.poi.major?.9:.8;if(k.lost){const d=game.time-(k.lostAt||-9);if(d>1.6)continue;s*=(1-d/1.6)*(Math.sin(d*40)>0?1:.15)}
    hole(c[0],c[1],TW2*(k.poi.major?3.8:3),s)}
  if(game.dark)return;const L=game.lay;if(!L||!L.lamps)return;
  for(const l of L.lamps){const c=at(l[0]+.5+l[2]*.7,l[1]+.5+l[3]*.7);if(vis(c))hole(c[0],c[1],TW2*1.9,.6)}
}
