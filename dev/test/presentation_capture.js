// Matched procedural art / animation evidence. BASELINE=1 reads the saved, ignored baseline build.
const {chromium}=require('playwright'),fs=require('node:fs'),path=require('node:path');
(async()=>{
 const before=process.env.BASELINE==='1',label=before?'before':'after',dir=path.join(__dirname,'out','presentation');fs.mkdirSync(dir,{recursive:true});
 const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),p=await b.newPage({viewport:{width:1280,height:800}}),errors=[];
 p.on('pageerror',e=>errors.push(e.message));
 if(before)await p.route('**/presentation-baseline.html*',r=>r.fulfill({contentType:'text/html',body:fs.readFileSync(path.join(__dirname,'out','presentation-baseline.html'),'utf8')}));
 await p.goto('http://localhost:8080/'+(before?'presentation-baseline':'debug')+'.html?debug=1');await p.waitForFunction(()=>window.__pal);
 const inventory=await p.evaluate(()=>Object.entries(__pal.BGS).map(([id,b])=>({id,name:b.name,rarity:b.r,static:b.still!==undefined,source:b.src,case:b.box||null})));
 fs.writeFileSync(path.join(dir,label+'-inventory.json'),JSON.stringify(inventory,null,2));
 for(const [w,h]of [[1280,800],[390,844],[844,390]]){
  const sheets=await p.evaluate(({w,h})=>{
   const P=__pal,result={};
   for(const [group,ids]of [['scenic',Object.keys(P.BGS).filter(k=>!k.startsWith('f_'))],['flags',P.FLAGS.map(f=>'f_'+f[0])]]){
    const tw=w===390?156:256,th=Math.round(tw*h/w),cols=5,cv=document.createElement('canvas');cv.width=cols*tw;cv.height=Math.ceil(ids.length/cols)*(th+24);const x=cv.getContext('2d');x.fillStyle='#161a20';x.fillRect(0,0,cv.width,cv.height);
    ids.forEach((id,i)=>{const c=document.createElement('canvas');c.width=w;c.height=h;P.drawBg(id,c.getContext('2d'),w,h,4);const px=i%cols*tw,py=Math.floor(i/cols)*(th+24);x.drawImage(c,px,py,tw,th);x.fillStyle='#fff';x.font='12px sans-serif';x.fillText(id,px+6,py+th+16)});result[group]=cv.toDataURL('image/png');
   }return result;
  },{w,h});
  for(const [group,data]of Object.entries(sheets))fs.writeFileSync(path.join(dir,`${label}-${group}-${w}x${h}.png`),Buffer.from(data.split(',')[1],'base64'));
 }
 const animation=await p.evaluate(async()=>{
  const P=__pal,cv=document.createElement('canvas');cv.width=960;cv.height=540;const x=cv.getContext('2d'),chunks=[],stream=cv.captureStream(24),rec=new MediaRecorder(stream,{mimeType:'video/webm'});rec.ondataavailable=e=>chunks.push(e.data);rec.start();
  const sheet=document.createElement('canvas');sheet.width=1440;sheet.height=440;const sx=sheet.getContext('2d');let next=0;
  const actor={cls:'soldier',cos:{skin:'std',hat:'class'},x:0,y:0,walk:0,aim:{x:1,y:0}},start=performance.now();let last=0;
  await new Promise(resolve=>{function frame(now){const t=(now-start)/1000,dt=Math.min(.05,t-last);last=t;const mode=Math.min(7,Math.floor(t)),moving=mode>=1&&mode<=4,speed=mode===2?13:10;
   if(moving){actor.x+=dt*(mode===3?-2:2);actor.y+=mode===4?dt*2:0;actor.walk+=dt*speed}P.game.time=t;
   x.fillStyle='#bbc4b4';x.fillRect(0,0,960,540);x.fillStyle='#29382e';x.font='22px sans-serif';x.fillText(['Idle','Walk','Sprint','Backpedal / aim','Strafe / turn','Stop / settle','Fire / recoil','Bolt / pump'][mode],24,36);
   for(let i=0;i<4;i++){const cls=['soldier','sniper','grenadier','quartermaster'][i],lk={...P.playerLook({...actor,cls}),...P.lookOf({skin:['std','galaxy','gknight','reaper'][i],hat:['class','tophat','ghelm','class'][i]},cls)};
    // Keep each actor's movement history stable in the after capture.
    if(P.presentationMotion)Object.assign(lk,P.presentationMotion(actor));
    if(mode===0&&P.stageBreath)lk.breath=P.stageBreath(t);
    lk.bolt=mode>=6?(t%1):-1;P.paintWardrobeCharacter(x,lk,.55+(mode===4?(t%1)*2:0),t,5,130+i*235,425,lk.walk??actor.walk);
   }
   if(t>=next+.45&&next<8){sx.drawImage(cv,0,0,960,540,(next%4)*360,Math.floor(next/4)*220,360,203);sx.fillStyle='#fff';sx.font='12px sans-serif';sx.fillText('t='+t.toFixed(2),next%4*360+6,Math.floor(next/4)*220+216);next++}
   if(t>=8){rec.stop();resolve()}else requestAnimationFrame(frame)}requestAnimationFrame(frame)});
  await new Promise(r=>rec.onstop=r);stream.getTracks().forEach(t=>t.stop());const bytes=new Uint8Array(await new Blob(chunks).arrayBuffer());let str='';for(let i=0;i<bytes.length;i+=8192)str+=String.fromCharCode(...bytes.subarray(i,i+8192));return {video:btoa(str),sheet:sheet.toDataURL('image/png')};
 });
 fs.writeFileSync(path.join(dir,label+'-animation.webm'),Buffer.from(animation.video,'base64'));fs.writeFileSync(path.join(dir,label+'-animation.png'),Buffer.from(animation.sheet.split(',')[1],'base64'));
 const perf=await p.evaluate(()=>{const P=__pal,results={};for(const [w,h]of [[390,844],[1280,800]]){const c=document.createElement('canvas');c.width=w;c.height=h;const x=c.getContext('2d');for(const id of ['campfire','hauntedfog','eventhorizon','f_progress','f_japan']){P.drawBg(id,x,w,h,4);const times=[];for(let n=0;n<90;n++){const t=performance.now();P.drawBg(id,x,w,h,4+n/30);x.getImageData(0,0,1,1);times.push(performance.now()-t)}times.sort((a,b)=>a-b);results[id+' '+w+'x'+h]={medianMs:times[45],p95Ms:times[85]}}}return {draw:results,cache:P.backgroundStats||null,wardrobe:P.wardrobeStats}});
 fs.writeFileSync(path.join(dir,label+'-perf.json'),JSON.stringify(perf,null,2));console.log('errors:',errors.length?errors:'none');await b.close();if(errors.length)process.exitCode=1;
})().catch(e=>{console.error(e);process.exit(1)});
