// Opt-in same-browser A/B, with actual Canvas readback to finish queued drawing.
const {chromium}=require('playwright'),fs=require('node:fs');
(async()=>{const browser=await chromium.launch({executablePath:process.env.CHROMIUM||undefined,args:['--enable-precise-memory-info']}),runs={before:[],after:[]},errors=[];
for(let trial=0;trial<3;trial++)for(const label of trial%2?['after','before']:['before','after']){const file=label==='before'?'cosmetics-baseline.html':'debug.html';
const p=await browser.newPage({viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true,hasTouch:true});p.on('pageerror',e=>errors.push(e.message));
if(label==='before')await p.route('**/cosmetics-baseline.html*',r=>r.fulfill({contentType:'text/html',body:fs.readFileSync(__dirname+'/out/cosmetics-baseline.html','utf8')}));
await p.goto('http://localhost:8080/'+file+'?debug=1');await p.waitForFunction(()=>window.__pal);
const cdp=await p.context().newCDPSession(p),trace=[];cdp.on('Tracing.dataCollected',e=>trace.push(...e.value));
await cdp.send('HeapProfiler.startSampling',{samplingInterval:16384,includeObjectsCollectedByMajorGC:true,includeObjectsCollectedByMinorGC:true});
await cdp.send('Tracing.start',{categories:'v8,disabled-by-default-v8.gc',transferMode:'ReportEvents'});
const started=Date.now(),result=await p.evaluate(()=>{const P=__pal,out={};P.demo=false;P.game.paused=true;document.querySelector('#menu').hidden=true;
for(const mode of ['flags','other'])for(const count of [100,300]){const cv=document.createElement('canvas');cv.width=780;cv.height=844;const x=cv.getContext('2d',{willReadFrequently:true}),list=Object.entries(P.TRAILS).filter(([k])=>mode==='flags'?k.startsWith('f_'):!k.startsWith('f_')).map(([,v])=>v),times=[],mem0=performance.memory?.usedJSHeapSize;
for(let frame=0;frame<200;frame++){const t=performance.now();x.clearRect(0,0,780,844);for(let j=0;j<count;j++){const px=25+j%12*62,py=20+Math.floor(j/12)*30;P.traceSeg(x,px,py,px+46,py+9,list[j%list.length],2.5,frame/60,false,j)}x.getImageData(0,0,1,1);if(frame>=40)times.push(performance.now()-t)}
times.sort((a,b)=>a-b);const operations={};for(const name of ['drawImage','fillRect','fill','stroke','clip','save','restore']){const original=x[name].bind(x);x[name]=(...args)=>{operations[name]=(operations[name]||0)+1;return original(...args)}}
for(let j=0;j<count;j++)P.traceSeg(x,25,25,71,34,list[j%list.length],2.5,0,false,j);
out[mode+'-'+count]={medianMs:times[80],p95Ms:times[152],p99Ms:times[158],operationsPerTracer:Object.fromEntries(Object.entries(operations).map(([k,v])=>[k,v/count])),heapDeltaBytes:(performance.memory?.usedJSHeapSize||0)-(mem0||0)};
}return out;});
const elapsedMs=Date.now()-started,{profile}=await cdp.send('HeapProfiler.stopSampling');
const finished=new Promise(resolve=>cdp.once('Tracing.tracingComplete',resolve));await cdp.send('Tracing.end');await finished;
const gc=trace.filter(e=>e.ph==='X'&&['MinorGC','MajorGC'].includes(e.name));
result.memory={sampledAllocatedBytes:profile.samples.reduce((s,v)=>s+v.size,0),elapsedMs,gcEvents:gc.length,gcTotalMs:gc.reduce((s,v)=>s+(v.dur||0)/1000,0),gcMaxMs:Math.max(0,...gc.map(v=>(v.dur||0)/1000))};
runs[label].push(result);await p.close();}
const median=a=>a.sort((a,b)=>a-b)[Math.floor(a.length/2)],results={};for(const label of ['before','after']){results[label]={};for(const key of ['flags-100','flags-300','other-100','other-300']){const list=runs[label].map(r=>r[key]);results[label][key]={medianMs:median(list.map(v=>v.medianMs)),p95Ms:median(list.map(v=>v.p95Ms)),p99Ms:median(list.map(v=>v.p99Ms)),operationsPerTracer:list[0].operationsPerTracer}}results[label].memory=Object.fromEntries(Object.keys(runs[label][0].memory).map(k=>[k,median(runs[label].map(r=>r.memory[k]))]));}
const report={method:'Three interleaved A/B trials in desktop Chrome; touch 390x844 DPR2 page; 780x844 software canvas; each workload 40 warmups +160 samples with readback. V8 sampling/GC trace cover the entire workload, including cache warmup and page activity. Heap delta is retained heap, not allocation. Not a physical phone or full-game FPS claim.',results,runs,errors};fs.writeFileSync(__dirname+'/out/tracer_perf.json',JSON.stringify(report,null,2));console.log(JSON.stringify({results,errors},null,2));console.log('errors:',errors.length?errors:'none');await browser.close();if(errors.length)process.exitCode=1;})().catch(e=>{console.error(e);process.exit(1)});
