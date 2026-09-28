/* ---------- lobby backgrounds ----------
   Chosen in the Locker, drawn behind your character in the lobby. Each one is a static layer (drawn once per screen
   size and cached) plus a light animated layer. draw(x,w,h,t): x is a 2D context already scaled to CSS pixels, t seconds.
   src: free / unlock (need: a stat goal, like the other unlocks) / case (found in that case). */
const BG_CACHE=new Map();
function bgLayer(key,w,h,paint){
  const k=key+'|'+(w|0)+'x'+(h|0),dp=Math.min(2,window.devicePixelRatio||1);let c=BG_CACHE.get(k);if(c)return c;
  if(BG_CACHE.size>12)BG_CACHE.clear();
  c=document.createElement('canvas');c.width=Math.ceil(w*dp);c.height=Math.ceil(h*dp);const x=c.getContext('2d');x.scale(dp,dp);paint(x,w,h);BG_CACHE.set(k,c);return c;
}
const bgBlit=(x,c,w,h)=>x.drawImage(c,0,0,w,h);
// a rounded rectangle path (the built-in one isn't in Safari before iOS 16)
function bgRound(x,X,Y,W,H,r){x.beginPath();x.moveTo(X+r,Y);x.arcTo(X+W,Y,X+W,Y+H,r);x.arcTo(X+W,Y+H,X,Y+H,r);x.arcTo(X,Y+H,X,Y,r);x.arcTo(X,Y,X+W,Y,r);x.closePath()}
const vgrad=(x,w,h,stops)=>{const gr=x.createLinearGradient(0,0,0,h);for(const[o,c]of stops)gr.addColorStop(o,c);x.fillStyle=gr;x.fillRect(0,0,w,h)};
// a soft round blob stamp (smoke, fog, glow), cached per colour
const BG_BLOB=new Map();
function bgBlob(col){let c=BG_BLOB.get(col);if(c)return c;c=document.createElement('canvas');c.width=c.height=128;const x=c.getContext('2d'),gr=x.createRadialGradient(64,64,0,64,64,64);
  gr.addColorStop(0,col);gr.addColorStop(1,col.replace(/[\d.]+\)$/,'0)'));x.fillStyle=gr;x.fillRect(0,0,128,128);BG_BLOB.set(col,c);return c}
// silhouettes shared by several backgrounds
function bgTrees(x,w,h,base,col,seed){x.fillStyle=col;for(let i=0;i<Math.ceil(w/26)+2;i++){const tx=i*26-10+hash(i,seed)*14,th=40+hash(i,seed+1)*70,tw=16+hash(i,seed+2)*10,y0=base+hash(i,seed+3)*10;
  x.beginPath();x.moveTo(tx,y0-th);x.lineTo(tx-tw/2,y0);x.lineTo(tx+tw/2,y0);x.closePath();x.fill()}x.fillRect(0,base+8,w,h-base)}
function bgFence(x,w,base,col){x.strokeStyle=col;x.lineWidth=3;x.beginPath();x.moveTo(0,base-18);x.lineTo(w,base-22);x.moveTo(0,base-8);x.lineTo(w,base-11);x.stroke();
  x.lineWidth=4;for(let px=8;px<w;px+=34){x.beginPath();x.moveTo(px,base+2);x.lineTo(px,base-28);x.stroke()}}
