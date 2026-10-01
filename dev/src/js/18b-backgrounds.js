/* ---------- lobby backgrounds ----------
   Chosen in the Locker, drawn behind your character in the lobby. Each one is a static layer (drawn once per screen
   size and cached) plus a light animated layer. draw(x,w,h,t): x is a 2D context already scaled to CSS pixels, t seconds.
   src: free / unlock (need: a stat goal, like the other unlocks) / case (found in that case). */
const BG_CACHE=new Map(),BG_CACHE_LIMIT=48*1024*1024;
let bgCacheBytes=0;
function bgLayer(key,w,h,paint){
  // Bound both raster resolution and retained memory; resizing / collection thumbnails must not flush every scene.
  const dp=Math.min(1.5,window.devicePixelRatio||1,Math.sqrt(4*1024*1024/(w*h))),k=key+'|'+w+'x'+h+'@'+dp;
  let c=BG_CACHE.get(k);if(c){BG_CACHE.delete(k);BG_CACHE.set(k,c);return c}
  c=document.createElement('canvas');c.width=Math.ceil(w*dp);c.height=Math.ceil(h*dp);const x=c.getContext('2d');x.scale(c.width/w,c.height/h);paint(x,w,h);
  // Bake scenic detail into an existing layer when possible: no additional full-screen blit per animated frame.
  if(BG_DEPTH_LAYER[key]&&BG_REFINEMENTS[BG_DEPTH_LAYER[key]])bgScenicDetail(BG_DEPTH_LAYER[key],x,w,h);
  const bytes=c.width*c.height*4;
  while(BG_CACHE.size&&(BG_CACHE.size>=24||bgCacheBytes+bytes>BG_CACHE_LIMIT)){const first=BG_CACHE.keys().next().value,old=BG_CACHE.get(first);bgCacheBytes-=old.width*old.height*4;BG_CACHE.delete(first)}
  BG_CACHE.set(k,c);bgCacheBytes+=bytes;return c;
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
      const fog=bgBlob('rgba(160,20,30,.4)');for(let i=0;i<5;i++){const cx=((t*12+i*170)%(w+320))-160;x.globalAlpha=.6;x.drawImage(fog,cx-150,h*(.78+.05*(i%2))-35,300,70)}x.globalAlpha=1}},
  // ---- v0.9.4.0 Blitzkrieg Case
  scorched:{name:'Scorched Front',r:'e',box:'blitz',still:0,
    draw(x,w,h){vgrad(x,w,h,[[0,'#1a0f10'],[.42,'#5a2414'],[.62,'#c0561e'],[.66,'#3a1a12'],[1,'#120a08']]);
      const smoke=bgBlob('rgba(30,20,20,.85)'),glow=bgBlob('rgba(255,120,40,.7)');
      for(let i=0;i<5;i++){const cx=w*(.12+.2*i+hash(i,91)*.06),by=h*.64;for(let k=0;k<6;k++){x.globalAlpha=.5-k*.06;x.drawImage(smoke,cx-40-k*14+Math.sin(k+i)*10,by-60-k*48,80+k*28,70+k*20)}}x.globalAlpha=1;
      x.fillStyle='#0d0806';x.beginPath();x.moveTo(0,h*.66);for(let px=0;px<=w;px+=w/24){const q=px/w,hh=(q>.28&&q<.72?h*.12:h*.05)*(q>.28&&q<.72&&Math.floor(q*24)%2?1.25:1)+hash(Math.floor(q*24),92)*h*.03;x.lineTo(px,h*.66-hh)}x.lineTo(w,h);x.lineTo(0,h);x.closePath();x.fill();   // the broken fort
      for(let i=0;i<9;i++){const fx=w*hash(i,93),fy=h*(.6+.06*hash(i,94));x.globalAlpha=.7;x.drawImage(glow,fx-30,fy-24,60,40);x.globalAlpha=1;x.fillStyle=i%2?'#ffb040':'#ff6a1a';x.beginPath();x.moveTo(fx-5,fy+4);x.quadraticCurveTo(fx,fy-14-hash(i,95)*10,fx+5,fy+4);x.fill()}
      x.fillStyle='rgba(255,140,60,.08)';for(let k=0;k<6;k++)x.fillRect(0,h*.57+k*5,w,2);   // heat haze
      for(let i=0;i<60;i++){x.globalAlpha=.3+.6*hash(i,96);x.fillStyle=i%3?'#ff8a3a':'#ffd06a';x.fillRect(hash(i,97)*w,hash(i,98)*h*.8,1.6,1.6)}x.globalAlpha=1}},
  hellgate:{name:'Hellgate',r:'g',box:'blitz',
    // The showcase: a colossal gate with a turning hellfire vortex, and every few seconds the Blue Butcher's arc cuts a
    // teal rift across the sky that seals again. Everything that doesn't move is one cached layer; each frame draws the
    // vortex (three rotated sprites), one pulse glow, the arc sweep and about 40 embers: no full-screen gradients.
    draw(x,w,h,t){const gx=w*.5,gy=h*.5,G=Math.min(w*.5,h*.86);
      bgBlit(x,bgLayer('hellgate',w,h,(x,w,h)=>hellgateScene(x,w,h)),w,h);
      const pulse=.5+.5*Math.sin(t*1.7),vr=G*.3,vy=gy-G*.06;
      x.save();x.globalCompositeOperation='lighter';x.globalAlpha=.5+.3*pulse;x.drawImage(bgBlob('rgba(255,60,20,.8)'),gx-vr*1.9,vy-vr*1.9,vr*3.8,vr*3.8);
      for(let k=0;k<3;k++){x.save();x.globalAlpha=.55-.12*k;x.translate(gx,vy);x.rotate(t*(.35+k*.22)*(k%2?-1:1));x.scale(1,.92);x.drawImage(hellSpiral(k),-vr,-vr,vr*2,vr*2);x.restore()}
      x.restore();
      const ph=(t%7)/7;if(ph>.62&&ph<.78){const k=(ph-.62)/.16,bi=Math.floor(t/7)%5;x.globalAlpha=Math.sin(k*Math.PI)*.55;hellSilhouette(x,gx,vy+vr*.35,vr*.62,bi);x.globalAlpha=1}   // a Blitzkrieg boss shows in the fire
      const sw=(t%6)/6;if(sw<.32){const k=sw/.32,ax=-w*.1+w*1.2*k,ay=h*(.18+.1*Math.sin(k*Math.PI));   // the arc sweeps across the sky...
        x.save();x.globalCompositeOperation='lighter';for(const[lw,col]of[[16,'rgba(40,200,220,.25)'],[7,'rgba(90,240,255,.8)'],[2.4,'#eaffff']]){x.strokeStyle=col;x.lineWidth=lw;x.beginPath();x.arc(ax-40,ay,70,-.75,.75);x.stroke()}
        x.globalAlpha=.8;x.strokeStyle='rgba(90,240,255,.6)';x.lineWidth=2;x.beginPath();x.moveTo(-w*.1,h*.2);for(let q=0;q<=k;q+=.05)x.lineTo(-w*.1+w*1.2*q,h*(.18+.1*Math.sin(q*Math.PI)));x.stroke();x.restore()}
      else if(sw<.5){const k=(sw-.32)/.18;x.save();x.globalCompositeOperation='lighter';x.globalAlpha=(1-k)*.7;x.strokeStyle='rgba(90,240,255,.7)';x.lineWidth=3*(1-k)+.5;x.beginPath();   // ...and the rift seals
        for(let q=0;q<=1;q+=.04){const px=-w*.1+w*1.2*q,py=h*(.18+.1*Math.sin(q*Math.PI))+Math.sin(q*40+t*9)*2*(1-k);q?x.lineTo(px,py):x.moveTo(px,py)}x.stroke();x.restore()}
      for(let i=0;i<40;i++){const p2=(t*.1*(0.5+hash(i,101))+hash(i,102))%1,ex=hash(i,103)*w+Math.sin(t*1.6+i)*12,ey=h*(1.02-p2*.95);   // embers and ash rising
        x.globalAlpha=Math.sin(p2*Math.PI)*.9;x.fillStyle=i%5===0?'#bdb4ac':i%3?'#ff7a2a':'#ffd070';x.fillRect(ex,ey,i%4?1.6:2.4,i%4?1.6:2.4)}x.globalAlpha=1}}
};
for(const k in BG_CASE)BGS[k]=Object.assign({src:'case'},BG_CASE[k]);
// v0.9.4.0 Hellgate: the still layer (sky, mountains, the gate with its burning veins, the ruins in front)
function hellgateScene(x,w,h){
  vgrad(x,w,h,[[0,'#050103'],[.45,'#2a0608'],[.6,'#6a1a0c'],[.64,'#1a0606'],[1,'#080203']]);
  const gx=w*.5,gy=h*.5,G=Math.min(w*.5,h*.86),hz=h*.62;
  x.fillStyle='#120406';x.beginPath();x.moveTo(0,hz);for(let px=0;px<=w;px+=w/30){x.lineTo(px,hz-h*(.05+.09*hash(Math.round(px/w*30),111))-(Math.abs(px-gx)<G*.7?0:h*.03))}x.lineTo(w,hz+2);x.lineTo(0,hz+2);x.closePath();x.fill();
  const vr=G*.3,vy=gy-G*.06;const gr=x.createRadialGradient(gx,vy,0,gx,vy,vr);gr.addColorStop(0,'#ffb040');gr.addColorStop(.35,'#c8200a');gr.addColorStop(1,'#1a0204');x.fillStyle=gr;x.beginPath();x.arc(gx,vy,vr,0,Math.PI*2);x.fill();
  // the gate: two pillars, a pointed arch, horned finials; black rock with burning veins
  const pw=G*.13,px0=gx-vr-pw*.75,px1=gx+vr-pw*.25,top=vy-vr*1.25;x.fillStyle='#231012';
  for(const px of[px0,px1]){x.fillRect(px,top,pw,hz-top+h*.03);x.beginPath();x.moveTo(px-pw*.2,top);x.lineTo(px+pw*.5,top-G*.12);x.lineTo(px+pw*1.2,top);x.closePath();x.fill()}
  x.beginPath();x.moveTo(px0,top+G*.04);x.quadraticCurveTo(gx,vy-vr*2.1,px1+pw,top+G*.04);x.lineTo(px1+pw,top+G*.14);x.quadraticCurveTo(gx,vy-vr*1.55,px0,top+G*.14);x.closePath();x.fill();
  for(const sd of[-1,1]){x.beginPath();x.moveTo(gx+sd*vr*.3,vy-vr*1.45);x.quadraticCurveTo(gx+sd*vr*.9,vy-vr*2.1,gx+sd*vr*1.3,vy-vr*1.95);x.quadraticCurveTo(gx+sd*vr*.8,vy-vr*1.8,gx+sd*vr*.5,vy-vr*1.36);x.closePath();x.fill()}
  x.fillStyle='rgba(255,90,40,.18)';for(const px of[px0,px1])x.fillRect(px+pw*.82,top,pw*.18,hz-top);   // rim light from the fire
  x.strokeStyle='rgba(255,110,30,.75)';x.lineWidth=1.4;x.lineJoin='round';
  for(let i=0;i<14;i++){const pl=i%2?px0:px1,sx=pl+pw*(.2+.6*hash(i,112)),sy=top+(hz-top)*hash(i,113);x.beginPath();x.moveTo(sx,sy);let cx=sx,cy=sy;for(let k=0;k<4;k++){cx+=(hash(i*7+k,114)-.5)*pw*.5;cy+=G*.05*(hash(i*7+k,115)+.3);x.lineTo(clamp(cx,pl+2,pl+pw-2),cy)}x.stroke()}
  x.strokeStyle='rgba(255,150,60,.5)';x.lineWidth=2.2;x.beginPath();x.arc(gx,vy,vr+2,0,Math.PI*2);x.stroke();
  // ruined battlements in front, and the burning ground
  x.fillStyle='#050203';for(const[sx,sw2,sh]of[[0,w*.24,h*.2],[w*.78,w*.22,h*.23]]){x.beginPath();x.moveTo(sx,h);x.lineTo(sx,h-sh);for(let q=0;q<6;q++){const qx=sx+sw2*q/6;x.lineTo(qx,h-sh-(q%2?0:h*.035)-hash(q+sx,116)*h*.02);x.lineTo(qx+sw2/6,h-sh-(q%2?0:h*.035))}x.lineTo(sx+sw2,h-sh*.6+hash(sx,117)*h*.05);x.lineTo(sx+sw2,h);x.closePath();x.fill()}
  x.strokeStyle='rgba(255,90,20,.45)';x.lineWidth=1.3;for(let i=0;i<8;i++){const sx=w*hash(i,118),sy=h*(.72+.22*hash(i,119));x.beginPath();x.moveTo(sx,sy);x.lineTo(sx+(hash(i,120)-.5)*60,sy+8+hash(i,121)*14);x.stroke()}
}
// three hellfire spiral sprites for the Hellgate vortex, painted once
const HELL_SP=[];
function hellSpiral(k){if(HELL_SP[k])return HELL_SP[k];const c=document.createElement('canvas');c.width=c.height=192;const x=c.getContext('2d');x.translate(96,96);
  const cols=[['rgba(255,190,80,.9)','rgba(255,90,20,.7)'],['rgba(255,120,40,.8)','rgba(180,20,10,.6)'],['rgba(255,220,140,.7)','rgba(255,70,20,.5)']][k];
  for(let arm=0;arm<3;arm++){x.beginPath();for(let q=0;q<=60;q++){const a=arm*Math.PI*2/3+q*.09+k,r=4+q*1.45;q?x.lineTo(Math.cos(a)*r,Math.sin(a)*r):x.moveTo(Math.cos(a)*r,Math.sin(a)*r)}x.strokeStyle=cols[arm%2];x.lineWidth=5-k;x.lineCap='round';x.stroke()}
  HELL_SP[k]=c;return c}
