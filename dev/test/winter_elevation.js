const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),page=await browser.newPage({viewport:{width:1100,height:760}}),errors=[];
 page.on('pageerror',e=>errors.push(e.message));await page.goto('http://localhost:8080/debug.html?debug=1');await page.waitForFunction(()=>window.__pal);
 const result=await page.evaluate(()=>{
  const P=__pal,out={};P.demo=false;P.pick.mode='5';P.pick.map='frost';P.pick.size='std';P.newGame();P.game.paused=true;
  out.coreZ=P.heightAt(P.core.i+.5,P.core.j+.5);out.tiers=[...new Set(P.heights)];out.connectors=P.connectors.filter(Boolean).length;
  const walker={x:4.5,y:12.5};for(let n=0;n<110;n++)P.moveEnt(walker,0,-.09,true);out.ramp={...walker};
  const cliff={x:8.5,y:6.5};for(let n=0;n<30;n++)P.moveEnt(cliff,0,-.1,true);out.cliff={...cliff};
  out.sideBlocked=!P.travelClear(3.5,5.5,2.5,5.5,true);out.rampBuild=P.buildEval(P.player,4,5,0,false).reason;
  out.projection=[];for(const [x,y]of[[4.5,5.25],[7.5,2.5],[4.5,10.8],[8.5,13.5]]){const s=P.iso(x,y),w=P.screenToWorld(...s);out.projection.push(Math.hypot(w.x-x,w.y-y))}
  P.addFrost(4.5,8.5);out.slow=P.slowAtHook(4.5,8.5);out.field=P.makeSnap(true).ice;
  P.render(1/60);out.mapKept=P.game.map;P.renderMapPanel();out.heightAfterPreview=P.heightAt(7.5,2.5);
  for(const size of ['std','xl']){P.pick.size=size;P.newGame();const e=P.spawnEnemyAt('shield',4.5,P.N-2.5);P.core.hp=P.core.max=P.player.hp=P.player.max=P.qm.hp=P.qm.max=1e8;P.game.phase='raid';P.game.queue=['rifle'];P.game.spawnT=1e8;P.player.x=7.5;P.player.y=2.5;
   let maxZ=0;for(let n=0;n<900;n++){P.updateEnemies(1/30);maxZ=Math.max(maxZ,P.heightAt(e.x,e.y))}out['enemy_'+size]={maxZ,x:e.x,y:e.y};
  }
  P.pick.mode='campaign';P.pick.map='frost';P.pick.size='std';P.newGame();out.startMap=P.game.map;out.bosses=[3,6,9,12,13].map(w=>P.bossOf(w));P.player.up.d=4;P.player.upS='40000';P.player.ammoEq=['fire',''];P.player.sal=190;P.game.dellLv=3;P.core.hp=123;
  P.game.wave=3;P.game.phase='raid';P.campaignAdvance();P.skipMapEvac();out.carry={map:P.game.map,chapter:P.game.chapter,up:P.player.up.d,ammo:P.player.ammoEq[0],sal:P.player.sal,core:P.core.hp,dell:P.game.dellLv,gid:P.game.gid};
  P.game.wave=6;P.campaignAdvance();P.skipMapEvac();P.game.wave=9;P.campaignAdvance();P.skipMapEvac();P.game.wave=12;P.game.phase='build';P.startRaid();out.finale={wave:P.game.wave,time:P.game.fb.t};
  P.game.fb.t=59;P.openEvac();out.evac=P.game.fb.evac;out.credits=P.chapterCredit(2,13);return out;
 });
 fs.writeFileSync(__dirname+'/out/winter_elevation.json',JSON.stringify(result,null,2)); assert.equal(result.coreZ,2);assert.deepEqual(result.tiers.sort(),[0,1,2]);assert.ok(result.connectors>=12);assert.ok(result.ramp.y<4.4);assert.equal(result.ramp.z,2);assert.ok(result.cliff.y>5.1);assert.ok(result.sideBlocked);assert.match(result.rampBuild,/connector/);result.projection.forEach(d=>assert.ok(d<.025,'surface picking error '+d));assert.equal(result.slow,.7);assert.equal(result.field.length,1);assert.equal(result.heightAfterPreview,2);
 assert.ok(result.enemy_std.maxZ>=1,'enemy reaches middle terrace');assert.ok(result.enemy_xl.maxZ>=1);assert.equal(result.startMap,'yard');assert.deepEqual(result.bosses,['whitebutcher','whiteferryman','whiteforeman','rime','']);assert.equal(result.carry.map,'river');assert.equal(result.carry.up,4);assert.equal(result.carry.ammo,'fire');assert.equal(result.carry.core,123);assert.equal(result.carry.dell,3);assert.equal(result.finale.wave,13);assert.equal(result.finale.time,210);   // v0.9.6.4: the Whiteout Gauntlet runs 3:30assert.deepEqual(result.credits,{yard:1,river:3,quarry:3,frost:4});assert.deepEqual(errors,[]);
 fs.writeFileSync(__dirname+'/out/winter_elevation.json',JSON.stringify(result,null,2));await page.screenshot({path:__dirname+'/out/winter_elevation.png'});console.log(JSON.stringify(result));console.log('errors: none');await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
