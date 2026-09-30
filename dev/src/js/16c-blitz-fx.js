/* ---------- v0.9.4.0: Blitzkrieg Rush on screen: the evac site, the variants' warnings, arcs and napalm ---------- */
// all of it is drawn with the boss effects (over the night lighting), so a warning or the evac ring is never lost in the dark
function drawEvacGround(t){
  const F=game.fb,E=F&&F.evac;if(!E||F.done)return;const c=iso(E.x,E.y),rx=TW2*E.r,ry=TH2*E.r,p=.5+.5*Math.sin(t*4);
  g.fillStyle=`rgba(90,255,140,${.1+.06*p})`;g.beginPath();g.ellipse(c[0],c[1],rx,ry,0,0,Math.PI*2);g.fill();
  g.setLineDash([9*u,6*u]);g.lineDashOffset=-t*30*u;g.strokeStyle=`rgba(138,255,154,${.65+.3*p})`;g.lineWidth=2.6*u;g.beginPath();g.ellipse(c[0],c[1],rx,ry,0,0,Math.PI*2);g.stroke();g.setLineDash([]);g.lineDashOffset=0;
  g.strokeStyle='rgba(138,255,154,.35)';g.lineWidth=1.2*u;g.beginPath();g.ellipse(c[0],c[1],rx*(.55+.1*p),ry*(.55+.1*p),0,0,Math.PI*2);g.stroke();
  // the flare: a light column and a glow
  const h=WH*5;const gr=g.createLinearGradient(0,c[1]-h,0,c[1]);gr.addColorStop(0,'rgba(138,255,154,0)');gr.addColorStop(1,`rgba(138,255,154,${.22+.1*p})`);g.fillStyle=gr;g.fillRect(c[0]-5*u,c[1]-h,10*u,h);
  g.globalCompositeOperation='lighter';const R=16*u*(1+.15*p);g.drawImage(SOFT.glow,c[0]-R,c[1]-R*.9-4*u,R*2,R*2);g.globalCompositeOperation='source-over';
  g.fillStyle='#d8ffe0';g.fillRect(c[0]-1.5*u,c[1]-7*u,3*u,6*u);
}
function drawNapalm(f,c,a,fr,t){
  const k=a*1.25,w=Math.sin(t*13+f.x*5)*.06;
  g.fillStyle=`rgba(120,20,8,${Math.min(.6,k)})`;g.beginPath();g.ellipse(c[0],c[1],TW2*1.02*fr,TH2*1.02*fr,0,0,Math.PI*2);g.fill();
  g.fillStyle=`rgba(255,80,20,${Math.min(.7,k*.9)})`;g.beginPath();g.ellipse(c[0],c[1],TW2*(.78+w)*fr,TH2*(.78+w)*fr,0,0,Math.PI*2);g.fill();
  g.fillStyle=`rgba(255,196,80,${Math.min(.6,k*.7)})`;g.beginPath();g.ellipse(c[0],c[1]-1*u,TW2*.36*fr,TH2*.36*fr,0,0,Math.PI*2);g.fill();
  if(rnd()<.05)ambient(f.x+(rnd()-.5)*.8,f.y+(rnd()-.5)*.8,WH*.4,'smoke');   // black smoke off the napalm
}
const laneQuad=(x0,y0,x1,y1,hw)=>{const dx=x1-x0,dy=y1-y0,l=Math.hypot(dx,dy)||1,nx=-dy/l*hw,ny=dx/l*hw;return[[x0+nx,y0+ny],[x1+nx,y1+ny],[x1-nx,y1-ny],[x0-nx,y0-ny]].map(q=>iso(q[0],q[1]))};
function fillQuad(P,fill,stroke,w){g.fillStyle=fill;g.beginPath();P.forEach((q,i)=>i?g.lineTo(q[0],q[1]):g.moveTo(q[0],q[1]));g.closePath();g.fill();if(stroke){g.strokeStyle=stroke;g.lineWidth=w*u;g.stroke()}}
// true when this variant's state has its own warning (otherwise the base boss's drawing is used)
function drawBlitzFx(e,f,pulse,ch){
  const k=e.boss;
  if(k==='harbinger'&&e.st===1){const q=iso(e.lx,e.ly);g.setLineDash([6*u,5*u]);g.lineWidth=1.8*u;g.strokeStyle=`rgba(255,122,58,${.45+.4*pulse})`;bossLine(e.x,e.y,e.lx,e.ly,ch*1.4);g.setLineDash([]);
    for(const s of[1.6,.9]){g.beginPath();g.ellipse(q[0],q[1],TW2*s*(1.2-f*.2),TH2*s*(1.2-f*.2),0,0,Math.PI*2);g.stroke()}return true}
  if(k==='bluebutcher'&&e.st===5){fillQuad(laneQuad(e.x,e.y,e.lx,e.ly,.42),`rgba(58,224,224,${.14+.2*pulse})`,`rgba(90,240,255,${.55+.35*pulse})`,1.6);return true}
  if(k==='arsonist'&&e.st===1){g.setLineDash([7*u,5*u]);g.lineWidth=2*u;g.strokeStyle=`rgba(255,90,26,${.5+.45*pulse})`;bossLine(e.x,e.y,e.lx,e.ly,ch*1.2);g.setLineDash([]);
    for(let n=0;n<4;n++){const fr=.5+n*.18,q=iso(e.x+(e.lx-e.x)*fr,e.y+(e.ly-e.y)*fr);g.beginPath();g.ellipse(q[0],q[1],TW2*(1.12-f*.12),TH2*(1.12-f*.12),0,0,Math.PI*2);g.stroke()}return true}
  if(k==='tempest'&&e.st){const[nx,ny]=twinOff(e),locked=f<.36;g.lineCap='round';g.strokeStyle=locked?`rgba(235,250,255,${.55+.45*pulse})`:'rgba(127,224,255,.7)';g.lineWidth=(1+2.4*(1-f))*u;
    for(const s of[-1,1]){const x0=e.x+nx*s,y0=e.y+ny*s,dx=e.lx-e.x,dy=e.ly-e.y,l=Math.hypot(dx,dy)||1;bossLine(x0,y0,clamp(x0+dx/l*12,0,N),clamp(y0+dy/l*12,0,N),ch*1.2)}g.lineCap='butt';return true}
  if(k==='bulldozer'){if(e.st===1||e.st===2){const P=laneQuad(e.x,e.y,e.lx,e.ly,.52);fillQuad(P,`rgba(255,210,58,${.12+.2*pulse})`,`rgba(255,210,58,${.6+.3*pulse})`,1.8);
      g.save();g.beginPath();P.forEach((q,i)=>i?g.lineTo(q[0],q[1]):g.moveTo(q[0],q[1]));g.closePath();g.clip();g.strokeStyle='rgba(30,26,20,.35)';g.lineWidth=5*u;
      const a=iso(e.x,e.y),b=iso(e.lx,e.ly),L=Math.hypot(b[0]-a[0],b[1]-a[1]);for(let d=0;d<L;d+=14*u){const x=a[0]+(b[0]-a[0])*d/L,y=a[1]+(b[1]-a[1])*d/L;g.beginPath();g.moveTo(x-8*u,y+6*u);g.lineTo(x+8*u,y-6*u);g.stroke()}g.restore()}
    return true}
  return false;
}
// the Blue Butcher's arcs: a glowing crescent side-on to where it's going (composite is already 'lighter' here)
function drawArcs(t,ch){
  for(const r of arcs){const c=iso(r.x,r.y),sd=wdirToScreen({x:r.vx,y:r.vy}),nx=-sd.y,ny=sd.x,z=c[1]-ch,L=16*u;
    for(const[w,col]of[[9,'rgba(40,200,220,.28)'],[4.5,'rgba(90,240,255,.85)'],[1.6,'rgba(235,255,255,1)']]){g.strokeStyle=col;g.lineWidth=w*u;g.beginPath();
      for(let s=0;s<=10;s++){const q=s/10-.5,bend=(1-4*q*q)*7*u;const x=c[0]+nx*L*q*2+sd.x*bend,y=z+ny*L*q*2+sd.y*bend;s?g.lineTo(x,y):g.moveTo(x,y)}g.stroke()}
    const R=14*u;g.drawImage(SOFT.glow,c[0]-R,z-R,R*2,R*2)}
}
function drawDazed(e){const c=iso(e.x,e.y),y=c[1]-WH*2.3,t=game.time*5;
  for(let n=0;n<3;n++){const a=t+n*2.094,x=c[0]+Math.cos(a)*11*u,yy=y+Math.sin(a)*3.5*u,s=3.2*u;g.fillStyle='#ffe066';g.beginPath();
    for(let q=0;q<10;q++){const r=q%2?s*.45:s,an=q*Math.PI/5-Math.PI/2;g.lineTo(x+Math.cos(an)*r,yy+Math.sin(an)*r)}g.closePath();g.fill()}}
