/* ---------- forest, fence and cached scenery ---------- */
// Scenery that never moves is painted once into two offscreen canvases (behind and in
// front of the action) instead of every frame. Near trees fade when someone walks behind.
const BAND=7;
const treesBack=[],treesFront=[];
// the trees (or, in the quarry, boulders and dead trees) round the outside; each map and size has its own
function genForest(){
  treesBack.length=0;treesFront.length=0;const m=MAP||MAPS.yard,Q=m===MAPS.quarry;
  for(let j=-BAND;j<N+BAND;j++)for(let i=-BAND;i<N+BAND;i++){
    if(i>=0&&j>=0&&i<N&&j<N)continue;
    if(m.outWater&&m.outWater(i,j,MAPO))continue;   // the river runs on past the fence
    const dx=i<0?-i:(i>=N?i-N+1:0),dy=j<0?-j:(j>=N?j-N+1:0),d=Math.max(dx,dy),front=i>=N||j>=N;
    if(Q&&rampNear(i,j))continue;
    const h=hash(i*3+101,j*7+13),v=hash(i+57,j+211),x=i+.2+hash(i+5,j+9)*.6,y=j+.2+hash(i+17,j+3)*.6;
    let t=null;
    if(Q){if(d>=2&&h>.72)t={x,y,kind:v>.7?1:4,v,h:40+v*26};else if(d>=1&&h>.86)t={x,y,kind:4,v,h:0}}
    else if(d>=(front?3:2)&&h>.3)t={x,y,kind:v>.93?1:0,v,h:56+v*30+(d-2)*2};
    else if(d>=1&&h>.8)t={x,y,kind:v>.35?2:3,v,h:0};
    if(t){t.a=1;t.snow=m===MAPS.frost;if(t.snow&&t.kind===1)t.kind=0}
    if(t)(front?treesFront:treesBack).push(t);
  }
  treesBack.sort((a,b)=>a.x+a.y-b.x-b.y);treesFront.sort((a,b)=>a.x+a.y-b.x-b.y);
}
// quarry ramps: the gap in the rim and the road up the slope outside it
function rampNear(i,j){const L=game.lay;if(!L||!L.ramps)return false;for(const[a,b]of L.ramps){if(b===0&&j<0&&Math.abs(i-a)<=1&&j>-5)return true;if(a===N-1&&i>=N&&Math.abs(j-b)<=1&&i<N+4)return true;
  if(b===N-1&&j>=N&&Math.abs(i-a)<=1&&j<N+4)return true;if(a===0&&i<0&&Math.abs(j-b)<=1&&i>-5)return true}return false}