// one of the five Blitzkrieg bosses as a dark shape in the fire (sword, launcher, lightning rifle, missiles, drill)
function hellSilhouette(x,cx,by,s,i){x.fillStyle='#0a0204';x.beginPath();x.ellipse(cx,by-s*.62,s*.16,s*.16,0,0,Math.PI*2);x.fill();
  x.beginPath();x.moveTo(cx-s*.24,by-s*.46);x.lineTo(cx+s*.24,by-s*.46);x.lineTo(cx+s*.18,by);x.lineTo(cx-s*.18,by);x.closePath();x.fill();
  x.strokeStyle='#0a0204';x.lineWidth=s*.07;x.lineCap='round';x.beginPath();
  if(i===0){x.moveTo(cx+s*.2,by-s*.4);x.lineTo(cx+s*.62,by-s*.95)}else if(i===1||i===3){x.moveTo(cx-s*.1,by-s*.5);x.lineTo(cx+s*.6,by-s*.6)}else if(i===2){x.moveTo(cx+s*.1,by-s*.3);x.lineTo(cx+s*.62,by-s*.42)}else{x.moveTo(cx+s*.2,by-s*.28);x.lineTo(cx+s*.55,by-s*.2)}x.stroke()}
/* Full-bleed flags: fields adapt to the viewport, emblems use a uniform unit.
   The original flag geometry remains the source of truth; no generated flag artwork. */
