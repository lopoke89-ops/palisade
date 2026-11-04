/* v0.12 THE UNDERSTRIP CASE backgrounds. Each is one cached layer (drawn once per screen size) and a light animated layer
   inside the existing background budget: drips, a light through the vault door, two searchlights and a hovering light,
   chasing neon, glowing tanks. Generic retro neon only: no real casino's sign, no real seal or insignia (work order 3). */
function paintUnderstripBackground(c,w,h,t,id,moving){
  const P=US_SCENES[id];if(!P)return;bgBlit(c,bgLayer('us:'+id,w,h,(x,w,h)=>P.base(x,w,h)),w,h);if(moving&&P.live)P.live(c,w,h,t)}
const usGlow=(x,X,Y,r,col,a=1)=>{const gr=x.createRadialGradient(X,Y,0,X,Y,r);gr.addColorStop(0,col);gr.addColorStop(1,'rgba(0,0,0,0)');x.globalAlpha=a;x.fillStyle=gr;x.fillRect(X-r,Y-r,r*2,r*2);x.globalAlpha=1};
const US_SCENES={
  // the flood tunnels: a concrete barrel vault, a lit grate high up, a drain channel, dripping
  floodtunnels:{base(x,w,h){vgrad(x,w,h,[[0,'#0d100e'],[.55,'#1b211d'],[1,'#0a0c0b']]);
      const cx=w/2,top=h*.18;x.fillStyle='#232a25';x.beginPath();x.moveTo(0,h);x.lineTo(0,h*.42);x.quadraticCurveTo(cx,-h*.12,w,h*.42);x.lineTo(w,h);x.fill();
      for(let i=0;i<9;i++){x.strokeStyle='rgba(0,0,0,.35)';x.lineWidth=2;x.beginPath();const k=i/8;x.moveTo(k*w,h);x.lineTo(cx+(k-.5)*w*.3,h*.5);x.stroke()}   // the vault's courses
      x.fillStyle='#141815';for(let i=0;i<5;i++){const y=h*(.46+i*.1);x.fillRect(0,y,w,2)}
      // the grate and its light
      usGlow(x,cx,top+h*.1,h*.55,'rgba(255,214,140,.35)');x.fillStyle='#3a3426';x.fillRect(cx-w*.08,top,w*.16,h*.06);x.fillStyle='rgba(255,226,160,.85)';for(let i=0;i<7;i++)x.fillRect(cx-w*.075+i*w*.022,top+h*.008,w*.012,h*.044);
      // light falling in a shaft
      const gr=x.createLinearGradient(0,top,0,h);gr.addColorStop(0,'rgba(255,220,150,.22)');gr.addColorStop(1,'rgba(255,220,150,0)');x.fillStyle=gr;x.beginPath();x.moveTo(cx-w*.08,top+h*.06);x.lineTo(cx+w*.08,top+h*.06);x.lineTo(cx+w*.2,h);x.lineTo(cx-w*.2,h);x.fill();
      // the channel and graffiti on the walls (no words)
      x.fillStyle='#16303c';x.fillRect(0,h*.86,w,h*.07);x.fillStyle='rgba(120,190,210,.25)';x.fillRect(0,h*.86,w,2);
      for(let i=0;i<6;i++){x.strokeStyle=['#ff5ad8','#5ab0ff','#e2b436'][i%3];x.globalAlpha=.35;x.lineWidth=4;x.beginPath();const X=w*(.08+i*.16),Y=h*(.6+hash(i,4)*.12);x.moveTo(X,Y);x.bezierCurveTo(X+20,Y-30,X+40,Y+20,X+60,Y-10);x.stroke()}x.globalAlpha=1;
      vgrad(x,w,h,[[0,'rgba(0,0,0,.25)'],[.6,'rgba(0,0,0,0)'],[1,'rgba(0,0,0,.6)']])},
    live(c,w,h,t){c.save();for(let i=0;i<7;i++){const X=w*(.12+hash(i,8)*.76),per=1.6+hash(i,9)*1.4,k=((t+hash(i,10)*per)%per)/per,y0=h*(.2+hash(i,11)*.2),y=y0+(h*.86-y0)*k*k;
        c.fillStyle='rgba(180,220,230,.7)';c.fillRect(X,y,2,6);if(k>.94){c.strokeStyle='rgba(180,220,230,.5)';c.lineWidth=1;c.beginPath();c.ellipse(X,h*.875,10*(k-.94)*20,3,0,0,Math.PI*2);c.stroke()}}
      c.globalAlpha=.08+.05*Math.sin(t*1.3);c.fillStyle='#ffe0a0';c.fillRect(0,0,w,h);c.restore()}},
  // the vault door: a huge round door ajar, gold light through it and across the floor
  vaultdoor:{base(x,w,h){vgrad(x,w,h,[[0,'#0e0c08'],[.6,'#1d1810'],[1,'#0a0806']]);
      const cx=w*.52,cy=h*.5,R=Math.min(w,h)*.36;usGlow(x,cx,cy,R*1.7,'rgba(255,200,90,.35)');
      x.fillStyle='#2a2418';x.beginPath();x.arc(cx,cy,R*1.12,0,Math.PI*2);x.fill();x.fillStyle='#ffd57a';x.beginPath();x.arc(cx,cy,R,0,Math.PI*2);x.fill();   // the opening, full of light
      x.fillStyle='#6a5a3a';x.beginPath();x.ellipse(cx+R*.62,cy,R*.42,R,0,0,Math.PI*2);x.fill();x.strokeStyle='#3a3020';x.lineWidth=R*.05;for(const k of[.7,.5,.3]){x.beginPath();x.ellipse(cx+R*.62,cy,R*.42*k,R*k,0,0,Math.PI*2);x.stroke()}   // the door, swung open
      for(let i=0;i<8;i++){const a=i*Math.PI/4;x.fillStyle='#8a7650';x.fillRect(cx+R*.62+Math.cos(a)*R*.25-4,cy+Math.sin(a)*R*.6-4,8,8)}
      const gr=x.createLinearGradient(0,cy,0,h);gr.addColorStop(0,'rgba(255,210,110,.4)');gr.addColorStop(1,'rgba(255,210,110,0)');x.fillStyle=gr;x.beginPath();x.moveTo(cx-R,cy+R*.5);x.lineTo(cx+R*.3,cy+R*.5);x.lineTo(cx+R*1.4,h);x.lineTo(cx-R*1.6,h);x.fill();
      for(let i=0;i<5;i++){x.fillStyle='rgba(40,30,15,.8)';x.fillRect(cx-R*.6+i*R*.3,cy-R*.05+(i%2)*R*.2,R*.2,R*.5)}   // stacked bars in silhouette
      vgrad(x,w,h,[[0,'rgba(0,0,0,.3)'],[.55,'rgba(0,0,0,0)'],[1,'rgba(0,0,0,.65)']])},
    live(c,w,h,t){const cx=w*.52,cy=h*.5,R=Math.min(w,h)*.36;c.save();c.globalCompositeOperation='lighter';for(let i=0;i<14;i++){const k=((t*.12+hash(i,3))%1),X=cx-R*.8+hash(i,5)*R*1.4,Y=cy+R*.2-k*R*1.2;c.globalAlpha=.6*Math.sin(k*Math.PI);c.fillStyle='#fff0b8';c.fillRect(X,Y,2,2)}
      c.globalAlpha=.1+.06*Math.sin(t*.9);usGlow(c,cx,cy,R*1.2,'rgba(255,210,110,.9)',c.globalAlpha);c.restore()}},
  // Area 67's fence at dusk: a wire fence, a guard tower, two searchlights sweeping and a light that hovers
  area67:{base(x,w,h){vgrad(x,w,h,[[0,'#1b1430'],[.45,'#5a3448'],[.62,'#c06a4a'],[.7,'#2a2026'],[1,'#120e12']]);
      x.fillStyle='#2a2026';x.beginPath();x.moveTo(0,h*.66);for(let i=0;i<=10;i++)x.lineTo(i*w/10,h*(.62+hash(i,2)*.05));x.lineTo(w,h);x.lineTo(0,h);x.fill();   // the desert ridge
      x.fillStyle='#0e0b10';x.fillRect(0,h*.74,w,h*.26);
      x.strokeStyle='rgba(20,16,22,.9)';x.lineWidth=2;for(let X=0;X<w;X+=w/14){x.beginPath();x.moveTo(X,h*.56);x.lineTo(X,h*.8);x.stroke()}   // posts
      x.lineWidth=1;x.strokeStyle='rgba(40,34,44,.8)';for(let X=-h;X<w;X+=14){x.beginPath();x.moveTo(X,h*.8);x.lineTo(X+h*.24,h*.56);x.stroke();x.beginPath();x.moveTo(X+h*.24,h*.8);x.lineTo(X,h*.56);x.stroke()}   // the mesh
      for(let X=0;X<w;X+=10){x.strokeStyle='#1a141c';x.beginPath();x.arc(X,h*.555,4,0,Math.PI*2);x.stroke()}   // wire on top
      x.fillStyle='#0c090e';x.fillRect(w*.78,h*.3,w*.06,h*.46);x.fillRect(w*.75,h*.27,w*.12,h*.05);   // the tower
      x.fillStyle='#e8e2d0';x.globalAlpha=.7;x.fillRect(w*.04,h*.68,w*.16,h*.04);x.globalAlpha=1;x.fillStyle='#c42a2a';x.fillRect(w*.04,h*.68,w*.16,h*.008);   // a blank warning sign
      for(let i=0;i<30;i++){x.fillStyle='#f4e8ff';x.globalAlpha=.2+.4*hash(i,7);x.fillRect(hash(i,8)*w,hash(i,9)*h*.3,1,1)}x.globalAlpha=1},
    live(c,w,h,t){c.save();c.globalCompositeOperation='lighter';
      for(const [X,ph]of[[w*.81,0],[w*.2,2.2]]){const a=-Math.PI/2+Math.sin(t*.4+ph)*.7,L=h*.9,gr=c.createLinearGradient(X,h*.3,X+Math.cos(a)*L,h*.3+Math.sin(a)*L);gr.addColorStop(0,'rgba(255,250,220,.35)');gr.addColorStop(1,'rgba(255,250,220,0)');
        c.fillStyle=gr;c.beginPath();c.moveTo(X,h*.3);c.lineTo(X+Math.cos(a-.08)*L,h*.3+Math.sin(a-.08)*L);c.lineTo(X+Math.cos(a+.08)*L,h*.3+Math.sin(a+.08)*L);c.fill()}
      const hx=w*(.42+.06*Math.sin(t*.3)),hy=h*(.2+.03*Math.sin(t*.7));usGlow(c,hx,hy,h*.12,'rgba(160,255,140,.8)',.6+.2*Math.sin(t*3));c.fillStyle='#f0fff0';c.globalAlpha=.9;c.beginPath();c.ellipse(hx,hy,8,3,0,0,Math.PI*2);c.fill();c.restore()}},
  // the Strip at night: a retro neon skyline (invented signs: stars, arrows, a big 7), its bulbs chasing
  stripnight:{base(x,w,h){vgrad(x,w,h,[[0,'#06040e'],[.55,'#1a0e2a'],[1,'#2a1020']]);
      for(let i=0;i<60;i++){x.fillStyle='#f0e8ff';x.globalAlpha=.15+.4*hash(i,21);x.fillRect(hash(i,22)*w,hash(i,23)*h*.45,1,1)}x.globalAlpha=1;
      usGlow(x,w/2,h,h*.9,'rgba(255,90,216,.25)');
      let px=-10,n=0;while(px<w){const bw=w*(.07+hash(n,31)*.07),bh=h*(.22+hash(n,32)*.32),y0=h*.8-bh;x.fillStyle=n%2?'#120a1c':'#0e0816';x.fillRect(px,y0,bw,h-y0);
        for(let wy=y0+8;wy<h*.8-6;wy+=10)for(let wx=px+5;wx<px+bw-5;wx+=9)if(hash(wx|0,wy|0)<.3){x.fillStyle='rgba(255,210,150,.55)';x.fillRect(wx,wy,3,4)}px+=bw+3;n++}
      x.fillStyle='#08060c';x.fillRect(0,h*.8,w,h*.2);
      // the signs' frames (their tubes are the live layer)
      for(const s of US_STRIP_SIGNS(w,h)){x.fillStyle='#14101e';x.fillRect(s.x-4,s.y-4,s.w+8,s.h+8)}},
    live(c,w,h,t){c.save();c.globalCompositeOperation='lighter';const S=US_STRIP_SIGNS(w,h);
      S.forEach((s,i)=>{const col=s.col,on=.55+.45*Math.sin(t*2+i);c.strokeStyle=col;c.globalAlpha=on;c.lineWidth=3;c.strokeRect(s.x,s.y,s.w,s.h);
        c.globalAlpha=on*.3;c.lineWidth=9;c.strokeRect(s.x,s.y,s.w,s.h);c.globalAlpha=1;
        const n=Math.floor((s.w+s.h)*2/14),k=Math.floor(t*8);for(let q=0;q<n;q++){if((q+k)%3)continue;const d=q/n*(s.w+s.h)*2;let X,Y;if(d<s.w){X=s.x+d;Y=s.y}else if(d<s.w+s.h){X=s.x+s.w;Y=s.y+d-s.w}else if(d<2*s.w+s.h){X=s.x+s.w-(d-s.w-s.h);Y=s.y+s.h}else{X=s.x;Y=s.y+s.h-(d-2*s.w-s.h)}
          c.fillStyle='#fff6c8';c.fillRect(X-1.5,Y-1.5,3,3)}   // chasing bulbs
        if(s.glyph==='7'){c.fillStyle=col;c.globalAlpha=on;c.font=`900 ${s.h*.8}px "Big Shoulders Stencil Display",sans-serif`;c.textAlign='center';c.textBaseline='middle';c.fillText('7',s.x+s.w/2,s.y+s.h/2)}
        else if(s.glyph==='star'){c.fillStyle=col;c.globalAlpha=on;c.beginPath();for(let k2=0;k2<10;k2++){const a=-Math.PI/2+k2*Math.PI/5,r=k2%2?s.h*.18:s.h*.4;c.lineTo(s.x+s.w/2+Math.cos(a)*r,s.y+s.h/2+Math.sin(a)*r)}c.fill()}
        else{c.strokeStyle=col;c.globalAlpha=on;c.lineWidth=4;c.beginPath();c.moveTo(s.x+s.w*.2,s.y+s.h/2);c.lineTo(s.x+s.w*.8,s.y+s.h/2);c.lineTo(s.x+s.w*.6,s.y+s.h*.25);c.moveTo(s.x+s.w*.8,s.y+s.h/2);c.lineTo(s.x+s.w*.6,s.y+s.h*.75);c.stroke()}});
      c.restore()}},
  // the specimen hall: a dark lab, a row of tanks glowing, something turning in the middle one
  specimenhall:{base(x,w,h){vgrad(x,w,h,[[0,'#04080a'],[.6,'#0a1418'],[1,'#030506']]);
      x.fillStyle='#0c161a';x.fillRect(0,h*.78,w,h*.22);x.strokeStyle='rgba(120,200,220,.08)';x.lineWidth=1;for(let X=0;X<w;X+=w/16){x.beginPath();x.moveTo(X,h*.78);x.lineTo(w/2+(X-w/2)*1.8,h);x.stroke()}
      for(const T of US_TANKS(w,h)){usGlow(x,T.x,T.y+T.h*.5,T.w*1.6,'rgba(90,220,170,.25)');x.fillStyle='#1c2a2e';x.fillRect(T.x-T.w/2-4,T.y-8,T.w+8,10);x.fillRect(T.x-T.w/2-4,T.y+T.h,T.w+8,12);
        const gr=x.createLinearGradient(T.x-T.w/2,0,T.x+T.w/2,0);gr.addColorStop(0,'rgba(60,170,140,.55)');gr.addColorStop(.5,'rgba(120,240,200,.7)');gr.addColorStop(1,'rgba(40,140,120,.55)');x.fillStyle=gr;x.fillRect(T.x-T.w/2,T.y,T.w,T.h);
        x.strokeStyle='rgba(220,255,240,.35)';x.strokeRect(T.x-T.w/2,T.y,T.w,T.h)}
      vgrad(x,w,h,[[0,'rgba(0,0,0,.35)'],[.5,'rgba(0,0,0,0)'],[1,'rgba(0,0,0,.6)']])},
    live(c,w,h,t){const S=US_TANKS(w,h);c.save();S.forEach((T,i)=>{for(let k=0;k<4;k++){const q=((t*.25+hash(i,k))%1),bx=T.x-T.w*.3+hash(k,i+3)*T.w*.6,by=T.y+T.h*(1-q);c.globalAlpha=.6*(1-q);c.strokeStyle='#d8fff0';c.lineWidth=1;c.beginPath();c.arc(bx,by,2+hash(k,i)*2,0,Math.PI*2);c.stroke()}
        const mid=i===Math.floor(S.length/2);if(mid){const sw=Math.sin(t*.6)*T.w*.12;c.globalAlpha=.85;c.fillStyle='#0a1a16';c.beginPath();c.ellipse(T.x+sw,T.y+T.h*.38,T.w*.18,T.h*.16,0,0,Math.PI*2);c.fill();c.beginPath();c.ellipse(T.x+sw*.8,T.y+T.h*.62,T.w*.1,T.h*.22,0,0,Math.PI*2);c.fill();
          c.fillStyle='rgba(200,255,220,.8)';c.globalAlpha=.5+.5*Math.sin(t*1.7);c.fillRect(T.x+sw-3,T.y+T.h*.36,2,2);c.fillRect(T.x+sw+2,T.y+T.h*.36,2,2)}});   // its eyes
      c.globalAlpha=.05+.04*Math.sin(t*2.1);c.fillStyle='#7cffd0';c.fillRect(0,0,w,h);c.restore()}}};
const US_STRIP_SIGNS=(w,h)=>[{x:w*.08,y:h*.22,w:w*.14,h:h*.12,col:'#ff5ad8',glyph:'star'},{x:w*.42,y:h*.12,w:w*.12,h:h*.2,col:'#ffd24a',glyph:'7'},{x:w*.7,y:h*.26,w:w*.18,h:h*.1,col:'#5ab0ff',glyph:'arrow'}];
const US_TANKS=(w,h)=>{const n=w>700?5:3,out=[];for(let i=0;i<n;i++){const tw=Math.min(w/(n*2.2),90);out.push({x:w*(i+.5)/n,y:h*.3,w:tw,h:h*.46})}return out};