const isRamp=(i,j)=>{const L=game.lay;return!!(L&&L.ramps&&L.ramps.some(r=>r[0]===i&&r[1]===j))};
function drawTree(t,alpha){const c=iso(t.x,t.y);drawTreeAt(t,c[0],c[1],alpha)}
function drawTreeAt(t,cx,cy,alpha){
  g.save();g.translate(cx,cy);g.scale(u,u);g.globalAlpha=alpha;
  if(t.kind===0){
    oval(5,1,17,7,'rgba(0,0,0,.3)');
    g.fillStyle='#120d0a';g.fillRect(-3.2,-13,6.4,13);g.fillStyle='#45301f';g.fillRect(-2.4,-13,4.8,12.4);
    const light=mix('#3d5a35','#4b5d34',t.v),dk=mix('#223620','#2a3a22',t.v);
    for(let k=0;k<3;k++){
      const by=-9-k*t.h*.2,w=(19-k*4.8)*(.9+t.v*.3),ty=by-t.h*.44;
      const L=[-w,by],R=[w,by],A=[0,ty],M=[0,by+3.5];
      P([L,A,M],light,false);P([M,A,R],dk,false);
      if(t.snow){P([[-w*.68,by-t.h*.14],A,[w*.68,by-t.h*.14],[0,by-t.h*.07]],k%2?'#d9ebef':'#b8d5e1',false)}
      g.strokeStyle=OUT;g.lineWidth=1.1;g.beginPath();g.moveTo(L[0],L[1]);g.lineTo(A[0],A[1]);g.lineTo(R[0],R[1]);g.lineTo(M[0],M[1]);g.closePath();g.stroke();
    }
  }else if(t.kind===1){
    const top=[0,-t.h*.8];seg([0,0],top,OUT,5);seg([0,0],top,'#3d3326',3.4);
    for(const[f,sgn,len]of[[.45,-1,10],[.6,1,8],[.72,-1,6]]){const p0=[0,-t.h*.8*f],p1=[p0[0]+sgn*len,p0[1]-len*.7];seg(p0,p1,OUT,3.2);seg(p0,p1,'#3d3326',1.8)}
  }else if(t.kind===2){
    const g1=mix('#2c4127','#394a2a',t.v),blobs=[[-4,-4,6],[4,-3.5,5.5],[0,-7,6]];
    for(const b of blobs)disc(b[0],b[1],b[2]+.9,OUT);for(const b of blobs)disc(b[0],b[1],b[2],g1);disc(-2,-9,2.5,mix(g1,'#ffffff',.12));
  }else if(t.kind===4){   // quarry boulder
    const r=8+t.v*7;oval(0,1,r*1.2,r*.5,'rgba(0,0,0,.3)');P([[-r,0],[-r*.7,-r*.9],[r*.1,-r*1.2],[r*.9,-r*.6],[r,0]],mix('#5e584f','#6b645a',t.v),true);
    P([[-r*.7,-r*.9],[r*.1,-r*1.2],[r*.9,-r*.6],[r*.1,-r*.5]],'#7a7368',false);
  }else{
    g.fillStyle='#3a2b1c';g.fillRect(-5,-6,10,6);oval(0,-6,5,2.4,'#806645');oval(0,0,5,2.4,'#3a2b1c');
  }
  g.restore();
}
function drawFence(a,b){
  const pa=iso(a[0],a[1]),pb=iso(b[0],b[1]);
  for(const h of[WH*.32,WH*.62]){g.lineWidth=3.4*u;g.strokeStyle=OUT;g.beginPath();g.moveTo(pa[0],pa[1]-h);g.lineTo(pb[0],pb[1]-h);g.stroke();
    g.lineWidth=2*u;g.strokeStyle='#5d4832';g.stroke()}
  for(const p of[pa,pb]){g.fillStyle=OUT;g.fillRect(p[0]-2.2*u,p[1]-WH*.85,4.4*u,WH*.85);g.fillStyle='#4a3a28';g.fillRect(p[0]-1.4*u,p[1]-WH*.82,2.8*u,WH*.82)}
}
// the yard's edge on one side: the fence, a gap where the river runs out, or the quarry's rock rim with its ramps
// side 'n' (j=0), 'w' (i=0) are painted behind; 's' (j=N), 'e' (i=N) in front
function drawEdge(side,s){
  const A=side==='n'?[s,0]:side==='w'?[0,s]:side==='s'?[s,N]:[N,s],B=side==='n'||side==='s'?[A[0]+1,A[1]]:[A[0],A[1]+1];
  const m=MAP||MAPS.yard,out=side==='n'?[s,-1]:side==='w'?[-1,s]:side==='s'?[s,N]:[N,s],inT=side==='n'?[s,0]:side==='w'?[0,s]:side==='s'?[s,N-1]:[N-1,s];
  if(m.outWater&&(m.outWater(out[0],out[1],MAPO)||tAt(inT[0],inT[1])===T_WATER))return;
  if(m===MAPS.quarry){
    if(isRamp(inT[0],inT[1]))return;
    const pa=iso(A[0],A[1]),pb=iso(B[0],B[1]),h=WH*(.9+hash(s*3+(side==='n'?1:side==='e'?2:3),7)*.5);
    quad(pa,pb,[pb[0],pb[1]-h],[pa[0],pa[1]-h],side==='n'||side==='s'?'#4a453e':'#3c3833');
    g.strokeStyle='rgba(0,0,0,.35)';g.lineWidth=u;g.beginPath();g.moveTo(pa[0],pa[1]-h);g.lineTo(pb[0],pb[1]-h);g.stroke();
    return}
  drawFence(A,B);
}
function paintBack(){
  const m=MAP||MAPS.yard,Q=m===MAPS.quarry;
  quad(iso(-BAND-6,-BAND-6),iso(N+BAND+6,-BAND-6),iso(N+BAND+6,N+BAND+6),iso(-BAND-6,N+BAND+6),Q?'#161412':'#151a12');
  for(let j=-BAND;j<N+BAND;j++)for(let i=-BAND;i<N+BAND;i++){
    if(i>=0&&j>=0&&i<N&&j<N)continue;
    const dx=i<0?-i:(i>=N?i-N+1:0),dy=j<0?-j:(j>=N?j-N+1:0),d=Math.max(dx,dy),h=hash(i+400,j+77);
    if(m.outWater&&m.outWater(i,j,MAPO)){quad(iso(i,j),iso(i+1,j),iso(i+1,j+1),iso(i,j+1),h<.5?'#1d3848':'#1b3544');continue}
    const col=m===MAPS.frost?mix('#adc6d1','#405966',clamp(d/8,0,1)):Q?(rampNear(i,j)?(h<.5?'#4a4238':'#453e35'):mix(mix('#2e2a25','#35302a',h),'#1a1816',clamp((d-2)/6,0,1))):
      d===1?(h<.5?'#342d21':'#2f2a1e'):mix(mix('#1f2518','#262c1b',h),'#171c13',clamp((d-2)/6,0,1));
    quad(iso(i,j),iso(i+1,j),iso(i+1,j+1),iso(i,j+1),col);
    if(Q){if(h>.7){const c=iso(i+.3+h*.4,j+.5);oval(c[0],c[1],3*u,1.4*u,'rgba(140,130,115,.25)')}continue}
    if(d>=2&&h>.55){const c=iso(i+.3+h*.4,j+.5);g.strokeStyle='rgba(107,84,51,.35)';g.lineWidth=u;g.beginPath();g.moveTo(c[0],c[1]);g.lineTo(c[0]+4*u,c[1]-u);g.stroke()}
    else if(d===1&&h>.7){const c=iso(i+.5,j+.5);oval(c[0],c[1],7*u,2.6*u,'rgba(84,104,64,.35)')}
  }
  for(const t of treesBack)drawTree(t,1);
  for(let j=0;j<N;j++)for(let i=0;i<N;i++){
    if(m===MAPS.frost){paintFrostTile(i,j);continue}
    const h=hash(i,j);quad(iso(i,j),iso(i+1,j),iso(i+1,j+1),iso(i,j+1),groundCol(i,j,h));
    if(!groundDetail(i,j,h)&&h>.86&&!Q){const c=iso(i+.5,j+.5);oval(c[0]+(h-.9)*40*u,c[1],6*u,2.5*u,'rgba(84,104,64,.35)')}
  }
  g.strokeStyle='rgba(0,0,0,.22)';g.lineWidth=1;g.beginPath();
  if(m!==MAPS.frost)for(let s=0;s<=N;s++){let a=iso(s,0),b=iso(s,N);g.moveTo(a[0],a[1]);g.lineTo(b[0],b[1]);a=iso(0,s);b=iso(N,s);g.moveTo(a[0],a[1]);g.lineTo(b[0],b[1])}g.stroke();
  for(let s=0;s<N;s++){drawEdge('n',s);drawEdge('w',s)}
  if(m===MAPS.frost)frostScenery();
}
// Near side of the yard. When someone walks behind a tree, only the small patch around that
// tree is redrawn in the cached image, never the whole thing (a full redraw was the hitch).
function paintFront(){
  for(let s=0;s<N;s++){drawEdge('s',s);drawEdge('e',s)}
  for(const t of treesFront)drawTree(t,t.a);
}
function treeBox(t){const c=iso(t.x,t.y),top=(t.kind<2?t.h*.9+16:20)*u;return[c[0]-28*u,c[1]-top,c[0]+28*u,c[1]+12*u]}
function repaintTrees(changed){
  const c=caches.front,ctx=c.cv.getContext('2d');ctx.setTransform(c.s,0,0,c.s,0,0);
  const kg=g,kx=camX,ky=camY;g=ctx;camX=-c.minX;camY=-c.minY;
  try{for(const ch of changed){
    const[x0,y0,x1,y1]=treeBox(ch);g.save();g.beginPath();g.rect(x0,y0,x1-x0,y1-y0);g.clip();g.clearRect(x0,y0,x1-x0,y1-y0);
    for(let s=0;s<N;s++){drawEdge('s',s);drawEdge('e',s)}
    for(const t of treesFront){const b=treeBox(t);if(b[2]<x0||b[0]>x1||b[3]<y0||b[1]>y1)continue;drawTree(t,t.a)}
    g.restore()}}finally{g=kg;camX=kx;camY=ky}
}
let caches=null,fadeT=0;
const cacheKey=()=>(MAP?MAP.name:'')+'|'+N+'|'+(game.pvp||'')+'|'+(game.lay?game.lay.core.join():'');   // the painted scenery belongs to one map and size
function paintCache(c,fn){
  const ctx=c.cv.getContext('2d');ctx.setTransform(c.s,0,0,c.s,0,0);if(c===caches.back){ctx.fillStyle='#10140e';ctx.fillRect(0,0,c.w,c.h)}else ctx.clearRect(0,0,c.w,c.h);
  const kg=g,kx=camX,ky=camY;g=ctx;camX=-c.minX;camY=-c.minY;
  try{fn()}finally{g=kg;camX=kx;camY=ky}
}
function makeCaches(){
  const minX=-(N+2*BAND)*TW2-40*u,maxX=(N+2*BAND)*TW2+40*u,minY=-2*BAND*TH2-120*u,maxY=(2*N+2*BAND)*TH2+20*u;
  const budget=DESK?2.4e7:7.4e6;let sc=DPR;if((maxX-minX)*(maxY-minY)*sc*sc>budget)sc=Math.sqrt(budget/((maxX-minX)*(maxY-minY)));
  const x0=Math.floor(minX*sc)/sc,y0=Math.floor(minY*sc)/sc,pw=Math.ceil((maxX-x0)*sc),ph=Math.ceil((maxY-y0)*sc);
  const mk=opaque=>{const cv2=document.createElement('canvas');cv2.width=pw;cv2.height=ph;const c={cv:cv2,s:sc,w:pw/sc,h:ph/sc,minX:x0,minY:y0};
    if(opaque){const x=cv2.getContext('2d',{alpha:false});x.fillStyle='#10140e';x.fillRect(0,0,pw,ph)}return c};
  genForest();
  caches={back:mk(true),front:mk(false),key:cacheKey()};
  paintCache(caches.back,paintBack);paintCache(caches.front,paintFront);
  caches.front.tiles=frontTiles(caches.front);
}
// the front layer (fence + front trees) is mostly empty: find the tiles that hold something, from the
// trees' and fence's own bounds, and draw only those (a full-screen transparent draw costs as much as an opaque one)
function frontTiles(c){
  const T=128,cols=Math.ceil(c.cv.width/T),rows=Math.ceil(c.cv.height/T),on=new Uint8Array(cols*rows);
  const kx=camX,ky=camY;camX=-c.minX;camY=-c.minY;
  const mark=(x0,y0,x1,y1)=>{const m=6*u;for(let r=Math.max(0,Math.floor((y0-m)*c.s/T));r<=Math.min(rows-1,Math.floor((y1+m)*c.s/T));r++)
    for(let q=Math.max(0,Math.floor((x0-m)*c.s/T));q<=Math.min(cols-1,Math.floor((x1+m)*c.s/T));q++)on[r*cols+q]=1};
  try{
    for(const t of treesFront){const b=treeBox(t);mark(b[0],b[1],b[2],b[3])}
    for(let q=0;q<N;q++)for(const[a,b]of[[[q,N],[q+1,N]],[[N,q],[N,q+1]]]){const A=iso(a[0],a[1]),B=iso(b[0],b[1]);
      mark(Math.min(A[0],B[0]),Math.min(A[1],B[1])-WH*1.6,Math.max(A[0],B[0]),Math.max(A[1],B[1])+4*u)}
  }finally{camX=kx;camY=ky}
  const out=[];   // runs of neighbouring tiles in a row become one draw
  for(let r=0;r<rows;r++)for(let q=0;q<cols;q++){if(!on[r*cols+q])continue;let e=q;while(e+1<cols&&on[r*cols+e+1])e++;
    const sx=q*T,sy=r*T;out.push([sx,sy,Math.min(c.cv.width,(e+1)*T)-sx,Math.min(c.cv.height,(r+1)*T)-sy]);q=e}
  return out;
}
function updateFades(){
  const who=[];if(!demo)for(const p of players.values())if(p.alive||p.downed)who.push(p);who.push(qm);for(const e of enemies)who.push(e);
  const changed=[];
  for(const t of treesFront){if(t.kind>=2)continue;const td=t.x+t.y,tl=t.x-t.y;let f=false;
    for(const p of who){const dd=td-(p.x+p.y);if(dd>0&&dd<5.5&&Math.abs((p.x-p.y)-tl)<1.6){f=true;break}}
    const a=f?.32:1;if(t.a!==a){t.a=a;changed.push(t)}}
  if(changed.length)repaintTrees(changed);
}
const drawCache=c=>{
  if(!c.tiles){drawBackView(c);return}
  const ox=camX+c.minX,oy=camY+c.minY;
  for(const[sx,sy,sw,sh]of c.tiles){const dx=ox+sx/c.s,dy=oy+sy/c.s,dw=sw/c.s,dh=sh/c.s;
    if(dx>W||dy>H||dx+dw<0||dy+dh<0)continue;g.drawImage(c.cv,sx,sy,sw,sh,dx,dy,dw,dh)}
};
// The static world cache is budgeted below device resolution on large maps.
// Resampling it every frame is expensive even when the camera has stopped.
// Rasterize a viewport plus a small pan margin once, then copy at device pixels.
// Camera coordinates already snap to device pixels, so panning this image keeps
// exactly the original sample grid. Terrain changes remain in the live layer.
function drawBackView(c){
  const pad=Math.ceil(96*DPR),pw=Math.ceil(W*DPR)+pad*2,ph=Math.ceil(H*DPR)+pad*2;
  // Full-resolution source caches already copy on the same pixel grid. Avoid
  // extra storage there, and cap the extra viewport buffer at 16 MiB.
  if(c.s===DPR||pw*ph*4>16*1024*1024){g.drawImage(c.cv,camX+c.minX,camY+c.minY,c.w,c.h);return}
  let v=c.view,sx,sy;
  if(v){sx=v.pad-Math.round((camX-v.x)*DPR);sy=v.pad-Math.round((camY-v.y)*DPR)}
  if(!v||v.cv.width!==pw||v.cv.height!==ph||v.dpr!==DPR||sx<0||sy<0||sx+W*DPR>pw||sy+H*DPR>ph){
    if(!v)v=c.view={cv:document.createElement('canvas')};
    if(v.cv.width!==pw||v.cv.height!==ph){v.cv.width=pw;v.cv.height=ph}
    const ctx=v.cv.getContext('2d',{alpha:false});ctx.setTransform(DPR,0,0,DPR,pad,pad);
    ctx.fillStyle='#10140e';ctx.fillRect(-pad/DPR,-pad/DPR,pw/DPR,ph/DPR);
    ctx.drawImage(c.cv,camX+c.minX,camY+c.minY,c.w,c.h);
    v.x=camX;v.y=camY;v.pad=pad;v.dpr=DPR;v.builds=(v.builds||0)+1;sx=sy=pad;
  }
  g.drawImage(v.cv,sx,sy,W*DPR,H*DPR,0,0,W,H);
}
function drawLighting(){
  if(light.L<.03&&light.warm<.01)return;
  // dusk's warm grade used to be a full-screen 'soft-light' pass (~5 ms a frame on phones). It's folded into the shade:
  // one plain tint that matches the old look within ~2/255 per channel (fitted against the old two-pass image).
  const warm=light.warm;
  const shade=`rgba(${(light.r+warm*428)|0},${(light.g+warm*214)|0},${light.b|0},${light.L+warm*.57})`;
  // daylight is a flat 12% tint with no pools of light, so it goes straight onto the frame (one pass instead of three)
  if(light.L<=.25){g.fillStyle=shade;g.fillRect(0,0,W,H);return}
  lg.globalCompositeOperation='copy';lg.fillStyle=shade;lg.fillRect(0,0,W,H);
  lg.globalCompositeOperation='destination-out';
  // holes are stamped 1:1 from soft dots pre-drawn at device pixels (stretching the 64 px dot up every frame cost ~5 ms at night)
  const sc=DPR*LQ;lg.setTransform(1,0,0,1,0,0);
  const hole=(x,y,r,s)=>{const c=holeDot(r*sc);lg.globalAlpha=Math.min(1,s);lg.drawImage(c,Math.round(x*sc)-(c.width>>1),Math.round(y*sc)-(c.width>>1))};
  const at=(x,y,z=0)=>{const c=iso(x,y);return[c[0],c[1]-z]};
  if(light.L>.25){
    let c=at(player.x,player.y,WH*.5);if(!demo)hole(c[0],c[1],TW2*3.4,.95);
    if(!demo)for(const o of players.values())if(o!==player&&o.alive){c=at(o.x,o.y,WH*.5);hole(c[0],c[1],TW2*2.2,.8)}
    if(qm.alive){c=at(qm.x,qm.y,WH*.5);hole(c[0],c[1],TW2*1.8,.7)}
    for(const k of cores){c=at(k.i+.5,k.j+.5,WH);hole(c[0],c[1],TW2*3,.85)}
    for(const e of enemies){c=at(e.x,e.y,WH*.5);hole(c[0],c[1],TW2*.9,.45)}
    for(let k=0;k<N*N;k++){const w=walls[k];if(w&&w.fire>0){c=at(k%N+.5,((k/N)|0)+.5,WH);hole(c[0],c[1],TW2*2,.8)}}
    for(const kiln of nodes)if(kiln.type===1&&!kiln.locked){c=at(kiln.i+.5,kiln.j+.5,WH*.3);hole(c[0],c[1],TW2*1.6,.6)}
    if(MAP===MAPS.quarry)for(let k=0;k<N*N;k++)if(terr[k]===T_DRUM){c=at(k%N+.5,((k/N)|0)+.5,WH);hole(c[0],c[1],TW2*(2.6+.12*Math.sin(game.time*7+k)),.9)}   // oil drums light the pit
    for(const ch of charges){c=at(ch.x,ch.y);hole(c[0],c[1],TW2*.7,.7)}
  }
  for(const f of flashes){const c=flashPoint(f),a=f.life/f.max;hole(c[0],c[1],TW2*(f.muzzle?2:4.5)*f.r*.6,a)}
  lg.globalAlpha=1;lg.setTransform(sc,0,0,sc,0,0);g.drawImage(lc,0,0,W,H);
}
// soft round dots for the light holes, one per size (radius in device pixels, rounded to 3 px; at most ~48 kept)
// (and the same for the warm flash glows)
const HOLE_DOTS=new Map(),GLOW_DOTS=new Map(),SOFT_HOLE=[[0,'rgba(0,0,0,1)'],[1,'rgba(0,0,0,0)']],SOFT_GLOW=[[0,'rgba(255,210,130,.55)'],[1,'rgba(255,150,60,0)']];
function softDot(M,rpx,stops){
  const k=Math.max(3,Math.round(rpx/3)*3);let c=M.get(k);if(c)return c;
  if(M.size>48)M.clear();
  c=document.createElement('canvas');c.width=c.height=k*2;const x=c.getContext('2d'),gr=x.createRadialGradient(k,k,0,k,k,k);
  for(const[o,col]of stops)gr.addColorStop(o,col);x.fillStyle=gr;x.fillRect(0,0,k*2,k*2);M.set(k,c);return c;
}
const holeDot=rpx=>softDot(HOLE_DOTS,rpx,SOFT_HOLE);
// round soft-edged shapes drawn once, then stamped: a black dot for light holes, a warm glow for flashes
const SOFT=(()=>{const mk=(stops)=>{const c=document.createElement('canvas');c.width=c.height=64;const x=c.getContext('2d'),gr=x.createRadialGradient(32,32,0,32,32,32);
  for(const[o,col]of stops)gr.addColorStop(o,col);x.fillStyle=gr;x.fillRect(0,0,64,64);return c};
  return{dot:mk([[0,'rgba(0,0,0,1)'],[1,'rgba(0,0,0,0)']]),glow:mk([[0,'rgba(255,210,130,.55)'],[1,'rgba(255,150,60,0)']])}})();
