/* ================= THE UNDERSTRIP: how the tunnels look ================= */
// Floors are painted into the cached ground like any map. Tunnel walls are drawn standing only where they face open ground
// (US_EDGE), from a few shared block sprites (the projection is the same everywhere, so one sprite serves every tile); walls
// on the camera side of you draw low, so a one-tile corridor never hides you, the raiders or a telegraph. Light comes from
// you: a cone where you aim and a small glow, plus the level's lamps, neon, shrines and flares. Raiders carry no light.
const US_LOOK={wallH:1.15,lowH:.32,cone:[[.7,.88],[1.5,1.16],[2.4,1.43],[3.4,1.65],[4.5,1.82],[5.4,1.76]],glow:1.76};   // v0.12.1: the cone and glow 10% wider (playtest: too dark)
function usGroundCol(i,j,h){const t=terr[idx(i,j)],z=US_HAZ[idx(i,j)];
  if(t===T_CONC||t===T_TANK||t===T_SHUT&&z!==HZ_BLAST)return'#0b0c0b';
  if(t===T_WATER)return h<.5?'#16303c':'#142b36';
  if(t===T_BRIDGE)return'#4a463c';
  if(usRegion()>1||z)return usRegGround(i,j,h);   // Shelter 7, Area 67 and the hazard floors (10k)
  if(t===T_LOW)return h<.33?'#2c3532':h<.66?'#2a322f':'#28302d';
  return h<.2?'#30322d':h<.75?'#2c2e29':'#292b26'}
// the floor's own detail: cracks, puddles, the odd stain of graffiti on the floor's edge
function usGroundDetail(i,j,h){const t=terr[idx(i,j)];if(t!==T_GROUND&&t!==T_LOW)return true;
  if(usRegion()>1||US_HAZ[idx(i,j)]){usRegDetail(i,j,h);return true}
  if(h>.9){const c=iso(i+.3+h*.4,j+.5);g.strokeStyle='rgba(15,15,14,.5)';g.lineWidth=u;g.beginPath();g.moveTo(c[0]-4*u,c[1]);g.lineTo(c[0]+2*u,c[1]-u);g.lineTo(c[0]+5*u,c[1]+u);g.stroke()}
  else if(h<.06){const c=iso(i+.5,j+.5);oval(c[0],c[1],8*u,3*u,'rgba(40,70,80,.35)');if(h<.03)oval(c[0]+u,c[1],5*u,1.6*u,h<.015?'rgba(255,90,216,.22)':'rgba(79,210,255,.2)')}   // v0.12.1: neon from the grates caught in the puddles
  else if(h>.8&&h<.83){const c=iso(i+.5,j+.5);oval(c[0],c[1],7*u,2.6*u,['rgba(255,90,216,.16)','rgba(255,210,58,.14)','rgba(124,255,107,.13)'][(i+j)%3])}   // spilt paint
  return true}
