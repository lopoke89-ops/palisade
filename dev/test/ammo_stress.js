// Six shooters, persistent crowd and boss, comparing ordinary and special ammo.
// CPU measurements describe this PC's phone-sized Chrome viewport, not phone hardware.
const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined,args:['--disable-gpu','--disable-accelerated-2d-canvas']}),p=await b.newPage({viewport:{width:390,height:844}}),errors=[];
  p.on('pageerror',e=>errors.push(e.message));await p.goto('http://localhost:8080/debug.html?debug=1');
  const out=await p.evaluate(()=>{const P=__pal;P.demo=false;P.pick.mode='endless';P.pick.map='yard';
    const run=ammo=>{P.newGame(['soldier','sniper','grenadier','quartermaster','sniper','grenadier'].map((cls,i)=>({id:i?'bot'+i:'solo',name:'Bot'+i,cls,cos:'',sk:P.skillStr({ammo_fire:4,ammo_shock:4,ammo_blast:4})})),'');
      for(const p of P.players.values()){p.hp=p.max=1e9;p.x=P.core.i+.5+(p.slot-2)*.3;p.y=P.core.j+2;p.ammoEq=ammo?(p.cls==='sniper'?['blast','shock']:[p.slot%2?'fire':'blast','']):['','']}
      P.core.hp=P.core.max=P.qm.hp=P.qm.max=1e9;P.game.wave=19;P.startRaid();P.game.queue=[];P.NET.mode='host';P.NET.inGame=true;
      for(let i=0;i<48;i++){const e=P.spawnEnemyAt(i%5?'rifle':'shield',3.5+(i%8)*1.2,2.5+Math.floor(i/8)*1.1);e.hp=e.max=1e6;e.cd=999;e.speed=0}
      P.spawnBoss('butcher');const boss=P.enemies.find(e=>e.type==='boss');boss.hp=boss.max=1e6;
      const up=[],rn=[];let peakParts=0,peakEvents=0,peakBullets=0,peakStatus=0;
      for(let f=0;f<1200;f++){
        // Capture and process real projectiles from every gun; refill to keep the load steady.
        for(const p of P.players.values()){const e=P.enemies[(p.slot+Math.floor(f/60))%48],dx=e.x-p.x,dy=e.y-p.y,l=Math.hypot(dx,dy)||1;p.aim={x:dx/l,y:dy/l};if(f%12===0)P.shoot(p,p.gun,0)}
        const t=performance.now();P.update(1/60);up.push(performance.now()-t);
        if(ammo&&f%30===0)for(let i=0;i<P.enemies.length;i++){const e=P.enemies[i];P.ammoHit(e,{own:'bot'+(i%6),shot:50000+f*100+i,ammo:[['fire',4],['shock',4]]})}
        peakParts=Math.max(peakParts,P.parts.length);peakEvents=Math.max(peakEvents,P.NET.fxq.length);peakBullets=Math.max(peakBullets,P.bullets.length);peakStatus=Math.max(peakStatus,P.enemies.filter(e=>e.burnT>0||e.slowT>0).length);P.NET.fxq=[];
        if(f%5===0){const t=performance.now();P.render(1/60);P.ctx.getImageData(0,0,1,1);rn.push(performance.now()-t)}
      }
      const q=(a,f)=>+a.sort((x,y)=>x-y)[Math.floor(a.length*f)].toFixed(2);
      return{players:P.players.size,enemies:P.enemies.length,peakStatus,peakParts,peakEvents,peakBullets,updateMedianMs:q(up,.5),updateP90Ms:q(up,.9),renderMedianMs:q(rn,.5),renderP90Ms:q(rn,.9),maxRoundHistory:Math.max(...P.enemies.flatMap(e=>Object.values(e.ammoSeen||{}).map(a=>a.length)),0)};
    };const out={ordinary:run(false),special:run(true)};P.NET.mode='solo';P.NET.inGame=false;return out});
  assert.equal(out.special.players,6);assert.ok(out.special.peakStatus>=48);assert.ok(out.special.maxRoundHistory<=128);assert.ok(out.special.peakParts<4000);assert.deepEqual(errors,[]);
  fs.writeFileSync(__dirname+'/out/ammo_stress.json',JSON.stringify(out,null,2));console.log(JSON.stringify(out));console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
