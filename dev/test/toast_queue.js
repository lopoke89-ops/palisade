// v0.9.7.1 round messages: two phase messages in a row both show for their full time, in order; a minor message waits
// behind phase ones; the queue keeps at most 3 waiting (dropping minor ones first); a tap dismisses; Settings → Message
// time stretches the time; phase messages get the coloured band and stay under the phase box. Three screen sizes.
// v0.9.7.3: 4.5 s / 3 s; a smaller banner at the top in every mode, text centred on it, clear of the HUD, the mini-map
// (it fades under the banner on portrait phones) and the boss bars (one, two or four up), in a normal raid and in Black Out.
const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),errors=[],out={};
 for(const [n,vp,m]of[['desktop',{width:1366,height:820},false],['portrait',{width:390,height:844},true],['landscape',{width:844,height:390},true]]){
  const p=await b.newPage({viewport:vp,isMobile:m,hasTouch:m});p.on('pageerror',e=>errors.push(n+': '+e.message));
  await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`);await p.waitForFunction(()=>window.__pal);
  out[n]=await p.evaluate(async()=>{const P=__pal,r={};P.pick.mode='5';P.showPage('solo');document.getElementById('startBtn').click();await new Promise(z=>setTimeout(z,400));P.game.paused=true;P.toastClear();
   const el=document.getElementById('toast'),cur=()=>P.toastCur?P.toastCur.big:'',tick=s=>{for(let t=0;t<s;t+=.1)P.toastTick(.1)};
   P.toast('RAID 3 BROKEN','+11 salvage each.');P.toast('POI UNDER ATTACK · HOSPITAL','The Butcher and 9 raiders.');P.toast('CASE DROP','A Supply Case.');
   r.first=cur();r.cls=el.className;r.waiting=P.toastQ.map(q=>q.big);tick(4.3);r.at43=cur();tick(.4);r.at47=cur();tick(4.5);r.third=cur();
   r.note=document.getElementById('phaseNote').textContent;r.noteShown=!document.getElementById('phaseNote').hidden;
   tick(3.1);r.empty=!P.toastCur&&!el.classList.contains('on');
   // queue cap: minor messages are dropped first
   P.toast('RAID 4','x');for(let i=0;i<4;i++)P.toast('MINOR '+i,'');P.toast('NEXT · GARAGE','y');r.capped=P.toastQ.map(q=>q.big);
   // tap to dismiss moves on to the next
   el.click();r.afterTap=cur();P.toastClear();
   // Message time: very long doubles a phase message
   document.querySelector('#msgSeg [data-msgt="2"]').click();P.toast('THE FINAL PUSH','Five minutes.');tick(8.8);r.long=cur();tick(.4);r.longDone=cur();
   document.querySelector('#msgSeg [data-msgt="1"]').click();
   // the panel is on screen and doesn't cover the phase box
   P.toast('RAID 5 BROKEN','A longer detail line to make sure the panel wraps and stays readable on a phone screen.');
   const t=el.getBoundingClientRect(),ph=document.querySelector('#top .phase').getBoundingClientRect();r.onScreen=t.left>=0&&t.right<=innerWidth&&t.bottom<=innerHeight;
   r.overlapPhase=!(t.right<ph.left||t.left>ph.right||t.bottom<ph.top||t.top>ph.bottom);r.small=parseFloat(getComputedStyle(el.querySelector('small')).fontSize);
   return r});await p.close()}
 // placement: every mode, with 0/1/2/4 bosses up
 const hit=(a,b)=>a&&b&&a.l<b.r-.5&&b.l<a.r-.5&&a.t<b.b-.5&&b.t<a.b-.5;
 for(const [n,vp,m]of[['desktop',{width:1366,height:820},false],['portrait',{width:390,height:844},true],['landscape',{width:844,height:390},true]])for(const mode of['5','blackout']){
  const p=await b.newPage({viewport:vp,isMobile:m,hasTouch:m});p.on('pageerror',e=>errors.push(n+'/'+mode+': '+e.message));
  await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`);await p.waitForFunction(()=>window.__pal);
  await p.evaluate(async mode=>{const P=__pal;P.pick.mode=mode;P.showPage('solo');document.getElementById('startBtn').click();await new Promise(z=>setTimeout(z,500))},mode);
  for(const bosses of[0,1,2,4]){
   const r=await p.evaluate(async bosses=>{const P=__pal;P.game.paused=true;P.toastClear();for(const e of P.enemies.slice())if(e.type==='boss')P.enemies.splice(P.enemies.indexOf(e),1);
    for(let i=0;i<bosses;i++)P.spawnBoss(['butcher','demolisher','butcher','demolisher'][i]);
    P.hud(.6);P.toast('POI UNDER ATTACK · HOSPITAL','The Butcher and 9 raiders are hitting it. Get there before it falls and the lights go out.');
    for(let i=0;i<20;i++){P.toastTick(0);P.hud(.03);P.render(1/60);await new Promise(z=>requestAnimationFrame(z))}
    const R=s=>{const e=typeof s==='string'?document.querySelector(s):s;if(!e||e.closest('[hidden]'))return null;const q=e.getBoundingClientRect();if(!q.width||!q.height)return null;return{l:q.left,t:q.top,r:q.right,b:q.bottom}};
    const el=document.getElementById('toast'),t=R(el),tt=R(el.querySelector('.tt')),sm=R(el.querySelector('small')),mm=P.game.lay&&P.game.lay.city?P.boMapBox():null,bb=P.bossBarsBox();
    const kit=[...document.querySelectorAll('#kit > *, #buildKit > *')].map(R).filter(Boolean);
    const sticks=[...document.querySelectorAll('.stick, #stickL, #stickR, .joy')].map(R).filter(Boolean);
    return{W:innerWidth,t,ttC:tt&&(tt.l+tt.r)/2,smL:sm&&sm.l,smR:sm&&sm.r,smText:sm&&(()=>{const rg=document.createRange();rg.selectNodeContents(el.querySelector('small'));const rs=[...rg.getClientRects()];return rs.length?{l:Math.min(...rs.map(x=>x.left)),r:Math.max(...rs.map(x=>x.right))}:null})(),
     vit:R('#top .vitals'),phase:R('#top .phase'),note:R('#phaseNote'),kit,sticks,feed:R('#feed')&&document.querySelector('#feed').children.length?R('#feed'):null,
     mm:mm&&{l:mm.x,t:mm.y,r:mm.x+mm.w,b:mm.y+mm.h},bb:bb&&{l:bb.left,t:bb.top,r:bb.right,b:bb.bottom},fade:P.boFade}},bosses);
   const id=`${n}/${mode}/${bosses} bosses`,T=r.t;
   assert.ok(T,id+': banner up');assert.ok(T.l>=0&&T.r<=r.W&&T.t>=0,id+' on screen '+JSON.stringify(T));
   assert.ok(T.b-T.t<=(n==='desktop'?90:100),id+' height '+(T.b-T.t));
   assert.ok(T.t<(n==='portrait'?(r.bb?r.bb.b+10:260):r.bb?Math.max(20,r.bb.b+10):20),id+' in the top band '+T.t);
   const pc=(T.l+T.r)/2;assert.ok(Math.abs(r.ttC-pc)<=2,id+' title centred '+r.ttC+' vs '+pc);
   if(r.smText)assert.ok(Math.abs((r.smText.l+r.smText.r)/2-pc)<=2,id+' detail centred '+JSON.stringify(r.smText)+' vs '+pc);
   for(const [k,v]of[['vitals',r.vit],['phase',r.phase],['note',r.note],['boss bars',r.bb],['feed',r.feed]])assert.ok(!hit(T,v),id+' overlaps '+k+' '+JSON.stringify({T,v}));
   for(const k of r.kit)assert.ok(!hit(T,k),id+' overlaps the kit '+JSON.stringify({T,k}));
   for(const k of r.sticks)assert.ok(!hit(T,k),id+' overlaps a joystick');
   if(r.mm){if(n==='portrait')assert.ok(!hit(T,r.mm)||r.fade<=.05,id+' mini-map fades under the banner '+r.fade);else assert.ok(!hit(T,r.mm),id+' overlaps the mini-map')}
   out[id]={banner:T,bb:r.bb,mm:r.mm,fade:r.fade};
   if(bosses===1)await p.screenshot({path:`${__dirname}/out/toast_${n}_${mode}.png`})}
  await p.close()}
 fs.writeFileSync(__dirname+'/out/toast_queue.json',JSON.stringify(out,null,1));console.log(JSON.stringify(out.desktop));
 for(const [n,r]of Object.entries(out)){if(n.includes('/'))continue;
  assert.equal(r.first,'RAID 3 BROKEN');assert.match(r.cls,/phase good/);assert.deepEqual(r.waiting,['POI UNDER ATTACK · HOSPITAL','CASE DROP'],'a phase message goes ahead of a minor one');
  assert.equal(r.at43,'RAID 3 BROKEN','still up at 4.3 s');assert.equal(r.at47,'POI UNDER ATTACK · HOSPITAL','the next one follows, not lost');assert.equal(r.third,'CASE DROP');
  assert.equal(r.note,'POI UNDER ATTACK · HOSPITAL');assert.ok(r.noteShown);assert.ok(r.empty);
  assert.equal(r.capped.length,3);assert.ok(r.capped.includes('NEXT · GARAGE'),'phase messages are never dropped');
  assert.equal(r.afterTap,r.capped[0],'a tap moves on');assert.equal(r.long,'THE FINAL PUSH','very long: 9 s');assert.equal(r.longDone,'');
  assert.ok(r.onScreen,n+' on screen');assert.ok(!r.overlapPhase,n+' clear of the phase box');assert.ok(r.small>=13,n+' detail text '+r.small)}
 assert.deepEqual(errors,[]);console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