// one block, drawn with the camera at the origin, reused for every tile (key: kind, height, size)
const US_SPR=new Map();
function usBlock(kind,low,v=0){const reg=usRegion(),key=kind+'|'+(low?1:0)+'|'+TW2+'|'+DPR+'|'+reg+'|'+v;let S=US_SPR.get(key);if(S)return S;const WC=US_REG[reg].wall;
  const hh=WH*(low?US_LOOK.lowH:kind==='junk'?.62:kind==='tank'?1.3:US_LOOK.wallH),pad=4*u,x0=Math.floor((-TW2-pad)*DPR)/DPR,y0=Math.floor((-hh-pad)*DPR)/DPR,x1=TW2+pad,y1=2*TH2+pad;
  const cv2=document.createElement('canvas');cv2.width=Math.ceil((x1-x0)*DPR);cv2.height=Math.ceil((y1-y0)*DPR);const ctx=cv2.getContext('2d');ctx.setTransform(DPR,0,0,DPR,0,0);
  const kg=g,kx=camX,ky=camY,hp=heightPreview;g=ctx;camX=-x0;camY=-y0;heightPreview=true;
  try{
    if(kind==='wall'){const T=boxR(0,0,1,1,0,hh,low?WC[3]:WC[0],WC[1],WC[2]);g.strokeStyle='rgba(190,196,180,.28)';g.lineWidth=u;g.beginPath();g.moveTo(T.D[0],T.D[1]-hh);g.lineTo(T.C[0],T.C[1]-hh);g.lineTo(T.B[0],T.B[1]-hh);g.stroke();
      if(!low){g.strokeStyle='rgba(0,0,0,.35)';g.lineWidth=u;faceLine(iso(0,1),iso(1,1),hh,.35);faceLine(iso(1,1),iso(1,0),hh,.35);faceLine(iso(0,1),iso(1,1),hh,.7);faceLine(iso(1,1),iso(1,0),hh,.7);
        g.strokeStyle='rgba(120,150,150,.18)';faceLine(iso(0,1),iso(1,1),hh,.1);   // concrete courses and a flood line
        if(reg===1&&v)usGraffiti(v,hh);   // v0.12.1: the Flood Tunnels' tags
        if(reg===2){g.strokeStyle='rgba(208,120,42,.5)';g.lineWidth=2*u;faceLine(iso(0,1),iso(1,1),hh,.5);faceLine(iso(1,1),iso(1,0),hh,.5)}   // Shelter 7's orange band
        if(reg===3){g.strokeStyle='rgba(124,255,107,.25)';g.lineWidth=1.4*u;const a=iso(.2,1),b=iso(.5,1);g.beginPath();g.moveTo(a[0],a[1]-hh*.2);g.quadraticCurveTo(a[0]+3*u,a[1]-hh*.5,b[0],b[1]-hh*.8);g.stroke()}}}   // growth up the lab wall
    else if(kind==='blast'){boxR(0,0,1,1,0,hh,'#5a5c50','#454738','#36382c');g.fillStyle='#d0782a';for(let q=0;q<4;q++){const a=iso(q/4,1),b=iso((q+.5)/4,1);g.beginPath();g.moveTo(a[0],a[1]-hh*.15);g.lineTo(b[0],b[1]-hh*.15);g.lineTo(b[0],b[1]-hh*.3);g.lineTo(a[0],a[1]-hh*.3);g.closePath();g.fill()}}
    else if(kind==='tank'){const c=iso(.5,.5);g.fillStyle='#2a3238';g.beginPath();g.ellipse(c[0],c[1],TW2*.42,TH2*.42,0,0,Math.PI*2);g.fill();
      g.fillStyle='rgba(90,220,170,.42)';g.fillRect(c[0]-TW2*.36,c[1]-hh,TW2*.72,hh);g.fillStyle='rgba(20,40,40,.55)';g.beginPath();g.ellipse(c[0],c[1]-hh*.55,TW2*.12,hh*.22,0,0,Math.PI*2);g.fill();   // the shape inside
      g.strokeStyle='rgba(220,255,240,.5)';g.lineWidth=u;g.strokeRect(c[0]-TW2*.36,c[1]-hh,TW2*.72,hh);g.fillStyle='#3a444c';g.fillRect(c[0]-TW2*.4,c[1]-hh-3*u,TW2*.8,4*u);g.fillRect(c[0]-TW2*.4,c[1]-2*u,TW2*.8,4*u)}
    else if(kind==='door'){boxR(.08,.08,.92,.92,0,hh,'#5a3a24','#6b4228','#4e301c');g.fillStyle='#2a1a10';const c=iso(.5,1);g.fillRect(c[0]-6*u,c[1]-hh*.6,4*u,3*u)}
    else if(kind==='gate'){boxR(.05,.05,.95,.95,0,hh,'#3a1612','#5a1c16','#46140f');g.strokeStyle='#ff5a3a';g.lineWidth=1.4*u;for(let q=1;q<5;q++){const a=iso(q/5,1),b=iso(1,q/5);g.beginPath();g.moveTo(a[0],a[1]);g.lineTo(a[0],a[1]-hh);g.stroke();g.beginPath();g.moveTo(b[0],b[1]);g.lineTo(b[0],b[1]-hh);g.stroke()}}
    else if(reg===2){boxR(.14,.18,.86,.82,0,hh*.8,'#5d6236','#4a4e2c','#3a3e22');g.fillStyle='#d0782a';const c=iso(.5,.82);g.fillRect(c[0]-6*u,c[1]-hh*.5,12*u,2.4*u)}   // a ration crate
    else if(reg===3){boxR(.16,.2,.84,.8,0,hh*.75,'#d8dde0','#b0b6ba','#8c9296');g.fillStyle='#3aa0d0';const c=iso(.5,.8);g.fillRect(c[0]-5*u,c[1]-hh*.45,10*u,2*u)}   // a lab cart
    else{boxR(.18,.2,.82,.8,0,hh,'#4b4f58','#3a3d46','#2c2f36');const c=iso(.5,.8);g.fillStyle='#1a1c22';g.fillRect(c[0]-5*u,c[1]-hh*.78,10*u,6*u);g.fillStyle='rgba(255,90,216,.5)';g.fillRect(c[0]-4*u,c[1]-hh*.75,8*u,4*u)}   // a dumped slot machine
  }finally{g=kg;camX=kx;camY=ky;heightPreview=hp}
  S={cv:cv2,x:x0,y:y0,w:cv2.width/DPR,h:cv2.height/DPR};if(US_SPR.size>48)US_SPR.clear();US_SPR.set(key,S);return S}
