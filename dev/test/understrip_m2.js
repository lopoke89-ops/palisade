// THE UNDERSTRIP M2: the second weapon (keys 1/2, the controller's d-pad, the touch button), its magazine and reserve (reloads
// take from the reserve; empty, it stops; shrines refill it), loot on the floor shown before it's taken (E), chests, elites
// (x2.5 health, their trick's warning, loot, staying down past a rest), the boss's drops, perks and relics doing what they say,
// and every class killing raiders with every one of the nine weapons.
const {chromium}=require('playwright'),assert=require('node:assert/strict');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),errors=[];
 const p=await b.newPage({viewport:{width:1280,height:800}});p.on('pageerror',e=>errors.push(e.message));
 await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`);await p.waitForFunction(()=>window.__pal);
 const start=()=>p.evaluate(async()=>{const P=__pal;let s=11;Math.random=()=>(s=(s*16807)%2147483647)/2147483647;P.pick.mode='understrip';P.showPage('solo');document.getElementById('startBtn').click();await new Promise(z=>setTimeout(z,400));P.game.paused=true});
 await start();
 const r=await p.evaluate(async()=>{const P=__pal,r={},g=()=>P.game,U=()=>P.game.us,pl=P.player,L=()=>P.game.lay;
  const step=(sec,each)=>{for(let t=0;t<sec;t+=1/30){if(each)each();g().paused=false;P.update(1/30);g().paused=true;if(g().phase==='over')break}};
  const clear=()=>{for(const e of P.enemies)e.dead=true;step(.05)};clear();pl.max=pl.hp=1e6;
  // 1. a weapon from the floor: shown before it's taken, E takes it, 2 and 1 swap
  const w={id:'w_nailgun',r:'e',mods:['m_dmg','m_mag']};P.usDropLoot(pl.x,pl.y,{kind:'weapon',w});r.label=P.usLootLabel(U().loot[0]);
  r.before=!!pl.w2;P.usInteract(pl,true);r.took=!!pl.w2&&pl.w2.id==='w_nailgun'&&pl.wSel===1&&U().loot.length===0;
  r.gun={name:pl.gun.us,mag:pl.gun.mag,ammo:pl.ammo};g().paused=false;window.dispatchEvent(new KeyboardEvent('keydown',{key:'1'}));r.after1=pl.wSel;window.dispatchEvent(new KeyboardEvent('keydown',{key:'2'}));r.after2=pl.wSel;document.getElementById('usWpn').dispatchEvent(new PointerEvent('pointerdown',{bubbles:true}));r.afterTap=pl.wSel;document.getElementById('usWpn').dispatchEvent(new PointerEvent('pointerdown',{bubbles:true}));g().paused=true;
  // 2. the magazine and the reserve
  const res0=pl.w2.res;pl.ammo=0;pl.rlReq=true;step(2.6);r.reload={ammo:pl.ammo,res:pl.w2.res,took:res0-pl.w2.res};
  pl.w2.res=0;pl.ammo=0;pl.rlReq=true;step(3);r.empty=pl.ammo;
  const S=L().shrines.find(q=>!q.arena);pl.x=S.x;pl.y=S.y+.6;pl.tp++;clear();P.usInteract(pl,true);r.shrineRefill=pl.w2.res===P.usReserveMax(pl.w2,pl);
  // 3. perks: Steady Hands tightens the spread; Big Gulp heals more; Insurance halves the drop; Back Step shortens the roll's wait
  const sp0=pl.gun.spread;pl.uPerks=['p_steady','p_gulp','p_insure','p_backstep'];P.usRefit(pl);r.steady=+(pl.gun.spread/sp0).toFixed(2);
  P.usRefit(pl);pl.hp=40;pl.uj=3;r.gulpExp=Math.round(pl.max*.45*1.25);P.usDrink(pl);step(1);r.gulp=Math.round(pl.hp-40);
  pl.sal=50;P.usDrop(pl);r.insure=[pl.sal,U().drops.find(d=>d.id===pl.id).sal];
  P.startRoll(pl,1,0);r.rollCd=+pl.dgCd.toFixed(2);pl.dgE=-1;pl.dgCd=0;step(.1);   // (the local roll moves in the input step, which the test doesn't run)
  // relics: the Paper Crown's fire rate and lower health
  P.usRefit(pl);const cd0=pl.gun.cd,mx0=pl.max;pl.uRelic='x_crown';P.usRefit(pl);r.crown=[+(cd0/pl.gun.cd).toFixed(2),+(pl.max/mx0).toFixed(2)];pl.uRelic='';pl.uPerks=[];P.usRefit(pl);pl.max=pl.hp=1e6;
  // 4. a chest: loot on the floor, not straight into your pack
  const c=L().chests[0];if(c){clear();pl.x=c.x;pl.y=c.y;pl.tp++;step(.1);r.chestLoot=U().loot.length===1&&U().loot[0].kind}
  U().loot.length=0;
  // 5. an elite: x2.5 health, a name tag, loot when it drops, gone for good past a rest
  const el=P.enemies.find(e=>e.elite)||(()=>{const e=P.spawnEnemyAt('shield',pl.x+3,pl.y);e.us={home:[e.x,e.y],st:'idle',sid:999,t:0,look:0};P.usMakeElite(e,()=>.5);return e})();
  r.elite={kind:el.elite,hp:+(el.max/(P.ETYPES[el.type].hp*P.game.Df.hp*P.mapHp())).toFixed(2)};const sid=el.us.sid;P.hurtEnemy(el,1e9,pl.id);step(.1);r.eliteLoot=U().loot.length>=1;
  P.usInteract(pl,true);clear();r.eliteGone=!U().eliteDown.includes(sid)?'not recorded':!P.enemies.some(e=>e.us&&e.us.sid===sid);
  // 5b. the tricks: the alien pistol charges and fires on release; the lab laser bounces off a wall; RIVETS triples every 5th nail
  P.changeClass(pl,'soldier');pl.max=pl.hp=1e6;clear();const frame1=f=>{for(let q=0;q<8;q++){pl.fireIn=f;g().paused=false;P.update(1/240);g().paused=true}};
  const dirs=[[1,0],[-1,0],[0,1],[0,-1]],tileAt=(ax,ay,d)=>P.terr[((pl.y+ay*d)|0)*P.N+((pl.x+ax*d)|0)],openDir=dirs.find(([ax,ay])=>[1,2,3,4].every(d=>tileAt(ax,ay,d)!==P.T_CONC&&tileAt(ax,ay,d)!==P.T_JUNK))||[1,0];
  const seenB=f=>{let m=null;for(const b of P.bullets)if(b.own===pl.id)m=f(m,b);return m};
  P.usGiveWeapon(pl,{id:'w_alien',r:'c',mods:[]});pl.aim={x:openDir[0],y:openDir[1]};pl.cd=0;let mx=0;
  for(let t=0;t<1.3;t+=1/30){frame1(true);mx=Math.max(mx,seenB((m,b)=>Math.max(m||0,b.dmg))||0)}r.heldNoShot=mx===0;
  for(let t=0;t<.3;t+=1/30){frame1(false);mx=Math.max(mx,seenB((m,b)=>Math.max(m||0,b.dmg))||0)}r.charged=Math.round(mx);
  clear();P.usGiveWeapon(pl,{id:'w_laser',r:'c',mods:[]});let wall=null;for(const[ax,ay]of[[1,0],[-1,0],[0,1],[0,-1]]){for(let d=1;d<=4;d++){const t=P.terr[((pl.y+ay*d)|0)*P.N+((pl.x+ax*d)|0)];if(t===P.T_CONC){wall=[ax,ay];break}}if(wall)break}
  pl.aim={x:wall[0],y:wall[1]};pl.cd=0;let bounced=false;for(let t=0;t<.4;t+=1/30){frame1(t<.05);if(P.bullets.some(b=>b.own===pl.id&&b.bnc>=1))bounced=true}r.bounced=bounced;
  clear();P.usGiveWeapon(pl,{id:'w_nailgun',r:'l',mods:['m_dmg','m_mag']});pl.aim={x:wall[0],y:wall[1]};pl.cd=0;const dm=new Set();for(let t=0;t<.8;t+=1/30){frame1(true);for(const b of P.bullets)if(b.own===pl.id)dm.add(Math.round(b.dmg))}
  pl.fireIn=false;r.rivets=[...dm].sort((x,y)=>x-y);
  // 6. every class kills with every weapon (a raider a few tiles in front, the trigger held)
  r.kills={};for(const cls of['soldier','sniper','grenadier','quartermaster'])for(const id of Object.keys(P.US_WEAPONS)){
    P.changeClass(pl,cls);pl.max=pl.hp=1e6;P.usGiveWeapon(pl,{id,r:'c',mods:[]});clear();
    let tx=pl.x,ty=pl.y,ok=false;for(const[ax,ay]of[[1,0],[-1,0],[0,1],[0,-1]]){let free=true;for(let d=1;d<=3;d++){const t=P.terr[((pl.y+ay*d)|0)*P.N+((pl.x+ax*d)|0)];if(t===P.T_CONC||t===P.T_SHUT||t===P.T_JUNK)free=false}if(free){tx=pl.x+ax*2.5;ty=pl.y+ay*2.5;pl.aim={x:ax,y:ay};ok=true;break}}
    const e=P.spawnEnemyAt('rifle',tx,ty);e.speed=0;e.us={home:[tx,ty],st:'idle',sid:-2,t:0,look:0};
    let t=0;step(12,()=>{pl.aim={x:(e.x-pl.x),y:(e.y-pl.y)};const l=Math.hypot(pl.aim.x,pl.aim.y)||1;pl.aim.x/=l;pl.aim.y/=l;pl.fireIn=(t%1.4)<1.25;pl.autoFire=true;   // (let go now and then: the alien pistol fires on release)
      if(pl.w2.res<5)pl.w2.res=50;t+=1/30;if(e.dead)g().paused=true});
    r.kills[cls+':'+id]=e.dead?+t.toFixed(1):-1;pl.fireIn=false}
  // 7. the boss's drops: one for each of you, and his tie-pin
  P.usChangeLevel(2);clear();const A=L().arena;pl.x=A.x+A.w/2;pl.y=A.y+A.h-3;pl.tp++;step(4.5);const B=P.enemies.find(e=>e.type==='boss');B.inv=0;P.hurtEnemy(B,1e9,pl.id);step(.3);
  r.bossLoot=U().loot.map(l=>l.kind+':'+(l.k||'')).sort();pl.x=U().loot[0].x;pl.y=U().loot[0].y;P.render(1/30);P.hud(1/30);   // drawn: every label resolves
  return r});
 console.log(JSON.stringify(r,null,1));
 assert.ok(r.label.name==='NAIL GUN'&&/EPIC/.test(r.label.line)&&/HOT/.test(r.label.line),'the label: name, rarity, mods');
 assert.equal(r.before,false);assert.ok(r.took);assert.equal(r.gun.name,'w_nailgun');assert.equal(r.gun.mag,42);assert.equal(r.after1,0);assert.equal(r.after2,1);assert.equal(r.afterTap,0,'the touch button swaps');
 assert.ok(r.reload.ammo>0&&r.reload.took===r.reload.ammo,'reload takes from the reserve');assert.equal(r.empty,0,'no reserve, no reload');assert.ok(r.shrineRefill);
 assert.equal(r.steady,.75);assert.equal(r.gulp,r.gulpExp,'Big Gulp: 45% x 1.25');assert.deepEqual(r.insure,[25,25]);assert.equal(r.rollCd,1.5,'2 s here, 0.5 s less with Back Step');
 assert.deepEqual(r.crown,[1.25,.75]);
 assert.ok(r.chestLoot===undefined||typeof r.chestLoot==='string');
 assert.equal(r.elite.hp,2.5);assert.ok(r.eliteLoot);assert.equal(r.eliteGone,true);
 assert.ok(r.heldNoShot,'the alien pistol waits while held');assert.ok(r.charged>=60,'a full charge: '+r.charged);assert.ok(r.bounced,'the laser bounces');
 assert.ok(r.rivets.length>=2&&Math.abs(r.rivets[r.rivets.length-1]/r.rivets[0]-3)<.1,'RIVETS: '+r.rivets);
 for(const[k,v]of Object.entries(r.kills))assert.ok(v>0,'no kill: '+k);
 assert.ok(r.bossLoot.includes('perk:p_tiepin')&&r.bossLoot.length===2,'one drop each (solo) and the tie-pin');
 console.log('errors:',errors.length?errors:'none');await b.close();if(errors.length)process.exit(1);
})().catch(e=>{console.error(e);process.exit(1)});