const BGS={
  campfire:{name:'Campfire Dusk',r:'c',src:'free',
    draw(x,w,h,t){bgBlit(x,bgLayer('campfire',w,h,(x,w,h)=>{vgrad(x,w,h,[[0,'#140f0c'],[.55,'#2a1a10'],[1,'#5a2a12']]);
        const gr=x.createRadialGradient(w/2,h*1.02,0,w/2,h*1.02,h*.55);gr.addColorStop(0,'rgba(255,140,50,.45)');gr.addColorStop(1,'rgba(255,140,50,0)');x.fillStyle=gr;x.fillRect(0,0,w,h);
        bgTrees(x,w,h,h*.86,'#0c0907',11)}),w,h);
      for(let i=0;i<26;i++){const ph=(t*.09*(0.6+hash(i,2))+hash(i,1))%1,ex=w*(.3+.4*hash(i,3))+Math.sin(t*1.3+i)*14,ey=h*(1-ph*.85);
        x.globalAlpha=Math.sin(ph*Math.PI)*.9;x.fillStyle=i%3?'#ffb04a':'#ffe08a';x.fillRect(ex,ey,2,2)}x.globalAlpha=1}},
  nightwatch:{name:'Night Watch',r:'c',src:'free',
    draw(x,w,h,t){bgBlit(x,bgLayer('nightwatch',w,h,(x,w,h)=>{vgrad(x,w,h,[[0,'#05070f'],[.7,'#0d1426'],[1,'#162038']]);bgTrees(x,w,h,h*.9,'#04050a',21)}),w,h);
      for(let i=0;i<70;i++){const sx=hash(i,5)*w,sy=hash(i,6)*h*.75;x.globalAlpha=.35+.65*Math.abs(Math.sin(t*(.6+hash(i,7))+i));x.fillStyle=i%9?'#e8eeff':'#ffe9b0';x.fillRect(sx,sy,i%7?1:1.6,i%7?1:1.6)}
      const sp=(t%11)/11;if(sp<.12){const k=sp/.12,x0=w*(.15+.5*k),y0=h*(.1+.18*k);x.globalAlpha=1-k;x.strokeStyle='#ffffff';x.lineWidth=1.4;x.beginPath();x.moveTo(x0,y0);x.lineTo(x0-40,y0-14);x.stroke()}
      x.globalAlpha=1}},
  dawn:{name:'First Light',r:'r',src:'unlock',need:{wins:1},how:'Win any run',
    draw(x,w,h,t){const k=.5+.5*Math.sin(t*.12);vgrad(x,w,h,[[0,`hsl(${250-20*k},40%,${14+6*k}%)`],[.55,`hsl(${340+10*k},55%,${38+8*k}%)`],[1,'#ffb070']]);
      const sy=h*(.74-.06*k);x.fillStyle='rgba(255,230,170,.9)';x.beginPath();x.arc(w*.62,sy,34,0,Math.PI*2);x.fill();
      for(let i=0;i<5;i++){const cx=((t*6*(1+i*.3)+i*170)%(w+260))-130,cy=h*(.2+.1*i);x.globalAlpha=.35;x.drawImage(bgBlob('rgba(255,210,220,.9)'),cx-90,cy-20,180,40)}x.globalAlpha=1;
      bgBlit(x,bgLayer('dawnfg',w,h,(x,w,h)=>bgTrees(x,w,h,h*.9,'#1a0f18',31)),w,h)}},
  aurora:{name:'Aurora',r:'e',src:'unlock',need:{wins:10},how:'Win 10 runs',
    draw(x,w,h,t){bgBlit(x,bgLayer('aurora',w,h,(x,w,h)=>{vgrad(x,w,h,[[0,'#02040a'],[1,'#0a1a24']]);for(let i=0;i<60;i++){x.fillStyle='#dfe8ff';x.globalAlpha=.3+.5*hash(i,9);x.fillRect(hash(i,8)*w,hash(i,10)*h*.8,1,1)}x.globalAlpha=1}),w,h);
      // three curtains: a wavy top edge, fading downward
      x.globalCompositeOperation='lighter';
      for(const[ci,rgb,yb,a0]of[[0,'60,255,160',.26,.5],[1,'150,90,255',.34,.4],[2,'60,220,255',.2,.35]]){
        const top=s=>h*yb+Math.sin(s*.009+t*.45+ci*2)*h*.05+Math.sin(s*.023+t*.8)*h*.015,depth=h*.2;
        const gr=x.createLinearGradient(0,h*yb-h*.07,0,h*yb+depth);gr.addColorStop(0,`rgba(${rgb},0)`);gr.addColorStop(.25,`rgba(${rgb},${a0})`);gr.addColorStop(1,`rgba(${rgb},0)`);
        x.fillStyle=gr;x.beginPath();x.moveTo(0,top(0));for(let s=8;s<=w+8;s+=8)x.lineTo(s,top(s));for(let s=w+8;s>=0;s-=8)x.lineTo(s,top(s)+depth*(.7+.3*Math.sin(s*.02+t*.6+ci)));x.closePath();x.fill()}
      x.globalCompositeOperation='source-over';bgBlit(x,bgLayer('aurorafg',w,h,(x,w,h)=>bgTrees(x,w,h,h*.9,'#010204',41)),w,h)}},
  emberfield:{name:'Ember Field',r:'r',src:'unlock',need:{drops:100},how:'Drop 100 raiders',
    draw(x,w,h,t){bgBlit(x,bgLayer('ember',w,h,(x,w,h)=>vgrad(x,w,h,[[0,'#0e0606'],[.6,'#2a0c08'],[1,'#6a1c0c']])),w,h);
      x.globalAlpha=.35+.1*Math.sin(t*1.7);x.drawImage(bgBlob('rgba(255,90,30,.6)'),w*.5-w*.9,h*.82,w*1.8,h*.5);
      for(let i=0;i<50;i++){const ph=(t*.12*(0.5+hash(i,12))+hash(i,13))%1,ex=hash(i,14)*w+Math.sin(t*2+i)*10,ey=h*(1.02-ph);
        x.globalAlpha=Math.sin(ph*Math.PI);x.fillStyle=i%4?'#ff8a3a':'#ffd06a';x.fillRect(ex,ey,i%5?1.6:2.4,i%5?1.6:2.4)}x.globalAlpha=1}},
  crimson:{name:'Crimson Smoke',r:'e',src:'unlock',need:{drops:500},how:'Drop 500 raiders',
    draw(x,w,h,t){vgrad(x,w,h,[[0,'#0a0506'],[1,'#1c080a']]);const b=bgBlob('rgba(170,30,34,.55)'),d=bgBlob('rgba(40,8,10,.8)');
      for(let i=0;i<9;i++){const cx=(hash(i,15)*w+t*(8+hash(i,16)*10))%(w+300)-150,cy=h*(.15+.8*hash(i,17))+Math.sin(t*.3+i)*20,r=120+90*hash(i,18);
        x.globalAlpha=.55;x.drawImage(i%3?b:d,cx-r,cy-r*.7,r*2,r*1.4)}x.globalAlpha=1}},
  neongrid:{name:'Neon Grid',r:'l',src:'unlock',need:{drops:1000},how:'Drop 1,000 raiders',
    draw(x,w,h,t){const hz=h*.55;bgBlit(x,bgLayer('neon',w,h,(x,w,h)=>{vgrad(x,w,h,[[0,'#07021a'],[.55,'#2a0a4a'],[.551,'#0a0214'],[1,'#12032a']]);
        const sx=w/2,sy=h*.55-60;for(let i=0;i<9;i++){x.fillStyle=i%2?'#ff5ad8':'#ffb03a';const y0=sy-40+i*9,hh=6-i*.5;if(hh<=0)continue;
          x.save();x.beginPath();x.arc(sx,sy,60,Math.PI,0);x.clip();x.fillRect(sx-60,y0,120,hh);x.restore()}}),w,h);
      x.strokeStyle='rgba(255,90,216,.7)';x.lineWidth=1.2;for(let i=-10;i<=10;i++){x.beginPath();x.moveTo(w/2+i*14,hz);x.lineTo(w/2+i*120,h);x.stroke()}
      x.strokeStyle='rgba(42,245,255,.65)';for(let k=0;k<12;k++){const f=((k+t*.8)%12)/12,y=hz+(h-hz)*f*f;x.globalAlpha=f;x.beginPath();x.moveTo(0,y);x.lineTo(w,y);x.stroke()}x.globalAlpha=1}},
  goldrush:{name:'Gold Rush',r:'l',src:'unlock',need:{hardWins:3},how:'Win 3 runs on Hard',
    draw(x,w,h,t){bgBlit(x,bgLayer('gold',w,h,(x,w,h)=>{vgrad(x,w,h,[[0,'#1a1206'],[.6,'#4a3410'],[1,'#8a6420']]);const gr=x.createRadialGradient(w/2,h*.45,0,w/2,h*.45,h*.6);
        gr.addColorStop(0,'rgba(255,220,120,.35)');gr.addColorStop(1,'rgba(255,220,120,0)');x.fillStyle=gr;x.fillRect(0,0,w,h)}),w,h);
      x.globalCompositeOperation='lighter';for(let i=0;i<6;i++){const a=Math.PI/2+(i-2.5)*.28+Math.sin(t*.25+i)*.06,L=h*1.1;x.globalAlpha=.07+.04*Math.sin(t*.8+i*1.7);x.fillStyle='#ffe6a0';   // rays fanning down from the top
        x.beginPath();x.moveTo(w/2,-h*.05);x.lineTo(w/2+Math.cos(a-.06)*L,-h*.05+Math.sin(a-.06)*L);x.lineTo(w/2+Math.cos(a+.06)*L,-h*.05+Math.sin(a+.06)*L);x.closePath();x.fill()}
      x.globalAlpha=1;x.globalCompositeOperation='source-over';
      for(let i=0;i<40;i++){const ph=(t*.04*(1+hash(i,26))+hash(i,27))%1;x.globalAlpha=Math.sin(ph*Math.PI)*.8;x.fillStyle='#ffe08a';x.fillRect(hash(i,28)*w+Math.sin(t+i)*8,h*(1-ph),1.4,1.4)}x.globalAlpha=1;
      for(let i=0;i<30;i++){const ph=(t*.7+hash(i,19)*3)%3;if(ph>.5)continue;const s=Math.sin(ph/.5*Math.PI)*4,px=hash(i,20)*w,py=hash(i,21)*h;
        x.strokeStyle='#fff6c8';x.lineWidth=1;x.beginPath();x.moveTo(px-s,py);x.lineTo(px+s,py);x.moveTo(px,py-s);x.lineTo(px,py+s);x.stroke()}}},
  // Halloween Case
  harvestmoon:{name:'Harvest Moon',r:'r',src:'case',box:'halloween',
    draw(x,w,h,t){bgBlit(x,bgLayer('harvest',w,h,(x,w,h)=>{vgrad(x,w,h,[[0,'#0c0612'],[.6,'#2a1420'],[1,'#3a1a10']]);
        const mx=w*.64,my=h*.3,gr=x.createRadialGradient(mx,my,40,mx,my,170);gr.addColorStop(0,'rgba(255,150,60,.35)');gr.addColorStop(1,'rgba(255,150,60,0)');x.fillStyle=gr;x.fillRect(0,0,w,h);
        x.fillStyle='#ff9a3a';x.beginPath();x.arc(mx,my,58,0,Math.PI*2);x.fill();x.fillStyle='rgba(200,90,30,.35)';for(const[a,b,r]of[[-18,-10,12],[14,8,9],[-4,22,7]]){x.beginPath();x.arc(mx+a,my+b,r,0,Math.PI*2);x.fill()}
        bgFence(x,w,h*.86,'#0a0508');x.fillStyle='#0a0508';x.fillRect(0,h*.86,w,h);
        x.strokeStyle='#0a0508';x.lineCap='round';const tx=w*.18;for(const[lw,pts]of[[9,[[tx,h*.87],[tx+4,h*.55]]],[5,[[tx+3,h*.64],[tx+46,h*.5]]],[4,[[tx+2,h*.6],[tx-30,h*.47]]],[3,[[tx+30,h*.55],[tx+44,h*.43]]],[3,[[tx-18,h*.51],[tx-34,h*.54]]]]){x.lineWidth=lw;x.beginPath();x.moveTo(...pts[0]);x.lineTo(...pts[1]);x.stroke()}}),w,h);
      for(let i=0;i<3;i++){const cx=((t*10*(1+i*.4)+i*220)%(w+300))-150,cy=h*(.22+.1*i);x.globalAlpha=.45;x.drawImage(bgBlob('rgba(30,14,24,.95)'),cx-110,cy-22,220,44)}x.globalAlpha=1;
      for(let i=0;i<4;i++){const ph=((t*.07+hash(i,22))%1),bx=w*(1.1-ph*1.3),by=h*(.18+.2*hash(i,23))+Math.sin(t*3+i)*10,f=Math.sin(t*22+i*2)*5;
        x.strokeStyle='#0a0508';x.lineWidth=2;x.beginPath();x.moveTo(bx-9,by-f);x.lineTo(bx-3,by);x.lineTo(bx,by-2);x.lineTo(bx+3,by);x.lineTo(bx+9,by-f);x.stroke()}}},
  hauntedfog:{name:'Haunted Fog',r:'e',src:'case',box:'halloween',
    draw(x,w,h,t){bgBlit(x,bgLayer('haunt',w,h,(x,w,h)=>{vgrad(x,w,h,[[0,'#05040c'],[.6,'#15122a'],[1,'#221a34']]);
        const hx=w*.5,hy=h*.62;x.fillStyle='#07060e';x.fillRect(hx-70,hy-60,140,70);x.beginPath();x.moveTo(hx-80,hy-58);x.lineTo(hx,hy-110);x.lineTo(hx+80,hy-58);x.fill();
        x.fillRect(hx+36,hy-120,14,40);bgTrees(x,w,h,h*.72,'#07060e',51)}),w,h);
      const f=.6+.4*Math.sin(t*9)*Math.sin(t*3.1);x.fillStyle=`rgba(255,200,110,${.5+.4*f})`;x.fillRect(w*.5-24,h*.62-44,12,14);x.fillStyle='rgba(255,200,110,.25)';x.fillRect(w*.5+14,h*.62-44,12,14);
      const fog=bgBlob('rgba(170,160,210,.35)');for(let L=0;L<3;L++)for(let i=0;i<5;i++){const cx=((t*(6+L*6)+i*160+L*70)%(w+320))-160,cy=h*(.66+L*.1)+Math.sin(t*.4+i+L)*8;
        x.globalAlpha=.55-L*.08;x.drawImage(fog,cx-150,cy-35,300,70)}
      for(let i=0;i<3;i++){const ph=(t*.05+hash(i,24))%1,sx=w*hash(i,25)+Math.sin(t+i)*20,sy=h*(.7-ph*.5),s=8;x.globalAlpha=Math.sin(ph*Math.PI)*.5;x.fillStyle='#d8ffe8';
        x.beginPath();x.arc(sx,sy,s,Math.PI,0);x.lineTo(sx+s,sy+s*1.3);x.lineTo(sx,sy+s*.9);x.lineTo(sx-s,sy+s*1.3);x.closePath();x.fill()}x.globalAlpha=1}}
};
// Case backgrounds follow one rule: Rare and Epic are still pictures; only Legendary and Super rare ones move.
// still: the moment of the animation that gets frozen (drawn once per screen size and cached).
Object.assign(BGS.harvestmoon,{still:4.2});Object.assign(BGS.hauntedfog,{still:6.5});
const BG_CASE={
  // ---- Supply Case: the old field kit
  fieldmap:{name:'Field Map',r:'r',box:'supply',still:0,
    draw(x,w,h){vgrad(x,w,h,[[0,'#b9a77a'],[1,'#9c8a5e']]);x.strokeStyle='rgba(60,50,30,.18)';x.lineWidth=1;for(let gx=0;gx<w;gx+=40){x.beginPath();x.moveTo(gx,0);x.lineTo(gx,h);x.stroke()}for(let gy=0;gy<h;gy+=40){x.beginPath();x.moveTo(0,gy);x.lineTo(w,gy);x.stroke()}
      for(const[cx,cy,n]of[[w*.3,h*.3,7],[w*.75,h*.62,6]])for(let k=1;k<=n;k++){x.strokeStyle=`rgba(90,60,30,${.2+.04*k})`;x.lineWidth=1.2;x.beginPath();for(let a=0;a<=64;a++){const an=a/64*Math.PI*2,r=k*18*(1+.18*Math.sin(an*3+k)+.08*Math.sin(an*5));x.lineTo(cx+Math.cos(an)*r,cy+Math.sin(an)*r*.8)}x.closePath();x.stroke()}
      x.strokeStyle='#a8342a';x.lineWidth=3;x.setLineDash([10,8]);x.beginPath();x.moveTo(w*.1,h*.85);x.bezierCurveTo(w*.4,h*.7,w*.2,h*.45,w*.62,h*.38);x.stroke();x.setLineDash([]);
      x.lineWidth=4;for(const[a,b]of[[w*.62,h*.38]]){x.beginPath();x.moveTo(a-9,b-9);x.lineTo(a+9,b+9);x.moveTo(a+9,b-9);x.lineTo(a-9,b+9);x.stroke()}
      for(const[a,b]of[[w*.28,h*.3],[w*.78,h*.64]]){x.fillStyle='#2a3a22';x.beginPath();x.arc(a,b,6,0,Math.PI*2);x.fill()}
      const gr=x.createRadialGradient(w/2,h/2,Math.min(w,h)*.3,w/2,h/2,Math.max(w,h)*.75);gr.addColorStop(0,'rgba(40,30,15,0)');gr.addColorStop(1,'rgba(40,30,15,.55)');x.fillStyle=gr;x.fillRect(0,0,w,h)}},
  sandbags:{name:'Sandbag Line',r:'r',box:'supply',still:0,
    draw(x,w,h){vgrad(x,w,h,[[0,'#2a3448'],[.55,'#8a6a52'],[.7,'#d9a060']]);x.fillStyle='rgba(255,240,200,.9)';x.fillRect(w*.8,h*.12,2,2);
      x.strokeStyle='#1c1812';x.lineWidth=1.5;x.beginPath();for(let px=0;px<=w;px+=12)x.lineTo(px,h*.6+(px/12%2?-5:5));x.stroke();for(let px=6;px<w;px+=36){x.beginPath();x.moveTo(px,h*.6-10);x.lineTo(px,h*.66);x.stroke()}
      const top=h*.66;x.fillStyle='#2a241a';x.fillRect(0,top,w,h-top);for(let row=0;row<Math.ceil((h-top)/26);row++)for(let i=-1;i<w/58+1;i++){const bx=i*58+(row%2?29:0),by=top+row*26;
        x.fillStyle=row%2?'#9a8660':'#a8946c';x.strokeStyle='#3a3024';x.lineWidth=2;bgRound(x,bx+2,by+2,54,23,10);x.fill();x.stroke();x.strokeStyle='rgba(58,48,36,.5)';x.lineWidth=1;x.beginPath();x.moveTo(bx+10,by+12);x.lineTo(bx+46,by+12);x.stroke()}}},
  dogtags:{name:'Dog Tags',r:'e',box:'supply',still:0,
    draw(x,w,h){vgrad(x,w,h,[[0,'#2b2e31'],[1,'#17191b']]);for(let yy=0;yy<h;yy+=3){x.fillStyle=`rgba(255,255,255,${.012+.012*hash(yy,3)})`;x.fillRect(0,yy,w,1)}
      const k=Math.min(w/390,h/760)*1.9,cx=w*.5,cy=h*.5;x.save();x.translate(cx,cy);x.scale(k,k);
      // a ball chain looping down from above to both tags
      x.fillStyle='#9aa0a6';for(const[x0,x1,y1]of[[-8,-62,-2],[8,48,16]])for(let n=0;n<=40;n++){const f=n/40,px=x0+(x1-x0)*f,py=-150+(y1+150)*f+Math.sin(f*Math.PI)*-10;x.beginPath();x.arc(px,py,1.7,0,Math.PI*2);x.fill()}
      for(const[dx,dy,rot]of[[-26,0,-.12],[24,18,.1]]){x.save();x.translate(dx,dy);x.rotate(rot);const gr=x.createLinearGradient(-45,-28,45,28);gr.addColorStop(0,'#cfd4d8');gr.addColorStop(.5,'#8e959b');gr.addColorStop(1,'#bfc5ca');
        x.fillStyle=gr;x.strokeStyle='#3a3f44';x.lineWidth=2;bgRound(x,-46,-28,92,56,14);x.fill();x.stroke();x.fillStyle='#2b2e31';x.beginPath();x.arc(-36,0,3,0,Math.PI*2);x.fill();
        x.fillStyle='rgba(40,44,48,.75)';x.font='600 10px "IBM Plex Mono", monospace';x.fillText('PALISADE',-26,-10);x.fillText(dx<0?'CLAIM HELD':'NO. 0001',-26,4);x.fillText(dx<0?'O POS':'YARD 16',-26,18);x.restore()}
      x.restore()}},
  watchtower:{name:'Watchtower',r:'e',box:'supply',still:0,
    draw(x,w,h){vgrad(x,w,h,[[0,'#04060c'],[1,'#141c2c']]);for(let i=0;i<60;i++){x.globalAlpha=.3+.6*hash(i,31);x.fillStyle='#e8eeff';x.fillRect(hash(i,32)*w,hash(i,33)*h*.6,1,1)}x.globalAlpha=1;
      const tx=w*.34,base=h*.82;x.globalCompositeOperation='lighter';const gr=x.createLinearGradient(tx,h*.36,w,h*.2);gr.addColorStop(0,'rgba(255,240,190,.35)');gr.addColorStop(1,'rgba(255,240,190,0)');x.fillStyle=gr;
      x.beginPath();x.moveTo(tx+8,h*.37);x.lineTo(w*1.1,h*.1);x.lineTo(w*1.1,h*.34);x.closePath();x.fill();x.globalCompositeOperation='source-over';
      x.strokeStyle='#07090e';x.lineWidth=5;x.beginPath();x.moveTo(tx-30,base);x.lineTo(tx-16,h*.4);x.moveTo(tx+30,base);x.lineTo(tx+16,h*.4);x.stroke();x.lineWidth=2.5;for(let k=0;k<4;k++){const y0=base-k*(base-h*.42)/4,y1=y0-(base-h*.42)/4;x.beginPath();x.moveTo(tx-30+k*3.5,y0);x.lineTo(tx+26-k*3.5,y1);x.stroke()}
      x.fillStyle='#07090e';x.fillRect(tx-26,h*.34,52,26);x.beginPath();x.moveTo(tx-32,h*.34);x.lineTo(tx,h*.29);x.lineTo(tx+32,h*.34);x.fill();x.fillStyle='#ffd88a';x.fillRect(tx-8,h*.35,10,8);
      bgTrees(x,w,h,h*.88,'#050709',61)}},
  searchlight:{name:'Searchlight',r:'l',box:'supply',
    draw(x,w,h,t){bgBlit(x,bgLayer('search',w,h,(x,w,h)=>{vgrad(x,w,h,[[0,'#03050a'],[1,'#10182a']]);for(let i=0;i<70;i++){x.globalAlpha=.3+.6*hash(i,34);x.fillStyle='#e8eeff';x.fillRect(hash(i,35)*w,hash(i,36)*h*.7,1,1)}x.globalAlpha=1}),w,h);
      x.globalCompositeOperation='lighter';for(const[ox,ph,sp]of[[w*.2,0,.5],[w*.8,2.1,.37]]){const a=-Math.PI/2+Math.sin(t*sp+ph)*.7,L=h*1.2,oy=h*.8;
        const gr=x.createRadialGradient(ox,oy,0,ox,oy,L);gr.addColorStop(0,'rgba(255,245,210,.45)');gr.addColorStop(1,'rgba(255,245,210,0)');x.fillStyle=gr;
        x.beginPath();x.moveTo(ox,oy);x.lineTo(ox+Math.cos(a-.09)*L,oy+Math.sin(a-.09)*L);x.lineTo(ox+Math.cos(a+.09)*L,oy+Math.sin(a+.09)*L);x.closePath();x.fill();
        for(let i=0;i<14;i++){const d=(hash(i,37+ox|0)*L*.8+t*20)%(L*.8),sp2=(hash(i,38)-.5)*.14;x.globalAlpha=.6*(1-d/L);x.fillStyle='#fff6d8';x.fillRect(ox+Math.cos(a+sp2)*d,oy+Math.sin(a+sp2)*d,1.5,1.5)}x.globalAlpha=1}
      x.globalCompositeOperation='source-over';bgBlit(x,bgLayer('searchfg',w,h,(x,w,h)=>{bgFence(x,w,h*.84,'#05070b');x.fillStyle='#05070b';x.fillRect(0,h*.84,w,h);
        for(const px of[w*.2,w*.8]){x.fillRect(px-6,h*.78,12,h*.06);x.beginPath();x.arc(px,h*.8,9,Math.PI,0);x.fill()}}),w,h)}},
  // ---- Afterglow Case: neon, cosmic, gradient, gold
  sunsetfade:{name:'Sunset Fade',r:'r',box:'afterglow',still:0,
    draw(x,w,h){vgrad(x,w,h,[[0,'#2a0a3a'],[.45,'#ff5ad8'],[.72,'#ffa03a'],[.721,'#3a0a3a'],[1,'#1a0520']]);const cx=w/2,cy=h*.6,r=Math.min(w*.35,120);
      x.save();x.beginPath();x.arc(cx,cy,r,Math.PI,0);x.clip();const gr=x.createLinearGradient(0,cy-r,0,cy);gr.addColorStop(0,'#fff0a0');gr.addColorStop(1,'#ff6a4a');x.fillStyle=gr;x.fillRect(cx-r,cy-r,r*2,r);
      x.fillStyle='rgba(42,10,58,.9)';for(let k=0;k<7;k++){const yy=cy-r*.55+k*r*.08;x.fillRect(cx-r,yy,r*2,2+k*1.2)}x.restore();
      x.fillStyle='#2a0830';x.beginPath();x.moveTo(0,h*.72);for(let px=0;px<=w;px+=w/8)x.lineTo(px,h*.72-(Math.sin(px*.03)+1)*h*.05-hash(px|0,2)*h*.03);x.lineTo(w,h);x.lineTo(0,h);x.fill()}},
  lagoonwaves:{name:'Lagoon',r:'r',box:'afterglow',still:0,
    draw(x,w,h){vgrad(x,w,h,[[0,'#0a2a3a'],[1,'#062038']]);for(let k=0;k<9;k++){const y0=h*(.25+k*.09),c1=`hsla(${160+k*6},90%,${55-k*3}%,.9)`;x.fillStyle=c1;x.beginPath();x.moveTo(0,h);
      for(let px=0;px<=w+10;px+=10)x.lineTo(px,y0+Math.sin(px*.025+k*1.3)*12+Math.sin(px*.06+k)*4);x.lineTo(w,h);x.closePath();x.globalAlpha=.35+k*.05;x.fill()}x.globalAlpha=1}},
  nebula:{name:'Nebula',r:'e',box:'afterglow',still:0,
    draw(x,w,h){vgrad(x,w,h,[[0,'#07031a'],[1,'#12062a']]);x.globalCompositeOperation='lighter';for(let i=0;i<14;i++){const col=['rgba(192,122,255,.5)','rgba(58,106,255,.45)','rgba(255,138,216,.4)'][i%3],r=80+hash(i,40)*140;
      x.drawImage(bgBlob(col),w*(.1+.8*hash(i,41))-r,h*(.15+.7*hash(i,42))-r*.7,r*2,r*1.4)}x.globalCompositeOperation='source-over';
      for(let i=0;i<120;i++){x.globalAlpha=.4+.6*hash(i,43);x.fillStyle=i%11?'#ffffff':'#ffd8f0';const s=i%13?1:2;x.fillRect(hash(i,44)*w,hash(i,45)*h,s,s)}x.globalAlpha=1}},
  arcade:{name:'Arcade',r:'e',box:'afterglow',still:0,
    draw(x,w,h){vgrad(x,w,h,[[0,'#0a0620'],[1,'#140a30']]);const px=Math.max(4,Math.round(w/60)),inv=['0010000100','0001001000','0011111100','0110110110','1111111111','1011111101','1010000101','0001101100'];
      const cols=['#3affd8','#ff3ad0','#ffe03a','#6a8aff'];for(let r=0;r<4;r++)for(let c=0;c<3;c++){const ox=w*(.12+c*.3),oy=h*(.14+r*.13),col=cols[(r+c)%4];x.fillStyle=col;
        inv.forEach((row,j)=>[...row].forEach((b,i)=>{if(b==='1')x.fillRect(ox+i*px*.7,oy+j*px*.7,px*.7,px*.7)}))}
      x.fillStyle='#ffe03a';x.font=`700 ${Math.round(w/14)}px "IBM Plex Mono", monospace`;x.textAlign='center';x.fillText('INSERT COIN',w/2,h*.8);x.textAlign='left';
      for(let yy=0;yy<h;yy+=3){x.fillStyle='rgba(0,0,0,.28)';x.fillRect(0,yy,w,1)}}},
  neonpulse:{name:'Neon Pulse',r:'l',box:'afterglow',
    draw(x,w,h,t){bgBlit(x,bgLayer('neonp',w,h,(x,w,h)=>{vgrad(x,w,h,[[0,'#0a0412'],[1,'#1a0624']]);x.fillStyle='#07030c';for(let i=0;i<14;i++){const bw=w/10,bh=h*(.12+.3*hash(i,46));x.fillRect(i*bw*.8-10,h*.85-bh,bw*.7,bh+h)}}),w,h);
      x.globalCompositeOperation='lighter';for(let k=0;k<3;k++){const ph=(t*.35+k/3)%1,r=ph*Math.max(w,h)*.7;x.globalAlpha=(1-ph)*.7;x.strokeStyle=k%2?'#2af5ff':'#ff3ad0';x.lineWidth=3;x.beginPath();x.arc(w/2,h*.4,r,0,Math.PI*2);x.stroke()}
      const pl=.6+.4*Math.sin(t*6);x.globalAlpha=pl;x.strokeStyle='#ff3ad0';x.lineWidth=2;for(let i=0;i<14;i++){const bw=w/10,bh=h*(.12+.3*hash(i,46));if(i%3)continue;x.strokeRect(i*bw*.8-10,h*.85-bh,bw*.7,bh)}
      x.globalAlpha=1;x.globalCompositeOperation='source-over'}},
  eventhorizon:{name:'Event Horizon',r:'l',box:'afterglow',
    draw(x,w,h,t){bgBlit(x,bgLayer('horizon',w,h,(x,w,h)=>{vgrad(x,w,h,[[0,'#030208'],[1,'#0a0414']]);for(let i=0;i<120;i++){x.globalAlpha=.3+.6*hash(i,47);x.fillStyle='#ffffff';x.fillRect(hash(i,48)*w,hash(i,49)*h,1,1)}x.globalAlpha=1}),w,h);
      const cx=w/2,cy=h*.42,R=Math.min(w,h)*.42;x.globalCompositeOperation='lighter';for(let k=0;k<26;k++){const a0=t*(.6+k*.02)+k*.9,rr=R*(1+.05*(k%5));x.strokeStyle=k%3?`rgba(176,106,255,${.18+.1*(k%4)})`:`rgba(255,160,80,${.25})`;x.lineWidth=2+k%3;
        x.beginPath();x.ellipse(cx,cy,rr,rr*.32,-.2,a0,a0+1.4);x.stroke()}x.globalCompositeOperation='source-over';
      // light bent round the hole: a warm ring arcing over the top and under the bottom
      x.globalCompositeOperation='lighter';for(let k=0;k<5;k++){x.strokeStyle=k%2?`rgba(255,170,90,${.22-k*.03})`:`rgba(255,120,200,${.2-k*.03})`;x.lineWidth=6-k;const rr=R*(.7+k*.03),sp=Math.sin(t*1.3+k)*.05;
        x.beginPath();x.ellipse(cx,cy,rr,rr*.92,0,Math.PI*(1.05+sp),Math.PI*(1.95-sp));x.stroke();x.beginPath();x.ellipse(cx,cy,rr,rr*.55,0,Math.PI*(.12+sp),Math.PI*(.88-sp));x.stroke()}
      x.globalCompositeOperation='source-over';
      const gr=x.createRadialGradient(cx,cy,R*.3,cx,cy,R*.62);gr.addColorStop(0,'#000');gr.addColorStop(.85,'#000');gr.addColorStop(1,'rgba(255,150,90,.7)');x.fillStyle=gr;x.beginPath();x.arc(cx,cy,R*.62,0,Math.PI*2);x.fill();
      // and the near side of the disc passes in front of it
      x.globalCompositeOperation='lighter';for(let k=0;k<10;k++){const a0=t*(.6+k*.02)+k*.9;x.strokeStyle=k%3?'rgba(255,170,90,.25)':'rgba(176,106,255,.3)';x.lineWidth=2+k%3;
        x.beginPath();x.ellipse(cx,cy,R*(1+.04*(k%5)),R*(1+.04*(k%5))*.32,-.2,Math.max(a0%(Math.PI*2),.1),Math.max(a0%(Math.PI*2),.1)+.9);x.stroke()}x.globalCompositeOperation='source-over'}},
  goldaurora:{name:'Gold Aurora',r:'g',box:'afterglow',
    draw(x,w,h,t){bgBlit(x,bgLayer('gaur',w,h,(x,w,h)=>vgrad(x,w,h,[[0,'#0a0804'],[1,'#1a1408']])),w,h);x.globalCompositeOperation='lighter';
      for(let ci=0;ci<4;ci++){const top=s=>h*(.2+ci*.07)+Math.sin(s*.009+t*.5+ci*1.7)*h*.05,depth=h*.24,hue=(t*30+ci*60)%360;const gr=x.createLinearGradient(0,h*.15,0,h*.6);
        gr.addColorStop(0,'rgba(0,0,0,0)');gr.addColorStop(.3,ci?`hsla(${hue},90%,65%,.28)`:'rgba(255,215,110,.45)');gr.addColorStop(1,'rgba(0,0,0,0)');x.fillStyle=gr;
        x.beginPath();x.moveTo(0,top(0));for(let s=8;s<=w+8;s+=8)x.lineTo(s,top(s));for(let s=w+8;s>=0;s-=8)x.lineTo(s,top(s)+depth);x.closePath();x.fill()}
      x.globalCompositeOperation='source-over';for(let i=0;i<34;i++){const ph=(t*.8+hash(i,50)*3)%3;if(ph>.45)continue;const s=Math.sin(ph/.45*Math.PI)*4.5,px=hash(i,51)*w,py=hash(i,52)*h;
        x.strokeStyle='#fff6c8';x.lineWidth=1.1;x.beginPath();x.moveTo(px-s,py);x.lineTo(px+s,py);x.moveTo(px,py-s);x.lineTo(px,py+s);x.stroke()}}},
  // ---- Halloween Case (with Harvest Moon and Haunted Fog)
  graveyard:{name:'Graveyard',r:'r',box:'halloween',still:0,
    draw(x,w,h){vgrad(x,w,h,[[0,'#0a0c14'],[.7,'#1c2230'],[1,'#12141a']]);x.fillStyle='rgba(230,235,210,.85)';x.beginPath();x.arc(w*.78,h*.18,26,0,Math.PI*2);x.fill();
      for(let row=0;row<3;row++)for(let i=0;i<6;i++){const gx=w*(.05+i*.18)+row*18+hash(i,row+60)*12,base=h*(.66+row*.1),gh=34+row*10+hash(i,row+61)*14,gw=22+row*6;x.fillStyle=['#2a2e38','#20242c','#161a20'][row];
        if((i+row)%4===2){x.fillRect(gx-3,base-gh,6,gh);x.fillRect(gx-12,base-gh*.75,24,6)}else{x.beginPath();x.moveTo(gx-gw/2,base);x.lineTo(gx-gw/2,base-gh+gw/2);x.arc(gx,base-gh+gw/2,gw/2,Math.PI,0);x.lineTo(gx+gw/2,base);x.fill()}}
      x.fillStyle='#0c0e12';x.fillRect(0,h*.9,w,h);const fog=bgBlob('rgba(190,200,220,.4)');for(let i=0;i<6;i++){x.globalAlpha=.5;x.drawImage(fog,i*w/5-90,h*(.74+.06*(i%2)),200,60)}x.globalAlpha=1}},
  witchbrew:{name:"Witch's Brew",r:'e',box:'halloween',still:0,
    draw(x,w,h){vgrad(x,w,h,[[0,'#07050c'],[1,'#141022']]);bgTrees(x,w,h,h*.7,'#050409',71);const cx=w/2,cy=h*.76;
      x.globalCompositeOperation='lighter';x.drawImage(bgBlob('rgba(60,255,120,.55)'),cx-160,cy-260,320,300);x.globalCompositeOperation='source-over';
      x.fillStyle='#0e0c10';x.beginPath();x.ellipse(cx,cy,78,52,0,0,Math.PI*2);x.fill();x.fillStyle='#2aff6a';x.beginPath();x.ellipse(cx,cy-40,66,12,0,0,Math.PI*2);x.fill();
      x.fillStyle='#b8ff8a';for(const[a,b,r]of[[-20,-44,6],[14,-46,4],[34,-42,3],[-2,-60,5],[8,-82,3],[-14,-100,2]]){x.globalAlpha=.8;x.beginPath();x.arc(cx+a,cy+b,r,0,Math.PI*2);x.fill()}x.globalAlpha=1;
      x.strokeStyle='#0e0c10';x.lineWidth=6;for(const d of[-50,50]){x.beginPath();x.moveTo(cx+d,cy+30);x.lineTo(cx+d*1.3,cy+62);x.stroke()}x.fillStyle='#ff7a1a';x.globalAlpha=.8;x.beginPath();x.moveTo(cx-40,cy+64);x.quadraticCurveTo(cx,cy+30,cx+40,cy+64);x.fill();x.globalAlpha=1}},
  bloodmoon:{name:'Blood Moon',r:'l',box:'halloween',
    draw(x,w,h,t){bgBlit(x,bgLayer('blood',w,h,(x,w,h)=>{vgrad(x,w,h,[[0,'#0c0204'],[.6,'#2a060a'],[1,'#140306']]);const mx=w*.5,my=h*.32;const gr=x.createRadialGradient(mx,my,50,mx,my,220);
        gr.addColorStop(0,'rgba(255,40,40,.35)');gr.addColorStop(1,'rgba(255,40,40,0)');x.fillStyle=gr;x.fillRect(0,0,w,h);x.fillStyle='#c41e24';x.beginPath();x.arc(mx,my,70,0,Math.PI*2);x.fill();
        x.fillStyle='rgba(90,0,8,.45)';for(const[a,b,r]of[[-24,-12,15],[18,14,11],[-6,28,8],[26,-26,7]]){x.beginPath();x.arc(mx+a,my+b,r,0,Math.PI*2);x.fill()}bgTrees(x,w,h,h*.84,'#070103',81)}),w,h);
      for(let i=0;i<9;i++){const an=t*(.8+i*.07)+i*.7,rx=w*.5+Math.cos(an)*(90+i*9),ry=h*.32+Math.sin(an*1.3)*(40+i*5),f=Math.sin(t*20+i*2)*4;x.strokeStyle='#070103';x.lineWidth=2;
        x.beginPath();x.moveTo(rx-8,ry-f);x.lineTo(rx-3,ry);x.lineTo(rx,ry-2);x.lineTo(rx+3,ry);x.lineTo(rx+8,ry-f);x.stroke()}
      const fog=bgBlob('rgba(160,20,30,.4)');for(let i=0;i<5;i++){const cx=((t*12+i*170)%(w+320))-160;x.globalAlpha=.6;x.drawImage(fog,cx-150,h*(.78+.05*(i%2))-35,300,70)}x.globalAlpha=1}}
};
for(const k in BG_CASE)BGS[k]=Object.assign({src:'case'},BG_CASE[k]);
// the one call the lobby and the Locker use: still backgrounds are drawn once and reused
function drawBg(id,x,w,h,t){const B=BGS[id]||BGS.campfire;if(B.still!==undefined)bgBlit(x,bgLayer('still:'+id,w,h,(c,w,h)=>B.draw(c,w,h,B.still)),w,h);else B.draw(x,w,h,t)}
const BG_IDS=Object.keys(BGS);

