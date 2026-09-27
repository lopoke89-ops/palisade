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
// bp: bolt-action phase after a shot (0 = just fired, 1 = bolt home), or -1 for none
// kind: '' rifle/carbine, 'sg' pump shotgun (the fore-end slides back on each pump), 'rpg' launcher tube,
// 'zap' lightning rifle, 'sword' (swing: 0 rest, 1 wind-up, 2 charge wind-up, 3 charging)
function gunArms(hand,sd,gl,shB,shF,sleeve,nogun,bob,bp=-1,kind='',swing=0){
  if(nogun){limb(shB,[shB[0],-13.5+bob],sleeve,2.6);limb(shF,[shF[0],-13.5+bob],sleeve,2.6);return}
  if(kind==='sword'){
    const sx=sd.x>=0?1:-1,a=swing===1?Math.atan2(-1,sx*.35):swing===2?Math.atan2(-.35,sx):swing===3?Math.atan2(sd.y,sd.x):Math.atan2(sd.y+.7,sd.x),c=Math.cos(a),n=Math.sin(a);
    limb(shB,hand,sleeve,2.6);limb(shF,hand,sleeve,2.6);
    const tip=[hand[0]+c*25,hand[1]+n*25],base=[hand[0]+c*2,hand[1]+n*2];
    if(swing===1||swing===2){g.globalAlpha=.55;seg(base,tip,'#ff4a32',6);g.globalAlpha=1}
    seg([hand[0]-c*4,hand[1]-n*4],base,OUT,3.4);seg([hand[0]-c*4,hand[1]-n*4],base,'#3a2a1a',2);
    seg(base,tip,OUT,3.8);seg(base,tip,'#d9dee0',2.2);seg([base[0]+c*6,base[1]+n*6],tip,'#ffffff',.7);
    seg([base[0]-n*4,base[1]+c*4],[base[0]+n*4,base[1]-c*4],OUT,2.8);seg([base[0]-n*3.4,base[1]+c*3.4],[base[0]+n*3.4,base[1]-c*3.4],'#8a6a36',1.6);return}
  let kb=0,pull=0;
  if(bp>=0){kb=bp<.2?(1-bp/.2)*2.6:0;if(bp>.24&&bp<.9)pull=Math.sin((bp-.24)/.66*Math.PI)}
  const lift=kind==='sg'?kb*.5:pull*2.4+kb*.5,at=k=>[hand[0]+sd.x*(k-kb),hand[1]+sd.y*(k-kb)-lift*Math.max(0,k+5)/(gl+5)];
  const stock=at(-5),muz=at(gl),mid=at(gl*.55),mg=at(2.2);
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
// A soldier, raider or Dell standing at tile (x,y), facing o.aim. Drawn in base pixels, scaled.
function drawPerson(x,y,o){
  const [sx,sy]=iso(x,y),BG=o.big||1;
  g.save();g.translate(sx,sy);g.scale(u*FIG*BG,u*FIG*BG);
  const walk=o.walk||0,bob=-Math.abs(Math.sin(walk))*1.1;
  const sd=wdirToScreen(o.aim),side=sd.x>=0?1:-1,front=sd.y>=-.15,lit=o.flash;
  const skin=lit?LIT:o.head,body=lit?LIT:o.body,vest=o.vest,pants=o.pants||'#3b372c',gl=o.gl||14,nogun=!!o.nogun;
  if(o.faded)g.globalAlpha=.5;
  if(o.holo)g.globalAlpha*=.66+.18*Math.sin(game.time*9)-(rnd()<.05?.3:0);   // hologram: flickers
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
  if(o.bandolier){seg([-5.2*side,-23.5+bob],[4.6*side,-13+bob],'#1d1914',2.6);seg([-5.2*side,-23.5+bob],[4.6*side,-13+bob],'#8a6a36',1.6)}
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
  seg([-4.8,-12.2+bob],[4.8,-12.2+bob],'#1d1914',1.8);
  if(o.mark){g.fillStyle=o.mark;g.fillRect(shF[0]-1.3,shF[1]+.8,2.6,2.4)}
  if(o.satchel){const c=[side*5.5,-14+bob];P(rectP(c[0],c[1],6,5),'#1a1510');g.fillStyle='#d65a3a';g.fillRect(c[0]-1,c[1]-1,2,1.5)}
  if(o.pack&&!front){P(rectP(0,-18.5+bob,11,10),o.pack);seg([-5.5,-21.5+bob],[5.5,-21.5+bob],OUT,1)}
  const hx=side*.4,hy2=-28.8+bob;
  disc(hx,hy2,5.3,OUT);disc(hx,hy2,4.5,front?skin:dark(skin,.3));
  if(front){g.fillStyle=OUT;g.fillRect(hx-1.9+side*1.2,hy2-.9,1.1,1.3);g.fillRect(hx+.9+side*1.2,hy2-.9,1.1,1.3);
    if(o.bandana)P(rectP(hx+side*.4,hy2+2.3,8.2,3.6),o.bandana)}
  if(o.helmet){P(domeP(hx,hy2-.4,5.4),o.helmet);seg([hx-6.2,hy2-.3],[hx+6.2,hy2-.3],OUT,1.6);if(o.hneon){neonSeg([hx-4.8,hy2-2.6],[hx+4.8,hy2-2.6],o.hneon);neonSeg([hx,hy2-5.6],[hx,hy2-2.6],o.hneon)}}
  else if(o.beanie){P(domeP(hx,hy2-.2,5.2),o.beanie);g.fillStyle=dark(o.beanie,.3);g.fillRect(hx-5.2,hy2-1.6,10.4,2.2);disc(hx,hy2-6,1.7,OUT);disc(hx,hy2-6,1.2,o.beanie)}
  else if(o.beret){P([[hx-5.6,hy2-1.6],[hx-2,hy2-5],[hx+4.6,hy2-4.4],[hx+6.6,hy2-2.2],[hx+4.8,hy2-1]],o.beret);disc(hx+.5,hy2-4.6,.9,dark(o.beret,.4))}
  else if(o.wrap){P(domeP(hx,hy2-.3,5),o.wrap);seg([hx-side*4.4,hy2-.6],[hx-side*7.4,hy2+2.8],OUT,2.6);seg([hx-side*4.4,hy2-.6],[hx-side*7.4,hy2+2.8],o.wrap,1.4)}
  else if(o.tophat){P(rectP(hx,hy2-2.6,12.4,2),o.tophat);P(rectP(hx,hy2-8.4,7.8,10),o.tophat);g.fillStyle='#8a2a2a';g.fillRect(hx-3.9,hy2-5.2,7.8,1.6)}
  else if(o.crown){P([[hx-5,hy2-1.8],[hx-5.2,hy2-7.4],[hx-2.6,hy2-4.6],[hx,hy2-8.6],[hx+2.6,hy2-4.6],[hx+5.2,hy2-7.4],[hx+5,hy2-1.8]],o.crown);disc(hx,hy2-4,1,'#c43a4a')}
  else if(o.cap){P(domeP(hx,hy2-.8,4.9),o.cap);P([[hx+side*2,hy2-1.6],[hx+side*7.6,hy2-.9],[hx+side*7,hy2+.5],[hx+side*1.6,hy2]],dark(o.cap,.25));if(o.capPix&&front){g.fillStyle=o.capPix;g.fillRect(hx+side*1.2-1,hy2-4.4,2,2);g.fillRect(hx+side*1.2+1,hy2-2.4,1,1)}}
  else if(o.boonie){oval(hx,hy2-1.6,8.2,2.6,OUT);oval(hx,hy2-1.6,7.4,2,o.boonie);P(domeP(hx,hy2-1.8,4.4),dark(o.boonie,.12))}
  else if(o.pcap){P(rectP(hx,hy2-3.9,10.6,3.8),o.pcap);P([[hx-5.4,hy2-2.2],[hx+5.4,hy2-2.2],[hx+side*7.4,hy2-.4],[hx-side*.8,hy2-.8]],dark(o.pcap,.35));disc(hx+side*1.6,hy2-4,1.3,OUT);disc(hx+side*1.6,hy2-4,.9,'#e2c25a')}
  else if(o.khelm){P(domeP(hx,hy2-.4,5.9),o.khelm);P(rectP(hx,hy2+1.3,11.4,5.6),o.khelm);
    if(front){g.fillStyle=OUT;g.fillRect(hx-4.2+side*.6,hy2-.8,8.4,1.4);for(const d of[-1.6,0,1.6])g.fillRect(hx+side*2+d-.35,hy2+1.6,.7,1.6)}
    seg([hx,hy2-6.2],[hx,hy2-1],dark(o.khelm,.3),.9);P([[hx-1.1,hy2-5.8],[hx+1.1,hy2-5.8],[hx+side*.6,hy2-10]],dark(o.khelm,.12));
    g.globalAlpha=A0*.6;seg([hx-3.4,hy2-4.6],[hx-4.4,hy2+3],'#fff6c8',.9);g.globalAlpha=A0}
  else if(o.hair){for(const[dx,dy,r]of[[-5.4,-1.6,3.2],[5.4,-1.6,3.2],[-2.8,-5.2,2.9],[2.8,-5.2,2.9],[0,-6.6,2.7]]){disc(hx+dx,hy2+dy,r+.8,OUT);disc(hx+dx,hy2+dy,r,o.hair)}
    if(o.hairGold){g.globalAlpha=A0*.8;for(const[dx,dy]of[[-6.2,-2.8],[1.8,-6.4],[4.6,-2.6]])disc(hx+dx,hy2+dy,.8,'#fffbe0');g.globalAlpha=A0}}
  else if(o.halo){const yy=hy2-9+Math.sin(game.time*2.4)*.7;g.globalAlpha=A0*.4;g.strokeStyle=o.halo;g.lineWidth=3.4;g.beginPath();g.ellipse(hx,yy,6.2,1.9,0,0,Math.PI*2);g.stroke();
    g.globalAlpha=A0;g.lineWidth=1.3;g.beginPath();g.ellipse(hx,yy,6.2,1.9,0,0,Math.PI*2);g.stroke();const a=game.time*3;disc(hx+Math.cos(a)*6.2,yy+Math.sin(a)*1.9,.9,'#ffffff')}
  else if(o.glitchm){const f=Math.floor(game.time*10),jx=(f%7===0)?1.4:0,C5=['#ff3a6a','#3affd8','#6a8aff','#ffe03a','#f3f0ff'];
    for(let a=0;a<3;a++)for(let b=0;b<3;b++){g.fillStyle=C5[(f+a*3+b*7)%5];g.fillRect(hx-4.6+a*3.1+(b===1?jx:0),hy2-4.8+b*3.1,3.1,3.1)}}
  else if(o.mask){if(front){disc(hx,hy2+.3,4.6,'#15151a');const bl=Math.sin(game.time*2.6)>.96;if(!bl){g.fillStyle=o.mask;g.fillRect(hx-2.8+side*1.1,hy2-1.4,1.8,1.2);g.fillRect(hx+1+side*1.1,hy2-1.4,1.8,1.2)}}
    seg([hx-4.8,hy2-1.2],[hx+4.8,hy2-1.2],'#15151a',1)}
  else if(o.visor){P(rectP(hx+side*.5,hy2-.9,10.4,2.8),'#101014');neonSeg([hx-4.4+side*.5,hy2-.9],[hx+4.4+side*.5,hy2-.9],o.visor)}
  else if(o.headband){neonSeg([hx-5,hy2-2.2],[hx+5,hy2-2.2],o.headband);seg([hx-side*4.8,hy2-2.2],[hx-side*7.8,hy2+.6],o.headband,1.2)}
  if(o.cross){const c=[shB[0],shB[1]+2.2];g.fillStyle='#efe6d2';g.fillRect(c[0]-1.9,c[1]-1.3,3.8,3.6);g.fillStyle='#c43a3a';g.fillRect(c[0]-.5,c[1]-.9,1,2.8);g.fillRect(c[0]-1.4,c[1]+.05,2.8,1)}
  if(front)gunArms(hand,sd,gl,shB,shF,body,nogun,bob,bp,o.weapon,o.swing);
  if(o.hp!==undefined&&o.hp<1){g.fillStyle='rgba(10,8,6,.8)';g.fillRect(-8,-41,16,2.6);g.fillStyle='#d65a3a';g.fillRect(-8,-41,16*Math.max(0,o.hp),2.6)}
  g.restore();
  if(o.tag)label(o.tag,sx,sy-46*u*BG,o.tagCol||'#a9bccb',BG>1?11:9);
}
function drawDowned(x,y,o,prog,tag){
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
  for(const f of fires){const c=iso(f.x,f.y),a=Math.min(1,f.t)*(.34+.1*Math.sin(t*9+f.x*3));g.fillStyle=`rgba(255,110,40,${a})`;g.beginPath();g.ellipse(c[0],c[1],TW2*.95,TH2*.95,0,0,Math.PI*2);g.fill()}
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
  let y=Math.max(W<700?(hud.topB||top)+10:top+10,(hud.tipB||0)+10);for(const e of enemies){if(e.type!=='boss')continue;const B=BOSSES[e.boss];if(!B)continue;
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
  breach:{body:'#5a2a22',vest:'#1f1512',pants:'#231c19',head:'#a07a5c',cap:'#1a1512',bandana:'#a8342a',nogun:true}
};
function playerLook(p){
  const cos=p.cos||DEFAULT_COS,C0=p.C||CLASSES[p.cls]||CLASSES.soldier,lk=cos.skin+'|'+cos.hat+'|'+C0.name;
  if(p._lk!==lk){p._lv=buildLook(p,cos);p._lk=lk}
  return Object.assign({},p._lv);
}
function buildLook(p,cos){
  const S=SKINS[cos.skin]||SKINS.std;
  const o={body:S.body,vest:S.vest,pants:S.pants,head:'#c19a78',mark:'#e2b436',gl:14,stripe:S.stripe,glow:S.glow,shine:S.shine};
  for(const k of SKIN_FX)if(S[k]!==undefined)o[k]=S[k];
  const C=p.C||CLASSES[p.cls]||CLASSES.soldier;
  if(C.name==='SNIPER'){o.gl=19}else if(C.name==='GRENADIER'){o.pack='#4a3a26';o.bandolier=true;o.gl=15;o.weapon='sg'}
  else if(C.name==='QUARTERMASTER'){o.pack='#5a4a30';o.cross=true;o.gl=11}
  const H=cos.hat;
  if(H==='class'){if(C.name==='SNIPER')o.boonie=S.boonie||'#5b5a3c';else if(C.name==='QUARTERMASTER')o.cap=S.hat;else o.helmet=S.hat}
  else if(H==='cap')o.cap=S.hat;else if(H==='boonie')o.boonie=S.boonie||'#5b5a3c';else if(H==='beanie')o.beanie='#6b2f2a';
  else if(H==='beret')o.beret='#7a1f24';else if(H==='wrap')o.wrap='#a8342a';else if(H==='tophat')o.tophat='#1c1a1a';else if(H==='crown')o.crown='#e2c25a';
  else if(H==='headband')o.headband='#ff3a6a';else if(H==='acap'){o.cap='#e2427f';o.capPix='#ffe03a'}else if(H==='nhelm'){o.helmet='#1b1e26';o.hneon='#2af5ff'}
  else if(H==='pcap')o.pcap='#1a2240';else if(H==='ledmask')o.mask='#ff3a3a';else if(H==='visor')o.visor='#ff2a8a';else if(H==='clownhair')o.hair='#ff3ad0';
  else if(H==='halo')o.halo='#fff0a0';else if(H==='glitch')o.glitchm=true;else if(H==='gclownhair'){o.hair='#f0cf5c';o.hairGold=true}else if(H==='ghelm')o.khelm='#e6c65c';
  else o.helmet=S.hat;
  if(p.slot)o.mark=SLOTCOL[p.slot%6];
  return o;
}

