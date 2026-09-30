// Same-browser A/B benchmark. Fresh software-backed canvases avoid Chrome changing readback strategies mid-run.
const {chromium}=require('playwright'),fs=require('node:fs');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),results={},errors=[];
 for(const [label,file]of [['before','presentation-baseline.html'],['after','debug.html']]){
  const p=await b.newPage({viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true,hasTouch:true});p.on('pageerror',e=>errors.push(label+': '+e.message));
  if(label==='before')await p.route('**/presentation-baseline.html*',r=>r.fulfill({contentType:'text/html',body:fs.readFileSync(__dirname+'/out/presentation-baseline.html','utf8')}));
  await p.goto('http://localhost:8080/'+file+'?debug=1');await p.waitForFunction(()=>window.__pal);await p.waitForTimeout(200);
  results[label]=await p.evaluate(async()=>{const P=__pal,draw={};document.querySelector('#menu').hidden=true;P.demo=false;
   for(const [w,h]of [[390,844],[844,390],[1280,800]])for(const id of ['campfire','hauntedfog','eventhorizon','f_progress','f_japan']){
    const cv=document.createElement('canvas');cv.width=w;cv.height=h;const x=cv.getContext('2d',{willReadFrequently:true}),t0=performance.now();P.drawBg(id,x,w,h,4);x.getImageData(0,0,1,1);const cold=performance.now()-t0,times=[];
    for(let i=0;i<160;i++){const t=performance.now();P.drawBg(id,x,w,h,4+i/30);x.getImageData(0,0,1,1);if(i>=20)times.push(performance.now()-t)}times.sort((a,b)=>a-b);draw[id+' '+w+'x'+h]={coldMs:+cold.toFixed(2),medianMs:+times[70].toFixed(2),p95Ms:+times[133].toFixed(2)};
   }
   const c=document.createElement('canvas');c.width=300;c.height=300;const x=c.getContext('2d',{willReadFrequently:true}),times=[];
   for(let i=0;i<120;i++){const look=P.lookOf({skin:'gknight',hat:'ghelm'},'grenadier'),t=performance.now();P.paintWardrobeCharacter(x,look,.6,i/30,3,150,200,i*.13);x.getImageData(0,0,1,1);if(i>19)times.push(performance.now()-t)}times.sort((a,b)=>a-b);
   const look=P.lookOf({skin:'std',hat:'class'},'soldier');for(let i=0;i<60;i++){P.drawWardrobeCharacter(x,look,i*.03,i*.03,2,150,200,i*.1);await new Promise(r=>setTimeout(r,16))}await new Promise(r=>setTimeout(r,250));
   return {draw,uncachedKnight:{medianMs:times[50],p95Ms:times[95]},backgroundCache:P.backgroundStats||null,poseCache:P.wardrobeStats};
  });await p.close();
 }
 fs.writeFileSync(__dirname+'/out/presentation/performance-comparison.json',JSON.stringify({method:'Desktop Chrome, emulated 390x844 DPR 2 touch context; CSS-size software canvases, 20 warmups + 140 timed draw/readback iterations. No CPU throttle. Not physical-phone frame times.',results,errors},null,2));console.log(JSON.stringify(results,null,2));console.log('errors:',errors.length?errors:'none');await b.close();if(errors.length)process.exitCode=1;
})().catch(e=>{console.error(e);process.exit(1)});
