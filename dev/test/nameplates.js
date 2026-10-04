// v0.9.9 nameplates: the top-left health panel is gone during matches; your bar and number sit above your head,
// teammates and Delgado show a name and a bar, PvP enemies a name only, teammates off screen get an edge arrow
// (red while downed), low health tints your screen edge, core health sits under the timer, Delgado's button is the
// host's only, and the Black Out ready tick shows on the plate. Three sizes; screenshots in out/plates_*.png.
const innerW={desktop:1366,portrait:390,landscape:844},{chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),errors=[],out={};
 for(const [n,vp,m]of[['desktop',{width:1366,height:820},false],['portrait',{width:390,height:844},true],['landscape',{width:844,height:390},true]]){
  const p=await b.newPage({viewport:vp,isMobile:m,hasTouch:m});p.on('pageerror',e=>errors.push(n+': '+e.message));
  await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`);await p.waitForFunction(()=>window.__pal);
  const frame=()=>p.evaluate(async()=>{for(let i=0;i<3;i++)await new Promise(r=>requestAnimationFrame(r));return __pal.plates});
  await p.evaluate(async()=>{const P=__pal;P.pick.mode='5';P.showPage('solo');document.getElementById('startBtn').click();await new Promise(r=>setTimeout(r,600));
   for(let i=0;i<3;i++){const q=P.makePlayer('m'+i,'Mate'+i,'soldier',i+1,'','');q.x=P.player.x+1+i*.8;q.y=P.player.y+.6;q.hp=q.max*(i===1?.2:.8);P.players.set('m'+i,q)}
   P.qm.x=P.player.x-1.2;P.qm.y=P.player.y+.4});
  let r=await frame();const R=s=>p.evaluate(s=>{const e=document.querySelector(s);if(!e||e.closest('[hidden]'))return null;const q=e.getBoundingClientRect();return q.width?{l:q.left,t:q.top,r:q.right,b:q.bottom}:null},s);
  const res={vitals:await R('#top .vitals'),core:await R('#top .phase #coreM'),phase:await R('#top .phase'),qmBtn:await R('#qmCommand'),plates:r};
  res.me=r.find(x=>x.who==='me');res.mates=r.filter(x=>/^Mate/.test(x.who||''));res.qm=r.find(x=>x.who==='DELGADO');
  await p.screenshot({path:`${__dirname}/out/plates_${n}.png`});
  // a teammate far away, another downed far away: edge arrows
  r=await p.evaluate(async()=>{const P=__pal,a=P.players.get('m0'),d=P.players.get('m2');a.x=P.player.x+14;a.y=P.player.y-12;d.x=P.player.x-14;d.y=P.player.y+12;d.alive=false;d.rt=8;
   for(let i=0;i<3;i++)await new Promise(r=>requestAnimationFrame(r));return P.plates});
  res.arrows=r.filter(x=>x.arrow);
  // low health
  r=await p.evaluate(async()=>{const P=__pal;P.player.hp=P.player.max*.15;for(let i=0;i<3;i++)await new Promise(r=>requestAnimationFrame(r));return P.plates});res.low=r.some(x=>x.lowGlow);
  if(n==='desktop')await p.screenshot({path:`${__dirname}/out/plates_low_desktop.png`});
  // Delgado's button: host yes, guest no
  res.guestBtn=await p.evaluate(()=>{const P=__pal,m=P.NET.mode;P.NET.mode='guest';P.syncQMControls();const h=document.getElementById('qmCommand').hidden;P.NET.mode=m;P.syncQMControls();return h});
  out[n]=res;await p.close()}
 // PvP: enemy names only
 {const p=await b.newPage({viewport:{width:1366,height:820}});p.on('pageerror',e=>errors.push('pvp: '+e.message));await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`);await p.waitForFunction(()=>window.__pal);
  out.pvp=await p.evaluate(async()=>{const P=__pal;P.pick.mode='5';P.showPage('solo');document.getElementById('startBtn').click();await new Promise(r=>setTimeout(r,600));P.game.paused=true;P.game.pvp='base';P.player.team='a';
   const f=P.makePlayer('f1','Friend','soldier',1,'','');f.team='a';f.x=P.player.x+1;f.y=P.player.y;const e=P.makePlayer('e1','Enemy','soldier',2,'','');e.team='b';e.x=P.player.x-1;e.y=P.player.y;P.players.set('f1',f);P.players.set('e1',e);
   P.drawNameplates();const r=P.plates;P.game.pvp=false;P.players.delete('f1');P.players.delete('e1');return{friend:r.find(x=>x.who==='Friend'),enemy:r.find(x=>x.who==='Enemy')}});await p.close()}
 fs.writeFileSync(__dirname+'/out/nameplates.json',JSON.stringify(out,null,1));
 for(const n of['desktop','portrait','landscape']){const r=out[n];
  assert.equal(r.vitals,null,n+': the top-left health panel is gone');assert.ok(r.core&&r.core.t>=r.phase.t&&r.core.b<=r.phase.b+1,n+': core health under the timer, in the phase box');if(n!=='landscape')assert.ok(r.phase.r>innerW[n]-40,n+': the phase box stays top right');
  assert.ok(r.qmBtn,n+': Delgado\'s button shows for the host');assert.equal(r.guestBtn,true,n+': and not for a guest');
  assert.ok(r.me&&r.me.bar&&r.me.num>0,n+': your bar and number above your head');assert.equal(r.mates.length,3,n+': every teammate has a plate');assert.ok(r.mates.every(x=>x.bar),n+': teammates show a bar');
  assert.ok(r.mates.some(x=>x.frac<.3),n+': a hurt teammate reads low');assert.ok(r.qm&&r.qm.bar,n+': Delgado has a plate');
  assert.ok(r.arrows.length===2&&r.arrows.some(a=>a.down)&&r.arrows.some(a=>!a.down),n+': edge arrows for teammates off screen, one marked down '+JSON.stringify(r.arrows));
  assert.ok(r.low,n+': low health tints the screen edge')}
assert.ok(out.pvp.friend&&out.pvp.friend.bar,'PvP: your team shows bars');assert.ok(out.pvp.enemy&&!out.pvp.enemy.bar,'PvP: the other side shows names only');
 console.log(JSON.stringify({desktop:{core:out.desktop.core,me:out.desktop.me},pvp:out.pvp}));assert.deepEqual(errors,[]);console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
