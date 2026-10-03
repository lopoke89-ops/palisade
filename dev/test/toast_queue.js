// v0.9.7.1 round messages: two phase messages in a row both show for their full time, in order; a minor message waits
// behind phase ones; the queue keeps at most 3 waiting (dropping minor ones first); a tap dismisses; Settings → Message
// time stretches the time; phase messages get the coloured band and stay under the phase box. Three screen sizes.
const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),errors=[],out={};
 for(const [n,vp,m]of[['desktop',{width:1366,height:820},false],['portrait',{width:390,height:844},true],['landscape',{width:844,height:390},true]]){
  const p=await b.newPage({viewport:vp,isMobile:m,hasTouch:m});p.on('pageerror',e=>errors.push(n+': '+e.message));
  await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`);await p.waitForFunction(()=>window.__pal);
  out[n]=await p.evaluate(async()=>{const P=__pal,r={};P.pick.mode='5';P.showPage('solo');document.getElementById('startBtn').click();await new Promise(z=>setTimeout(z,400));P.game.paused=true;P.toastClear();
   const el=document.getElementById('toast'),cur=()=>P.toastCur?P.toastCur.big:'',tick=s=>{for(let t=0;t<s;t+=.1)P.toastTick(.1)};
   P.toast('RAID 3 BROKEN','+11 salvage each.');P.toast('POI UNDER ATTACK · HOSPITAL','The Butcher and 9 raiders.');P.toast('CASE DROP','A Supply Case.');
   r.first=cur();r.cls=el.className;r.waiting=P.toastQ.map(q=>q.big);tick(5.8);r.at58=cur();tick(.4);r.at62=cur();tick(6);r.third=cur();
   r.note=document.getElementById('phaseNote').textContent;r.noteShown=!document.getElementById('phaseNote').hidden;
   tick(3.6);r.empty=!P.toastCur&&!el.classList.contains('on');
   // queue cap: minor messages are dropped first
   P.toast('RAID 4','x');for(let i=0;i<4;i++)P.toast('MINOR '+i,'');P.toast('NEXT · GARAGE','y');r.capped=P.toastQ.map(q=>q.big);
   // tap to dismiss moves on to the next
   el.click();r.afterTap=cur();P.toastClear();
   // Message time: very long doubles a phase message
   document.querySelector('#msgSeg [data-msgt="2"]').click();P.toast('THE FINAL PUSH','Five minutes.');tick(11.8);r.long=cur();tick(.4);r.longDone=cur();
   document.querySelector('#msgSeg [data-msgt="1"]').click();
   // the panel is on screen and doesn't cover the phase box
   P.toast('RAID 5 BROKEN','A longer detail line to make sure the panel wraps and stays readable on a phone screen.');
   const t=el.getBoundingClientRect(),ph=document.querySelector('#top .phase').getBoundingClientRect();r.onScreen=t.left>=0&&t.right<=innerWidth&&t.bottom<=innerHeight;
   r.overlapPhase=!(t.right<ph.left||t.left>ph.right||t.bottom<ph.top||t.top>ph.bottom);r.small=parseFloat(getComputedStyle(el.querySelector('small')).fontSize);
   return r});await p.close()}
 fs.writeFileSync(__dirname+'/out/toast_queue.json',JSON.stringify(out,null,1));console.log(JSON.stringify(out.desktop));
 for(const [n,r]of Object.entries(out)){
  assert.equal(r.first,'RAID 3 BROKEN');assert.match(r.cls,/phase good/);assert.deepEqual(r.waiting,['POI UNDER ATTACK · HOSPITAL','CASE DROP'],'a phase message goes ahead of a minor one');
  assert.equal(r.at58,'RAID 3 BROKEN','still up at 5.8 s');assert.equal(r.at62,'POI UNDER ATTACK · HOSPITAL','the next one follows, not lost');assert.equal(r.third,'CASE DROP');
  assert.equal(r.note,'POI UNDER ATTACK · HOSPITAL');assert.ok(r.noteShown);assert.ok(r.empty);
  assert.equal(r.capped.length,3);assert.ok(r.capped.includes('NEXT · GARAGE'),'phase messages are never dropped');
  assert.equal(r.afterTap,r.capped[0],'a tap moves on');assert.equal(r.long,'THE FINAL PUSH','very long: 12 s');assert.equal(r.longDone,'');
  assert.ok(r.onScreen,n+' on screen');assert.ok(!r.overlapPhase,n+' clear of the phase box');assert.ok(r.small>=14,n+' detail text '+r.small)}
 assert.deepEqual(errors,[]);console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