// v0.12.1: graffiti on the Flood Tunnels' walls (our own abstract tags: no words, no real crews). v 1-3 picks the style;
// a point on a face: s along it (0-1), f up it (0-1); the left face runs iso(0,1)→iso(1,1), the right iso(1,1)→iso(1,0)
const US_TAG=['#ff5ad8','#4fd2ff','#ffd23a','#7cff6b','#ff8a3a','#b98cff'];
function usGraffiti(v,hh){const L=(s,f)=>{const a=iso(0,1),b=iso(1,1);return[a[0]+(b[0]-a[0])*s,a[1]+(b[1]-a[1])*s-hh*f]},R=(s,f)=>{const a=iso(1,1),b=iso(1,0);return[a[0]+(b[0]-a[0])*s,a[1]+(b[1]-a[1])*s-hh*f]};
  const path=(F,pts)=>{g.beginPath();pts.forEach(([s,f],n)=>{const p=F(s,f);n?g.lineTo(p[0],p[1]):g.moveTo(p[0],p[1])})};g.lineCap='round';g.lineJoin='round';
  if(v===1){   // a bubble tag: a fat pink loop with a cyan outline and a highlight
    const P=[[.14,.32],[.24,.62],[.36,.34],[.46,.6],[.58,.3],[.7,.58],[.84,.36]];g.strokeStyle='rgba(79,210,255,.75)';g.lineWidth=5.4*u;path(L,P);g.stroke();
    g.strokeStyle='rgba(255,90,216,.85)';g.lineWidth=3.4*u;path(L,P);g.stroke();g.strokeStyle='rgba(255,240,250,.55)';g.lineWidth=.9*u;path(L,P.slice(1,4).map(([s,f])=>[s,f+.04]));g.stroke()}
  else if(v===2){   // a yellow zigzag with drips, and an orange underline
    const P=[[.12,.62],[.26,.42],[.4,.66],[.54,.4],[.68,.64],[.84,.44]];g.strokeStyle='rgba(255,210,58,.85)';g.lineWidth=2.6*u;path(R,P);g.stroke();
    g.lineWidth=1.2*u;for(const s of[.26,.54,.84]){path(R,[[s,P.find(q=>q[0]===s)[1]],[s,P.find(q=>q[0]===s)[1]-.2-s*.12]]);g.stroke()}
    g.strokeStyle='rgba(255,138,58,.75)';g.lineWidth=1.8*u;path(R,[[.1,.3],[.88,.3]]);g.stroke()}
  else{   // a green star and a violet scrawl across both faces
    const c=L(.3,.5),r=hh*.16,pts=[];for(let k=0;k<10;k++){const a=-Math.PI/2+k*Math.PI/5,rr=k%2?r*.45:r;pts.push([c[0]+Math.cos(a)*rr*1.3,c[1]+Math.sin(a)*rr])}
    g.fillStyle='rgba(124,255,107,.7)';g.beginPath();pts.forEach((p,n)=>n?g.lineTo(p[0],p[1]):g.moveTo(p[0],p[1]));g.closePath();g.fill();
    g.strokeStyle='rgba(185,140,255,.8)';g.lineWidth=2.2*u;path(L,[[.55,.62],[.66,.38],[.78,.6],[.9,.4]]);g.stroke();path(R,[[.06,.42],[.2,.62],[.34,.36],[.5,.56]]);g.stroke()}
  g.lineCap='butt';g.lineJoin='miter'}
