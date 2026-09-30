/* Cached scenic finishing layers. Delete an ID from BG_REFINEMENTS to restore that scene's v0.9.3.3 art.
   Original scene definitions remain in 18b-backgrounds.js; this file adds no assets or per-frame particles. */
const BG_REFINEMENTS={
 campfire:['terrain','#55331f','#211a16','#100e0c'],nightwatch:['terrain','#263448','#141f30','#080e18'],
 dawn:['terrain','#784756','#4a3045','#211927'],aurora:['terrain','#193f49','#142a38','#070f18'],
 emberfield:['terrain','#5a2419','#301612','#150c0b'],harvestmoon:['terrain','#422735','#271726','#100b14'],
 hauntedfog:['terrain','#393346','#221f31','#100e1c'],watchtower:['terrain','#243041','#151f2d','#090e18'],
 searchlight:['terrain','#1c2a3a','#121e2a','#070d15'],bloodmoon:['terrain','#41131c','#240a12','#0e050b'],
 graveyard:['ground','#2a303a','#161d26','#0c1018'],witchbrew:['ground','#1b2c25','#101b18','#090e13'],
 sunsetfade:['terrain','#57234e','#321330','#160b24'],lagoonwaves:['water'],
 fieldmap:['paper'],sandbags:['canvas'],dogtags:['metal'],crimson:['smoke'],
 nebula:['cosmic'],eventhorizon:['lens'],neongrid:['horizon'],neonpulse:['city'],goldrush:['gold'],goldaurora:['goldsky']
 // Arcade deliberately retains its crisp, flat pixel-art composition.
};
const BG_DEPTH_LAYER={campfire:'campfire',nightwatch:'nightwatch',dawnfg:'dawn',aurorafg:'aurora',ember:'emberfield',neon:'neongrid',gold:'goldrush',searchfg:'searchlight',blood:'bloodmoon',gaur:'goldaurora',neonp:'neonpulse',horizon:'eventhorizon'};
function bgScenicDetail(id,x,w,h){
 const [kind,far,mid,near]=BG_REFINEMENTS[id],u=Math.min(w,h),seed=id.length*37;
 const poly=(pts,col)=>{x.fillStyle=col;x.beginPath();pts.forEach(([a,b],i)=>i?x.lineTo(a,b):x.moveTo(a,b));x.closePath();x.fill()};
 const ridge=(base,amp,col,s)=>{const pts=[[0,h]];for(let i=0;i<=16;i++)pts.push([w*i/16,h*(base-amp*hash(i,s))]);pts.push([w,h]);poly(pts,col)};
 const glow=(cx,cy,rx,ry,col)=>x.drawImage(bgBlob(col),cx-rx,cy-ry,rx*2,ry*2);
 if(kind==='terrain'||kind==='ground'){
  const base=kind==='ground'?.94:id==='hauntedfog'?.91:.84;
  ridge(base,.065,far,seed);ridge(base+.045,.035,mid,seed+1);ridge(.982,.045,near,seed+2);
  // A receding path / water glint ties the distant plane to the foreground without filling the menu's centre.
  if(['campfire','dawn','nightwatch','hauntedfog','watchtower','aurora','sunsetfade'].includes(id)){
   const warm=id==='campfire'||id==='dawn',col=warm?'rgba(232,159,101,.16)':'rgba(153,190,218,.13)';
   poly([[w*.61,h*(base-.015)],[w*.66,h*(base+.015)],[w*.52,h*.94],[w*.69,h],[w*.38,h],[w*.43,h*.94]],col);
   for(let i=0;i<14;i++){const y=h*(base+.02+i*.01),width=(i+1)*w*.003;x.fillStyle=warm?'rgba(244,187,121,.16)':'rgba(174,213,230,.14)';x.fillRect(w*(.565+.02*Math.sin(i)) -width,y,width*2,Math.max(1,u*.001))}
  }
  if(id==='campfire'||id==='emberfield')glow(w*.5,h*1.03,w*.55,h*.18,'rgba(255,126,42,.3)');
  if(id==='hauntedfog'||id==='graveyard'||id==='bloodmoon')glow(w*.35,h*.91,w*.7,h*.05,id==='bloodmoon'?'rgba(181,54,66,.17)':'rgba(171,177,205,.16)');
  // Angular stones and grasses are concentrated at the edges, away from the soldier's feet.
  for(let i=0;i<20;i++){const left=i%2===0,px=w*(left?hash(i,seed+3)*.24:.78+hash(i,seed+3)*.22),py=h*(.91+.09*hash(i,seed+4)),r=u*(.003+.013*hash(i,seed+5));
   poly([[px-r,py],[px-r*.5,py-r*.6],[px+r*.6,py-r*.45],[px+r,py]],mid);x.strokeStyle=far;x.lineWidth=Math.max(.7,u*.001);x.beginPath();x.moveTo(px-r*.5,py-r*.6);x.lineTo(px+r*.6,py-r*.45);x.stroke();
   if(i%3===0){x.strokeStyle=near;x.beginPath();x.moveTo(px,py);x.lineTo(px-r*.2,py-r*1.8);x.moveTo(px,py);x.lineTo(px+r*.6,py-r*1.1);x.stroke()}}
  if(id==='nightwatch'){glow(w*.77,h*.23,u*.14,u*.14,'rgba(135,181,229,.15)');x.fillStyle='#b1c6d5';x.beginPath();x.arc(w*.77,h*.23,u*.023,0,Math.PI*2);x.fill();x.fillStyle='#101a2b';x.beginPath();x.arc(w*.77+u*.01,h*.23-u*.007,u*.022,0,Math.PI*2);x.fill()}
 }else if(kind==='water'){
  // Faceted crests and specular fragments follow the existing nine wave bands.
  for(let k=0;k<9;k++){x.strokeStyle=`rgba(173,255,233,${.13+k*.014})`;x.lineWidth=1+k*.2;x.beginPath();for(let px=0;px<=w+10;px+=10){const y=h*(.25+k*.09)+Math.sin(px*.025+k*1.3)*12+Math.sin(px*.06+k)*4;px?x.lineTo(px,y):x.moveTo(px,y)}x.stroke()}
  for(let i=0;i<80;i++){const y=h*(.3+.7*hash(i,113)),ww=u*(.003+.02*hash(i,114));x.fillStyle='rgba(166,255,232,.12)';x.fillRect(hash(i,112)*w,y,ww,Math.max(1,u*.0015))}
 }else if(kind==='paper'){
  for(const f of [.33,.66]){const g=x.createLinearGradient(w*f-9,0,w*f+9,0);g.addColorStop(0,'#38280e00');g.addColorStop(.45,'#38280e22');g.addColorStop(.55,'#fff6da33');g.addColorStop(1,'#fff6da00');x.fillStyle=g;x.fillRect(w*f-9,0,18,h)}
  x.strokeStyle='rgba(59,54,33,.4)';x.lineWidth=1;const cx=w*.88,cy=h*.17,r=u*.06;x.beginPath();x.arc(cx,cy,r,0,Math.PI*2);x.moveTo(cx-r*1.2,cy);x.lineTo(cx+r*1.2,cy);x.moveTo(cx,cy-r*1.2);x.lineTo(cx,cy+r*1.2);x.stroke();poly([[cx,cy-r],[cx-r*.18,cy+r*.4],[cx+r*.18,cy+r*.4]],'#625638');
  for(let i=0;i<280;i++){x.fillStyle='rgba(64,47,22,.075)';x.fillRect(hash(i,116)*w,hash(i,117)*h,1+hash(i,118)*3,1)}
 }else if(kind==='canvas'){
  for(let row=0;row<Math.ceil(h*.34/26);row++)for(let i=-1;i<w/58+1;i++){const bx=i*58+(row%2?29:0),by=h*.66+row*26;
   x.strokeStyle='rgba(250,223,170,.32)';x.lineWidth=1;x.beginPath();x.moveTo(bx+12,by+5);x.lineTo(bx+45,by+5);x.stroke();x.fillStyle='rgba(35,29,20,.18)';x.fillRect(bx+10,by+20,38,2);
   for(let k=0;k<6;k++){x.fillStyle='rgba(52,40,22,.15)';x.fillRect(bx+10+k*6,by+9,1,5)}}
  const g=x.createLinearGradient(0,h*.66,0,h);g.addColorStop(0,'#18130d00');g.addColorStop(1,'#18130d88');x.fillStyle=g;x.fillRect(0,h*.66,w,h*.34);
 }else if(kind==='metal'){
  const g=x.createLinearGradient(0,0,w,h);g.addColorStop(0,'#d5e6eb00');g.addColorStop(.25,'#d5e6eb12');g.addColorStop(.45,'#d5e6eb00');g.addColorStop(1,'#030a1144');x.fillStyle=g;x.fillRect(0,0,w,h);
  for(let i=0;i<45;i++){x.strokeStyle='rgba(190,210,217,.045)';const px=hash(i,120)*w,py=hash(i,121)*h;x.beginPath();x.moveTo(px,py);x.lineTo(px+u*.03,py-u*.02);x.stroke()}
 }else if(kind==='smoke'){
  for(let i=0;i<8;i++){const px=w*(.08+.84*hash(i,125)),py=h*(.1+.8*hash(i,126));glow(px,py,w*.24,h*.18,'rgba(131,30,46,.10)');glow(px+w*.035,py+h*.03,w*.18,h*.14,'rgba(7,4,12,.30)')}
 }else if(kind==='cosmic'||kind==='goldsky'){
  const gold=kind==='goldsky';for(let i=0;i<42;i++){const px=hash(i,130)*w,py=hash(i,131)*h,r=i%9===0?u*.015:u*.002;
   if(i%9===0)glow(px,py,r*3,r*3,gold?'rgba(255,210,110,.17)':'rgba(131,161,255,.24)');x.fillStyle=gold?'#eee0b199':'#d7e5ffbb';x.fillRect(px,py,Math.max(1,r*.25),Math.max(1,r*.25))}
  if(!gold)for(let i=0;i<7;i++)glow(w*(.13+i*.12),h*(.28+i*.064),w*.11,h*.13,'rgba(6,4,19,.42)');
  else{ridge(.96,.06,'#1d1c20',137);ridge(1,.055,'#0a0d12',138)}
 }else if(kind==='lens'){
  // A diffuse outer accretion glow adds volume without painting across the black centre.
  const cx=w*.5,cy=h*.42,R=Math.min(w,h)*.42,g=x.createRadialGradient(cx,cy,R*.63,cx,cy,R*1.35);g.addColorStop(0,'#ffb17000');g.addColorStop(.28,'#ffa2660b');g.addColorStop(.55,'#b681ff10');g.addColorStop(1,'#b681ff00');x.fillStyle=g;x.fillRect(0,0,w,h);
 }else if(kind==='horizon'){
  glow(w*.5,h*.55,w*.52,h*.1,'rgba(221,65,226,.17)');
  for(const side of [-1,1])poly([[w*(.5+side*.26),h*.55],[w*(.5+side*.4),h*.49],[w*(.5+side*.48),h*.53],[w*(.5+side*.5),h*.46],[w*(.5+side*.5),h*.55]],'#170d2b');
 }else if(kind==='city'){
  // Foreground reflections support the skyline without another animated layer.
  for(let i=0;i<30;i++){const px=hash(i,150)*w,py=h*(.89+hash(i,151)*.1);x.fillStyle=i%2?'rgba(208,61,203,.18)':'rgba(67,172,223,.16)';x.fillRect(px,py,5+hash(i,152)*w*.03,Math.max(1,u*.0015))}
 }else if(kind==='gold'){
  // Sparse cut-crystal facets at the edges keep the central light and soldier clear.
  for(let i=0;i<12;i++){const px=w*(i%2?.88+.12*hash(i,155):.12*hash(i,155)),py=h*(.4+.7*hash(i,156)),r=u*(.025+.06*hash(i,157));poly([[px,py-r],[px+r*.5,py],[px,py+r],[px-r*.55,py]],'rgba(239,192,89,.14)');poly([[px,py-r],[px,py+r],[px-r*.55,py]],'rgba(66,40,17,.25)')}
 }
}
for(const id of Object.keys(BG_REFINEMENTS)){
 if(Object.values(BG_DEPTH_LAYER).includes(id))continue;
 const original=BGS[id].draw;
 BGS[id].draw=function(x,w,h,t){original(x,w,h,t);if(this.still!==undefined)bgScenicDetail(id,x,w,h);else bgBlit(x,bgLayer('depth:'+id,w,h,(c,W,H)=>bgScenicDetail(id,c,W,H)),w,h)};
}
