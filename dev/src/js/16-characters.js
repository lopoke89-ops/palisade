/* ---------- characters: outlined, limbs, kit that reads at a glance ---------- */
const OUT='rgba(14,12,10,.95)',LIT='#f3e9d6',FIG=1.18;
function P(pts,col,outline=true){g.beginPath();g.moveTo(pts[0][0],pts[0][1]);for(let i=1;i<pts.length;i++)g.lineTo(pts[i][0],pts[i][1]);g.closePath();g.fillStyle=col;g.fill();if(outline){g.strokeStyle=OUT;g.lineWidth=1.1;g.stroke()}}
function seg(a,b,col,w){g.strokeStyle=col;g.lineWidth=w;g.beginPath();g.moveTo(a[0],a[1]);g.lineTo(b[0],b[1]);g.stroke()}
function limb(a,b,col,w){g.lineCap='round';seg(a,b,OUT,w+1.8);seg(a,b,col,w);g.lineCap='butt'}
const rectP=(cx,cy,w,h)=>[[cx-w/2,cy-h/2],[cx+w/2,cy-h/2],[cx+w/2,cy+h/2],[cx-w/2,cy+h/2]];
function domeP(cx,cy,r){const p=[];for(let k=0;k<=8;k++){const a=Math.PI+Math.PI*k/8;p.push([cx+Math.cos(a)*r,cy+Math.sin(a)*r])}return p}
function disc(x,y,r,col){g.fillStyle=col;g.beginPath();g.arc(x,y,r,0,Math.PI*2);g.fill()}
function oval(x,y,rx,ry,col){g.fillStyle=col;g.beginPath();g.ellipse(x,y,rx,ry,0,0,Math.PI*2);g.fill()}
const dark=(c,f)=>mix(c,'#000000',f);
function neonSeg(a,b,col){const A=g.globalAlpha;g.globalAlpha=A*.32;seg(a,b,col,3.4);g.globalAlpha=A;seg(a,b,col,1.15)}
/* Character illustration: presentation only; consumes existing look fields. */
// Weapon table (model units; every gun points along +z from its butt). x/y: where the gun sits beside the body;
// butt: how far in front of the chest the stock starts; stock/recv: [length, height, width, colour]; grip: rear hand;
// fore/foreL: where the front hand holds and how long the fore-end is; barrel: radius. The painter and the muzzle
// measurement both read this, so a new held item only needs a row here.
function createWardrobeRenderer(){
const WEAPON_TABLE={
 carbine:{x:5.9,y:21.9,butt:4.3,stock:[4.2,2.4,1.8,'#3e4336'],recv:[5.2,2.3,1.85,'#303b3b'],grip:5.3,mag:[1.6,3,1.3],magZ:6.6,fore:9.6,foreL:3.8,foreC:'#4a5040',barrel:.55},
 rifle:{x:5.9,y:21.9,butt:4.3,stock:[4.6,2.5,1.75,'#4d3a26'],stockY:-.1,recv:[5.4,2.1,1.75,'#2e3431'],grip:5.6,fore:10.2,foreL:4.4,foreC:'#5a4430',barrel:.5,scope:true},
 sg:{x:6.3,y:19.6,butt:4.6,stock:[4.6,2.5,1.9,'#6a4526'],stockY:-.15,recv:[4.4,2.4,1.85,'#2e3534'],grip:5.6,fore:9.6,foreL:4.6,foreC:'#8a603a',foreW:1.9,foreH:1.6,foreY:-1.2,barrel:.6,tube:true,pump:true},
 smg:{x:5.9,y:21.9,butt:4.3,stock:[2.8,1.5,1.3,'#2a2e2b'],recv:[5,2.5,1.9,'#303836'],grip:4,mag:[1.2,3.8,1.2],magZ:6.2,magC:'#262b28',fore:7.9,foreL:2.8,foreC:'#3a403a',barrel:.5}
};
function weaponKind(o){return o.weapon==='sg'?'sg':(o.gl||14)>17?'rifle':(o.gl||14)<=11?'smg':'carbine'}
// two-bone reach: the elbow for a shoulder, a hand, the two bone lengths and a hint of which way the elbow bends
function reach(S,H,L1,L2,pole){
 const d0=[H[0]-S[0],H[1]-S[1],H[2]-S[2]],D=Math.hypot(...d0)||1,dir=d0.map(v=>v/D),d=Math.min(D,(L1+L2)*.999);
 const a=(L1*L1-L2*L2+d*d)/(2*d),h=Math.sqrt(Math.max(0,L1*L1-a*a)),pd=pole[0]*dir[0]+pole[1]*dir[1]+pole[2]*dir[2];
 let p=pole.map((v,i)=>v-dir[i]*pd);const pl=Math.hypot(...p)||1;p=p.map(v=>v/pl);
 return [0,1,2].map(i=>S[i]+dir[i]*a+p[i]*h);
}
// 60% planted travel / 40% lifted recovery. Height never falls below the resting sole.
function wardrobeStep(phase,side,weight=1,dir=0){
 const f=((phase/(Math.PI*2)+(side<0?.5:0))%1+1)%1,stance=f<.6,q=stance?f/.6:(f-.6)/.4;
 const stride=(stance?1-2*q:-1+2*q*q*(3-2*q))*2.15*weight,lift=stance?0:Math.sin(q*Math.PI)**2*1.35*weight;
 return {x:side*3.1+Math.sin(dir)*stride,z:Math.cos(dir)*stride,lift,stance};
}
function paintWardrobeCharacter(ctx,o,angle,time,scale,cx,cy,walking=false){
 const compact=scale<=6;
 // Outfit details are independent of the separately equipped headgear.
 const goldClown=!!(o.glitter&&o.dots),goldPolice=!!(o.glitter&&o.badge),goldKnight=!!(o.glitter&&o.plate);
 // Only luminous trim and specular highlights emit; fabric keeps its dark ink edges.
 const emit=new Set([o.neon,o.hneon,o.halo,o.visor,o.mask,o.frost,o.spots,
  ...(o.stars?['#f3eaff','#b2b5ff']:[]),...(o.holo?['#b5f5ff']:[]),
  ...(o.shine||o.chrome?['#fff1c1','#ffffff']:[]),...(o.glitter?['#fffbe0']:[]),
  o.reaper,o.phantom,o.lamp,...(o.pumpkin?[o.pking?'#ffb040':'#ffd35a','#ff7a1a']:[]),...(o.wraps?['#ffc94a']:[])].filter(Boolean));
 const ca=Math.cos(angle),sa=Math.sin(angle),phase=typeof walking==="number"?walking:walking?time*7:0;
 const weight=o.downed?0:o.gaitWeight===undefined?(walking?1:0):o.gaitWeight,dir=o.gaitDir||0;
 const bob=-(1-Math.cos(phase*2))*.14*weight+(o.downed?0:(o.breath||0)*.16),faces=[];
 const leg=side=>{const step=wardrobeStep(phase,side,weight,dir),ankle=[step.x,3.2+step.lift,step.z],hip=[side*2.6,14.4+bob,0];return {...step,ankle,hip,knee:reach(hip,ankle,6,6,[0,0,1])}};
 const hex=c=>{const m=/^#([0-9a-f]{6})$/i.exec(c||'');return m?m[1].match(/../g).map(s=>parseInt(s,16)):[90,95,75]};
 const tint=(c,k)=>{const v=hex(c);return '#'+v.map(x=>Math.max(0,Math.min(255,Math.round(x*k))).toString(16).padStart(2,'0')).join('')};
 const project=p=>{const d=-p[0]*sa+p[2]*ca;return [p[0]*ca+p[2]*sa,-p[1]+d*.32,d+p[1]*.32]};
 const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
 const sub=(a,b)=>a.map((v,i)=>v-b[i]);
 function mesh(v,ff,col,outline=.55,bias=0){
  if(o.downed)v=v.map(q=>[q[1]*.8-14,q[2]*.8+4,q[0]*.8]);
  const vis=[],projected=v.map(project);
  for(const ids of ff){
   const A=v[ids[0]],B=v[ids[1]],C=v[ids[2]],ax=B[0]-A[0],ay=B[1]-A[1],az=B[2]-A[2],bx=C[0]-A[0],by=C[1]-A[1],bz=C[2]-A[2];
   const x=ay*bz-az*by,y=az*bx-ax*bz,z=ax*by-ay*bx,l=Math.hypot(x,y,z)||1;
   const nx=(x*ca+z*sa)/l,ny=y/l,nz=(-x*sa+z*ca)/l;
   if(nz+ny*.32<=.001)continue;
   const pts=ids.map(i=>projected[i]),light=.73+Math.max(0,-nx*.48+ny*.7+nz*.42)*.35;
   vis.push({ids,pts,emission:!o.flash&&emit.has(col)?col:null,col:o.flash?"#f3e9d6":tint(col,light),depth:pts.reduce((s,p)=>s+p[2],0)/pts.length+bias,edges:[],outline,bias});
  }
  const counts=new Map();for(const f of vis)for(let i=0;i<f.ids.length;i++){const a=f.ids[i],b=f.ids[(i+1)%f.ids.length],key=a<b?a*256+b:b*256+a;counts.set(key,(counts.get(key)||0)+1)}
  for(const f of vis){for(let i=0;i<f.ids.length;i++){const a=f.ids[i],b=f.ids[(i+1)%f.ids.length],key=a<b?a*256+b:b*256+a;if(counts.get(key)===1)f.edges.push([projected[a],projected[b]])}faces.push(f)}
 }
 const boxFaces=[[0,3,2,1],[4,5,6,7],[0,1,5,4],[3,7,6,2],[1,2,6,5],[0,4,7,3]];
 function box(x,y,z,w,h,d,col,outline=.48,bias=0){
  const v=[[-1,-1,-1],[1,-1,-1],[1,1,-1],[-1,1,-1],[-1,-1,1],[1,-1,1],[1,1,1],[-1,1,1]].map(p=>[x+p[0]*w/2,y+p[1]*h/2,z+p[2]*d/2]);mesh(v,boxFaces,col,outline,bias);
 }
 // Rounded octagonal sections keep the silhouette compact and avoid square toy limbs.
 function column(x,y,z,w,h,d,col,topScale=1,outline=.55){
  if(compact&&w<6){box(x,y,z,w,h,d,col,outline);return}
  const ring=[[-.72,-1],[.72,-1],[1,-.6],[1,.6],[.72,1],[-.72,1],[-1,.6],[-1,-.6]];
  const v=ring.map(p=>[x+p[0]*w/2,y-h/2,z+p[1]*d/2]).concat(ring.map(p=>[x+p[0]*w/2*topScale,y+h/2,z+p[1]*d/2*topScale]));
  const ff=[[7,6,5,4,3,2,1,0],[8,9,10,11,12,13,14,15]];for(let i=0;i<8;i++)ff.push([i,(i+1)%8,(i+1)%8+8,i+8]);mesh(v,ff.map(f=>f.slice().reverse()),col,outline);
 }
 function beam(a,b,r,col,r2=r,outline=.48){
  const axis=sub(b,a),L=Math.hypot(...axis),up=Math.abs(axis[1]/L)>.9?[0,0,1]:[0,1,0];let U=cross(axis,up);const ul=Math.hypot(...U);U=U.map(x=>x/ul);let V=cross(axis,U);const vl=Math.hypot(...V);V=V.map(x=>x/vl);
  const v=[],sides=compact?4:8;for(const [p,rr]of [[a,r],[b,r2]])for(let i=0;i<sides;i++){const t=2*Math.PI*i/sides;v.push(p.map((x,j)=>x+rr*(U[j]*Math.cos(t)+V[j]*Math.sin(t))))}
  const ff=[Array.from({length:sides},(_,i)=>sides-1-i),Array.from({length:sides},(_,i)=>i+sides)];for(let i=0;i<sides;i++)ff.push([i,(i+1)%sides,(i+1)%sides+sides,i+sides]);mesh(v,ff,col,outline);
 }
 const B=goldPolice?'#26334b':goldKnight?'#454039':o.body,V=goldClown?'#67293b':o.vest,H=o.helmet||o.cap||o.boonie||B,T=goldPolice?'#202b40':goldKnight?'#393630':o.pants||"#3b372c",skin=o.head;
 const bp=o.bolt===undefined?-1:o.bolt,kick=bp>=0&&bp<.2?(1-bp/.2)*.65:0,pull=bp>.24&&bp<.9?Math.sin((bp-.24)/.66*Math.PI):0,shotgun=o.weapon==="sg",sniper=(o.gl||14)>17;
 const W=WEAPON_TABLE[weaponKind(o)],gunX=W.x,gunY=W.y,gunZ=W.butt,gl=o.gl||14;
 // Measurement uses the very same projection and endpoints as the painted barrel.
 if(!ctx)return {tip:project([gunX,gunY+bob,gunZ+gl+2.4-kick]),root:project([gunX,gunY+bob,0])};
 // A planted stance, shaped thighs, separate knees and substantial boots.
 for(const side of[-1,1]){
  const L=leg(side),{x,z,lift,ankle,knee,hip}=L;
  if(o.sahur){
   column(x,1.5+lift,1.05+z,3.4,2.2,5.3,'#9a6033',.85,.4);
   beam(ankle,knee,.95,B,1.05,.3);beam(knee,hip,1.05,B,1.2,.3);continue;
  }
  column(x,2+lift,1.05+z,4.3,3.1,6.1,'#35362e',.87);
  box(x,.7+lift,1.2+z,4.35,.85,6.25,'#202722',.3);
  beam(ankle,knee,1.7,T,2);beam(knee,hip,2.05,T,2.35);
  column(knee[0],knee[1],knee[2]+1.75,2.8,3.2,1.25,tint(T,.75),.88,.32);
  box(side*4.7,11.7+bob,0,1.5,3.3,2.75,tint(T,1.1),.3);
 }
 if(o.sahur){
  // One continuous wooden silhouette, kept inside the existing pose frame.
  column(0,24.7+bob,0,9.5,22.6,7.6,B,.98,.5);
  for(const [x,y,h]of[[-2.6,24,8],[1.7,20.4,9],[-.3,28,5],[3.3,27,10]])
   beam([x,y-h/2+bob,3.84],[x+.25,y+h/2+bob,3.84],.09,'#8b552f',.07,.03);
  for(const side of[-1,1])beam([side*4.77,17+bob,-1],[side*4.77,32+bob,-.7],.1,'#8b552f',.08,.03);
  // A stowed wooden beater leaves both hands free for the equipped class weapon.
  beam([-5,15+bob,-2.8],[-6.5,27+bob,-2.8],.5,'#734724',.9,.25);
 }else{
 column(0,15+bob,0,9.1,3.8,5.2,B,1.06);
 column(0,21.2+bob,0,10.2,10.8,5.6,B,1.15);
 // Plate carrier has its own thickness, shoulder straps and three magazine pouches.
 column(0,21.7+bob,.1,10.3,8.8,6.35,V,1.02,.48);
 box(0,23.5+bob,3.36,6.6,3.2,.7,tint(V,1.1),.28);
 for(const x of[-3.8,3.8])box(x,23.8+bob,3.35,1.25,5.6,.8,tint(V,.72),.22);
 for(const x of[-2.9,0,2.9]){
  box(x,19.1+bob,3.75,2.35,3.65,1.55,tint(V,.94),.35);
  box(x,20.2+bob,4.6,2.35,.75,.22,tint(V,1.15),.12);
 }
 box(0,15.8+bob,0,9.35,1.35,5.8,'#35372b',.28);
 box(0,15.8+bob,3.03,1.6,1.25,.45,'#b6ac7c',.22);
 // Small collar separates the head from the vest.
 column(0,27+bob,0,4.5,2.8,3.6,skin,1,.32);
 box(-1.65,26.1+bob,2,2,1.7,2,tint(B,.85),.3);box(1.65,26.1+bob,2,2,1.7,2,tint(B,.85),.3);
 }

 // Arms: a two-bone reach from the shoulder to where each hand holds the gun (weapon table), with the elbows
 // bent down and out so the upper arms stay outside the chest and the gun sits clear in front of it.
 // Cosmetic recoil is short; the simulation's fire timing and aim are untouched.
 const shL=[-6.3,24.7+bob,1],shR=[6.3,24.7+bob,1];
 const haL=o.nogun?[-6.3,16+bob,1]:[gunX-.3,gunY-1.1+bob,gunZ+W.fore+W.foreL*.35-kick-(W.pump?pull*2:0)];
 const haR=o.nogun?[6.3,16+bob,1]:[gunX+.2+(sniper?pull*1.6:0),gunY-1.6+bob+(sniper?pull:0),gunZ+W.grip-kick-(sniper?pull*1.5:0)];
 const elL=o.nogun?[-6.8,20.4+bob,2.2]:reach(shL,haL,8.2,12.6,[-.75,-1,.1]),elR=o.nogun?[7.1,20.8+bob,2.6]:reach(shR,haR,7.4,7.8,[.8,-1,-.35]);
 for(const [sh,el,ha]of [[shL,elL,haL],[shR,elR,haR]]){
  beam(sh,el,o.sahur?1.1:2,B,o.sahur?1:1.7);beam(el,ha,o.sahur?1:1.65,B,o.sahur?.9:1.42);
  if(o.reaper){beam(sh,el,2.7,B,2.5,.4);beam(el,ha.map((v,i)=>v+(el[i]-v)*.3),2.5,B,2.6,.4)}
  beam(ha.map((v,i)=>v+(el[i]-v)*.13),ha,o.sahur?1.1:1.5,o.sahur?'#bf834b':'#363b2b',o.sahur?1.05:1.48,.35);
 }
 box(6.8,24.3+bob,1.8,1.65,1.8,.5,o.mark||'#dcb647',.2);
 box(8.05,24+bob,.1,.22,1.6,2,o.mark||'#dcb647',.15);
 if(o.cross){box(-8,24+bob,0,.25,2.6,2.4,'#eee7d6',.2);box(-8.2,24+bob,0,.2,1.8,.6,'#c43a3a',.05);box(-8.2,24+bob,0,.2,.6,1.8,'#c43a3a',.05)}
 if(!o.nogun){
  // every gun is assembled from the weapon table: stock, receiver, grip, magazine, fore-end, barrel, sights
  const z0=gunZ-kick,wb=(y,z,w,h,d,c,l=.3)=>box(gunX,gunY+y+bob,z0+z,w,h,d,c,l);
  const [sl,sh,sw,sc]=W.stock;wb(W.stockY||0,sl/2,sw,sh,sl,sc,.36);
  if(W.stockTop)wb(sh/2-.2,sl/2,sw*.7,.4,sl*.9,tint(sc,.8),.15);
  const [rl,rh,rw,rc]=W.recv;wb(0,sl+rl/2,rw,rh,rl,rc,.38);
  wb(rh/2+.25,sl+rl/2+.2,rw*.55,.5,rl*.9,'#67716b',.2);   // top rail / sight line
  wb(-rh/2-.9,W.grip,1.25,2,1.3,tint(rc,.9),.3);            // pistol grip
  if(W.mag)wb(-rh/2-W.mag[1]/2+.3,W.magZ,W.mag[2],W.mag[1],W.mag[0],W.magC||'#333c33',.32);
  const fz=W.fore-(W.pump?pull*2:0);wb(W.foreY||0,fz+W.foreL/2,W.foreW||1.6,W.foreH||1.9,W.foreL,W.foreC,.3);
  if(W.pump)for(let i=0;i<3;i++)wb((W.foreY||0)-(W.foreH||1.9)/2-.05,fz+.8+i*1.2,(W.foreW||1.6)*1.05,.25,.45,tint(W.foreC,.7),.05);
  // the barrel in three pieces, so the painter's depth order stays right when it points at or away from you
  const bz0=gunZ+sl+rl-.4-kick,bz1=gunZ+gl+2.4-kick;for(let i=0;i<3;i++)beam([gunX,gunY+bob,bz0+(bz1-bz0)*i/3],[gunX,gunY+bob,bz0+(bz1-bz0)*(i+1)/3],W.barrel,'#333c3b',W.barrel*.88,.28);
  wb(.7,gl+1.3,.75,1.5,.65,'#303835',.22);                   // front sight
  if(W.tube)beam([gunX,gunY-1.2+bob,gunZ+sl+rl-kick],[gunX,gunY-1.2+bob,gunZ+gl+.6-kick],W.barrel*1.05,'#434b43',W.barrel,.23);
  if(W.scope){
   beam([gunX,gunY+2.6+bob,gunZ+sl+.4-kick],[gunX,gunY+2.6+bob,gunZ+sl+rl+2.2-kick],.9,'#344038',1,.3);
   wb(1.8,sl+rl/2+.5,.6,1,1.6,'#282f2a',.2);
   beam([gunX+.3,gunY+bob,gunZ+sl+.8-kick],[gunX+1.6,gunY+bob+pull*2,gunZ+sl+.8-kick-pull*1.5],.25,'#9caa9c',.25,.1);
  }
 }
 // Opaque face pieces replace facial detail; drawing eyes and nose behind them lets those
 // small meshes break through when the head turns or an item sits close to the face.
 const faceCovered=!!(o.hood||o.sheet||o.pumpkin||o.glitchm||o.mask||o.visor||o.hockey||o.sack||o.facewrap||o.khelm||o.bomb||o.clownface);
 // Angular cheek and jaw planes, ears and a shaped helmet instead of a flat circle.
 if(!o.pumpkin&&!o.sheet&&!o.sahur){   // special heads replace the ordinary ears and face
 column(0,30.1+bob,.2,7.2,6.4,6.3,skin,1.13,.6);
 column(-4.05,30.5+bob,.15,1.15,2.25,2,skin,1,.3);column(4.05,30.5+bob,.15,1.15,2.25,2,skin,1,.3);
 if(!faceCovered){
 box(-1.45,30.75+bob,3.85,.7,.72,.18,'#34392c',.08,1.5);box(1.45,30.75+bob,3.85,.7,.72,.18,'#34392c',.08,1.5);
 box(0,29.9+bob,3.6,.75,1.4,.7,tint(skin,1.03),.08,1.2);
 box(0,28.55+bob,3.45,1.75,.28,.18,tint(skin,.64),.05,1.5);
 }
 }

 function dome(col,base=32,rx=5.3,rz=4.5,height=4.7){
  const v=[],N=compact?8:12,rings=[[base,rx*.94,rz],[base+height*.24,rx,rz],[base+height*.66,rx*.85,rz*.84],[base+height*.94,rx*.45,rz*.49],[base+height,.08,.08]];
  for(const[y,xr,zr]of rings)for(let i=0;i<N;i++){const t=Math.PI*2*i/N;v.push([Math.cos(t)*xr,y+bob,Math.sin(t)*zr])}
  const ff=[];for(let j=0;j<rings.length-1;j++)for(let i=0;i<N;i++)ff.push([j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i]);
  ff.push(Array.from({length:N},(_,i)=>(rings.length-1)*N+i));mesh(v,ff.map(f=>f.slice().reverse()),col,.6);
 }
 function ball(x,y,z,r,c){column(x,y,z,r*1.8,r*1.65,r*1.8,c,.75,.35)}
 if(o.sahur){
  const eye=(x,y,rx,ry,z,col,bias=1.2)=>{const v=[];for(let i=0;i<12;i++){const a=i*Math.PI/6;v.push([x+Math.cos(a)*rx,y+Math.sin(a)*ry+bob,z])}mesh(v,[v.map((_,i)=>i)],col,.08,bias)};
  for(const x of[-1.9,1.9]){
   eye(x,31.1,1.2,1.48,4.32,'#efe7ce');
   eye(x+.18,31.05,.48,.83,4.42,'#281b13',1.4);
   eye(x-.04,31.48,.16,.23,4.52,'#fff9e8',1.6);
   beam([x-1.1,33.02+bob,3.94],[x+.9,33.25+bob,3.94],.17,'#604021',.13,.06);
  }
  column(0,29.6+bob,4.05,1.1,2.3,1.35,'#ba8047',.8,.13);
  box(0,27.9+bob,3.94,3.5,.8,.22,'#4c2c19',.08,1);
  box(0,28.16+bob,4.08,2.6,.22,.12,'#ead5af',.02,1);
 }else if(o.pumpkin){
  // a ribbed pumpkin replaces the head; the carved face glows (the Pumpkin King's flames flicker over 4 cached frames)
  const pc=o.pumpkin,glowC=o.pking?'#ffb040':'#ffd35a';
  // The gourd replaces the whole head; cover the normal cheek and crown silhouette at every angle.
  const cy=30.3,RX=5.2,RY=4.1,RZ=4.8,SEG=compact?12:24,RINGS=compact?5:8,v=[],ff=[];
  for(let r=0;r<=RINGS;r++){const a=-Math.PI/2+Math.PI*r/RINGS,y=Math.sin(a)*RY,k=Math.cos(a)*(r===0||r===RINGS?.25:1);
   for(let q=0;q<SEG;q++){const t=Math.PI*2*q/SEG,rib=1-.085*(1-Math.cos(8*t))/2;v.push([Math.cos(t)*RX*k*rib,cy+y+bob-(r===RINGS?.5:0),Math.sin(t)*RZ*k*rib])}}
  for(let r=0;r<RINGS;r++)for(let q=0;q<SEG;q++){const a0=r*SEG+q,a1=r*SEG+(q+1)%SEG;ff.push([a0,a1,a1+SEG,a0+SEG])}
  ff.push(Array.from({length:SEG},(_,q)=>RINGS*SEG+SEG-1-q),Array.from({length:SEG},(_,q)=>q));
  mesh(v,ff.map(f=>f.slice().reverse()),pc,.55);
  beam([0,cy+RY-.7+bob,0],[.5,cy+RY+1.3+bob,.35],.55,'#4a6a22',.4,.35);
  // the carved face sits on the front of the gourd and turns with it
  const fz=RZ*.985,face=(pts)=>{const q=pts.map(p=>[p[0]*.9,cy+(p[1]-31)*.9+bob,fz-Math.pow(p[0]/RX,2)*1.3]).reverse();mesh(q,[q.map((_,i)=>i)],glowC,.06,1.2)};
  face([[-2.9,31.5],[-1.4,33.3],[-.5,31.5]]);face([[.5,31.5],[1.4,33.3],[2.9,31.5]]);
  face([[-3.1,29.9],[-2,28.7],[-1,29.5],[0,28.5],[1,29.5],[2,28.7],[3.1,29.9],[2.2,28],[-2.2,28]]);
  if(o.pking){const f=[0,1,2,3].map(k=>1.6+1.3*Math.abs(Math.sin((time+k*.7)*1.9)));
   for(const [i,x,z]of[[0,-1.8,.6],[1,0,-.2],[2,1.8,.5]])beam([x,cy+RY-.3+bob,z],[x*.8,cy+RY-.3+bob+f[i],z],.8,i===1?'#ffd24a':'#ff7a1a',.05,.1)}
 }else if(o.witch){
  // wide brim, a cone in three stacked pieces that bends back, a purple band with a gold buckle
  column(0,32.5+bob,0,15.5,.8,13.5,o.witch,1,.4);column(0,34.45+bob,0,8.6,3.7,7.8,o.witch,.72,.45);
  column(0,37.4+bob,-.6,6,2.6,5.4,o.witch,.62,.4);beam([0,38.6+bob,-1],[-.6,41.2+bob,-3.4],1.7,o.witch,.25,.35);
  column(0,33.2+bob,0,8.8,1.1,8,'#6a2a8a',1,.2);box(0,33.2+bob,4.05,1.8,1.3,.3,'#e2c25a',.15,1);box(0,33.2+bob,4.2,.8,.6,.2,'#6a2a8a',.02,1.2);
 }else if(o.hood){
  // a deep hood with the face lost in shadow and two glowing eyes
  dome(o.hood,29.2,5.4,5.1,7.2);column(0,29.4+bob,-.6,11,4.6,10,o.hood,.95,.45);box(0,28.4+bob,-4.4,8.6,6.4,1,o.hood,.35);
  box(0,30.6+bob,4.35,5.2,5.4,.35,'#050407',.08,1.3);for(const x of[-1.3,1.3])box(x,31+bob,4.6,.9,.6,.2,o.reaper||'#8fe0ff',.02,1.6);
 }else if(o.sheet){
  // v0.9.3 Sheet Ghost: the sheet comes up over the head, with two cut-out eyes
  dome(o.sheet,26.3,5.9,5.2,9.4);for(const x of[-1.5,1.5])box(x,31.4+bob,4.72,1.25,1.9,.3,'#121014',.02,1.6);
 }else if(o.halloweenHat){
  const h=o.halloweenHat,ink='#27232c',ivory='#e9dfc5';
  if(h==='gravecap'){
   dome('#35323b',32.5,4.35,3.95,2.5);column(0,32.65+bob,0,8.7,.6,7.9,'#24222a',1,.22);
   column(0,33.65+bob,4.02,1.8,1.6,.26,'#bcbdb4',.82,.12);box(0,33.75+bob,4.2,1,.18,.1,ink,.01,1);
  }else{
   dome('#433b2b',32.7,4.2,3.6,1.65);
   if(h==='stemband'){
    column(0,32.8+bob,0,8.7,.65,7.9,'#355332',1,.2);
    beam([0,34+bob,0],[.45,35.3+bob,-.15],.48,'#db852f',.3,.18);
    box(-.85,34.65+bob,.25,1.3,.35,1.15,'#73974b',.12);
   }else if(h==='batcirclet'){
    column(0,32.8+bob,0,8.7,.7,7.9,'#34243f',1,.2);
    for(const x of[-3,3])beam([x,33+bob,.2],[x*.95,35.4+bob,.1],.85,'#3c2b4d',.08,.18);
    box(0,32.95+bob,4.05,1.2,.6,.2,'#b48ace',.02,1);
   }else if(h==='bonewrap'){
    column(0,32.6+bob,0,8.6,1,7.9,'#792d3a',1,.2);
    for(const x of[-1.55,1.55]){box(x,32.6+bob,4.06,1.7,.38,.2,ivory,.05,1);for(const d of[-.75,.75])column(x+d,32.6+bob,4.12,.46,.7,.3,ivory,1,.05)}
   }else if(h==='webpin'){
    box(1.5,32.6+bob,3.95,3,1.85,.28,ink,.13,1);
    for(const dx of[-.8,0,.8])box(1.5+dx,32.65+bob,4.28,.18,1.45,.12,ivory,.01,1.5);
    for(const dy of[-.4,.25])box(1.5,32.65+dy+bob,4.3,2,.16,.12,ivory,.01,1.5);
    column(2.6,32+bob,4.32,.75,.75,.25,'#df853a',1,.03);
   }else if(h==='skullseal'){
    column(0,32.95+bob,4,3.4,1.7,.25,ivory,.7,.12);
    box(0,33.4+bob,4.18,2.1,.8,.12,'#433b2b',.03,1);
    column(0,32.5+bob,4.25,1.15,1,.2,'#765389',.8,.04);for(const x of[-.22,.22])box(x,32.65+bob,4.39,.18,.18,.08,ivory,.01,1);
   }
  }
 }else if(o.hardhat){
  // v0.9.3 Foreman: a hard hat with a full brim and a ridge
  dome(o.hardhat,32,5.1,4.6,4.4);column(0,32.1+bob,.5,11.2,.45,10.4,tint(o.hardhat,.88),1,.4);beam([0,36.2+bob,-3.3],[0,36.2+bob,3.3],.55,tint(o.hardhat,1.12),.55,.3);
 }else if(o.straw){
  // v0.9.3 Yard hands and the scarecrow: a wide straw hat with a band
  column(0,32.4+bob,0,15.2,.8,13.8,o.straw,1,.4);column(0,34.2+bob,0,8.4,3.8,7.4,tint(o.straw,.95),.82,.45);column(0,33.1+bob,0,8.6,1,7.6,'#7a3a1a',1,.2);
 }else if(o.ghood){
  // v0.9.3 Sniper reward: a ghillie hood, strands hanging at the sides and back (the face stays clear)
  dome(o.ghood,31.4,5.7,5.1,5.4);
  for(let i=0;i<14;i++){const a=i*Math.PI*2/14;if(Math.sin(a)>.5)continue;beam([Math.cos(a)*5.2,32+bob,Math.sin(a)*4.7],[Math.cos(a)*6.3,27.4+bob-(i%3),Math.sin(a)*5.7],.42,i%2?o.ghood:tint(o.ghood,.72),.15,.15)}
 }else if(o.bomb){
  // v0.9.3 Grenadier reward: a heavy blast helmet with a tinted face shield
  dome(o.bomb,31.4,5.9,5.3,5.6);box(0,30.9+bob,4.35,7,3.6,.5,'#23303a',.3,1.2);box(-1.6,31.9+bob,4.62,1.8,.35,.08,'#bfe6ff',.02,1.4);
 }else if(o.slick){
  // v0.9.3 Dracula: slicked-back hair with a widow's peak
  dome(o.slick,31.2,4.35,3.85,2.8);mesh([[-1.4,32.6+bob,3.72],[0,31.5+bob,3.76],[1.4,32.6+bob,3.72]],[[0,1,2]],o.slick,.06,1.4);
  for(const x of[-3.55,3.55])box(x,30.4+bob,.9,.5,2,1.2,o.slick,.1);
 }else if(o.mop){
  // v0.9.3 Frankenstein's Monster (after the novel): long, lank black hair
  for(const [x,y,z,r]of[[-3.7,31.6,-.9,2.1],[3.7,31.6,-.9,2.1],[0,33.7,-.4,2.7],[-2,33.9,1.6,1.7],[2,33.9,1.5,1.7],[0,31.3,-3.3,2.5],[-3,29.6,-2.6,1.9],[3,29.6,-2.6,1.9],[0,28.6,-3.4,2]])ball(x,y+bob,z,r,o.mop);
  for(const x of[-2,-.6,.8,2])box(x,32.3+bob,3.4,.5,1.7,.3,o.mop,.08,1);
 }else if(o.helmet){
  dome(o.helmet);column(0,32.1+bob,.05,10.6,.75,9.1,tint(o.helmet,.73),1,.28);
  box(-4.15,30.5+bob,.8,.55,3.5,1.2,tint(o.helmet,.53),.22);box(4.15,30.5+bob,.8,.55,3.5,1.2,tint(o.helmet,.53),.22);
  box(0,34+bob,4.13,1.75,1.6,.5,tint(o.helmet,.62),.22);
  if(o.hneon){box(0,33.3+bob,4.5,7,.5,.3,o.hneon,.04,1);box(0,35+bob,3.7,.55,2.6,.25,o.hneon,.04,1)}
 }else if(o.cap){
  dome(o.cap,32,4.8,4.2,3.3);box(0,32+bob,4.7,8,.5,4.4,tint(o.cap,.85),.4);
  if(o.capPix){box(0,34+bob,4.1,1.8,1.8,.3,o.capPix,.03,1);box(1.25,33.2+bob,4.3,.7,.7,.2,o.capPix,.03,1)}
 }else if(o.boonie){
  column(0,32.1+bob,0,14,.9,12,o.boonie,1,.45);dome(tint(o.boonie,.9),32.2,4.5,3.9,3.1);column(0,33+bob,0,9.3,.85,8,tint(o.boonie,.64),1,.2);
 }else if(o.beanie){
  dome(o.beanie,31.9,5.1,4.3,4.7);column(0,32.3+bob,0,10.3,1.5,8.8,tint(o.beanie,.75),1,.32);ball(0,37.1+bob,0,1.3,o.beanie);
 }else if(o.beret){
  column(0,32.2+bob,0,9.6,.8,8,'#28291f',1,.25);column(1,34+bob,0,11,3,8.8,o.beret,.66,.5);box(-2,33.5+bob,4.1,1.4,1.5,.3,'#d4be73',.2,1);
 }else if(o.wrap){
  dome(o.wrap,31.8,4.9,4.1,3.4);column(0,32+bob,0,10,1.2,8.5,tint(o.wrap,.74),1,.2);beam([-4.4,32+bob,-1],[-5.6,28.4+bob,-4],.5,o.wrap,.3);
 }else if(o.tophat){
  // Overlap brim, band and crown so their outlines cannot reveal a seam when rotated.
  column(0,32.4+bob,0,12,.9,10,o.tophat,1,.4);column(0,33.8+bob,0,8.6,2.5,7.6,'#be303b',1,.24);column(0,37.8+bob,0,8.6,6.1,7.6,o.tophat,1,.5);
 }else if(o.crown){
  column(0,32.7+bob,0,10,1.7,8.6,o.crown,1,.4);
  for(let i=0;i<8;i++){const a=i*Math.PI/4;beam([Math.cos(a)*4.6,33+bob,Math.sin(a)*4],[Math.cos(a)*5,37+bob,Math.sin(a)*4.3],.9,o.crown,.1,.3)}
  box(0,33+bob,4.45,1.5,1.4,.4,'#c43a4a',.15,1);
 }else if(o.pcap){
  column(0,33.8+bob,0,10.7,3.7,8.4,o.pcap,1.12,.5);box(0,32+bob,4.4,8,.8,3.8,tint(o.pcap,.55),.35);box(0,34+bob,4.35,1.6,1.8,.4,'#e2c25a',.2,1);
 }else if(o.khelm){
  dome(o.khelm,31.5,5.5,4.6,5);
  column(0,30+bob,.7,9.5,4.8,8.9,o.khelm,1.04,.4);
  box(0,31+bob,5.3,7.6,.9,.3,'#111510',.08,1);
  for(const x of[-1.5,0,1.5])box(x,29+bob,5.3,.45,1.5,.3,'#252820',.06,1);
  beam([0,36.4+bob,-3],[0,36.4+bob,3],.65,tint(o.khelm,.82),.65,.3);
 }else if(o.hair){
  // One rounded afro cap, clear of the eyes, instead of separate blocky clumps.
  const seg=compact?12:20,rings=compact?6:10,v=[],ff=[];
  for(let r=0;r<=rings;r++){const a=-Math.PI/2+Math.PI*r/rings,y=36+Math.sin(a)*4.7,k=Math.cos(a);
   for(let q=0;q<seg;q++){const t=2*Math.PI*q/seg;v.push([Math.cos(t)*5.5*k,y+bob,Math.sin(t)*4.9*k-.3])}}
  for(let r=0;r<rings;r++)for(let q=0;q<seg;q++){const a=r*seg+q,b=r*seg+(q+1)%seg;ff.push([a,b,b+seg,a+seg])}
  mesh(v,ff.map(f=>f.slice().reverse()),o.hair,.55);
  if(o.hairGold)for(const x of[-3,1,4])box(x,35.5+bob,1.7,.5,.7,.5,'#fff1b0',.03,1);
 }else{
  // Uncovered head remains visible beneath masks and floating accessories.
  if(!(o.bones||o.wraps||o.phantom))dome('#433b2b',32.7,4.2,3.6,1.65);
  if(o.mask){column(0,30.4+bob,1,8.6,5.4,7.5,'#15151a',1,.4);for(const x of[-1.8,1.8])box(x,31+bob,4.9,1.5,.85,.3,o.mask,.03,1)}
  if(o.visor){box(0,31.2+bob,4.3,8.8,2.5,.9,'#101014',.32,1);box(0,31.2+bob,4.82,7.8,.65,.15,o.visor,.03,1)}
  if(o.headband){column(0,32.2+bob,0,9,.65,7.8,o.headband,1,.15);beam([-4.2,32.2+bob,-1],[-5.7,28.7+bob,-3.6],.35,o.headband,.2,.15)}
  if(o.glitchm){
   const cs=['#ff3a6a','#3affd8','#6a8aff','#ffe03a','#f3f0ff'],f=Math.floor(time*10);
   box(0,31.5+bob,.2,9.4,9.4,9.4,'#161923',.65);
   for(let y=0;y<3;y++)for(let x=0;x<3;x++){
    const a=(x-1)*3,b=28.5+y*3+bob,c=cs[(f+x*3+y*7)%5];
    box(a,b,4.98,2.72,2.72,.18,c,.06,.1);box(a,b,-4.58,2.72,2.72,.18,cs[(f+x+y*2+1)%5],.06,.1);
    box(-4.78,b,a+.2,.18,2.72,2.72,cs[(f+x*2+y+2)%5],.06,.1);box(4.78,b,a+.2,.18,2.72,2.72,cs[(f+x+y+3)%5],.06,.1);
    box(a,36.28+bob,(y-1)*3+.2,2.72,.18,2.72,cs[(f+x+y*3)%5],.06,.1);
   }
  }
 }
 // Floating Halo is independent of the head branch; the sheet gets a verified clearance.
 if(o.halo){for(let i=0;i<16;i++){const a=i*Math.PI/8,b=(i+1)*Math.PI/8,y=(o.sheet?43:39)+bob+Math.sin(time*2.4)*.35;beam([Math.cos(a)*6,y,Math.sin(a)*4.8],[Math.cos(b)*6,y,Math.sin(b)*4.8],.22,o.halo,.22,.04)}}
 // v0.9.3 add-ons over whatever is on the head
 if(o.pbraid&&o.pcap)box(0,32.75+bob,4.52,7.6,.35,.25,o.pbraid,.05,1.1);
 if(o.lamp&&o.cap){box(0,33.6+bob,4.5,1.7,1.3,.7,'#2a2a28',.2,1);box(0,33.6+bob,4.9,1.2,.9,.15,o.lamp,.03,1.3)}
 if(o.headset){for(const x of[-4.9,4.9])box(x,30.7+bob,.3,1.1,2.5,2.5,'#1e2022',.3);beam([-4.9,32.4+bob,.3],[0,36.2+bob,.3],.35,'#1e2022',.35,.2);beam([0,36.2+bob,.3],[4.9,32.4+bob,.3],.35,'#1e2022',.35,.2);
  beam([4.9,29.8+bob,1.2],[2,28.6+bob,3.9],.18,'#1e2022',.18,.1);ball(1.8,28.6+bob,4,.4,'#2a2c2e')}
 if(!o.pumpkin&&!o.sheet&&!o.sahur){
  if(o.facewrap){box(0,29.2+bob,.35,7.9,2.5,7.4,o.facewrap,.3,.8);box(0,29.3+bob,-3.55,1.2,1,.6,o.facewrap,.2,.9);beam([0,29.3+bob,-3.6],[-.8,26.8+bob,-4.2],.3,o.facewrap,.2,.15);beam([0,29.3+bob,-3.6],[.9,27+bob,-4.3],.3,o.facewrap,.2,.15)}
  if(o.hockey){box(0,30.5+bob,3.85,6.2,5.8,.55,o.hockey,.25,1.2);column(0,31.2+bob,.2,7.7,.35,6.8,'#26221c',1,.1);
   for(const x of[-1.45,1.45])box(x,31.2+bob,4.14,1.3,.9,.08,'#15110e',.02,1.8);
   for(const [x,y]of[[-1.2,29.2],[0,29.2],[1.2,29.2],[-.6,28.3],[.6,28.3],[-1.5,32.4],[-.5,32.4],[.5,32.4],[1.5,32.4]])box(x,y+bob,4.14,.35,.35,.08,'#15110e',.02,1.8)}
  if(o.clownface){ball(0,29.9+bob,3.95,.65,'#e02a2a');
   for(const x of[-1.45,1.45])mesh([[x+.8,31.05+bob,3.9],[x,32.1+bob,3.9],[x-.8,31.05+bob,3.9],[x,30+bob,3.9]],[[0,1,2,3]],'#2a1a3a',.04,1.5);
   box(0,28.45+bob,3.62,3.6,.45,.15,'#c01a2a',.02,1.6);for(const x of[-1.9,1.9])box(x,28.9+bob,3.6,.45,.9,.15,'#c01a2a',.02,1.6)}
  if(o.stitches){box(0,32.3+bob,3.55,4.6,.2,.12,o.stitches,.02,1.6);for(const x of[-1.8,-.6,.6,1.8])box(x,32.3+bob,3.57,.18,.8,.1,o.stitches,.02,1.7);
   box(2.4,29.6+bob,3.42,.2,1.8,.12,o.stitches,.02,1.6);column(0,27+bob,0,4.8,.35,3.9,o.stitches,1,.05);box(0,28.55+bob,3.52,1.9,.35,.15,'#1c1416',.02,1.6)}
  if(o.sack){for(const x of[-1.45,1.45])box(x,30.9+bob,3.95,1.2,1.2,.2,'#1a1410',.03,1.6);box(0,28.7+bob,3.62,3.8,.25,.15,'#2a1a10',.02,1.6);
   for(let k=-2;k<=2;k++)box(k*.8,28.7+bob,3.64,.18,.8,.12,'#2a1a10',.02,1.7);column(0,27.3+bob,0,4.9,.5,4,'#8a6a3a',1,.15)}
 }
 box(0,23+bob,-3.3,6.5,5.7,.7,tint(V,.92),.3);
 box(0,26.1+bob,-3.8,3.1,.65,.7,tint(V,.65),.2);

 // Existing skin signatures follow the same rotating surfaces as the clothing.
 const decal=(pts,col,bias=.7)=>mesh(pts.map(p=>[p[0],p[1]+bob,p[2]]),[pts.map((_,i)=>i)],col,.06,bias);
 const chest=(x,y,w,h,col,z=4.06)=>box(x,y+bob,z,w,h,.15,col,.035,.65);
 if(o.pack){column(0,21+bob,-4.8,9,8.7,4.2,o.pack,.96,.5);box(0,23.9+bob,-7,7.6,.8,.5,tint(o.pack,.65),.2);box(0,19+bob,-7.1,5,3.6,.7,tint(o.pack,1.06),.25)}
 if(o.bandolier){
  // the grenadier's kit: a chest belt of five green grenades on a strap, and a smaller row on the waist belt
  beam([-4.3,26+bob,3.9],[4.3,17+bob,4.75],.6,'#3a3020',.6,.2);
  for(let i=0;i<5;i++){const t=(i+.5)/5,x=-4.3+8.6*t,y=26-9*t+bob,z=4.75+.85*t;
   column(x,y,z,1.75,2.05,1.7,'#8aa83f',.8,.4);box(x,y+1.15,z,.55,.45,.55,'#8f9486',.1);box(x+.45,y+.9,z+.35,.18,.7,.18,'#c9c2a2',.05,.6)}
  for(const x of[-3.2,-1.6,0])column(x,15.9+bob,3.95,1.3,1.55,1.3,'#8aa83f',.8,.3);
 }
 if(o.stripe){
  for(const z of[4.04,-3.6])for(const x of[-3.6,0,3.4]){
   const p=[[x-1,25,z],[x+.4,25,z],[x+2,21,z],[x+.4,21,z]];decal(z>0?p.slice().reverse():p,o.stripe);
  }
  for(const side of[-1,1]){box(side*6.9,23+bob,1.8,1.6,.75,.4,o.stripe,.03,.5);box(side*3.1,10.7+bob,2,2.8,.65,.3,o.stripe,.03,.5)}
 }
 if(o.plate){
  for(const x of[-6.4,6.4])column(x,25+bob,.1,5.3,3.1,5.3,o.plate,.9,.5);
  chest(0,23.7,6.8,3.4,o.plate);chest(0,23.7,.5,3.6,tint(o.plate,.55),4.22);
  for(const y of[17.7,19,20.3])chest(0,y,7.7,.5,o.plate,4.72);
 }
 if(o.neon){
  for(const x of[-3.8,3.8])chest(x,23.5,.4,4.4,o.neon,4.35);
  for(const x of[-4.55,4.55]){beam([x,25.5+bob,3.65],[x*.9,17.4+bob,4.5],.18,o.neon,.18,.015);beam([x,25.5+bob,-3.4],[x*.9,18+bob,-3.4],.17,o.neon,.17,.015)}
  chest(0,16.5,8.7,.35,o.neon,3.9);
  for(const side of[-1,1])box(side*3.1,3.3,3.7,3,.3,.2,o.neon,.01);
 }
 if(o.badge){
  const x=-2.5,z=4.35;decal([[x,25.5,z],[x+1.25,24.8,z],[x+.8,22.9,z],[x,22.4,z],[x-.8,22.9,z],[x-1.25,24.8,z]].reverse(),o.badge,.9);
  chest(x,24.3,.35,1.1,tint(o.badge,.58),4.5);
 }
 if(o.ruff){
  for(let i=0;i<10;i++){const a=i*Math.PI/5,b=(i+1)*Math.PI/5;const p=[[Math.cos(a)*4.7,26,Math.sin(a)*3.8],[Math.cos((a+b)/2)*4.3,27.8,Math.sin((a+b)/2)*3.7],[Math.cos(b)*4.7,26,Math.sin(b)*3.8]];decal(p,o.ruff,.15);decal(p.slice().reverse(),o.ruff,.15)}
 }
 if(o.dots)for(const z of[4.33,-3.7])for(const [x,y]of[[-2.7,24.6],[2.8,21.8],[-.6,22.5],[.7,25.1]]){
 const p=Array.from({length:8},(_,i)=>[x+Math.cos(i*Math.PI/4)*.8,y+Math.sin(i*Math.PI/4)*.8,z]);decal(z>0?p:p.slice().reverse(),o.dots,.8);
 }
 if(o.spots){
  for(const z of[4.15,-3.7])for(const [x,y,h]of[[-2.7,23.7,2.4],[1.2,24.1,3.1],[3,21.5,1.8]]){box(x,y+bob,z,.8,h,.2,o.spots,.03,.7);box(x+.35,y+h/2+bob,z,1.5,.65,.2,o.spots,.03,.7)}
  box(-6.9,24+bob,1.8,1.25,1.5,.35,o.spots,.03,.5);
 }
 if(o.frost){
  for(const z of[4.2,-3.7])for(const [x,y]of[[-3,24],[3,23],[0,19.5]]){box(x,y+bob,z,1.7,.35,.2,o.frost,.015,.7);box(x,y+bob,z,.35,1.7,.2,o.frost,.015,.7)}
 }
 if(o.stars){
  for(let i=0;i<14;i++){
   const x=-4+((i*37)%79)/10,y=18+((i*23)%70)/10,z=i%2?4.22:-3.72,k=.32+Math.abs(Math.sin(time*2.2+i*1.9))*.65;
   box(x,y+bob,z,.3+k*.3,.3+k*.3,.15,i%3?'#f3eaff':'#b2b5ff',.02,.7);
  }
 }
 if(o.shine||o.chrome){
  chest(-2.8,23.4,.55,3.7,'#fff1c1',4.27);
  if(o.chrome)chest(2.8,23.4,.4,3.7,'#ffffff',4.27);
 }
 if(o.holo){
  for(let y=17;y<=26;y+=1.4)for(const z of[4.8,-3.9])box(0,y+bob,z,8.9,.14,.15,'#b5f5ff',.01,.8);
 }
 // Gold editions have distinct garment construction, not just a shared gold tint.
 if(goldClown){
  // Ivory pleated collar, plum panels, gold diamonds, and oversized cuff buttons.
  for(let i=0;i<12;i++){
   const a=i*Math.PI/6,b=(i+1)*Math.PI/6;
   const p=[[Math.cos(a)*5.4,26.2,Math.sin(a)*4.2],[Math.cos((a+b)/2)*5.6,28,Math.sin((a+b)/2)*4.5],[Math.cos(b)*5.4,26.2,Math.sin(b)*4.2]];
   decal(p,'#fff1c9',.3);decal(p.slice().reverse(),'#fff1c9',.3);
  }
  for(const z of[4.95,-3.95])for(const [x,y]of[[-2.7,24.3],[2.7,24.3],[0,21.6],[-2.7,18.8],[2.7,18.8]]){
   const p=[[x,y+1.3,z],[x+1.1,y,z],[x,y-1.3,z],[x-1.1,y,z]];decal(z>0?p.slice().reverse():p,'#f3d677',.85);
  }
  for(const side of[-1,1]){
   const L=leg(side),step=L.z;
   column(L.ankle[0]+(L.knee[0]-L.ankle[0])*.3,5.3+L.lift*.7,step+(L.knee[2]-step)*.3,4.25,1.6,4.15,'#fff1c9',1,.3);
   for(const z of[-2.4,2.6])for(const y of[10.3,12.8]){
    const f=(y-8)/6,x=L.knee[0]+(L.hip[0]-L.knee[0])*f,zz=z+L.knee[2]*(1-f),p=[[x,y+1.1,zz],[x+.95,y,zz],[x,y-1.1,zz],[x-.95,y,zz]];decal(z>0?p.slice().reverse():p,'#67293b',.8);
   }
   box(side*6.85,23.4+bob,2,1.7,2.8,.45,'#67293b',.25);
   ball(side*6.85,23.5+bob,2.5,.65,'#fff1c9');
  }
 }
 if(goldPolice){
  // Navy sleeves and trousers frame a gold dress vest, ivory shirt, and shield.
  chest(0,24.5,2.8,3.8,'#f1e8ce',4.45);
  decal([[-.5,26.2,4.65],[.5,26.2,4.65],[.75,23.2,4.65],[0,22.5,4.65],[-.75,23.2,4.65]].reverse(),'#202b40',.9);
  for(const x of[-6.2,6.2]){box(x,26.5+bob,0,3.6,.8,3.8,'#f0cf5c',.35);box(x,27+bob,.2,1.9,.2,2.6,'#fff1c1',.1)}
  const shield=[[-4.1,25.4,4.7],[-1,25.4,4.7],[-1.25,23.3,4.7],[-2.55,22.6,4.7],[-3.85,23.3,4.7]];
  decal(shield.slice().reverse(),'#202b40',1);chest(-2.55,24.1,1.25,1.5,'#fff1c1',4.87);
  chest(2.5,24.7,1.8,.55,'#fff1c1',4.8);
  for(const side of[-1,1]){const L=leg(side),step=L.z;beam([L.knee[0]+side*1.9,L.knee[1],L.knee[2]],[L.hip[0]+side*1.9,L.hip[1],L.hip[2]],.2,'#e6c65c',.2,.12);box(L.x,3.5+L.lift,2.6+step,3.3,1.2,1.7,'#202b40',.25)}
  box(0,15.8+bob,3.45,9,1.4,.55,'#202b40',.3);box(0,15.8+bob,3.8,1.6,1.1,.25,'#fff1c1',.2);
  for(const x of[-2.8,2.8])box(x,14.7+bob,3.2,1.8,2.2,1.3,'#202b40',.3);
  box(0,23+bob,-3.9,6.2,3.8,.35,'#26334b',.3);box(0,23+bob,-4.15,3.8,.6,.2,'#f0cf5c',.1);
 }
 if(goldKnight){
  // Articulated gold plate over dark mail, with an ivory heraldic center.
  for(const side of[-1,1]){
   const L=leg(side),step=L.z;
   column(side*6.5,26+bob,0,5.7,2.8,5.2,'#f0cf5c',.72,.55);
   box(side*6.5,25.2+bob,2.7,4,.8,.35,'#8a6a1c',.2);
   beam(L.ankle,L.knee,2.2,'#d4ae45',2,.45);
   column(L.knee[0],L.knee[1]+.7,L.knee[2]+1.65,4.2,2.6,2.2,'#f0cf5c',.7,.4);
   beam([L.ankle[0],L.ankle[1]+.6,L.ankle[2]+2.25],[L.knee[0],L.knee[1]-.8,L.knee[2]+2.1],.18,'#fff1c1',.18,.06);
   for(const z of[-3.25,3.3])column(side*2.8,13.5+bob,z,4.35,3.4,1,'#e2bd52',.85,.4);
  }
  chest(0,23.6,6.8,4.4,'#d4ae45',4.65);
  decal([[-1.3,25.6,4.87],[1.3,25.6,4.87],[1,23.3,4.87],[0,22.4,4.87],[-1,23.3,4.87]].reverse(),'#fff1c9',.9);
  decal([[0,25.1,5.02],[.65,24.3,5.02],[0,23.5,5.02],[-.65,24.3,5.02]].reverse(),'#67293b',1);
  for(const [el,ha]of [[elL,haL],[elR,haR]]){
   const a=el.map((v,i)=>v+(ha[i]-v)*.45),b=el.map((v,i)=>v+(ha[i]-v)*.83);
   beam(a,b,1.87,'#d4ae45',1.7,.4);
  }
  column(0,22.5+bob,-3.85,8.2,6.6,1.1,'#d4ae45',.88,.4);
  box(0,22.6+bob,-4.5,.55,5.8,.25,'#fff1c1',.08);
 }
 // Halloween outfits
 const strip=(a,b,w,z,col,bias=.75)=>{const dx=b[0]-a[0],dy=b[1]-a[1],l=Math.hypot(dx,dy)||1,nx=-dy/l*w/2,ny=dx/l*w/2;
  const p=[[a[0]+nx,a[1]+ny,z],[b[0]+nx,b[1]+ny,z],[b[0]-nx,b[1]-ny,z],[a[0]-nx,a[1]-ny,z]];decal(z>0?p.slice().reverse():p,col,bias)};   // wound to face outward (back faces are skipped)
 // chest details sit just in front of the vest and its pouches (z 4.85) and behind the back plate (z -4.2)
 if(o.ribs)for(const z of[4.85,-4.2])for(const x of[-3.1,0,3.1])strip([x,26],[x*.85,16.6],.9,z,o.ribs);
 if(o.web)for(const z of[4.85,-4.2]){const c=[-1,22.5];for(let k=0;k<6;k++){const a=k*Math.PI/3;strip(c,[c[0]+Math.cos(a)*5,c[1]+Math.sin(a)*4.4],.34,z,o.web)}
  for(const r of[1.8,3.6])for(let k=0;k<6;k++){const a0=k*Math.PI/3,a1=a0+Math.PI/3;strip([c[0]+Math.cos(a0)*r,c[1]+Math.sin(a0)*r*.88],[c[0]+Math.cos(a1)*r,c[1]+Math.sin(a1)*r*.88],.28,z,o.web)}}
 if(o.bones){for(const z of[4.85,-4.2]){strip([0,26.2],[0,16.4],.8,z,o.bones);for(const [y,w]of[[24.6,4.2],[23,4.5],[21.4,4.3],[19.9,3.6]])for(const s of[-1,1])strip([s*.4,y],[s*w,y-.9],.6,z,o.bones)}
  strip([-2.4,16.2],[2.4,16.2],1,4.85,o.bones);for(const side of[-1,1]){const L=leg(side);for(const [a,b]of [[L.ankle,L.knee],[L.knee,L.hip]])beam([a[0],a[1]+.5,a[2]+1.9],[b[0],b[1]-.5,b[2]+1.9],.33,o.bones,.33,.02)}
  for(const x of[-1.45,1.45])box(x,30.8+bob,3.95,1.6,1.4,.25,'#15110e',.02,1.6);box(0,29.6+bob,3.95,.6,.8,.25,'#15110e',.02,1.6);for(let k=-2;k<=2;k++)box(k*.7,28.4+bob,3.95,.35,.9,.25,'#15110e',.02,1.6)}
 if(o.wraps){for(let y=15.2;y<=26;y+=1.9)column(0,y+bob,.1,10.9,.55,6.9,o.wraps,1,.18);
  for(const side of[-1,1]){const L=leg(side);for(const [a,b]of [[L.ankle,L.knee],[L.knee,L.hip]])for(const f of [.3,.7])column(a[0]+(b[0]-a[0])*f,a[1]+(b[1]-a[1])*f,a[2]+(b[2]-a[2])*f+.6,4.6,.5,4.4,o.wraps,1,.14)}
  for(const y of[29,30.3,32.6])column(0,y+bob,.2,7.8,.55,6.9,o.wraps,1,.16);for(const x of[-1.45,1.45])box(x,31.4+bob,3.95,.9,.45,.2,'#ffc94a',.02,1.6)}
 if(o.reaper){column(0,7.6,0,13.6,13.6,8.6,B,.62,.5);column(0,1.3,0,14,.8,9,tint(B,.7),1,.3)}
 if(o.phantom){for(const [i,x]of[[0,-3],[1,0],[2,3]]){const sw=Math.sin(i*2.1)*1.6;beam([x,14.4+bob,0],[x+sw,8,1],1.6,o.phantom,.9,.2);beam([x+sw,8,1],[x-sw*.6,2.5,-.5],.9,o.phantom,.15,.15)}
  for(const x of[-1.45,1.45])box(x,30.8+bob,3.9,1,1,.2,'#0e3a26',.02,1.6)}
 // v0.9.3 outfits
 if(o.apron){box(0,15.2+bob,4.95,7.8,14,.3,o.apron,.3,.4);box(0,12.8+bob,5.18,3.6,2,.14,tint(o.apron,1.25),.12,.5);
  for(const s of[-1,1]){beam([s*2.8,22+bob,4.9],[s*2.2,26.8+bob,3.4],.3,o.apron,.3,.15);beam([s*3.9,15.5+bob,4.8],[s*4.9,15.5+bob,1],.25,o.apron,.25,.15)}}
 if(o.coat){column(0,9.2,0,11.8,10,7.6,o.coat,.8,.5);for(const s of[-1,1])box(s*3.6,22+bob,3.95,1.1,8,.3,tint(o.coat,1.15),.2,.4)}
 if(o.cape){box(0,15.6+bob,-4.35,11.6,22,.4,o.cape,.35);box(0,26.2+bob,-2.2,12.4,1,5,o.cape,.35);
  if(o.collar){box(0,30.8+bob,-3.5,9.4,5.4,.45,o.cape,.35);box(0,30.6+bob,-3.2,8.6,4.8,.2,o.lining||tint(o.cape,1.4),.1)}}
 if(o.reflect)for(const y of[18.2,21.8])column(0,y+bob,.1,10.9,.7,6.9,o.reflect,1,.15);
 if(o.waders){column(0,17.2+bob,0,9.7,4.8,5.9,o.waders,1.02,.45);for(const s of[-1,1])for(const z of[3.1,-2.9])beam([s*2.6,19.4+bob,z],[s*3.4,26+bob,z*.93],.35,o.waders,.35,.15)}
 if(o.charges){for(const x of[-2.9,0,2.9])box(x,14.9+bob,3.55,2.2,2,1.1,o.charges,.3,.6);beam([-2.9,15.9+bob,4.15],[2.9,15.9+bob,4.15],.12,'#1a1a1a',.12,.05);box(0,15.2+bob,4.15,.9,.5,.1,'#7affb0',.02,1)}
 if(o.medals){['#b83a3a','#3a6ab8','#e2c25a'].forEach((c,i)=>chest(-3.6+i*.95,25.1,.8,1.1,c,4.95));for(const x of[-3.6,-1.7])ball(x,23.6+bob,4.95,.45,'#f0cf5c')}
 if(o.medal){for(const s of[-1,1])beam([s*1.8,26.5+bob,3.2],[0,24.6+bob,4.6],.12,o.medal,.12,.05);ball(0,24+bob,4.7,.8,o.medal);box(0,24+bob,5.4,.5,.5,.2,'#c01a2a',.02,1.2)}
 if(o.ghillie){for(let i=0;i<12;i++){const x=-5.5+i;beam([x,26+bob,-3.2-(i%2)*.3],[x+Math.sin(i*1.7)*1.2,15.5+(i%3),-4.6],.35,i%2?o.ghillie:tint(o.ghillie,.7),.2,.15)}
  for(const s of[-1,1])for(let k=0;k<3;k++)beam([s*(5.2+k*.5),26.3+bob,1-k],[s*(6.6+k*.4),21+bob,1.5-k],.3,k%2?o.ghillie:tint(o.ghillie,.75),.2,.15)}
 if(o.sheet){column(0,14.2+bob*.5,0,12.6,24.6,9.2,o.sheet,.85,.45)}
 if(o.patches){chest(-2.3,23.8,2.3,2.3,'#6a4a8a',4.98);chest(2.5,19.4,2,2.1,'#8a3a2a',4.98);chest(-2.3,23.8,2.6,.18,'#2a2014',5.05);chest(2.5,19.4,.18,2.4,'#2a2014',5.05);box(0,21+bob,-3.95,2.4,2.4,.15,'#5a6a3a',.035,.65)}
 if(o.straws){for(let i=0;i<6;i++){const a=i*Math.PI/3;beam([Math.cos(a)*2.4,27.4+bob,Math.sin(a)*2],[Math.cos(a)*3.6,26.4+bob,Math.sin(a)*3],.2,o.straws,.05,.05)}
  for(const [el,ha]of[[elL,haL],[elR,haR]]){const w=ha.map((v,i)=>v+(el[i]-v)*.16);for(const d of[[1,0,0],[-1,0,0],[0,1,0]])beam(w,w.map((v,i)=>v+d[i]*1.4),.18,o.straws,.05,.05)}
  for(const s of[-1,1]){const L=leg(s);for(const d of[-1,1])beam([L.x,3.6+L.lift,L.z],[L.x+d*1.3,2.8+L.lift,L.z+d*.6],.2,o.straws,.05,.05)}}
 if(o.glitter){
  for(let i=0;i<4;i++){const phase=(time*1.1+i*.29+i*.13)%1;if(phase>.3)continue;const r=Math.sin(phase/.3*Math.PI)*1.2,x=-3+i*2,y=22+(i%2)*3;
   chest(x,y,r*2,.17,'#fffbe0',4.9);chest(x,y,.17,r*2,'#fffbe0',4.9)}
 }


 ctx.save();ctx.translate(cx,cy);ctx.scale(scale,scale);ctx.lineJoin='round';ctx.lineCap='round';

 if(o.faded)ctx.globalAlpha*=.5;
 if(o.holo)ctx.globalAlpha*=.74+.15*Math.sin(time*9);
 if(o.phantom)ctx.globalAlpha*=.62;
 // Ground light is part of the sprite, behind the feet and their contact shadow.
 const ground=o.ring||o.glow;
 if(ground){
  const rgb=hex(ground).join(',');
  ctx.save();ctx.translate(0,1);ctx.scale(1,.4);
  const light=ctx.createRadialGradient(0,0,3,0,0,21);
  light.addColorStop(0,'rgba('+rgb+',.04)');light.addColorStop(.48,'rgba('+rgb+',.23)');light.addColorStop(1,'rgba('+rgb+',0)');
  ctx.fillStyle=light;ctx.fillRect(-21,-21,42,42);ctx.restore();
  const ring=(col,rx,ry)=>{
   ctx.save();ctx.strokeStyle=col;
   ctx.shadowColor=col;ctx.shadowBlur=3*scale;
   for(const [width,alpha]of [[2.5,.55],[1.1,.95]]){
    ctx.save();ctx.globalAlpha*=alpha;ctx.lineWidth=width;ctx.beginPath();ctx.ellipse(0,1,rx,ry,0,0,Math.PI*2);ctx.stroke();ctx.restore();
   }
   ctx.shadowBlur=0;ctx.globalAlpha*=.85;ctx.strokeStyle='#f4fff4';ctx.lineWidth=.28;ctx.beginPath();ctx.ellipse(0,1,rx,ry,0,0,Math.PI*2);ctx.stroke();ctx.restore();
  };
  if(o.glow)ring(o.glow,12,4.7);
  if(o.ring)ring(o.ring,11,4.5);
 }
 ctx.fillStyle='rgba(0,0,0,.23)';
ctx.beginPath();ctx.ellipse(0,1.1,10.5,4,0,0,Math.PI*2);ctx.fill();
 faces.sort((a,b)=>a.depth-b.depth);
 for(const f of faces){
  ctx.beginPath();f.pts.forEach((p,i)=>i?ctx.lineTo(p[0],p[1]):ctx.moveTo(p[0],p[1]));ctx.closePath();ctx.fillStyle=f.col;
  if(f.emission){ctx.shadowColor=f.emission;ctx.shadowBlur=2.2*scale;ctx.fill();ctx.shadowBlur=0}
  ctx.fill();ctx.strokeStyle=f.col;ctx.lineWidth=.13;ctx.stroke();
  ctx.strokeStyle='#070a08';ctx.lineWidth=f.outline;
  for(const[a,b]of f.edges){ctx.beginPath();ctx.moveTo(a[0],a[1]);ctx.lineTo(b[0],b[1]);ctx.stroke()}
 }
 ctx.restore();
 let left=ground?-22:-13,right=ground?22:13,top=-1,bottom=ground?11:6;
 for(const f of faces)for(const p of f.pts){const pad=f.emission?4:1;left=Math.min(left,p[0]-pad);right=Math.max(right,p[0]+pad);top=Math.min(top,p[1]-pad);bottom=Math.max(bottom,p[1]+pad)}
 return {left:Math.floor(left),top:Math.floor(top),w:Math.ceil(right)-Math.floor(left),h:Math.ceil(bottom)-Math.floor(top)};
}


// Serialize this complete closure for workers: minification can rename every internal dependency safely.
return {paintWardrobeCharacter,wardrobeStep};
}
const {paintWardrobeCharacter,wardrobeStep}=createWardrobeRenderer();

// Compensate for the model's flattened depth before aligning it with the screen aim.
function wardrobeAimAngle(sd){return Math.atan2(sd.x,sd.y/.32)}
function wardrobeBarrel(o,sd,walk=0){
 const angle=Math.round(wardrobeAimAngle(sd)*180/Math.PI)*Math.PI/180;
 const phase=Math.round(walk*24/(Math.PI*2))*Math.PI*2/24,pose=Object.assign({},o);
 if(pose.bolt!==undefined)pose.bolt=Math.round(pose.bolt*24)/24;
 return paintWardrobeCharacter(null,pose,angle,0,1,0,0,phase);
}
// Cosmetic coordinates only: collision position, speed, spread, damage and range stay untouched.
function wardrobeShotVisual(from,ang,gun){
 if(from.id===undefined||players.get(from.id)!==from)return null;
 const look=Object.assign(playerLook(from),{bolt:gun.bolt?0:-1}),barrel=wardrobeBarrel(look,wdirToScreen(from.aim),look.walk??from.walk??0);
 const tip=barrel.tip.map(v=>v*FIG),root=barrel.root.map(v=>v*FIG);
 const vx=(Math.cos(ang)-Math.sin(ang))*32,vy=(Math.cos(ang)+Math.sin(ang))*16;
 const along=((tip[0]-root[0])*vx+(tip[1]-root[1])*vy)/(vx*vx+vy*vy);
 const c=iso(from.x,from.y),m=screenToWorld(c[0]+tip[0]*u,c[1]+tip[1]*u);
 return [tip[0]-vx*along,tip[1]-vy*along,m.x,m.y];
}
function flashPoint(f){const c=f.visual?iso(f.visual[0],f.visual[1]):iso(f.x,f.y);return [c[0],c[1]-(f.visual?0:WH*.5)]}

// Bounded sprite cache keeps the full mesh out of steady-state gameplay frames.
// 360 headings and 24 gait samples affect illustration only, never simulation or aiming.
const WARDROBE_CACHE=new Map(),WARDROBE_OMIT=new Set(['aim','walk','tag','tagCol','hp','big','detail','syncRender']);
const WARDROBE_SCRATCH=document.createElement("canvas"),WARDROBE_POOL=[];
const wardrobeScratchContext=WARDROBE_SCRATCH.getContext("2d",{willReadFrequently:true});
let wardrobeCacheBytes=0;

const WARDROBE_RECENT=new Map(),WARDROBE_JOBS=new Map(),WARDROBE_BUSY=new Set();
let wardrobeWorkers=null,wardrobeWorkerURL=null,wardrobeWorkerCompletions=0;
function rememberWardrobe(actor,key){
 WARDROBE_RECENT.delete(actor);WARDROBE_RECENT.set(actor,key);
 while(WARDROBE_RECENT.size>64)WARDROBE_RECENT.delete(WARDROBE_RECENT.keys().next().value);
}
function storeWardrobe(key,entry){
 if(WARDROBE_CACHE.has(key)){if(entry.cv.close)entry.cv.close();return}
 while(WARDROBE_CACHE.size&&(wardrobeCacheBytes+entry.bytes>24*1024*1024||WARDROBE_CACHE.size>=96)){
  const k=WARDROBE_CACHE.keys().next().value,old=WARDROBE_CACHE.get(k);wardrobeCacheBytes-=old.bytes;
  if(old.cv.close)old.cv.close();else if(WARDROBE_POOL.length<4)WARDROBE_POOL.push(old.cv);
  WARDROBE_CACHE.delete(k);
 }
 WARDROBE_CACHE.set(key,entry);wardrobeCacheBytes+=entry.bytes;
}
function startWardrobeWorkers(){
 if(wardrobeWorkers!==null)return wardrobeWorkers.length>0;
 wardrobeWorkers=[];
 if(typeof Worker==='undefined'||typeof OffscreenCanvas==='undefined'||typeof ImageBitmap==='undefined')return false;
 const source="const paint=("+createWardrobeRenderer.toString()+")().paintWardrobeCharacter;"+"\n const stage=new OffscreenCanvas(1,1),ctx=stage.getContext('2d',{willReadFrequently:true}),out=new OffscreenCanvas(1,1),outctx=out.getContext('2d',{willReadFrequently:true});\n onmessage=e=>{const j=e.data;\n try{\n  const w=72*j.r,h=72*j.r;\n  if(stage.width!==w||stage.height!==h){stage.width=w;stage.height=h}else ctx.clearRect(0,0,w,h);\n  const bounds=paint(ctx,j.pose,j.heading*Math.PI/180,j.tick,j.r,36*j.r,54*j.r,j.gait*Math.PI*2/24);\n  if(out.width!==bounds.w*j.r||out.height!==bounds.h*j.r){out.width=bounds.w*j.r;out.height=bounds.h*j.r}\n  outctx.drawImage(stage,(36+bounds.left)*j.r,(54+bounds.top)*j.r,out.width,out.height,0,0,out.width,out.height);\n  const bitmap=out.transferToImageBitmap();postMessage({key:j.key,actor:j.actor,bounds,bitmap},[bitmap]);\n }catch(error){postMessage({failed:true,actor:j.actor})}\n };\n postMessage({ready:true});";
 try{
  wardrobeWorkerURL=URL.createObjectURL(new Blob([source],{type:'text/javascript'}));
  const n=(navigator.hardwareConcurrency||2)>=4?2:1;let ready=0;
  for(let i=0;i<n;i++){
   const worker=new Worker(wardrobeWorkerURL),slot={worker,busy:false};wardrobeWorkers.push(slot);
   worker.onerror=()=>{for(const s of wardrobeWorkers)s.worker.terminate();wardrobeWorkers=[];WARDROBE_BUSY.clear();WARDROBE_JOBS.clear();if(wardrobeWorkerURL){URL.revokeObjectURL(wardrobeWorkerURL);wardrobeWorkerURL=null}};
   worker.onmessage=e=>{
    const m=e.data;if(m.ready){if(++ready===n&&wardrobeWorkerURL){URL.revokeObjectURL(wardrobeWorkerURL);wardrobeWorkerURL=null}return}
    slot.busy=false;WARDROBE_BUSY.delete(m.actor);
    if(m.failed){worker.onerror();return}
    wardrobeWorkerCompletions++;storeWardrobe(m.key,{cv:m.bitmap,bytes:m.bitmap.width*m.bitmap.height*4,...m.bounds});rememberWardrobe(m.actor,m.key);
    dispatchWardrobeJobs();
   };
  }
 }catch(error){for(const s of wardrobeWorkers)s.worker.terminate();wardrobeWorkers=[];if(wardrobeWorkerURL){URL.revokeObjectURL(wardrobeWorkerURL);wardrobeWorkerURL=null}}
 return wardrobeWorkers.length>0;
}
function dispatchWardrobeJobs(){
 for(const slot of wardrobeWorkers||[]){
  if(slot.busy)continue;
  for(const [actor,job]of WARDROBE_JOBS){
   if(WARDROBE_BUSY.has(actor))continue;
   WARDROBE_JOBS.delete(actor);WARDROBE_BUSY.add(actor);slot.busy=true;slot.worker.postMessage(job);break;
  }
 }
}
function queueWardrobePose(job){
 WARDROBE_JOBS.set(job.actor,job);
 while(WARDROBE_JOBS.size>16)WARDROBE_JOBS.delete(WARDROBE_JOBS.keys().next().value);
 dispatchWardrobeJobs();
}


// what decides which cached pose drawWardrobeCharacter shows (heading step and animation tick), so a caller can skip
// repainting when nothing it would draw has changed
function wardrobePoseSig(o,angle,time,scale){const step=scale>3?8:5,animated=o.stars||o.holo||o.glitter||o.halo||o.glitchm;
 return Math.round(angle*180/Math.PI/step)+':'+(animated?Math.floor(time*20):o.pking?Math.floor(time*6)%4:0)}
function drawWardrobeCharacter(ctx,o,angle,time,scale,cx,cy,walking=false){
 const step=scale>3?8:5,heading=Math.round(angle*180/Math.PI/step)*step,phase=typeof walking==='number'?walking:walking?time*7:0;
 const gait=Math.round(((phase%(Math.PI*2))+Math.PI*2)%(Math.PI*2)*24/(Math.PI*2));
 const animated=o.stars||o.holo||o.glitter||o.halo||o.glitchm;
 const tick=animated?Math.floor(time*20)/20:o.pking?Math.floor(time*6)%4:0,pose=Object.assign({},o);
 if(pose.bolt!==undefined)pose.bolt=Math.round(pose.bolt*24)/24;
 const tr=ctx.getTransform(),dpr=Math.min(3,Math.max(1,Math.hypot(tr.a,tr.b))),r=Math.ceil(scale*Math.min(dpr,2));   // 2x is plenty for these sprites; 3x made big previews ~1 MB each and overflowed the cache
 const key=Object.keys(pose).filter(k=>!WARDROBE_OMIT.has(k)).sort().map(k=>k+':'+pose[k]).join('|')+';'+heading+';'+gait+';'+tick+';'+r;
 const actor=Object.keys(pose).filter(k=>!WARDROBE_OMIT.has(k)&&!['bolt','gaitWeight','gaitDir','breath'].includes(k)).sort().map(k=>k+':'+pose[k]).join('|')+';'+(o.tag||'self')+';'+r;
 let entry=WARDROBE_CACHE.get(key);
 if(!entry&&scale<=3&&!o.syncRender&&!o.flash&&!o.downed&&startWardrobeWorkers()){
  const previous=WARDROBE_CACHE.get(WARDROBE_RECENT.get(actor));
  if(previous){
   queueWardrobePose({actor,key,pose,heading,gait,tick,r});
   ctx.drawImage(previous.cv,cx+previous.left*scale,cy+previous.top*scale,previous.w*scale,previous.h*scale);return;
  }
 }
 if(entry){WARDROBE_CACHE.delete(key);WARDROBE_CACHE.set(key,entry)}
 else{
  const cv=WARDROBE_SCRATCH;if(cv.width!==72*r||cv.height!==72*r){cv.width=72*r;cv.height=72*r}else wardrobeScratchContext.clearRect(0,0,cv.width,cv.height);
  const bounds=paintWardrobeCharacter(wardrobeScratchContext,pose,heading*Math.PI/180,tick,r,36*r,54*r,gait*Math.PI*2/24);
  const sprite=WARDROBE_POOL.pop()||document.createElement('canvas');sprite.width=bounds.w*r;sprite.height=bounds.h*r;
  sprite.getContext('2d',{willReadFrequently:true}).drawImage(cv,(36+bounds.left)*r,(54+bounds.top)*r,sprite.width,sprite.height,0,0,sprite.width,sprite.height);
  entry={cv:sprite,bytes:sprite.width*sprite.height*4,...bounds};
  storeWardrobe(key,entry);
 }
 rememberWardrobe(actor,key);
 ctx.drawImage(entry.cv,cx+entry.left*scale,cy+entry.top*scale,entry.w*scale,entry.h*scale);
}

// bp: bolt-action phase after a shot (0 = just fired, 1 = bolt home), or -1 for none
// kind: '' rifle/carbine, 'sg' pump shotgun (the fore-end slides back on each pump), 'rpg' launcher tube,
// 'zap' lightning rifle, 'sword' (swing: 0 rest, 1 wind-up, 2 charge wind-up, 3 charging)
function gunArms(hand,sd,gl,shB,shF,sleeve,nogun,bob,bp=-1,kind='',swing=0){
  if(nogun){limb(shB,[shB[0],-13.5+bob],sleeve,2.6);limb(shF,[shF[0],-13.5+bob],sleeve,2.6);return}
  if(kind==='sword'||kind==='swordp'){const pk=kind==='swordp';
    const sx=sd.x>=0?1:-1,a=swing===1?Math.atan2(-1,sx*.35):swing===2?Math.atan2(-.35,sx):swing===3?Math.atan2(sd.y,sd.x):Math.atan2(sd.y+.7,sd.x),c=Math.cos(a),n=Math.sin(a);
    limb(shB,hand,sleeve,2.6);limb(shF,hand,sleeve,2.6);
    const tip=[hand[0]+c*25,hand[1]+n*25],base=[hand[0]+c*2,hand[1]+n*2];
    if(swing===1||swing===2){g.globalAlpha=.55;seg(base,tip,pk?'#ff8a2a':'#ff4a32',6);g.globalAlpha=1}
    if(pk){g.globalAlpha=.3+.15*Math.sin(game.time*11);seg(base,tip,'#ff9a3a',5);g.globalAlpha=1}
    seg([hand[0]-c*4,hand[1]-n*4],base,OUT,3.4);seg([hand[0]-c*4,hand[1]-n*4],base,'#3a2a1a',2);
    seg(base,tip,OUT,3.8);seg(base,tip,pk?'#ffb070':'#d9dee0',2.2);seg([base[0]+c*6,base[1]+n*6],tip,pk?'#fff0c8':'#ffffff',.7);
    seg([base[0]-n*4,base[1]+c*4],[base[0]+n*4,base[1]-c*4],OUT,2.8);seg([base[0]-n*3.4,base[1]+c*3.4],[base[0]+n*3.4,base[1]-c*3.4],'#8a6a36',1.6);return}
  if(kind==='shield'){   // riot shield on the front arm, pistol in the other hand
    limb(shB,hand,sleeve,2.6);const pm=[hand[0]+sd.x*6,hand[1]+sd.y*6];seg(hand,pm,OUT,3.6);seg(hand,pm,'#2b2823',2.2);
    const cx=hand[0]+sd.x*5,cy=hand[1]+sd.y*3-4,w=4+9*Math.min(1,Math.abs(sd.y)*1.7),h=22;limb(shF,[cx,cy+2],sleeve,2.6);
    g.fillStyle=OUT;g.fillRect(cx-w/2-1,cy-h/2-1,w+2,h+2);g.fillStyle='#4a5358';g.fillRect(cx-w/2,cy-h/2,w,h);g.fillStyle='#6b767c';g.fillRect(cx-w/2,cy-h/2,w*.35,h);
    g.fillStyle='rgba(160,200,220,.6)';g.fillRect(cx-w*.32,cy-h*.34,w*.64,2.2);g.fillStyle='#e2b436';g.fillRect(cx-w/2,cy+h*.28,w,1.6);return}
  if(kind==='bottle'){   // a lit fire bottle held up, ready to throw
    limb(shB,[shB[0],-13.5+bob],sleeve,2.6);const b=[shF[0]+sd.x*3,shF[1]-7];limb(shF,b,sleeve,2.6);
    g.fillStyle=OUT;g.fillRect(b[0]-2.2,b[1]-6,4.4,7);g.fillStyle='#3f7a4a';g.fillRect(b[0]-1.6,b[1]-5.4,3.2,6);g.fillStyle='#e8dcc0';g.fillRect(b[0]-.8,b[1]-8,1.6,2.6);
    const f=Math.sin(game.time*20)*.8;g.fillStyle='#ff8a2a';g.beginPath();g.moveTo(b[0]-1.8,b[1]-8);g.quadraticCurveTo(b[0]+f,b[1]-15,b[0]+1.8,b[1]-8);g.fill();
    g.fillStyle='#ffd070';g.beginPath();g.moveTo(b[0]-.9,b[1]-8);g.quadraticCurveTo(b[0]+f*.5,b[1]-12,b[0]+.9,b[1]-8);g.fill();return}
  if(kind==='drill'){   // the Foreman's rock drill, pointed at the ground
    const d0=[hand[0]+sd.x*2,hand[1]-2],d1=[d0[0]+sd.x*6,d0[1]+12];limb(shB,d0,sleeve,2.6);limb(shF,[d0[0]+sd.x*3,d0[1]+1],sleeve,2.6);
    seg(d0,d1,OUT,6.4);seg(d0,d1,'#e0a030',4.6);seg([d0[0]-3,d0[1]],[d0[0]+3,d0[1]],OUT,3);const jit=Math.sin(game.time*60)*.6,tip=[d1[0]+sd.x+jit,d1[1]+6];seg(d1,tip,OUT,2.6);seg(d1,tip,'#b9bcb8',1.4);return}
  let kb=0,pull=0;
  if(bp>=0){kb=bp<.2?(1-bp/.2)*2.6:0;if(bp>.24&&bp<.9)pull=Math.sin((bp-.24)/.66*Math.PI)}
  const lift=kind==='sg'?kb*.5:pull*2.4+kb*.5,at=k=>[hand[0]+sd.x*(k-kb),hand[1]+sd.y*(k-kb)-lift*Math.max(0,k+5)/(gl+5)];
  const stock=at(-5),muz=at(gl),mid=at(gl*.55),mg=at(2.2);
  if(kind==='harpoon'){   // the Ferryman's harpoon gun: long, with a barbed head
    limb(shB,hand,sleeve,2.6);const a0=at(-6),a1=at(gl);seg(a0,a1,OUT,4.6);seg(a0,a1,'#5a4630',3);const t0=at(gl),t1=at(gl+5);seg(t0,t1,OUT,3);seg(t0,t1,'#c9ccc8',1.6);
    const bb=at(gl+2.4);seg(bb,[bb[0]-sd.y*3-sd.x*2,bb[1]+sd.x*3-sd.y*2],'#c9ccc8',1.2);seg(bb,[bb[0]+sd.y*3-sd.x*2,bb[1]-sd.x*3-sd.y*2],'#c9ccc8',1.2);
    limb(shF,at(gl*.4),sleeve,2.6);return}
  if(kind==='rpg'){limb(shB,hand,sleeve,2.6);const a0=at(-8),a1=at(gl);seg(a0,a1,OUT,7.4);seg(a0,a1,'#4d5638',5.4);seg(at(gl*.28),at(gl*.36),'#2c3122',5.6);
    const w=at(gl+2.6);disc(w[0],w[1],3.8,OUT);disc(w[0],w[1],3,'#7a6f58');disc(w[0]+sd.x*1.6,w[1]+sd.y*1.6,1.6,'#9a8c6c');
    seg(mg,[mg[0],mg[1]+4],OUT,3);seg(mg,[mg[0],mg[1]+3.6],'#2b2823',1.7);limb(shF,at(gl*.38),sleeve,2.6);return}
  if(kind==='sg'){limb(shB,hand,sleeve,2.6);seg(stock,muz,OUT,5.2);seg(stock,at(gl*.18),'#6a4526',3.8);seg(at(gl*.18),muz,'#34312b',2.6);
    const sl=pull*3.6,f0=at(gl*.46-sl),f1=at(gl*.76-sl);seg(f0,f1,OUT,5.4);seg(f0,f1,'#7a5230',3.6);
    seg(mg,[mg[0],mg[1]+3.8],OUT,3);seg(mg,[mg[0],mg[1]+3.4],'#2b2823',1.7);limb(shF,at(gl*.62-sl),sleeve,2.6);return}
  if(bp>=0){const kn=at(3.2-pull*6),up=pull*2.6;
    limb(shB,[kn[0],kn[1]-up],sleeve,2.6);
    seg(stock,muz,OUT,4.4);seg(stock,mid,'#2b2823',3);seg(mid,muz,'#45423b',1.8);
    seg(mg,[mg[0],mg[1]+3.8],OUT,3);seg(mg,[mg[0],mg[1]+3.4],'#2b2823',1.7);
    seg(at(1.6),[kn[0],kn[1]-up],OUT,2.2);seg(at(1.6),[kn[0],kn[1]-up],'#8d887b',1.1);disc(kn[0],kn[1]-up,1.3,OUT);disc(kn[0],kn[1]-up,.8,'#b7b1a2')}
  else{limb(shB,hand,sleeve,2.6);
    seg(stock,muz,OUT,4.4);seg(stock,mid,'#2b2823',3);seg(mid,muz,'#45423b',1.8);
    seg(mg,[mg[0],mg[1]+3.8],OUT,3);seg(mg,[mg[0],mg[1]+3.4],'#2b2823',1.7)}
  if(kind==='zap'){for(const k of[.62,.74,.86]){const c=at(gl*k);disc(c[0],c[1],1.5,'#7fe0ff')}g.globalAlpha=.8;disc(muz[0],muz[1],2.4,'#bff3ff');g.globalAlpha=1}
  limb(shF,at(gl*.42),sleeve,2.6);
}
// A soldier, raider or Delgado standing at tile (x,y), facing o.aim. Drawn in base pixels, scaled.
function drawPerson(x,y,o){
  if(o.mark&&o.detail!==false||o.sahur||o.halloweenHat||o.sheet){
    const [sx,sy]=iso(x,y),sd=wdirToScreen(o.aim),BG=o.big||1;
    if(o.aura)paintAura(g,o.aura,sx,sy,u*FIG*BG,game.time,o.faded?.5:1,'ground');   // v0.9.3: rings and pools under the figure,
    drawWardrobeCharacter(g,o,wardrobeAimAngle(sd),game.time,u*FIG*BG,sx,sy,o.walk||0);
    if(o.aura)paintAura(g,o.aura,sx,sy,u*FIG*BG,game.time,o.faded?.5:1,'top');      // the rest over the cached figure
    if(o.hp!==undefined&&o.hp<1){g.fillStyle='rgba(10,8,6,.8)';g.fillRect(sx-8*u,sy-43*u,16*u,2.6*u);g.fillStyle='#d65a3a';g.fillRect(sx-8*u,sy-43*u,16*u*Math.max(0,o.hp),2.6*u)}
    if(o.tag)label(o.tag,sx,sy-46*u*BG,o.tagCol||'#a9bccb',BG>1?11:9);
    return;
  }
  const [sx,sy]=iso(x,y),BG=o.big||1;
  g.save();g.translate(sx,sy);g.scale(u*FIG*BG,u*FIG*BG);
  const walk=o.walk||0,bob=-Math.abs(Math.sin(walk))*1.1;
  const sd=wdirToScreen(o.aim),side=sd.x>=0?1:-1,front=sd.y>=-.15,lit=o.flash;
  const skin=lit?LIT:o.head,body=lit?LIT:o.body,vest=o.vest,pants=o.pants||'#3b372c',gl=o.gl||14,nogun=!!o.nogun;
  if(o.faded)g.globalAlpha=.5;
  if(o.holo)g.globalAlpha*=.66+.18*Math.sin(game.time*9)-(rnd()<.05?.3:0);   // hologram: flickers
  if(o.phantom)g.globalAlpha*=.6+.1*Math.sin(game.time*4.2);   // phantom: see-through, breathing
  const A0=g.globalAlpha;
  if(o.glow){g.globalAlpha=.4;oval(0,0,13,6,o.glow);g.globalAlpha=o.faded?.5:1}
  oval(0,0,10,4.8,'rgba(0,0,0,.38)');
  if(o.ring){g.strokeStyle=o.ring;g.lineWidth=1.6;g.beginPath();g.ellipse(0,0,10.5,5,0,0,Math.PI*2);g.stroke()}
  const sw=Math.sin(walk)*2.6,hy=-12+bob,lf=[-2.8+sw,-2],rf=[2.8-sw,-2];
  limb([-2.5,hy],lf,pants,3.2);limb([2.5,hy],rf,pants,3.2);
  for(const f of[lf,rf])P(rectP(f[0]+side*.8,f[1]+.6,4.6,2.6),'#1a1612');
  const hand=[sd.x*6,-17+bob+sd.y*3],shB=[-side*5,-22.5+bob],shF=[side*5,-22.5+bob];
  if(o.pack&&front)P(rectP(-side*1.2,-19.5+bob,13,11),o.pack);
  const bp=o.bolt===undefined?-1:o.bolt;
  if(!front)gunArms(hand,sd,gl,shB,shF,body,nogun,bob,bp,o.weapon,o.swing);
  P([[-6.2,-24.5+bob],[6.2,-24.5+bob],[4.8,-11.5+bob],[-4.8,-11.5+bob]],body);
  P([[-5,-23+bob],[5,-23+bob],[4.3,-14.5+bob],[-4.3,-14.5+bob]],vest,false);
  if(front){g.fillStyle=dark(vest,.3);for(const px of[-4,-1.2,1.6])g.fillRect(px,-17.2+bob,2.4,2.6)}
  if(o.stripe)for(const[a,b2]of[[-5,-7],[-1,-2.5],[3,1.5]]){seg([a,-23.5+bob],[b2+2,-13+bob],o.stripe,1.3)}
  if(o.shine){g.globalAlpha=.45;seg([-4,-23+bob],[-2.4,-14+bob],'#fff6c8',1.2);g.globalAlpha=1}
  if(o.bandolier){seg([-5.2*side,-23.5+bob],[4.6*side,-13+bob],'#1d1914',2.6);seg([-5.2*side,-23.5+bob],[4.6*side,-13+bob],'#8a6a36',1.6);
    if(front)for(let k=0;k<4;k++){const t=(k+.6)/4.4;disc(-5.2*side+9.8*side*t,-23.5+10.5*t+bob,1.45,OUT);disc(-5.2*side+9.8*side*t,-23.5+10.5*t+bob,1.05,'#8aa83f')}}   // green grenades on the strap
  if(o.plate){P(domeP(-5.8,-21.4+bob,3.1),o.plate);P(domeP(5.8,-21.4+bob,3.1),o.plate);seg([0,-23+bob],[0,-14.6+bob],dark(o.plate,.35),1.2);seg([-4.2,-18.6+bob],[4.2,-18.6+bob],dark(o.plate,.3),1)}
  if(o.dots)for(const[a,b2]of[[-3.2,-20.6],[2.4,-17.4],[-1,-14.9],[3.4,-22.1]])disc(a,b2+bob,1.15,o.dots);
  if(o.spots)for(const[a,b2,l]of[[-3,-21.5,3],[2,-19.5,4],[0,-15.5,2.5]]){seg([a,b2+bob],[a,b2+l+bob],o.spots,1.3);disc(a,b2+l+bob,.95,o.spots)}
  if(o.ruff)for(let k=0;k<6;k++){const x0=-7+k*2.35;P([[x0,-24.4+bob],[x0+1.18,-26.4+bob],[x0+2.35,-24.4+bob]],o.ruff,false)}
  if(o.badge&&front){const bx=side*2.4,by=-20.2+bob;P([[bx,by-2.1],[bx+1.8,by-.6],[bx+1.2,by+1.8],[bx-1.2,by+1.8],[bx-1.8,by-.6]],o.badge)}
  if(o.neon){neonSeg([-5.7,-23.8+bob],[-4.5,-12.3+bob],o.neon);neonSeg([5.7,-23.8+bob],[4.5,-12.3+bob],o.neon);neonSeg([-4.8,-12.3+bob],[4.8,-12.3+bob],o.neon);if(front)neonSeg([0,-22.6+bob],[0,-15+bob],o.neon)}
  if(o.stars){for(let k=0;k<9;k++){g.globalAlpha=A0*(.3+.7*Math.abs(Math.sin(game.time*2.2+k*1.9)));g.fillStyle=k%3?'#ffffff':'#c9b8ff';g.fillRect(-5.2+hash(k,3)*10.4,-24+hash(k,7)*11.4+bob,.9,.9)}g.globalAlpha=A0}
  if(o.frost)for(const[a,b2]of[[-5.2,-22.5],[5.2,-22.5],[-2,-13.6]]){seg([a-1.1,b2+bob],[a+1.1,b2+bob],o.frost,.6);seg([a,b2-1.1+bob],[a,b2+1.1+bob],o.frost,.6)}
  if(o.chrome){g.globalAlpha=A0*.55;seg([2.2,-23.4+bob],[3.4,-12.8+bob],'#ffffff',1.1);g.globalAlpha=A0}
  if(o.holo){g.globalAlpha=A0*.32;for(let yy=-25;yy<-11;yy+=1.6)seg([-6.4,yy+bob],[6.4,yy+bob],'#e6fdff',.35);g.globalAlpha=A0}
  if(o.glitter)for(let k=0;k<4;k++){const ph=(game.time*1.1+k*.29+hash(k,11))%1;if(ph>.3)continue;const sz=Math.sin(ph/.3*Math.PI)*1.6,x0=-4.6+hash(k,5)*9.2,y0=-23.5+hash(k,9)*11+bob;
    seg([x0-sz,y0],[x0+sz,y0],'#fffbe0',.6);seg([x0,y0-sz],[x0,y0+sz],'#fffbe0',.6)}
  if(o.ribs)for(const a of[-3.2,0,3.2])seg([a,-24+bob],[a*.85,-12.6+bob],o.ribs,.8);
  if(o.web){g.globalAlpha=A0*.8;const c=[-1.5,-19.5+bob];for(let k=0;k<6;k++){const an=k*Math.PI/3;seg(c,[c[0]+Math.cos(an)*6.5,c[1]+Math.sin(an)*6],o.web,.45)}
    for(const r of[2.2,4.4])for(let k=0;k<6;k++){const a0=k*Math.PI/3,a1=a0+Math.PI/3;seg([c[0]+Math.cos(a0)*r,c[1]+Math.sin(a0)*r*.92],[c[0]+Math.cos(a1)*r,c[1]+Math.sin(a1)*r*.92],o.web,.4)}g.globalAlpha=A0}
  if(o.bones){seg([0,-23.6+bob],[0,-13+bob],o.bones,1.3);for(const[yy,w]of[[-21.8,4.6],[-19.6,4.9],[-17.4,4.6],[-15.3,3.8]]){seg([-w,yy+bob],[w,yy+bob],o.bones,1)}
    seg([-2.2,-12.4+bob],[2.2,-12.4+bob],o.bones,1.6)}
  if(o.wraps){g.globalAlpha=A0*.9;for(let k=0;k<6;k++){const yy=-24+k*2.1;seg([-6,yy+bob+(k%2?1.2:0)],[6,yy+bob+(k%2?0:1.2)],o.wraps,.7)}
    for(const x of[-2.5,2.5])for(let yy=-10;yy>-2;yy-=2.4)seg([x-1.6,yy+bob],[x+1.6,yy-1+bob],o.wraps,.6);g.globalAlpha=A0}
  if(o.reaper){P([[-6.4,-13+bob],[6.4,-13+bob],[7.6,-1.2],[-7.6,-1.2]],o.body);seg([-7.2,-1.6],[7.2,-1.6],dark(o.body,.4),.8);
    for(const x of[-3,1.5])seg([x,-12+bob],[x*1.2,-2],dark(o.body,.5),.5)}
  if(o.phantom){const t=game.time,A=A0;g.globalAlpha=A*.55;for(let k=0;k<3;k++){const x0=-3.5+k*3.5,ph=t*3+k*2;
    g.strokeStyle=o.phantom;g.lineWidth=1.4;g.beginPath();g.moveTo(x0,-11+bob);for(let yy=-9;yy<=1;yy+=2)g.lineTo(x0+Math.sin(ph+yy*.5)*1.4,yy+bob);g.stroke()}g.globalAlpha=A}
  seg([-4.8,-12.2+bob],[4.8,-12.2+bob],'#1d1914',1.8);
  if(o.mark){g.fillStyle=o.mark;g.fillRect(shF[0]-1.3,shF[1]+.8,2.6,2.4)}
  if(o.satchel){const c=[side*5.5,-14+bob];P(rectP(c[0],c[1],6,5),'#1a1510');g.fillStyle='#d65a3a';g.fillRect(c[0]-1,c[1]-1,2,1.5)}
  if(o.pack&&!front){P(rectP(0,-18.5+bob,11,10),o.pack);seg([-5.5,-21.5+bob],[5.5,-21.5+bob],OUT,1)}
  const hx=side*.4;let hy2=-28.8+bob;
  if(!o.pumpkin){disc(hx,hy2,5.3,OUT);disc(hx,hy2,4.5,front?skin:dark(skin,.3))}
  if(front&&!o.pumpkin&&!o.hood&&!o.sheet&&!o.glitchm&&!o.mask&&!o.visor&&!o.hockey&&!o.sack&&!o.facewrap&&!o.khelm&&!o.bomb&&!o.clownface){
    if(o.bones){g.fillStyle='#1a1614';disc(hx-1.5+side*1.2,hy2-.5,1.3,'#1a1614');disc(hx+1.5+side*1.2,hy2-.5,1.3,'#1a1614');g.fillRect(hx+side*1.2-.4,hy2+1.2,.8,1);
      for(let k=-2;k<=2;k++)g.fillRect(hx+side*1.2+k*.8-.2,hy2+2.8,.4,1)}
    else if(o.phantom){disc(hx-1.5+side*1.2,hy2-.6,1,'#0e3a26');disc(hx+1.5+side*1.2,hy2-.6,1,'#0e3a26');g.globalAlpha=A0*.6;disc(hx+side*1.2,hy2+2.2,.9,'#0e3a26');g.globalAlpha=A0}
    else{g.fillStyle=OUT;g.fillRect(hx-1.9+side*1.2,hy2-.9,1.1,1.3);g.fillRect(hx+.9+side*1.2,hy2-.9,1.1,1.3)}
    if(o.wraps){for(const d of[-2.6,.8,3.4])seg([hx-4.2,hy2+d],[hx+4.2,hy2+d-1],o.wraps,.7);g.fillStyle='#ffd24a';g.fillRect(hx-1.8+side*1.2,hy2-.9,.9,.6);g.fillRect(hx+1+side*1.2,hy2-.9,.9,.6)}
    if(o.bandana)P(rectP(hx+side*.4,hy2+2.3,8.2,3.6),o.bandana)}
  if(o.pumpkin){const pc=o.pumpkin,fl=o.pking?.75+.25*Math.sin(game.time*17)*Math.sin(game.time*7.3):1;
    // Cover the regular head footprint, including the side silhouette.
    const py=hy2+.5;oval(hx,py-.4,6.1,5.5,OUT);oval(hx,py-.4,5.5,4.9,pc);for(const d of[-3,-1,1,3]){const dd=d+sd.x*1.2;if(Math.abs(dd)<4.6)seg([hx+dd*.62,py-4.8],[hx+dd*.9,py+4],dark(pc,.3),.7)}
    seg([hx,py-4.9],[hx+side*.9,py-7.2],'#4a6a22',1.6);hy2=py;
    if(front){const fx=hx+sd.x*2.2,glow=o.pking?`rgba(255,${190+40*fl|0},90,${fl})`:'#ffd24a';g.fillStyle=glow;
      P([[fx-3,hy2-.2],[fx-1.4,hy2-2.6],[fx-.4,hy2-.2]],glow,false);P([[fx+.4,hy2-.2],[fx+1.4,hy2-2.6],[fx+3,hy2-.2]],glow,false);
      P([[fx-3.2,hy2+1.4],[fx-2,hy2+3.2],[fx-.8,hy2+2.2],[fx+.4,hy2+3.4],[fx+1.6,hy2+2.2],[fx+3.2,hy2+1.4],[fx+2.4,hy2+3.8],[fx-2.4,hy2+3.8]],glow,false)}
    if(o.pking){g.globalAlpha=A0*(.5+.4*fl);for(let k=0;k<3;k++){const x0=hx-2+k*2,h=2.4+1.6*Math.sin(game.time*9+k*2.1);P([[x0-1.1,hy2-5.4],[x0,hy2-5.6-h],[x0+1.1,hy2-5.4]],k===1?'#ffd24a':'#ff7a1a',false)}g.globalAlpha=A0}}
  else if(o.hood){P([[hx-6.4,hy2+4.6],[hx-6.2,hy2-3.2],[hx-2.6,hy2-7.4],[hx+3,hy2-7.4],[hx+6.2,hy2-3.4],[hx+6.4,hy2+4.6]],o.hood);
    if(front){oval(hx+side*1.2,hy2+.6,3.6,3.4,'#050407');const e=.6+.4*Math.sin(game.time*3);g.globalAlpha=A0*e;disc(hx-1.3+side*1.4,hy2,.8,o.reaper||'#8fe0ff');disc(hx+1.3+side*1.4,hy2,.8,o.reaper||'#8fe0ff');g.globalAlpha=A0}}
  if(o.helmet){P(domeP(hx,hy2-.4,5.4),o.helmet);seg([hx-6.2,hy2-.3],[hx+6.2,hy2-.3],OUT,1.6);if(o.hneon){neonSeg([hx-4.8,hy2-2.6],[hx+4.8,hy2-2.6],o.hneon);neonSeg([hx,hy2-5.6],[hx,hy2-2.6],o.hneon)}}
  else if(o.beanie){P(domeP(hx,hy2-.2,5.2),o.beanie);g.fillStyle=dark(o.beanie,.3);g.fillRect(hx-5.2,hy2-1.6,10.4,2.2);disc(hx,hy2-6,1.7,OUT);disc(hx,hy2-6,1.2,o.beanie)}
  else if(o.beret){P([[hx-5.6,hy2-1.6],[hx-2,hy2-5],[hx+4.6,hy2-4.4],[hx+6.6,hy2-2.2],[hx+4.8,hy2-1]],o.beret);disc(hx+.5,hy2-4.6,.9,dark(o.beret,.4))}
  else if(o.wrap){P(domeP(hx,hy2-.3,5),o.wrap);seg([hx-side*4.4,hy2-.6],[hx-side*7.4,hy2+2.8],OUT,2.6);seg([hx-side*4.4,hy2-.6],[hx-side*7.4,hy2+2.8],o.wrap,1.4)}
  else if(o.tophat){P(rectP(hx,hy2-2.6,12.4,2.4),o.tophat);P(rectP(hx,hy2-8.1,7.8,10.4),o.tophat);g.fillStyle='#8a2a2a';g.fillRect(hx-3.9,hy2-5.4,7.8,2)}
  else if(o.crown){P([[hx-5,hy2-1.8],[hx-5.2,hy2-7.4],[hx-2.6,hy2-4.6],[hx,hy2-8.6],[hx+2.6,hy2-4.6],[hx+5.2,hy2-7.4],[hx+5,hy2-1.8]],o.crown);disc(hx,hy2-4,1,'#c43a4a')}
  else if(o.cap){P(domeP(hx,hy2-.8,4.9),o.cap);P([[hx+side*2,hy2-1.6],[hx+side*7.6,hy2-.9],[hx+side*7,hy2+.5],[hx+side*1.6,hy2]],dark(o.cap,.25));if(o.capPix&&front){g.fillStyle=o.capPix;g.fillRect(hx+side*1.2-1,hy2-4.4,2,2);g.fillRect(hx+side*1.2+1,hy2-2.4,1,1)}}
  else if(o.boonie){oval(hx,hy2-1.6,8.2,2.6,OUT);oval(hx,hy2-1.6,7.4,2,o.boonie);P(domeP(hx,hy2-1.8,4.4),dark(o.boonie,.12))}
  else if(o.pcap){P(rectP(hx,hy2-3.9,10.6,3.8),o.pcap);P([[hx-5.4,hy2-2.2],[hx+5.4,hy2-2.2],[hx+side*7.4,hy2-.4],[hx-side*.8,hy2-.8]],dark(o.pcap,.35));disc(hx+side*1.6,hy2-4,1.3,OUT);disc(hx+side*1.6,hy2-4,.9,'#e2c25a')}
  else if(o.khelm){P(domeP(hx,hy2-.4,5.9),o.khelm);P(rectP(hx,hy2+1.3,11.4,5.6),o.khelm);
    if(front){g.fillStyle=OUT;g.fillRect(hx-4.2+side*.6,hy2-.8,8.4,1.4);for(const d of[-1.6,0,1.6])g.fillRect(hx+side*2+d-.35,hy2+1.6,.7,1.6)}
    seg([hx,hy2-6.2],[hx,hy2-1],dark(o.khelm,.3),.9);P([[hx-1.1,hy2-5.8],[hx+1.1,hy2-5.8],[hx+side*.6,hy2-10]],dark(o.khelm,.12));
    g.globalAlpha=A0*.6;seg([hx-3.4,hy2-4.6],[hx-4.4,hy2+3],'#fff6c8',.9);g.globalAlpha=A0}
  else if(o.hair){disc(hx,hy2-5.6,6.1,OUT);disc(hx,hy2-5.6,5.5,o.hair);
    if(o.hairGold){g.globalAlpha=A0*.8;for(const[dx,dy]of[[-6.2,-2.8],[1.8,-6.4],[4.6,-2.6]])disc(hx+dx,hy2+dy,.8,'#fffbe0');g.globalAlpha=A0}}
  else if(o.halo){const yy=hy2-9+Math.sin(game.time*2.4)*.7;g.globalAlpha=A0*.4;g.strokeStyle=o.halo;g.lineWidth=3.4;g.beginPath();g.ellipse(hx,yy,6.2,1.9,0,0,Math.PI*2);g.stroke();
    g.globalAlpha=A0;g.lineWidth=1.3;g.beginPath();g.ellipse(hx,yy,6.2,1.9,0,0,Math.PI*2);g.stroke();const a=game.time*3;disc(hx+Math.cos(a)*6.2,yy+Math.sin(a)*1.9,.9,'#ffffff')}
  else if(o.glitchm){const f=Math.floor(game.time*10),jx=(f%7===0)?1.4:0,C5=['#ff3a6a','#3affd8','#6a8aff','#ffe03a','#f3f0ff'];
    for(let a=0;a<3;a++)for(let b=0;b<3;b++){g.fillStyle=C5[(f+a*3+b*7)%5];g.fillRect(hx-4.6+a*3.1+(b===1?jx:0),hy2-4.8+b*3.1,3.1,3.1)}}
  else if(o.mask){if(front){disc(hx,hy2+.3,4.6,'#15151a');const bl=Math.sin(game.time*2.6)>.96;if(!bl){g.fillStyle=o.mask;g.fillRect(hx-2.8+side*1.1,hy2-1.4,1.8,1.2);g.fillRect(hx+1+side*1.1,hy2-1.4,1.8,1.2)}}
    seg([hx-4.8,hy2-1.2],[hx+4.8,hy2-1.2],'#15151a',1)}
  else if(o.visor){P(rectP(hx+side*.5,hy2-.9,10.4,2.8),'#101014');neonSeg([hx-4.4+side*.5,hy2-.9],[hx+4.4+side*.5,hy2-.9],o.visor)}
  else if(o.witch){oval(hx,hy2-2.4,9.4,2.7,OUT);oval(hx,hy2-2.4,8.6,2.1,o.witch);
    P([[hx-4.4,hy2-2.8],[hx+4.4,hy2-2.8],[hx+2.4,hy2-9],[hx-side*1.6,hy2-13.8],[hx-side*5,hy2-12.6],[hx-1.4,hy2-9]],o.witch);
    g.fillStyle='#6a2a8a';g.fillRect(hx-4.3,hy2-4.8,8.6,1.8);P(rectP(hx+side*.4,hy2-3.9,2.6,2.4),'#e2c25a',false);P(rectP(hx+side*.4,hy2-3.9,1.2,1.1),'#6a2a8a',false)}
  else if(o.headband){neonSeg([hx-5,hy2-2.2],[hx+5,hy2-2.2],o.headband);seg([hx-side*4.8,hy2-2.2],[hx-side*7.8,hy2+.6],o.headband,1.2)}
  if(o.cross){const c=[shB[0],shB[1]+2.2];g.fillStyle='#efe6d2';g.fillRect(c[0]-1.9,c[1]-1.3,3.8,3.6);g.fillStyle='#c43a3a';g.fillRect(c[0]-.5,c[1]-.9,1,2.8);g.fillRect(c[0]-1.4,c[1]+.05,2.8,1)}
  if(front)gunArms(hand,sd,gl,shB,shF,body,nogun,bob,bp,o.weapon,o.swing);
  if(o.hp!==undefined&&o.hp<1){g.fillStyle='rgba(10,8,6,.8)';g.fillRect(-8,-41,16,2.6);g.fillStyle='#d65a3a';g.fillRect(-8,-41,16*Math.max(0,o.hp),2.6)}
  g.restore();
  if(o.tag)label(o.tag,sx,sy-46*u*BG,o.tagCol||'#a9bccb',BG>1?11:9);
}
function drawDowned(x,y,o,prog,tag){
  if(o.mark&&o.detail!==false){
    const [sx,sy]=iso(x,y);
    drawWardrobeCharacter(g,Object.assign({},o,{downed:true,nogun:true}),.7,game.time,u*FIG,sx,sy,0);
    label(tag,sx,sy-20*u,'#d65a3a',10);
    if(prog>0){g.strokeStyle='#a9bccb';g.lineWidth=3*u;g.beginPath();g.arc(sx,sy-10*u,10*u,-Math.PI/2,-Math.PI/2+Math.PI*2*prog);g.stroke()}
    return;
  }
  const [sx,sy]=iso(x,y);
  g.save();g.translate(sx,sy);g.scale(u*FIG,u*FIG);
  oval(0,0,13,5.5,'rgba(0,0,0,.38)');
  const ax=[.944,.33],pr=[-.33,.944],c=[0,-3],at=(a,p)=>[c[0]+ax[0]*a+pr[0]*p,c[1]+ax[1]*a+pr[1]*p];
  const pants=o.pants||'#3b372c';
  limb(at(-3,2),at(-10,2.6),pants,3.2);limb(at(-3,-2),at(-10,-1.6),pants,3.2);
  P([at(-3,5),at(7,5.8),at(7,-5.8),at(-3,-5)],o.body);
  P([at(-1,4),at(6,4.6),at(6,-4.6),at(-1,-4)],o.vest,false);
  const hc=at(11.5,0);disc(hc[0],hc[1],5.1,OUT);disc(hc[0],hc[1],4.3,o.head);
  if(o.helmet)P(domeP(hc[0],hc[1]-.4,5.2),o.helmet);
  g.restore();
  label(tag,sx,sy-20*u,'#d65a3a',10);
  if(prog>0){g.strokeStyle='#a9bccb';g.lineWidth=3*u;g.beginPath();g.arc(sx,sy-10*u,10*u,-Math.PI/2,-Math.PI/2+Math.PI*2*prog);g.stroke()}
}
/* ---------- boss effects: drawn over the night lighting so a warning is never lost in the dark ---------- */
function bossLine(x0,y0,x1,y1,z){const a=iso(x0,y0),b=iso(x1,y1);g.beginPath();g.moveTo(a[0],a[1]-z);g.lineTo(b[0],b[1]-z);g.stroke()}
function drawBossFx(){
  const ch=WH*.55,t=game.time,pulse=.55+.45*Math.sin(t*22);
  for(const f of fires){const c=iso(f.x,f.y),a=Math.min(1,f.t)*(.34+.1*Math.sin(t*9+f.x*3)),fr=(f.r||.9)/.9;g.fillStyle=`rgba(255,110,40,${a})`;g.beginPath();g.ellipse(c[0],c[1],TW2*.95*fr,TH2*.95*fr,0,0,Math.PI*2);g.fill()}
  // spotters: a red laser while they line up (st 1), solid with a mark over the soldier once they have them (st 2)
  for(const e of enemies){if(e.type!=='spotter'||!e.st)continue;const a=iso(e.x,e.y),b=iso(e.lx,e.ly);g.strokeStyle=e.st===2?'rgba(255,60,50,.75)':`rgba(255,60,50,${.25+.3*pulse})`;g.lineWidth=(e.st===2?1.3:.9)*u;
    g.beginPath();g.moveTo(a[0],a[1]-ch);g.lineTo(b[0],b[1]-ch);g.stroke();
    if(e.st===2){const y=b[1]-WH*1.9,s=5*u;g.fillStyle='#ff4a3a';g.beginPath();g.moveTo(b[0],y-s);g.lineTo(b[0]+s*.7,y);g.lineTo(b[0],y+s);g.lineTo(b[0]-s*.7,y);g.closePath();g.fill()}}
  for(const c of chains){const a=iso(c.x0,c.y0),b=iso(c.x1,c.y1),k=c.life/c.max;g.strokeStyle=`rgba(200,205,200,${k})`;g.lineWidth=2.2*u;g.setLineDash([4*u,2*u]);g.beginPath();g.moveTo(a[0],a[1]-ch);g.lineTo(b[0],b[1]-ch*.8);g.stroke();g.setLineDash([])}
  for(const e of enemies){if(e.type!=='boss'||!e.st)continue;const f=NET.mode==='guest'?(e.stF||0):Math.max(0,e.stT/e.stM);
    if(e.boss==='demolisher'){const a=Math.atan2(e.ly-e.y,e.lx-e.x),L=Math.hypot(e.lx-e.x,e.ly-e.y);
      g.setLineDash([7*u,5*u]);g.lineWidth=2.2*u;g.strokeStyle=`rgba(255,60,40,${.5+.45*pulse})`;
      for(const o of e.st===2?[-.3,0,.3]:[0]){const qx=e.x+Math.cos(a+o)*L,qy=e.y+Math.sin(a+o)*L,q=iso(qx,qy);bossLine(e.x,e.y,qx,qy,ch*1.2);
        g.beginPath();g.ellipse(q[0],q[1],TW2*1.5*(1.15-f*.15),TH2*1.5*(1.15-f*.15),0,0,Math.PI*2);g.stroke()}
      g.setLineDash([])}
    else if(e.boss==='butcher'&&e.st===1){const a0=Math.atan2(e.aim.y,e.aim.x);g.fillStyle=`rgba(255,50,40,${.18+.2*pulse})`;g.beginPath();const c0=iso(e.x,e.y);g.moveTo(c0[0],c0[1]);
      for(let k=0;k<=10;k++){const a=a0+(k/10-.5)*2.4,c=iso(e.x+Math.cos(a)*1.5,e.y+Math.sin(a)*1.5);g.lineTo(c[0],c[1])}g.closePath();g.fill()}
    else if(e.boss==='butcher'&&e.st===2){const dx=e.lx-e.x,dy=e.ly-e.y,l=Math.hypot(dx,dy)||1,nx=-dy/l*.45,ny=dx/l*.45,P=[[e.x+nx,e.y+ny],[e.lx+nx,e.ly+ny],[e.lx-nx,e.ly-ny],[e.x-nx,e.y-ny]].map(q=>iso(q[0],q[1]));
      g.fillStyle=`rgba(255,50,40,${.16+.22*pulse})`;g.strokeStyle=`rgba(255,80,60,${.6+.3*pulse})`;g.lineWidth=1.6*u;g.beginPath();P.forEach((q,i)=>i?g.lineTo(q[0],q[1]):g.moveTo(q[0],q[1]));g.closePath();g.fill();g.stroke()}
    else if(e.boss==='ferryman'&&e.st===1){g.setLineDash([3*u,4*u]);g.lineCap='round';g.lineWidth=2.2*u;g.strokeStyle=`rgba(95,214,196,${.5+.45*pulse})`;bossLine(e.x,e.y,e.lx,e.ly,ch);g.setLineDash([]);g.lineCap='butt';
      const q=iso(e.lx,e.ly);g.strokeStyle=`rgba(95,214,196,${.6+.3*pulse})`;g.lineWidth=1.6*u;g.beginPath();g.ellipse(q[0],q[1],TW2*.6,TH2*.6,0,0,Math.PI*2);g.stroke()}
    else if(e.boss==='ferryman'&&e.st===3){const row=Math.floor(e.ly);g.fillStyle=`rgba(255,60,40,${.18+.25*pulse})`;for(let i=0;i<N;i++)if(tAt(i,row)===T_BRIDGE)quad(iso(i,row),iso(i+1,row),iso(i+1,row+1),iso(i,row+1),g.fillStyle)}
    else if(e.boss==='foreman'&&e.st===1){const q=iso(e.lx,e.ly);g.strokeStyle=`rgba(255,177,58,${.55+.4*pulse})`;g.lineWidth=2*u;g.beginPath();g.ellipse(q[0],q[1],TW2*.95*(1.2-f*.2),TH2*.95*(1.2-f*.2),0,0,Math.PI*2);g.stroke()}
    else if(e.boss==='foreman'&&e.st===3){const dx=e.lx-e.x,dy=e.ly-e.y,l=Math.hypot(dx,dy)||1,nx=-dy/l*.5,ny=dx/l*.5,P=[[e.x+nx,e.y+ny],[e.lx+nx,e.ly+ny],[e.lx-nx,e.ly-ny],[e.x-nx,e.y-ny]].map(q=>iso(q[0],q[1]));
      g.fillStyle=`rgba(255,150,40,${.16+.22*pulse})`;g.strokeStyle=`rgba(255,177,58,${.6+.3*pulse})`;g.lineWidth=1.6*u;g.beginPath();P.forEach((q,i)=>i?g.lineTo(q[0],q[1]):g.moveTo(q[0],q[1]));g.closePath();g.fill();g.stroke()}
    else if(e.boss==='foreman'&&e.st===4){const q=iso(e.x,e.y);g.strokeStyle=`rgba(255,70,40,${.6+.4*pulse})`;g.lineWidth=2.4*u;g.beginPath();g.ellipse(q[0],q[1],TW2*1.4,TH2*1.4,0,0,Math.PI*2);g.stroke()}
    else if(e.boss==='storm'){const dx=e.lx-e.x,dy=e.ly-e.y,l=Math.hypot(dx,dy)||1,ex=clamp(e.x+dx/l*12,0,N),ey=clamp(e.y+dy/l*12,0,N),locked=f<.36;
      g.lineCap='round';g.strokeStyle=locked?`rgba(235,250,255,${.55+.45*pulse})`:'rgba(127,224,255,.7)';g.lineWidth=(1+2.4*(1-f))*u;bossLine(e.x,e.y,ex,ey,ch*1.2);g.lineCap='butt'}}
  for(const r of rockets){const c=iso(r.x,r.y),sd=wdirToScreen({x:r.vx,y:r.vy}),z=c[1]-ch,L=7*u;
    g.fillStyle='rgba(0,0,0,.35)';g.beginPath();g.ellipse(c[0],c[1],5*u,2.4*u,0,0,Math.PI*2);g.fill();
    g.lineCap='round';g.strokeStyle=OUT;g.lineWidth=5.4*u;g.beginPath();g.moveTo(c[0]-sd.x*L,z-sd.y*L);g.lineTo(c[0]+sd.x*L*.7,z+sd.y*L*.7);g.stroke();
    g.strokeStyle='#5d6450';g.lineWidth=3.6*u;g.stroke();g.lineCap='butt';
    g.globalCompositeOperation='lighter';const R=9*u*(1+.2*Math.sin(t*40));g.drawImage(SOFT.glow,c[0]-sd.x*L*1.3-R,z-sd.y*L*1.3-R,R*2,R*2);g.globalCompositeOperation='source-over'}
  g.globalCompositeOperation='lighter';g.lineCap='round';g.lineJoin='round';
  for(const zp of zaps){const a=zp.life/zp.max,P=zp.pts;
    for(let i=0;i+3<P.length;i+=2){const A=iso(P[i],P[i+1]),B=iso(P[i+2],P[i+3]),ax=A[0],ay=A[1]-ch*1.2,bx=B[0],by=B[1]-ch,d=Math.hypot(bx-ax,by-ay),n=Math.max(3,Math.round(d/(14*u))),nx=-(by-ay)/(d||1),ny=(bx-ax)/(d||1),pts=[[ax,ay]];
      for(let k=1;k<n;k++){const o=(rnd()-.5)*12*u;pts.push([ax+(bx-ax)*k/n+nx*o,ay+(by-ay)*k/n+ny*o])}pts.push([bx,by]);
      for(const[w,col]of[[8,`rgba(80,180,255,${.3*a})`],[3.4,`rgba(127,224,255,${.9*a})`],[1.4,`rgba(255,255,255,${a})`]]){g.strokeStyle=col;g.lineWidth=w*u;g.beginPath();pts.forEach((q,k)=>k?g.lineTo(q[0],q[1]):g.moveTo(q[0],q[1]));g.stroke()}}}
  for(const w of slashes){const a=w.life/w.max,a0=Math.atan2(w.ay,w.ax),sw=(1-a)*.6;g.strokeStyle=`rgba(255,235,220,${a})`;g.lineWidth=3*u;g.beginPath();
    for(let k=0;k<=12;k++){const an=a0-1.2+sw+(k/12)*2.4,c=iso(w.x+Math.cos(an)*1.35,w.y+Math.sin(an)*1.35);k?g.lineTo(c[0],c[1]-ch):g.moveTo(c[0],c[1]-ch)}g.stroke()}
  for(const r of rings){const t=1-r.life/r.max,e=1-Math.pow(1-t,2.2),rad=r.r0+(r.r1-r.r0)*e,c=iso(r.x,r.y);if(rad<=0)continue;
    g.globalAlpha=Math.min(1,r.life/r.max*1.6);g.strokeStyle=mix(r.c1,r.c2,t);g.lineWidth=r.w*u*(1-t*.5);g.beginPath();g.ellipse(c[0],c[1]-WH*.3,TW2*rad,TH2*rad,0,0,Math.PI*2);g.stroke()}
  g.globalAlpha=1;g.lineCap='butt';g.lineJoin='miter';g.globalCompositeOperation='source-over';
}
// a boss's name and health across the top of the screen
function drawBossBars(top){
  let y=Math.max(W<700?(hud.topB||top)+10:top+10,(hud.tipB||0)+10);for(const e of enemies){if(e.type!=='boss')continue;if(!BOSSES[e.boss])continue;const B=bossInfo(e.boss);
    const w=Math.min(440,W-48),x=(W-w)/2,f=Math.max(0,e.hp/e.max);
    g.fillStyle='rgba(12,10,8,.8)';g.fillRect(x-3,y-3,w+6,26);
    g.font='800 13px "Big Shoulders Stencil Display", "Arial Narrow", sans-serif';g.textAlign='left';g.fillStyle=B.col;g.fillText(B.name,x+2,y+10);
    g.textAlign='right';g.fillStyle='#dcd2ba';g.font='600 11px "IBM Plex Mono", monospace';g.fillText(`${Math.ceil(f*100)}%`,x+w-2,y+10);
    g.fillStyle='#2a2520';g.fillRect(x,y+14,w,6);g.fillStyle=B.col;g.fillRect(x,y+14,w*f,6);
    if(e.flash>0){g.fillStyle='rgba(255,255,255,.5)';g.fillRect(x,y+14,w*f,6)}
    y+=32}
  g.textAlign='center';
}
// the pump shotgun's tube, under your soldier: six shells, and LOADING while they go in
function drawShells(p){
  const G=p.gun;if(!G||!G.mag||!(p.ammo>=0))return;const c=iso(p.x,p.y),n=G.mag,sw=4*u,gap=2*u,x0=c[0]-(n*sw+(n-1)*gap)/2,y0=c[1]+9*u;
  for(let i=0;i<n;i++){const x=x0+i*(sw+gap),full=i<p.ammo;g.fillStyle='rgba(12,10,8,.75)';g.fillRect(x-1,y0-1,sw+2,8*u+2);
    if(full){g.fillStyle='#c23a2e';g.fillRect(x,y0,sw,5.4*u);g.fillStyle='#d8b25a';g.fillRect(x,y0+5.4*u,sw,2.6*u)}}
  if(p.rl>0&&p.ammo<n)label(p.ammo<=0?'RELOADING':'LOADING',c[0],y0+19*u,p.ammo<=0?'#ff6a4a':'#dcd2ba',9);
}
function drawGhost(t){
  const col=t.ok?'rgba(226,180,54,':'rgba(200,80,60,';
  const A=iso(t.i,t.j),B=iso(t.i+1,t.j),C=iso(t.i+1,t.j+1),D=iso(t.i,t.j+1);
  g.strokeStyle=col+'.9)';g.lineWidth=1.5*u;g.setLineDash([4*u,3*u]);g.beginPath();g.moveTo(A[0],A[1]);g.lineTo(B[0],B[1]);g.lineTo(C[0],C[1]);g.lineTo(D[0],D[1]);g.closePath();g.stroke();g.setLineDash([]);
  if(t.ok&&(t.act==='PLACE'||t.act==='DOOR')){g.globalAlpha=.32;const m=MAT[t.mat];const r=boxR(t.i+.03,t.j+.03,t.i+.97,t.j+.97,0,WH,m.top,m.l,m.r);if(t.door){doorSlab(r.D,r.C,WH,'#1d150e');doorSlab(r.C,r.B,WH,'#1d150e')}g.globalAlpha=1}
}
const QM_LOOK={body:'#9e9a78',vest:'#3d4a52',pants:'#3a3a33',head:'#b58f6e',cap:'#3d4a52',pack:'#5a4a30',gl:14,weapon:'sg'};
const LOOK={
  rifle:{body:'#7e3a2a',vest:'#3f231a',pants:'#2b2420',head:'#b08868',helmet:'#2f2820',bandana:'#a8342a'},
  gren:{body:'#6c5738',vest:'#2f261b',pants:'#2b2420',head:'#a98262',helmet:'#241f19',pack:'#3a2e1f',bandolier:true,bandana:'#a8342a',gl:17},
  breach:{body:'#5a2a22',vest:'#1f1512',pants:'#231c19',head:'#a07a5c',cap:'#1a1512',bandana:'#a8342a',nogun:true},
  // v0.9.0: each has one clear tell at a glance: the riot shield, the white medic kit, the red boonie and scope glint, the lit bottle
  shield:{body:'#3f4048',vest:'#23242a',pants:'#26262b',head:'#a98262',helmet:'#2a2b30',bandana:'#a8342a',gl:8,weapon:'shield'},
  medic:{body:'#6a5a48',vest:'#e8e2d0',pants:'#2b2420',head:'#b08868',helmet:'#e8e2d0',pack:'#e8e2d0',cross:true,gl:8},
  spotter:{body:'#4a4a36',vest:'#2a2a1e',pants:'#2b2420',head:'#a98262',boonie:'#8a2a22',bandana:'#a8342a',gl:8},
  fire:{body:'#6a3a1e',vest:'#2a1a10',pants:'#231c19',head:'#a07a5c',wrap:'#d06a1e',pack:'#3a2a1a',weapon:'bottle'}
};
// Render-only motion follows displacement, including remote snapshots. No input, simulation or wire fields change.
const PLAYER_PRESENTATION=new WeakMap();
function presentationMotion(p){
 if(!Number.isFinite(p.x)||!Number.isFinite(p.y))return {};
 const now=game.time;let m=PLAYER_PRESENTATION.get(p);
 if(!m||now<m.at||now-m.at>1){m={x:p.x,y:p.y,at:now,moved:now-1,weight:0,strength:0,phase:0,dx:0,dy:1};PLAYER_PRESENTATION.set(p,m)}
 const dt=now-m.at;
 if(dt>0){
  // Network interpolation approaches its target asymptotically. Tiny residual drift is not another full step.
  const dx=p.x-m.x,dy=p.y-m.y,d=Math.hypot(dx,dy),valid=d>Math.max(.0001,dt*.12)&&d<2;
  if(valid){m.phase=(m.phase+d*3)%(Math.PI*2);m.moved=now;m.strength=Math.min(1,d/dt/1.4);m.dx=dx/d;m.dy=dy/d}
  const target=p.downed||p.alive===false?0:now-m.moved<.085?m.strength:0;
  m.weight+=(target-m.weight)*(1-Math.exp(-dt/(target?.075:.085)));
  m.x=p.x;m.y=p.y;m.at=now;
 }
 const aim=p.aim||{x:0,y:1},dir=wardrobeAimAngle(wdirToScreen({x:m.dx,y:m.dy}))-wardrobeAimAngle(wdirToScreen(aim));
 return {walk:m.phase,gaitWeight:Math.round(m.weight*4)/4,gaitDir:Math.round(dir/(Math.PI/4))*Math.PI/4};
}
function playerLook(p){
  const cos=p.cos||DEFAULT_COS,C0=p.C||CLASSES[p.cls]||CLASSES.soldier,lk=cos.skin+'|'+cos.hat+'|'+C0.name;
  if(p._lk!==lk){p._lv=buildLook(p,cos);p._lk=lk}
  return Object.assign({},p._lv,presentationMotion(p));
}
function buildLook(p,cos){
  const S=SKINS[cos.skin]||SKINS.std;
  const o={body:S.body,vest:S.vest,pants:S.pants,head:S.head||'#c19a78',mark:'#e2b436',gl:14,stripe:S.stripe,glow:S.glow,shine:S.shine};
  for(const k of SKIN_FX)if(S[k]!==undefined)o[k]=S[k];
  const C=p.C||CLASSES[p.cls]||CLASSES.soldier;
  if(C.name==='SNIPER'){o.gl=19}else if(C.name==='GRENADIER'){o.pack='#4a3a26';o.bandolier=true;o.gl=15;o.weapon='sg'}
  else if(C.name==='QUARTERMASTER'){o.pack='#5a4a30';o.cross=true;o.gl=11}
  const H=headwearAllowed(cos.skin,cos.hat)?cos.hat:'class';
  if(H==='class'){if(C.name==='SNIPER')o.boonie=S.boonie||'#5b5a3c';else if(C.name==='QUARTERMASTER')o.cap=S.hat;else o.helmet=S.hat}
  else if(H==='cap')o.cap=S.hat;else if(H==='boonie')o.boonie=S.boonie||'#5b5a3c';else if(H==='beanie')o.beanie='#6b2f2a';
  else if(H==='beret')o.beret='#7a1f24';else if(H==='wrap')o.wrap='#a8342a';else if(H==='tophat')o.tophat='#1c1a1a';else if(H==='crown')o.crown='#e2c25a';
  else if(H==='headband')o.headband='#ff3a6a';else if(H==='acap'){o.cap='#e2427f';o.capPix='#ffe03a'}else if(H==='nhelm'){o.helmet='#1b1e26';o.hneon='#2af5ff'}
  else if(H==='pcap')o.pcap='#1a2240';else if(H==='ledmask')o.mask='#ff3a3a';else if(H==='visor')o.visor='#ff2a8a';else if(H==='clownhair')o.hair='#ff3ad0';
  else if(H==='halo')o.halo='#fff0a0';else if(H==='glitch')o.glitchm=true;else if(H==='gclownhair'){o.hair='#f0cf5c';o.hairGold=true}else if(H==='ghelm')o.khelm='#e6c65c';
  else if(H==='jackolantern')o.pumpkin='#e8771e';else if(H==='pumpkinking'){o.pumpkin='#c9561a';o.pking=true}else if(H==='witch')o.witch='#241a30';
  else if(H==='officer'){o.pcap='#34402c';o.pbraid='#e2c25a'}else if(H==='ghood')o.ghood='#55642e';else if(H==='bombhelm')o.bomb='#3e4a38';else if(H==='qmset'){o.cap='#3d4a52';o.headset=true}   // v0.9.3 class rewards
  else if(HALLOWEEN_HATS[H])o.halloweenHat=H;
  else o.helmet=S.hat;
  if(S.headwear&&H==='class'){delete o.helmet;delete o.cap;delete o.boonie;Object.assign(o,S.headwear)}   // v0.9.3: the outfit's own hat (a hard hat, a straw hat…)
  if(S.reaper&&H==='class'){delete o.helmet;delete o.cap;delete o.boonie;o.hood=S.body}
  else if((S.bones||S.wraps||S.phantom)&&H==='class'){delete o.helmet;delete o.cap;delete o.boonie}   // the face is the point: no default headgear
  if(p.slot)o.mark=SLOTCOL[p.slot%6];
  return o;
}