let vignette=null,vignetteDemo=null;
function drawVignette(forDemo){
  // centred where the camera keeps your soldier (the menu's demo: the middle of the screen)
  if(forDemo){if(!vignetteDemo){const c=document.createElement('canvas'),s=Math.min(DPR,2);c.width=Math.ceil(W*s);c.height=Math.ceil(H*s);const x=c.getContext('2d');x.scale(s,s);
    const gr=x.createRadialGradient(W/2,H/2,Math.min(W,H)*.25,W/2,H/2,Math.max(W,H)*.8);gr.addColorStop(0,'rgba(12,10,8,0)');gr.addColorStop(1,'rgba(12,10,8,.6)');x.fillStyle=gr;x.fillRect(0,0,W,H);vignetteDemo=c}
    g.drawImage(vignetteDemo,0,0,W,H);return}
  if(!vignette){const c=document.createElement('canvas'),s=Math.min(DPR,2);c.width=Math.ceil(W*s);c.height=Math.ceil(H*s);const x=c.getContext('2d');x.scale(s,s);
    const cx=W*(W<760?.4:.5),cy=H*.52,gr=x.createRadialGradient(cx,cy,Math.min(W,H)*.25,cx,cy,Math.max(W,H)*.8);
    gr.addColorStop(0,'rgba(12,10,8,0)');gr.addColorStop(1,'rgba(12,10,8,.6)');x.fillStyle=gr;x.fillRect(0,0,W,H);vignette=c}
  g.drawImage(vignette,0,0,W,H);
}
let PROF=null;const PM=k=>{if(PROF){if(PROF.f)g.getImageData(0,0,1,1);const t=performance.now();PROF.a[PROF.k]=(PROF.a[PROF.k]||0)+t-PROF.t;PROF.k=k;PROF.t=t}};
// the draw list: depth, draw function and its arguments, in reused arrays (sorted back to front, ties in insert order)
const RI={n:0,d:[],f:[],a:[],b:[],o:[]};
function ritem(d,f,a,b){const k=RI.n++;RI.d[k]=d;RI.f[k]=f;RI.a[k]=a;RI.b[k]=b}
const byDepth=(x,y)=>RI.d[x]-RI.d[y]||x-y;
function itemWall(k,cut){drawWall(k%N,(k/N)|0,walls[k],cut?.3:1)}
function itemDebris(k){drawDebris(k%N,(k/N)|0,debris[k]-1)}
function itemSack(s){const c=iso(s.x,s.y);g.fillStyle='rgba(0,0,0,.35)';g.beginPath();g.ellipse(c[0],c[1],6*u,3*u,0,0,Math.PI*2);g.fill();g.fillStyle='#cbbf9f';g.beginPath();g.ellipse(c[0],c[1]-4*u,5*u,5*u,0,0,Math.PI*2);g.fill()}
function itemCharge(c){const s=iso(c.x,c.y);g.fillStyle='#1a1510';g.fillRect(s[0]-5*u,s[1]-5*u,10*u,6*u);if(Math.sin(game.time*(20-c.fuse*5))>0){g.fillStyle='#ff5a3a';g.beginPath();g.arc(s[0],s[1]-6*u,2*u,0,Math.PI*2);g.fill()}}
const ECOL={rifle:'#d65a3a',gren:'#e2b436',breach:'#ff8a5a',shield:'#9aa4ae',medic:'#8fe0a0',spotter:'#ff5a4a',fire:'#ff9a2a'};
function itemEnemy(e){
  if(e.type==='boss'){const B=BOSSES[e.boss];if(!B)return;const I=bossInfo(e.boss);
    if(e.burrow||(e.boss==='foreman'&&(e.st===2||e.st===4))){drawMound(e);return}
    const rf=B.raft&&e.raft!==false;if(rf)drawRaft(e);const kb=bossBase(e.boss);
    drawPerson(e.x,e.y,Object.assign({aim:e.aim,walk:rf?0:e.walk,flash:e.flash>0,hp:e.hp/e.max,big:1.45,tag:I.name,tagCol:I.col,winterSt:e.st,swing:kb==='butcher'&&e.st<5?e.st|0:e.boss==='bluebutcher'&&e.st===5?1:0},I.look));
    if(e.boss==='bulldozer'&&e.st===6)drawDazed(e);drawAmmoStatus(e);return}
  drawPerson(e.x,e.y,Object.assign({aim:e.aim,walk:e.walk,flash:e.flash>0,hp:e.hp/e.max},LOOK[e.type]||LOOK.rifle,{satchel:e.type==='breach'&&!e.planted},e.type==='shield'?{big:1.1}:null));
  drawAmmoStatus(e);
  if(e.type==='medic'&&game.phase==='raid'){const c=iso(e.x,e.y);g.strokeStyle='rgba(143,224,160,.35)';g.lineWidth=1.2*u;g.beginPath();g.ellipse(c[0],c[1],TW2*2.6,TH2*2.6,0,0,Math.PI*2);g.stroke()}   // his healing reach
}
function drawAmmoStatus(e){
  if(!(e.burnT>0||e.slowT>0))return;const c=iso(e.x,e.y);g.save();g.lineWidth=1.8*u;
  if(e.burnT>0){g.strokeStyle='#ff8244';g.beginPath();g.ellipse(c[0],c[1]-2*u,10*u,4*u,0,0,Math.PI*2);g.stroke()}
  if(e.slowT>0){g.strokeStyle='#81dafa';g.beginPath();g.ellipse(c[0],c[1]+2*u,13*u,5*u,0,0,Math.PI*2);g.stroke()}
  g.restore();
}
// the Ferryman's raft, bobbing under him
function drawRaft(e){const c=iso(e.x,e.y),b=Math.sin(game.time*2.2+e.id)*1.5*u;
  g.save();g.translate(c[0],c[1]+b);g.strokeStyle='rgba(170,210,230,.4)';g.lineWidth=1.2*u;g.beginPath();g.ellipse(0,2*u,34*u,13*u,0,0,Math.PI*2);g.stroke();
  for(let k=-2;k<=2;k++){const y=k*4.4*u;g.fillStyle=k%2?'#6b4f33':'#5a4330';g.beginPath();g.moveTo(-26*u+Math.abs(k)*3*u,y-2*u);g.lineTo(26*u-Math.abs(k)*3*u,y-2*u+ -k*2*u);g.lineTo(26*u-Math.abs(k)*3*u,y+2.4*u-k*2*u);g.lineTo(-26*u+Math.abs(k)*3*u,y+2.4*u);g.closePath();g.fill()}
  g.fillStyle='#2c2016';g.fillRect(-2*u,-24*u,3*u,24*u);g.fillStyle='#d8c9a8';g.beginPath();g.moveTo(1*u,-23*u);g.lineTo(14*u,-14*u);g.lineTo(1*u,-8*u);g.closePath();g.fill();
  g.restore()}
