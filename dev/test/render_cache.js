// Opt-in visual/cache regression against the preserved pre-change debug build.
// Run through run_targeted.ps1 -Tests render_cache; prepare render-perf baseline first.
const {chromium}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
(async()=>{
 const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined,args:['--disable-gpu','--disable-accelerated-2d-canvas']}),errors=[],results=[];
 try{
 for(const spec of[{w:390,h:844,dpr:2},{w:844,h:390,dpr:2},{w:1280,h:720,dpr:1},{w:900,h:700,dpr:1.25},{w:390,h:844,dpr:3}]){
  for(const version of['baseline','candidate']){
   const ctx=await b.newContext({viewport:{width:spec.w,height:spec.h},deviceScaleFactor:spec.dpr,hasTouch:true,isMobile:true,serviceWorkers:'block'});
   await ctx.route('**/*.supabase.co/**',r=>r.abort());
   if(version==='baseline')await ctx.route('**/cache-baseline.html?*',r=>r.fulfill({contentType:'text/html',body:fs.readFileSync(__dirname+'/out/render-perf/baseline-debug-min.html')}));
   await ctx.addInitScript(()=>{let seed=713;Math.random=()=>((seed=seed*16807%2147483647)-1)/2147483646;requestAnimationFrame=()=>1;});
   const p=await ctx.newPage();p.on('pageerror',e=>errors.push(e.message));await p.goto('http://localhost:8080/'+(version==='baseline'?'cache-baseline.html':'debug.html')+'?debug=1');await p.waitForFunction(()=>window.__pal);if(version==='candidate')assert.ok(await p.evaluate(()=>__pal.renderCacheStats),'test server must serve the current candidate build');await p.evaluate(()=>document.fonts.ready);
   for(const map of['yard','river','quarry','frost'])for(const size of['std','xl']){
    await p.evaluate(({map,size})=>{const P=__pal;P.demo=false;P.pick.map=map;P.pick.size=size;P.pick.mode='5';P.newGame();P.enterGameHook();P.game.paused=true;P.player._shotDrawUntil=1e10;}, {map,size});
    for(const [pose,[x,y]]of [[-2,1],[.5,.5],[5,8],[12,16],[25,25],[60,60],[8,9],[8.1,9.1],[8.3,9.2]].entries()){
     const state=await p.evaluate(({x,y})=>{const P=__pal;P.player.x=x;P.player.y=y;for(let n=0;n<45;n++)P.render(1/60);return {image:P.ctx.canvas.toDataURL(),cam:[P.camX,P.camY],stats:P.renderCacheStats||null};},{x,y});
     const key=`${spec.w}x${spec.h}-${spec.dpr}-${map}-${size}-${pose}`;
     const name=__dirname+'/out/render-perf/cache-'+version+'-'+key+'.png';fs.writeFileSync(name,Buffer.from(state.image.split(',')[1],'base64'));
     if(state.stats)assert.ok(state.stats.viewBytes<=16*1024*1024,'viewport cache exceeds budget');results.push({version,key,cam:state.cam,stats:state.stats});
    }
   }
   // Resize an already populated cache, rather than only testing initial sizes.
   await p.setViewportSize({width:spec.w+17,height:spec.h-13});await p.waitForTimeout(150);const resized=await p.evaluate(()=>{for(let n=0;n<45;n++)__pal.render(1/60);return {image:__pal.ctx.canvas.toDataURL(),stats:__pal.renderCacheStats||null}});
   fs.writeFileSync(__dirname+`/out/render-perf/cache-${version}-${spec.w}x${spec.h}-${spec.dpr}-resize.png`,Buffer.from(resized.image.split(',')[1],'base64'));if(resized.stats)assert.ok(resized.stats.viewBytes<=16*1024*1024);await ctx.close();
  }
 }
 assert.deepEqual(errors,[]);fs.writeFileSync(__dirname+'/out/render-perf/cache-check.json',JSON.stringify({results,errors},null,2));console.log('map changes, camera travel, fractional DPR, resize, cache memory: errors: none');
 }finally{await b.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
