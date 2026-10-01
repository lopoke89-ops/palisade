/* ---------- Frostpeak: authoritative ground height and connectors ---------- */
// One height unit is a terrace, drawn 24*u pixels above the previous one. Ramps
// interpolate from the north/high edge to the south/low edge; stairs use the same
// continuous collision plane, with treads drawn over it. Heights never grant damage.
let heights=new Uint8Array(N*N),connectors=new Uint8Array(N*N),frostFields=[];
const heightPx=()=>24*u;
function heightAt(x,y){
  if(!inb(Math.floor(x),Math.floor(y)))return 0;
  const k=idx(Math.floor(x),Math.floor(y));
  return(heights[k]||0)+(connectors[k]?1-(y-Math.floor(y)):0);
}
function heightLink(i,j,ni,nj){
  if(!inb(i,j)||!inb(ni,nj))return false;
  if(MAP!==MAPS.frost)return true;
  const a=idx(i,j),b=idx(ni,nj),ca=connectors[a],cb=connectors[b];
  if(!ca&&!cb)return heights[a]===heights[b];
  if(i!==ni)return false; // connector sides have guard rails; use the ends
  if(ca&&cb)return heights[a]===heights[b];
  const r=ca?a:b,f=ca?b:a,ry=(r/N)|0,fy=(f/N)|0;
  return heights[f]===heights[r]+(fy<ry?1:0);
}
function heightCollision(x,y,r){
  if(MAP!==MAPS.frost)return false;
  const z=heightAt(x,y);
  for(const[a,b]of[[r,0],[-r,0],[0,r],[0,-r]]){
    if(Math.abs(heightAt(x+a,y+b)-z)>.42)return true;
    const i=Math.floor(x),j=Math.floor(y),ni=Math.floor(x+a),nj=Math.floor(y+b);
    if((i!==ni||j!==nj)&&!heightLink(i,j,ni,nj))return true;
  }
  return false;
}
function travelClear(x,y,tx,ty,team,r=.2){
  const d=Math.hypot(tx-x,ty-y),n=Math.max(1,Math.ceil(d/.1));let px=x,py=y;
  for(let s=1;s<=n;s++){
    const nx=x+(tx-x)*s/n,ny=y+(ty-y)*s/n;
    if(collides(nx,ny,r,team)||Math.abs(heightAt(nx,ny)-heightAt(px,py))>.22)return false;
    const i=Math.floor(px),j=Math.floor(py),ni=Math.floor(nx),nj=Math.floor(ny);
    if(i!==ni&&j!==nj){if(!heightLink(i,j,ni,j)||!heightLink(ni,j,ni,nj))return false}
    else if((i!==ni||j!==nj)&&!heightLink(i,j,ni,nj))return false;
    px=nx;py=ny;
  }
  return true;
}
// Ground height is resolved before character-height hit tests. Guns aim between
// chest-height endpoints; higher intervening terrain stops a round. Grenades arc
// above terrain and land on their target terrace. Blasts use 3D distance.
function heightRayClear(x0,y0,x1,y1){
  if(MAP!==MAPS.frost)return true;
  const d=Math.hypot(x1-x0,y1-y0),n=Math.ceil(d/.12),z0=heightAt(x0,y0)+.7,z1=heightAt(x1,y1)+.7;
  for(let s=1;s<n;s++){const t=s/n;if(heightAt(x0+(x1-x0)*t,y0+(y1-y0)*t)>z0+(z1-z0)*t-.05)return false}
  return true;
}
const heightDist=(x,y,tx,ty)=>MAP===MAPS.frost?Math.hypot(tx-x,ty-y,(heightAt(tx,ty)-heightAt(x,y))*.8):Math.hypot(tx-x,ty-y);
const groundReach=(x,y,tx,ty,r)=>Math.abs(heightAt(x,y)-heightAt(tx,ty))<.45&&Math.hypot(tx-x,ty-y)<r;
function bulletHeight(from,ang,range){
  const z0=heightAt(from.x,from.y)+.7;let target=from.foe||null,score=.1;
  if(!target){for(const e of from===qm?enemies:players.has(from.id)?foes():allies()){
    if(e.dead||e.burrow||e.alive===false)continue;
    const dx=e.x-from.x,dy=e.y-from.y,d=Math.hypot(dx,dy),dot=(dx*Math.cos(ang)+dy*Math.sin(ang))/(d||1);
    const cross=Math.abs(dx*Math.sin(ang)-dy*Math.cos(ang));
    if(d>0&&heightDist(from.x,from.y,e.x,e.y)<=range&&dot>.97&&cross<.6&&heightRayClear(from.x,from.y,e.x,e.y)&&dot>score){score=dot;target=e}
  }}
  const d=target?Math.hypot(target.x-from.x,target.y-from.y):range;
  return[z0,target?(heightAt(target.x,target.y)+.7-z0)/Math.max(.5,d):0];
}
const bulletZ=b=>(b.z0??heightAt(b.x,b.y)+.7)+(b.zSlope||0)*b.dist;
const bulletRangeScale=b=>Math.hypot(1,(b.zSlope||0)*.8);
const bulletAtActor=(b,e)=>Math.abs(bulletZ(b)-(heightAt(e.x,e.y)+.7))<.6;
function frostSlow(x,y){
  if(!frostFields.length)return 1;
  const z=heightAt(x,y);for(const f of frostFields)if(f.t>0&&Math.abs(f.z-z)<.45&&Math.hypot(x-f.x,y-f.y)<f.r)return .7;
  return 1;
}
function addFrost(x,y){
  if(!inb(Math.floor(x),Math.floor(y))||solidTile(Math.floor(x),Math.floor(y)))return;
  const k=idx(Math.floor(x),Math.floor(y));let f=frostFields.find(f=>f.k===k);
  if(f){f.t=Math.max(f.t,10);return}
  if(frostFields.length>=64)frostFields.shift();
  frostFields.push({k,x,y,z:heightAt(x,y),r:.72,t:10});
}
function ageFrost(dt){for(let i=frostFields.length-1;i>=0;i--)if((frostFields[i].t-=dt)<=0)frostFields.splice(i,1)}
// Charges can break walls, but may never bypass a cliff or a connector side.
function heightTravelClear(x,y,tx,ty){
  if(MAP!==MAPS.frost)return true;
  const n=Math.max(1,Math.ceil(Math.hypot(tx-x,ty-y)/.1));let px=x,py=y;
  for(let q=1;q<=n;q++){const nx=x+(tx-x)*q/n,ny=y+(ty-y)*q/n,i=Math.floor(px),j=Math.floor(py),ni=Math.floor(nx),nj=Math.floor(ny);
    if(heightCollision(nx,ny,.27)||Math.abs(heightAt(nx,ny)-heightAt(px,py))>.22)return false;
    if(i!==ni&&j!==nj){if(!heightLink(i,j,ni,j)||!heightLink(ni,j,ni,nj))return false}else if((i!==ni||j!==nj)&&!heightLink(i,j,ni,nj))return false;px=nx;py=ny;
  }return true;
}

