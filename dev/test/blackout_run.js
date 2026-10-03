// v0.9.7 City Black Out, the run: gathering, the attack order (minors then majors), held / lost / pulled-back outcomes,
// raiders walking to their POI, the perks turning on and off, the final push's penalties and boss cap, the Supreme
// Destroyer at 3:00 with shield and grenadier squads only, killing him ends the run, and Main Command falling loses it.
const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),errors=[];
 const p=await b.newPage({viewport:{width:1280,height:800}});p.on('pageerror',e=>errors.push(e.message));
 await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`);await p.waitForFunction(()=>window.__pal);
 const out=await p.evaluate(async()=>{const P=__pal,r={};
  let s=11;Math.random=()=>(s=(s*16807)%2147483647)/2147483647;
  P.pick.mode='blackout';P.showPage('solo');document.getElementById('startBtn').click();await new Promise(z=>setTimeout(z,400));
  const g=()=>P.game,pl=P.player,god=()=>{pl.max=pl.hp=1e6;pl.alive=true;pl.downed=false;P.core.hp=P.core.max};
  const step=(sec,each)=>{for(let t=0;t<sec;t+=1/20){god();if(each)each();g().paused=false;P.update(1/20);g().paused=true;if(g().phase==='over')break}};
  g().paused=true;
  r.map=g().map;r.N=P.N;r.gather=Math.round(g().timer);r.phase0=g().phase;r.pois=P.cores.length-1;
  P.qm.alive=false;P.qm.gone=true;   // Delgado's kills would add salvage
  step(1);const B=()=>g().bo;r.purse=pl.sal;r.order=B().order.map(i=>P.cores[i].poi.major);r.stage0=B().stage;
  r.shopGather=P.canShop?null:null;
  // the first target is called out before the gathering ends (15 s with the Radio Tower)
  step(30);r.warnedAt=B().warned;r.nextFlag=P.cores[B().order[0]].next;
  step(15);r.stage1=B().stage;r.phase1=g().phase;const c1=B().cur.ci;r.firstIsOrder0=c1===B().order[0];
  const boss1=P.enemies.find(e=>e.type==='boss');r.bossPoi=boss1&&boss1.poi===c1;
  // troops arrive tagged to the POI, and walk toward it (on its own flow field)
  step(6);const tr=P.enemies.filter(e=>e.type!=='boss');r.troops=tr.length;r.troopsTagged=tr.every(e=>e.poi===c1);
  const C1=P.cores[c1],d0=tr.map(e=>Math.hypot(e.x-C1.i,e.y-C1.j));step(4);r.closer=tr.filter((e,n)=>!e.dead&&Math.hypot(e.x-C1.i,e.y-C1.j)<d0[n]-.5).length;
  r.flowFinite=P.poiFlow(c1)[C1.j*P.N+C1.i+1]<1e5;
  // held: the boss goes down, the rest pull back
  P.hurtEnemy(boss1,1e9,pl.id);step(.2);r.held=B().held;r.after1=B().stage;r.leftOver=P.enemies.filter(e=>e.poi===c1).length;r.log1=B().log[0][1];
  r.shopGap=P.shopOpen(pl);
  // the gap is 30 s, then the next one (pulled back after 60 s: held but damaged)
  r.shopAtPoi=(()=>{const c=P.cores.find(o=>o.poi&&!o.lost),x=pl.x,y=pl.y;pl.x=c.i+.5;pl.y=c.j+2;const s=P.canShop(pl),fix=(P.core.hp=P.core.max-60,P.repairCore(pl));P.core.hp=P.core.max;pl.x=x;pl.y=y;return[s,fix]})();
  step(34.5);r.stillGap=B().stage;step(1);r.stage2=B().stage;const c2=B().cur.ci;
  r.shopInAttack=(()=>{const c=P.cores.find(o=>o.poi&&!o.lost),x=pl.x,y=pl.y;pl.x=c.i+.5;pl.y=c.j+2;const s=P.canShop(pl);pl.x=x;pl.y=y;return s})();
  const sal2=pl.sal;
  step(61,()=>{const c=P.cores[c2];c.hp=Math.max(c.hp,c.max*.5);for(const e of P.enemies)if(e.type==='boss')e.hp=e.max});r.log2=B().log[1];r.pay2=pl.sal-sal2;r.dmg2=P.cores[c2].hp<P.cores[c2].max;
  // repairs during the quiet
  const h0=P.cores[c2].hp;step(5);r.repaired=P.cores[c2].hp>h0;
  // make the Power Station the next one and lose it: the streetlights go and the city darkens
  const pw=P.cores.findIndex(c=>c.poi&&c.poi.perk==='lights');B().order.splice(B().n,0,pw);B().order=B().order.filter((v,i,a)=>a.indexOf(v)===i);
  step(35);r.cur3=B().cur&&B().cur.ci===pw;const sal3=pl.sal;P.cores[pw].hp=0;step(.2);r.pay3=pl.sal-sal3;r.lost=B().lost;r.dark=!!g().dark;r.pwLost=P.cores[pw].lost;
  step(3);r.lightL=+P.light.L.toFixed(2);
  // perks: Hospital heals, Gas Station pays 25% more nearby, the Parking Garage gives range
  const H=P.cores.find(c=>c.poi&&c.poi.perk==='heal'),G=P.cores.find(c=>c.poi&&c.poi.perk==='salvage'),R=P.cores.find(c=>c.poi&&c.poi.perk==='range');
  pl.x=H.i+.5;pl.y=H.j+2.5;pl.max=100;pl.hp=50;g().paused=false;P.update(1);g().paused=true;r.healed=+(pl.hp-50).toFixed(1);
  r.gas=[P.boSalvage({x:G.i+1,y:G.j+1}),P.boSalvage({x:G.i+20,y:G.j+20})];r.high=[P.boHigh({x:R.i+.5,y:R.j+1.5}),P.boHigh({x:R.i+9,y:R.j})];
  H.lost=true;pl.hp=50;g().paused=false;P.update(1);g().paused=true;r.healLost=+(pl.hp-50).toFixed(1);H.lost=false;
  // the final push: lose a major and a minor first so the penalties show
  const mn=P.cores.findIndex(c=>c.poi&&!c.poi.major&&!c.lost);P.cores[mn].lost=true;
  P.boReviveMul&&0;B().order.length=B().n;   // no attacks left
  if(B().stage==='attack'){P.boEnd('held')}
  for(let w=0;w<800&&B().stage!=='ready';w++)step(.05);r.readyStage=B().stage;const salR=pl.sal;r.readyT=Math.round(B().t);step(88);r.stillReady=B().stage;
  P.boReady(pl);step(.2);r.push=B().stage;const F=B().push;r.xs=F&&F.xs;r.hpMul=F&&F.hp;
  let maxBoss=0;step(170,()=>{let n=0;for(const e of P.enemies)if(e.type==='boss'&&!e.dead)n++;maxBoss=Math.max(maxBoss,n)});r.maxBoss=maxBoss;r.pushBosses=F.n;
  step(12);r.dest=F.dest;const D=P.enemies.find(e=>e.dest);r.destUp=!!D;
  for(const e of P.enemies)e.seenT=1;const seen=new Set();step(45,()=>{for(const e of P.enemies)if(!e.seenT&&e.type!=='boss'){e.seenT=1;if(e.push&&F.dest)seen.add(e.type)}});r.squads=[...seen].sort();
  r.overBefore=g().phase;P.hurtEnemy(D,1e9,pl.id);step(.3);r.overAfter=g().phase;r.won=g().won;r.destroyer=B().destroyer;
  // a fresh run: Main Command falling ends it
  P.toMenu();P.pick.mode='blackout';P.showPage('solo');document.getElementById('startBtn').click();await new Promise(z=>setTimeout(z,300));
  g().paused=true;g().timer=.05;step(.5);P.core.hp=0;g().paused=false;P.update(1/20);g().paused=true;r.lossPhase=g().phase;r.lossWon=g().won;
  return r});
 fs.writeFileSync(__dirname+'/out/blackout_run.json',JSON.stringify(out,null,1));console.log(JSON.stringify(out));
 assert.equal(out.map,'city');assert.equal(out.N,64);assert.equal(out.gather,45);assert.equal(out.phase0,'build');assert.equal(out.pois,8);
 assert.deepEqual(out.order,[false,false,false,false,true,true,true,true],'minors then majors');
 assert.equal(out.warnedAt,0);assert.ok(out.nextFlag,'first target flagged');
 assert.equal(out.stage1,'attack');assert.equal(out.phase1,'raid');assert.ok(out.firstIsOrder0);assert.ok(out.bossPoi);
 assert.ok(out.troops>=3,'troops '+out.troops);assert.ok(out.troopsTagged);assert.ok(out.closer>=Math.ceil(out.troops/2),'troops walk to the POI: '+out.closer+'/'+out.troops);assert.ok(out.flowFinite);
 assert.equal(out.held,1);assert.equal(out.after1,'gap');assert.equal(out.leftOver,0);assert.equal(out.log1,'held');assert.ok(out.shopGap,'armory open in the quiet');
 assert.equal(out.stillGap,'gap');assert.equal(out.stage2,'attack');assert.equal(out.log2[1],'retreat');assert.ok(out.dmg2);assert.ok(out.repaired);
 assert.ok(out.cur3);assert.equal(out.lost,1);assert.ok(out.dark);assert.ok(out.pwLost);assert.ok(out.lightL>.72,'darker city '+out.lightL);
 assert.ok(out.healed-out.healLost>=2.9,'the 3 HP/s is the Hospital: '+out.healed+' vs '+out.healLost);assert.deepEqual(out.gas,[1.5625,1.25],'Black Out bounties ×1.25, ×1.25 again near the Gas Station');assert.deepEqual(out.high,[true,false]);
 assert.equal(out.purse,40,'starting purse');assert.equal(out.pay2,30,'attack 2 held (pulled back): 20 + 5×2');assert.equal(out.pay3,18,'attack 3 lost: half of 35, rounded up');
 assert.deepEqual(out.shopAtPoi,[true,false],'armory at a held POI in the quiet, core repair only at Main Command');assert.equal(out.shopInAttack,false,'no armory during an attack');
 assert.equal(out.readyStage,'ready','READY UP before the push');assert.ok(out.readyT>=88&&out.readyT<=90,'90 s ready stage '+out.readyT);assert.equal(out.stillReady,'ready','nobody forces it: still waiting at 1:28');
 assert.equal(out.push,'push');assert.equal(out.xs,1,'one lost major: one extra squad');assert.equal(out.hpMul,1.05,'one lost minor: +5%');
 assert.ok(out.maxBoss<=4,'boss cap '+out.maxBoss);assert.ok(out.pushBosses>=5,'push bosses '+out.pushBosses);
 assert.ok(out.dest&&out.destUp,'the Destroyer arrives at 3:00');assert.deepEqual(out.squads,['gren','shield'],'his squads: '+out.squads);
 assert.equal(out.overBefore,'raid');assert.equal(out.overAfter,'over');assert.ok(out.won);assert.ok(out.destroyer);
 assert.equal(out.lossPhase,'over');assert.equal(out.lossWon,false);
 assert.deepEqual(errors,[]);console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
