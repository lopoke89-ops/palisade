// v0.9.7.3 City Black Out HUD: the mini-map sits top right under the phase box (desktop, portrait) or beside it on its
// left (landscape phones); it overlaps none of the phase box, START button, phase note, vitals, build kit or boss bars
// (it steps below the bars while bosses are up); it stays put when the tip box hides (B6); the kill feed sits beside it;
// on portrait phones it fades out under a banner and comes back after (B3). Three sizes. node blackout_hud.js
const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),errors=[],out={};
 const hit=(a,b)=>a&&b&&a.l<b.r-.5&&b.l<a.r-.5&&a.t<b.b-.5&&b.t<a.b-.5;
 for(const [n,vp,m]of[['desktop',{width:1366,height:820},false],['portrait',{width:390,height:844},true],['landscape',{width:844,height:390},true]]){
  const p=await b.newPage({viewport:vp,isMobile:m,hasTouch:m});p.on('pageerror',e=>errors.push(n+': '+e.message));
  await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`);await p.waitForFunction(()=>window.__pal);
  await p.evaluate(async()=>{const P=__pal;P.pick.mode='blackout';P.showPage('solo');document.getElementById('startBtn').click();await new Promise(z=>setTimeout(z,500));P.game.paused=true;P.toastClear()});
  const snap=async(bosses,extra)=>p.evaluate(async([bosses,extra])=>{const P=__pal;for(const e of P.enemies.slice())if(e.type==='boss')P.enemies.splice(P.enemies.indexOf(e),1);
    for(let i=0;i<bosses;i++)P.spawnBoss(['butcher','demolisher','butcher','demolisher'][i]);
    if(extra!=='after')P.toastClear();   // boss intros queue banners of their own
    if(extra==='notip'){const t=document.getElementById('tip');t.hidden=true}
    if(extra==='feed')P.feed('Rab took down a raider','#e8c7a0');
    if(extra==='banner')P.toast('POI UNDER ATTACK · HOSPITAL','The Butcher and 9 raiders.');
    for(let i=0;i<(extra==='after'?60:24);i++){if(extra==='after')P.toastTick(.1);else P.toastTick(0);P.hud(.03);P.render(1/60);await new Promise(z=>requestAnimationFrame(z))}
    const R=s=>{const e=typeof s==='string'?document.querySelector(s):s;if(!e||e.closest('[hidden]'))return null;const q=e.getBoundingClientRect();if(!q.width||!q.height)return null;return{l:q.left,t:q.top,r:q.right,b:q.bottom}};
    const M=P.boMapBox(),bb=P.bossBarsBox(),fd=document.getElementById('feed');
    return{W:innerWidth,H:innerHeight,mm:{l:M.x,t:M.y,r:M.x+M.w,b:M.y+M.h},bb:bb&&{l:bb.left,t:bb.top,r:bb.right,b:bb.bottom},fade:P.boFade,banner:P.toastRect(),
      phase:R('#top .phase'),vit:R('#top .vitals'),note:R('#phaseNote'),skip:R('#skipBtn'),kit:[...document.querySelectorAll('#kit > *')].map(R).filter(Boolean),
      feed:fd.children.length?R(fd):null}},[bosses,extra]);
  const res={};
  for(const [k,bosses,extra]of[['base',0,''],['boss1',1,''],['boss2',2,''],['boss4',4,''],['feed',0,'feed'],['banner',0,'banner'],['after',0,'after'],['notip',0,'notip']]){
   const r=await snap(bosses,extra),id=n+'/'+k,M=r.mm;res[k]=r;
   assert.ok(M.l>=0&&M.r<=r.W&&M.t>=0&&M.b<=r.H,id+' on screen');
   if(!r.bb){assert.ok(M.l>r.W*.55,id+' on the right '+M.l);assert.ok(M.t<(n==='landscape'?40:r.phase.b+100),id+' at the top '+M.t)}
   for(const [nm,v]of[['phase',r.phase],['note',r.note],['start',r.skip],['vitals',r.vit],['boss bars',r.bb]])assert.ok(!hit(M,v),id+' mini-map overlaps '+nm+' '+JSON.stringify({M,v}));
   for(const kk of r.kit)assert.ok(!hit(M,kk),id+' mini-map overlaps the kit '+JSON.stringify({M,kk}));
   if(n==='landscape'&&!r.bb)assert.ok(M.r<=r.phase.l&&Math.abs(M.t-r.phase.t)<=2,id+' beside the phase box, top-aligned');
   if(n!=='landscape'&&!r.bb)assert.ok(Math.abs(M.r-r.phase.r)<=2&&M.t>=r.phase.b,id+' right under the phase box');
   if(k==='feed'){assert.ok(r.feed,'feed line');assert.ok(Math.abs(r.feed.t-M.t)<=2&&r.feed.r<=M.l-4&&r.feed.r>=M.l-12,id+' feed beside the mini-map '+JSON.stringify(r.feed));
    for(const [nm,v]of[['phase',r.phase],['vitals',r.vit],['boss bars',r.bb]])assert.ok(!hit(r.feed,v),id+' feed overlaps '+nm);for(const kk of r.kit)assert.ok(!hit(r.feed,kk),id+' feed overlaps the kit')}
   if(k==='banner'){assert.ok(r.banner,id+' banner up');if(hit(M,{l:r.banner.left,r:r.banner.right,t:r.banner.top,b:r.banner.bottom}))assert.ok(r.fade<=.05,id+' fades under the banner');else assert.ok(r.fade>=.95,id+' stays when clear')}
   if(k==='after')assert.ok(!r.banner&&r.fade>=.95,id+' back after the banner '+r.fade+' '+JSON.stringify(r.banner))}
  assert.deepEqual(res.after.mm,res.base.mm,n+': the first phase note does not move the mini-map '+JSON.stringify([res.base.mm,res.after.mm]));
  assert.deepEqual(res.notip.mm,res.base.mm,n+': the mini-map stays put when the tip hides '+JSON.stringify([res.base.mm,res.notip.mm,res.base.phase,res.notip.phase]));
  assert.equal(n==='portrait'?res.banner.fade<=.05:true,true,'portrait: the banner covers the mini-map spot (B3)');
  out[n]=Object.fromEntries(Object.entries(res).map(([k,r])=>[k,{mm:r.mm,bb:r.bb,fade:r.fade,feed:r.feed}]));
  await p.evaluate(async()=>{const P=__pal;P.spawnBoss('butcher');P.feed('Rab took down a raider','#e8c7a0');for(let i=0;i<8;i++){P.hud(.03);P.render(1/60);await new Promise(z=>requestAnimationFrame(z))}});
  await p.screenshot({path:`${__dirname}/out/blackout_hud_${n}.png`});await p.close()}
 fs.writeFileSync(__dirname+'/out/blackout_hud.json',JSON.stringify(out,null,1));console.log(JSON.stringify(Object.fromEntries(Object.entries(out).map(([k,v])=>[k,v.base.mm]))));
 assert.deepEqual(errors,[]);console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
