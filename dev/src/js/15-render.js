/* ================= rendering ================= */
const HEXC=new Map(),MIXC=new Map();
const hex=h=>{let v=HEXC.get(h);if(!v){v=[parseInt(h.slice(1,3),16),parseInt(h.slice(3,5),16),parseInt(h.slice(5,7),16)];if(HEXC.size>512)HEXC.clear();HEXC.set(h,v)}return v};
const mix=(a,b,t)=>{const k=a+b+t;let v=MIXC.get(k);if(v===undefined){const A=hex(a),B=hex(b);v=`rgb(${Math.round(A[0]+(B[0]-A[0])*t)},${Math.round(A[1]+(B[1]-A[1])*t)},${Math.round(A[2]+(B[2]-A[2])*t)})`;if(MIXC.size>4096)MIXC.clear();MIXC.set(k,v)}return v};
function quad(a,b,c,d,fill){g.fillStyle=fill;g.beginPath();g.moveTo(a[0],a[1]);g.lineTo(b[0],b[1]);g.lineTo(c[0],c[1]);g.lineTo(d[0],d[1]);g.closePath();g.fill()}
const up=(p,h)=>[p[0],p[1]-h];
function boxR(x0,y0,x1,y1,z,h,top,l,r){
  const hz=heightAt((x0+x1)/2,(y0+y1)/2),A=iso(x0,y0,hz),B=iso(x1,y0,hz),C=iso(x1,y1,hz),D=iso(x0,y1,hz);
  quad(up(D,z),up(C,z),up(C,z+h),up(D,z+h),l);quad(up(C,z),up(B,z),up(B,z+h),up(C,z+h),r);
  quad(up(A,z+h),up(B,z+h),up(C,z+h),up(D,z+h),top);return{A,B,C,D};
}
const lerp2=(a,b,t)=>[a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t];
function faceLine(P,Q,h,v){const a=up(P,h*v),b=up(Q,h*v);g.beginPath();g.moveTo(a[0],a[1]);g.lineTo(b[0],b[1]);g.stroke()}
function doorSlab(P,Q,h,col,hc){const a=lerp2(P,Q,.3),b=lerp2(P,Q,.7);quad(a,b,up(b,h*.82),up(a,h*.82),col);const hd=up(lerp2(P,Q,.62),h*.42);g.fillStyle=hc||'#e2b436';g.fillRect(hd[0]-1*u,hd[1]-1*u,2*u,2*u)}
function drawWall(i,j,w,alpha){
  const st=wallState(w),key=(w.slab?'s':w.mat)+(w.cov||'')+'|'+(w.door?1:0)+'|'+st+'|'+Math.round(w.char*8)+'|'+(w.flash>0?1:0)+'|'+(w.tm||'')+'|'+TW2+'|'+DPR;
  let S=w._spr;if(!S||S.key!==key||S.i!==i||S.j!==j)S=w._spr=wallSprite(i,j,w,key);
  g.globalAlpha=alpha;g.drawImage(S.cv,camX+S.x,camY+S.y,S.w,S.h);
  if(w.fire>0){const c=iso(i+.5,j+.5),R=TW2*1.25,h=WH*(st===2?.58:1);g.globalAlpha=alpha*.85;g.drawImage(SOFT.glow,c[0]-R,c[1]-h-R,R*2,R*2)}
  g.globalAlpha=1;
}
function wallSprite(i,j,w,key){
  // the tile's box on screen (camera at 0,0), snapped to device pixels so the image copies 1:1
  const hz=heightAt(i+.5,j+.5)*heightPx(),x0=Math.floor(((i-j-1)*TW2-4*u)*DPR)/DPR,y0=Math.floor(((i+j)*TH2-hz-WH-4*u)*DPR)/DPR,x1=(i-j+1)*TW2+4*u,y1=(i+j+2)*TH2-hz+4*u;
  const cv2=document.createElement('canvas');cv2.width=Math.ceil((x1-x0)*DPR);cv2.height=Math.ceil((y1-y0)*DPR);
  const ctx=cv2.getContext('2d');ctx.setTransform(DPR,0,0,DPR,0,0);
  const kg=g,kx=camX,ky=camY;g=ctx;camX=-x0;camY=-y0;
  try{drawWallShape(i,j,w)}finally{g=kg;camX=kx;camY=ky}
  return{key,i,j,cv:cv2,x:x0,y:y0,w:cv2.width/DPR,h:cv2.height/DPR};
}
function drawWallShape(i,j,w){
  if(w.slab){   // the Foreman's rock slab: a rough grey block, lower as it cracks
    const st=wallState(w),h=WH*(st===2?.45:st===1?.6:.72),hs=hash(i+7,j+3);
    boxR(i+.1,j+.14,i+.9,j+.86,0,h,w.flash>0?'#9a948a':'#6f695f','#524d46','#403c37');
    boxR(i+.22+hs*.2,j+.24,i+.62+hs*.2,j+.6,h,WH*.18,'#7d766b','#5c5750','#4a4640');
    if(st>0){g.strokeStyle='#1c1a17';g.lineWidth=u;const c=iso(i+.5,j+.5);g.beginPath();g.moveTo(c[0]-6*u,c[1]-h*.8);g.lineTo(c[0]-1*u,c[1]-h*.4);g.lineTo(c[0]+4*u,c[1]-h*.7);g.stroke()}
    return}
  if(w.cov){drawCover(i,j,w);return}
  const m=MAT[w.mat],st=wallState(w),h=WH*(st===2?.58:1);
  let top=m.top,l=m.l,r=m.r;
  if(w.char>0){top=mix(top,'#241b15',w.char*.85);l=mix(l,'#1d1612',w.char*.85);r=mix(r,'#18120f',w.char*.85)}
  if(w.flash>0)top=mix(m.top,'#ffffff',.35);
  const {B,C,D}=boxR(i+.03,j+.03,i+.97,j+.97,0,h,top,l,r);
  g.strokeStyle=m.line;g.lineWidth=Math.max(1,u*.9);
  if(w.mat===2){for(const t of[.2,.4,.6,.8])for(const[P,Q]of[[D,C],[C,B]]){const a=lerp2(P,Q,t);g.beginPath();g.moveTo(a[0],a[1]);g.lineTo(a[0],a[1]-h);g.stroke()}}
  else{for(const v of[.33,.66])for(const[P,Q]of[[D,C],[C,B]])faceLine(P,Q,h,v);
    if(w.mat===1)for(const[P,Q]of[[D,C],[C,B]])for(const[t,v0]of[[.3,0],[.7,0],[.5,.33],[.15,.66],[.85,.66]]){const a=up(lerp2(P,Q,t),h*v0);g.beginPath();g.moveTo(a[0],a[1]);g.lineTo(a[0],a[1]-h*.33);g.stroke()}}
  if(w.door){const dc=w.mat===2?'#3b4142':w.mat===1?'#3a2418':'#3d2a17',hc=w.tm&&TEAMS[w.tm]?TEAMS[w.tm].col:null;doorSlab(D,C,h,dc,hc);doorSlab(C,B,h,dc,hc)}
  if(st>0){
    const n=st===1?2:3;g.fillStyle=w.mat===2&&st===1?'rgba(40,44,45,.75)':'#0e0b09';
    for(const[P,Q,s]of[[D,C,1],[C,B,2]])for(let q=0;q<n;q++){
      const hu=.2+hash(i*7+q+s*13,j*5)*.6,hv=.25+hash(i*3+q,j*11+s)*.5,pt=up(lerp2(P,Q,hu),h*hv);
      g.beginPath();g.ellipse(pt[0],pt[1],(2.2+st)*u,(2.8+st)*u,0,0,Math.PI*2);g.fill();
    }
  }
}
// Free-for-all cover (it can't be broken): stacked timber, a ruined shed's walls, or a supply crate
function drawCover(i,j,w){
  const hs=hash(i*3+1,j*7+2),fl=w.flash>0;
  if(w.cov==='timber'){
    const h=WH*.78,{B,C,D}=boxR(i+.08,j+.08,i+.92,j+.92,0,h,fl?'#d8b27a':'#a47a46','#7a5530','#5e4024');
    g.fillStyle='#c9a06a';g.strokeStyle='rgba(40,24,10,.7)';g.lineWidth=Math.max(1,u*.8);
    for(const[P,Q]of[[D,C],[C,B]])for(let r=0;r<3;r++)for(let q=0;q<3;q++){const a=up(lerp2(P,Q,.18+q*.32),h*(.17+r*.31));g.beginPath();g.ellipse(a[0],a[1],3.1*u,3.1*u,0,0,Math.PI*2);g.fill();g.stroke()}
    g.strokeStyle='#3a2612';g.lineWidth=1.4*u;const c=iso(i+.5,j+.5);g.beginPath();g.moveTo(c[0]-TW2*.8,c[1]-h+2*u);g.lineTo(c[0]+TW2*.8,c[1]-h+2*u);g.stroke();
    return}
  if(w.cov==='shed'){
    const h=WH*(.62+hs*.3),{B,C,D}=boxR(i+.12,j+.12,i+.88,j+.88,0,h,fl?'#8a7a64':'#5b4c3a','#4a3d2e','#3a3024');
    g.strokeStyle='rgba(20,14,8,.6)';g.lineWidth=Math.max(1,u*.8);for(const[P,Q]of[[D,C],[C,B]])for(const t of[.25,.5,.75]){const a=lerp2(P,Q,t);g.beginPath();g.moveTo(a[0],a[1]);g.lineTo(a[0],a[1]-h*(.8+hash(i+t*9,j)*.2));g.stroke()}
    g.fillStyle='#2a2119';const c=iso(i+.5,j+.5);g.beginPath();g.moveTo(c[0]-5*u,c[1]-h);g.lineTo(c[0]+1*u,c[1]-h-6*u);g.lineTo(c[0]+5*u,c[1]-h);g.closePath();g.fill();   // a snapped board
    return}
  if(w.cov==='crate'){
    const h=WH*.66,{B,C,D}=boxR(i+.14,j+.14,i+.86,j+.86,0,h,fl?'#c9a877':'#8f7148','#6d5433','#553f25');
    g.strokeStyle='#3a2a16';g.lineWidth=1.3*u;for(const[P,Q]of[[D,C],[C,B]]){const a=P,b=Q,c=up(Q,h),d=up(P,h);g.beginPath();g.moveTo(a[0],a[1]);g.lineTo(c[0],c[1]);g.moveTo(b[0],b[1]);g.lineTo(d[0],d[1]);g.stroke()}
    return}
  boxR(i+.03,j+.03,i+.97,j+.97,0,WH,MAT[3].top,MAT[3].l,MAT[3].r);
}
function drawDebris(i,j,mat){const m=MAT[mat];for(let q=0;q<3;q++){const a=hash(i+q*17,j),b=hash(i,j+q*29),x=i+.15+a*.55,y=j+.15+b*.55;boxR(x,y,x+.22,y+.18,0,3.5*u,m.top,m.l,m.r)}}
// Labels (name tags, damage numbers, stake names) are cached as small images: outlined text is one of the
// costlier things to redraw 60 times a second on a phone. Same look as drawing the text directly.
const LABELS=new Map();
try{document.fonts.ready.then(()=>LABELS.clear());document.fonts.addEventListener('loadingdone',()=>LABELS.clear())}catch(e){}
function label(t,x,y,col,size=11){
  t=String(t);const px=Math.round(size*u),key=t+'|'+col+'|'+px+'|'+DPR;let S=LABELS.get(key);
  if(S){LABELS.delete(key);LABELS.set(key,S)}   // most recently used last
  else{
    const font=`800 ${px}px "Big Shoulders Stencil Display", "Arial Narrow", sans-serif`;g.font=font;
    const w=Math.ceil(g.measureText(t).width)+6,h=Math.ceil(px*1.5)+6,asc=Math.ceil(px*1.1)+3,cv2=document.createElement('canvas');
    cv2.width=Math.ceil(w*DPR);cv2.height=Math.ceil(h*DPR);const c=cv2.getContext('2d');c.setTransform(DPR,0,0,DPR,0,0);
    c.font=font;c.textAlign='center';c.lineWidth=3;c.strokeStyle='rgba(12,10,8,.85)';c.strokeText(t,w/2,asc);c.fillStyle=col;c.fillText(t,w/2,asc);
    S={cv:cv2,w,h,asc};LABELS.set(key,S);if(LABELS.size>160)LABELS.delete(LABELS.keys().next().value);
  }
  g.drawImage(S.cv,x-S.w/2,y-S.asc,S.w,S.h);
}
function drawNode(n){
  const {i,j}=n;
  if(n.type===0){
    const layers=Math.ceil(n.amt/16);
    if(!layers){boxR(i+.3,j+.4,i+.7,j+.55,0,2*u,'#6b4a28','#4f361d','#3e2a16');return}
    for(let s=0;s<layers;s++){boxR(i+.18,j+.22,i+.82,j+.48,s*5*u,5*u,'#c09058','#8b6236','#6b4a28');boxR(i+.18,j+.52,i+.82,j+.78,s*5*u,5*u,'#b8894f','#86603a','#654626')}
  }else if(n.type===1){
    const lk=n.locked,c=lk?['#6a5048','#4c3a34','#3a2c28']:[MAT[1].top,MAT[1].l,MAT[1].r];
    const {C,D}=boxR(i+.1,j+.1,i+.9,j+.9,0,WH*1.05,c[0],c[1],c[2]);
    const m=lerp2(D,C,.5);g.fillStyle=lk?'#1a1412':'#2a0f06';g.beginPath();g.ellipse(m[0],m[1]-WH*.3,5*u,7*u,0,0,Math.PI*2);g.fill();
    if(!lk){g.fillStyle=`rgba(255,${140+Math.sin(game.time*6)*30|0},50,.8)`;g.beginPath();g.ellipse(m[0],m[1]-WH*.25,3.4*u,4.5*u,0,0,Math.PI*2);g.fill()}
    boxR(i+.55,j+.15,i+.8,j+.4,WH*1.05,WH*.9,c[0],c[1],c[2]);
  }else{
    const cs=n.locked?['#5d6262','#454a4a','#353939']:[MAT[2].top,MAT[2].l,MAT[2].r];
    boxR(i+.12,j+.2,i+.62,j+.7,0,WH*.5,cs[0],cs[1],cs[2]);boxR(i+.45,j+.1,i+.9,j+.55,0,WH*.8,cs[0],cs[1],cs[2]);boxR(i+.3,j+.55,i+.85,j+.9,0,WH*.3,cs[0],cs[1],cs[2]);
  }
  if(n.locked){const c=iso(i+.5,j+.5);label(`${n.type===1?'KILN':'SCRAP'} · ${n.poi?'CUT OFF':'OPENS RAID '+n.unlock}`,c[0],c[1]-WH*2.1,'#9a8f7a')}
}
function drawStake(c){
  const {i,j}=c,f=c.flash>0,band=c.team&&TEAMS[c.team]?TEAMS[c.team].col:'#e2b436';
  const {C,D,B}=boxR(i+.14,j+.14,i+.86,j+.86,0,WH*1.15,f?'#8a4a34':'#4d5c40',f?'#6a3424':'#38452e',f?'#50281c':'#2a3421');
  for(const[P,Q]of[[D,C],[C,B]])quad(up(P,WH*.62),up(Q,WH*.62),up(Q,WH*.8),up(P,WH*.8),band);
  const top=iso(i+.5,j+.5),px=top[0],py=top[1]-WH*1.15;
  g.strokeStyle='#1b1812';g.lineWidth=2*u;g.beginPath();g.moveTo(px,py);g.lineTo(px,py-28*u);g.stroke();
  const fl=Math.sin(game.time*5)*2*u;g.fillStyle=band;g.beginPath();g.moveTo(px,py-28*u);g.lineTo(px+15*u,py-24*u+fl);g.lineTo(px,py-19*u);g.fill();
  if(light.L>.4){g.fillStyle='#fff2c4';g.beginPath();g.arc(px,py-30*u,2.2*u,0,Math.PI*2);g.fill()}
  if(game.pvp==='base'){const mine=player&&c.team===player.team;label(mine?'YOUR STAKE':'ENEMY STAKE',px,py-36*u,band,10);
    const w=34*u,hb=4*u,x0=px-w/2,y0=py-33*u;g.fillStyle='rgba(10,8,6,.85)';g.fillRect(x0-1,y0-1,w+2,hb+2);g.fillStyle=band;g.fillRect(x0,y0,w*Math.max(0,c.hp/c.max),hb)}
}
