// v0.9.7 Phase 0 gate, kept as a regression test: the 64×64 city with 60 raiders on screen against Quarry XL (the biggest
// map before it) on the same machine, desktop and phone viewports. Headless Chromium has no GPU, so absolute frame times
// mean little here: the city must stay within 1.6× of Quarry XL's frame time, its painted chunks must stay under the
// keep budget (far ones evicted) and its chunk memory under 120 MB. Real-phone numbers are in dev/evidence.
const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),errors=[],out={};
 for(const [vn,vp,m] of [['desktop',{width:1366,height:820},false],['phone',{width:844,height:390},true]]){
  for(const scen of vn==='desktop'?['quarryxl','city','city70']:['quarryxl','city']){   // city70: the desktop zoom at its widest (v0.9.7.1)
   const p=await b.newPage({viewport:vp,isMobile:m,hasTouch:m,deviceScaleFactor:m?3:1});p.on('pageerror',e=>errors.push(vn+' '+scen+': '+e.message));
   await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`);await p.waitForFunction(()=>window.__pal);
   out[vn+':'+scen]=await p.evaluate(async scen=>{const P=__pal;
    if(scen==='city70'){const sl=document.getElementById('sZoom');sl.value=70;sl.dispatchEvent(new Event('input'));await new Promise(r=>setTimeout(r,300))}
    if(scen.startsWith('city'))P.pick.mode='blackout';else{P.pick.mode='5';P.pick.map='quarry';P.pick.size='xl'}
    P.showPage('solo');document.getElementById('startBtn').click();await new Promise(r=>setTimeout(r,1200));
    const g=P.game;g.paused=true;const pl=P.player;
    for(let n=0;n<60;n++){const a=n*2.4,r=2+(n%10)*.8;P.spawnEnemyAt(['rifle','gren','shield','fire','breach'][n%5],Math.max(1,Math.min(P.N-2,pl.x+Math.cos(a)*r)),Math.max(1,Math.min(P.N-2,pl.y+Math.sin(a)*r)))}
    g.phase='raid';if(g.bo)g.bo.stage='done';for(const e of P.enemies){e.hp=e.max=1e6}
    const frame=()=>{const t=performance.now();g.paused=false;P.update(1/60);g.paused=true;P.render(1/60);return performance.now()-t};
    for(let i=0;i<30;i++)frame();
    const ts=[];let maxChunks=0;for(let i=0;i<240;i++){if(i%20===0){pl.x=Math.min(P.N-3,pl.x+.9);pl.y=Math.min(P.N-3,pl.y+.4)}ts.push(frame());const c=P.chunkStats;if(c)maxChunks=Math.max(maxChunks,c.back+c.front)}
    ts.sort((a,b)=>a-b);const c=P.chunkStats,mem=P.renderCacheStats;
    return{avg:+(ts.reduce((a,b)=>a+b,0)/ts.length).toFixed(2),p95:+ts[Math.floor(ts.length*.95)].toFixed(2),N:P.N,enemies:P.enemies.length,chunks:c,maxChunks,mb:+(((mem&&mem.sourceBytes)||0)/1048576).toFixed(1)}},scen);
   await p.close()}}
 fs.writeFileSync(__dirname+'/out/blackout_perf.json',JSON.stringify(out,null,1));console.log(JSON.stringify(out));
 {const z=out['desktop:city70'],q=out['desktop:quarryxl'];assert.ok(z.avg<=q.avg*2.2+2,'zoomed out to 70%: '+z.avg+' ms vs Quarry XL '+q.avg+' ms');assert.ok(z.mb<160,'70% chunk memory '+z.mb+' MB')}
 for(const vn of['desktop','phone']){const c=out[vn+':city'],q=out[vn+':quarryxl'];
  assert.equal(c.N,64);assert.ok(c.enemies>=60);assert.ok(c.chunks,'the city paints in chunks');
  assert.ok(c.avg<=q.avg*1.6+2,vn+': city '+c.avg+' ms vs Quarry XL '+q.avg+' ms');
  assert.ok(c.maxChunks<=2*c.chunks.keep+2,vn+': chunks evicted ('+c.maxChunks+' held, keep '+c.chunks.keep+')');
  assert.ok(c.mb<120,vn+': chunk memory '+c.mb+' MB')}
 assert.deepEqual(errors,[]);console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