function star5(x,cx,cy,r,col,rot=-Math.PI/2){x.fillStyle=col;x.beginPath();for(let i=0;i<10;i++){const a=rot+i*Math.PI/5,rr=i%2?r*.382:r;i?x.lineTo(cx+Math.cos(a)*rr,cy+Math.sin(a)*rr):x.moveTo(cx+Math.cos(a)*rr,cy+Math.sin(a)*rr)}x.closePath();x.fill()}
function drawFlag(x,id,W,H){
  const U=Math.min(H,W/1.5),tri=Math.min(H*.866,W*.56);
  const hw=(pairs)=>{const tot=pairs.reduce((a,p)=>a+p[1],0);let y=0;for(const[c,n]of pairs){x.fillStyle=c;x.fillRect(0,Math.floor(y),W,Math.ceil(H*n/tot)+1);y+=H*n/tot}};
  const hs=cols=>hw(cols.map(c=>[c,1])),vs=(cols,wt)=>{const w=wt||cols.map(()=>1),tot=w.reduce((a,b)=>a+b,0);let px=0;cols.forEach((c,i)=>{x.fillStyle=c;x.fillRect(Math.floor(px),0,Math.ceil(W*w[i]/tot)+1,H);px+=W*w[i]/tot})};
  const poly=(pts,c)=>{x.fillStyle=c;x.beginPath();pts.forEach((p,i)=>i?x.lineTo(p[0],p[1]):x.moveTo(p[0],p[1]));x.closePath();x.fill()};
  const disc=(cx,cy,r,c)=>{x.fillStyle=c;x.beginPath();x.arc(cx,cy,r,0,Math.PI*2);x.fill()};
  const F=Object.fromEntries(FLAGS.map(f=>[f[0],f[3]])),B=F[id];
  switch(id){
    case'progress':{hs(['#e40303','#ff8c00','#ffed00','#008026','#004dff','#750787']);const b=W*.062;
      [['#000000',4],['#613915',3],['#5bcefa',2],['#f5a9b8',1],['#ffffff',0]].forEach(([c,k])=>{const d=b*k;poly([[0,0],[d,0],[d+Math.min(H/2,W*.32),H/2],[d,H],[0,H]],c)});break}
    case'bi':hw([['#d60270',2],['#9b4f96',1],['#0038a8',2]]);break;
    case'intersex':x.fillStyle='#ffd800';x.fillRect(0,0,W,H);x.strokeStyle='#7902aa';x.lineWidth=U*.075;x.beginPath();x.arc(W/2,H/2,U*.22,0,Math.PI*2);x.stroke();break;
    case'usa':{for(let i=0;i<13;i++){x.fillStyle=i%2?'#ffffff':'#b22234';x.fillRect(0,Math.floor(i*H/13),W,Math.ceil(H/13)+1)}const cw=W*.4,ch=H*7/13;x.fillStyle='#3c3b6e';x.fillRect(0,0,cw,ch);
      for(let r=0;r<9;r++){const n=r%2?5:6;for(let k=0;k<n;k++)star5(x,cw*((r%2?2:1)+k*2)/12,ch*(r+1)/10,Math.min(ch*.042,cw*.035),'#ffffff')}break}
    case'mexico':vs(B);x.fillStyle='#8a5a2a';x.beginPath();x.ellipse(W/2,H*.5-U*.03,U*.09,U*.12,0,0,Math.PI*2);x.fill();x.strokeStyle='#2e7a3a';x.lineWidth=U*.025;x.beginPath();x.arc(W/2,H*.5,U*.15,Math.PI*.15,Math.PI*.85);x.stroke();
      x.fillStyle='#5a3a1a';x.beginPath();x.ellipse(W/2-U*.05,H*.5-U*.1,U*.035,U*.05,-.5,0,Math.PI*2);x.fill();break;
    case'brazil':{x.fillStyle='#009c3b';x.fillRect(0,0,W,H);poly([[W/2-U*.6225,H/2],[W/2,H/2-U*.415],[W/2+U*.6225,H/2],[W/2,H/2+U*.415]],'#ffdf00');const r=U*.25;disc(W/2,H/2,r,'#002776');
      x.save();x.beginPath();x.arc(W/2,H/2,r,0,Math.PI*2);x.clip();x.strokeStyle='#ffffff';x.lineWidth=r*.16;x.beginPath();x.arc(W/2-r*.3,H/2+r*1.6,r*1.9,-Math.PI*.68,-Math.PI*.28);x.stroke();x.restore();
      for(let i=0;i<9;i++)disc(W/2+(hash(i,71)-.5)*r*1.3,H/2+r*.15+hash(i,72)*r*.6,r*.03,'#ffffff');break}
    case'japan':x.fillStyle='#ffffff';x.fillRect(0,0,W,H);disc(W/2,H/2,U*.3,'#bc002d');break;
    case'skorea':{x.fillStyle='#ffffff';x.fillRect(0,0,W,H);const R=U/4,th=Math.atan2(1,1.5);x.save();x.translate(W/2,H/2);x.rotate(th);
      x.fillStyle='#cd2e3a';x.beginPath();x.arc(0,0,R,Math.PI,0);x.fill();x.fillStyle='#0047a0';x.beginPath();x.arc(0,0,R,0,Math.PI);x.fill();
      x.fillStyle='#cd2e3a';x.beginPath();x.arc(R/2,0,R/2,0,Math.PI);x.fill();x.fillStyle='#0047a0';x.beginPath();x.arc(-R/2,0,R/2,Math.PI,0);x.fill();x.restore();
      const bar=(solid)=>{if(solid)x.fillRect(-R*.5,0,R,R*.12);else{x.fillRect(-R*.5,0,R*.44,R*.12);x.fillRect(R*.06,0,R*.44,R*.12)}};
      for(const[ang,pat]of[[Math.PI+th,[1,1,1]],[-th,[0,1,0]],[th,[0,0,0]],[Math.PI-th,[1,0,1]]]){x.save();x.translate(W/2+Math.cos(ang)*R*1.8,H/2+Math.sin(ang)*R*1.8);x.rotate(ang+Math.PI/2);x.fillStyle='#000000';
        pat.forEach((sd,k)=>{x.save();x.translate(0,(k-1)*R*.2-R*.06);bar(sd);x.restore()});x.restore()}break}
    case'puertorico':{for(let i=0;i<5;i++){x.fillStyle=i%2?'#ffffff':'#ed0000';x.fillRect(0,Math.floor(i*H/5),W,Math.ceil(H/5)+1)}poly([[0,0],[tri,H/2],[0,H]],'#0050f0');star5(x,tri/3,H/2,Math.min(U*.13,tri*.2),'#ffffff');break}
    case'canada':{vs(B,[1,2,1]);x.save();x.translate(W/2,H*.55);const k=U*.0065;x.scale(k,k);
      poly([[0,-48],[8,-32],[16,-38],[12,-16],[26,-26],[30,-18],[44,-22],[38,-6],[46,-2],[22,14],[26,24],[3,20],[3,40],[-3,40],[-3,20],[-26,24],[-22,14],[-46,-2],[-38,-6],[-44,-22],[-30,-18],[-26,-26],[-12,-16],[-16,-38],[-8,-32]],'#d52b1e');x.restore();break}
    case'uk':{x.fillStyle='#012169';x.fillRect(0,0,W,H);x.lineCap='butt';const ln=(w,c,a,b)=>{x.strokeStyle=c;x.lineWidth=w;x.beginPath();x.moveTo(...a);x.lineTo(...b);x.stroke()};
      for(const[a,b]of[[[0,0],[W,H]],[[W,0],[0,H]]]){ln(U*.2,'#ffffff',a,b);ln(U*.067,'#c8102e',a,b)}ln(U/3,'#ffffff',[W/2,0],[W/2,H]);ln(U/3,'#ffffff',[0,H/2],[W,H/2]);ln(U*.2,'#c8102e',[W/2,0],[W/2,H]);ln(U*.2,'#c8102e',[0,H/2],[W,H/2]);break}
    case'france':case'italy':case'ireland':vs(B);break;
    case'spain':{hw([['#aa151b',1],['#f1bf00',2],['#aa151b',1]]);const cx=W*.31,cy=H*.5;x.fillStyle='#aa151b';x.fillRect(cx-U*.0675,cy-U*.13,U*.135,U*.26);x.fillStyle='#f1bf00';x.fillRect(cx-U*.045,cy-U*.11,U*.045,U*.1);x.fillStyle='#c8b8a0';x.fillRect(cx-U*.105,cy-U*.15,U*.0225,U*.3);x.fillRect(cx+U*.0825,cy-U*.15,U*.0225,U*.3);break}
    case'argentina':{hs(B);x.strokeStyle='#f6b40e';x.lineWidth=U*.012;for(let i=0;i<16;i++){const a=i*Math.PI/8;x.beginPath();x.moveTo(W/2+Math.cos(a)*U*.085,H/2+Math.sin(a)*U*.085);x.lineTo(W/2+Math.cos(a)*U*.14,H/2+Math.sin(a)*U*.14);x.stroke()}disc(W/2,H/2,U*.08,'#f6b40e');break}
    case'philippines':{hs(['#0038a8','#ce1126']);poly([[0,0],[tri,H/2],[0,H]],'#ffffff');const sx=tri/3,sy=H/2;x.strokeStyle='#fcd116';x.lineWidth=U*.02;
      for(let i=0;i<8;i++){const a=i*Math.PI/4;x.beginPath();x.moveTo(sx+Math.cos(a)*U*.07,sy+Math.sin(a)*U*.07);x.lineTo(sx+Math.cos(a)*U*.13,sy+Math.sin(a)*U*.13);x.stroke()}
      disc(sx,sy,U*.065,'#fcd116');for(const[a,b]of[[tri*.08,H*.09],[tri*.08,H*.91],[tri*.85,H/2]])star5(x,a,b,U*.04,'#fcd116');break}
    case'india':{hs(B);x.strokeStyle='#000080';x.lineWidth=U*.012;x.beginPath();x.arc(W/2,H/2,U*.14,0,Math.PI*2);x.stroke();for(let i=0;i<24;i++){const a=i*Math.PI/12;x.beginPath();x.moveTo(W/2,H/2);x.lineTo(W/2+Math.cos(a)*U*.14,H/2+Math.sin(a)*U*.14);x.stroke()}disc(W/2,H/2,U*.025,'#000080');break}
    case'israel':{x.fillStyle='#ffffff';x.fillRect(0,0,W,H);x.fillStyle='#0038b8';x.fillRect(0,H*.1,W,H*.15);x.fillRect(0,H*.75,W,H*.15);x.strokeStyle='#0038b8';x.lineWidth=U*.03;x.lineJoin='miter';
      for(const rot of[-Math.PI/2,Math.PI/2]){x.beginPath();for(let i=0;i<3;i++){const a=rot+i*Math.PI*2/3;i?x.lineTo(W/2+Math.cos(a)*U*.19,H/2+Math.sin(a)*U*.19):x.moveTo(W/2+Math.cos(a)*U*.19,H/2+Math.sin(a)*U*.19)}x.closePath();x.stroke()}break}
    case'nkorea':hw([['#024fa2',6],['#ffffff',1],['#ed1c27',15],['#ffffff',1],['#024fa2',6]]);disc(W*.36,H/2,U*.19,'#ffffff');star5(x,W*.36,H/2,U*.18,'#ed1c27');break;
    default:hs(B||['#888888']);
  }
}
function flagScene(x,w,h,t,id,moving){
  const flat=bgLayer('flag:'+id,w,h,(c,W,H)=>{
    drawFlag(c,id,W,H);
    // A light fabric finish leaves all field colours recognizable and the menus readable.
    const shade=c.createLinearGradient(0,0,0,H);shade.addColorStop(0,'rgba(5,10,18,.13)');shade.addColorStop(.45,'rgba(5,10,18,.03)');shade.addColorStop(1,'rgba(5,10,18,.22)');c.fillStyle=shade;c.fillRect(0,0,W,H);
  });
  bgBlit(x,flat,w,h);
  // Moving light across unbroken cloth, rather than displaced strips: no seams or exposed edges.
  const phase=moving&&!reduceMotion()?t*.48:0,band=w*.24;
  for(let i=-1;i<6;i++){
    const px=((i/5+phase*.07)%1.4-.2)*w,gr=x.createLinearGradient(px,0,px+band,0);
    gr.addColorStop(0,'rgba(0,0,0,0)');gr.addColorStop(.35,'rgba(0,0,0,.075)');gr.addColorStop(.65,'rgba(255,255,255,.055)');gr.addColorStop(1,'rgba(255,255,255,0)');x.fillStyle=gr;x.fillRect(px,0,band,h);
  }
}
for(const[id,name,r]of FLAGS){const moving=r==='l'||r==='g';BGS['f_'+id]=Object.assign({name:name+' Flag',r,src:'case',box:'flags',draw(x,w,h,t){flagScene(x,w,h,t,id,moving)}},moving?{}:{still:0})}
// the one call the lobby and the Locker use: still backgrounds are drawn once and reused
function drawBg(id,x,w,h,t){const B=BGS[id]||BGS.campfire;if(B.still!==undefined)bgBlit(x,bgLayer('still:'+id,w,h,(c,w,h)=>B.draw(c,w,h,B.still)),w,h);else B.draw(x,w,h,t)}
registerWinterBackgrounds();
const BG_IDS=Object.keys(BGS);

// backgrounds are lobby cosmetics: Locker items like the rest (cat 'bg'), never sent to other players
for(const id of BG_IDS){const B=BGS[id],box=B.src==='case'?B.box:null,c={id:'bg:'+id,cat:'bg',key:id,name:B.name,r:B.r,src:B.src,box,need:B.need||null,
  how:B.how||(box?'Found in '+CASES[box].short:'Free'),description:B.description,collection:B.collection,animated:!!B.animated,price:null};COS.push(c);COSBY[c.id]=c}
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
