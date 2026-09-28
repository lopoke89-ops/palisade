const { chromium } = require('playwright');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined,args:['--autoplay-policy=no-user-gesture-required']});
const ctx=await b.newContext({viewport:{width:390,height:844},deviceScaleFactor:2});const p=await ctx.newPage();
const errs=[];p.on('pageerror',e=>errs.push(e.message+' @ '+(e.stack||'').split('\n').slice(1,3).join(' | ')));
await p.goto('http://localhost:8080/debug.html?debug=1');await p.waitForTimeout(800);await p.mouse.click(5,5);
// 1. afterglow reel: tile heights, strip visible, tick count while the menu demo runs
await p.evaluate(()=>{const P=__pal;P.locker.bag.afterglow=2;P.showPage('locker');P.renderLocker();
  // count ticks by watching oscillator creation
  window.__osc=0;const o=AudioContext.prototype.createOscillator;AudioContext.prototype.createOscillator=function(){window.__osc++;return o.call(this)}});
await p.click('[data-open=afterglow]');await p.waitForTimeout(400);await p.click('#caseIntro');await p.waitForTimeout(1500);
const r=await p.evaluate(()=>{const w=document.querySelector('.reelWrap').getBoundingClientRect();const tiles=[...document.querySelectorAll('#reel .item')];
  const hs=[...new Set(tiles.map(t=>Math.round(t.getBoundingClientRect().height)))];
  const bottoms=tiles.map(t=>t.getBoundingClientRect().bottom);return{heights:hs,stripInside:bottoms.every(y=>y<=w.bottom+.5),demo:__pal.demo,labels:tiles.slice(0,6).map(t=>t.querySelector('i').textContent+'/'+getComputedStyle(t.querySelector('i')).color).join(' ')}});
await p.screenshot({path:__dirname+'/out/v084_reel_mid.png'});await p.waitForTimeout(3500);
console.log('reel',JSON.stringify(r),'| oscillators (ticks+reveal) during spin:',await p.evaluate(()=>window.__osc));
await p.screenshot({path:__dirname+'/out/v084_reel_end.png'});await p.evaluate(()=>document.getElementById('caseDone').click());
// 2. music: solo co-op run, build phase -> plays, raid -> fades out, menu -> off
await p.evaluate(()=>__pal.showPage('solo'));await p.click('#startBtn');await p.waitForTimeout(400);
const m=async()=>p.evaluate(()=>{const M=__pal.mus,B=M.bufs.between;return{phase:__pal.game.phase,want:__pal.musicWant(),track:M.cur,loaded:!!B,playing:!!M.src,dur:B&&B.duration.toFixed(3),loopEnd:M.src&&M.src.loopEnd.toFixed(3),bus:M.bus&&M.bus.gain.value}});
await p.waitForTimeout(3500);console.log('opening build phase',JSON.stringify(await m()));
await p.keyboard.press('Enter');await p.waitForTimeout(600);console.log('raid started',JSON.stringify(await m()));
await p.evaluate(()=>{const P=__pal;P.game.wave=1;P.startBuild?P.startBuild(30):(P.game.phase='build')});await p.waitForTimeout(600);console.log('between raids',JSON.stringify(await m()));
await p.evaluate(()=>{document.getElementById('sMus').value=0;document.getElementById('sMus').dispatchEvent(new Event('input'))});await p.waitForTimeout(300);console.log('music slider 0',JSON.stringify(await m()));
await p.evaluate(()=>{document.getElementById('sMus').value=70;document.getElementById('sMus').dispatchEvent(new Event('input'))});await p.waitForTimeout(300);console.log('music slider 70',JSON.stringify(await m()));
await p.evaluate(()=>__pal.toMenu());await p.waitForTimeout(300);console.log('back to menu',JSON.stringify(await m()));
await p.evaluate(()=>__pal.showPage('settings'));await p.screenshot({path:__dirname+'/out/v084_settings.png'});
console.log('errors',errs.length?errs:'none');await b.close()})();
