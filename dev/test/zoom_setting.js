// v0.9.7.1 zoom (desktops only): Settings → ZOOM changes the world's tile size within 70%-140%, is saved and comes back
// after a reload, the mouse wheel zooms in a game inside the same range, a burst of changes rebuilds the scenery once, the
// HUD doesn't move, and phones have no slider and keep their view even with a saved zoom.
const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),errors=[],out={};
 const url=`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`,wait=ms=>new Promise(r=>setTimeout(r,ms));
 const ctx=await b.newContext({viewport:{width:1366,height:820}}),p=await ctx.newPage();p.on('pageerror',e=>errors.push('desk: '+e.message));
 await p.goto(url);await p.waitForFunction(()=>window.__pal);
 out.desk=await p.evaluate(async()=>{const P=__pal,r={},w=ms=>new Promise(z=>setTimeout(z,ms));P.pick.mode='5';P.showPage('solo');document.getElementById('startBtn').click();await w(500);
  r.base=P.TW2;r.shown=getComputedStyle(document.getElementById('zoomSet')).display!=='none';
  const hud0=document.querySelector('#top .phase').getBoundingClientRect().top;
  const sl=document.getElementById('sZoom'),set=v=>{sl.value=v;sl.dispatchEvent(new Event('input'))};
  const z0=P.zoomRebuilds;for(const v of[90,110,130,140])set(v);await w(400);r.rebuilds=P.zoomRebuilds-z0;r.at140=+(P.TW2/r.base).toFixed(2);
  set(200);await w(300);r.capHigh=+(P.TW2/r.base).toFixed(2);set(10);await w(300);r.capLow=+(P.TW2/r.base).toFixed(2);
  r.hudMoved=Math.abs(document.querySelector('#top .phase').getBoundingClientRect().top-hud0)>1;
  set(100);await w(300);P.game.paused=false;const cvs=document.querySelector('canvas');
  for(let i=0;i<4;i++)cvs.dispatchEvent(new WheelEvent('wheel',{deltaY:-100,bubbles:true,cancelable:true}));await w(300);r.wheel=+(P.TW2/r.base).toFixed(2);r.wheelLabel=document.getElementById('sZoomV').textContent;
  set(125);await w(300);return r});
 await p.reload();await p.waitForFunction(()=>window.__pal);await wait(400);
 out.reload=await p.evaluate(()=>({zoom:__pal.ZOOM,label:document.getElementById('sZoomV').textContent}));
 const ph=await b.newPage({viewport:{width:390,height:844},isMobile:true,hasTouch:true});ph.on('pageerror',e=>errors.push('phone: '+e.message));
 await ph.goto(url);await ph.waitForFunction(()=>window.__pal);
 out.phone=await ph.evaluate(async()=>{const P=__pal,w=ms=>new Promise(z=>setTimeout(z,ms));const t0=P.TW2;try{const c=JSON.parse(localStorage.getItem('palisade.cfg.v1')||'{}');c.zoom=1.4;localStorage.setItem('palisade.cfg.v1',JSON.stringify(c))}catch(e){}
  location.reload();return t0});
 await ph.waitForFunction(()=>window.__pal);await wait(400);
 out.phoneAfter=await ph.evaluate(()=>({tw:__pal.TW2,zoom:__pal.ZOOM,shown:getComputedStyle(document.getElementById('zoomSet')).display!=='none'}));
 fs.writeFileSync(__dirname+'/out/zoom_setting.json',JSON.stringify(out,null,1));console.log(JSON.stringify(out));
 const d=out.desk;assert.ok(d.shown,'desktop has the slider');assert.equal(d.rebuilds,1,'a burst of changes rebuilds once');
 assert.ok(d.at140>=1.35&&d.at140<=1.45,'140% '+d.at140);assert.ok(d.capHigh<=1.45,'capped at 140%');assert.ok(d.capLow>=.65&&d.capLow<=.75,'floor 70% '+d.capLow);
 assert.ok(!d.hudMoved,'the HUD stays put');assert.ok(d.wheel>1.15,'the wheel zooms in '+d.wheel);assert.equal(d.wheelLabel,'120%');
 assert.deepEqual(out.reload,{zoom:1.25,label:'125%'},'saved and restored');
 assert.equal(out.phoneAfter.zoom,1,'phones ignore zoom');assert.equal(out.phoneAfter.tw,out.phone,'phone view unchanged');assert.equal(out.phoneAfter.shown,false,'no slider on phones');
 assert.deepEqual(errors,[]);console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
