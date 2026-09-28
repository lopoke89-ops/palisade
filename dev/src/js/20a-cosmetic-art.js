/* Cosmetic artwork shared by the game, locker icons, and local review. */
const TRACE_STAMPS=new Map(),TRACE_KEYS=new WeakMap(),FX_GLOWS=new Map();
function cosmeticGlow(ctx,x,y,r,col,alpha=1){
 let cv=FX_GLOWS.get(col);
 if(!cv){cv=document.createElement('canvas');cv.width=cv.height=64;const c=cv.getContext('2d'),gr=c.createRadialGradient(32,32,0,32,32,32);gr.addColorStop(0,col);gr.addColorStop(.2,col);gr.addColorStop(1,'transparent');c.fillStyle=gr;c.fillRect(0,0,64,64);FX_GLOWS.set(col,cv);if(FX_GLOWS.size>32)FX_GLOWS.delete(FX_GLOWS.keys().next().value)}
 ctx.save();ctx.globalAlpha*=alpha;ctx.drawImage(cv,x-r,y-r,r*2,r*2);ctx.restore();
}
function tracerStamp(st,t){
 let id=TRACE_KEYS.get(st);if(id===undefined){id=TRAIL_IDS.findIndex(k=>TRAILS[k]===st);TRACE_KEYS.set(st,id)}
 const phase=st.rgrad||st.rainbow?Math.floor(((t*2)%12+12)%12):0,key=id+':'+phase;
 let cv=TRACE_STAMPS.get(key);if(cv)return cv;
 cv=document.createElement('canvas');cv.width=192;cv.height=48;const c=cv.getContext('2d');
 const colors=st.rgrad||st.rainbow?Array.from({length:5},(_,i)=>'hsl('+(phase*30+i*65)+',100%,70%)'):st.grad||[st.c||st.head||'#ffecaa',st.c||'#ffb44a'];
 const gr=c.createLinearGradient(0,0,192,0);colors.forEach((col,i)=>gr.addColorStop(i/(colors.length-1),col));
 const shape=()=>{c.beginPath();c.moveTo(0,24);c.lineTo(7,17);c.lineTo(35,18);c.lineTo(190,24);c.lineTo(35,30);c.lineTo(7,31);c.closePath()};
 c.shadowColor=st.edge||colors[0];c.shadowBlur=12;c.fillStyle=gr;shape();c.fill();c.globalAlpha=.24;shape();c.fill();c.globalAlpha=1;c.shadowBlur=0;
 c.strokeStyle=st.edge||'rgba(7,10,8,.55)';c.lineWidth=st.edge?4:1.3;shape();c.stroke();c.fillStyle=st.edge?'#10071c':gr;c.fill();
 if(!st.edge){c.fillStyle=st.rgrad?'#fff4b2':'#f8ffff';c.beginPath();c.moveTo(0,24);c.lineTo(10,22.7);c.lineTo(145,24);c.lineTo(10,25.3);c.closePath();c.fill()}
 else{c.strokeStyle='#e1bbff';c.lineWidth=1;c.beginPath();c.moveTo(1,23);c.lineTo(45,19);c.lineTo(140,23);c.stroke()}
 const fade=c.createLinearGradient(0,0,192,0);fade.addColorStop(0,'#fff');fade.addColorStop(.64,'#fff');fade.addColorStop(1,'transparent');c.globalCompositeOperation='destination-in';c.fillStyle=fade;c.fillRect(0,0,192,48);
 TRACE_STAMPS.set(key,cv);if(TRACE_STAMPS.size>64)TRACE_STAMPS.delete(TRACE_STAMPS.keys().next().value);return cv;
}
// Cache the two color channels; chromatic splitting adds no per-shot canvas allocation.
function glitchChannel(col){
 const key='glitch-channel:'+col;let cv=TRACE_STAMPS.get(key);if(cv)return cv;
 const source=tracerStamp(TRAILS.glitch,0);cv=document.createElement('canvas');cv.width=source.width;cv.height=source.height;
 const c=cv.getContext('2d');c.drawImage(source,0,0);c.globalCompositeOperation='source-in';c.fillStyle=col;c.fillRect(0,0,cv.width,cv.height);
 TRACE_STAMPS.set(key,cv);if(TRACE_STAMPS.size>64)TRACE_STAMPS.delete(TRACE_STAMPS.keys().next().value);return cv;
}
function paintTracer(ctx,x1,y1,x2,y2,st,w,t,heavy){
 const len=Math.hypot(x2-x1,y2-y1);if(len<.01)return;
 ctx.save();ctx.translate(x1,y1);ctx.rotate(Math.atan2(y2-y1,x2-x1));
 if(st===ENEMY_TR){ctx.strokeStyle=st.c;ctx.lineWidth=w;ctx.lineCap='round';ctx.beginPath();ctx.moveTo(0,0);ctx.lineTo(len,0);ctx.stroke();ctx.restore();return}
 const width=w*(st.pulse?1+.16*Math.sin(t*28):1),height=width*6.5;
 ctx.beginPath();ctx.rect(0,-height/2,len,height);ctx.clip();
 // The stamp is confined to the calibrated segment, including its soft tail.
 if(st.glitch){
  const tear=Math.floor(t*13)%7===0,split=width*(1.05+.22*Math.sin(t*19)+(tear?.35:0)),drift=Math.min(width*.65,len*.08);
  // Color fringes travel with the shot and remain inside the calibrated head/tail clip.
  ctx.save();ctx.globalCompositeOperation='lighter';ctx.globalAlpha*=.88;
  ctx.drawImage(glitchChannel('#ff285b'),drift,-height/2-split,len,height);
  ctx.drawImage(glitchChannel('#24eaff'),-drift,-height/2+split,len,height);ctx.restore();
  ctx.drawImage(tracerStamp(st,t),0,-height*.32,len,height*.64);
  if(tear)for(let i=0;i<2;i++){ctx.fillStyle=i?'#24eaff':'#ff285b';ctx.fillRect(len*(.28+i*.28),(i?1:-1)*split,Math.min(len*.17,width*5),width*.42)}
 }else ctx.drawImage(tracerStamp(st,t),0,-height/2,len,height);
 if(st.pulse||st===TRAILS.plasma||st===TRAILS.aurora){ctx.strokeStyle=st.pulse?'#fff2fb':'#deffff';ctx.globalAlpha*=.7;ctx.lineWidth=Math.max(.5,width*.22);for(let i=1;i<4;i++){const xx=len*i/5;ctx.beginPath();ctx.moveTo(xx,-width*.7);ctx.lineTo(xx+width*.5,0);ctx.lineTo(xx,width*.7);ctx.stroke()}}
 if(st.pk==='star'||st.pk==='cosmic'||st.rgrad){ctx.fillStyle=st.rgrad?'#fff1ac':'#f4edff';for(let i=1;i<4;i++){const xx=len*(i*.21),yy=Math.sin(i*2+t*5)*width*.55,rr=width*(i===1?.65:.4);ctx.beginPath();ctx.moveTo(xx-rr,yy);ctx.lineTo(xx,yy-rr);ctx.lineTo(xx+rr,yy);ctx.lineTo(xx,yy+rr);ctx.closePath();ctx.fill()}}
 if(st.pk==='rock'){ctx.fillStyle='#d2b8a0';ctx.strokeStyle='#292322';ctx.lineWidth=.6;for(let i=1;i<4;i++){const xx=len*i/5,yy=(i%2?1:-1)*width*.7;ctx.beginPath();ctx.moveTo(xx-width*.7,yy);ctx.lineTo(xx,yy-width*.55);ctx.lineTo(xx+width*.5,yy);ctx.lineTo(xx,yy+width*.7);ctx.closePath();ctx.fill();ctx.stroke()}}
 ctx.restore();
}
const FINISH_LIFE={sparks:.48,smoke:1.15,confetti:.95,embers:.8,glint:.65,bolt:.48,skull:.95,pixel:.7,frost:.75,gradburst:.75,sunburst:.75,toxic:.85,supernova:.85,glitchout:.6,singularity:.85,shockwave:.7,bubbles:1.2};
function paintFinish(ctx,key,progress,scale,x,y){
 if(!(key in FINISH_LIFE)||progress<0||progress>=1)return;
 const p=progress,e=1-Math.pow(1-p,3),fade=Math.min(1,(1-p)*2.8),pop=Math.min(1,p*12),tau=Math.PI*2;
 ctx.save();ctx.translate(x,y);ctx.scale(scale,scale);ctx.globalAlpha*=fade*pop;ctx.lineJoin='round';ctx.lineCap='round';
 const ink='#0b1111',gold='#ffd566',ice='#c7f6ff',violet='#ac8dff';
 const path=(pts,col,line=ink,w=.7)=>{ctx.beginPath();pts.forEach((v,i)=>i?ctx.lineTo(v[0],v[1]):ctx.moveTo(v[0],v[1]));ctx.closePath();ctx.fillStyle=col;ctx.fill();if(line){ctx.strokeStyle=line;ctx.lineWidth=w;ctx.stroke()}};
 const line=(pts,col,w=1)=>{ctx.beginPath();pts.forEach((v,i)=>i?ctx.lineTo(v[0],v[1]):ctx.moveTo(v[0],v[1]));ctx.strokeStyle=col;ctx.lineWidth=w;ctx.stroke()};
 const ring=(r,col,w=1,flat=1)=>{ctx.strokeStyle=col;ctx.lineWidth=w;ctx.beginPath();ctx.ellipse(0,0,r,r*flat,0,0,tau);ctx.stroke()};
 const star=(xx,yy,r,col,rot=0)=>{const pts=[];for(let i=0;i<8;i++){const a=i*Math.PI/4+rot,rr=i%2?r*.25:r;pts.push([xx+Math.cos(a)*rr,yy+Math.sin(a)*rr])}path(pts,col,ink,.45)};
 const shard=(xx,yy,r,col,a=0)=>{ctx.save();ctx.translate(xx,yy);ctx.rotate(a);path([[0,-r],[r*.42,0],[0,r],[-r*.42,0]],col);line([[0,-r*.65],[0,r*.4]],'#fffbea',.45);ctx.restore()};
 const glow=(r,col,a=.5)=>cosmeticGlow(ctx,0,0,r,col,a);
 const radial=(n,fn)=>{for(let i=0;i<n;i++){const a=i*tau/n+.28,r=(6+e*19)*(1+(i%3)*.12);fn(Math.cos(a)*r,Math.sin(a)*r,a,i)}};
 switch(key){
 case'sparks':glow(20,gold,.4);radial(10,(xx,yy,a,i)=>{const r=1.5+(1-p)*4;line([[xx-Math.cos(a)*r*2,yy-Math.sin(a)*r*2],[xx,yy]],'#ffac4f',2);line([[xx-Math.cos(a)*r,yy-Math.sin(a)*r],[xx,yy]],'#fff4c8',.8)});star(0,0,7*(1-p),'#fff5cd');break;
 case'smoke':for(let i=0;i<7;i++){const a=i*2.4,r=(7+e*14)*(1-i*.045),xx=Math.cos(a)*e*10,yy=Math.sin(a)*e*5-e*17;ctx.fillStyle=['#444b47','#636d65','#919b8d'][i%3];ctx.globalAlpha=fade*pop*(.28+i*.035);ctx.beginPath();ctx.arc(xx,yy,r,0,tau);ctx.fill();ctx.strokeStyle='#b7bfaa';ctx.lineWidth=.45;ctx.beginPath();ctx.arc(xx,yy,r*.83,3.5,4.8);ctx.stroke()}break;
 case'confetti':glow(22,'#ff9dcd',.18);radial(14,(xx,yy,a,i)=>{const col=['#ff6197','#ffda6b','#66e8ff','#a3f471','#c09aff'][i%5];ctx.save();ctx.translate(xx,yy+p*p*13);ctx.rotate(a+p*5);path([[-1.6,-4],[1.6,-3],[2,3],[-1,4]],col,ink,.5);ctx.restore()});break;
 case'embers':glow(27,'#ff792f',.55);for(let i=0;i<8;i++){const xx=Math.sin(i*2.4)*e*18,yy=-e*(12+i*3)+p*p*6,r=(1-p)*6+1;path([[xx,yy-r*2],[xx+r*.6,yy],[xx,yy+r*.7],[xx-r*.65,yy]],i%2?'#ffbb49':'#f26b36',ink,.45);line([[xx,yy],[xx,yy-r]],'#fff3aa',.7)}break;
 case'glint':glow(26,ice,.35);radial(7,(xx,yy,a,i)=>star(xx,yy,2.8+(1-p)*2.8,i%2?'#e6fbff':'#8de9ff',p));star(0,0,9*(1-p),'#ffffff',Math.PI/4);break;
 case'bolt':{glow(32,'#79ccff',.5);const j=Math.floor(p*12)%2?1:-1,pts=[[5,-43],[-3+j,-27],[5,-24],[-4,-9],[3,-11],[-2,8]];line(pts,'#3479d8',7);line(pts,'#98e8ff',3);line(pts,'#f0ffff',1.2);line([[-3,-27],[-14,-22],[-10,-13],[-19,-7]],'#b5f4ff',1.5);line([[-4,-9],[12,-14],[17,-7]],'#82dfff',1.4);ring(6+e*17,'#88dfff',1.1,.4);break}
 case'skull':ctx.translate(0,-e*18);ctx.fillStyle='#efe6d2';ctx.font='28px serif';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText('☠',0,0);break;
 case'pixel':glow(22,'#d884ff',.3);radial(12,(xx,yy,a,i)=>{const rr=(i%3+2)*(1-p*.55),col=['#ff567e','#50f4d5','#ffe77a','#839dff'][i%4];ctx.fillStyle=ink;ctx.fillRect(Math.round(xx)-rr-1,Math.round(yy)-rr-1,rr*2+2,rr*2+2);ctx.fillStyle=col;ctx.fillRect(Math.round(xx)-rr,Math.round(yy)-rr,rr*2,rr*2);ctx.fillStyle='#f2faff';ctx.fillRect(Math.round(xx)-rr,Math.round(yy)-rr,rr,.7)});break;
 case'frost':glow(30,ice,.45);for(let i=0;i<6;i++){const a=i*Math.PI/3,rr=9+e*17;line([[0,0],[Math.cos(a)*rr,Math.sin(a)*rr]],'#a7e8f9',1);shard(Math.cos(a)*rr,Math.sin(a)*rr,5*(1-p)+2,'#d6f9ff',a+Math.PI/2)}star(0,0,8*(1-p),'#f2ffff',Math.PI/4);break;
 case'gradburst':case'sunburst':{const warm=key==='sunburst',a=warm?'#ff759f':'#c79bff',b=warm?'#ffc36b':'#658bff';glow(32,a,.48);ring(5+e*23,b,1.2);radial(warm?8:10,(xx,yy,aa,i)=>shard(xx,yy,(1-p)*5+1,i%2?a:b,aa+Math.PI/2));star(0,0,11*(1-p),'#fff3ea',warm?Math.PI/4:0);break}
 case'toxic':glow(29,'#a7ff46',.32);for(let i=0;i<8;i++){const a=i*.79,r=e*(12+i%3*5),xx=Math.cos(a)*r,yy=Math.sin(a)*r;ctx.fillStyle=i%2?'#a9ec42':'#4ea546';ctx.strokeStyle=ink;ctx.lineWidth=.65;ctx.beginPath();ctx.ellipse(xx,yy,3+(1-p)*2,2.4+(1-p)*2,0,0,tau);ctx.fill();ctx.stroke();line([[xx,yy+2],[xx,yy+4+p*9]],'#b5f653',1.5);ctx.fillStyle='#eeffd0';ctx.fillRect(xx-1,yy-1,1.5,1)}break;
 case'supernova':glow(40,'#9189ff',.55);ring(7+e*25,'#a5b9ff',1.3);ring(5+e*20,'#f5edff',.65,.52);star(0,0,19*(1-p)+3,'#fff8dd',p*.2);radial(9,(xx,yy,a,i)=>star(xx,yy,2.8*(1-p)+.7,i%2?'#e2d7ff':'#fff4c1',a));break;
 case'glitchout':glow(24,'#57edce',.2);for(let i=0;i<11;i++){const yy=(i-5)*4,xx=Math.sin(i*9+Math.floor(p*10))*e*17,ww=(6+i%4*4)*(1-p*.55);ctx.fillStyle=['#ff467c','#53f4d5','#8a99ff','#f1faff'][i%4];ctx.fillRect(xx-ww/2,yy,ww,i%3?2:4);ctx.fillStyle=ink;ctx.fillRect(xx+1,yy+.7,ww*.3,.6)}break;
 case'singularity':{const rr=15*(1-p)+3;glow(36,violet,.5);ctx.fillStyle='#090710';ctx.beginPath();ctx.arc(0,0,rr,0,tau);ctx.fill();ring(rr+2,'#c29fff',1.3,.45);ctx.save();ctx.rotate(-.35);ring(rr+5,'#8165dc',1,.35);ctx.restore();for(let i=0;i<9;i++){const a=i*.7+p*5,r=(1-e)*30+rr+3;shard(Math.cos(a)*r,Math.sin(a)*r*.6,2.5,'#bc8dff',a+p)}break}
 case'shockwave':glow(31,'#5df1ff',.3);ring(4+e*28,'#52edff',2,.58);ring(2+e*21,'#fd7cda',1.3,.58);ring(3+e*26,'#e2ffff',.5,.58);for(let i=0;i<8;i++){const a=i*Math.PI/4,r=8+e*28;line([[Math.cos(a)*r,Math.sin(a)*r*.58],[Math.cos(a)*(r+3),Math.sin(a)*(r+3)*.58]],i%2?'#fe8ddf':'#b4ffff',1)}break;
 case'bubbles':glow(33,gold,.3);for(let i=0;i<9;i++){const a=i*2.4,r=e*(9+i%3*6),xx=Math.cos(a)*r,yy=Math.sin(a)*r*.6-e*(i%4)*6,rr=(3+i%4)*(1-p*.3);ctx.fillStyle='rgba(255,214,92,.13)';ctx.strokeStyle='#ffe598';ctx.lineWidth=.9;ctx.beginPath();ctx.arc(xx,yy,rr,0,tau);ctx.fill();ctx.stroke();ctx.strokeStyle=i%2?'#a4faff':'#ffb4dc';ctx.lineWidth=.5;ctx.beginPath();ctx.arc(xx,yy,rr*.8,.3,2);ctx.stroke();line([[xx-rr*.5,yy-rr*.25],[xx-rr*.25,yy-rr*.5]],'#fffce9',1.2)}for(let i=0;i<4;i++)star(Math.cos(i*1.7)*e*24,Math.sin(i*1.7)*e*16,2.2,'#fff1b6',p);break;
 }
 ctx.restore();
}
function drawFinishEffects(){for(const p of parts)if(p.kind.startsWith('finish:')){const c=iso(p.x,p.y);paintFinish(g,p.kind.slice(7),1-p.life/p.max,u,c[0],c[1]-p.z)}}
function paintCosmeticParticle(ctx,q,x,y,s,t){
 const a=Math.max(0,q.life/q.max),r=q.size*s,col=q.c1?mix(q.c1,q.c2,Math.round((1-a)*16)/16):q.col;
 if(!['star','cosmic','goldsp','glint','ice','rock','confetti','pix','glitch','nova','grad1','grad2','neon','spark','ember','bolt'].includes(q.kind))return false;
 ctx.save();ctx.globalAlpha*=Math.min(1,a*1.5);ctx.translate(x,y);ctx.fillStyle=col;ctx.strokeStyle='#101810';ctx.lineWidth=Math.max(.35,s*.3);ctx.lineJoin='round';
 if(['spark','ember','bolt'].includes(q.kind)){ctx.strokeStyle=col;ctx.lineWidth=Math.max(.7,r*.55);ctx.beginPath();ctx.moveTo(0,0);ctx.lineTo(-q.vx*s*.65,q.vz*s*.025);ctx.stroke();ctx.fillStyle='#fff4d6';ctx.fillRect(-r*.16,-r*.16,r*.32,r*.32)}
 else if(q.kind==='confetti'||q.kind==='glitch'||q.kind==='pix'){ctx.rotate((q.x+q.y)*5+(1-a)*4);const w=q.kind==='glitch'?r*2:r;ctx.fillRect(-w/2,-r/2,w,r);ctx.strokeRect(-w/2,-r/2,w,r);ctx.fillStyle='#ffffff';ctx.globalAlpha*=.45;ctx.fillRect(-w/2,-r/2,w,.5*s)}
 else{const star=['star','cosmic','goldsp','glint','nova'].includes(q.kind);ctx.rotate((q.x+q.y)*3+t*.7);ctx.beginPath();if(star){for(let i=0;i<8;i++){const ang=i*Math.PI/4,rr=i%2?r*.25:r;i?ctx.lineTo(Math.cos(ang)*rr,Math.sin(ang)*rr):ctx.moveTo(rr,0)}}else{ctx.moveTo(0,-r*1.25);ctx.lineTo(r*.65,0);ctx.lineTo(0,r);ctx.lineTo(-r*.55,0)}ctx.closePath();ctx.fill();ctx.stroke();ctx.fillStyle='#f8ffed';ctx.fillRect(-r*.12,-r*.12,r*.24,r*.24)}
 ctx.restore();return true;
}
