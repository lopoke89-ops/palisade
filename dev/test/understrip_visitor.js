// v0.12.5: the Visitor stays the finale, loses its top third, then summons one doubled boss.
const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM});
 try {
  const page=await browser.newPage(),errors=[];
  await page.route('**/*',r=>/^(localhost|127\.0\.0\.1)$/.test(new URL(r.request().url()).hostname)?r.continue():r.abort());
  page.on('pageerror',e=>errors.push(e.message));
  await page.goto(`http://127.0.0.1:${process.env.PORT||8089}/debug.html?debug=1`);
  await page.waitForFunction(()=>window.__pal&&__pal.ready);
  const result=await page.evaluate(async()=>{
   const P=__pal;P.pick.mode='understrip';P.showPage('solo');document.getElementById('startBtn').click();
   await new Promise(r=>setTimeout(r,300));P.game.paused=true;
   const checks=[],check=(v,t)=>checks.push([!!v,t]);
   const fixture=Array.from({length:256},(_,s)=>[s,P.usAddKey(s)]).concat([2147483647,2147483648,4294967295].map(s=>[s,P.usAddKey(s)]));
   const seeds={};for(const [seed,key] of fixture)seeds[key]=seed;
   check(Object.keys(seeds).length===8,'all eight eligible bosses can be summoned');
   check(!P.US_ADD.some(k=>/ferry|harbinger|destroyer/.test(k)),'pool excludes river bosses and Supreme Destroyer');
   const start=seed=>{
    P.US_RUN.seed=seed;P.game.us.seed=seed;P.usChangeLevel(9);P.enemies.splice(0);
    const A=P.game.lay.arena,pl=P.player;pl.x=A.x+A.w/2;pl.y=A.y+A.h/2;pl.max=pl.hp=1e7;
    P.usBossWake();P.game.us.gate=2;return P.enemies[0];
   };
   for(const [key,seed] of Object.entries(seeds)){
    const v=start(seed),U=P.game.us;
    const think=dt=>P.BOSSES.visitor.think(v,dt,null,null,()=>0,P.game.Df);
    check(v.boss==='visitor'&&Math.abs(v.max-62500)<.01,key+': finale is the 62,500 HP Visitor');
    v.hp=v.max*.8;think(.05);check(U.bossStage===0&&!P.enemies.some(e=>e.usAdd),'no summon before the top third is gone');
    v.hp=v.max*.66;think(.05);
    check(v.st===82&&Math.abs(v.hp/v.max-2/3)<1e-8&&P.usBossFrac(v)===1,'transition at two-thirds health with a full stage-two bar');
    think(2.9);check(!P.enemies.some(e=>e.usAdd),'summon waits for transition to finish');think(.2);
    const add=P.enemies.find(e=>e.usAdd),B=P.BOSSES[key];
    check(add&&add.boss===key&&Math.abs(add.max-B.hp*P.BOSS_HP*P.game.Df.hp*P.mapHp()*2)<.01&&add.speed===B.speed*2&&add.us.st==='hunt',key+': seeded summon has double health/speed and hunts players');
    P.usVisitorAdd(v);check(P.enemies.filter(e=>e.usAdd).length===1,'transition cannot summon twice');
    add.hp=add.max*.5;check(P.usBossFrac(add)===.5,'support health bar uses its full health');add.hp=add.max;
    if(key==='demolisher'){
     const damageBefore=P.game.Df.dmg;
     add.st=1;add.stT=.001;add.lx=P.player.x;add.ly=P.player.y;P.updateEnemies(.02);
     check(P.rockets.some(r=>Math.abs(r.pw-2.3*P.game.Df.dmg)<1e-8),'summon rocket carries double damage');
     check(P.game.Df.dmg===damageBefore,'summon damage does not alter global difficulty');
    }
    if(key==='butcher'){
     add.hp=add.max*.3;P.updateEnemies(.02);
     check(Math.abs(add.speed-B.speed*1.25*2)<1e-8,'enraged support keeps doubled speed');
    }
    const sal=P.player.sal,credit=P.game.bossLog.length;
    P.hurtEnemy(add,1e9,P.player.id);
    check(P.player.sal===sal&&P.game.bossLog.length===credit,'killing support gives no salvage or boss credit');
    P.usBossTick(.01);check(!U.bossDown,'killing support does not clear the Visitor');
    const v2=start(seed);v2.hp=v2.max*.66;P.BOSSES.visitor.think(v2,.05,null,null,()=>0,P.game.Df);P.BOSSES.visitor.think(v2,3.1,null,null,()=>0,P.game.Df);
    const a2=P.enemies.find(e=>e.usAdd);v2.inv=0;P.hurtEnemy(v2,1e9,P.player.id);P.usBossTick(.01);
    check(a2.dead&&P.game.us.bossDown&&P.game.us.loot.some(l=>l.k==='x_eye'),'Visitor death clears support, opens exit and preserves finale reward');
   }
   return {checks,fixture};
  });
  for(const [ok,label] of result.checks)assert.ok(ok,label);
  assert.deepEqual(errors,[],'no browser script errors');
  if(process.env.VISITOR_FIXTURE)fs.writeFileSync(process.env.VISITOR_FIXTURE,JSON.stringify(result.fixture));
  console.log(`PASS understrip_visitor (${result.checks.length} checks; ${result.fixture.length} seed references)`);
 } finally {await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
