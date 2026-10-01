// Reproducible gameplay benchmark. Baseline must be saved BEFORE editing source.
// node render_perf.js baseline|candidate [software|accelerated]
// Uses real game code, fixed seeds and timesteps, one browser/viewport/DPR.
// Submission is CPU API time; readback is a separate diagnostic raster barrier,
// never GPU time. RAF spacing is measured separately from fixed-step work.
const {chromium}=require('playwright');
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const label=process.argv[2]||'candidate',backend=process.argv[3]||'software';
const root=path.resolve(__dirname,'../..'),out=path.join(__dirname,'out/render-perf');
fs.mkdirSync(out,{recursive:true});
const quant=(a,p)=>a.slice().sort((x,y)=>x-y)[Math.min(a.length-1,Math.floor(a.length*p))];
const summary=a=>({median:+quant(a,.5).toFixed(3),p95:+quant(a,.95).toFixed(3)});
function setup(scene){
 const P=__pal;window.__resetSeed(713);
 P.demo=false;P.pick.mode=scene==='winter'?'blitz':'endless';P.pick.map=scene==='winter'?'frost':scene==='night'?'quarry':'yard';P.pick.size='xl';P.cfg.fpsMode='60';P.cfg.touchLock='off';
 const count=scene==='typical'?1:6;
 P.newGame(Array.from({length:count},(_,i)=>({id:i?'bot'+i:'solo',name:'CREW '+i,cls:['soldier','sniper','grenadier','quartermaster'][i%4],cos:scene==='winter'?['aurorasovereign|aurorahalo|auroralance|solsticenova','rimewarden|rimecrest|solsticecomet|borealiscollapse','snowline|snowgoggles|snowstreak|winterbloom'][i%3]:'',sk:P.skillStr({ammo_fire:4,ammo_shock:4,ammo_blast:4})})), '');
 P.enterGameHook();
 P.NET.mode='solo';P.NET.inGame=false;
 for(const p of P.players.values()){p.hp=p.max=1e9;p.x=P.core.i+.5+(p.slot%3-1)*.8;p.y=P.core.j+2.5+Math.floor(p.slot/3)*.6;p.aim={x:0,y:-1};p.ammoEq=scene==='typical'?['','']:[p.slot%2?'fire':'blast',p.cls==='sniper'?'shock':''];p.walk=1;}
 P.qm.hp=P.qm.max=P.core.hp=P.core.max=1e9;
 let k=0;for(let j=0;j<P.N;j++)for(let i=0;i<P.N;i++){const d=Math.max(Math.abs(i-P.core.i),Math.abs(j-P.core.j));if((d===3||d===4)&&!P.walls[j*P.N+i]){const w=P.makeWall(k%3,k%11===0,[1,.6,.25][k%3]);if(k%9===0){w.fire=100;w.char=.5}P.walls[j*P.N+i]=w;k++;}}
 P.game.wave=scene==='typical'?1:15;P.game.phase='raid';P.game.queue=[];P.game.timer=99999;
 const n=scene==='typical'?12:64;
 for(let i=0;i<n;i++){const e=P.spawnEnemyAt(['rifle','gren','shield','medic','spotter','fire'][i%6],1.5+(i%8)*2.6,1.5+Math.floor(i/8)*2.6);e.hp=e.max=1e8;e.cd=999;e.speed=0;e.walk=i*.7;}
 if(scene!=='typical')for(const id of scene==='winter'?['rime','rime','tempest','bulldozer']:['bluebutcher','arsonist','tempest','bulldozer']){P.spawnBoss(id);const e=P.enemies[P.enemies.length-1];e.hp=e.max=1e8;e.x=P.core.i-2+(P.enemies.length%4)*1.3;e.y=P.core.j-2.5;e.cd=999;e.speed=0;e.st=0;e.stT=999;}
 if(scene==='winter'){P.startFinalBlitz();P.game.fb.next=1e9;P.game.fb.t=280;}
 window.__step=f=>{
  // Replenish representative real effects with identical inputs in both builds.
  if(scene!=='typical'&&f%12===0)for(const p of P.players.values())P.shoot(p,p.gun,0);
  if(scene==='winter'&&f%30===0){for(let j=0;j<8;j++)for(let i=0;i<8;i++)P.addFrost(2.5+i,6.5+j);P.killFx('solo',P.player.x-1,P.player.y-1);}
  for(const p of P.players.values()){p.hp=p.max;p.walk=(f/60)*7;p.aim={x:Math.sin(f/100),y:-Math.cos(f/100)};p.x=P.core.i+.5+(p.slot%3-1)*.8+Math.sin(f/75)*1.4;p.y=P.core.j+2.5+Math.floor(p.slot/3)*.6+Math.cos(f/90)*.8;}
  P.qm.hp=P.qm.max;P.core.hp=P.core.max;
 };
 return {scene,players:P.players.size,enemies:P.enemies.length,map:P.MAP.name,N:P.N};
}
function measure({start,n,profile=false,stageFlush=false}){
 const P=__pal,up=[],submit=[],barrier=[],total=[],hud=[];
 if(profile)P.profOn(stageFlush);
 let peakParts=0,peakBullets=0;
 for(let f=start;f<start+n;f++){
  __step(f);
  const t=performance.now();P.update(1/60);const t1=performance.now();
  P.render(1/60);const t2=performance.now();
  // Explicit synchronization for software-raster work, reported separately.
  P.ctx.getImageData(0,0,1,1);const t3=performance.now();P.hud(1/60);const t4=performance.now();
  up.push(t1-t);submit.push(t2-t1);barrier.push(t3-t2);hud.push(t4-t3);total.push(t4-t);
  peakParts=Math.max(peakParts,P.parts.length);peakBullets=Math.max(peakBullets,P.bullets.length);
 }
 return {up,submit,barrier,total,hud,stages:profile?P.prof():null,peakParts,peakBullets,state:{wave:P.game.wave,time:P.game.time,players:[...P.players.values()].map(p=>[p.id,p.x,p.y,p.hp,p.sal]),enemies:P.enemies.map(e=>[e.id,e.type,e.x,e.y,e.hp]),walls:P.walls.map(w=>w?[w.mat,w.hp,w.fire]:null),parts:P.parts.length,bullets:P.bullets.length,fields:P.frostFields.length},cache:{wardrobe:P.wardrobeStats,render:P.renderCacheStats||null}};
}
module.exports={setup,measure,summary};
if(require.main===module)(async()=>{
 const server=http.createServer((req,res)=>{let file=path.join(root,decodeURIComponent(req.url.split('?')[0]));if(!file.startsWith(root)){res.writeHead(403).end();return;}if(req.url.split('?')[0]==='/baseline.html')file=path.join(out,'baseline-debug.html');try{const body=fs.readFileSync(file);res.setHeader('Content-Type',file.endsWith('.html')?'text/html':file.endsWith('.js')?'application/javascript':file.endsWith('.css')?'text/css':file.endsWith('.woff2')?'font/woff2':'application/octet-stream');res.end(body);}catch(e){res.writeHead(404).end();}});
 await new Promise(r=>server.listen(8086,'127.0.0.1',r));
 let b;try{
 b=await chromium.launch({executablePath:process.env.CHROMIUM||'C:/Program Files/Google/Chrome/Application/chrome.exe',args:[...(backend==='software'?['--disable-gpu','--disable-accelerated-2d-canvas']:[]),'--enable-precise-memory-info']});
 const results={label,backend,browser:await b.version(),viewport:{width:390,height:844},deviceScaleFactor:2,canvasDPR:2,baseCommit:'cfca0e59edc2d920a336ca307c21124bcf6602e2',samples:Number(process.env.SAMPLES||3),framesPerSample:Number(process.env.FRAMES||480),stageBarriers:!!process.env.STAGE_FLUSH,cpuProfiler:!!process.env.PROFILE,scenes:{},errors:[]};
 for(const scene of (process.env.SCENES||'typical,dense,night,winter').split(',')){
  const runs=[];
  for(let sample=0;sample<Number(process.env.SAMPLES||3);sample++){
   const ctx=await b.newContext({viewport:results.viewport,deviceScaleFactor:2,hasTouch:true,isMobile:true,serviceWorkers:'block'});
   await ctx.route('**/*.supabase.co/**',r=>r.abort());await ctx.route('**/0.peerjs.com/**',r=>r.abort());
   await ctx.addInitScript(()=>{let seed=713;window.__resetSeed=s=>seed=s;Math.random=()=>((seed=seed*16807%2147483647)-1)/2147483646;window.__nativeRAF=window.requestAnimationFrame.bind(window);window.__raf=()=>{};window.requestAnimationFrame=fn=>(window.__raf=fn,1);window.cancelAnimationFrame=()=>{};});
   const p=await ctx.newPage();p.on('pageerror',e=>results.errors.push(e.message));
   await p.goto('http://127.0.0.1:8086/'+(label==='baseline'?'baseline.html':'debug.html')+'?debug=1');await p.waitForFunction(()=>window.__pal);await p.evaluate(()=>document.fonts.ready);await p.evaluate(setup,scene);
   // Yield between warm-up blocks so character workers and fonts settle.
   for(let j=0;j<6;j++){await p.evaluate(measure,{start:j*30,n:30});await p.waitForTimeout(80);}
   let cdp;if(process.env.PROFILE&&sample===0){cdp=await ctx.newCDPSession(p);await cdp.send('Profiler.enable');await cdp.send('Profiler.setSamplingInterval',{interval:200});await cdp.send('Profiler.start');}
   const r=await p.evaluate(measure,{start:180,n:Number(process.env.FRAMES||480),profile:sample===0,stageFlush:!!process.env.STAGE_FLUSH});runs.push(r);
   if(cdp){const {profile}=await cdp.send('Profiler.stop');fs.writeFileSync(path.join(out,`${label}-${backend}-${scene}.cpuprofile`),JSON.stringify(profile));}
   if(sample===0){
    // Freeze motion at measured state; screenshots across a 60-frame sequence
    // reveal layering, flicker and animation differences as well as still art.
    for(let j=0;j<6;j++){await p.evaluate(({f})=>{__step(f);__pal.update(1/60);__pal.render(1/60);__pal.hud(1/60);},{f:660+j});await p.screenshot({path:path.join(out,`${label}-${backend}-${scene}-${j}.png`)});}
   }
   await ctx.close();
  }
  const a=k=>runs.flatMap(r=>r[k]);const render=runs.flatMap(r=>r.submit.map((v,i)=>v+r.barrier[i]));
  results.scenes[scene]={updateMs:summary(a('up')),renderSubmissionMs:summary(a('submit')),rasterBarrierMs:summary(a('barrier')),renderWithBarrierMs:summary(render),hudMs:summary(a('hud')),totalWorkMs:summary(a('total')),overBudget60Hz:a('total').filter(v=>v>1000/60).length,frames:a('total').length,samples:runs.map(r=>({update:summary(r.up),render:summary(r.submit.map((v,i)=>v+r.barrier[i])),total:summary(r.total)})),stagesMs:Object.fromEntries(Object.entries(runs[0].stages).map(([k,v])=>[k,+(v/Number(process.env.FRAMES||480)).toFixed(3)])),peakParts:Math.max(...runs.map(r=>r.peakParts)),peakBullets:Math.max(...runs.map(r=>r.peakBullets)),cache:runs.map(r=>r.cache),states:runs.map(r=>r.state)};
  console.log(scene,JSON.stringify({...results.scenes[scene],states:undefined,samples:undefined,cache:undefined}));
 }
 assert.deepEqual(results.errors,[]);fs.writeFileSync(path.join(out,`${label}-${backend}.json`),JSON.stringify(results,null,2));console.log('errors: none');
 }finally{if(b)await b.close();await new Promise(r=>server.close(r));}
})().catch(e=>{console.error(e);process.exit(1)});
