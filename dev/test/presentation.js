// Presentation contract: opaque responsive flags, reduced motion, grounded stop/strafe poses and bounded caches.
const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),p=await b.newPage({viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true,hasTouch:true}),errors=[];
 p.on('pageerror',e=>errors.push(e.message));await p.goto('http://localhost:8080/debug.html?debug=1');await p.waitForFunction(()=>window.__pal);
 const flags=await p.evaluate(()=>{const P=__pal,bad=[],counts={static:0,moving:0};
  for(const [w,h]of [[390,844],[844,390],[1280,800],[768,1024]])for(const [id,,rarity]of P.FLAGS){
   const c=document.createElement('canvas');c.width=w;c.height=h;const x=c.getContext('2d',{willReadFrequently:true});P.drawBg('f_'+id,x,w,h,1);const before=c.toDataURL();
   // Scan every outer pixel, not just the four corners; transparent gaps can occur between displaced strips.
   for(const [X,Y,W,H]of [[0,0,w,1],[0,h-1,w,1],[0,0,1,h],[w-1,0,1,h]]){const a=x.getImageData(X,Y,W,H).data;for(let k=3;k<a.length;k+=4)if(a[k]!==255){bad.push(`${id} ${w}x${h}: exposed edge`);break}}
   x.clearRect(0,0,w,h);P.drawBg('f_'+id,x,w,h,7);const moves=before!==c.toDataURL();if(moves!=='lg'.includes(rarity))bad.push(`${id}: rarity motion`);counts[moves?'moving':'static']++;
  }
  // Circular national emblems remain circular in portrait; tricolour side bands remain visible.
  const c=document.createElement('canvas');c.width=390;c.height=844;const x=c.getContext('2d',{willReadFrequently:true});P.drawBg('f_japan',x,390,844,0);const d=x.getImageData(0,0,390,844).data;let x0=390,x1=0,y0=844,y1=0;
  for(let y=0;y<844;y++)for(let xx=0;xx<390;xx++){const i=(y*390+xx)*4;if(d[i]>d[i+1]*2&&d[i]>d[i+2]*1.5){x0=Math.min(x0,xx);x1=Math.max(x1,xx);y0=Math.min(y0,y);y1=Math.max(y1,y)}}
  if(Math.abs((x1-x0)/(y1-y0)-1)>.04||x0<1||x1>388)bad.push('portrait Japan emblem distorted/cropped');
  P.drawBg('f_france',x,390,844,0);const left=x.getImageData(10,422,1,1).data,right=x.getImageData(380,422,1,1).data;if(left[2]<left[0]*1.5||right[0]<right[2]*1.5)bad.push('portrait tricolour lost its side bands');
  return {bad,counts,cache:P.backgroundStats};
 });assert.deepEqual(flags.bad,[]);assert.ok(flags.cache.bytes<=flags.cache.limit);
 await p.emulateMedia({reducedMotion:'reduce'});
 const reduced=await p.evaluate(()=>{const P=__pal,c=document.createElement('canvas');c.width=390;c.height=844;const x=c.getContext('2d');const bad=[];for(const [id,,r]of P.FLAGS.filter(f=>'lg'.includes(f[2]))){P.drawBg('f_'+id,x,390,844,1);const a=c.toDataURL();P.drawBg('f_'+id,x,390,844,8);if(a!==c.toDataURL())bad.push(id)}return {bad,breath:P.stageBreath(2)}});assert.deepEqual(reduced,{bad:[],breath:0});
 await p.emulateMedia({reducedMotion:'no-preference'});
 const motion=await p.evaluate(async()=>{const P=__pal,bad=[],o={x:0,y:0,alive:true,aim:{x:1,y:0},walk:0},start=P.game.time;let now=start;
  const tick=(dx,dy,dt=1/60)=>{now+=dt;P.game.time=now;o.x+=dx;o.y+=dy;return P.presentationMotion(o)};
  P.presentationMotion(o);let moving;for(let i=0;i<30;i++)moving=tick(.05,0);if(moving.gaitWeight<.75)bad.push('walking did not engage');
  const phase=moving.walk;for(let i=0;i<36;i++)moving=tick(0,0);if(moving.gaitWeight!==0||moving.walk!==phase)bad.push('stopped feet did not settle / phase kept sliding');
  for(let i=0;i<10;i++){o.walk+=.3;moving=tick(0,0)}if(moving.gaitWeight!==0)bad.push('input without displacement animated feet');
  for(let i=0;i<24;i++)moving=tick(-.05,0);if(Math.abs(Math.cos(moving.gaitDir)+1)>.05)bad.push('backpedal direction');
  for(let i=0;i<24;i++)moving=tick(.025,.025);const strafe=moving.gaitDir;if(Math.abs(Math.sin(strafe))<.6)bad.push('strafe direction');
  o.downed=true;for(let i=0;i<36;i++)moving=tick(0,0);if(moving.gaitWeight!==0)bad.push('downed gait');o.downed=false;
  // Snapshot cadence: gaps at 20 Hz should not repeatedly plant both feet.
  let minWeight=1;for(let i=0;i<120;i++){moving=tick(i%3===0?.15:0,0);if(i>20)minWeight=Math.min(minWeight,moving.gaitWeight)}if(minWeight<.75)bad.push('remote snapshot gait flicker');
  for(let i=0;i<96;i++){const phase=i*Math.PI*2/96,a=P.wardrobeStep(phase,-1),b=P.wardrobeStep(phase,1);if(a.lift<0||b.lift<0||!a.stance&&!b.stance)bad.push('both feet airborne / below floor')}
  const cv=document.createElement('canvas');cv.width=400;cv.height=400;const x=cv.getContext('2d');const begin=performance.now();
  for(let i=0;i<240;i++){const lk={...P.lookOf({skin:'gknight',hat:'ghelm'},'grenadier'),gaitWeight:i%5/4,gaitDir:i%8*Math.PI/4,tag:'pose-soak'};P.drawWardrobeCharacter(x,lk,i*.03,i*.03,2,200,260,i*.2);if(i%12===0)await new Promise(r=>setTimeout(r,16))}
  await new Promise(r=>setTimeout(r,500));const cache=P.wardrobeStats;if(cache.entries>96||cache.bytes>24*1024*1024||cache.pending>16||cache.busy>2)bad.push('pose cache exceeded bounds');if(!cache.workers||!cache.completed)bad.push('Chrome worker poses did not complete');
  P.game.time=start;return {bad,remoteMinimumWeight:minWeight,strafe,cache,soakMs:performance.now()-begin};
 });assert.deepEqual(motion.bad,[]);
 fs.writeFileSync(__dirname+'/out/presentation-check.json',JSON.stringify({flags,reduced,motion,errors},null,2));console.log(JSON.stringify({flags,reduced,motion,errors},null,2));assert.deepEqual(errors,[]);console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