// the Foreman underground: a moving mound of broken earth; it swells before he bursts up
function drawMound(e){const c=iso(e.x,e.y),sw=e.st===4?1.35+Math.sin(game.time*40)*.08:1,t=game.time*6;
  g.save();g.translate(c[0],c[1]);g.scale(sw,sw);oval(0,1*u,18*u,7*u,'rgba(0,0,0,.35)');
  for(let k=0;k<7;k++){const a=k/7*Math.PI*2+t*.3,r=(8+hash(k,e.id)*5)*u;oval(Math.cos(a)*r,Math.sin(a)*r*.45-2*u,(5+hash(k+3,e.id)*3)*u,(3+hash(k+5,e.id)*2)*u,k%2?'#5a4838':'#4a3a2c')}
  oval(0,-4*u,9*u,5*u,'#6b5642');g.restore()}
function itemQM(q){drawPerson(q.x,q.y,Object.assign({aim:q.aim,walk:q.walk,flash:q.flash>0,tag:'DELGADO'},QM_LOOK))}
function itemQMDown(q){drawDowned(q.x,q.y,QM_LOOK,q.revive/2,'DELGADO · DOWN')}
function itemPlayer(o){
  const p=player,PL=playerLook(o),me=o===p,tag=me||players.size<2?null:o.name.toUpperCase();
  if(o._shotDrawUntil>game.time)PL.syncRender=true;
  if(game.pvp){PL.mark=teamCol(o);if(game.pvp==='base')PL.ring=teamCol(o);else if(me)PL.ring='#e2b436'}
  const bf=NET.mode==='guest'?(o.boltF||0):(o.bolt>0?o.bolt/o.boltT:0);if(bf>0)PL.bolt=1-bf;
  if(o.alive)drawPerson(o.x,o.y,Object.assign({aim:o.aim,walk:o.walk,flash:o.flash>0,tag,tagCol:game.pvp?teamCol(o):SLOTCOL[o.slot%6],faded:o.prot>0||stealthed(o),hp:game.pvp&&!me&&o.hp<o.max?o.hp/o.max:undefined},PL));
  else drawDowned(o.x,o.y,PL,o.revive/2.2,me?(o.rt>1e5?'DOWN · UNTIL THE RAID IS BROKEN':`DOWN · ${Math.ceil(o.rt)}`):`${o.name.toUpperCase()} · DOWN`);
}
// v0.9.3.7: corner brackets on the raider a touch grenade or rocket will lock onto
function drawLock(e){
  const c=iso(e.x,e.y),r=(e.big?16:11)*u,cy=c[1]-WH*.55*(e.big?1.4:1),k=r*.45,pulse=1+.08*Math.sin(game.time*8);
  g.save();g.strokeStyle='#ffd24a';g.lineWidth=2*u;g.globalAlpha=.9;g.beginPath();
  for(const [sx,sy] of [[-1,-1],[1,-1],[1,1],[-1,1]]){const x=c[0]+sx*r*pulse,y=cy+sy*r*pulse;g.moveTo(x-sx*k,y);g.lineTo(x,y);g.lineTo(x,y-sy*k)}
  g.stroke();g.restore();
}
function render(dt){
  PM('pre');const p=player;
  if(!caches||caches.key!==cacheKey())makeCaches();
  fadeT-=dt;if(fadeT<=0){fadeT=.1;updateFades()}
  let fx=p.x,fy=p.y,cxF=W<760?.4:.5,cyF=.52; // keep the east approach clear of the kit column on phones
  if(p.out&&!demo){const s=spectateTarget(p);fx=s.x;fy=s.y}   // v0.9.4.0: out of the Final Blitz, you watch your crew
  if(demo){const t=game.time*.07;fx=core.i+2.5+Math.cos(t)*2.5;fy=core.j-2+Math.sin(t)*2;cxF=.5;cyF=W>700?.5:.3}
  const tx=W*cxF-(fx-fy)*TW2,ty=H*cyF-(fx+fy)*TH2+heightAt(fx,fy)*heightPx();
  camSX+=(tx-camSX)*.14;camSY+=(ty-camSY)*.14;
  const sh=shakeOffset(dt);camX=snapPx(camSX+sh[0]);camY=snapPx(camSY+sh[1]);
  const bk=caches.back,bx=camX+bk.minX,by=camY+bk.minY;
  if(!(bx<=0&&by<=0&&bx+bk.w>=W&&by+bk.h>=H)){g.fillStyle='#10140e';g.fillRect(0,0,W,H)}
  PM('back');drawCache(caches.back);drawTerrainLive();drawFrostFields();drawWinterTelegraphs();PM('items');
  if(game.pvp==='base'&&game.phase==='build'&&!demo){const a=iso(0,0),b=iso(N,N);g.save();g.strokeStyle='rgba(226,180,54,.55)';g.lineWidth=2*u;g.setLineDash([7*u,6*u]);g.beginPath();g.moveTo(a[0],a[1]);g.lineTo(b[0],b[1]);g.stroke();g.restore();
    const m=iso(N*.5,N*.5);label('TRUCE LINE',m[0],m[1]+14*u,'rgba(226,180,54,.8)',11)}
  RI.n=0;const pd=p.x+p.y,pl=p.x-p.y;
  for(let k=0;k<N*N;k++){
    const i=k%N,j=(k/N)|0;
    if(MAP===MAPS.frost&&heights[k]&&!connectors[k]&&((j+1<N&&heights[k]>heights[k+N]+(connectors[k+N]?1:0))||(i+1<N&&heights[k]>heights[k+1])))ritem(i+j+2,itemFrostCliff,k);
    if(walls[k]){const dd=i+j+1-pd,lat=(i-j)-pl;ritem(i+j+1,itemWall,k,dd>0&&dd<3.2&&Math.abs(lat)<1.7)}
    else if(debris[k])ritem(i+j+.2,itemDebris,k);
    if(terr[k]>=T_ROCK)ritem(i+j+1,itemTerr,k);   // rock and oil drums
  }
  for(const n of nodes)ritem(n.i+n.j+1,drawNode,n);
  for(const c of cores)ritem(c.i+c.j+1,drawStake,c);
  for(const s of sacks)ritem(s.x+s.y,itemSack,s);
  for(const c of charges)ritem(c.x+c.y,itemCharge,c);
  for(const e of enemies)ritem(e.x+e.y,itemEnemy,e);
  if(qm.alive)ritem(qm.x+qm.y,itemQM,qm);else if(!qm.gone)ritem(qm.x+qm.y,itemQMDown,qm);
  if(!demo)for(const o of players.values())if(o.alive||o.downed)ritem(o.x+o.y,itemPlayer,o);
  if(playing()&&p.alive&&cfg.build&&game.pvp!=='ffa'){const t=buildTarget(p,game.sel,game.piece==='door');ritem(t.i+t.j+1.05,drawGhost,t)}
  const O=RI.o;O.length=RI.n;for(let k=0;k<RI.n;k++)O[k]=k;O.sort(byDepth);
  for(let q=0;q<RI.n;q++){const k=O[q];RI.f[k](RI.a[k],RI.b[k])}
  RI.a.fill(null,0,RI.n);PM('bullets');
  g.lineCap='round';
  for(const b of bullets)drawTracer(b);
  if(playing()&&touchMode&&!padMode&&p.alive&&!game.pvp){const e=lockNow(p);if(e)drawLock(e)}
  g.lineCap='butt';
  for(const l of lobs){if(l.t<0)continue;const t=l.t/l.T,x=l.x0+(l.x1-l.x0)*t,y=l.y0+(l.y1-l.y0)*t,z=Math.sin(Math.PI*t)*((l.k===3||l.k===5?90:40)+Math.hypot(l.x1-l.x0,l.y1-l.y0)*9)*u+WH*.5*(1-t);
    const c=iso(x,y,heightAt(l.x0,l.y0)+(heightAt(l.x1,l.y1)-heightAt(l.x0,l.y0))*t);g.fillStyle='rgba(0,0,0,.35)';g.beginPath();g.ellipse(c[0],c[1],3*u,1.5*u,0,0,Math.PI*2);g.fill();
    if(l.k===1){g.fillStyle='#2f6a3a';g.fillRect(c[0]-2*u,c[1]-z-3*u,4*u,6*u);g.fillStyle='#ffb040';g.beginPath();g.arc(c[0],c[1]-z-4.5*u,1.8*u+Math.sin(game.time*30)*.6*u,0,Math.PI*2);g.fill()}   // fire bottle
    else if(l.k>=3&&l.k<=5){drawBlitzLob(l,c,z,t)}   // v0.9.4.0: missile, napalm bottle, artillery shell
    else if(l.k===2){g.fillStyle='#6f695f';g.strokeStyle=OUT;g.lineWidth=1.2*u;g.beginPath();g.moveTo(c[0]-7*u,c[1]-z);g.lineTo(c[0]-4*u,c[1]-z-6*u);g.lineTo(c[0]+6*u,c[1]-z-5*u);g.lineTo(c[0]+7*u,c[1]-z+2*u);g.lineTo(c[0]-2*u,c[1]-z+4*u);g.closePath();g.fill();g.stroke()}   // rock slab
    else{g.fillStyle='#262219';g.beginPath();g.arc(c[0],c[1]-z,3*u,0,Math.PI*2);g.fill()}
    const e=iso(l.x1,l.y1);g.strokeStyle=l.k===1?'rgba(255,150,50,.6)':l.k===2?'rgba(255,177,58,.65)':l.k===4?'rgba(255,90,26,.7)':l.k===3||l.k===5?`rgba(255,60,40,${.55+.35*Math.sin(game.time*18)})`:'rgba(214,90,58,.55)';g.lineWidth=(l.k===3||l.k===5?2:1.2)*u;g.beginPath();g.ellipse(e[0],e[1],TW2*l.R*.9*(1-t*.3),TH2*l.R*.9*(1-t*.3),0,0,Math.PI*2);g.stroke()}
  PM('parts');for(const q of parts){if(q.kind.startsWith('finish:'))continue;const c=iso(q.x,q.y),a=Math.max(0,q.life/q.max);
    if(q.kind==='bubble'){const r=q.size*u*(1.25-a*.25),cx=c[0]+Math.sin(game.time*4+q.h)*2*u,cy=c[1]-q.z;g.globalAlpha=Math.min(1,a*1.8);
      g.fillStyle='rgba(255,226,130,.16)';g.beginPath();g.arc(cx,cy,r,0,Math.PI*2);g.fill();g.lineWidth=1.3*u;g.strokeStyle='#ffd24a';g.stroke();
      g.lineWidth=.8*u;g.strokeStyle=`hsl(${(game.time*220+q.h)%360},95%,78%)`;g.beginPath();g.arc(cx,cy,r*.8,-2.4,-.6);g.stroke();
      g.fillStyle='#fffbe8';g.fillRect(cx-r*.45,cy-r*.55,1.4*u,1.4*u);g.globalAlpha=1;continue}
    if(q.kind==='bat'){const cx=c[0],cy=c[1]-q.z,s=q.size*u,f=Math.sin(game.time*34+q.h)*.9;g.globalAlpha=Math.min(1,a*2);g.strokeStyle='#120c16';g.lineWidth=1.3*u;
      g.beginPath();g.moveTo(cx-s*1.3,cy-s*f*.8);g.lineTo(cx-s*.5,cy-s*.1);g.lineTo(cx,cy-s*.3);g.lineTo(cx+s*.5,cy-s*.1);g.lineTo(cx+s*1.3,cy-s*f*.8);g.stroke();
      g.fillStyle='#120c16';g.beginPath();g.arc(cx,cy,s*.32,0,Math.PI*2);g.fill();g.fillStyle='#ff3a3a';g.fillRect(cx-s*.2,cy-s*.12,u*.8,u*.8);g.globalAlpha=1;continue}
    if(q.kind==='spider'){if(q.z<WH*.25){q.z=WH*.25;q.vz=0}const cx=c[0],cy=c[1]-q.z,s=q.size*u,top=cy-WH*2.6,sw=Math.sin(game.time*3+q.h)*1.5*u;g.globalAlpha=Math.min(1,a*2.5);
      g.strokeStyle='rgba(235,235,245,.8)';g.lineWidth=.7*u;g.beginPath();g.moveTo(cx,top);g.lineTo(cx+sw,cy-s);g.stroke();g.strokeStyle='#15101a';g.lineWidth=.9*u;
      for(let k=0;k<4;k++){const yy=cy-s*.4+k*s*.35,wv=Math.sin(game.time*12+k)*s*.15;g.beginPath();g.moveTo(cx+sw-s*1.5,yy-s*.5+wv);g.lineTo(cx+sw-s*.8,yy-s*.9);g.lineTo(cx+sw,yy);g.lineTo(cx+sw+s*.8,yy-s*.9);g.lineTo(cx+sw+s*1.5,yy-s*.5-wv);g.stroke()}
      g.fillStyle='#15101a';g.beginPath();g.arc(cx+sw,cy,s*.75,0,Math.PI*2);g.fill();g.beginPath();g.arc(cx+sw,cy-s*.8,s*.45,0,Math.PI*2);g.fill();
      g.fillStyle='#b8261e';g.fillRect(cx+sw-s*.3,cy-s*.1,s*.6,s*.5);g.globalAlpha=1;continue}
    if(q.kind==='soul'){const cx=c[0]+Math.sin(game.time*2.4+q.h)*3*u,cy=c[1]-q.z,s=q.size*u;g.globalAlpha=Math.min(.85,a*1.4);g.fillStyle='#d8ffe8';
      g.beginPath();g.arc(cx,cy-s*.4,s,Math.PI,0);g.lineTo(cx+s,cy+s*.9);for(let k=3;k>=0;k--){const xx=cx-s+k*s*.5,yy=cy+s*.9+((k+Math.floor(game.time*8))%2?s*.35:0);g.lineTo(xx+s*.5,yy);g.lineTo(xx,cy+s*.9)}g.closePath();g.fill();
      g.fillStyle='#0e3a26';g.fillRect(cx-s*.5,cy-s*.55,s*.3,s*.38);g.fillRect(cx+s*.2,cy-s*.55,s*.3,s*.38);g.globalAlpha=1;continue}
    if(paintCosmeticParticle(g,q,c[0],c[1]-q.z,u,game.time))continue;
    if(q.c1){g.globalAlpha=Math.min(1,a*1.5);g.fillStyle=mix(q.c1,q.c2,Math.round((1-a)*16)/16);g.fillRect(c[0]-q.size*u/2,c[1]-q.z-q.size*u/2,q.size*u,q.size*u);g.globalAlpha=1;continue}
    if(q.kind==='dust'||q.kind==='smoke'){g.globalAlpha=a*(q.kind==='smoke'?.5:.4);g.fillStyle=q.rgb||(q.rgb=q.col.replace('rgba','rgb').replace(/,$/,')'));g.beginPath();g.arc(c[0],c[1]-q.z,q.size*u*(1.6-a*.6),0,Math.PI*2);g.fill();g.globalAlpha=1}
    else{g.globalAlpha=Math.min(1,a*1.5);g.fillStyle=q.col;g.fillRect(c[0]-q.size*u/2,c[1]-q.z-q.size*u/2,q.size*u,q.size*u);g.globalAlpha=1}}
  PM('front');drawCache(caches.front);PM('light');
  drawLighting();drawFinishEffects();drawBossFx();PM('flash');
  g.globalCompositeOperation='lighter';
  // glows stamped 1:1 from pre-drawn sizes, like the light holes (stretching the 64 px glow was the slow part)
  if(flashes.length){g.setTransform(1,0,0,1,0,0);
    for(const f of flashes){const c=flashPoint(f),a=f.life/f.max,r=TW2*f.r*(f.muzzle?1:2.2)*(f.muzzle?1:1.4-a*.4),im=softDot(GLOW_DOTS,r*DPR,SOFT_GLOW);
      g.globalAlpha=a;g.drawImage(im,Math.round(c[0]*DPR)-(im.width>>1),Math.round(c[1]*DPR)-(im.width>>1))}
    g.setTransform(DPR,0,0,DPR,0,0)}
  g.globalAlpha=1;
  g.globalCompositeOperation='source-over';
  drawStorm(dt);drawVignette(demo);PM('floats');
  for(const f of floats){const c=iso(f.x,f.y),a=f.life/f.max;g.globalAlpha=Math.min(1,a*2);label(f.t,c[0],c[1]-WH*1.5-(1-a)*24*u,f.col,11);g.globalAlpha=1}
  PM('ui');if(playing()&&!overlayOpen())drawPrompts(p);if(game.fb&&!demo)drawEvacHud();
  if(playing()&&p.alive&&!overlayOpen()){drawCrosshair(p);drawShells(p)}
  const top=110;
  for(const e of game.pvp&&!demo?foes():enemies){const c=iso(e.x,e.y);if(c[0]>14&&c[0]<W-14&&c[1]>top&&c[1]<H-14)continue;
    const ex=clamp(c[0],18,W-18),ey=clamp(c[1],top+8,H-18),a=Math.atan2(c[1]-H/2,c[0]-W/2);
    g.save();g.translate(ex,ey);g.rotate(a);if(e.type==='boss')g.scale(1.6,1.6);g.fillStyle=game.pvp?teamCol(e):e.type==='boss'?bossInfo(e.boss).col||'#ff4a3a':ECOL[e.type]||'#ff8a5a';g.beginPath();g.moveTo(8,0);g.lineTo(-5,-6);g.lineTo(-5,6);g.closePath();g.fill();g.restore()}
  if(!demo&&!game.pvp)drawBossBars(top);
  if(touchMode&&playing()&&!game.paused){
    for(const[s,lab]of[[stickMove,'MOVE'],[stickAim,'AIM · FIRE']]){
      if(s.id!==null){g.strokeStyle='rgba(220,210,186,.35)';g.lineWidth=2;g.beginPath();g.arc(s.ox,s.oy,SR,0,Math.PI*2);g.stroke();
        g.strokeStyle='rgba(226,180,54,.25)';g.beginPath();g.arc(s.ox,s.oy,SR*.5,0,Math.PI*2);g.stroke();
        g.fillStyle=s===stickAim&&s.mag>.5?'rgba(226,180,54,.8)':'rgba(220,210,186,.55)';g.beginPath();g.arc(s.ox+s.vx*SR,s.oy+s.vy*SR,20,0,Math.PI*2);g.fill()}
      else if(game.wave===0&&game.time<25){const x=s===stickMove?W*.2:W*.6,y=H-100;g.strokeStyle='rgba(220,210,186,.18)';g.lineWidth=2;g.beginPath();g.arc(x,y,SR*.8,0,Math.PI*2);g.stroke();
        g.font='600 11px "IBM Plex Mono", monospace';g.textAlign='center';g.fillStyle='rgba(220,210,186,.45)';g.fillText(lab,x,y+4)}
    }
  }
  PM('end');
}

