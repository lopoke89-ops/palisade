const {chromium}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
function workload(winter){const P=__pal;P.demo=false;P.pick.mode='blitz';P.pick.map=winter?'frost':'yard';P.pick.size='std';P.cfg.touchLock='off';
 P.newGame(['soldier','sniper','grenadier','quartermaster','sniper','grenadier'].map((cls,i)=>({id:i?'bot'+i:'solo',name:'Bot'+i,cls,cos:winter?['aurorasovereign|aurorahalo|auroralance|solsticenova','rimewarden|rimecrest|solsticecomet|borealiscollapse','snowline|snowgoggles|snowstreak|winterbloom'][i%3]:'',sk:P.skillStr({ammo_fire:4,ammo_shock:4,ammo_blast:4})})),'');
 for(const p of P.players.values()){p.hp=p.max=1e9;p.x=6+(p.slot%3);p.y=winter?7.5:11.5;p.ammoEq=p.cls==='sniper'?['blast','shock']:[p.slot%2?'fire':'blast','']}
 P.core.hp=P.core.max=P.qm.hp=P.qm.max=1e9;P.game.wave=15;P.game.phase='raid';P.startFinalBlitz();P.game.fb.next=1e9;P.game.queue=[];P.NET.mode='host';P.NET.inGame=true;
 for(let i=0;i<48;i++){const e=P.spawnEnemyAt(i%5?'rifle':'shield',2.5+(i%8)*1.25,winter?11.5+Math.floor(i/8)*.55:2.5+Math.floor(i/8)*1.1);e.hp=e.max=1e6;e.cd=999;e.speed=0}
 for(const key of winter?['rime','rime','tempest','bulldozer']:['bluebutcher','arsonist','tempest','bulldozer'])P.spawnBoss(key);
 for(const e of P.enemies)if(e.type==='boss'){e.hp=e.max=1e6;e.x=3.5+P.enemies.indexOf(e)%8;e.y=winter?12.5:7.5}
 const up=[],rn=[],sizes=[];let peakParts=0,peakEvents=0,peakBullets=0,peakFields=0,maxFrame=0;
 for(let f=0;f<1200;f++){
  for(const p of P.players.values()){const e=P.enemies[(p.slot+Math.floor(f/60))%48],dx=e.x-p.x,dy=e.y-p.y,l=Math.hypot(dx,dy)||1;p.aim={x:dx/l,y:dy/l};if(f%12===0)P.shoot(p,p.gun,0)}
  if(winter&&f%30===0){for(let j=0;j<8;j++)for(let i=0;i<8;i++)P.addFrost(2.5+i,6.5+j);P.killFx('solo',8.5,8.5)}
  const t=performance.now();P.update(1/60);const cost=performance.now()-t;if(f>=180)up.push(cost);
  if(f%30===0)for(let i=0;i<P.enemies.length;i++)P.ammoHit(P.enemies[i],{own:'bot'+i%6,shot:50000+f*100+i,ammo:[['fire',4],['shock',4]]});
  peakParts=Math.max(peakParts,P.parts.length);peakEvents=Math.max(peakEvents,P.NET.fxq.length);peakBullets=Math.max(peakBullets,P.bullets.length);peakFields=Math.max(peakFields,winter?P.frostFields.length:0);P.NET.fxq=[];
  if(f%5===0){const t=performance.now();P.render(1/60);P.ctx.getImageData(0,0,1,1);const cost=performance.now()-t;if(f>=180){rn.push(cost);maxFrame=Math.max(maxFrame,cost)}}
  if(f%15===0)sizes.push(new TextEncoder().encode(JSON.stringify(P.makeSnap(false))).length);
 }
 const q=(a,p)=>+a.slice().sort((a,b)=>a-b)[Math.floor(a.length*p)].toFixed(3),bytes=q(sizes,.9),out={players:P.players.size,enemies:P.enemies.length,bosses:P.enemies.filter(e=>e.type==='boss').length,peakParts,peakEvents,peakBullets,peakFields,updateMedianMs:q(up,.5),updateP90Ms:q(up,.9),renderMedianMs:q(rn,.5),renderP90Ms:q(rn,.9),renderP99Ms:q(rn,.99),maxRenderMs:+maxFrame.toFixed(2),snapshotP90Bytes:bytes,hostStateBytesPerSecond:bytes*15*5,wardrobe:P.wardrobeStats,background:P.backgroundStats,fx:P.cosmeticCache};P.NET.mode='solo';return out;
}
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined,args:['--disable-gpu','--disable-accelerated-2d-canvas']}),ctx=await b.newContext({viewport:{width:390,height:844}}),errors=[];await ctx.route('**/winter-baseline.html?*',r=>r.fulfill({contentType:'text/html',body:fs.readFileSync(__dirname+'/out/winter-baseline-debug.html','utf8')}));
 const p=await ctx.newPage();p.on('pageerror',e=>errors.push(e.message));await p.goto('http://localhost:8080/winter-baseline.html?debug=1');await p.waitForFunction(()=>__pal?.NET);const baseline=await p.evaluate(workload,false);await p.goto('http://localhost:8080/debug.html?debug=1');await p.waitForFunction(()=>__pal?.NET);const candidate=await p.evaluate(workload,false),winter=await p.evaluate(workload,true);
 const total=r=>r.updateMedianMs+r.renderMedianMs,comparison={sameWorkloadPercent:+((total(candidate)/total(baseline)-1)*100).toFixed(1),winterPercent:+((total(winter)/total(baseline)-1)*100).toFixed(1)},result={device:'Windows desktop Chrome, software Canvas, 390x844 viewport; no physical phone',baseline,candidate,winter,comparison};fs.writeFileSync(__dirname+'/out/winter_performance.json',JSON.stringify(result,null,2));assert.equal(winter.players,6);assert.equal(winter.bosses,4);assert.ok(winter.peakFields<=64);assert.ok(winter.wardrobe.bytes<=24*1024*1024);assert.deepEqual(errors,[]);console.log(result);console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
