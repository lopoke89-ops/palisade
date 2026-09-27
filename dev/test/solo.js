const { chromium } = require('playwright');
const O=__dirname+'/out';
(async()=>{
 const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined});
 const p=await b.newPage({viewport:{width:1600,height:900}});
 const errs=[];p.on('pageerror',e=>errs.push(e.message+' '+(e.stack||'').split('\n')[1]));
 await p.goto('http://localhost:8080/debug.html?debug=1');await p.waitForTimeout(800);
 await p.mouse.move(800,450);
 await p.click('[data-go=solo]');await p.click('[data-c=sniper]');await p.click('#startBtn');await p.waitForTimeout(500);
 const P=f=>p.evaluate(f);
 console.log('start', await P(()=>({mats:__pal.player.mats,cap:__pal.player.cap,keys:document.getElementById('keys').textContent,sub:document.getElementById('buildSub').textContent})));
 // build a wall and a door
 const r=await P(()=>{const P=__pal,pl=P.player;const i=Math.floor(pl.x)+2,j=Math.floor(pl.y);
   const a=P.buildEval(pl,i,j,0,false);P.doBuild(pl,i,j,0,false);const m1=pl.mats[0];pl.bcd=0;
   let b;for(const[di,dj]of[[0,-1],[1,0],[-1,1],[0,-2],[2,-1],[1,1]]){b=P.buildEval(pl,i+di,j+dj,0,true);if(b.ok){P.doBuild(pl,i+di,j+dj,0,true);break}}const m2=pl.mats[0];pl.bcd=0;
   const c=P.buildEval(pl,i,j,0,true);  // make door from wall
   return{wall:a.cost,after1:m1,door:b.cost,dok:b.ok,dr:b.reason,after2:m2,makeDoor:c.cost,act:c.act}});
 console.log('build',JSON.stringify(r));
 // gather: stand on the nearest wood pile for 1s
 console.log('gather',await P(async()=>{const P=__pal,pl=P.player;pl.mats[0]=0;const n=P.game&&window.__nodes;return 'skip'}));
 // sniper semi-auto: hold mouse for 2s -> 1 shot; then 3 clicks spaced -> 3 more
 await P(()=>{__pal.startRaid()});await p.waitForTimeout(300);
 const shots=()=>P(()=>__pal.bullets.filter(b=>b.own===__pal.player.id).length);
 let fired=0;const cnt=async()=>P(()=>window.__shots||0);
 await P(()=>{window.__shots=0;const o=__pal.player;const orig=o.__cd;let last=o.cd;setInterval(()=>{if(o.cd>last+.3)window.__shots++;last=o.cd},5)});
 await p.mouse.move(1200,450);await p.mouse.down();await p.waitForTimeout(2000);await p.mouse.up();
 const held=await cnt();
 for(let k=0;k<3;k++){await p.mouse.down();await p.waitForTimeout(30);await p.mouse.up();await p.waitForTimeout(1200)}
 const clicked=await cnt();
 console.log('sniper: holding 2s fired',held,'then 3 clicks ->',clicked-held);
 await p.mouse.down();await p.waitForTimeout(40);await p.mouse.up();await p.waitForTimeout(170);
 await p.screenshot({path:O+'/bolt.png'});
 console.log('bolt state',await P(()=>({bolt:__pal.player.bolt,boltT:__pal.player.boltT})));
 console.log('keys',await P(()=>document.getElementById('keys').textContent),'chatBtn hidden',await P(()=>document.getElementById('chatBtn').hidden));
 console.log('ERRS',errs);await b.close();
})().catch(e=>{console.log('FAIL',e.message);process.exit(1)});