MAPS.frost={name:'FROSTPEAK',short:'Frostpeak',blurb:'Hold the summit. Two switchback approaches, ramps and stairs bring raiders up through three snowy terraces.',
  from:'up the mountain',bosses:['rime','storm','rime'],col:'#a8dfef',hp:1.08,
  lay(o){
    const a=N>16?7:5,b=N>16?15:10,lanes=N>16?[[4,5,6],[16,17,18]]:[[3,4,5],[10,11,12]];
    for(let j=0;j<N;j++)for(let i=0;i<N;i++){const k=idx(i,j);heights[k]=j<a?2:j<b?1:0;
      if(j===a||j===b){if(lanes.some(L=>L.includes(i))){connectors[k]=lanes[1].includes(i)?2:1;heights[k]=j===a?1:0}}}
    const c=[N>16?10:7,2],wood=[[2,2],[N-3,3],[2,a+3],[N-3,b+3]].map(woodNode);
    const L={core:c,nodes:[...wood,kiln([c[0]-3,3],0),scrap([c[0]+3,3],0),scrap([N-3,a+3],0)],
      ruins:[[[[c[0]-1,4],[c[0]+1,4]],1,.65,.1]],spawns:[{w:1,tiles:Array.from({length:N-2},(_,i)=>[i+1,N-1])}],
      bossAt:[[3,N-2],[N-4,N-2]],evacAt:[N>16?11:7,a+3]};
    for(const[i,j]of[[1,a+2],[N-2,a+2],[1,b+2],[N-2,b+2]])terr[idx(i,j)]=T_ROCK;
    return L;
  }};
MAP_IDS.push('frost');

