// v0.9.6.5: +25% boss health, ammo weaknesses (+35% bullet damage), and the eight new moves for the Stormcaller, Tempest,
// Arsonist and Bulldozer: each one's warning state, where it hurts, and that its warning draws on screen.
const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),errors=[];
 const p=await b.newPage({viewport:{width:1280,height:800}});p.on('pageerror',e=>errors.push(e.message));
 await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`);await p.waitForFunction(()=>window.__pal);
 const out=await p.evaluate(async()=>{const P=__pal,res={hp:{},weak:{},moves:{},draw:[]};
  P.pick.mode='5';P.pick.size='std';P.showPage('solo');document.getElementById('startBtn').click();await new Promise(r=>setTimeout(r,300));
  let s=7;Math.random=()=>(s=(s*16807)%2147483647)/2147483647;
  const g=P.game;g.paused=true;g.phase='raid';g.queue=[];const step=dt=>{g.paused=false;P.update(dt);g.paused=true};
  const pl=P.player;
  const fresh=(k,dist)=>{P.enemies.length=0;g.queue=[];P.spawnBoss(k,false);const e=P.enemies.find(o=>o.type==='boss');
    pl.x=P.N/2;pl.y=P.N/2+3;pl.max=pl.hp=5000;pl.alive=true;pl.stun=0;P.qm.x=1;P.qm.y=1;
    e.x=pl.x;e.y=pl.y-dist;e.foe=pl;e.cd=0;e.lastNew=false;e.mvA=0;e.mvB=0;e.st=0;return e};
  // health: base x 1.25 (one player, early raid, so only the map and difficulty multipliers apply)
  for(const k of Object.keys(P.BOSSES)){const e=fresh(k,6);res.hp[e.boss]=+(e.max/(P.BOSSES[e.boss].hp*g.Df.hp*P.mapHp())).toFixed(3)}   // river bosses fall back to the Butcher on dry maps
  // weakness: +35% for the matching ammo, nothing for the rest, nothing for raiders
  for(const k of Object.keys(P.BOSS_WEAK)){const e={type:'boss',boss:k,x:0,y:0};const w=P.BOSS_WEAK[k],other=['ap','fire','blast','shock'].find(a=>a!==w);
    res.weak[k]=[P.bossWeak(e,{ammo:[[w,1]]}),P.bossWeak({...e,weakSeen:true},{ammo:[[other,1]]}),P.bossWeak({type:'rifle',x:0,y:0},{ammo:[[w,1]]}),P.bossWeak({...e,weakSeen:true},{})]}
  // each new move: start it, run it to the end, record the states it went through and the damage dealt
  const run=(k,dist,want,setup)=>{const e=fresh(k,dist);if(setup)setup(e);const hp0=pl.hp,fires0=P.fires2.length;
    const ok=P.startMove(k,e);const seen=new Set();let t=0;while(t<8){step(1/30);t+=1/30;if(e.st)seen.add(e.st);if(e.st===0&&seen.size)break}
    return{ok,first:[...seen][0],states:[...seen],dmg:Math.round(hp0-pl.hp),fires:P.fires2.length-fires0,want}};
  res.moves.pulse=run('storm',2.5,21);
  res.moves.strike=run('storm',7,20,e=>{e.mvA=99});
  res.moves.cyclone=run('tempest',6,22);
  res.moves.cage=run('tempest',6,24,e=>{e.mvA=99});
  res.moves.flame=run('arsonist',2.5,25);
  res.moves.firering=run('arsonist',6,27,e=>{e.mvA=99});
  res.moves.slam=run('bulldozer',2.2,28);
  res.moves.overdrive=run('bulldozer',6,29);
  // a dodged Thunderstrike: the player steps away during the warning and takes nothing
  {const e=fresh('storm',7);e.mvA=99;P.startMove('storm',e);const hp0=pl.hp;step(.3);pl.x+=4;let t=0;while(t<3&&e.st){step(1/30);t+=1/30}res.moves.strikeDodged=Math.round(hp0-pl.hp)}
  // after a new move, the boss uses his own attack before another new one
  {const e=fresh('storm',7);e.mvA=99;P.startMove('storm',e);let t=0;while(t<3&&e.st){step(1/30);t+=1/30}e.cd=0;e.mvA=0;e.mvB=0;res.moves.alternates=!P.startMove('storm',e)&&e.lastNew===true}
  // the warnings draw for every new state (host view)
  for(const st of[20,21,22,23,24,25,26,27,28,29,30]){const e=fresh(['storm','storm','tempest','tempest','tempest','arsonist','arsonist','arsonist','bulldozer','bulldozer','bulldozer'][[20,21,22,23,24,25,26,27,28,29,30].indexOf(st)],5);
    e.st=st;e.stT=.5;e.stM=1;e.lx=pl.x;e.ly=pl.y;try{P.render();res.draw.push(st)}catch(err){res.draw.push('ERR '+st+' '+err.message)}}
  // the Permafrost Foreman borrows the Bulldozer's AI but doesn't get the new moves
  res.permafrost=P.BOSSES.whiteforeman.think!==P.BOSSES.bulldozer.think;
  return res});
 for(const [k,v]of Object.entries(out.hp))assert.equal(v,1.25,'hp '+k);
 for(const [k,v]of Object.entries(out.weak))assert.deepEqual(v,[1.35,1,1,1],'weak '+k);
 assert.equal(Object.keys(out.weak).length,15);   // v0.9.7: + the Supreme Destroyer
 const M=out.moves;
 for(const k of['pulse','strike','cyclone','cage','flame','firering','slam','overdrive']){assert.ok(M[k].ok,k+' starts');assert.equal(M[k].first,M[k].want,k+' warning state')}
 for(const k of['pulse','strike','cyclone','cage','flame','slam','overdrive'])assert.ok(M[k].dmg>0,k+' hits the player in its area: '+M[k].dmg);
 assert.equal(M.firering.dmg,0,'Ring of Fire leaves the middle safe');assert.equal(M.firering.fires,8,'Ring of Fire lays 8 napalm patches');
 assert.equal(M.strikeDodged,0,'stepping out of the rings dodges Thunderstrike');
 assert.ok(M.alternates,'the boss goes back to his own attack between new moves');
 assert.ok(out.draw.every(x=>typeof x==='number'),JSON.stringify(out.draw));
 assert.ok(out.permafrost);
 assert.deepEqual(errors,[]);
 fs.writeFileSync(__dirname+'/out/v0965_bosses.json',JSON.stringify(out,null,1));
 console.log(JSON.stringify(Object.fromEntries(Object.entries(M).map(([k,v])=>[k,typeof v==='object'?{dmg:v.dmg,states:v.states}:v]))));console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
