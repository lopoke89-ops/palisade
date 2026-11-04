/* v0.12 THE UNDERSTRIP CASE: kill effects and tracer decorations. The kill effects are fixed geometry on the shared finish
   timeline (as the Winter and Hybrid Theory finishes are): every piece is placed from the progress value, so nothing
   accumulates and the case reel's per-effect budget holds. Abducted is the gold showpiece. Generic 7s, no slot brand. */
Object.assign(FINISH_LIFE,{bust:.95,plumes:1,jackpot:1.15,dissolved:1.1,abducted:1.3});
const US_FX_KEYS=new Set(US_FX.map(f=>f[0]));
function paintUsFinish(c,key,p,s,x,y){
  if(!US_FX_KEYS.has(key))return false;if(p<0||p>=1)return true;
  const e=1-(1-p)**3,fade=Math.min(1,p*12,(1-p)*3),ink='#0b1111',tau=Math.PI*2;
  c.save();c.translate(x,y);c.scale(s,s);c.globalAlpha*=fade;c.lineJoin='round';c.lineCap='round';
  const ground=(col,r,a=.35)=>{c.fillStyle=col;c.globalAlpha*=a;c.beginPath();c.ellipse(0,6,r,r*.35,0,0,tau);c.fill();c.globalAlpha/=a};
  const blob=(xx,yy,r,col)=>{c.fillStyle=col;c.beginPath();c.arc(xx,yy,r,0,tau);c.fill()};
  const card=(xx,yy,rot,face,suit)=>{c.save();c.translate(xx,yy);c.rotate(rot);const fw=Math.abs(Math.cos(face*Math.PI))*5;c.fillStyle=face<.5?'#f4f0e6':'#a8202a';c.strokeStyle=ink;c.lineWidth=.6;c.fillRect(-fw/2,-3.6,fw,7.2);c.strokeRect(-fw/2,-3.6,fw,7.2);
    if(face<.5&&fw>2){c.fillStyle=suit%2?'#c42a3a':'#141414';c.font='700 4px sans-serif';c.textAlign='center';c.textBaseline='middle';c.fillText(['♠','♥','♣','♦'][suit%4],0,0)}else if(fw>2){c.strokeStyle='#f4dc7a';c.strokeRect(-fw/2+1,-2.6,fw-2,5.2)}c.restore()};
  switch(key){
    case'bust':{ground('#a8202a',8+e*8);for(let i=0;i<7;i++){const a=i*tau/7+.4,r=4+e*16,xx=Math.cos(a)*r,yy=Math.sin(a)*r*.5-14*Math.sin(Math.min(1,p*1.6)*Math.PI)+p*6;card(xx,yy,a+p*5,Math.min(1,Math.max(0,(p-.35)*2.2)),i)}break}   // cards scatter, then flip face down
    case'plumes':{ground('#ff5ad8',8+e*9);for(let i=0;i<9;i++){const a=i*tau/9,r=3+e*18,xx=Math.cos(a)*r+Math.sin(p*6+i)*2,yy=Math.sin(a)*r*.5-e*12+p*p*16;c.save();c.translate(xx,yy);c.rotate(a+Math.sin(p*5+i));
        c.fillStyle=i%2?'#ffd0f0':'#ff8ad8';c.beginPath();c.ellipse(0,0,1.4,5,0,0,tau);c.fill();c.strokeStyle='rgba(255,255,255,.7)';c.lineWidth=.4;c.beginPath();c.moveTo(0,-5);c.lineTo(0,5);c.stroke();c.restore()}
      for(let i=0;i<12;i++){const a=i*2.1,r=2+e*22*hash(i,3),xx=Math.cos(a)*r,yy=Math.sin(a)*r*.5-e*16+p*p*20;blob(xx,yy,.8,['#ffe39a','#e6f0ff','#ff5ad8'][i%3])}break}   // sequins
    case'jackpot':{ground('#ffd24a',9+e*8);const up=Math.min(1,p*3),yy=-16*up;c.fillStyle='#7a1a2a';c.strokeStyle=ink;c.lineWidth=.8;c.fillRect(-11,yy-8,22,14);c.strokeRect(-11,yy-8,22,14);   // the machine
      c.fillStyle='#f4f0e6';c.fillRect(-9,yy-6,18,8);for(let k=0;k<3;k++){const spin=p<.25+k*.12,X=-6+k*6;c.save();c.beginPath();c.rect(X-2.6,yy-6,5.2,8);c.clip();
        if(spin){for(let q=-1;q<2;q++){c.fillStyle='#8a8a8a';c.fillRect(X-1.5,yy-2+q*4+((p*90+k*7)%4)-2,3,1.4)}}else{c.fillStyle='#c42a3a';c.font='900 7px "Big Shoulders Stencil Display",sans-serif';c.textAlign='center';c.textBaseline='middle';c.fillText('7',X,yy-2)}c.restore()}
      c.fillStyle='#e2b436';c.fillRect(11,yy-6,2,7);blob(12,yy-7,1.6,'#c42a3a');
      if(p>.55){const q=(p-.55)/.45;for(let i=0;i<10;i++){const a=-Math.PI/2+(i/9-.5)*2.2,r=6+q*24,xx=Math.cos(a)*r,y2=yy+Math.sin(a)*r+q*q*30;blob(xx,y2,1.7,'#ffd24a');c.strokeStyle='#8a6410';c.lineWidth=.4;c.beginPath();c.arc(xx,y2,1.7,0,tau);c.stroke()}}break}   // three 7s, then the coins
    case'dissolved':{const melt=Math.min(1,p*1.4);ground('#7cff6b',6+melt*12,.5);c.fillStyle='#5ad84a';c.beginPath();c.ellipse(0,5,4+melt*10,1.5+melt*3,0,0,tau);c.fill();   // the puddle grows
      if(melt<1){const hgt=18*(1-melt);c.fillStyle='rgba(90,216,74,.85)';c.beginPath();c.moveTo(-4,5);c.quadraticCurveTo(-5,5-hgt*.6,0,5-hgt);c.quadraticCurveTo(5,5-hgt*.6,4,5);c.fill();
        for(let i=0;i<4;i++){const dx=-3+i*2,dl=(p*20+i*3)%6;c.fillRect(dx,5-hgt*.5+dl,1,2)}}   // the figure slumping and dripping
      for(let i=0;i<5;i++){const q=((p*2+i*.2)%1),xx=-8+hash(i,7)*16,yy=4-q*14;c.globalAlpha=fade*(1-q);c.strokeStyle='#c8ffb0';c.lineWidth=.6;c.beginPath();c.arc(xx,yy,1+q*1.5,0,tau);c.stroke()}break}   // bubbles
    case'abducted':{const beam=Math.min(1,p*4),lift=p<.25?0:Math.min(1,(p-.25)/.6);
      c.globalAlpha=fade*.35*beam;const gr=c.createLinearGradient(0,-60,0,8);gr.addColorStop(0,'rgba(184,255,168,.9)');gr.addColorStop(1,'rgba(184,255,168,.2)');c.fillStyle=gr;c.beginPath();c.moveTo(-5,-58);c.lineTo(5,-58);c.lineTo(14,6);c.lineTo(-14,6);c.fill();c.globalAlpha=fade;
      ground('#b8ffa8',14*beam,.5);for(let i=0;i<6;i++){const q=((p*1.6+i/6)%1);c.globalAlpha=fade*(1-q)*.6;c.strokeStyle='#e8ffd8';c.lineWidth=.6;c.beginPath();c.ellipse(0,6-q*58,12-q*7,(12-q*7)*.3,0,0,tau);c.stroke()}c.globalAlpha=fade;   // rings rising up the beam
      const by=2-lift*56,sp=lift*5;c.save();c.translate(0,by);c.rotate(Math.sin(sp)*.6);c.globalAlpha=fade*(1-Math.max(0,lift-.8)*5);c.fillStyle='#3a3a30';c.fillRect(-2,-9,4,9);blob(0,-11,2.2,'#a98262');c.strokeStyle='#3a3a30';c.lineWidth=1.4;c.beginPath();c.moveTo(-2,-7);c.lineTo(-5,-4+Math.sin(sp*2)*2);c.moveTo(2,-7);c.lineTo(5,-4-Math.sin(sp*2)*2);c.moveTo(-1,0);c.lineTo(-2,4);c.moveTo(1,0);c.lineTo(2,4);c.stroke();c.restore();c.globalAlpha=fade;   // the raider, lifted and turning
      const sx=Math.sin(p*3)*3,sy=-62;c.fillStyle='#8a90a0';c.beginPath();c.ellipse(sx,sy,15,4,0,0,tau);c.fill();c.fillStyle='#c8d0e0';c.beginPath();c.ellipse(sx,sy-3,6,4,0,Math.PI,0);c.fill();   // the saucer
      for(let i=0;i<5;i++){blob(sx-10+i*5,sy+.5,1,Math.sin(p*20+i*1.3)>0?'#7cff6b':'#ffd24a')}
      if(p>.88){c.globalAlpha=(1-p)/.12;blob(sx,sy,6+(p-.88)*80,'#e8ffd8')}break}   // a flash as it goes
  }
  c.restore();return true;
}
// tracers: the cached stamp's marks (once a frame kind) and the live parts (each shot)
function usTracerStamp(c,id){
  if(id==='chips')for(let i=1;i<4;i++){const x=i*38,col=['#c42a3a','#2a5ac4','#2fa04a'][i-1];c.fillStyle=col;c.beginPath();c.ellipse(x,24,7,5,0,0,Math.PI*2);c.fill();c.strokeStyle='#f4f0e6';c.lineWidth=1.6;c.setLineDash([3,3]);c.beginPath();c.ellipse(x,24,5,3.4,0,0,Math.PI*2);c.stroke();c.setLineDash([])}
  else if(id==='neontube'){c.strokeStyle='#5ab0ff';c.lineWidth=2;c.beginPath();c.moveTo(4,24);c.lineTo(150,24);c.stroke()}
  else if(id==='jackpotcoins')for(let i=1;i<4;i++){const x=i*36;c.fillStyle='#ffd24a';c.beginPath();c.arc(x,24+(i%2?3:-3),5,0,Math.PI*2);c.fill();c.strokeStyle='#8a6410';c.lineWidth=1.2;c.stroke()}
  else if(id==='saucerbolt'){c.strokeStyle='#e8ffd8';c.lineWidth=2.4;c.beginPath();c.ellipse(10,24,7,13,0,0,Math.PI*2);c.stroke()}}
