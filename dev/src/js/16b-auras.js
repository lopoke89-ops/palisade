/* ================= outfit effects (v0.9.3) =================
   The moving part of a Legendary or Gold milestone outfit: embers, sparks, lightning, rain, fireflies, bats.
   The figure itself stays a cached, still sprite (16-characters.js); this layer is drawn over it every frame
   straight from the clock, with no particle state to keep. Everything is small shapes and the cached glow
   stamps, so six players in Gold outfits cost about as much as one extra kill effect.
   paintAura(ctx, kind, x, y, s, t, alpha): x,y = the feet on screen, s = pixels per model unit (the figure is
   about 37 units tall), t = seconds. */
const AURA_TAU=Math.PI*2;
function auraShape(c,shape,x,y,r,col,rot){
  c.fillStyle=col;
  if(shape==='dot'){c.fillRect(x-r*.5,y-r*.5,r,r);return}
  c.beginPath();
  if(shape==='diamond'){c.moveTo(x,y-r*1.3);c.lineTo(x+r*.6,y);c.lineTo(x,y+r*.8);c.lineTo(x-r*.6,y)}
  else if(shape==='star'){for(let i=0;i<8;i++){const a=i*Math.PI/4+(rot||0),rr=i%2?r*.28:r;i?c.lineTo(x+Math.cos(a)*rr,y+Math.sin(a)*rr):c.moveTo(x+rr,y)}}
  else if(shape==='drop'){c.moveTo(x,y-r*1.4);c.quadraticCurveTo(x+r*.8,y+r*.1,x,y+r*.6);c.quadraticCurveTo(x-r*.8,y+r*.1,x,y-r*1.4)}
  else if(shape==='flake'){c.rect(x-r*.6,y-r*.25,r*1.2,r*.5)}
  else if(shape==='leaf'){c.ellipse(x,y,r*.9,r*.4,rot||0,0,AURA_TAU)}
  c.closePath();c.fill();
}
// the pieces every effect is built from
const AURA_PART={
  // a soft light around the body, or on the ground under it
  glow(c,x,y,s,t,o){cosmeticGlow(c,x,y-(o.y??18)*s,(o.r||16)*s,o.col,(o.a||.2)*(1+.12*Math.sin(t*2.3)))},
  pool(c,x,y,s,t,o){c.save();c.translate(x,y);c.scale(1,.38);cosmeticGlow(c,0,0,(o.r||15)*s,o.col,(o.a||.3)*(1+.15*Math.sin(t*3.1)));c.restore()},
  // a bright ring on the ground that breathes (every Gold outfit has one)
  ring(c,x,y,s,t,o){const k=1+.06*Math.sin(t*2.4);c.save();c.globalAlpha*=.75;c.strokeStyle=o.col;c.lineWidth=Math.max(1,.9*s);c.beginPath();c.ellipse(x,y+.6*s,12.5*s*k,4.7*s*k,0,0,AURA_TAU);c.stroke();
    c.globalAlpha*=.5;c.lineWidth=Math.max(.5,.35*s);c.beginPath();c.ellipse(x,y+.6*s,14.5*s*k,5.5*s*k,0,0,AURA_TAU);c.stroke();c.restore()},
  // a wave that rolls out from the feet now and then
  pulse(c,x,y,s,t,o){const ph=(t/(o.every||1.8))%1;if(ph>.45)return;const k=ph/.45;c.save();c.globalAlpha*=(1-k)*.8;c.strokeStyle=o.col;c.lineWidth=Math.max(1,1.4*s*(1-k));
    c.beginPath();c.ellipse(x,y+.6*s,(8+18*k)*s,(3+6.8*k)*s,0,0,AURA_TAU);c.stroke();c.restore()},
  // specks drifting up from the feet to above the head
  rise(c,x,y,s,t,o){const n=o.n||6,cols=o.cols;for(let i=0;i<n;i++){const ph=(t*(o.sp||.5)*(.7+.6*hash(i,1))+hash(i,2))%1,px=x+((hash(i,3)-.5)*18+Math.sin(t*1.7+i*2.3)*2)*s,py=y-(ph*44+2)*s;
    c.globalAlpha=Math.sin(ph*Math.PI);auraShape(c,o.shape||'diamond',px,py,(o.size||1.2)*s,cols[i%cols.length],t*2+i)}c.globalAlpha=1},
  // drops, ash or flakes falling past the body; drops leave a ripple where they land
  fall(c,x,y,s,t,o){const n=o.n||6,cols=o.cols;for(let i=0;i<n;i++){const ph=(t*(o.sp||.7)*(.8+.4*hash(i,5))+hash(i,6))%1,px=x+((hash(i,7)-.5)*(o.w||20)+(o.drift?Math.sin(t+i)*2:0))*s,top=o.top??40,py=y-(top-ph*top)*s;
    if(ph<.94){c.globalAlpha=Math.min(1,ph*6)*.9;auraShape(c,o.shape||'drop',px,py,(o.size||1)*s,cols[i%cols.length],t+i)}
    else if(o.ripple){const k=(ph-.94)/.06;c.globalAlpha=(1-k)*.8;c.strokeStyle=cols[i%cols.length];c.lineWidth=Math.max(.5,.3*s);c.beginPath();c.ellipse(px,y,(1+3*k)*s,(.4+1.2*k)*s,0,0,AURA_TAU);c.stroke()}}c.globalAlpha=1},
  // short bright streaks thrown out from one point (a fuse, a welding torch)
  sparks(c,x,y,s,t,o){const n=o.n||6,cx=x+(o.x||0)*s,cy=y-(o.y??15)*s;c.lineCap='round';
    for(let i=0;i<n;i++){const ph=(t*(o.sp||2.2)+hash(i,11))%1,a=(o.dir??-Math.PI/2)+(hash(i,12)-.5)*(o.spread||2.4),d=(2+ph*(o.len||9))*s,g=ph*ph*6*s;
      c.globalAlpha=1-ph;c.strokeStyle=o.cols[i%o.cols.length];c.lineWidth=Math.max(.6,.45*s);c.beginPath();c.moveTo(cx+Math.cos(a)*d*.55,cy+Math.sin(a)*d*.55+g*.5);c.lineTo(cx+Math.cos(a)*d,cy+Math.sin(a)*d+g);c.stroke()}
    c.globalAlpha=1;c.lineCap='butt';cosmeticGlow(c,cx,cy,4*s,o.cols[0],.5+.3*Math.sin(t*30))},
  // grey puffs rolling up from the shoulder
  smoke(c,x,y,s,t,o){for(let i=0;i<(o.n||3);i++){const ph=(t*.45+i/(o.n||3))%1,px=x+((o.x||5)+Math.sin(t+i)*1.5)*s,py=y-((o.y??26)+ph*14)*s;c.globalAlpha=(1-ph)*.35;c.fillStyle=o.col||'#6a6560';c.beginPath();c.arc(px,py,(1.5+ph*3.5)*s,0,AURA_TAU);c.fill()}c.globalAlpha=1},
  // lightning jumping between points on the body
  arcs(c,x,y,s,t,o){c.lineCap='round';c.lineJoin='round';for(let i=0;i<(o.n||2);i++){const f=Math.floor(t*9+i*3.7),on=hash(f,i+20)<.45;if(!on)continue;
    const x0=x+(hash(f,1+i)-.5)*16*s,y0=y-(10+hash(f,2+i)*24)*s,x1=x0+(hash(f,3+i)-.5)*14*s,y1=y0+(hash(f,4+i)-.5)*12*s,pts=[[x0,y0]];
    for(let k=1;k<4;k++)pts.push([x0+(x1-x0)*k/4+(hash(f+k,5+i)-.5)*4*s,y0+(y1-y0)*k/4+(hash(f+k,6+i)-.5)*4*s]);pts.push([x1,y1]);
    for(const [w,col,a]of[[1.6,o.col,.35],[.55,'#ffffff',1]]){c.globalAlpha=a;c.strokeStyle=col;c.lineWidth=Math.max(.5,w*s);c.beginPath();pts.forEach((q,k)=>k?c.lineTo(q[0],q[1]):c.moveTo(q[0],q[1]));c.stroke()}}
    c.globalAlpha=1;c.lineCap='butt';c.lineJoin='miter'},
  // shapes circling the waist (behind and in front of the body: the far half is dimmer)
  orbit(c,x,y,s,t,o){const n=o.n||3;for(let i=0;i<n;i++){const a=t*(o.sp||1.2)+i*AURA_TAU/n,px=x+Math.cos(a)*(o.r||12)*s,py=y-((o.y??16)-Math.sin(a)*4)*s;
    c.globalAlpha=Math.sin(a)>0?1:.45;if(o.glow)cosmeticGlow(c,px,py,3*s,o.col,.6);auraShape(c,o.shape||'star',px,py,(o.size||1.3)*s,o.col,t*3)}c.globalAlpha=1},
  // glowing dots wandering around, blinking
  flies(c,x,y,s,t,o){for(let i=0;i<(o.n||6);i++){const px=x+Math.sin(t*.9*(1+hash(i,31))+i*2)*14*s,py=y-(8+hash(i,32)*26+Math.sin(t*1.3+i)*5)*s,b=Math.pow((Math.sin(t*2.6+i*1.9)+1)/2,2);
    if(b<.05)continue;cosmeticGlow(c,px,py,3.2*s,o.col,b*.8);c.globalAlpha=b;c.fillStyle='#fffbe0';c.fillRect(px-.4*s,py-.4*s,.8*s,.8*s)}c.globalAlpha=1},
  // low mist curling round the feet
  mist(c,x,y,s,t,o){for(let i=0;i<(o.n||3);i++)cosmeticGlow(c,x+Math.sin(t*.5+i*2.1)*10*s,y-(1+i%2)*s,(8+2*Math.sin(t+i))*s,o.col,o.a||.28)},
  // bats flapping round the head
  bats(c,x,y,s,t,o){c.strokeStyle='#0c0a10';c.lineWidth=Math.max(.8,.55*s);for(let i=0;i<(o.n||3);i++){const a=t*1.4+i*AURA_TAU/(o.n||3),px=x+Math.cos(a)*12*s,py=y-(36+Math.sin(a*2)*2-Math.sin(a)*3)*s,f=Math.sin(t*16+i*2)*.9,w=2.2*s;
    c.globalAlpha=Math.sin(a)>0?1:.55;c.beginPath();c.moveTo(px-w*1.4,py-w*f);c.lineTo(px-w*.5,py);c.lineTo(px,py-w*.35);c.lineTo(px+w*.5,py);c.lineTo(px+w*1.4,py-w*f);c.stroke();
    c.fillStyle='#0c0a10';c.beginPath();c.arc(px,py,w*.35,0,AURA_TAU);c.fill();c.fillStyle='#ff3a3a';c.fillRect(px-.3*s,py-.3*s,.6*s,.5*s)}c.globalAlpha=1},
  // gold glints popping on and off around the body
  twinkle(c,x,y,s,t,o){for(let i=0;i<(o.n||4);i++){const ph=(t*.8+hash(i,41))%1;if(ph>.35)continue;const k=Math.sin(ph/.35*Math.PI),px=x+(hash(i,42)-.5)*20*s,py=y-(6+hash(i,43)*32)*s;
    c.globalAlpha=k;auraShape(c,'star',px,py,(1.2+k*1.3)*s,o.col||'#fffbe0',0)}c.globalAlpha=1}
};
const GOLDS=['#ffe066','#fff6c8','#ffd24a'];
// each effect is a list of pieces, drawn in order (ground first)
const AURAS={
  // Legendary: one simple effect
  rage:[{p:'glow',col:'#ff2a1a',a:.2},{p:'rise',n:7,cols:['#ff4a2a','#ffa03a'],sp:.55}],
  fuse:[{p:'sparks',n:6,cols:['#fff0a0','#ff9a2a'],x:0,y:15,dir:-1.3},{p:'smoke',n:3,x:5,y:26}],
  arcs:[{p:'glow',col:'#7fe0ff',a:.16},{p:'arcs',n:2,col:'#7fe0ff'}],
  drowned:[{p:'mist',n:3,col:'rgba(95,214,196,.55)'},{p:'fall',n:6,cols:['#8fe8dc','#bff6ee'],top:26,w:14,sp:.9,ripple:true}],
  weld:[{p:'sparks',n:7,cols:['#fff6c8','#ffb13a','#7fd0ff'],x:7,y:17,dir:.4,spread:2.8},{p:'rise',n:4,cols:['rgba(200,170,120,.8)'],shape:'dot',sp:.35,size:1.6}],
  firefly:[{p:'flies',n:6,col:'#d8ff6a'}],
  rain:[{p:'fall',n:9,cols:['#bfe8ff','#8fd0ff'],top:44,w:22,sp:1.1,ripple:true}],
  ash:[{p:'fall',n:9,cols:['#b8b0a8','#8a8480','#d8d0c8'],top:44,w:24,sp:.35,shape:'flake',drift:true,size:1.1},{p:'rise',n:3,cols:['#ffb060'],sp:.4,size:.9}],
  bats:[{p:'glow',col:'#8a0f1f',a:.14,y:30},{p:'bats',n:3}],
  // Gold: a ring on the ground and the richest version of the idea
  gbutcher:[{p:'pool',col:'#ff3a1a',a:.3},{p:'ring',col:'#ffd24a'},{p:'glow',col:'#ff4a2a',a:.18},{p:'rise',n:9,cols:['#ffd24a','#ff4a2a','#fff0b0'],sp:.6,size:1.4},{p:'twinkle',n:4}],
  gdemo:[{p:'pool',col:'#ff8a2a',a:.3},{p:'ring',col:'#ffb040'},{p:'pulse',col:'#ffd070',every:1.6},{p:'sparks',n:8,cols:['#fff6c8','#ffb040','#ff6a1a'],x:0,y:15,dir:-1.3},{p:'rise',n:5,cols:GOLDS,sp:.5}],
  gstorm:[{p:'pool',col:'#7fe0ff',a:.25},{p:'ring',col:'#fff0a0'},{p:'glow',col:'#bff4ff',a:.2},{p:'arcs',n:3,col:'#fff0a0'},{p:'orbit',n:4,col:'#bff4ff',shape:'dot',size:1.1,glow:true,sp:1.6}],
  gferry:[{p:'mist',n:3,col:'rgba(95,214,196,.5)'},{p:'ring',col:'#e6c65c'},{p:'orbit',n:3,col:'#6affd8',shape:'drop',size:1.4,glow:true,sp:.9,y:22},{p:'fall',n:5,cols:GOLDS,top:26,w:14,sp:.9,ripple:true}],
  gforeman:[{p:'pool',col:'#ff9a2a',a:.3},{p:'ring',col:'#ffb13a'},{p:'sparks',n:9,cols:['#fff6c8','#ffd24a','#ff8a2a'],x:7,y:17,dir:.4,spread:2.8},{p:'rise',n:6,cols:GOLDS,sp:.5},{p:'twinkle',n:3}],
  gyard:[{p:'pool',col:'#f0d070',a:.25},{p:'ring',col:'#f0d070'},{p:'flies',n:8,col:'#fff0a0'},{p:'rise',n:5,cols:['#f0d070','#e0b84a'],shape:'leaf',sp:.35,size:1.3}],
  griver:[{p:'mist',n:2,col:'rgba(120,200,255,.4)'},{p:'ring',col:'#e6c65c'},{p:'glow',col:'#9fe0ff',a:.16},{p:'fall',n:9,cols:['#fff0b0','#bfe8ff'],top:44,w:22,sp:1.1,ripple:true},{p:'twinkle',n:3}],
  gquarry:[{p:'pool',col:'#ff7a1a',a:.35},{p:'ring',col:'#ffb040'},{p:'rise',n:8,cols:['#ffd24a','#ff7a1a','#fff0b0'],sp:.55},{p:'fall',n:4,cols:GOLDS,top:44,w:24,sp:.35,shape:'flake',drift:true}],
  gsoldier:[{p:'pool',col:'#ffd24a',a:.22},{p:'ring',col:'#ffd24a'},{p:'glow',col:'#fff0a0',a:.16},{p:'orbit',n:3,col:'#fff0b0',size:1.5,glow:true},{p:'rise',n:6,cols:GOLDS,shape:'star',sp:.45}],
  gsniper:[{p:'pool',col:'#e0c060',a:.2},{p:'ring',col:'#e0c060'},{p:'rise',n:7,cols:['#c9d86a','#e0c060','#8aa83f'],shape:'leaf',sp:.35,size:1.3},{p:'twinkle',n:5}],
  ggren:[{p:'pool',col:'#ffb040',a:.28},{p:'ring',col:'#ffb040'},{p:'pulse',col:'#ffd070',every:2.2},{p:'sparks',n:6,cols:['#fff6c8','#ffb040'],x:0,y:15,dir:-1.3},{p:'rise',n:6,cols:GOLDS,sp:.5}],
  gqm:[{p:'pool',col:'#e6c65c',a:.22},{p:'ring',col:'#e6c65c'},{p:'orbit',n:4,col:'#fff6c8',shape:'dot',size:1.2,glow:true,sp:1},{p:'rise',n:6,cols:['#9fe8b0','#fff6c8'],shape:'star',sp:.45}]
};
// part: which pieces to draw. 'ground': what lies under the figure (drawn before it); 'top': the rest.
// The lobby stage bakes the big, nearly still lights into its cached figure ('sground' under it, 'stop' over it)
// and redraws only the 'moving' pieces each frame: at stage size those soft lights are most of the cost.
const AURA_GROUND=new Set(['pool','ring','pulse','mist']),AURA_STILL=new Set(['pool','ring','glow']);
const AURA_PICK={ground:p=>AURA_GROUND.has(p),top:p=>!AURA_GROUND.has(p),sground:p=>p==='pool'||p==='ring',stop:p=>p==='glow',moving:p=>!AURA_STILL.has(p)};
function paintAura(c,kind,x,y,s,t,alpha=1,part){
  const L=AURAS[kind];if(!L)return;const pick=part&&AURA_PICK[part];
  c.save();c.globalAlpha=alpha;
  for(const o of L){if(pick&&!pick(o.p))continue;c.globalAlpha=alpha;AURA_PART[o.p](c,x,y,s,t,o)}
  c.restore();
}
