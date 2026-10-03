// v0.9.7 City Black Out rewards on the client: a won run's claim (cv:5, 9 stages, POIs held and majors, the Destroyer),
// a no-account locker paid by the server's rules (POIs fill the Supply Case bar, +1 per major, the win, the Destroyer),
// the BLACK OUT ladder's counters and unlocks, its six items in the Locker's milestone tab, and their art drawing.
const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined}),errors=[];
 const p=await b.newPage({viewport:{width:1280,height:800}});p.on('pageerror',e=>errors.push(e.message));
 await p.goto(`http://localhost:${process.env.PORT||8080}/debug.html?debug=1`);await p.waitForFunction(()=>window.__pal);
 const out=await p.evaluate(async()=>{const P=__pal,r={};
  P.locker.cases=0;P.locker.prog=0;P.locker.shards=0;P.locker.st={...P.locker.st,bo_pois:0,bo_wins:0,bo_dest:0,bo_perfect:0};
  P.pick.mode='blackout';P.showPage('solo');document.getElementById('startBtn').click();await new Promise(z=>setTimeout(z,400));
  const g=P.game;g.paused=true;g.timer=.01;g.paused=false;P.update(1/20);g.paused=true;
  const B=g.bo;B.held=8;B.lost=0;B.destroyer=true;B.stage='done';g.time=900;P.player.sal=0;
  g.won=true;g.phase='over';const {claim}=P.runClaim(9,true,40);r.claim={cv:claim.cv,mode:claim.mode,to:claim.raid_to,pois:claim.pois_held,major:claim.pois_major,dest:claim.destroyer,keys:claim.boss_keys.length};
  g.phase='raid';P.endGame(true);await new Promise(z=>setTimeout(z,300));
  r.title=document.getElementById('overTitle').textContent;r.eye=document.getElementById('overEyebrow').textContent;r.loot=document.getElementById('overLoot').textContent;
  r.locker={cases:P.locker.cases,prog:P.locker.prog,shards:P.locker.shards,st:{p:P.locker.st.bo_pois,w:P.locker.st.bo_wins,d:P.locker.st.bo_dest,f:P.locker.st.bo_perfect}};
  r.owns=['skin:nightshift','hat:blackout','trail:streetlight','fx:orbital','bg:skyline','skin:gnightshift'].map(id=>P.locker.owned.includes(id));
  // the Locker's milestone tab: the ladder with its six tiles
  P.toMenu();P.showPage('locker');await new Promise(z=>setTimeout(z,200));document.querySelector('#lockTabs [data-cat=ms]').click();await new Promise(z=>setTimeout(z,300));
  const h=[...document.querySelectorAll('.gsec')].find(x=>/CITY BLACK OUT/.test(x.textContent));r.ladder=h?h.textContent:'';r.tiles=h&&h.nextElementSibling?h.nextElementSibling.children.length:0;
  return r});
 fs.writeFileSync(__dirname+'/out/blackout_rewards.json',JSON.stringify(out,null,1));console.log(JSON.stringify(out));
 assert.deepEqual(out.claim,{cv:5,mode:'blackout',to:9,pois:8,major:4,dest:true,keys:0});
 assert.equal(out.title,'THE CITY HELD');assert.match(out.eye,/8 OF 8 POINTS HELD · THE DESTROYER IS DOWN/);assert.match(out.loot,/8 points held/);
 assert.equal(out.locker.cases,8,'2 from 8 points + 4 majors + 2 for the win');assert.equal(out.locker.prog,2);assert.ok(out.locker.shards>=65,'shards '+out.locker.shards);
 assert.deepEqual(out.locker.st,{p:8,w:1,d:1,f:1});
 assert.deepEqual(out.owns,[false,true,false,true,true,false],'helmet, orbital strike and the skyline unlock');
 assert.match(out.ladder,/8 points held · 1 win · 1 Destroyer · 3 \/ 6 unlocked/);assert.equal(out.tiles,6);
 assert.deepEqual(errors,[]);console.log('errors: none');await b.close();
})().catch(e=>{console.error(e);process.exit(1)});