// over the world: an arrow to the evac site when it's off screen, and a fill ring over anyone standing in it
function drawEvacHud(){
  const F=game.fb,E=F&&F.evac;if(!E||F.done)return;const top=110;
  for(const p of players.values()){if(!p.alive||!(p.ev>0)||p.out)continue;const c=iso(p.x,p.y),k=Math.min(1,p.ev/BLITZ.hold),y=c[1]-WH*2.2;
    g.strokeStyle='rgba(12,10,8,.7)';g.lineWidth=5*u;g.beginPath();g.arc(c[0],y,11*u,0,Math.PI*2);g.stroke();
    g.strokeStyle='#8aff9a';g.lineWidth=3*u;g.beginPath();g.arc(c[0],y,11*u,-Math.PI/2,-Math.PI/2+Math.PI*2*k);g.stroke()}
  const me=player;if(!me||me.out)return;
  const c=iso(E.x,E.y);if(c[0]>20&&c[0]<W-20&&c[1]>top&&c[1]<H-20)return;
  const ex=clamp(c[0],26,W-26),ey=clamp(c[1],top+14,H-26),a=Math.atan2(c[1]-H/2,c[0]-W/2),p=.8+.2*Math.sin(game.time*6);
  g.save();g.translate(ex,ey);g.rotate(a);g.scale(1.9*p,1.9*p);g.fillStyle='#8aff9a';g.strokeStyle='rgba(12,10,8,.8)';g.lineWidth=1.5;g.beginPath();g.moveTo(9,0);g.lineTo(-5,-7);g.lineTo(-2,0);g.lineTo(-5,7);g.closePath();g.stroke();g.fill();g.restore();
  label('EVAC',ex,ey+(ey>H/2?-20:24),'#8aff9a',10);
}
// the camera, once you're out: the nearest teammate still down there, else the evac site
function spectateTarget(p){let best=null,bd=1e9;for(const o of players.values())if(o!==p&&(o.alive||o.downed)&&!o.out){const d=dist2(o,p);if(d<bd){bd=d;best=o}}
  const E=game.fb&&game.fb.evac;return best?{x:best.x,y:best.y}:E?{x:E.x,y:E.y}:{x:p.x,y:p.y}}
