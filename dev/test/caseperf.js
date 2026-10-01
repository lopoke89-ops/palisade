// Matched phone/software Canvas opening benchmark. PAGE, QTY, SAMPLES, CHROMIUM override defaults.
const {chromium}=require('playwright'),fs=require('node:fs');
const label=process.argv[2]||process.env.LABEL||'candidate',qty=+(process.env.QTY||1),samples=+(process.env.SAMPLES||3);
const pageName=process.env.PAGE||'debug.html',url=`http://localhost:${process.env.PORT||8080}/${pageName}?debug=1`,repeat=process.env.REPEAT==='1';
const dist=a=>{a=a.slice().sort((a,b)=>a-b);return {median:a[Math.floor(a.length*.5)]||0,p95:a[Math.floor(a.length*.95)]||0,max:a.at(-1)||0,n:a.length}};
(async()=>{const browser=await chromium.launch({executablePath:process.env.CHROMIUM||undefined,args:['--disable-gpu','--disable-accelerated-2d-canvas']});
 const page=await browser.newPage({viewport:{width:390,height:844},deviceScaleFactor:3,hasTouch:true,isMobile:true}),errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.addInitScript(()=>{let seed=961;Math.random=()=>((seed=Math.imul(seed,1664525)+1013904223|0)>>>0)/4294967296});
 const cdp=await page.context().newCDPSession(page);await cdp.send('Performance.enable');
 const metrics=async()=>Object.fromEntries((await cdp.send('Performance.getMetrics')).metrics.map(m=>[m.name,m.value]));
 const runs=[];
 for(let s=0;s<samples;s++){
  if(s===0||!repeat)await page.goto(url);await page.waitForFunction(()=>window.__pal);await page.evaluate(()=>{__pal.cfg.music=0;__pal.cfg.volume=0;__pal.locker.cases=100;__pal.showPage('locker');__pal.renderLocker();window.__reads=0;if(window.__casePerfInstrumented)return;window.__casePerfInstrumented=true;const read=getComputedStyle;window.getComputedStyle=(e,...a)=>{if(e?.classList.contains('reel'))window.__reads++;return read(e,...a)};window.__frameD=[];let last=0;function frame(t){if(last)window.__frameD.push(t-last);last=t;requestAnimationFrame(frame)}requestAnimationFrame(frame)});await page.waitForTimeout(800);
  const measure=async(ms,trigger)=>{await page.evaluate(()=>window.__frameD.length=0);const a=await metrics();await trigger();await page.waitForTimeout(ms);const b=await metrics(),frames=await page.evaluate(()=>window.__frameD.slice());return {cpu_ms_per_s:(b.TaskDuration-a.TaskDuration)*1000/(ms/1000),layouts:b.LayoutCount-a.LayoutCount,style_recalcs:b.RecalcStyleCount-a.RecalcStyleCount,frame_ms:dist(frames),heap_bytes:b.JSHeapUsedSize,dom_nodes:b.Nodes}};
  const intro=await measure(2600,()=>page.click(qty===5?'[data-open5=supply]':'[data-open=supply]'));
  const setup0=await metrics(),setupT=Date.now();await page.waitForFunction(()=>!__pal.caseIntroOn);await page.waitForFunction(()=>document.querySelectorAll('#reel .item').length>0);const setup1=await metrics(),setup={remaining_intro_and_reel_setup_ms:Date.now()-setupT,cpu_ms:(setup1.TaskDuration-setup0.TaskDuration)*1000};
  const reel=await measure(3400,async()=>{});reel.computed_style_reads=await page.evaluate(()=>window.__reads);
  await page.waitForFunction(()=>!document.getElementById('caseResult').hidden);
  const correct=await page.evaluate(q=>{if(q===1)return document.querySelectorAll('#reel .item')[document.querySelector('#reel').dataset.win||29]?.querySelector('b')?.textContent===document.getElementById('caseName').textContent;return [...document.querySelectorAll('.caseResultRow')].length===5&&[...document.querySelectorAll('.reel')].every((r,i)=>r.querySelectorAll('.item')[r.dataset.win]?.dataset.item===document.querySelectorAll('.caseResultRow')[i]?.dataset.item)},qty);
  await page.screenshot({path:__dirname+`/out/caseperf-${label}-${qty}.png`});
  const latency=await page.evaluate(async()=>{const t=performance.now();document.getElementById('caseDone').click();await new Promise(requestAnimationFrame);return performance.now()-t});
  await cdp.send('HeapProfiler.collectGarbage');const retained=(await metrics()).JSHeapUsedSize;runs.push({intro,reel,setup,correct,input_response_ms:latency,retained_heap_bytes:retained,art_cache:await page.evaluate(()=>__pal.caseArtStats||null)});
 }
 const result={label,qty,samples,browser:browser.version(),viewport:[390,844,3],runs,errors};fs.writeFileSync(__dirname+`/out/caseperf-${label}-${qty}.json`,JSON.stringify(result,null,2));console.log(JSON.stringify(result));console.log('errors:',errors.length?errors:'none');await browser.close();if(errors.length||runs.some(r=>!r.correct))process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1});
