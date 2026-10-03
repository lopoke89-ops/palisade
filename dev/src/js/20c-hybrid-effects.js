/* v0.9.6.4 Hybrid Theory kill effects: fixed geometry on the shared finish timeline (early, rise, peak, fade, ground
   ellipse), like the winter finishes. No emitters: every piece is placed from the progress value, so nothing accumulates. */
Object.assign(FINISH_LIFE,{leaf:.9,bands:1,swish:1.05,nuke:1.1,poop:.9,demon:1,hundo:.9,fire:.85,eight:.8,sixty:.95,zzz:1.1});
const HYBRID_FX_KEYS=new Set(HYBRID_FX.map(f=>f[0]));
function paintHybridFinish(c,key,p,s,x,y){
  if(!HYBRID_FX_KEYS.has(key))return false;if(p<0||p>=1)return true;
  const e=1-(1-p)**3,fade=Math.min(1,p*12,(1-p)*3),ink='#0b1111',tau=Math.PI*2;
  c.save();c.translate(x,y);c.scale(s,s);c.globalAlpha*=fade;c.lineJoin='round';c.lineCap='round';
  const ground=(col,r)=>{c.fillStyle=col;c.globalAlpha*=.35;c.beginPath();c.ellipse(0,6,r,r*.35,0,0,tau);c.fill();c.globalAlpha/=.35};
  const blob=(xx,yy,r,col)=>{c.fillStyle=col;c.beginPath();c.arc(xx,yy,r,0,tau);c.fill()};
  const block=(txt,xx,yy,size,col,rot=0)=>{c.save();c.translate(xx,yy);c.rotate(rot);c.font=`900 ${size}px "Big Shoulders Stencil Display", "Arial Narrow", sans-serif`;c.textAlign='center';c.textBaseline='middle';c.lineWidth=size*.18;c.strokeStyle=ink;c.strokeText(txt,0,0);c.fillStyle=col;c.fillText(txt,0,0);c.restore()};
  switch(key){
    case'leaf':{ground('#3FAE49',8+e*10);for(let i=0;i<8;i++){const a=i*tau/8+.3,r=4+e*18,xx=Math.cos(a)*r,yy=Math.sin(a)*r*.6-e*10+p*p*14;c.save();c.translate(xx,yy);c.rotate(a+p*3);c.fillStyle=i%2?'#C1D32F':'#3FAE49';c.strokeStyle='#1f5a26';c.lineWidth=.6;
      for(let k=-2;k<=2;k++){c.save();c.rotate(k*.42);c.beginPath();c.ellipse(0,-3.2,1.1,3.4,0,0,tau);c.fill();c.stroke();c.restore()}c.restore()}break}
    case'bands':{ground('#85BB65',8+e*8);for(let i=0;i<9;i++){const a=i*tau/9,r=3+e*17,xx=Math.cos(a)*r+Math.sin(p*9+i)*2,yy=Math.sin(a)*r*.5-e*14+p*p*22;c.save();c.translate(xx,yy);c.rotate(Math.sin(p*7+i)*.8);
      if(i%3===2){blob(0,0,2.2,'#FDB927');c.strokeStyle='#8a6410';c.lineWidth=.5;c.stroke()}else{c.fillStyle='#85BB65';c.fillRect(-4,-2.2,8,4.4);c.strokeStyle='#2f5a22';c.lineWidth=.6;c.strokeRect(-4,-2.2,8,4.4);blob(0,0,1.1,'#d8edc8')}c.restore()}break}
    case'swish':{const rimY=-22;c.strokeStyle='#F58426';c.lineWidth=2;c.beginPath();c.ellipse(0,rimY,9,3,0,0,tau);c.stroke();
      const kick=p>.45&&p<.7?Math.sin((p-.45)/.25*Math.PI)*2:0;c.strokeStyle='#ffffff';c.lineWidth=.7;for(let i=-3;i<=3;i++){c.beginPath();c.moveTo(i*2.6,rimY+1);c.lineTo(i*1.4+(i%2?kick:-kick),rimY+11+kick);c.stroke()}
      for(let j=1;j<3;j++){c.beginPath();c.ellipse(0,rimY+j*4,9-j*2,2.4-j*.5,0,0,tau);c.stroke()}
      const by=-40+Math.min(1,p*1.6)*44;blob(0,by,4.2,'#e8702a');c.strokeStyle=ink;c.lineWidth=.7;c.beginPath();c.arc(0,by,4.2,0,tau);c.moveTo(-4.2,by);c.lineTo(4.2,by);c.moveTo(0,by-4.2);c.lineTo(0,by+4.2);c.stroke();ground('#F58426',6+e*6);break}
    case'nuke':{if(p<.18){c.globalAlpha*=1-p/.18;blob(0,-6,30*(p/.18+.2),'#ffffff');c.globalAlpha=fade}
      ground('#9a9a9a',10+e*22);c.strokeStyle='#bfbfbf';c.lineWidth=2;c.globalAlpha*=.7;c.beginPath();c.ellipse(0,6,8+e*26,(8+e*26)*.35,0,0,tau);c.stroke();c.globalAlpha=fade;
      const top=-10-e*22;c.fillStyle='#b55a22';c.fillRect(-3,top+6,6,16+e*4);blob(0,top,9+e*5,'#EF3B24');blob(-6,top+2,6+e*3,'#f26a2a');blob(6,top+2,6+e*3,'#f26a2a');blob(0,top-3,6+e*3,'#ffb04a');break}
    case'poop':{ground('#6B4A32',7+e*7);const yy=-6-e*6;for(let k=0;k<3;k++){c.fillStyle=k%2?'#7d5a3e':'#6B4A32';c.beginPath();c.ellipse(0,yy-k*4,7-k*2,3,0,0,tau);c.fill();c.strokeStyle='#3e2a1c';c.lineWidth=.6;c.stroke()}
      for(let i=0;i<4;i++){const a=i*tau/4+p*2,r=8+e*10;c.globalAlpha=fade*.5;blob(Math.cos(a)*r,yy-8-e*10+Math.sin(a)*3,2+e*2,'#9fb35a')}break}
    case'demon':{ground('#552583',9+e*9);c.strokeStyle='#ff8a2a';c.lineWidth=1.4;for(let i=0;i<10;i++){const a=i*tau/10,r=9+e*7,h=3+Math.sin(p*14+i)*1.5;c.beginPath();c.moveTo(Math.cos(a)*r,6+Math.sin(a)*r*.35);c.lineTo(Math.cos(a)*r,6+Math.sin(a)*r*.35-h);c.stroke()}
      const yy=-14-e*6;for(const sd of[-1,1]){c.fillStyle='#552583';c.strokeStyle=ink;c.lineWidth=.7;c.beginPath();c.moveTo(sd*4,yy);c.quadraticCurveTo(sd*9,yy-4,sd*8,yy-11);c.lineTo(sd*6,yy-2);c.closePath();c.fill();c.stroke();blob(sd*3,yy+5,1.6,'#c7a0ff')}break}
    case'hundo':{for(let i=0;i<3;i++){const a=i*tau/3+.5,r=e*14*(i?1:0),k=.6+e*.7;c.globalAlpha=fade*(1-i*.15);block('100',Math.cos(a)*r,-12-e*8+Math.sin(a)*r*.5,9*k,'#ffffff',Math.sin(a)*.3)}break}
    case'fire':{ground('#ff6a1a',7+e*7);for(let i=0;i<6;i++){const xx=(i-2.5)*3.2,h=6+e*14*(1-Math.abs(i-2.5)/3.5)+Math.sin(p*20+i)*2;c.fillStyle=i%2?'#ffd24a':'#ff7a1a';c.beginPath();c.moveTo(xx-2.4,4);c.quadraticCurveTo(xx-1.6,4-h*.6,xx,4-h);c.quadraticCurveTo(xx+1.6,4-h*.6,xx+2.4,4);c.closePath();c.fill()}
      if(p>.5)for(let i=0;i<5;i++){const a=i*1.3,r=(p-.5)*30;blob(Math.cos(a)*r*.5,-4-r+Math.sin(a)*2,1,'#ffb04a')}break}
    case'eight':{if(p<.65){const k=Math.min(1,p*5);c.globalAlpha=fade;c.fillStyle='#e8b48c';c.strokeStyle=ink;c.lineWidth=.8;
        blob(-5*k,-8,3.2*k,'#e8b48c');blob(5*k,-8,3.2*k,'#e8b48c');c.fillRect(-2.4*k,-24*k-6,4.8*k,18*k);c.strokeRect(-2.4*k,-24*k-6,4.8*k,18*k);blob(0,-24*k-6,2.6*k,'#e8b48c')}
      else{c.globalAlpha=fade*(.4+.6*(1-(p-.65)/.35));blob(0,-12,8+(p-.65)*40,'#ffffff');ground('#e8b48c',10)}break}
    case'sixty':{const crack=p>.6?(p-.6)/.4:0;block('6',-6-crack*6,-14-e*6+crack*8,16,'#ffffff',-crack*.5);block('7',6+crack*6,-14-e*6+crack*8,16,'#C1D32F',crack*.5);
      if(crack){c.strokeStyle=ink;c.lineWidth=.8;c.beginPath();c.moveTo(-8,-22);c.lineTo(-5,-15);c.lineTo(-8,-9);c.moveTo(6,-22);c.lineTo(9,-15);c.lineTo(5,-9);c.stroke()}break}
    case'zzz':{ground('#7BA3C9',8);c.fillStyle='#d9d4c4';c.fillRect(-9,-2,18,5);c.fillStyle='#7BA3C9';c.fillRect(-9,-4,7,3);c.fillStyle='#5b4a3a';c.fillRect(-10,-5,2,9);c.fillRect(8,-2,2,6);
      for(let i=0;i<3;i++){const q=Math.max(0,Math.min(1,p*1.6-i*.25));if(!q)continue;c.globalAlpha=fade*(1-q*.6);block('Z',4+i*4+q*4,-8-q*18-i*3,7+i*2,'#cfe2f2')}break}
  }
  c.restore();return true;
}