const US_GATE=new Set();
// which walls carry a tag (region 1, standing walls only): about 3 in 5, a style from the tile's own hash
const usTagOf=k=>{let h=(k*2654435761)>>>0;h^=h>>>15;h=Math.imul(h,2246822519)>>>0;h^=h>>>13;const n=h%5;return n<2?0:n-1};
function itemUsWall(k,cut){const i=k%N,j=(k/N)|0,t=terr[k],kind=t===T_JUNK?'junk':t===T_TANK?'tank':t===T_SHUT?(US_GATE.has(k)?'gate':US_HAZ[k]===HZ_BLAST?'blast':'door'):'wall',low=cut&&(kind==='wall'||kind==='blast'),S=usBlock(kind,low,kind==='wall'&&!low&&usRegion()===1?usTagOf(k):0);
  g.drawImage(S.cv,camX+(i-j)*TW2+S.x,camY+(i+j)*TH2+S.y,S.w,S.h)}
// shrines, the merchant, chests, the lift's ring, dropped salvage and flares
function usItems(){const L=game.lay,U=game.us;if(!L||!U)return;
  US_GATE.clear();for(const[x,y]of L.gate||[])US_GATE.add(idx(x,y));
  L.shrines.forEach((s,n)=>ritem(s.x+s.y,usDrawShrine,s,n));
  L.merchants.forEach(m=>ritem(m.x+m.y,usDrawMerchant,m));usHazItems();
  L.chests.forEach((c,n)=>{if(!(U.chests&(1<<n)))ritem(c.x+c.y,usDrawChest,c)});
  ritem(L.exit[0]+L.exit[1]-.9,usDrawLift,L.exit);
  for(const d of U.drops)ritem(d.x+d.y,usDrawDrop,d);
  for(const f of U.flares)ritem(f.x+f.y,usDrawFlare,f);
  for(const l of U.loot||[])ritem(l.x+l.y,usDrawLoot,l)}
function usDrawShrine(s,n){const U=game.us,on=!!(U.lit&(1<<n)),sleep=s.arena&&!U.bossDown,c=iso(s.x,s.y),t=game.time,fl=sleep?.15:on?.85+.15*Math.sin(t*9+n):.35+.3*Math.max(0,Math.sin(t*3.1+n*2)*Math.sin(t*7.3));
  g.fillStyle='#1d1c1a';g.fillRect(c[0]-11*u,c[1]-22*u,22*u,20*u);g.strokeStyle=`rgba(255,90,216,${fl})`;g.lineWidth=2.2*u;g.strokeRect(c[0]-9*u,c[1]-20*u,18*u,16*u);
  g.fillStyle=`rgba(255,226,120,${fl})`;g.font=`900 ${8*u}px "Big Shoulders Stencil Display", sans-serif`;g.textAlign='center';g.fillText('7',c[0],c[1]-9*u);
  if(U.rest.ix===n){g.strokeStyle='rgba(255,90,216,.35)';g.lineWidth=1.5*u;g.beginPath();g.ellipse(c[0],c[1],TW2*.9,TH2*.9,0,0,Math.PI*2);g.stroke()}}
