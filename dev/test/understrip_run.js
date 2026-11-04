// THE UNDERSTRIP (M1), solo, start to finish: a level from the seed (no stake, no build, no Delgado), raiders waiting in the
// dark until they hear or see you, no healing but Lucky Juice, a fall costs a shared life and leaves your salvage where you
// fell, Neon Shrines (rest, refill, the raiders come back, raiders too close and you can't), the shortcut door opening from
// one side only, chests, the Tunnel Trader (grenades, juice, a barricade you place), the lift's ring to the next level, the
// Pit Boss behind a sealing gate with both stages (no damage while he changes, the flood, the second bar), and the run's end
// both ways.
const {chromium}=require('playwright'),assert=require('node:assert/strict');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),errors=[];
 const p=await b.newPage({viewport:{width:1280,height:800}});p.on('pageerror',e=>errors.push(e.message));
 await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`);await p.waitForFunction(()=>window.__pal);
 const r=await p.evaluate(async()=>{const P=__pal,r={};
  let s=7;Math.random=()=>(s=(s*16807)%2147483647)/2147483647;
  P.pick.mode='understrip';P.showPage('solo');document.getElementById('startBtn').click();await new Promise(z=>setTimeout(z,500));
  const g=()=>P.game,U=()=>P.game.us,pl=P.player,L=()=>P.game.lay;
  const step=(sec,each)=>{for(let t=0;t<sec;t+=1/30){if(each)each();g().paused=false;P.update(1/30);g().paused=true;if(g().phase==='over')break}};
  const tp=(x,y)=>{pl.x=x;pl.y=y;pl.tp++};
  const quiet=()=>{for(const e of P.enemies)if(e.us){e.us.st='idle';e.x=e.us.home[0];e.y=e.us.home[1];e.hp=e.max}};
  g().paused=true;
  // 1. the level
  r.start={mode:g().mode,phase:g().phase,N:P.N,cores:P.game.lay.under&&P.qm.gone,lives:U().lives,juice:[pl.uj,pl.ujm],raiders:P.enemies.length,waiting:P.enemies.every(e=>e.us&&(e.us.st==='idle'||e.us.st==='ambush')),
    hash:P.usTileHash(P.usLevel()),atStart:L().starts.some(([x,y])=>Math.abs(x-pl.x)<.01&&Math.abs(y-pl.y)<.01),walls:P.terr.filter(t=>t===P.T_CONC).length>P.N*P.N*.4};
  // keep the raiders out of the way while the rules are checked
  const far=()=>{for(const e of P.enemies)if(e.us&&Math.hypot(e.x-pl.x,e.y-pl.y)<12){e.x=e.us.home[0];e.y=e.us.home[1]}};
  for(const e of P.enemies)if(e.us&&Math.hypot(e.us.home[0]-pl.x,e.us.home[1]-pl.y)<12)e.dead=true;step(.1);
  // 2. no healing out of a fight
  pl.hp=50;step(10,quiet);r.noRegen=Math.round(pl.hp);
  // 3. Lucky Juice: 0.8 s, 45% of max, slows you while you drink
  r.drinkFull=(pl.hp=pl.max,P.usDrink(pl));pl.hp=40;r.drank=P.usDrink(pl);r.juiceLeft=pl.uj;step(.4);r.midDrink=Math.round(pl.hp);step(.5);r.afterDrink=Math.round(pl.hp);r.expected=Math.round(40+pl.max*.45);
  // 4. waiting raiders: one put beside you starts hunting; one far off doesn't
  const e1=P.enemies.find(e=>e.us&&e.us.st==='idle'&&e.type!=='medic'),e2=P.enemies.filter(e=>e.us&&e.us.st==='idle'&&e!==e1).sort((a,b)=>Math.hypot(b.x-pl.x,b.y-pl.y)-Math.hypot(a.x-pl.x,a.y-pl.y))[0];
  e1.x=pl.x+1.2;e1.y=pl.y;step(.3);r.heard=e1.us.st;r.farStill=e2.us.st;
  // a hunter walks its flow field toward you
  // a hunter out of sight walks its flow field toward you (one that can see you stands and shoots)
  const e3=P.enemies.filter(e=>e.us&&e.us.st!=='hunt'&&e.type==='rifle'&&!P.losClear(e.x,e.y,pl.x,pl.y)).sort((a,b)=>Math.hypot(a.x-pl.x,a.y-pl.y)-Math.hypot(b.x-pl.x,b.y-pl.y))[0];
  // (measured along its path: the way round can be long, so the straight line hardly changes)
  const fv=()=>{const F=P.US_FLOW.get(pl.id);return F?F.f[(e3.y|0)*P.N+(e3.x|0)]:1e9};e3.us.st='hunt';pl.max=pl.hp=1e5;step(.5);const d0=fv();step(4);r.huntCloser=fv()<d0-4||e3.foe===pl;pl.max=pl.hp=pl.C.hp||110;
  for(const e of P.enemies)if(e.us&&e.us.st==='hunt')e.dead=true;step(.1);
  // 5. a fall: salvage stays where you fell, a life goes, back at the lift with juice refilled
  // (somewhere other than where you come back, or you'd pick it straight up)
  {const c=L().merchants[0];tp(c.x,c.y+1)}
  const fx=pl.x,fy=pl.y;pl.sal=37;pl.uj=0;P.hurtPlayer(pl,1e4);r.down=[pl.alive,pl.downed];step(3);
  r.wipe={lives:U().lives,alive:pl.alive,hp:pl.hp===pl.max,juice:pl.uj,sal:pl.sal,drop:U().drops.map(d=>[d.sal,Math.abs(d.x-fx)<.01&&Math.abs(d.y-fy)<.01])};
  tp(fx,fy);step(.2);r.recovered=pl.sal;r.dropsLeft=U().drops.length;
  // 6. the shrine: raiders near stop you resting; resting refills, sets the comeback point, brings the raiders back
  const S=L().shrines.find(q=>!q.arena),si=L().shrines.indexOf(S);for(const e of P.enemies)if(e.us&&Math.hypot(e.x-S.x,e.y-S.y)<12)e.dead=true;step(.1);tp(S.x,S.y+.6);
  const near=P.spawnEnemyAt('rifle',S.x+2,S.y);near.us={home:[S.x+2,S.y],st:'hunt',t:0,look:0};pl.uj=1;P.usInteract(pl,true);r.restBlocked=pl.uj===1;near.dead=true;step(.1);
  const before=P.enemies.length;P.usInteract(pl,true);r.rest={juice:pl.uj,ix:U().rest.ix===si,lit:!!(U().lit&(1<<si)),raidersBack:P.enemies.length>before&&P.enemies.length===L().raiders.length};
  for(const e of P.enemies)if(e.us)e.dead=true;step(.1);
  // 7. the shortcut: shut, won't open from the wrong side, opens from its side
  const D=L().doors[0],t0=D.tiles[0],k0=t0[1]*P.N+t0[0],sd={N:[0,-1],S:[0,1],E:[1,0],W:[-1,0]}[D.side];r.doorShut=P.terr[k0]===P.T_SHUT;
  const cx=D.tiles.reduce((a,t)=>a+t[0]+.5,0)/D.tiles.length,cy=D.tiles.reduce((a,t)=>a+t[1]+.5,0)/D.tiles.length;
  tp(cx-sd[0]*1.1,cy-sd[1]*1.1);P.usInteract(pl,true);r.wrongSide=P.terr[k0]===P.T_SHUT;
  tp(cx+sd[0]*1.1,cy+sd[1]*1.1);P.usInteract(pl,true);r.rightSide=P.terr[k0]!==P.T_SHUT&&!!(U().opened&1);
  // 8. a chest
  if(L().chests.length){const c=L().chests[0],s0=pl.sal;tp(c.x,c.y);step(.1);r.chest=pl.sal-s0}else r.chest='none';
  // 9. the Tunnel Trader
  const m=L().merchants[0];tp(m.x,m.y+1);r.shop=P.canShop(pl);pl.sal=200;pl.nades=0;
  const st=m.stock,ni=st.findIndex(q=>q.k==='c_nade'),left0=U().left[0][ni];r.buyNade=P.usBuy(pl,0,ni)&&pl.nades===1&&pl.sal===185&&U().left[0][ni]===left0-1;
  pl.uj=0;const ji=st.findIndex(q=>q.k==='c_juice');r.buyJuice=P.usBuy(pl,0,ji)&&pl.uj===1;r.juiceSoldOut=!P.usBuy(pl,0,ji);
  tp(L().starts[0][0],L().starts[0][1]);r.notAtTrader=!P.canShop(pl);
  pl.ui.bar=1;pl.aim={x:1,y:0};pl.face={x:1,y:0};const before2=P.walls.filter(Boolean).length;let placed=false;
  for(const [ax,ay]of[[1,0],[-1,0],[0,1],[0,-1]]){pl.aim={x:ax,y:ay};pl.face=pl.aim;const ti=Math.floor(pl.x+ax*1),tj=Math.floor(pl.y+ay*1);if(P.usUseItem(pl,'bar',ti,tj)){placed=true;break}}
  r.barricade=placed&&P.walls.filter(Boolean).length===before2+1&&pl.ui.bar===0;
  // 10. the lift: everyone in the ring for 3 s, the next level
  const lv0=U().level,h0=r.start.hash;tp(L().exit[0],L().exit[1]);step(3.3);r.lift=U().lift>0;step(5.3);
  r.level2={level:U().level,newMap:P.usTileHash(P.usLevel())!==h0,atStart:L().starts.some(([x,y])=>Math.abs(x-pl.x)<.01&&Math.abs(y-pl.y)<.01),raiders:P.enemies.length>0,lives:U().lives};
  for(const e of P.enemies)if(e.us)e.dead=true;step(.1);tp(L().exit[0],L().exit[1]);step(8.8);
  // 11. the Pit Boss
  r.boss={level:U().level,kind:!!L().arena,gate:U().gate};const A=L().arena;
  tp(A.x+A.w/2,A.y+A.h-3);step(.2);r.boss.closing=U().gate===1;step(4.2);r.boss.sealed=U().gate===2&&L().gate.every(([x,y])=>P.terr[y*P.N+x]===P.T_SHUT);
  const B=P.enemies.find(e=>e.type==='boss');r.boss.spawned=!!B&&B.boss==='pitboss';r.boss.hp=B&&Math.round(B.max);r.boss.exitShut=(()=>{tp(L().exit[0],L().exit[1]);step(3.5,()=>{pl.hp=pl.max});return U().lift===0&&g().phase!=='over'})();
  tp(A.x+A.w/2,A.y+A.h-3);
  const seen=new Set();pl.max=pl.hp=1e6;step(12,()=>{pl.hp=pl.max;if(B.st)seen.add(B.st)});r.boss.stage1Moves=[...seen].sort();
  P.hurtEnemy(B,B.hp-B.max*.49,pl.id);step(.1);r.boss.stage2=U().bossStage===1&&B.st===60;r.boss.flooded=!!U().floodOn;const hp2=B.hp;P.hurtEnemy(B,500,pl.id);r.boss.invulnerable=B.hp===hp2;
  r.boss.bar=+P.usBossFrac(B).toFixed(2);seen.clear();let kite=0;step(16,()=>{pl.hp=pl.max;if(B.st)seen.add(B.st);if((kite+=1/30)>2.5&&!B.st){kite=0;const a=Math.random()*6.28;for(let d=6;d>2;d--){const x=B.x+Math.cos(a)*d,y=B.y+Math.sin(a)*d;const t=P.terr[(y|0)*P.N+(x|0)];if(t!==P.T_CONC&&t!==P.T_SHUT&&t!==P.T_JUNK){tp(x,y);break}}}});r.boss.stage2Moves=[...seen].sort();
  P.hurtEnemy(B,1e9,pl.id);step(.3);r.boss.downWhy=[!!U().bossDown,U().gate,!!U().floodOn,B.dead,B.inv,B.hp,P.enemies.filter(e=>e.type==='boss').length];r.boss.down=!!U().bossDown&&U().gate===0&&!U().floodOn;
  // 12. out: the run is won
  tp(L().exit[0],L().exit[1]);step(3.4);r.end={phase:g().phase,won:g().won,title:document.getElementById('overTitle').textContent};
  // 13. a run with no lives left ends on the next fall
  document.getElementById('menuBtn')&&0;P.newGame(null,'',{});await new Promise(z=>setTimeout(z,100));g().paused=true;U().lives=0;P.hurtPlayer(P.player,1e4);step(3);r.lost={phase:g().phase,won:g().won};
  return r});
 console.log(JSON.stringify(r,null,1));
 assert.equal(r.start.mode,'understrip');assert.equal(r.start.phase,'raid');assert.ok(r.start.N>=48&&r.start.N<=64);assert.ok(r.start.cores,'no Delgado, no stake');
 assert.equal(r.start.lives,3);assert.deepEqual(r.start.juice,[3,3]);assert.ok(r.start.raiders>8&&r.start.waiting,'raiders wait in the dark');assert.ok(r.start.atStart&&r.start.walls);
 assert.equal(r.noRegen,50,'no healing out of a fight');
 assert.equal(r.drinkFull,false,'no drinking at full health');assert.ok(r.drank);assert.equal(r.juiceLeft,2);assert.equal(r.midDrink,40,'the heal lands when the drink ends');assert.equal(r.afterDrink,r.expected);
 assert.equal(r.heard,'hunt');assert.notEqual(r.farStill,'hunt');assert.ok(r.huntCloser,'a hunter walks toward you');
 assert.deepEqual(r.down,[false,true]);assert.equal(r.wipe.lives,2);assert.ok(r.wipe.alive&&r.wipe.hp);assert.equal(r.wipe.juice,3);assert.equal(r.wipe.sal,0);assert.deepEqual(r.wipe.drop,[[37,true]]);
 assert.equal(r.recovered,37);assert.equal(r.dropsLeft,0);
 assert.ok(r.restBlocked,'no resting with raiders close');assert.deepEqual(r.rest,{juice:3,ix:true,lit:true,raidersBack:true});
 assert.ok(r.doorShut&&r.wrongSide&&r.rightSide,'the shortcut opens from its own side only');
 assert.ok(r.chest==='none'||r.chest>=15,'chests pay salvage');
 assert.ok(r.shop&&r.notAtTrader);assert.ok(r.buyNade);assert.ok(r.buyJuice&&r.juiceSoldOut);assert.ok(r.barricade);
 assert.ok(r.lift);assert.deepEqual(r.level2,{level:1,newMap:true,atStart:true,raiders:true,lives:2});
 assert.equal(r.boss.level,2);assert.ok(r.boss.kind);assert.equal(r.boss.gate,0);assert.ok(r.boss.closing&&r.boss.sealed&&r.boss.spawned);assert.equal(r.boss.hp,1200,'960 base, x1.25 (BOSS_HP), one player on Normal');assert.ok(r.boss.exitShut,'the lift is dead until he is');
 assert.ok(r.boss.stage1Moves.length>=1&&r.boss.stage1Moves.every(s=>[1].includes(s)),'stage 1: the swing (chips are lobs)');
 assert.ok(r.boss.stage2&&r.boss.flooded&&r.boss.invulnerable);assert.equal(r.boss.bar,1,'stage 2 starts its own full bar');
 assert.ok(r.boss.stage2Moves.some(s=>s===61)&&r.boss.stage2Moves.some(s=>s===2||s===3),'stage 2: the spray and the rush');assert.ok(r.boss.down);
 assert.equal(r.end.phase,'over');assert.equal(r.end.won,true);assert.match(r.end.title,/COUNT ROOM/);
 assert.equal(r.lost.phase,'over');assert.equal(r.lost.won,false);
 console.log('errors:',errors.length?errors:'none');await b.close();if(errors.length)process.exit(1);
})().catch(e=>{console.error(e);process.exit(1)});
