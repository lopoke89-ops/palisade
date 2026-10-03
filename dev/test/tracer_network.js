const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
(async()=>{const b=await chromium.launch({executablePath:process.env.CHROMIUM||undefined,args:['--disable-features=WebRtcHideLocalIpsWithMdns']}),h=await b.newPage(),g=await b.newPage(),errors=[],url='http://localhost:8080/debug.html?debug=1&peerhost=127.0.0.1&peerport=9000&peerpath=/';
for(const p of[h,g]){p.on('pageerror',e=>errors.push(e.message));await p.goto(url)}
await h.evaluate(()=>{__pal.locker.owned.push('trail:f_trans','skin:sahur','hat:devilhorns');__pal.locker.eq.trail='f_trans';__pal.locker.eq.skin='sahur';__pal.locker.eq.hat='devilhorns'});
await h.click('[data-go=multi]');await h.fill('#mName','Color Host');await h.click('#hostBtn');await h.waitForSelector('#pg-lobby:not([hidden])');const code=await h.textContent('#lCode');
const join=async p=>{await p.click('[data-go=multi]');await p.fill('#mName','Color Guest');await p.fill('#mCode',code);await p.click('#joinBtn')};
await join(g);await g.waitForSelector('#pg-lobby:not([hidden])');await h.evaluate(()=>__pal.lobbyReadyAll());await h.click('#lStart');await g.waitForFunction(()=>__pal.NET.inGame);
const shots=await h.evaluate(()=>{const P=__pal,p=P.player;P.game.paused=true;P.bullets.length=0;p.aim={x:1,y:0};for(let i=0;i<3;i++)P.shoot(p,{...p.gun,speed:0,range:100,pellets:3,spread:.1},0);return P.bullets.map(b=>({id:b.id,tc:b.tc}))});
await g.waitForFunction(ids=>ids.every(id=>__pal.bullets.some(b=>b.id===id)),shots.map(b=>b.id));
const received=await g.evaluate(ids=>__pal.bullets.filter(b=>ids.includes(b.id)).map(b=>({id:b.id,tc:b.tc})),shots.map(b=>b.id));assert.deepEqual(received,shots);
assert.ok(await g.evaluate(()=>[...__pal.players.values()].some(p=>p.cos.skin==='sahur'&&p.cos.hat==='devilhorns'&&__pal.playerLook(p).horns)),'guest sees Sahur Devil Horns');
const late=await b.newPage();late.on('pageerror',e=>errors.push(e.message));await late.goto(url);await join(late);await late.waitForFunction(()=>__pal.NET.inGame);await late.waitForFunction(ids=>ids.every(id=>__pal.bullets.some(b=>b.id===id)),shots.map(b=>b.id));
const resumed=await late.evaluate(ids=>({shots:__pal.bullets.filter(b=>ids.includes(b.id)).map(b=>({id:b.id,tc:b.tc})),sahur:[...__pal.players.values()].some(p=>p.cos.skin==='sahur'&&p.cos.hat==='devilhorns'&&__pal.playerLook(p).horns)}),shots.map(b=>b.id));assert.deepEqual(resumed.shots,shots);assert.ok(resumed.sahur);assert.deepEqual(errors,[]);
fs.writeFileSync(__dirname+'/out/tracer_network.json',JSON.stringify({shots,received,resumed,errors},null,2));console.log('shot colors and Sahur reached guest + mid-match join');console.log('errors: none');await b.close();})().catch(e=>{console.error(e);process.exit(1)});