function paintFrostTile(i,j){
  const k=idx(i,j),z=heights[k],r=connectors[k],p=(x,y,h)=>iso(x,y,h),h=hash(i+6,j+31);
  const A=p(i,j,z+(r?1:0)),B=p(i+1,j,z+(r?1:0)),C=p(i+1,j+1,z),D=p(i,j+1,z);
  const lowS=inb(i,j+1)?heights[idx(i,j+1)]+(connectors[idx(i,j+1)]?1:0):0,lowE=inb(i+1,j)?heights[idx(i+1,j)]:0;
  if(z>lowS)quad(D,C,p(i+1,j+1,lowS),p(i,j+1,lowS),'#435b6a');
  if(z>lowE)quad(B,C,p(i+1,j+1,lowE),p(i+1,j,lowE),'#304858');
  quad(A,B,C,D,r?'#acc9d8':h>.55?'#dceaf0':'#c8dee8');
  g.strokeStyle='rgba(68,109,134,.2)';g.lineWidth=u;g.beginPath();g.moveTo(D[0],D[1]);g.lineTo(C[0],C[1]);g.stroke();
  if(r){g.strokeStyle=r===2?'#547b90':'#e7f5fa';g.lineWidth=r===2?2*u:u;
    for(let q=1;q<=(r===2?5:2);q++){const t=q/(r===2?6:3),a=p(i,j+t,z+1-t),b=p(i+1,j+t,z+1-t);g.beginPath();g.moveTo(a[0],a[1]);g.lineTo(b[0],b[1]);g.stroke()}
  }else if(h>.83){const c=p(i+.5,j+.5,z);g.fillStyle='rgba(255,255,255,.55)';g.fillRect(c[0]-2*u,c[1],4*u,u)}
}
// Reinsert cliff faces into the existing world depth queue. An actor standing
// behind a lip is partly occluded; actors on its lower/front side stay visible.
function itemFrostCliff(k){
  const i=k%N,j=(k/N)|0,z=heights[k],r=connectors[k],p=(x,y,h)=>iso(x,y,h);
  if(r||!z)return;
  const c=iso(i+.5,j+.5,z);if(c[0]+TW2<0||c[0]-TW2>W||c[1]+TH2+2*heightPx()<0||c[1]-TH2>H)return;
  const s=inb(i,j+1)?heights[idx(i,j+1)]+(connectors[idx(i,j+1)]?1:0):0,e=inb(i+1,j)?heights[idx(i+1,j)]:0;
  if(z>s){quad(p(i,j+1,z),p(i+1,j+1,z),p(i+1,j+1,s),p(i,j+1,s),'#435b6a');
    const A=p(i+.2,j+1,z),B=p(i+.35,j+1,s);g.strokeStyle='#719aaa';g.lineWidth=u;g.beginPath();g.moveTo(...A);g.lineTo(...B);g.stroke()}
  if(z>e)quad(p(i+1,j,z),p(i+1,j+1,z),p(i+1,j+1,e),p(i+1,j,e),'#304858');
}
function frostScenery(){
  // Expedition caches sit beyond the walkable boundary. A slim beacon and route
  // flags communicate the summit and ascents without adding invisible cover.
  for(const[x,y]of[[-.6,3],[N+.6,N-4],[-.6,N-3]]){
    boxR(x,y,.7,.5,WH*.3,'#456571','#203e4c','#304f5a','#233b45');
    const c=iso(x,y);g.fillStyle='#dfedf0';g.fillRect(c[0]-12*u,c[1]-WH*.3,24*u,3*u);
    g.strokeStyle='#9bb5be';g.lineWidth=2*u;g.beginPath();g.moveTo(c[0]-15*u,c[1]+3*u);g.lineTo(c[0]+15*u,c[1]+3*u);g.stroke();
  }
  const c=iso(core.i+2.1,.8);g.strokeStyle='#405969';g.lineWidth=3*u;g.beginPath();g.moveTo(c[0],c[1]);g.lineTo(c[0],c[1]-WH*1.5);g.stroke();
  g.fillStyle='#ffd882';g.fillRect(c[0]-3*u,c[1]-WH*1.55,6*u,5*u);
  g.fillStyle='#bd5450';g.beginPath();g.moveTo(c[0]+2*u,c[1]-WH*1.35);g.lineTo(c[0]+17*u,c[1]-WH*1.25);g.lineTo(c[0]+2*u,c[1]-WH*1.1);g.fill();
  for(let k=0;k<N*N;k++)if(connectors[k]&&(!inb(k%N-1,(k/N)|0)||!connectors[k-1])){
    const x=k%N+.08,y=((k/N)|0)+.5,p=iso(x,y);g.strokeStyle='#486a7c';g.lineWidth=2*u;g.beginPath();g.moveTo(p[0],p[1]);g.lineTo(p[0],p[1]-WH*.55);g.stroke();
    g.fillStyle='#efa568';g.fillRect(p[0],p[1]-WH*.55,7*u,3*u);
  }
}
let frostArt=null;
function drawFrostFields(){
  if(!frostFields.length)return;
  const key=[u,DPR,TW2,TH2].join('|');
  if(!frostArt||frostArt.key!==key){
    const rx=TW2*.72*Math.SQRT2,ry=TH2*.72*Math.SQRT2,w=rx*2+4*u,h=ry*2+4*u,cv=document.createElement('canvas'),sc=Math.min(1.5,DPR);cv.width=Math.ceil(w*sc);cv.height=Math.ceil(h*sc);
    const c=cv.getContext('2d');c.scale(sc,sc);c.translate(w/2,h/2);c.fillStyle='#508d91';c.strokeStyle='#bbffd7';c.lineWidth=1.2*u;c.beginPath();c.ellipse(0,0,rx,ry,0,0,Math.PI*2);c.fill();c.stroke();
    c.strokeStyle='#e2fff3';c.beginPath();for(let q=0;q<3;q++){const a=q*Math.PI*2/3;c.moveTo(0,0);c.lineTo(Math.cos(a)*rx*.65,Math.sin(a)*ry*.65)}c.stroke();frostArt={key,cv,w,h};
  }
  const a=frostArt;g.save();for(const f of frostFields){const c=iso(f.x,f.y,f.z);if(c[0]+a.w/2<0||c[0]-a.w/2>W||c[1]+a.h/2<0||c[1]-a.h/2>H)continue;g.globalAlpha=Math.min(.75,f.t*.3);g.drawImage(a.cv,c[0]-a.w/2,c[1]-a.h/2,a.w,a.h)}g.restore();
}