function usDrawMerchant(m){const c=iso(m.x,m.y);
  if(m.kind==='keeper'){usDrawKeeper(m);return}
  const look=m.kind==='collector'?{body:'#141418',vest:'#e8e2d0',pants:'#141418',head:'#c8b8a8',hat:'#0e0e12',nogun:true}:m.kind==='lift'?{body:'#4a5a3a',vest:'#2e3a24',pants:'#2a3024',head:'#a98262',cap:'#c8a03a',nogun:true}:{body:'#5a4a6a',vest:'#2a2233',pants:'#2c2a30',head:'#b08a6a',hat:'#1a1620',nogun:true};
  drawPerson(m.x,m.y,{aim:{x:0,y:1},walk:0,flash:false,...look});
  if(m.kind==='collector'){g.fillStyle='#c42a3a';g.fillRect(c[0]-1.5*u,c[1]-WH*1.02,3*u,2*u);return}   // a red bow tie
  g.fillStyle='#3a2a20';g.fillRect(c[0]-10*u,c[1]+1*u,20*u,6*u)}
// the Shrine Keeper: a squat cleaning robot with a mop arm and one lamp eye
function usDrawKeeper(m){const c=iso(m.x,m.y),t=game.time,b=Math.sin(t*2)*u;oval(c[0],c[1],10*u,4*u,'rgba(0,0,0,.35)');
  g.fillStyle='#8a9098';g.fillRect(c[0]-8*u,c[1]-18*u+b,16*u,16*u);g.fillStyle='#5c6268';g.fillRect(c[0]-8*u,c[1]-6*u+b,16*u,4*u);
  g.fillStyle='#2a2e32';g.fillRect(c[0]-5*u,c[1]-15*u+b,10*u,5*u);g.fillStyle=`rgba(124,216,255,${.7+.3*Math.sin(t*5)})`;g.beginPath();g.arc(c[0],c[1]-12.5*u+b,2*u,0,Math.PI*2);g.fill();
  g.strokeStyle='#6a5a40';g.lineWidth=1.6*u;g.beginPath();g.moveTo(c[0]+8*u,c[1]-10*u+b);g.lineTo(c[0]+14*u,c[1]+2*u);g.stroke();g.fillStyle='#c8c0a0';g.fillRect(c[0]+11*u,c[1]+1*u,7*u,3*u)}
function usDrawChest(k){const c=iso(k.x,k.y);boxR(k.x-.3,k.y-.2,k.x+.3,k.y+.2,0,WH*.38,'#7a5a30','#5a4224','#4a361c');g.fillStyle='#e2b436';g.fillRect(c[0]-2*u,c[1]-WH*.3,4*u,3*u)}
function usDrawLift(e){const U=game.us,open=usKind(U.level)!=='boss'||U.bossDown,c=iso(e[0],e[1]),f=U.exitT/US.exitHold;
  g.strokeStyle=open?`rgba(124,255,107,${.45+.25*Math.sin(game.time*3)})`:'rgba(120,120,110,.3)';g.lineWidth=2*u;g.setLineDash([6*u,5*u]);g.beginPath();g.ellipse(c[0],c[1],TW2*US.exitR,TH2*US.exitR,0,0,Math.PI*2);g.stroke();g.setLineDash([]);
  if(f>0){g.strokeStyle='#7cff6b';g.lineWidth=3*u;g.beginPath();g.ellipse(c[0],c[1],TW2*US.exitR,TH2*US.exitR,0,-Math.PI/2,-Math.PI/2+f*Math.PI*2);g.stroke()}}
function usDrawDrop(d){const c=iso(d.x,d.y),b=Math.sin(game.time*4)*2*u;g.fillStyle='rgba(226,180,54,.25)';g.beginPath();g.ellipse(c[0],c[1],10*u,4*u,0,0,Math.PI*2);g.fill();
  g.fillStyle='#cbbf9f';g.beginPath();g.ellipse(c[0],c[1]-5*u+b,5*u,5*u,0,0,Math.PI*2);g.fill();g.fillStyle='#e2b436';g.fillRect(c[0]-1.5*u,c[1]-9*u+b,3*u,3*u)}