// lobbed Blitzkrieg shots in flight: the Harbinger's missile (3), the Arsonist's napalm bottle (4), a Barrage shell (5)
function drawBlitzLob(l,c,z,t){
  if(l.k===4){g.fillStyle='#5a2a10';g.fillRect(c[0]-2*u,c[1]-z-3*u,4*u,6*u);g.fillStyle='#ff5a1a';g.beginPath();g.arc(c[0],c[1]-z-4.5*u,2.2*u+Math.sin(game.time*30)*.6*u,0,Math.PI*2);g.fill();return}
  const dz=Math.cos(Math.PI*t),a=Math.atan2(-dz*1.4,1),sx=l.x1>=l.x0?1:-1,L=6*u,cx=c[0],cy=c[1]-z,ux=Math.cos(a)*sx,uy=Math.sin(a);
  g.lineCap='round';g.strokeStyle=OUT;g.lineWidth=4.6*u;g.beginPath();g.moveTo(cx-ux*L,cy-uy*L);g.lineTo(cx+ux*L,cy+uy*L);g.stroke();
  g.strokeStyle=l.k===3?'#6a6258':'#4a4a40';g.lineWidth=3*u;g.stroke();g.fillStyle=l.k===3?'#ff7a3a':'#d8c090';g.beginPath();g.arc(cx+ux*L,cy+uy*L,1.6*u,0,Math.PI*2);g.fill();g.lineCap='butt';
  g.globalCompositeOperation='lighter';const R=7*u*(1+.25*Math.sin(game.time*40));g.drawImage(SOFT.glow,cx-ux*L*1.4-R,cy-uy*L*1.4-R,R*2,R*2);g.globalCompositeOperation='source-over';
  if(rnd()<.35)ambient(l.x0+(l.x1-l.x0)*t,l.y0+(l.y1-l.y0)*t,z,"smoke");
}