// backgrounds are lobby cosmetics: Locker items like the rest (cat 'bg'), never sent to other players
for(const id of BG_IDS){const B=BGS[id],box=B.src==='case'?B.box:null,c={id:'bg:'+id,cat:'bg',key:id,name:B.name,r:B.r,src:B.src,box,need:B.need||null,
  how:B.how||(box?'Found in '+CASES[box].short:'Free'),price:null};COS.push(c);COSBY[c.id]=c}
CATN.bg='BACKGROUND';
locker=normLocker(locker);   // the locker loaded before these items existed: give the free ones and check the equipped one
const DEFAULT_BG='campfire',lobbyBgId=()=>BGS[locker.eq.bg]?locker.eq.bg:DEFAULT_BG;
// the lobby background canvas: shown whenever the menu is up outside a game (the demo yard behind it is never drawn)
let bgDrawn='',bgAt=0;
const LOBBY={bgFps:DESK?30:15,bgDpr:DESK?1.5:1,stageTouch:100,stageDesk:50};
function syncBg(){const on=!$('menu').hidden&&demo;$('lobbyBg').hidden=!on;bgDrawn=''}
const RM=matchMedia('(prefers-reduced-motion: reduce)'),reduceMotion=()=>RM.matches;
function drawLobbyBg(now){
  // Only the lobby's own pages show the background in full; behind the Locker, Settings and Account panels it's a still.
  // Animated ones run at a modest rate and resolution: they're soft gradients, glows and drifting specks, and every
  // repaint means the whole screen is composited again (that, not the drawing, was most of the menu's cost).
  const id=lobbyBgId(),B=BGS[id],c=$('lobbyBg'),still=B.still!==undefined||reduceMotion()||!stageVisible()||$('menu').dataset.page==='locker';   // the Locker's item grid is busy enough: a still there
  const dpr=Math.min(DPR,still?1.5:LOBBY.bgDpr),w=W,h=H,pw=Math.round(w*dpr),ph=Math.round(h*dpr),key=id+'|'+pw+'x'+ph+(still?'|s':'');
  if(still&&bgDrawn===key)return;                         // a still background is drawn once
  if(!still&&bgDrawn===key&&now-bgAt<1000/LOBBY.bgFps)return;
  bgAt=now;bgDrawn=key;if(c.width!==pw||c.height!==ph){c.width=pw;c.height=ph}
  const x=c.getContext('2d');x.setTransform(dpr,0,0,dpr,0,0);x.clearRect(0,0,w,h);drawBg(id,x,w,h,still?4:now/1000);
}