function usTracerLive(ctx,id,len,w,t){
  if(id==='chips'){for(let i=0;i<3;i++){const x=len*(.55+i*.16),r=w*.7,tilt=Math.abs(Math.cos(t*14+i*2));ctx.fillStyle=['#c42a3a','#2a5ac4','#e8e2d0'][i];ctx.beginPath();ctx.ellipse(x,(i%2?1:-1)*w*.9,r,r*tilt+.2,0,0,Math.PI*2);ctx.fill()}}   // chips tumbling off the back
  else if(id==='tractorbeam'){ctx.strokeStyle='rgba(232,255,216,.7)';ctx.lineWidth=Math.max(.5,w*.3);ctx.beginPath();for(let q=0;q<=12;q++){const x=len*q/12,y=Math.sin(q*.9-t*18)*w*.9;q?ctx.lineTo(x,y):ctx.moveTo(x,y)}ctx.stroke()}   // the wobble
  else if(id==='neontube'){ctx.globalAlpha*=.35+.25*Math.sin(t*40);ctx.fillStyle='#ff8ae4';ctx.fillRect(0,-w*1.4,len*.7,w*2.8)}
  else if(id==='saucerbolt'){ctx.strokeStyle='rgba(124,255,107,.8)';ctx.lineWidth=Math.max(.6,w*.35);const r=w*(1.6+.4*Math.sin(t*30));ctx.beginPath();ctx.ellipse(w*.6,0,r*.45,r,0,0,Math.PI*2);ctx.stroke()}}