function usDrawFlare(f){const c=iso(f.x,f.y);g.fillStyle='#c42a1a';g.fillRect(c[0]-1.5*u,c[1]-7*u,3*u,7*u);if(f.t>0){g.fillStyle=`rgba(255,${120+Math.random()*80|0},80,.9)`;g.beginPath();g.arc(c[0],c[1]-8*u,2.4*u,0,Math.PI*2);g.fill()}}
// how dark it is (the Dungeon brightness setting raises the floor)
const usDarkL=()=>US.darkL[clamp(cfg.usBright|0,0,US.darkL.length-1)];
// drawLighting's holes in the tunnels
function usLights(hole,at){const L=game.lay,U=game.us,t=game.time;let c;
  const cone=(o,s)=>{const k=usConeMul(o);c=at(o.x,o.y,WH*.5);hole(c[0],c[1],TW2*US_LOOK.glow,.85*s);const a=o.aim||{x:1,y:0};for(const[d,r]of US_LOOK.cone){c=at(o.x+a.x*d*k,o.y+a.y*d*k,WH*.3);hole(c[0],c[1],TW2*r*Math.sqrt(k),.8*s)}};   // perks and relics stretch or shorten it
  for(const o of players.values())if(o.alive||o.downed)cone(o,o===player?1:.8);
  const dark=usBossNow()==='visitor'&&U.bossStage>0&&!U.bossDown;   // the Visitor's field fails: the room's own lights go out
  if(!dark)L.lamps.forEach((p,n)=>{const on=usLampOn(n);if(!on)return;c=at(p[0],p[1],WH*.6);hole(c[0],c[1],TW2*2.8*(.7+.3*on),.75*on)});
  for(const q of L.tanks||[]){c=at(q[0],q[1],WH*.6);hole(c[0],c[1],TW2*1.2,dark?.25:.4)}   // the tanks' glow
  if(!dark)L.neon.forEach((p,n)=>{const fl=reduceMotion()?.6:.45+.35*Math.max(0,Math.sin(t*2.3+n)*Math.sin(t*5.7+n*3));c=at(p[0],p[1],WH*.4);hole(c[0],c[1],TW2*1.9,fl)});
  L.shrines.forEach((s,n)=>{if(s.arena&&!U.bossDown)return;c=at(s.x,s.y,WH*.6);hole(c[0],c[1],TW2*(U.lit&(1<<n)?2.8:1.6),.8)});
  for(const m of L.merchants){c=at(m.x,m.y,WH*.6);hole(c[0],c[1],TW2*2.2,.75)}
  if(usKind(U.level)!=='boss'||U.bossDown){c=at(L.exit[0],L.exit[1]);hole(c[0],c[1],TW2*2,.7)}
  for(const f of U.flares){c=at(f.x,f.y,WH*.4);hole(c[0],c[1],TW2*((f.r||4)+Math.sin(t*20+f.x)*.2),.95)}
  for(const d of U.drops){c=at(d.x,d.y);hole(c[0],c[1],TW2*.9,.5)}
  for(const e of enemies)if(e.type==='boss'){c=at(e.x,e.y,WH*.6);hole(c[0],c[1],TW2*1.4,.55)}   // a boss you can always find
}
// Settings › DUNGEON BRIGHTNESS on its top step (work order 12): every raider is marked above the darkness, as telegraphs are,
// so nothing in the room needs your light to be seen. A thin ring at the feet and a dot over the head, shape not colour alone.
function usBrightMarks(){if((cfg.usBright|0)<US.darkL.length-1)return 0;let n=0;
  for(const e of enemies){if(e.dead)continue;const c=iso(e.x,e.y);if(c[0]<-20||c[0]>W+20||c[1]<-40||c[1]>H+20)continue;n++;
    g.strokeStyle=e.type==='boss'?'rgba(255,214,90,.75)':'rgba(255,120,90,.6)';g.lineWidth=1.3*u;g.beginPath();g.ellipse(c[0],c[1],TW2*.42,TH2*.42,0,0,Math.PI*2);g.stroke();
    g.fillStyle=g.strokeStyle;g.beginPath();g.moveTo(c[0],c[1]-WH*1.55);g.lineTo(c[0]-2.5*u,c[1]-WH*1.55-4*u);g.lineTo(c[0]+2.5*u,c[1]-WH*1.55-4*u);g.closePath();g.fill()}return n}
