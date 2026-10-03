// v0.9.7 THE SUPREME DESTROYER: each of his five attacks shows its warning, hurts only inside its area, and draws; the
// Orbital Cannon only below 40%; mines arm, trip, and go off safely when shot; gas hurts over time; health and weakness.
const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),errors=[];
 const p=await b.newPage({viewport:{width:1280,height:800}});p.on('pageerror',e=>errors.push(e.message));
 await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`);await p.waitForFunction(()=>window.__pal);
 const out=await p.evaluate(async()=>{const P=__pal,r={moves:{},draw:[]};
  P.pick.mode='blackout';P.showPage('solo');document.getElementById('startBtn').click();await new Promise(z=>setTimeout(z,400));
  let s=5;Math.random=()=>(s=(s*16807)%2147483647)/2147483647;
  const g=P.game;g.paused=true;g.phase='raid';g.timer=0;const step=dt=>{g.paused=false;P.update(dt);g.paused=true};const pl=P.player;
  if(g.bo)g.bo.stage='done';   // the run's own clock stays out of it
  const C=P.core;const fresh=(dist)=>{P.enemies.length=0;P.fires.length=0;P.lobs.length=0;P.spawnBoss('destroyer',false);const e=P.enemies.find(o=>o.boss==='destroyer');
    pl.x=C.i+4.5;pl.y=C.j+4.5;pl.max=pl.hp=5000;pl.alive=true;pl.stun=0;P.qm.x=1;P.qm.y=1;P.qm.alive=false;P.qm.gone=true;
    e.x=pl.x;e.y=pl.y-dist;e.foe=pl;e.cd=0;e.st=0;e.orbT=99;return e};
  { const e=fresh(6),B=P.BOSSES.destroyer;r.hpRatio=+(e.max/(B.hp*g.Df.hp*P.mapHp())).toFixed(3);r.weak=P.BOSS_WEAK.destroyer;r.big=B.big;r.ecode=P.ECODE.includes('boss:destroyer')}
  // run one attack from its warning state; dodge moves the player out of the area mid-warning
  const run=(st,dist,opt={})=>{const e=fresh(dist);if(opt.setup)opt.setup(e);e.st=st;e.stT=e.stM=opt.T||1;e.lx=opt.self?e.x:pl.x;e.ly=opt.self?e.y:pl.y;
    const hp0=pl.hp,seen=new Set([st]);let t=0;if(opt.dodge){step(.2);pl.x+=opt.dodge}
    while(t<(opt.max||6)){step(1/30);t+=1/30;if(e.st)seen.add(e.st);if(!e.st&&!P.lobs.length&&!opt.keep)break}
    e.cd=99;if(opt.after)for(let n=0;n<opt.after*30;n++)step(1/30);
    return{states:[...seen],dmg:Math.round(hp0-pl.hp),fires:P.fires.map(f=>f.nap|0)}};
  r.moves.rockets=run(40,6,{T:1.4});r.moves.rocketsDodged=run(40,6,{T:1.4,dodge:6});
  r.moves.fire=run(41,4,{T:.9});r.moves.fireDodged=run(41,4,{T:.9,dodge:3});
  r.moves.bolt=run(43,6,{T:1.1});
  r.moves.gas=run(44,2,{T:2,keep:true,max:2.2,after:3,self:true});r.moves.gasFar=run(44,6,{T:2,keep:true,max:2.2,after:3,self:true});
  r.moves.orb=run(46,6,{T:3,max:6});r.moves.orbDodged=(()=>{const e=fresh(6);e.st=47;e.stT=e.stM=1;e.lx=pl.x;e.ly=pl.y;pl.x+=4;const h=pl.hp;for(let n=0;n<60;n++)step(1/30);return Math.round(h-pl.hp)})();
  // the Orbital Cannon only below 40%
  {const e=fresh(6);e.orbT=0;let used=new Set();for(let n=0;n<300;n++){step(1/30);if(e.st)used.add(e.st)}r.orbAbove=used.has(46);
   const e2=fresh(6);e2.hp=e2.max*.3;e2.orbT=0;used=new Set();for(let n=0;n<300;n++){step(1/30);if(e2.st)used.add(e2.st)}r.orbBelow=used.has(46);r.rage=!!e2.rage}
  // mines: ten of them, they arm after 1 s, a step trips one, a bullet sets one off safely
  {const e=fresh(6);e.st=45;e.stT=e.stM=1;e.lx=pl.x+3;e.ly=pl.y;for(let n=0;n<40;n++)step(1/30);e.dead=true;
   const M=P.fires.filter(f=>f.nap===3);r.mines=M.length;const m=M[0];
   pl.x=m.x+.3;pl.y=m.y;m.arm=.5;let h=pl.hp;step(1/30);r.unarmed=m.t>0&&pl.hp===h;
   m.arm=0;h=pl.hp;step(1/30);r.tripped=m.t<=0;r.tripDmg=Math.round(h-pl.hp);
   const m2=P.fires.find(f=>f.nap===3&&f.t>0);pl.x=m2.x+4;pl.y=m2.y;h=pl.hp;P.bullets.push({x:m2.x+.1,y:m2.y,vx:0,vy:0,team:0,dmg:1,dist:0,range:9,z0:0,zSlope:0,id:99999});step(1/30);r.shot=m2.t<=0;r.shotDmg=Math.round(h-pl.hp)}
  // the warnings draw for every state (host view)
  for(const st of[40,41,42,43,44,45,46,47]){const e=fresh(5);e.st=st;e.stT=.5;e.stM=1;e.lx=pl.x;e.ly=pl.y;try{P.render(1/60);r.draw.push(st)}catch(err){r.draw.push('ERR '+st+' '+err.message)}}
  P.fires.push({x:pl.x,y:pl.y,t:5,max:5,tick:1,r:3,nap:2},{x:pl.x+1,y:pl.y,t:5,max:5,tick:1e9,r:.45,nap:3,arm:0});try{P.render(1/60);r.drawFires=true}catch(err){r.drawFires=err.message}
  return r});
 fs.writeFileSync(__dirname+'/out/blackout_destroyer.json',JSON.stringify(out,null,1));console.log(JSON.stringify(out));
 assert.equal(out.hpRatio,1.25);assert.equal(out.weak,'ap');assert.ok(out.big>2);assert.ok(out.ecode);
 const M=out.moves;
 assert.ok(M.rockets.dmg>0,'rockets hit '+M.rockets.dmg);assert.equal(M.rocketsDodged.dmg,0,'rockets dodged');
 assert.ok(M.fire.states.includes(42),'fire stream');assert.ok(M.fire.dmg>0,'fire hits');assert.equal(M.fireDodged.dmg,0,'fire dodged');assert.ok(M.fire.fires.filter(n=>n===0).length>=4,'burning ground');
 assert.ok(M.bolt.dmg>0,'bolt hits');
 assert.ok(M.gas.fires.includes(2),'gas cloud');assert.ok(M.gas.dmg>0,'gas hurts inside');assert.equal(M.gasFar.dmg,0,'gas harmless outside');
 assert.ok(M.orb.states.includes(47),'orbital locks');assert.ok(M.orb.dmg>=60,'orbital beam '+M.orb.dmg);assert.equal(M.orbDodged,0,'orbital dodged');
 assert.equal(out.orbAbove,false,'no orbital above 40%');assert.ok(out.orbBelow,'orbital below 40%');assert.ok(out.rage);
 assert.ok(out.mines>=8,'mines '+out.mines);assert.ok(out.unarmed,'not armed yet');assert.ok(out.tripped&&out.tripDmg>0,'a step trips one');assert.ok(out.shot,'a bullet sets one off');assert.equal(out.shotDmg,0,'safely');
 assert.ok(out.draw.every(x=>typeof x==='number'),JSON.stringify(out.draw));assert.equal(out.drawFires,true);
 assert.deepEqual(errors,[]);console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
