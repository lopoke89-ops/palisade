// Actual game-loop RAF cadence and sustained memory check, without readbacks.
// node render_playback.js baseline|candidate software|default
// SCENES=typical,dense,night,winter SAMPLES=2 SECONDS=12 (defaults)
const {chromium}=require('playwright'),fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {setup,summary}=require('./render_perf');
const label=process.argv[2]||'candidate',backend=process.argv[3]||'default',root=path.resolve(__dirname,'../..'),out=path.join(__dirname,'out/render-perf');
(async()=>{
 const server=http.createServer((req,res)=>{let f=path.join(root,decodeURIComponent(req.url.split('?')[0]));if(req.url.startsWith('/baseline.html'))f=path.join(out,'baseline-debug.html');try{res.setHeader('Content-Type',f.endsWith('.html')?'text/html':f.endsWith('.js')?'application/javascript':f.endsWith('.woff2')?'font/woff2':'application/octet-stream');res.end(fs.readFileSync(f));}catch(e){res.writeHead(404).end();}});await new Promise(r=>server.listen(8087,'127.0.0.1',r));
 let b;try{
 b=await chromium.launch({executablePath:process.env.CHROMIUM||'C:/Program Files/Google/Chrome/Application/chrome.exe',args:backend==='software'?['--disable-gpu','--disable-accelerated-2d-canvas']:[]});
 const data={label,backend,browser:await b.version(),viewport:{width:390,height:844},deviceScaleFactor:2,seconds:Number(process.env.SECONDS||12),scenes:{},errors:[]};
 const browserSession=await b.newBrowserCDPSession();const info=await browserSession.send('SystemInfo.getInfo');data.hardware={gpuDevices:info.gpu.devices,featureStatus:info.gpu.featureStatus,auxAttributes:info.gpu.auxAttributes};
 for(const scene of(process.env.SCENES||'typical,dense,night,winter').split(',')){
  const samples=[];
  for(let sample=0;sample<Number(process.env.SAMPLES||2);sample++){
   const ctx=await b.newContext({viewport:data.viewport,deviceScaleFactor:2,hasTouch:true,isMobile:true,serviceWorkers:'block'});await ctx.route('**/*.supabase.co/**',r=>r.abort());
   await ctx.addInitScript(()=>{let seed=713;window.__resetSeed=s=>seed=s;Math.random=()=>((seed=seed*16807%2147483647)-1)/2147483646;window.__nativeRAF=requestAnimationFrame.bind(window);window.requestAnimationFrame=fn=>(window.__raf=fn,1);});
   const p=await ctx.newPage();p.on('pageerror',e=>data.errors.push(e.message));await p.goto('http://127.0.0.1:8087/'+(label==='baseline'?'baseline.html':'debug.html')+'?debug=1');await p.waitForFunction(()=>window.__pal);await p.evaluate(()=>document.fonts.ready);await p.evaluate(setup,scene);
   const cdp=await ctx.newCDPSession(p);await cdp.send('HeapProfiler.collectGarbage');const heapBefore=(await cdp.send('Runtime.getHeapUsage')).usedSize;
   const heapCheckpoints=[];let monitor=Promise.resolve();const monitorStart=Date.now();
   const timer=process.env.MEMORY?setInterval(()=>{monitor=monitor.then(async()=>{await cdp.send('HeapProfiler.collectGarbage');heapCheckpoints.push({seconds:+((Date.now()-monitorStart)/1000).toFixed(1),...(await cdp.send('Runtime.getHeapUsage'))});});},10000):null;
   const r=await p.evaluate(seconds=>new Promise(resolve=>{
    const work=[],spacing=[],memory=[],cache=[];let n=0,last=0,t0=0;
    function tick(now){if(!t0)t0=now;__step(n++);const t=performance.now();__raf(now);const cost=performance.now()-t;
     if(now-t0>3000){work.push(cost);if(last)spacing.push(now-last);}last=now;
     if(n%120===0){memory.push(performance.memory?performance.memory.usedJSHeapSize:null);cache.push(__pal.renderCacheStats||null);}
     if(now-t0<(seconds+3)*1000)__nativeRAF(tick);else resolve({work,spacing,memory,cache,frames:work.length,simTime:__pal.game.time,entities:{parts:__pal.parts.length,enemies:__pal.enemies.length,players:__pal.players.size},wardrobe:__pal.wardrobeStats});
    }__nativeRAF(tick);
   }),data.seconds);
   if(timer)clearInterval(timer);await monitor;await cdp.send('HeapProfiler.collectGarbage');r.heapBeforeBytes=heapBefore;r.heapAfterBytes=(await cdp.send('Runtime.getHeapUsage')).usedSize;r.heapCheckpoints=heapCheckpoints;samples.push(r);await ctx.close();
  }
  const spacing=samples.flatMap(r=>r.spacing),work=samples.flatMap(r=>r.work);
  data.scenes[scene]={callbackWorkMs:summary(work),rafIntervalMs:summary(spacing),delayedIntervalsOver25Ms:spacing.filter(v=>v>25).length,estimatedMissed60HzSlots:spacing.reduce((n,v)=>n+Math.max(0,Math.round(v/(1000/60))-1),0),frames:work.length,samples:samples.map(r=>({...r,work:undefined,spacing:undefined}))};console.log(scene,JSON.stringify(data.scenes[scene]));
 }
 assert.deepEqual(data.errors,[]);fs.writeFileSync(path.join(out,`${label}-${backend}-playback${process.env.OUTPUT_TAG||''}.json`),JSON.stringify(data,null,2));console.log('errors: none');
 }finally{if(b)await b.close();await new Promise(r=>server.close(r));}
})().catch(e=>{console.error(e);process.exit(1)});
